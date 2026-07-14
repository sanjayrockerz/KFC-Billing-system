-- ============================================================
-- ZERA BILLING SYSTEM — PRODUCTION FIX SCRIPT (Safe to re-run)
-- Run this ENTIRE script in Supabase SQL Editor → New Query → Run
-- ============================================================

-- ─────────────────────────────────────────────────────────
-- 1. EXTENSIONS
-- ─────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────────────────
-- 2. HELPER FUNCTIONS
-- ─────────────────────────────────────────────────────────

-- is_admin() checks JWT app_metadata (set by trigger) OR profiles.role
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COALESCE((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin'
    OR EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    );
$$;

-- Keep app_metadata.role in sync when profiles.role changes
CREATE OR REPLACE FUNCTION public.sync_role_to_auth()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    UPDATE auth.users
    SET raw_app_meta_data =
      COALESCE(raw_app_meta_data, '{}'::jsonb) ||
      jsonb_build_object('role', NEW.role)
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_sync_role_to_auth ON public.profiles;
CREATE TRIGGER trg_sync_role_to_auth
  AFTER UPDATE OF role ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_role_to_auth();

-- ─────────────────────────────────────────────────────────
-- 3. SCHEMA PATCHES — Add all missing columns safely
-- ─────────────────────────────────────────────────────────

-- categories
DO $$ BEGIN
  BEGIN ALTER TABLE public.categories ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.categories ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.categories ADD COLUMN name_ta TEXT NOT NULL DEFAULT ''; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.categories ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW(); EXCEPTION WHEN duplicate_column THEN END;
END $$;

-- products — all ZERA POS fields
DO $$ BEGIN
  BEGIN ALTER TABLE public.products ADD COLUMN category_id BIGINT REFERENCES public.categories(id) ON DELETE SET NULL; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN name_ta TEXT DEFAULT ''; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN tamil_name TEXT DEFAULT ''; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN remedy TEXT[] DEFAULT '{}'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN offer_price NUMERIC(10,2); EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN unit_type TEXT DEFAULT 'unit'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN unit_label TEXT DEFAULT 'piece'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN base_quantity NUMERIC(12,3) DEFAULT 1; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN stock_quantity NUMERIC(12,3) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN stock_unit TEXT DEFAULT 'piece'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN allow_decimal_quantity BOOLEAN DEFAULT false; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN predefined_options JSONB DEFAULT '[]'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN is_active BOOLEAN DEFAULT true; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN sort_order INTEGER DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN unit TEXT DEFAULT '100g'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN rating NUMERIC(3,1) DEFAULT 4.7; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN description_ta TEXT DEFAULT ''; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN benefits_ta TEXT DEFAULT ''; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN image_url TEXT DEFAULT '/assets/images/default-herb.jpg'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN has_variants BOOLEAN DEFAULT false; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW(); EXCEPTION WHEN duplicate_column THEN END;
  -- ZERA POS extra fields
  BEGIN ALTER TABLE public.products ADD COLUMN sku TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN barcode TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN brand TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN purchase_price NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN mrp NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN gst_percent NUMERIC(5,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN opening_stock NUMERIC(12,3) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN low_stock_alert NUMERIC(12,3) DEFAULT 5; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN supplier TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN size TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN color TEXT; EXCEPTION WHEN duplicate_column THEN END;
END $$;

-- orders — all ZERA POS + dashboard required fields
DO $$ BEGIN
  BEGIN ALTER TABLE public.orders ADD COLUMN order_mode TEXT DEFAULT 'offline'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN order_type TEXT DEFAULT 'pos_sale'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN coupon_code TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN coupon_percentage NUMERIC(5,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN discount_amount NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN manual_discount_amount NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN manual_discount_type TEXT DEFAULT 'flat'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN manual_discount_value NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN delivery_charge NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN total_gst NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN gst_amount NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN gst_enabled BOOLEAN DEFAULT false; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN payment_mode TEXT DEFAULT 'cash'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN payment_method TEXT DEFAULT 'cash'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN split_details JSONB DEFAULT '{}'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN invoice_pdf_url TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW(); EXCEPTION WHEN duplicate_column THEN END;
END $$;

-- order_items — all required fields
CREATE TABLE IF NOT EXISTS public.order_items (
  id                  BIGSERIAL PRIMARY KEY,
  order_id            UUID          NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id          BIGINT        REFERENCES public.products(id) ON DELETE SET NULL,
  product_name        TEXT          NOT NULL DEFAULT 'Product',
  product_tamil_name  TEXT,
  quantity            NUMERIC(12,3) NOT NULL DEFAULT 0,
  unit                TEXT          NOT NULL DEFAULT 'piece',
  unit_type           TEXT          NOT NULL DEFAULT 'unit',
  base_quantity       NUMERIC(12,3) NOT NULL DEFAULT 1,
  base_price          NUMERIC(10,2) NOT NULL DEFAULT 0,
  line_total          NUMERIC(10,2) NOT NULL DEFAULT 0,
  image_url           TEXT,
  is_manual           BOOLEAN DEFAULT false,
  created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
DO $$ BEGIN
  BEGIN ALTER TABLE public.order_items ADD COLUMN is_manual BOOLEAN DEFAULT false; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.order_items ADD COLUMN product_name TEXT NOT NULL DEFAULT 'Product'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.order_items ADD COLUMN variant_id UUID REFERENCES public.product_variants(id) ON DELETE SET NULL; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.order_items ADD COLUMN name TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.order_items ADD COLUMN tamil_name TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.order_items ADD COLUMN discount NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.order_items ADD COLUMN gst_amount NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.order_items ADD COLUMN gst_rate NUMERIC(5,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
EXCEPTION WHEN undefined_table THEN
  -- variant table not yet created, skip variant_id FK
  BEGIN ALTER TABLE public.order_items ADD COLUMN is_manual BOOLEAN DEFAULT false; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.order_items ADD COLUMN product_name TEXT NOT NULL DEFAULT 'Product'; EXCEPTION WHEN duplicate_column THEN END;
END $$;

-- product_variants table
CREATE TABLE IF NOT EXISTS public.product_variants (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id    BIGINT REFERENCES public.products(id) ON DELETE CASCADE,
  variant_name  TEXT NOT NULL DEFAULT '',
  size_label    TEXT,
  sku           TEXT,
  barcode       TEXT,
  purchase_price NUMERIC(10,2) DEFAULT 0,
  mrp           NUMERIC(10,2) DEFAULT 0,
  price         NUMERIC(10,2) NOT NULL DEFAULT 0,
  stock         NUMERIC(12,3) DEFAULT 0,
  weight_value  NUMERIC(12,3),
  weight_unit   TEXT,
  is_default    BOOLEAN DEFAULT false,
  is_active     BOOLEAN DEFAULT true,
  sort_order    INTEGER DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- store_settings table
CREATE TABLE IF NOT EXISTS public.store_settings (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL DEFAULT 'ZERA',
  owner_name  TEXT DEFAULT '',
  phone       TEXT DEFAULT '',
  address     TEXT DEFAULT '',
  gst_enabled BOOLEAN DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO public.store_settings (name, owner_name, phone, address, gst_enabled)
SELECT 'ZERA', 'Sulficker Roshan N', '9342489391', 'ZERA, Kurinji Nagar, Brindhavan Circle, Kuniyamuthur', false
WHERE NOT EXISTS (SELECT 1 FROM public.store_settings);

-- coupons table
CREATE TABLE IF NOT EXISTS public.coupons (
  id              BIGSERIAL PRIMARY KEY,
  code            TEXT NOT NULL UNIQUE,
  percentage      NUMERIC(5,2) NOT NULL DEFAULT 0,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  expiry_date     DATE,
  usage_limit     INTEGER,
  usage_count     INTEGER NOT NULL DEFAULT 0,
  min_order_value NUMERIC(10,2) DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- invoice_counter table
CREATE TABLE IF NOT EXISTS public.invoice_counter (
  id      INTEGER PRIMARY KEY DEFAULT 1,
  counter INTEGER NOT NULL DEFAULT 0,
  year    INTEGER NOT NULL DEFAULT EXTRACT(YEAR FROM NOW())::INTEGER
);
INSERT INTO public.invoice_counter (id, counter, year)
  VALUES (1, 0, EXTRACT(YEAR FROM NOW())::INTEGER)
ON CONFLICT (id) DO NOTHING;

-- ─────────────────────────────────────────────────────────
-- 4. ROW LEVEL SECURITY — Disable for admin bypass tables
-- ─────────────────────────────────────────────────────────
ALTER TABLE public.products        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_settings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupons         ENABLE ROW LEVEL SECURITY;

-- products
DROP POLICY IF EXISTS products_anon_read    ON public.products;
DROP POLICY IF EXISTS products_admin_manage ON public.products;
DROP POLICY IF EXISTS "Enable all access for all users" ON public.products;
CREATE POLICY products_anon_read    ON public.products FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY products_admin_manage ON public.products FOR ALL    TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- categories
DROP POLICY IF EXISTS categories_anon_read    ON public.categories;
DROP POLICY IF EXISTS categories_admin_manage ON public.categories;
CREATE POLICY categories_anon_read    ON public.categories FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY categories_admin_manage ON public.categories FOR ALL    TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- orders
DROP POLICY IF EXISTS orders_user_select ON public.orders;
DROP POLICY IF EXISTS orders_user_insert ON public.orders;
DROP POLICY IF EXISTS orders_anon_insert ON public.orders;
DROP POLICY IF EXISTS orders_admin_all   ON public.orders;
CREATE POLICY orders_user_select ON public.orders FOR SELECT TO authenticated USING (auth.uid() = user_id OR public.is_admin());
CREATE POLICY orders_user_insert ON public.orders FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() OR user_id IS NULL OR public.is_admin());
CREATE POLICY orders_anon_insert ON public.orders FOR INSERT TO anon          WITH CHECK (user_id IS NULL);
CREATE POLICY orders_admin_all   ON public.orders FOR ALL    TO authenticated USING (public.is_admin());

-- order_items
DROP POLICY IF EXISTS order_items_user_select ON public.order_items;
DROP POLICY IF EXISTS order_items_user_insert ON public.order_items;
DROP POLICY IF EXISTS order_items_admin_all   ON public.order_items;
CREATE POLICY order_items_user_select ON public.order_items FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_items.order_id AND (o.user_id = auth.uid() OR public.is_admin()))
);
CREATE POLICY order_items_user_insert ON public.order_items FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_items.order_id AND (o.user_id = auth.uid() OR public.is_admin()))
);
CREATE POLICY order_items_admin_all ON public.order_items FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- product_variants
DROP POLICY IF EXISTS product_variants_read   ON public.product_variants;
DROP POLICY IF EXISTS product_variants_manage ON public.product_variants;
CREATE POLICY product_variants_read   ON public.product_variants FOR SELECT TO anon, authenticated USING (is_active = true);
CREATE POLICY product_variants_manage ON public.product_variants FOR ALL    TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- store_settings
DROP POLICY IF EXISTS store_settings_read   ON public.store_settings;
DROP POLICY IF EXISTS store_settings_manage ON public.store_settings;
CREATE POLICY store_settings_read   ON public.store_settings FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY store_settings_manage ON public.store_settings FOR ALL    TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- coupons
DROP POLICY IF EXISTS coupons_admin_all ON public.coupons;
DROP POLICY IF EXISTS coupons_auth_read ON public.coupons;
CREATE POLICY coupons_admin_all ON public.coupons FOR ALL    TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY coupons_auth_read ON public.coupons FOR SELECT TO authenticated USING (is_active = true OR public.is_admin());

-- ─────────────────────────────────────────────────────────
-- 5. STORAGE BUCKETS — invoices & product-images
-- ─────────────────────────────────────────────────────────

-- invoices bucket (public read, authenticated upload — no admin-only check)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('invoices', 'invoices', true, 5242880, ARRAY['application/pdf'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- product-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('product-images', 'product-images', true, 5242880)
ON CONFLICT (id) DO NOTHING;

-- Drop old restrictive storage policies
DROP POLICY IF EXISTS invoices_public_read     ON storage.objects;
DROP POLICY IF EXISTS invoices_admin_upload    ON storage.objects;
DROP POLICY IF EXISTS invoices_admin_update    ON storage.objects;
DROP POLICY IF EXISTS invoices_admin_delete    ON storage.objects;
DROP POLICY IF EXISTS product_images_public_read   ON storage.objects;
DROP POLICY IF EXISTS product_images_auth_upload   ON storage.objects;

-- invoices: anyone can read, any authenticated user can upload (POS billing)
CREATE POLICY invoices_public_read ON storage.objects
  FOR SELECT USING (bucket_id = 'invoices');

CREATE POLICY invoices_auth_upload ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'invoices');

CREATE POLICY invoices_auth_update ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'invoices') WITH CHECK (bucket_id = 'invoices');

CREATE POLICY invoices_auth_delete ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'invoices');

-- product images: public read, authenticated upload
CREATE POLICY product_images_public_read ON storage.objects
  FOR SELECT USING (bucket_id = 'product-images');

CREATE POLICY product_images_auth_upload ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product-images');

-- ─────────────────────────────────────────────────────────
-- 6. get_next_invoice_no  (idempotent)
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_next_invoice_no()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  cur_year INTEGER := EXTRACT(YEAR FROM NOW())::INTEGER;
  cnt      INTEGER;
BEGIN
  INSERT INTO public.invoice_counter (id, counter, year)
  VALUES (1, 1, cur_year)
  ON CONFLICT (id) DO UPDATE
    SET counter = CASE
          WHEN invoice_counter.year = cur_year THEN invoice_counter.counter + 1
          ELSE 1
        END,
        year = cur_year
  RETURNING counter INTO cnt;
  RETURN 'INV-' || cur_year || '-' || LPAD(cnt::TEXT, 4, '0');
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_next_invoice_no() TO authenticated, anon;

-- ─────────────────────────────────────────────────────────
-- 7. create_order_with_stock — FULL ZERA POS version
-- ─────────────────────────────────────────────────────────
-- Remove every historical overload before creating the
-- canonical signature below. The old migrations used two different orders
-- for the final GST/payment parameters, making named Supabase RPC calls
-- ambiguous.
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

DROP FUNCTION IF EXISTS public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT,
  NUMERIC, NUMERIC, NUMERIC, TEXT, NUMERIC, TEXT, NUMERIC,
  TEXT, JSONB, BOOLEAN
);
DROP FUNCTION IF EXISTS public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT,
  NUMERIC, NUMERIC, NUMERIC, TEXT, NUMERIC, TEXT, NUMERIC,
  BOOLEAN, TEXT, JSONB
);

