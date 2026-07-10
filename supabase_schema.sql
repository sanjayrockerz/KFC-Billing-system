-- =====================================================================
-- Thirupathi Balaji Herbal Store — COMPLETE SCHEMA  (v4 – safe to re-run)
-- Run this ENTIRE script in Supabase SQL Editor
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════════════════
-- 1. PROFILES
--    • customer_code  → sequential readable ID  e.g. CUST-00042
--    • NO recursive RLS — admin check uses auth.jwt() metadata, not profiles
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  customer_code TEXT UNIQUE,
  name          TEXT NOT NULL DEFAULT '',
  mobile        TEXT DEFAULT '',
  email         TEXT,
  role          TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('admin','customer')),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Helper to safely add missing columns if the table already existed
DO $$ 
BEGIN
  BEGIN ALTER TABLE public.profiles ADD COLUMN customer_code TEXT UNIQUE; EXCEPTION WHEN duplicate_column THEN END;
END $$;

-- Customer code sequence
CREATE SEQUENCE IF NOT EXISTS public.customer_code_seq START WITH 1;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop ALL old policies first
DROP POLICY IF EXISTS "profiles_self_select"  ON public.profiles;
DROP POLICY IF EXISTS "profiles_self_insert"  ON public.profiles;
DROP POLICY IF EXISTS "profiles_self_update"  ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_all"    ON public.profiles;

-- Simple, NON-recursive policies
-- Users can always read/update their own row
CREATE POLICY "profiles_self_select" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles_self_insert" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_self_update" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Admin: we read role from JWT app_metadata (set by a DB trigger below)
-- This avoids querying profiles table from within profiles RLS
CREATE POLICY "profiles_admin_all" ON public.profiles
  FOR ALL USING (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin'
  );


-- ── Trigger: auto-create profile + assign customer_code ──────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_role TEXT;
  v_code TEXT;
  v_seq  BIGINT;
BEGIN
  v_role := CASE
    WHEN NEW.email = 'admin@srisiddha.com' THEN 'admin'
    WHEN coalesce(NEW.raw_user_meta_data->>'role','') = 'admin' THEN 'admin'
    ELSE 'customer'
  END;

  SELECT nextval('public.customer_code_seq') INTO v_seq;
  v_code := 'CUST-' || LPAD(v_seq::TEXT, 5, '0');

  INSERT INTO public.profiles (id, customer_code, name, mobile, email, role)
  VALUES (
    NEW.id,
    v_code,
    coalesce(nullif(trim(NEW.raw_user_meta_data->>'name'),''), split_part(coalesce(NEW.email,''), '@', 1), 'Customer'),
    coalesce(NEW.raw_user_meta_data->>'mobile', ''),
    NEW.email,
    v_role
  )
  ON CONFLICT (id) DO NOTHING;

  -- Stamp role in app_metadata so JWT carries it (used by RLS)
  UPDATE auth.users
    SET raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', v_role)
    WHERE id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ── Backfill existing profiles that have no customer_code ─────────────
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.profiles WHERE customer_code IS NULL LOOP
    UPDATE public.profiles
      SET customer_code = 'CUST-' || LPAD(nextval('public.customer_code_seq')::TEXT, 5, '0')
      WHERE id = r.id;
  END LOOP;
END $$;

-- ── Make sure admin profile has correct role ───────────────────────────
UPDATE public.profiles SET role = 'admin'
  WHERE email = 'admin@srisiddha.com';

UPDATE auth.users
  SET raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb) || '{"role":"admin"}'::jsonb
  WHERE email = 'admin@srisiddha.com';


