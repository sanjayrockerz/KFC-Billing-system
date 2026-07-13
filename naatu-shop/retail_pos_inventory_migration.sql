-- Retail POS + Inventory migration (safe, additive)
-- Run this in Supabase SQL Editor.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Categories: editable and reusable by admin
CREATE TABLE IF NOT EXISTS public.categories (
  id BIGSERIAL PRIMARY KEY,
  name_en TEXT NOT NULL UNIQUE,
  name_ta TEXT NOT NULL DEFAULT '',
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "categories_anon_read" ON public.categories;
CREATE POLICY "categories_anon_read" ON public.categories
FOR SELECT TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "categories_admin_manage" ON public.categories;
CREATE POLICY "categories_admin_manage" ON public.categories
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid() AND COALESCE(p.role, 'customer') = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid() AND COALESCE(p.role, 'customer') = 'admin'
  )
);

-- Products: additive retail fields
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category_id BIGINT REFERENCES public.categories(id) ON DELETE SET NULL;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS tamil_name TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS unit_type TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS unit_label TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS base_quantity NUMERIC(12,3);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS stock_quantity NUMERIC(12,3);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS stock_unit TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS allow_decimal_quantity BOOLEAN;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS predefined_options JSONB DEFAULT '[]'::JSONB;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_active BOOLEAN;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS sort_order INTEGER;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url TEXT;

ALTER TABLE public.products
  ALTER COLUMN predefined_options SET DEFAULT '[]'::JSONB;

-- Ensure updated_at exists for legacy tables
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Backfill categories from legacy text category field
INSERT INTO public.categories (name_en, name_ta, sort_order)
SELECT DISTINCT
  TRIM(p.category) AS name_en,
  TRIM(p.category) AS name_ta,
  0
FROM public.products p
WHERE COALESCE(TRIM(p.category), '') <> ''
ON CONFLICT (name_en) DO NOTHING;

UPDATE public.products p
SET category_id = c.id
FROM public.categories c
WHERE p.category_id IS NULL
  AND COALESCE(TRIM(p.category), '') <> ''
  AND c.name_en = TRIM(p.category);

-- Backfill retail unit model from legacy columns
UPDATE public.products
SET tamil_name = COALESCE(NULLIF(tamil_name, ''), NULLIF(name_ta, ''), '')
WHERE tamil_name IS NULL OR tamil_name = '';

UPDATE public.products
SET unit_type = COALESCE(
  NULLIF(unit_type, ''),
  CASE
    WHEN LOWER(COALESCE(unit, '')) ~ '(mg|g|kg)$' THEN 'weight'
    WHEN LOWER(COALESCE(unit, '')) ~ '(ml|l)$' THEN 'volume'
    ELSE 'unit'
  END
)
WHERE unit_type IS NULL OR unit_type = '';

UPDATE public.products
SET unit_label = COALESCE(
  NULLIF(unit_label, ''),
  (regexp_match(LOWER(COALESCE(unit, '')), '([a-z]+)$'))[1],
  CASE
    WHEN unit_type = 'weight' THEN 'g'
    WHEN unit_type = 'volume' THEN 'ml'
    WHEN unit_type = 'bundle' THEN 'bundle'
    ELSE 'piece'
  END
)
WHERE unit_label IS NULL OR unit_label = '';

UPDATE public.products
SET base_quantity = COALESCE(
  base_quantity,
  NULLIF((regexp_match(LOWER(COALESCE(unit, '')), '^([0-9]+(?:\\.[0-9]+)?)'))[1], '')::NUMERIC,
  CASE WHEN unit_type IN ('unit', 'bundle') THEN 1 ELSE 100 END
)
WHERE base_quantity IS NULL OR base_quantity <= 0;

UPDATE public.products
SET stock_quantity = COALESCE(stock_quantity, stock, 0)
WHERE stock_quantity IS NULL;

UPDATE public.products
SET stock_unit = COALESCE(NULLIF(stock_unit, ''), NULLIF(unit_label, ''), 'piece')
WHERE stock_unit IS NULL OR stock_unit = '';

UPDATE public.products
SET allow_decimal_quantity = COALESCE(allow_decimal_quantity, unit_type IN ('weight', 'volume'))
WHERE allow_decimal_quantity IS NULL;

UPDATE public.products
SET predefined_options = COALESCE(predefined_options, '[]'::JSONB)
WHERE predefined_options IS NULL;

UPDATE public.products
SET image_url = COALESCE(NULLIF(image_url, ''), NULLIF(image, ''), '/assets/images/default-herb.jpg')
WHERE image_url IS NULL OR image_url = '';

UPDATE public.products
SET is_active = COALESCE(is_active, true)
WHERE is_active IS NULL;

