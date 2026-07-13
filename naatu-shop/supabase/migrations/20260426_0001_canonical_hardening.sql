-- Canonical migration 0001: schema/RLS hardening and index baseline
-- Safe/idempotent where possible. Run before 0002.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -------------------------------------------------------------------
-- Helpers
-- -------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin';
$$;

CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- -------------------------------------------------------------------
-- Profiles and auth bootstrap
-- -------------------------------------------------------------------

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS customer_code TEXT,
  ADD COLUMN IF NOT EXISTS name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS mobile TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'customer',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_customer_code_unique
  ON public.profiles(customer_code);

CREATE SEQUENCE IF NOT EXISTS public.customer_code_seq START WITH 1;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role TEXT;
  v_code TEXT;
  v_seq BIGINT;
BEGIN
  v_role := CASE
    WHEN NEW.email = 'admin@srisiddha.com' THEN 'admin'
    WHEN COALESCE(NEW.raw_user_meta_data->>'role', '') = 'admin' THEN 'admin'
    ELSE 'customer'
  END;

  SELECT nextval('public.customer_code_seq') INTO v_seq;
  v_code := 'CUST-' || LPAD(v_seq::TEXT, 5, '0');

  INSERT INTO public.profiles (id, customer_code, name, mobile, email, role)
  VALUES (
    NEW.id,
    v_code,
    COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''), SPLIT_PART(COALESCE(NEW.email, ''), '@', 1), 'Customer'),
    COALESCE(NEW.raw_user_meta_data->>'mobile', ''),
    NEW.email,
    v_role
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    name = COALESCE(NULLIF(public.profiles.name, ''), EXCLUDED.name),
    mobile = COALESCE(NULLIF(public.profiles.mobile, ''), EXCLUDED.mobile),
    role = public.profiles.role,
    updated_at = NOW();

  UPDATE auth.users
  SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', v_role)
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- -------------------------------------------------------------------
-- Categories/tags/products/orders compatibility columns
-- -------------------------------------------------------------------

ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.health_tags
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS category_id BIGINT REFERENCES public.categories(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS unit_type TEXT DEFAULT 'unit',
  ADD COLUMN IF NOT EXISTS unit_label TEXT DEFAULT 'piece',
  ADD COLUMN IF NOT EXISTS base_quantity NUMERIC(12,3) DEFAULT 1,
  ADD COLUMN IF NOT EXISTS stock_quantity NUMERIC(12,3) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stock_unit TEXT DEFAULT 'piece',
  ADD COLUMN IF NOT EXISTS allow_decimal_quantity BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS predefined_options JSONB DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS image_url TEXT DEFAULT '/assets/images/default-herb.jpg',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE TABLE IF NOT EXISTS public.invoice_counter (
  id INTEGER PRIMARY KEY DEFAULT 1,
  counter INTEGER NOT NULL DEFAULT 0,
  year INTEGER NOT NULL DEFAULT EXTRACT(YEAR FROM NOW())::INTEGER
);

INSERT INTO public.invoice_counter (id, counter, year)
VALUES (1, 0, EXTRACT(YEAR FROM NOW())::INTEGER)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------------------
-- Updated-at triggers
-- -------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_profiles_touch_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_touch_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS trg_categories_touch_updated_at ON public.categories;
CREATE TRIGGER trg_categories_touch_updated_at
BEFORE UPDATE ON public.categories
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS trg_health_tags_touch_updated_at ON public.health_tags;
CREATE TRIGGER trg_health_tags_touch_updated_at
BEFORE UPDATE ON public.health_tags
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS trg_products_touch_updated_at ON public.products;
CREATE TRIGGER trg_products_touch_updated_at
BEFORE UPDATE ON public.products
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS trg_orders_touch_updated_at ON public.orders;
CREATE TRIGGER trg_orders_touch_updated_at
BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- -------------------------------------------------------------------
-- RLS enable
-- -------------------------------------------------------------------

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_counter ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------
-- RLS policies (canonical)
-- -------------------------------------------------------------------

DROP POLICY IF EXISTS profiles_self_select ON public.profiles;
DROP POLICY IF EXISTS profiles_self_insert ON public.profiles;
DROP POLICY IF EXISTS profiles_self_update ON public.profiles;
DROP POLICY IF EXISTS profiles_admin_all ON public.profiles;
CREATE POLICY profiles_self_select ON public.profiles
FOR SELECT USING (auth.uid() = id);
CREATE POLICY profiles_self_insert ON public.profiles
FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY profiles_self_update ON public.profiles
FOR UPDATE USING (auth.uid() = id);
CREATE POLICY profiles_admin_all ON public.profiles
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS categories_public_read ON public.categories;
DROP POLICY IF EXISTS categories_admin_manage ON public.categories;
CREATE POLICY categories_public_read ON public.categories
FOR SELECT TO anon, authenticated USING (is_active = true);
CREATE POLICY categories_admin_manage ON public.categories
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS tags_public_read ON public.health_tags;
DROP POLICY IF EXISTS tags_admin_manage ON public.health_tags;
CREATE POLICY tags_public_read ON public.health_tags
FOR SELECT TO anon, authenticated USING (is_active = true);
CREATE POLICY tags_admin_manage ON public.health_tags
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS products_public_read ON public.products;
DROP POLICY IF EXISTS products_admin_manage ON public.products;
CREATE POLICY products_public_read ON public.products
FOR SELECT TO anon, authenticated USING (is_active = true);
CREATE POLICY products_admin_manage ON public.products
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS orders_user_select ON public.orders;
DROP POLICY IF EXISTS orders_user_insert ON public.orders;
DROP POLICY IF EXISTS orders_admin_all ON public.orders;
CREATE POLICY orders_user_select ON public.orders
FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY orders_user_insert ON public.orders
FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id OR public.is_admin());
CREATE POLICY orders_admin_all ON public.orders
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS counter_admin_read ON public.invoice_counter;
DROP POLICY IF EXISTS counter_admin_update ON public.invoice_counter;
CREATE POLICY counter_admin_read ON public.invoice_counter
FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY counter_admin_update ON public.invoice_counter
FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- -------------------------------------------------------------------
-- Invoice + stock RPCs
-- -------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_next_invoice_no()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  cur_year INTEGER := EXTRACT(YEAR FROM NOW())::INTEGER;
  cnt INTEGER;
