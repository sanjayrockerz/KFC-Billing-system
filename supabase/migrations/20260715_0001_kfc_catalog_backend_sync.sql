-- Korean Fried Chicken catalog/backend sync.
-- Run this on the connected KFC Supabase project after deploying this frontend.
-- The portal uses local password auth, so catalog writes are performed with the
-- anon client and require explicit anon policies for product/category management.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS name_en TEXT,
  ADD COLUMN IF NOT EXISTS name_ta TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS name_ta TEXT,
  ADD COLUMN IF NOT EXISTS tamil_name TEXT,
  ADD COLUMN IF NOT EXISTS category TEXT,
  ADD COLUMN IF NOT EXISTS category_id BIGINT REFERENCES public.categories(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS remedy JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS price NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS offer_price NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS unit_type TEXT DEFAULT 'unit',
  ADD COLUMN IF NOT EXISTS unit_label TEXT DEFAULT 'pc',
  ADD COLUMN IF NOT EXISTS base_quantity NUMERIC(10,3) DEFAULT 1,
  ADD COLUMN IF NOT EXISTS stock_quantity NUMERIC(12,3) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stock NUMERIC(12,3) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stock_unit TEXT DEFAULT 'pc',
  ADD COLUMN IF NOT EXISTS allow_decimal_quantity BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS predefined_options JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT '1pc',
  ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2) DEFAULT 4.8,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS description_ta TEXT,
  ADD COLUMN IF NOT EXISTS benefits TEXT,
  ADD COLUMN IF NOT EXISTS benefits_ta TEXT,
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS image TEXT,
  ADD COLUMN IF NOT EXISTS has_variants BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS sku TEXT,
  ADD COLUMN IF NOT EXISTS barcode TEXT,
  ADD COLUMN IF NOT EXISTS brand TEXT DEFAULT 'Korean Fried Chicken',
  ADD COLUMN IF NOT EXISTS purchase_price NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS mrp NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gst_percent NUMERIC(5,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS opening_stock NUMERIC(12,3) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS low_stock_alert NUMERIC(12,3) DEFAULT 5,
  ADD COLUMN IF NOT EXISTS supplier TEXT,
  ADD COLUMN IF NOT EXISTS size TEXT,
  ADD COLUMN IF NOT EXISTS color TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE TABLE IF NOT EXISTS public.store_settings (
  id BIGSERIAL PRIMARY KEY,
  name TEXT DEFAULT 'Korean Fried Chicken',
  owner_name TEXT DEFAULT 'Sulficker Roshan N',
  phone TEXT DEFAULT '9342489391',
  address TEXT DEFAULT 'Nanjappa Garden Selvapuram, Shivalaya Mahal Road, SBI Bank Opposite, Komarapalayam, Coimbatore',
  gst_enabled BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.store_settings
  ADD COLUMN IF NOT EXISTS name TEXT DEFAULT 'Korean Fried Chicken',
  ADD COLUMN IF NOT EXISTS owner_name TEXT DEFAULT 'Sulficker Roshan N',
  ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '9342489391',
  ADD COLUMN IF NOT EXISTS address TEXT DEFAULT 'Nanjappa Garden Selvapuram, Shivalaya Mahal Road, SBI Bank Opposite, Komarapalayam, Coimbatore',
  ADD COLUMN IF NOT EXISTS gst_enabled BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_kfc_categories_name_lower ON public.categories (LOWER(BTRIM(name_en)));
CREATE INDEX IF NOT EXISTS idx_kfc_products_name_lower ON public.products (LOWER(BTRIM(name)));
CREATE INDEX IF NOT EXISTS idx_kfc_products_category_id ON public.products (category_id);
CREATE INDEX IF NOT EXISTS idx_kfc_products_active_sort ON public.products (is_active, sort_order);

DROP TRIGGER IF EXISTS trg_categories_touch_updated_at ON public.categories;
CREATE TRIGGER trg_categories_touch_updated_at
BEFORE UPDATE ON public.categories
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS trg_products_touch_updated_at ON public.products;
CREATE TRIGGER trg_products_touch_updated_at
BEFORE UPDATE ON public.products
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE OR REPLACE FUNCTION public.sync_product_category_name()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.category_id IS NOT NULL THEN
    SELECT c.name_en INTO NEW.category
    FROM public.categories c
    WHERE c.id = NEW.category_id;
  END IF;
  IF NULLIF(BTRIM(COALESCE(NEW.category, '')), '') IS NULL THEN
    NEW.category := 'Chicken';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_product_category_name ON public.products;
CREATE TRIGGER trg_sync_product_category_name
BEFORE INSERT OR UPDATE OF category_id, category ON public.products
FOR EACH ROW EXECUTE FUNCTION public.sync_product_category_name();

CREATE OR REPLACE FUNCTION public.sync_category_name_to_products()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.name_en IS DISTINCT FROM OLD.name_en THEN
    UPDATE public.products
    SET category = NEW.name_en,
        updated_at = NOW()
    WHERE category_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_category_name_to_products ON public.categories;
CREATE TRIGGER trg_sync_category_name_to_products
AFTER UPDATE OF name_en ON public.categories
FOR EACH ROW EXECUTE FUNCTION public.sync_category_name_to_products();

-- Hide stale categories/products from the failed shop while preserving old order history.
UPDATE public.categories
SET is_active = FALSE
WHERE LOWER(BTRIM(COALESCE(name_en, ''))) NOT IN ('chicken', 'sides', 'burgers & wraps', 'beverages');

UPDATE public.products
SET is_active = FALSE
WHERE LOWER(BTRIM(COALESCE(name, ''))) NOT IN (
  'bone shot', 'big shot', 'strips', 'loaded fries', 'french fries', 'wrap', 'burger'
);

-- Ensure canonical KFC categories exist and are visible.
WITH seed_categories(name_en, sort_order) AS (
  VALUES
    ('Chicken', 1),
    ('Sides', 2),
    ('Burgers & Wraps', 3),
    ('Beverages', 4)
)
INSERT INTO public.categories (name_en, name_ta, is_active, sort_order)
SELECT sc.name_en, '', TRUE, sc.sort_order
FROM seed_categories sc
WHERE NOT EXISTS (
  SELECT 1 FROM public.categories c
  WHERE LOWER(BTRIM(c.name_en)) = LOWER(BTRIM(sc.name_en))
);

UPDATE public.categories c
SET is_active = TRUE,
    name_en = sc.name_en,
    sort_order = sc.sort_order
FROM (
  VALUES
    ('Chicken', 1),
    ('Sides', 2),
    ('Burgers & Wraps', 3),
    ('Beverages', 4)
) AS sc(name_en, sort_order)
WHERE LOWER(BTRIM(c.name_en)) = LOWER(BTRIM(sc.name_en));

-- Remove duplicate active KFC categories, keeping one canonical row per name.
WITH ranked_categories AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY LOWER(BTRIM(name_en))
      ORDER BY sort_order NULLS LAST, id
    ) AS rn
  FROM public.categories
  WHERE LOWER(BTRIM(COALESCE(name_en, ''))) IN ('chicken', 'sides', 'burgers & wraps', 'beverages')
)
UPDATE public.categories c
SET is_active = FALSE
FROM ranked_categories r
WHERE c.id = r.id AND r.rn > 1;

