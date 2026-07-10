-- ── Korean Fried Chicken — Public POS Schema ────────────────────
-- Run this ONCE in your Supabase SQL Editor.
-- No login required — works with anon key for POS billing & coupons.

-- 1. Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Helper functions
CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_admin() RETURNS BOOLEAN AS $$
BEGIN
  RETURN COALESCE(
    (SELECT raw_app_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin',
    false
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- Auto-create profile on auth signup (for when login IS used)
CREATE OR REPLACE FUNCTION handle_new_user() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, mobile, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'mobile', ''),
    CASE WHEN NEW.email = 'admin@koreanfriedchicken.com' THEN 'admin' ELSE 'customer' END
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 3. Tables (idempotent)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  customer_code TEXT UNIQUE,
  name TEXT,
  mobile TEXT,
  email TEXT,
  role TEXT DEFAULT 'customer' CHECK (role IN ('admin','customer')),
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS categories (
  id BIGSERIAL PRIMARY KEY,
  name_en TEXT NOT NULL,
  name_ta TEXT DEFAULT '',
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  name_ta TEXT DEFAULT '',
  tamil_name TEXT DEFAULT '',
  category TEXT NOT NULL,
  category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL,
  description TEXT DEFAULT '',
  description_ta TEXT DEFAULT '',
  benefits TEXT DEFAULT '',
  benefits_ta TEXT DEFAULT '',
  price NUMERIC(10,2) NOT NULL DEFAULT 0,
  offer_price NUMERIC(10,2),
  image TEXT DEFAULT '/assets/images/default-product.jpg',
  image_url TEXT DEFAULT '/assets/images/default-product.jpg',
  unit_type TEXT DEFAULT 'unit' CHECK (unit_type IN ('unit','weight','volume','bundle')),
  unit_label TEXT DEFAULT 'piece',
  base_quantity NUMERIC(10,3) DEFAULT 1,
  stock_quantity NUMERIC(10,3) DEFAULT 0,
  stock_unit TEXT DEFAULT 'piece',
  allow_decimal_quantity BOOLEAN DEFAULT false,
  predefined_options JSONB DEFAULT '[]'::jsonb,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  has_variants BOOLEAN DEFAULT false,
  rating NUMERIC(3,1) DEFAULT 4.5,
  sku TEXT,
  barcode TEXT,
  brand TEXT,
  stock NUMERIC(10,3) DEFAULT 0,
  unit TEXT DEFAULT 'piece',
  remedy JSONB DEFAULT '[]'::jsonb,
  purchase_price NUMERIC(10,2) DEFAULT 0,
  gst_percent NUMERIC(5,2) DEFAULT 0,
  opening_stock NUMERIC(10,3) DEFAULT 0,
  low_stock_alert NUMERIC(10,3) DEFAULT 5,
  supplier TEXT,
  size TEXT,
  color TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_variants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id TEXT NOT NULL,
  variant_name TEXT NOT NULL,
  size_label TEXT,
  group_name TEXT,
  price NUMERIC(10,2) NOT NULL DEFAULT 0,
  purchase_price NUMERIC(10,2),
  mrp NUMERIC(10,2),
  stock NUMERIC(10,3) DEFAULT 0,
  sku TEXT,
  barcode TEXT,
  sort_order INTEGER DEFAULT 0,
  is_default BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  weight_value NUMERIC(10,3),
  weight_unit TEXT,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  invoice_no TEXT UNIQUE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  customer_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  address TEXT DEFAULT '',
  items JSONB DEFAULT '[]'::jsonb,
  subtotal NUMERIC(10,2) DEFAULT 0,
  shipping NUMERIC(10,2) DEFAULT 0,
  total NUMERIC(10,2) DEFAULT 0,
  status TEXT DEFAULT 'pending',
  order_mode TEXT DEFAULT 'online' CHECK (order_mode IN ('online','offline')),
  order_type TEXT DEFAULT 'pos_sale' CHECK (order_type IN ('online_request','pos_sale','manual_sale')),
  delivery_charge NUMERIC(10,2) DEFAULT 0,
  discount_amount NUMERIC(10,2) DEFAULT 0,
  manual_discount_amount NUMERIC(10,2) DEFAULT 0,
  manual_discount_type TEXT CHECK (manual_discount_type IN ('flat','percent')),
  manual_discount_value NUMERIC(10,2) DEFAULT 0,
  coupon_code TEXT,
  coupon_percentage NUMERIC(5,2) DEFAULT 0,
  payment_method TEXT CHECK (payment_method IN ('cash','upi','card','split')),
  split_details JSONB,
  total_gst NUMERIC(10,2) DEFAULT 0,
  gst_enabled BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id TEXT,
  variant_id TEXT,
  product_name TEXT NOT NULL,
  variant_name TEXT,
  product_tamil_name TEXT DEFAULT '',
  quantity NUMERIC(10,3) NOT NULL DEFAULT 1,
  unit TEXT DEFAULT 'piece',
  unit_type TEXT DEFAULT 'unit',
  base_quantity NUMERIC(10,3) DEFAULT 1,
  base_price NUMERIC(10,2) DEFAULT 0,
  line_total NUMERIC(10,2) DEFAULT 0,
  image_url TEXT,
  is_manual BOOLEAN DEFAULT false,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS coupons (
  id BIGSERIAL PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  percentage NUMERIC(5,2) NOT NULL DEFAULT 10,
  is_active BOOLEAN DEFAULT true,
  expiry_date DATE,
  usage_limit INTEGER,
  usage_count INTEGER DEFAULT 0,
  min_order_value NUMERIC(10,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS invoice_counter (
  id INTEGER PRIMARY KEY DEFAULT 1,
  counter INTEGER DEFAULT 0,
  year INTEGER DEFAULT EXTRACT(YEAR FROM NOW())
);

CREATE TABLE IF NOT EXISTS store_settings (
  id BIGSERIAL PRIMARY KEY,
  name TEXT DEFAULT 'Korean Fried Chicken',
  owner_name TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  address TEXT DEFAULT '',
  gst_enabled BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Triggers
DROP TRIGGER IF EXISTS trg_profiles_updated_at ON profiles;
CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
DROP TRIGGER IF EXISTS trg_products_updated_at ON products;
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
DROP TRIGGER IF EXISTS trg_orders_updated_at ON orders;
CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
DROP TRIGGER IF EXISTS trg_categories_updated_at ON categories;
CREATE TRIGGER trg_categories_updated_at BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- 5. RLS — PUBLIC ACCESS: anon can do everything needed for POS
-- These policies let anyone with the anon key use the POS + coupons.
-- No login required.

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_counter ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_settings ENABLE ROW LEVEL SECURITY;

-- Categories: anyone can read, anyone can write (POS management)
DROP POLICY IF EXISTS categories_public ON categories;
CREATE POLICY categories_public ON categories FOR ALL USING (true) WITH CHECK (true);

-- Products: anyone can read, anyone can write
DROP POLICY IF EXISTS products_public ON products;
CREATE POLICY products_public ON products FOR ALL USING (true) WITH CHECK (true);

-- Product variants: anyone can read, anyone can write
DROP POLICY IF EXISTS variants_public ON product_variants;
CREATE POLICY variants_public ON product_variants FOR ALL USING (true) WITH CHECK (true);

-- Orders: anyone can read, anyone can write
DROP POLICY IF EXISTS orders_public ON orders;
CREATE POLICY orders_public ON orders FOR ALL USING (true) WITH CHECK (true);

-- Order items: anyone can read, anyone can write
DROP POLICY IF EXISTS order_items_public ON order_items;
CREATE POLICY order_items_public ON order_items FOR ALL USING (true) WITH CHECK (true);

-- Coupons: anyone can read, anyone can write
DROP POLICY IF EXISTS coupons_public ON coupons;
CREATE POLICY coupons_public ON coupons FOR ALL USING (true) WITH CHECK (true);

-- Invoice counter: anyone can read, anyone can write
DROP POLICY IF EXISTS invoice_counter_public ON invoice_counter;
CREATE POLICY invoice_counter_public ON invoice_counter FOR ALL USING (true) WITH CHECK (true);

-- Store settings: anyone can read, anyone can write
DROP POLICY IF EXISTS settings_public ON store_settings;
CREATE POLICY settings_public ON store_settings FOR ALL USING (true) WITH CHECK (true);

-- Profiles: only needed if auth is added later
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profiles_public ON profiles;
CREATE POLICY profiles_public ON profiles FOR ALL USING (true) WITH CHECK (true);

-- 6. RPCs
-- Get next invoice number
CREATE OR REPLACE FUNCTION get_next_invoice_no() RETURNS TEXT AS $$
DECLARE
  curr_year INTEGER;
  next_val INTEGER;
BEGIN
  curr_year := EXTRACT(YEAR FROM NOW());
  INSERT INTO invoice_counter (id, counter, year)
  VALUES (1, 1, curr_year)
  ON CONFLICT (id) DO UPDATE SET counter = invoice_counter.counter + 1
  WHERE invoice_counter.year = curr_year
  RETURNING counter INTO next_val;
  IF next_val IS NULL THEN
    UPDATE invoice_counter SET counter = 1, year = curr_year WHERE id = 1;
    next_val := 1;
  END IF;
  RETURN 'INV-' || curr_year || '-' || LPAD(next_val::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- Retail decrement stock
CREATE OR REPLACE FUNCTION retail_decrement_stock(
  p_product_id BIGINT,
  p_quantity NUMERIC,
  p_unit_type TEXT DEFAULT 'unit'
) RETURNS VOID AS $$
BEGIN
  UPDATE products SET stock_quantity = GREATEST(COALESCE(stock_quantity, 0) - p_quantity, 0)
  WHERE id::TEXT = p_product_id::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Create order with stock (15-param variant-aware version)
CREATE OR REPLACE FUNCTION create_order_with_stock(
  p_customer_name TEXT,
  p_phone TEXT,
  p_address TEXT,
  p_items JSONB,
  p_shipping NUMERIC DEFAULT 0,
  p_status TEXT DEFAULT 'pending',
  p_order_mode TEXT DEFAULT 'online',
  p_order_type TEXT DEFAULT NULL,
  p_delivery_charge NUMERIC DEFAULT 0,
  p_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_type TEXT DEFAULT 'flat',
  p_manual_discount_value NUMERIC DEFAULT 0,
  p_coupon_code TEXT DEFAULT NULL,
  p_coupon_percentage NUMERIC DEFAULT 0
) RETURNS JSONB AS $$
DECLARE
  v_order_id UUID;
  v_invoice_no TEXT;
  v_subtotal NUMERIC := 0;
  v_item RECORD;
  v_is_manual BOOLEAN;
  v_detected_type TEXT;
BEGIN
  v_detected_type := COALESCE(p_order_type,
    CASE WHEN p_status = 'pending' AND p_order_mode = 'online' THEN 'online_request'
         ELSE 'pos_sale' END);
  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
    product_id TEXT, variant_id TEXT, name TEXT, product_name TEXT,
    quantity NUMERIC, price NUMERIC, line_total NUMERIC,
    source TEXT, is_manual BOOLEAN
  ) LOOP
    IF COALESCE(v_item.is_manual, false) OR v_item.source = 'manual' OR v_item.product_id IS NULL THEN
      v_detected_type := 'manual_sale'; EXIT; END IF;
  END LOOP;
  SELECT get_next_invoice_no() INTO v_invoice_no;
  SELECT COALESCE(SUM(line_total), 0) INTO v_subtotal
  FROM jsonb_to_recordset(p_items) AS x(line_total NUMERIC);
  INSERT INTO orders (invoice_no, customer_name, phone, address, items, subtotal,
    shipping, total, status, order_mode, order_type,
    delivery_charge, discount_amount, manual_discount_amount,
    manual_discount_type, manual_discount_value, coupon_code, coupon_percentage)
  VALUES (v_invoice_no, p_customer_name, p_phone, p_address, p_items, v_subtotal,
    p_shipping,
    GREATEST(v_subtotal + COALESCE(p_shipping,0) + COALESCE(p_delivery_charge,0)
      - COALESCE(p_discount_amount,0) - COALESCE(p_manual_discount_amount,0), 0),
    p_status, p_order_mode, v_detected_type,
    p_delivery_charge, p_discount_amount, p_manual_discount_amount,
    p_manual_discount_type, p_manual_discount_value, p_coupon_code, p_coupon_percentage)
  RETURNING id INTO v_order_id;
  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
    product_id TEXT, variant_id TEXT, name TEXT, product_name TEXT,
    variant_name TEXT, tamil_name TEXT, quantity NUMERIC, unit TEXT,
    unit_type TEXT, base_quantity NUMERIC, base_price NUMERIC,
    line_total NUMERIC, image_url TEXT, source TEXT, is_manual BOOLEAN, note TEXT
  ) LOOP
    v_is_manual := COALESCE(v_item.is_manual, false) OR v_item.source = 'manual';
    INSERT INTO order_items (order_id, product_id, variant_id, product_name, variant_name,
      product_tamil_name, quantity, unit, unit_type, base_quantity,
      base_price, line_total, image_url, is_manual, note)
    VALUES (v_order_id, v_item.product_id, v_item.variant_id,
      COALESCE(v_item.product_name, v_item.name, 'Item'), v_item.variant_name,
      v_item.tamil_name, COALESCE(v_item.quantity, 1), COALESCE(v_item.unit, 'piece'),
      COALESCE(v_item.unit_type, 'unit'), COALESCE(v_item.base_quantity, 1),
      COALESCE(v_item.base_price, 0), COALESCE(v_item.line_total, 0),
      v_item.image_url, v_is_manual, v_item.note);
    IF NOT v_is_manual AND v_item.product_id IS NOT NULL THEN
      IF v_item.variant_id IS NOT NULL AND v_item.variant_id <> '' THEN
        UPDATE product_variants SET stock = GREATEST(COALESCE(stock, 0) - COALESCE(v_item.quantity, 1), 0)
        WHERE id::TEXT = v_item.variant_id;
      ELSE
        PERFORM retail_decrement_stock(v_item.product_id::BIGINT, COALESCE(v_item.quantity, 1), COALESCE(v_item.unit_type, 'unit'));
      END IF;
    END IF;
  END LOOP;
  IF p_coupon_code IS NOT NULL AND p_coupon_code <> '' THEN
    UPDATE coupons SET usage_count = COALESCE(usage_count, 0) + 1 WHERE code = p_coupon_code;
  END IF;
  RETURN jsonb_build_object('order_id', v_order_id, 'invoice_no', v_invoice_no);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Indexes
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_sort ON products(sort_order);
CREATE INDEX IF NOT EXISTS idx_product_variants_product ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_orders_invoice ON orders(invoice_no);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_phone ON orders(phone);
CREATE INDEX IF NOT EXISTS idx_orders_type ON orders(order_type);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);

-- 8. Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE order_items;
ALTER PUBLICATION supabase_realtime ADD TABLE products;

-- 9. Seed data
INSERT INTO categories (name_en, sort_order) VALUES
  ('Chicken', 1),
  ('Sides', 2),
  ('Burgers & Wraps', 3),
  ('Beverages', 4)
ON CONFLICT DO NOTHING;

INSERT INTO store_settings (name, owner_name, phone, address, gst_enabled)
SELECT 'Korean Fried Chicken', 'Sulficker Roshan N', '+91 9342489391',
  'Nanjappa Garden, Selvapuram, SBI Bank Opposite, Shivalaya Mahal Road, Komarapalayam, Coimbatore', false
WHERE NOT EXISTS (SELECT 1 FROM store_settings);

DO $$
DECLARE
  cat_chicken BIGINT; cat_sides BIGINT; cat_wraps BIGINT;
BEGIN
  SELECT id INTO cat_chicken FROM categories WHERE name_en = 'Chicken' LIMIT 1;
  SELECT id INTO cat_sides FROM categories WHERE name_en = 'Sides' LIMIT 1;
  SELECT id INTO cat_wraps FROM categories WHERE name_en = 'Burgers & Wraps' LIMIT 1;
  INSERT INTO products (name, category, category_id, price, stock, description, sort_order, image, image_url)
  VALUES
    ('Bone Shot', 'Chicken', cat_chicken, 120.00, 100, 'Crispy Korean fried chicken bone-in pieces.', 1, '/assets/images/default-product.jpg', '/assets/images/default-product.jpg'),
    ('Big Shot', 'Chicken', cat_chicken, 180.00, 100, 'Large boneless chicken pieces with Korean sauce.', 2, '/assets/images/default-product.jpg', '/assets/images/default-product.jpg'),
    ('Strips', 'Chicken', cat_chicken, 150.00, 100, 'Tender crispy chicken strips with dip.', 3, '/assets/images/default-product.jpg', '/assets/images/default-product.jpg'),
    ('Loaded Fries', 'Sides', cat_sides, 130.00, 100, 'Fries loaded with cheese, sauce & chicken topping.', 4, '/assets/images/default-product.jpg', '/assets/images/default-product.jpg'),
    ('French Fries', 'Sides', cat_sides, 70.00, 100, 'Classic crispy salted french fries.', 5, '/assets/images/default-product.jpg', '/assets/images/default-product.jpg'),
    ('Wrap', 'Burgers & Wraps', cat_wraps, 140.00, 100, 'Tortilla wrap with crispy chicken, veggies & sauce.', 6, '/assets/images/default-product.jpg', '/assets/images/default-product.jpg'),
    ('Burger', 'Burgers & Wraps', cat_wraps, 160.00, 100, 'Chicken burger with lettuce, tomato, cheese & sauce.', 7, '/assets/images/default-product.jpg', '/assets/images/default-product.jpg')
  ON CONFLICT DO NOTHING;
END $$;

INSERT INTO invoice_counter (id, counter, year)
SELECT 1, 0, EXTRACT(YEAR FROM NOW())
WHERE NOT EXISTS (SELECT 1 FROM invoice_counter);