UPDATE public.products
SET sort_order = COALESCE(sort_order, id)
WHERE sort_order IS NULL;

-- Keep legacy columns coherent for older UI screens
UPDATE public.products
SET name_ta = COALESCE(NULLIF(name_ta, ''), tamil_name, '')
WHERE name_ta IS NULL OR name_ta = '';

UPDATE public.products
SET stock = GREATEST(0, FLOOR(COALESCE(stock_quantity, 0))::INTEGER)
WHERE stock IS DISTINCT FROM GREATEST(0, FLOOR(COALESCE(stock_quantity, 0))::INTEGER);

ALTER TABLE public.products
  ALTER COLUMN unit_type SET DEFAULT 'unit',
  ALTER COLUMN unit_label SET DEFAULT 'piece',
  ALTER COLUMN base_quantity SET DEFAULT 1,
  ALTER COLUMN stock_quantity SET DEFAULT 0,
  ALTER COLUMN stock_unit SET DEFAULT 'piece',
  ALTER COLUMN allow_decimal_quantity SET DEFAULT false,
  ALTER COLUMN is_active SET DEFAULT true,
  ALTER COLUMN sort_order SET DEFAULT 0;

DO $$
BEGIN
  ALTER TABLE public.products
    ADD CONSTRAINT products_unit_type_check
    CHECK (unit_type IN ('unit', 'weight', 'volume', 'bundle'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON public.products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_sort_order ON public.products(sort_order);
CREATE INDEX IF NOT EXISTS idx_products_unit_type ON public.products(unit_type);
CREATE INDEX IF NOT EXISTS idx_categories_sort_order ON public.categories(sort_order);

-- Decimal-capable stock decrement RPC
CREATE OR REPLACE FUNCTION public.retail_decrement_stock(
  p_product_id BIGINT,
  p_quantity NUMERIC,
  p_unit TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_unit_type TEXT;
  v_unit_label TEXT;
  v_stock_unit TEXT;
  v_deduct NUMERIC;
BEGIN
  SELECT
    COALESCE(NULLIF(unit_type, ''), 'unit'),
    COALESCE(NULLIF(unit_label, ''), 'piece'),
    COALESCE(NULLIF(stock_unit, ''), COALESCE(NULLIF(unit_label, ''), 'piece'))
  INTO v_unit_type, v_unit_label, v_stock_unit
  FROM public.products
  WHERE id = p_product_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_deduct := GREATEST(COALESCE(p_quantity, 0), 0);

  IF v_unit_type = 'weight' THEN
    IF LOWER(COALESCE(p_unit, v_unit_label)) = 'kg' AND LOWER(v_stock_unit) = 'g' THEN
      v_deduct := v_deduct * 1000;
    ELSIF LOWER(COALESCE(p_unit, v_unit_label)) = 'g' AND LOWER(v_stock_unit) = 'kg' THEN
      v_deduct := v_deduct / 1000;
    ELSIF LOWER(COALESCE(p_unit, v_unit_label)) = 'mg' AND LOWER(v_stock_unit) = 'g' THEN
      v_deduct := v_deduct / 1000;
    ELSIF LOWER(COALESCE(p_unit, v_unit_label)) = 'g' AND LOWER(v_stock_unit) = 'mg' THEN
      v_deduct := v_deduct * 1000;
    END IF;
  ELSIF v_unit_type = 'volume' THEN
    IF LOWER(COALESCE(p_unit, v_unit_label)) = 'l' AND LOWER(v_stock_unit) = 'ml' THEN
      v_deduct := v_deduct * 1000;
    ELSIF LOWER(COALESCE(p_unit, v_unit_label)) = 'ml' AND LOWER(v_stock_unit) = 'l' THEN
      v_deduct := v_deduct / 1000;
    END IF;
  ELSE
    v_deduct := GREATEST(ROUND(v_deduct), 0);
  END IF;

  UPDATE public.products
  SET
    stock_quantity = GREATEST(0, COALESCE(stock_quantity, stock, 0) - GREATEST(v_deduct, 0)),
    stock = GREATEST(0, FLOOR(GREATEST(0, COALESCE(stock_quantity, stock, 0) - GREATEST(v_deduct, 0)))::INTEGER),
    updated_at = NOW()
  WHERE id = p_product_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.retail_decrement_stock(BIGINT, NUMERIC, TEXT) TO anon, authenticated;

-- Keep existing function name for backward compatibility
CREATE OR REPLACE FUNCTION public.decrement_stock(product_id BIGINT, qty_sold INTEGER)
RETURNS VOID AS $$
BEGIN
  PERFORM public.retail_decrement_stock(product_id, qty_sold::NUMERIC, NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.decrement_stock(BIGINT, INTEGER) TO anon, authenticated;