-- Remove duplicate active KFC products, keeping one row per name if present.
WITH ranked AS (
  SELECT id, ROW_NUMBER() OVER (PARTITION BY LOWER(BTRIM(name)) ORDER BY id) AS rn
  FROM public.products
  WHERE LOWER(BTRIM(COALESCE(name, ''))) IN (
    'bone shot', 'big shot', 'strips', 'loaded fries', 'french fries', 'wrap', 'burger'
  )
)
UPDATE public.products p
SET is_active = FALSE
FROM ranked r
WHERE p.id = r.id AND r.rn > 1;

DO $$
DECLARE
  cat_chicken BIGINT;
  cat_sides BIGINT;
  cat_wraps BIGINT;
BEGIN
  SELECT id INTO cat_chicken FROM public.categories WHERE LOWER(BTRIM(name_en)) = 'chicken' LIMIT 1;
  SELECT id INTO cat_sides FROM public.categories WHERE LOWER(BTRIM(name_en)) = 'sides' LIMIT 1;
  SELECT id INTO cat_wraps FROM public.categories WHERE LOWER(BTRIM(name_en)) = 'burgers & wraps' LIMIT 1;

  WITH seed_products(name, category_id, price, stock, description, benefits, image_url, sort_order) AS (
    VALUES
      ('Bone Shot', cat_chicken, 150.00, 50, 'Crispy bone-in Korean fried chicken shot.', 'Juicy, crispy, full of flavour.', 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?auto=format&fit=crop&w=800&q=80', 1),
      ('Big Shot', cat_chicken, 250.00, 50, 'Large portion of boneless fried chicken with Korean sauce.', 'Generous serving, tender and juicy.', 'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=800&q=80', 2),
      ('Strips', cat_chicken, 180.00, 50, 'Tender crispy chicken strips with dip.', 'Perfect snack with a crunchy coating.', 'https://images.unsplash.com/photo-1614308457932-e16b9c6b0df1?auto=format&fit=crop&w=800&q=80', 3),
      ('Loaded Fries', cat_sides, 200.00, 40, 'French fries loaded with cheese, chicken and sauce.', 'Hearty, cheesy and satisfying.', 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&w=800&q=80', 4),
      ('French Fries', cat_sides, 100.00, 60, 'Classic crispy salted french fries.', 'Golden, crispy and lightly salted.', 'https://images.unsplash.com/photo-1576107232684-1279f390859f?auto=format&fit=crop&w=800&q=80', 5),
      ('Wrap', cat_wraps, 180.00, 40, 'Chicken wrap with fresh veggies and sauce.', 'Fresh, filling and easy to eat on the go.', 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?auto=format&fit=crop&w=800&q=80', 6),
      ('Burger', cat_wraps, 200.00, 40, 'Crispy chicken burger with lettuce and mayo.', 'Classic chicken burger with a juicy patty.', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=800&q=80', 7)
  )
  INSERT INTO public.products (
    name, category_id, category, price, stock, stock_quantity, stock_unit,
    description, benefits, image_url, image, unit_type, unit_label,
    base_quantity, unit, is_active, sort_order, rating, brand
  )
  SELECT
    sp.name, sp.category_id, c.name_en, sp.price, sp.stock, sp.stock, 'pc',
    sp.description, sp.benefits, sp.image_url, sp.image_url, 'unit', 'pc',
    1, '1pc', TRUE, sp.sort_order, 4.8, 'Korean Fried Chicken'
  FROM seed_products sp
  JOIN public.categories c ON c.id = sp.category_id
  WHERE TRUE
  ON CONFLICT (name) DO UPDATE
  SET category_id = EXCLUDED.category_id,
      category = EXCLUDED.category,
      price = EXCLUDED.price,
      stock = EXCLUDED.stock,
      stock_quantity = EXCLUDED.stock_quantity,
      stock_unit = EXCLUDED.stock_unit,
      unit_type = EXCLUDED.unit_type,
      unit_label = EXCLUDED.unit_label,
      base_quantity = EXCLUDED.base_quantity,
      unit = EXCLUDED.unit,
      description = EXCLUDED.description,
      benefits = EXCLUDED.benefits,
      image_url = EXCLUDED.image_url,
      image = EXCLUDED.image,
      is_active = TRUE,
      sort_order = EXCLUDED.sort_order,
      rating = EXCLUDED.rating,
      brand = EXCLUDED.brand,
      updated_at = NOW();
END $$;

-- Store settings used by invoices/receipts/fallback settings.
INSERT INTO public.store_settings (name, owner_name, phone, address, gst_enabled)
SELECT
  'Korean Fried Chicken',
  'Sulficker Roshan N',
  '9342489391',
  'Nanjappa Garden Selvapuram, Shivalaya Mahal Road, SBI Bank Opposite, Komarapalayam, Coimbatore',
  FALSE
WHERE NOT EXISTS (SELECT 1 FROM public.store_settings);

UPDATE public.store_settings
SET name = 'Korean Fried Chicken',
    owner_name = 'Sulficker Roshan N',
    phone = '9342489391',
    address = 'Nanjappa Garden Selvapuram, Shivalaya Mahal Road, SBI Bank Opposite, Komarapalayam, Coimbatore',
    gst_enabled = FALSE;

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS kfc_categories_read ON public.categories;
DROP POLICY IF EXISTS kfc_categories_manage ON public.categories;
DROP POLICY IF EXISTS categories_portal_manage ON public.categories;
CREATE POLICY kfc_categories_read
ON public.categories FOR SELECT
TO anon, authenticated
USING (TRUE);
CREATE POLICY kfc_categories_manage
ON public.categories FOR ALL
TO anon, authenticated
USING (TRUE)
WITH CHECK (TRUE);

DROP POLICY IF EXISTS kfc_products_read ON public.products;
DROP POLICY IF EXISTS kfc_products_manage ON public.products;
DROP POLICY IF EXISTS products_portal_manage ON public.products;
CREATE POLICY kfc_products_read
ON public.products FOR SELECT
TO anon, authenticated
USING (TRUE);
CREATE POLICY kfc_products_manage
ON public.products FOR ALL
TO anon, authenticated
USING (TRUE)
WITH CHECK (TRUE);

-- Billing/order backend required by the POS panel.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no TEXT UNIQUE,
  user_id UUID,
  customer_name TEXT NOT NULL DEFAULT 'Customer',
  phone TEXT,
  address TEXT,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  subtotal NUMERIC(10,2) NOT NULL DEFAULT 0,
  shipping NUMERIC(10,2) NOT NULL DEFAULT 0,
  total NUMERIC(10,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS invoice_no TEXT,
  ADD COLUMN IF NOT EXISTS user_id UUID,
  ADD COLUMN IF NOT EXISTS customer_name TEXT DEFAULT 'Customer',
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS items JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS subtotal NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS shipping NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS order_mode TEXT DEFAULT 'offline',
  ADD COLUMN IF NOT EXISTS order_type TEXT DEFAULT 'pos_sale',
  ADD COLUMN IF NOT EXISTS delivery_charge NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS manual_discount_amount NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS manual_discount_type TEXT DEFAULT 'flat',
  ADD COLUMN IF NOT EXISTS manual_discount_value NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS coupon_code TEXT,
  ADD COLUMN IF NOT EXISTS coupon_percentage NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_gst NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gst_enabled BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS split_details JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS invoice_pdf_url TEXT,
  ADD COLUMN IF NOT EXISTS invoice_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS receipt_printed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id BIGINT,
  variant_id UUID,
  product_name TEXT NOT NULL,
  name TEXT,
  product_tamil_name TEXT,
  tamil_name TEXT,
  quantity NUMERIC(10,2) NOT NULL DEFAULT 0,
  unit TEXT DEFAULT 'piece',
  unit_type TEXT DEFAULT 'unit',
  base_quantity NUMERIC(10,2) DEFAULT 1,
  base_price NUMERIC(10,2) DEFAULT 0,
  line_total NUMERIC(10,2) DEFAULT 0,
  image_url TEXT,
  is_manual BOOLEAN DEFAULT FALSE,
  discount NUMERIC(10,2) DEFAULT 0,
  gst_amount NUMERIC(10,2) DEFAULT 0,
  gst_rate NUMERIC(10,2) DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS product_id BIGINT,
  ADD COLUMN IF NOT EXISTS variant_id UUID,
  ADD COLUMN IF NOT EXISTS product_name TEXT,
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS product_tamil_name TEXT,
  ADD COLUMN IF NOT EXISTS tamil_name TEXT,
  ADD COLUMN IF NOT EXISTS quantity NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'piece',
  ADD COLUMN IF NOT EXISTS unit_type TEXT DEFAULT 'unit',
  ADD COLUMN IF NOT EXISTS base_quantity NUMERIC(10,2) DEFAULT 1,
  ADD COLUMN IF NOT EXISTS base_price NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS line_total NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS is_manual BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS discount NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gst_amount NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gst_rate NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_kfc_orders_created_at ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_kfc_orders_invoice_no ON public.orders(invoice_no);
CREATE INDEX IF NOT EXISTS idx_kfc_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_kfc_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_kfc_order_items_product_name ON public.order_items(product_name);

CREATE OR REPLACE FUNCTION public.get_next_invoice_no()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next INTEGER;
BEGIN
  SELECT COALESCE(MAX(NULLIF(regexp_replace(invoice_no, '\D', '', 'g'), '')::INTEGER), 0) + 1
  INTO v_next
  FROM public.orders
  WHERE invoice_no IS NOT NULL;

  RETURN 'KFC-' || LPAD(v_next::TEXT, 5, '0');
END;
$$;

DO $$
DECLARE
  fn RECORD;
BEGIN
  FOR fn IN
    SELECT oid::regprocedure AS signature
    FROM pg_proc
    WHERE pronamespace = 'public'::regnamespace
      AND proname = 'create_order_with_stock'
      AND prokind = 'f'
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || fn.signature;
  END LOOP;
END;
$$;

CREATE FUNCTION public.create_order_with_stock(
  p_customer_name          TEXT,
  p_phone                  TEXT,
  p_address                TEXT,
  p_items                  JSONB,
  p_shipping               NUMERIC DEFAULT 0,
  p_status                 TEXT DEFAULT 'pending',
  p_order_mode             TEXT DEFAULT 'offline',
  p_order_type             TEXT DEFAULT 'pos_sale',
  p_delivery_charge        NUMERIC DEFAULT 0,
  p_discount_amount        NUMERIC DEFAULT 0,
  p_manual_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_type   TEXT DEFAULT 'flat',
  p_manual_discount_value  NUMERIC DEFAULT 0,
  p_coupon_code            TEXT DEFAULT NULL,
  p_coupon_percentage      NUMERIC DEFAULT 0,
  p_total_gst              NUMERIC DEFAULT 0,
  p_gst_enabled            BOOLEAN DEFAULT FALSE,
  p_payment_method         TEXT DEFAULT 'cash',
  p_split_details          JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice_no TEXT;
  v_order_id UUID;
  v_subtotal NUMERIC(10,2) := 0;
  v_total NUMERIC(10,2);
  v_item JSONB;
  v_product_id BIGINT;
  v_variant_id UUID;
  v_qty NUMERIC(10,2);
BEGIN
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'At least one order item is required';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_subtotal := v_subtotal + COALESCE(NULLIF(v_item->>'line_total', '')::NUMERIC, 0);
  END LOOP;

  v_total := GREATEST(0, v_subtotal + COALESCE(p_total_gst, 0)
    + COALESCE(p_delivery_charge, 0) + COALESCE(p_shipping, 0)
    - COALESCE(p_discount_amount, 0) - COALESCE(p_manual_discount_amount, 0));

  v_invoice_no := public.get_next_invoice_no();

  INSERT INTO public.orders (
    invoice_no, user_id, customer_name, phone, address, items,
    subtotal, shipping, total, status, order_mode, order_type,
    delivery_charge, discount_amount, manual_discount_amount,
    manual_discount_type, manual_discount_value, coupon_code,
    coupon_percentage, total_gst, gst_enabled, payment_method,
    payment_mode, split_details
  ) VALUES (
    v_invoice_no, auth.uid(), COALESCE(NULLIF(TRIM(p_customer_name), ''), 'Customer'),
    COALESCE(NULLIF(TRIM(p_phone), ''), ''), COALESCE(NULLIF(TRIM(p_address), ''), ''),
    p_items, v_subtotal, COALESCE(p_shipping, 0), v_total,
    COALESCE(NULLIF(TRIM(p_status), ''), 'pending'),
    COALESCE(NULLIF(TRIM(p_order_mode), ''), 'offline'),
    COALESCE(NULLIF(TRIM(p_order_type), ''), 'pos_sale'),
    COALESCE(p_delivery_charge, 0), COALESCE(p_discount_amount, 0),
    COALESCE(p_manual_discount_amount, 0), COALESCE(NULLIF(TRIM(p_manual_discount_type), ''), 'flat'),
    COALESCE(p_manual_discount_value, 0), NULLIF(TRIM(COALESCE(p_coupon_code, '')), ''),
    COALESCE(p_coupon_percentage, 0), COALESCE(p_total_gst, 0), COALESCE(p_gst_enabled, FALSE),
    COALESCE(NULLIF(TRIM(p_payment_method), ''), 'cash'),
    COALESCE(NULLIF(TRIM(p_payment_method), ''), 'cash'), COALESCE(p_split_details, '{}'::jsonb)
  ) RETURNING id INTO v_order_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := CASE
      WHEN COALESCE(v_item->>'id', v_item->>'product_id', '') ~ '^[0-9]+$'
      THEN COALESCE(v_item->>'id', v_item->>'product_id')::BIGINT
      ELSE NULL
    END;
    v_variant_id := CASE
      WHEN COALESCE(v_item->>'variant_id', '') ~ '^[0-9a-fA-F-]{36}$'
      THEN (v_item->>'variant_id')::UUID
      ELSE NULL
    END;
    v_qty := COALESCE(NULLIF(v_item->>'quantity', '')::NUMERIC, 0);

    INSERT INTO public.order_items (
      order_id, product_id, variant_id, product_name, name,
      product_tamil_name, tamil_name, quantity, unit, unit_type,
      base_quantity, base_price, line_total, image_url, is_manual,
      discount, gst_amount, gst_rate
    ) VALUES (
      v_order_id, v_product_id, v_variant_id,
      COALESCE(NULLIF(v_item->>'name', ''), 'Product'),
      COALESCE(NULLIF(v_item->>'name', ''), 'Product'),
      NULLIF(v_item->>'tamil_name', ''), NULLIF(v_item->>'tamil_name', ''),
      v_qty, COALESCE(NULLIF(v_item->>'unit', ''), 'piece'),
      COALESCE(NULLIF(v_item->>'unit_type', ''), 'unit'),
      COALESCE(NULLIF(v_item->>'base_quantity', '')::NUMERIC, 1),
      COALESCE(NULLIF(v_item->>'base_price', '')::NUMERIC, 0),
      COALESCE(NULLIF(v_item->>'line_total', '')::NUMERIC, 0),
      NULLIF(v_item->>'image_url', ''),
      COALESCE((v_item->>'source') = 'manual', FALSE),
      COALESCE(NULLIF(v_item->>'discount', '')::NUMERIC, 0),
      COALESCE(NULLIF(v_item->>'gst_amount', '')::NUMERIC, 0),
      COALESCE(NULLIF(v_item->>'gst_rate', '')::NUMERIC, 0)
    );

    IF v_product_id IS NOT NULL THEN
      UPDATE public.products
      SET stock_quantity = GREATEST(COALESCE(stock_quantity, 0) - v_qty, 0),
          stock = GREATEST(FLOOR(COALESCE(stock_quantity, 0) - v_qty), 0)::INTEGER,
          updated_at = NOW()
      WHERE id = v_product_id;
    END IF;

    IF v_variant_id IS NOT NULL AND to_regclass('public.product_variants') IS NOT NULL THEN
      UPDATE public.product_variants
      SET stock = GREATEST(COALESCE(stock, 0) - v_qty, 0),
          updated_at = NOW()
      WHERE id = v_variant_id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('orderId', v_order_id, 'invoiceNo', v_invoice_no, 'createdAt', NOW());
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_next_invoice_no() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT,
  NUMERIC, NUMERIC, NUMERIC, TEXT, NUMERIC, TEXT, NUMERIC,
  NUMERIC, BOOLEAN, TEXT, JSONB
) TO anon, authenticated;

-- Public invoice page lookup. Customers opening /invoice/{invoice_no} do not
-- have an authenticated Supabase session, so expose only the exact requested
-- invoice through a SECURITY DEFINER function.
CREATE OR REPLACE FUNCTION public.get_public_invoice_by_number(p_invoice_no TEXT)
RETURNS SETOF public.orders
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT o.*
  FROM public.orders AS o
  WHERE o.invoice_no = NULLIF(BTRIM(p_invoice_no), '')
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_public_invoice_by_number(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_invoice_by_number(TEXT) TO anon, authenticated;

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS kfc_orders_all ON public.orders;
CREATE POLICY kfc_orders_all
ON public.orders FOR ALL
TO anon, authenticated
USING (TRUE)
WITH CHECK (TRUE);

DROP POLICY IF EXISTS kfc_order_items_all ON public.order_items;
CREATE POLICY kfc_order_items_all
ON public.order_items FOR ALL
TO anon, authenticated
USING (TRUE)
WITH CHECK (TRUE);

-- Coupon management used by the dashboard and POS checkout.
CREATE TABLE IF NOT EXISTS public.coupons (
  id BIGSERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  percentage NUMERIC(5,2) NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  expiry_date DATE,
  usage_limit INTEGER,
  usage_count INTEGER NOT NULL DEFAULT 0,
  min_order_value NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.coupons
  ADD COLUMN IF NOT EXISTS code TEXT,
  ADD COLUMN IF NOT EXISTS percentage NUMERIC(5,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS expiry_date DATE,
  ADD COLUMN IF NOT EXISTS usage_limit INTEGER,
  ADD COLUMN IF NOT EXISTS usage_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS min_order_value NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE UNIQUE INDEX IF NOT EXISTS idx_kfc_coupons_code_unique ON public.coupons (UPPER(BTRIM(code)));
CREATE INDEX IF NOT EXISTS idx_kfc_coupons_active ON public.coupons (is_active);

DROP TRIGGER IF EXISTS trg_coupons_touch_updated_at ON public.coupons;
CREATE TRIGGER trg_coupons_touch_updated_at
BEFORE UPDATE ON public.coupons
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS kfc_coupons_read ON public.coupons;
DROP POLICY IF EXISTS kfc_coupons_manage ON public.coupons;
DROP POLICY IF EXISTS coupons_admin_all ON public.coupons;
DROP POLICY IF EXISTS coupons_admin_manage ON public.coupons;
CREATE POLICY kfc_coupons_read
ON public.coupons FOR SELECT
TO anon, authenticated
USING (TRUE);
CREATE POLICY kfc_coupons_manage
ON public.coupons FOR ALL
TO anon, authenticated
USING (TRUE)
WITH CHECK (TRUE);

-- Useful verification after running:
-- SELECT name_en, is_active FROM public.categories ORDER BY sort_order, name_en;
-- SELECT name, category, price, stock, is_active FROM public.products WHERE is_active ORDER BY sort_order, name;
-- SELECT code, percentage, is_active FROM public.coupons ORDER BY created_at DESC;