BEGIN
  UPDATE public.invoice_counter
  SET counter = CASE WHEN year = cur_year THEN counter + 1 ELSE 1 END,
      year    = cur_year
  WHERE id = 1
  RETURNING counter INTO cnt;

  RETURN 'INV-' || cur_year || '-' || LPAD(cnt::TEXT, 6, '0');
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_next_invoice_no() TO authenticated;
REVOKE ALL ON FUNCTION public.get_next_invoice_no() FROM anon;

CREATE OR REPLACE FUNCTION public.retail_decrement_stock(
  p_product_id BIGINT,
  p_quantity NUMERIC,
  p_unit TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
    RAISE EXCEPTION 'Product not found: %', p_product_id;
  END IF;

  v_deduct := GREATEST(COALESCE(p_quantity, 0), 0);

  IF v_unit_type = 'weight' THEN
    IF LOWER(COALESCE(p_unit, v_unit_label)) = 'kg' AND LOWER(v_stock_unit) = 'g' THEN
      v_deduct := v_deduct * 1000;
    ELSIF LOWER(COALESCE(p_unit, v_unit_label)) = 'g' AND LOWER(v_stock_unit) = 'kg' THEN
      v_deduct := v_deduct / 1000;
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
$$;

GRANT EXECUTE ON FUNCTION public.retail_decrement_stock(BIGINT, NUMERIC, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.retail_decrement_stock(BIGINT, NUMERIC, TEXT) FROM anon;

-- -------------------------------------------------------------------
-- Indexes required by RLS/search
-- -------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_profiles_customer_code ON public.profiles(customer_code);
CREATE INDEX IF NOT EXISTS idx_products_name ON public.products(name);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON public.products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_sort_order ON public.products(sort_order);

CREATE INDEX IF NOT EXISTS idx_orders_invoice_no ON public.orders(invoice_no);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_phone ON public.orders(phone);

-- -------------------------------------------------------------------
-- Storage bucket/policies for product images
-- -------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE
SET public = true;

DROP POLICY IF EXISTS product_images_public_read ON storage.objects;
DROP POLICY IF EXISTS product_images_admin_insert ON storage.objects;
DROP POLICY IF EXISTS product_images_admin_update ON storage.objects;
DROP POLICY IF EXISTS product_images_admin_delete ON storage.objects;

CREATE POLICY product_images_public_read ON storage.objects
FOR SELECT TO anon, authenticated
USING (bucket_id = 'product-images');

CREATE POLICY product_images_admin_insert ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'product-images' AND public.is_admin());

CREATE POLICY product_images_admin_update ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'product-images' AND public.is_admin())
WITH CHECK (bucket_id = 'product-images' AND public.is_admin());

CREATE POLICY product_images_admin_delete ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'product-images' AND public.is_admin());