CREATE OR REPLACE FUNCTION public.create_order_with_stock(
  p_customer_name          TEXT,
  p_phone                  TEXT,
  p_address                TEXT,
  p_items                  JSONB,
  p_shipping               NUMERIC  DEFAULT 0,
  p_status                 TEXT     DEFAULT 'pending',
  p_order_mode             TEXT     DEFAULT 'offline',
  p_order_type             TEXT     DEFAULT 'pos_sale',
  p_delivery_charge        NUMERIC  DEFAULT 0,
  p_discount_amount        NUMERIC  DEFAULT 0,
  p_manual_discount_amount NUMERIC  DEFAULT 0,
  p_manual_discount_type   TEXT     DEFAULT 'flat',
  p_manual_discount_value  NUMERIC  DEFAULT 0,
  p_coupon_code            TEXT     DEFAULT NULL,
  p_coupon_percentage      NUMERIC  DEFAULT 0,
  p_total_gst              NUMERIC  DEFAULT 0,
  p_gst_enabled            BOOLEAN  DEFAULT false,
  p_payment_method         TEXT     DEFAULT 'cash',
  p_split_details          JSONB    DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requester  UUID   := auth.uid();
  v_invoice_no TEXT;
  v_order_id   UUID;
  v_subtotal   NUMERIC(10,2) := 0;
  v_effective_discount NUMERIC;
  v_total      NUMERIC(10,2);
  v_item       JSONB;
  v_product_id BIGINT;
  v_variant_id UUID;
  v_order_type TEXT;
BEGIN
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'At least one order item is required';
  END IF;

  -- Resolve order type
  v_order_type := COALESCE(NULLIF(TRIM(p_order_type), ''), 'pos_sale');

  -- Calculate subtotal
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_subtotal := v_subtotal + COALESCE((v_item->>'line_total')::NUMERIC, 0);
  END LOOP;

  -- Calculate total
  v_effective_discount := COALESCE(p_discount_amount, 0) + COALESCE(p_manual_discount_amount, 0);
  v_total := v_subtotal + COALESCE(p_total_gst, 0) - v_effective_discount
             + COALESCE(p_delivery_charge, 0) + COALESCE(p_shipping, 0);
  IF v_total < 0 THEN v_total := 0; END IF;

  -- Generate invoice number
  v_invoice_no := public.get_next_invoice_no();

  -- Insert order
  INSERT INTO public.orders (
    invoice_no, user_id, customer_name, phone, address,
    items, subtotal, shipping, total, status,
    order_mode, order_type, delivery_charge,
    discount_amount, manual_discount_amount, manual_discount_type, manual_discount_value,
    coupon_code, coupon_percentage, total_gst, gst_enabled,
    payment_method, payment_mode, split_details
  ) VALUES (
    v_invoice_no,
    v_requester,
    COALESCE(NULLIF(TRIM(p_customer_name), ''), 'Customer'),
    COALESCE(NULLIF(TRIM(p_phone), ''), ''),
    COALESCE(NULLIF(TRIM(p_address), ''), ''),
    p_items,
    v_subtotal,
    COALESCE(p_shipping, 0),
    v_total,
    COALESCE(NULLIF(TRIM(p_status), ''), 'pending'),
    COALESCE(NULLIF(TRIM(p_order_mode), ''), 'offline'),
    v_order_type,
    COALESCE(p_delivery_charge, 0),
    COALESCE(p_discount_amount, 0),
    COALESCE(p_manual_discount_amount, 0),
    COALESCE(NULLIF(TRIM(p_manual_discount_type), ''), 'flat'),
    COALESCE(p_manual_discount_value, 0),
    NULLIF(TRIM(COALESCE(p_coupon_code, '')), ''),
    COALESCE(p_coupon_percentage, 0),
    COALESCE(p_total_gst, 0),
    COALESCE(p_gst_enabled, false),
    COALESCE(NULLIF(TRIM(p_payment_method), ''), 'cash'),
    COALESCE(NULLIF(TRIM(p_payment_method), ''), 'cash'),
    COALESCE(p_split_details, '{}')
  ) RETURNING id INTO v_order_id;

  -- Insert order items and decrement stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := NULLIF(COALESCE(v_item->>'id', v_item->>'product_id'), '')::BIGINT;
    v_variant_id := NULLIF(v_item->>'variant_id', '')::UUID;

    INSERT INTO public.order_items (
      order_id, product_id, variant_id,
      product_name, name, product_tamil_name, tamil_name,
      quantity, unit, unit_type, base_quantity, base_price, line_total, image_url,
      is_manual, discount, gst_amount, gst_rate
    ) VALUES (
      v_order_id,
      v_product_id,
      v_variant_id,
      COALESCE(NULLIF(v_item->>'name', ''), 'Product'),
      COALESCE(NULLIF(v_item->>'name', ''), 'Product'),
      NULLIF(v_item->>'tamil_name', ''),
      NULLIF(v_item->>'tamil_name', ''),
      COALESCE((v_item->>'quantity')::NUMERIC, 0),
      COALESCE(NULLIF(v_item->>'unit', ''), 'piece'),
      COALESCE(NULLIF(v_item->>'unit_type', ''), 'unit'),
      COALESCE((v_item->>'base_quantity')::NUMERIC, 1),
      COALESCE((v_item->>'base_price')::NUMERIC, 0),
      COALESCE((v_item->>'line_total')::NUMERIC, 0),
      NULLIF(v_item->>'image_url', ''),
      COALESCE((v_item->>'source')::TEXT = 'manual', false),
      COALESCE((v_item->>'discount')::NUMERIC, 0),
      COALESCE((v_item->>'gst_amount')::NUMERIC, 0),
      COALESCE((v_item->>'gst_rate')::NUMERIC, 0)
    );

    -- Decrement product stock
    IF v_product_id IS NOT NULL THEN
      UPDATE public.products
      SET
        stock_quantity = GREATEST(COALESCE(stock_quantity, 0) - COALESCE((v_item->>'quantity')::NUMERIC, 0), 0),
        stock          = GREATEST(FLOOR(COALESCE(stock_quantity, 0) - COALESCE((v_item->>'quantity')::NUMERIC, 0)), 0)::INTEGER,
        updated_at     = NOW()
      WHERE id = v_product_id;
    END IF;

    -- Decrement variant stock
    IF v_variant_id IS NOT NULL THEN
      UPDATE public.product_variants
      SET stock = GREATEST(COALESCE(stock, 0) - COALESCE((v_item->>'quantity')::NUMERIC, 0), 0),
          updated_at = NOW()
      WHERE id = v_variant_id;
    END IF;

    -- Increment coupon usage_count
    IF p_coupon_code IS NOT NULL AND TRIM(p_coupon_code) <> '' THEN
      UPDATE public.coupons
      SET usage_count = usage_count + 1
      WHERE code = UPPER(TRIM(p_coupon_code));
    END IF;

  END LOOP;

  RETURN jsonb_build_object(
    'orderId',    v_order_id,
    'invoiceNo',  v_invoice_no,
    'createdAt',  NOW()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_order_with_stock(
  TEXT,TEXT,TEXT,JSONB,NUMERIC,TEXT,TEXT,TEXT,NUMERIC,NUMERIC,NUMERIC,TEXT,NUMERIC,TEXT,NUMERIC,NUMERIC,BOOLEAN,TEXT,JSONB
) TO authenticated, anon;

-- ─────────────────────────────────────────────────────────
-- 8. Sequence grants
-- ─────────────────────────────────────────────────────────
DO $$
BEGIN
  EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE public.products_id_seq TO authenticated, anon';
EXCEPTION WHEN undefined_table THEN NULL;
END $$;
DO $$
BEGIN
  EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE public.categories_id_seq TO authenticated, anon';
EXCEPTION WHEN undefined_table THEN NULL;
END $$;
DO $$
BEGIN
  EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE public.order_items_id_seq TO authenticated, anon';
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- ─────────────────────────────────────────────────────────
-- 9. Reload PostgREST schema cache
-- ─────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';

-- ─────────────────────────────────────────────────────────
-- 10. Set admin role for known admin email (update if needed)
-- ─────────────────────────────────────────────────────────
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'your-admin@email.com';
-- UPDATE auth.users SET raw_app_meta_data = raw_app_meta_data || '{"role":"admin"}'::jsonb WHERE email = 'your-admin@email.com';