-- ═══════════════════════════════════════════════════════════════════════
-- 2. CATEGORIES
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.categories (
  id         BIGSERIAL PRIMARY KEY,
  name_en    TEXT NOT NULL UNIQUE,
  name_ta    TEXT NOT NULL DEFAULT '',
  is_active  BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "categories_anon_read"    ON public.categories;
DROP POLICY IF EXISTS "categories_admin_manage" ON public.categories;

CREATE POLICY "categories_anon_read" ON public.categories
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "categories_admin_manage" ON public.categories
  FOR ALL USING (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin'
  );

-- Helper to safely add missing columns if upgrading
DO $$ 
BEGIN
  BEGIN ALTER TABLE public.categories ADD COLUMN name_ta TEXT NOT NULL DEFAULT ''; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.categories ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.categories ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW(); EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.categories ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW(); EXCEPTION WHEN duplicate_column THEN END;
END $$;

INSERT INTO public.categories (name_en, name_ta, sort_order) VALUES
  ('Herbal Powder',  'மூலிகை பொடி',         1),
  ('Herbal Oil',     'மூலிகை எண்ணெய்',      2),
  ('Herbal Root',    'மூலிகை வேர்',          3),
  ('Herbal Spice',   'மூலிகை மசாலா',        4),
  ('Herbal Gel',     'மூலிகை ஜெல்',         5),
  ('Mineral Herb',   'தாது மூலிகை',          6),
  ('Herbal Tablet',  'மூலிகை மாத்திரை',     7),
  ('Herbal Leaf',    'மூலிகை இலை',          8),
  ('Herbal Product', 'மூலிகை பொருள்',       9)
ON CONFLICT (name_en) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════
-- 3. HEALTH TAGS
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.health_tags (
  id         BIGSERIAL PRIMARY KEY,
  name_en    TEXT NOT NULL UNIQUE,
  name_ta    TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.health_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tags_anon_read"    ON public.health_tags;
DROP POLICY IF EXISTS "tags_admin_manage" ON public.health_tags;

CREATE POLICY "tags_anon_read" ON public.health_tags
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "tags_admin_manage" ON public.health_tags
  FOR ALL USING (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin'
  );

-- Helper to safely add missing columns if upgrading
DO $$ 
BEGIN
  BEGIN ALTER TABLE public.health_tags ADD COLUMN name_ta TEXT NOT NULL DEFAULT ''; EXCEPTION WHEN duplicate_column THEN END;
END $$;

INSERT INTO public.health_tags (name_en, name_ta) VALUES
  ('Cold & Cough',  'சளி மற்றும் இருமல்'),
  ('Digestion',     'செரிமானம்'),
  ('Hair Growth',   'முடி வளர்ச்சி'),
  ('Immunity',      'நோய் எதிர்ப்பு சக்தி'),
  ('Skin Care',     'சரும பராமரிப்பு'),
  ('Stress',        'மன அழுத்தம்'),
  ('Fever',         'காய்ச்சல்'),
  ('Joint Pain',    'மூட்டு வலி'),
  ('Diabetes',      'நீரிழிவு'),
  ('Weight Loss',   'எடை குறைப்பு')
ON CONFLICT (name_en) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════
-- 4. PRODUCTS  (with retail complexity columns)
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.products (
  id             BIGSERIAL PRIMARY KEY,
  name           TEXT NOT NULL,
  name_ta        TEXT DEFAULT '',
  tamil_name     TEXT DEFAULT '',
  category       TEXT NOT NULL DEFAULT 'Herbal Product',
  category_id    BIGINT REFERENCES public.categories(id) ON DELETE SET NULL,
  remedy         TEXT[] DEFAULT '{}',
  price          NUMERIC(10,2) NOT NULL DEFAULT 0,
  offer_price    NUMERIC(10,2),
  unit_type      TEXT NOT NULL DEFAULT 'unit' CHECK (unit_type IN ('unit','weight','volume','bundle')),
  unit_label     TEXT NOT NULL DEFAULT 'piece',
  base_quantity  NUMERIC(12,3) NOT NULL DEFAULT 1,
  stock_quantity NUMERIC(12,3) NOT NULL DEFAULT 0,
  stock_unit     TEXT DEFAULT 'piece',
  allow_decimal_quantity BOOLEAN NOT NULL DEFAULT false,
  predefined_options JSONB NOT NULL DEFAULT '[]',
  description    TEXT DEFAULT '',
  description_ta TEXT DEFAULT '',
  benefits       TEXT DEFAULT '',
  benefits_ta    TEXT DEFAULT '',
  image          TEXT DEFAULT '/assets/images/default-herb.jpg',
  image_url      TEXT DEFAULT '/assets/images/default-herb.jpg',
  stock          INTEGER NOT NULL DEFAULT 0,
  unit           TEXT DEFAULT '100g',
  rating         NUMERIC(3,1) DEFAULT 4.7,
  is_active      BOOLEAN NOT NULL DEFAULT true,
  sort_order     INTEGER NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "products_anon_read"    ON public.products;
DROP POLICY IF EXISTS "products_admin_manage" ON public.products;

CREATE POLICY "products_anon_read" ON public.products
  FOR SELECT TO anon, authenticated USING (is_active = true);

CREATE POLICY "products_admin_manage" ON public.products
  FOR ALL USING (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin'
  );

-- Helper to add missing columns if upgrading from old schema
DO $$ 
BEGIN
  BEGIN ALTER TABLE public.products ADD COLUMN tamil_name TEXT DEFAULT ''; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN unit_type TEXT NOT NULL DEFAULT 'unit'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN unit_label TEXT NOT NULL DEFAULT 'piece'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN base_quantity NUMERIC(12,3) NOT NULL DEFAULT 1; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN stock_quantity NUMERIC(12,3) NOT NULL DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN stock_unit TEXT DEFAULT 'piece'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN allow_decimal_quantity BOOLEAN NOT NULL DEFAULT false; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN predefined_options JSONB NOT NULL DEFAULT '[]'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN image_url TEXT DEFAULT '/assets/images/default-herb.jpg'; EXCEPTION WHEN duplicate_column THEN END;
END $$;



-- ═══════════════════════════════════════════════════════════════════════
-- 5. ORDERS
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.orders (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  invoice_no    TEXT NOT NULL UNIQUE,
  user_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  customer_name TEXT NOT NULL,
  phone         TEXT NOT NULL DEFAULT '',
  address       TEXT NOT NULL DEFAULT '',
  items         JSONB NOT NULL DEFAULT '[]',
  subtotal      NUMERIC(10,2) NOT NULL DEFAULT 0,
  shipping      NUMERIC(10,2) NOT NULL DEFAULT 0,
  total         NUMERIC(10,2) NOT NULL DEFAULT 0,
  status        TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','processing','completed','cancelled')),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "orders_user_select" ON public.orders;
DROP POLICY IF EXISTS "orders_user_insert" ON public.orders;
DROP POLICY IF EXISTS "orders_anon_insert" ON public.orders;
DROP POLICY IF EXISTS "orders_admin_all"   ON public.orders;

CREATE POLICY "orders_user_select" ON public.orders
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "orders_user_insert" ON public.orders
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "orders_anon_insert" ON public.orders
  FOR INSERT TO anon WITH CHECK (user_id IS NULL);

CREATE POLICY "orders_admin_all" ON public.orders
  FOR ALL USING (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin'
  );


-- ═══════════════════════════════════════════════════════════════════════
-- 6. INVOICE COUNTER
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.invoice_counter (
  id      INTEGER PRIMARY KEY DEFAULT 1,
  counter INTEGER NOT NULL DEFAULT 0,
  year    INTEGER NOT NULL DEFAULT EXTRACT(YEAR FROM NOW())::INTEGER
);
ALTER TABLE public.invoice_counter ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "counter_read"   ON public.invoice_counter;
DROP POLICY IF EXISTS "counter_update" ON public.invoice_counter;

CREATE POLICY "counter_read"   ON public.invoice_counter
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "counter_update" ON public.invoice_counter
  FOR UPDATE TO anon, authenticated USING (true);

INSERT INTO public.invoice_counter (id, counter, year)
  VALUES (1, 0, EXTRACT(YEAR FROM NOW())::INTEGER)
ON CONFLICT (id) DO NOTHING;

-- Atomic invoice number generator
CREATE OR REPLACE FUNCTION public.get_next_invoice_no()
RETURNS TEXT AS $$
DECLARE
  cur_year INTEGER := EXTRACT(YEAR FROM NOW())::INTEGER;
  cnt INTEGER;
BEGIN
  UPDATE public.invoice_counter
  SET counter = CASE WHEN year = cur_year THEN counter + 1 ELSE 1 END,
      year    = cur_year
  WHERE id = 1
  RETURNING counter INTO cnt;

  RETURN 'INV-' || cur_year || '-' || LPAD(cnt::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_next_invoice_no() TO anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════════
-- 7. STOCK DECREMENT  (simple integer)
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.decrement_stock(product_id BIGINT, qty_sold INTEGER)
RETURNS void AS $$
BEGIN
  UPDATE public.products
  SET stock      = GREATEST(0, stock - qty_sold),
      updated_at = NOW()
  WHERE id = product_id AND is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.decrement_stock(BIGINT, INTEGER) TO anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════════
-- 8. SEED MOCK PRODUCTS (61 Full Items for Dashboard)
-- ═══════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF (SELECT COUNT(*) FROM public.products) < 60 THEN
    DELETE FROM public.products;
    
    INSERT INTO public.products (
      name, name_ta, tamil_name, category, category_id, remedy, price, offer_price, description, 
      benefits, image, image_url, stock, stock_quantity, stock_unit, unit, unit_type, unit_label, base_quantity, allow_decimal_quantity
    ) VALUES
    ('Amukkara Chooranam', 'அமுக்கரா சூரணம்', 'அமுக்கரா சூரணம்', 'Herbal Powder', 1, ARRAY['Stress', 'Immunity'], 150, 140, 'Premium Herbal Powder formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Stress and Immunity.', 'Naturally targets Stress, Immunity while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Nilavembu Kudineer', 'நிலவேம்பு குடிநீர்', 'நிலவேம்பு குடிநீர்', 'Herbal Powder', 1, ARRAY['Fever', 'Immunity'], 120, 110, 'Premium Herbal Powder formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Fever and Immunity.', 'Naturally targets Fever, Immunity while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Kaba Sura Kudineer', 'கபசுர குடிநீர்', 'கபசுர குடிநீர்', 'Herbal Powder', 1, ARRAY['Cold & Cough', 'Fever'], 130, 120, 'Premium Herbal Powder formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Cold & Cough and Fever.', 'Naturally targets Cold & Cough, Fever while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Thoothuvalai Podi', 'தூதுவளை பொடி', 'தூதுவளை பொடி', 'Herbal Powder', 1, ARRAY['Cold & Cough', 'Immunity'], 110, 100, 'Premium Herbal Powder formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Cold & Cough and Immunity.', 'Naturally targets Cold & Cough, Immunity while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Karisalanganni Podi', 'கரிசலாங்கண்ணி பொடி', 'கரிசலாங்கண்ணி பொடி', 'Herbal Powder', 1, ARRAY['Hair Growth', 'Digestion'], 140, 130, 'Premium Herbal Powder formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Hair Growth and Digestion.', 'Naturally targets Hair Growth, Digestion while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Vasambu Podi', 'வசம்பு பொடி', 'வசம்பு பொடி', 'Herbal Powder', 1, ARRAY['Digestion', 'Immunity'], 80, NULL, 'Premium Herbal Powder formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Digestion and Immunity.', 'Naturally targets Digestion, Immunity while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '50g', 'weight', 'g', 50, true),
    ('Neem Powder', 'வேப்பிலை பொடி', 'வேப்பிலை பொடி', 'Herbal Powder', 1, ARRAY['Skin Care', 'Diabetes'], 90, NULL, 'Premium Herbal Powder formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care and Diabetes.', 'Naturally targets Skin Care, Diabetes while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Moringa Powder', 'முருங்கை பொடி', 'முருங்கை பொடி', 'Herbal Powder', 1, ARRAY['Immunity', 'Joint Pain'], 160, 150, 'Premium Herbal Powder formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Immunity and Joint Pain.', 'Naturally targets Immunity, Joint Pain while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Triphala Chooranam', 'திரிபலா சூரணம்', 'திரிபலா சூரணம்', 'Herbal Powder', 1, ARRAY['Digestion', 'Weight Loss'], 150, 140, 'Premium Herbal Powder formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Digestion and Weight Loss.', 'Naturally targets Digestion, Weight Loss while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Adhatoda Powder', 'ஆடாதோடா பொடி', 'ஆடாதோடா பொடி', 'Herbal Powder', 1, ARRAY['Cold & Cough', 'Fever'], 130, 120, 'Premium Herbal Powder formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Cold & Cough and Fever.', 'Naturally targets Cold & Cough, Fever while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Karpooravalli Thailam', 'கற்பூரவள்ளி தைலம்', 'கற்பூரவள்ளி தைலம்', 'Herbal Oil', 2, ARRAY['Cold & Cough', 'Joint Pain'], 200, 190, 'Premium Herbal Oil formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Cold & Cough and Joint Pain.', 'Naturally targets Cold & Cough, Joint Pain while boosting overall vitality.', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 100, 100, 'ml', '100ml', 'volume', 'ml', 100, true),
    ('Neelibhringadi Thailam', 'நீலிபிருங்காதி தைலம்', 'நீலிபிருங்காதி தைலம்', 'Herbal Oil', 2, ARRAY['Hair Growth', 'Stress'], 250, 240, 'Premium Herbal Oil formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Hair Growth and Stress.', 'Naturally targets Hair Growth, Stress while boosting overall vitality.', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 100, 100, 'ml', '100ml', 'volume', 'ml', 100, true),
    ('Pinda Thailam', 'பிண்ட தைலம்', 'பிண்ட தைலம்', 'Herbal Oil', 2, ARRAY['Joint Pain', 'Skin Care'], 220, 210, 'Premium Herbal Oil formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Joint Pain and Skin Care.', 'Naturally targets Joint Pain, Skin Care while boosting overall vitality.', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 100, 100, 'ml', '100ml', 'volume', 'ml', 100, true),
    ('Castor Oil (Amanakku)', 'ஆமணக்கு எண்ணெய்', 'ஆமணக்கு எண்ணெய்', 'Herbal Oil', 2, ARRAY['Digestion', 'Hair Growth'], 180, 170, 'Premium Herbal Oil formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Digestion and Hair Growth.', 'Naturally targets Digestion, Hair Growth while boosting overall vitality.', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 100, 100, 'ml', '200ml', 'volume', 'ml', 200, true),
    ('Sesame Oil (Nallennai)', 'நல்லெண்ணெய்', 'நல்லெண்ணெய்', 'Herbal Oil', 2, ARRAY['Joint Pain', 'Skin Care'], 350, 340, 'Premium Herbal Oil formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Joint Pain and Skin Care.', 'Naturally targets Joint Pain, Skin Care while boosting overall vitality.', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 100, 100, 'ml', '500ml', 'volume', 'ml', 500, true),
    ('Mahamasha Thailam', 'மகாமாஷ தைலம்', 'மகாமாஷ தைலம்', 'Herbal Oil', 2, ARRAY['Joint Pain', 'Stress'], 280, 270, 'Premium Herbal Oil formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Joint Pain and Stress.', 'Naturally targets Joint Pain, Stress while boosting overall vitality.', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 100, 100, 'ml', '100ml', 'volume', 'ml', 100, true),
    ('Kumkumadi Thailam', 'குங்குமாதி தைலம்', 'குங்குமாதி தைலம்', 'Herbal Oil', 2, ARRAY['Skin Care'], 450, 440, 'Premium Herbal Oil formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care.', 'Naturally targets Skin Care while boosting overall vitality.', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 100, 100, 'ml', '25ml', 'volume', 'ml', 25, true),
    ('Arugan Thailam', 'அருகன் தைலம்', 'அருகன் தைலம்', 'Herbal Oil', 2, ARRAY['Skin Care', 'Hair Growth'], 210, 200, 'Premium Herbal Oil formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care and Hair Growth.', 'Naturally targets Skin Care, Hair Growth while boosting overall vitality.', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80', 100, 100, 'ml', '100ml', 'volume', 'ml', 100, true),
    ('Ashwagandha Root', 'அஸ்வகந்தா வேர்', 'அஸ்வகந்தா வேர்', 'Herbal Root', 3, ARRAY['Stress', 'Immunity'], 300, 290, 'Premium Herbal Root formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Stress and Immunity.', 'Naturally targets Stress, Immunity while boosting overall vitality.', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Sarsaparilla Root', 'நன்னாரி வேர்', 'நன்னாரி வேர்', 'Herbal Root', 3, ARRAY['Digestion', 'Skin Care'], 250, 240, 'Premium Herbal Root formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Digestion and Skin Care.', 'Naturally targets Digestion, Skin Care while boosting overall vitality.', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Korai Kizhangu', 'கோரை கிழங்கு', 'கோரை கிழங்கு', 'Herbal Root', 3, ARRAY['Digestion', 'Weight Loss'], 180, 170, 'Premium Herbal Root formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Digestion and Weight Loss.', 'Naturally targets Digestion, Weight Loss while boosting overall vitality.', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Vettiver', 'வெட்டிவேர்', 'வெட்டிவேர்', 'Herbal Root', 3, ARRAY['Stress', 'Skin Care'], 150, 140, 'Premium Herbal Root formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Stress and Skin Care.', 'Naturally targets Stress, Skin Care while boosting overall vitality.', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 100, 100, 'g', '50g', 'weight', 'g', 50, true),
    ('Athimathuram Root', 'அதிமதுரம் வேர்', 'அதிமதுரம் வேர்', 'Herbal Root', 3, ARRAY['Cold & Cough', 'Digestion'], 220, 210, 'Premium Herbal Root formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Cold & Cough and Digestion.', 'Naturally targets Cold & Cough, Digestion while boosting overall vitality.', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Sitharathai Root', 'சித்தரத்தை வேர்', 'சித்தரத்தை வேர்', 'Herbal Root', 3, ARRAY['Cold & Cough', 'Joint Pain'], 240, 230, 'Premium Herbal Root formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Cold & Cough and Joint Pain.', 'Naturally targets Cold & Cough, Joint Pain while boosting overall vitality.', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Poolankilangu', 'பூலாங்கிழங்கு', 'பூலாங்கிழங்கு', 'Herbal Root', 3, ARRAY['Skin Care', 'Fever'], 190, 180, 'Premium Herbal Root formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care and Fever.', 'Naturally targets Skin Care, Fever while boosting overall vitality.', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Black Pepper', 'மிளகு', 'மிளகு', 'Herbal Spice', 4, ARRAY['Cold & Cough', 'Digestion'], 350, 340, 'Premium Herbal Spice formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Cold & Cough and Digestion.', 'Naturally targets Cold & Cough, Digestion while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '200g', 'weight', 'g', 200, true),
    ('Dry Ginger (Sukku)', 'சுக்கு', 'சுக்கு', 'Herbal Spice', 4, ARRAY['Digestion', 'Joint Pain'], 180, 170, 'Premium Herbal Spice formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Digestion and Joint Pain.', 'Naturally targets Digestion, Joint Pain while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Cardamom (Elakkai)', 'ஏலக்காய்', 'ஏலக்காய்', 'Herbal Spice', 4, ARRAY['Digestion', 'Skin Care'], 400, 390, 'Premium Herbal Spice formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Digestion and Skin Care.', 'Naturally targets Digestion, Skin Care while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '50g', 'weight', 'g', 50, true),
    ('Clove (Krambu)', 'கிராம்பு', 'கிராம்பு', 'Herbal Spice', 4, ARRAY['Cold & Cough', 'Joint Pain'], 250, 240, 'Premium Herbal Spice formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Cold & Cough and Joint Pain.', 'Naturally targets Cold & Cough, Joint Pain while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '50g', 'weight', 'g', 50, true),
    ('Turmeric (Manjal)', 'மஞ்சள்', 'மஞ்சள்', 'Herbal Spice', 4, ARRAY['Skin Care', 'Immunity'], 150, 140, 'Premium Herbal Spice formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care and Immunity.', 'Naturally targets Skin Care, Immunity while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '250g', 'weight', 'g', 250, true),
    ('Fenugreek (Vendhayam)', 'வெந்தயம்', 'வெந்தயம்', 'Herbal Spice', 4, ARRAY['Diabetes', 'Hair Growth'], 120, 110, 'Premium Herbal Spice formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Diabetes and Hair Growth.', 'Naturally targets Diabetes, Hair Growth while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '250g', 'weight', 'g', 250, true),
    ('Cinnamon (Pattai)', 'பட்டை', 'பட்டை', 'Herbal Spice', 4, ARRAY['Weight Loss', 'Diabetes'], 200, 190, 'Premium Herbal Spice formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Weight Loss and Diabetes.', 'Naturally targets Weight Loss, Diabetes while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Cumin (Seeragam)', 'சீரகம்', 'சீரகம்', 'Herbal Spice', 4, ARRAY['Digestion', 'Weight Loss'], 220, 210, 'Premium Herbal Spice formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Digestion and Weight Loss.', 'Naturally targets Digestion, Weight Loss while boosting overall vitality.', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80', 100, 100, 'g', '200g', 'weight', 'g', 200, true),
    ('Aloe Vera Gel', 'கற்றாழை ஜெல்', 'கற்றாழை ஜெல்', 'Herbal Gel', 5, ARRAY['Skin Care', 'Hair Growth'], 180, 170, 'Premium Herbal Gel formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care and Hair Growth.', 'Naturally targets Skin Care, Hair Growth while boosting overall vitality.', 'https://images.unsplash.com/photo-1615397323759-4ac9fc2726bb?w=400&q=80', 'https://images.unsplash.com/photo-1615397323759-4ac9fc2726bb?w=400&q=80', 100, 100, 'g', '150g', 'weight', 'g', 150, true),
    ('Kuppaimeni Gel', 'குப்பைமேனி ஜெல்', 'குப்பைமேனி ஜெல்', 'Herbal Gel', 5, ARRAY['Skin Care', 'Fever'], 160, 150, 'Premium Herbal Gel formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care and Fever.', 'Naturally targets Skin Care, Fever while boosting overall vitality.', 'https://images.unsplash.com/photo-1615397323759-4ac9fc2726bb?w=400&q=80', 'https://images.unsplash.com/photo-1615397323759-4ac9fc2726bb?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Vettiver Gel', 'வெட்டிவேர் ஜெல்', 'வெட்டிவேர் ஜெல்', 'Herbal Gel', 5, ARRAY['Skin Care', 'Stress'], 200, 190, 'Premium Herbal Gel formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care and Stress.', 'Naturally targets Skin Care, Stress while boosting overall vitality.', 'https://images.unsplash.com/photo-1615397323759-4ac9fc2726bb?w=400&q=80', 'https://images.unsplash.com/photo-1615397323759-4ac9fc2726bb?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Tulsi Anti-Acne Gel', 'துளசி ஜெல்', 'துளசி ஜெல்', 'Herbal Gel', 5, ARRAY['Skin Care', 'Immunity'], 150, 140, 'Premium Herbal Gel formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care and Immunity.', 'Naturally targets Skin Care, Immunity while boosting overall vitality.', 'https://images.unsplash.com/photo-1615397323759-4ac9fc2726bb?w=400&q=80', 'https://images.unsplash.com/photo-1615397323759-4ac9fc2726bb?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Shilajit Extract', 'சிலாஜித்', 'சிலாஜித்', 'Mineral Herb', 6, ARRAY['Immunity', 'Stress'], 950, 940, 'Premium Mineral Herb formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Immunity and Stress.', 'Naturally targets Immunity, Stress while boosting overall vitality.', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 100, 100, 'g', '20g', 'weight', 'g', 20, true),
    ('Padikaram (Alum)', 'படிகாரம்', 'படிகாரம்', 'Mineral Herb', 6, ARRAY['Skin Care', 'Joint Pain'], 90, NULL, 'Premium Mineral Herb formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care and Joint Pain.', 'Naturally targets Skin Care, Joint Pain while boosting overall vitality.', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Loha Bhasma', 'லோக பஸ்மா', 'லோக பஸ்மா', 'Mineral Herb', 6, ARRAY['Immunity', 'Hair Growth'], 350, 340, 'Premium Mineral Herb formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Immunity and Hair Growth.', 'Naturally targets Immunity, Hair Growth while boosting overall vitality.', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 100, 100, 'g', '10g', 'weight', 'g', 10, true),
    ('Kavikkal (Red Ochre)', 'கவிக்கல்', 'கவிக்கல்', 'Mineral Herb', 6, ARRAY['Skin Care'], 120, 110, 'Premium Mineral Herb formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care.', 'Naturally targets Skin Care while boosting overall vitality.', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Brahmi Vati', 'பிரம்மி மாத்திரை', 'பிரம்மி மாத்திரை', 'Herbal Tablet', 7, ARRAY['Stress', 'Memory'], 250, 240, 'Premium Herbal Tablet formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Stress and Memory.', 'Naturally targets Stress, Memory while boosting overall vitality.', 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80', 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80', 100, 100, 'capsules', '60 capsules', 'unit', 'capsules', 60, false),
    ('Arjuna Tablet', 'அர்ஜுனா மாத்திரை', 'அர்ஜுனா மாத்திரை', 'Herbal Tablet', 7, ARRAY['Stress', 'Immunity'], 220, 210, 'Premium Herbal Tablet formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Stress and Immunity.', 'Naturally targets Stress, Immunity while boosting overall vitality.', 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80', 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80', 100, 100, 'capsules', '60 capsules', 'unit', 'capsules', 60, false),
    ('Vallarai Tablet', 'வல்லாரை மாத்திரை', 'வல்லாரை மாத்திரை', 'Herbal Tablet', 7, ARRAY['Stress', 'Fatigue'], 200, 190, 'Premium Herbal Tablet formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Stress and Fatigue.', 'Naturally targets Stress, Fatigue while boosting overall vitality.', 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80', 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80', 100, 100, 'capsules', '60 capsules', 'unit', 'capsules', 60, false),
    ('Madhumehari Tablet', 'நீரிழிவு மாத்திரை', 'நீரிழிவு மாத்திரை', 'Herbal Tablet', 7, ARRAY['Diabetes', 'Weight Loss'], 350, 340, 'Premium Herbal Tablet formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Diabetes and Weight Loss.', 'Naturally targets Diabetes, Weight Loss while boosting overall vitality.', 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80', 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80', 100, 100, 'capsules', '100 capsules', 'unit', 'capsules', 100, false),
    ('Amla Extract Capsule', 'நெல்லிக்காய் மாத்திரை', 'நெல்லிக்காய் மாத்திரை', 'Herbal Tablet', 7, ARRAY['Immunity', 'Hair Growth'], 280, 270, 'Premium Herbal Tablet formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Immunity and Hair Growth.', 'Naturally targets Immunity, Hair Growth while boosting overall vitality.', 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80', 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80', 100, 100, 'capsules', '60 capsules', 'unit', 'capsules', 60, false),
    ('Manasamithini Tablet', 'மனசமிதிநி மாத்திரை', 'மனசமிதிநி மாத்திரை', 'Herbal Tablet', 7, ARRAY['Stress', 'Digestion'], 240, 230, 'Premium Herbal Tablet formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Stress and Digestion.', 'Naturally targets Stress, Digestion while boosting overall vitality.', 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80', 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80', 100, 100, 'capsules', '60 capsules', 'unit', 'capsules', 60, false),
    ('Dry Tulsi Leaves', 'துளசி இலை', 'துளசி இலை', 'Herbal Leaf', 8, ARRAY['Fever', 'Cold & Cough'], 90, NULL, 'Premium Herbal Leaf formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Fever and Cold & Cough.', 'Naturally targets Fever, Cold & Cough while boosting overall vitality.', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 100, 100, 'g', '50g', 'weight', 'g', 50, true),
    ('Dry Neem Leaves', 'வேப்பிலை', 'வேப்பிலை', 'Herbal Leaf', 8, ARRAY['Skin Care', 'Diabetes'], 80, NULL, 'Premium Herbal Leaf formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care and Diabetes.', 'Naturally targets Skin Care, Diabetes while boosting overall vitality.', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Mint Leaves (Pudina)', 'புதினா இலை', 'புதினா இலை', 'Herbal Leaf', 8, ARRAY['Digestion', 'Weight Loss'], 120, 110, 'Premium Herbal Leaf formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Digestion and Weight Loss.', 'Naturally targets Digestion, Weight Loss while boosting overall vitality.', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 100, 100, 'g', '50g', 'weight', 'g', 50, true),
    ('Curry Leaves', 'கறிவேப்பிலை', 'கறிவேப்பிலை', 'Herbal Leaf', 8, ARRAY['Hair Growth', 'Digestion'], 110, 100, 'Premium Herbal Leaf formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Hair Growth and Digestion.', 'Naturally targets Hair Growth, Digestion while boosting overall vitality.', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Senna Leaves', 'நிலாவாரை', 'நிலாவாரை', 'Herbal Leaf', 8, ARRAY['Digestion', 'Skin Care'], 150, 140, 'Premium Herbal Leaf formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Digestion and Skin Care.', 'Naturally targets Digestion, Skin Care while boosting overall vitality.', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Siriyanangai Leaves', 'சிறியாநங்கை இலை', 'சிறியாநங்கை இலை', 'Herbal Leaf', 8, ARRAY['Diabetes', 'Fever'], 180, 170, 'Premium Herbal Leaf formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Diabetes and Fever.', 'Naturally targets Diabetes, Fever while boosting overall vitality.', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 100, 100, 'g', '50g', 'weight', 'g', 50, true),
    ('Keezhanelli Leaves', 'கீழாநெல்லி இலை', 'கீழாநெல்லி இலை', 'Herbal Leaf', 8, ARRAY['Digestion', 'Immunity'], 160, 150, 'Premium Herbal Leaf formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Digestion and Immunity.', 'Naturally targets Digestion, Immunity while boosting overall vitality.', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Siddha Hair Wash Pack', 'சிகைக்காய் தூள்', 'சிகைக்காய் தூள்', 'Herbal Product', 9, ARRAY['Hair Growth'], 220, 210, 'Premium Herbal Product formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Hair Growth.', 'Naturally targets Hair Growth while boosting overall vitality.', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 100, 100, 'g', '200g', 'weight', 'g', 200, true),
    ('Pancha Karpam Bathing Powder', 'பஞ்ச கற்பம்', 'பஞ்ச கற்பம்', 'Herbal Product', 9, ARRAY['Skin Care', 'Stress'], 280, 270, 'Premium Herbal Product formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care and Stress.', 'Naturally targets Skin Care, Stress while boosting overall vitality.', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 100, 100, 'g', '250g', 'weight', 'g', 250, true),
    ('Avarampoo Bath Powder', 'ஆவாரம்பூ குளியல் பொடி', 'ஆவாரம்பூ குளியல் பொடி', 'Herbal Product', 9, ARRAY['Skin Care', 'Fever'], 250, 240, 'Premium Herbal Product formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Skin Care and Fever.', 'Naturally targets Skin Care, Fever while boosting overall vitality.', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 100, 100, 'g', '200g', 'weight', 'g', 200, true),
    ('Herbal Tooth Powder', 'மூலிகை பல்பொடி', 'மூலிகை பல்பொடி', 'Herbal Product', 9, ARRAY['Immunity'], 140, 130, 'Premium Herbal Product formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Immunity.', 'Naturally targets Immunity while boosting overall vitality.', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 100, 100, 'g', '100g', 'weight', 'g', 100, true),
    ('Triphala Honey Blend', 'திரிபலா தேன் கலவை', 'திரிபலா தேன் கலவை', 'Herbal Product', 9, ARRAY['Digestion', 'Weight Loss'], 400, 390, 'Premium Herbal Product formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Digestion and Weight Loss.', 'Naturally targets Digestion, Weight Loss while boosting overall vitality.', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 100, 100, 'g', '250g', 'weight', 'g', 250, true),
    ('Siddha Chyawanprash', 'சித்தா சியவன்ப்ராஷ்', 'சித்தா சியவன்ப்ராஷ்', 'Herbal Product', 9, ARRAY['Immunity', 'Stress'], 550, 540, 'Premium Herbal Product formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Immunity and Stress.', 'Naturally targets Immunity, Stress while boosting overall vitality.', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 100, 100, 'g', '500g', 'weight', 'g', 500, true),
    ('Navadhanya Mix', 'நவதானிய மாவு', 'நவதானிய மாவு', 'Herbal Product', 9, ARRAY['Weight Loss', 'Diabetes'], 300, 290, 'Premium Herbal Product formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to Weight Loss and Diabetes.', 'Naturally targets Weight Loss, Diabetes while boosting overall vitality.', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80', 100, 100, 'g', '500g', 'weight', 'g', 500, true);
  END IF;
END $$;


-- ═══════════════════════════════════════════════════════════════════════
-- 9. SUPABASE STORAGE — product-images bucket (public)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  VALUES ('product-images', 'product-images', true, 5242880,
          ARRAY['image/jpeg','image/png','image/webp','image/gif'])
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "product_images_public_read"   ON storage.objects;
DROP POLICY IF EXISTS "product_images_admin_upload"  ON storage.objects;
DROP POLICY IF EXISTS "product_images_admin_delete"  ON storage.objects;

CREATE POLICY "product_images_public_read" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'product-images');

CREATE POLICY "product_images_admin_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'product-images'
    AND coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin'
  );

CREATE POLICY "product_images_admin_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'product-images'
    AND coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin'
  );
NOTIFY pgrst, 'reload schema';