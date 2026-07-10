-- ── Korean Fried Chicken — Initial Schema ────────────────────────────
-- Run this once in your Supabase SQL Editor.
-- Idempotent — safe to re-run.

-- 1. Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Helpers
CREATE OR REPLACE FUNCTION is_admin() RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT raw_app_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin',
    false
  );
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

-- 3. Tables
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
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_variants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id TEXT NOT NULL,
  variant_name TEXT NOT NULL,
  size_label TEXT,
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

-- 5. Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user() RETURNS TRIGGER AS $$
DECLARE
  cust_code TEXT;
BEGIN
  cust_code := 'CUST-' || LPAD(nextval('customer_code_seq'::REGCLASS)::TEXT, 5, '0');
  INSERT INTO public.profiles (id, email, name, mobile, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'mobile', NEW.raw_user_meta_data->>'phone', ''),
    CASE WHEN NEW.email = 'admin@koreanfriedchicken.com' THEN 'admin' ELSE 'customer' END
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Ensure customer_code_seq exists
CREATE SEQUENCE IF NOT EXISTS customer_code_seq START 1;

-- 6. RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_counter ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_settings ENABLE ROW LEVEL SECURITY;

-- Profiles
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='profiles' AND policyname='profiles_select_own') THEN
    CREATE POLICY profiles_select_own ON profiles FOR SELECT USING (id = auth.uid() OR is_admin());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='profiles' AND policyname='profiles_update_own') THEN
    CREATE POLICY profiles_update_own ON profiles FOR UPDATE USING (id = auth.uid());
  END IF;
END $$;

-- Categories
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='categories' AND policyname='categories_read_all') THEN
    CREATE POLICY categories_read_all ON categories FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='categories' AND policyname='categories_admin_all') THEN
    CREATE POLICY categories_admin_all ON categories FOR ALL USING (is_admin());
  END IF;
END $$;

-- Products
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='products' AND policyname='products_read_all') THEN
    CREATE POLICY products_read_all ON products FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='products' AND policyname='products_admin_all') THEN
    CREATE POLICY products_admin_all ON products FOR ALL USING (is_admin());
  END IF;
END $$;

-- Product Variants
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='product_variants' AND policyname='variants_read_all') THEN
    CREATE POLICY variants_read_all ON product_variants FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='product_variants' AND policyname='variants_admin_all') THEN
    CREATE POLICY variants_admin_all ON product_variants FOR ALL USING (is_admin());
  END IF;
END $$;

-- Orders
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='orders' AND policyname='orders_select_own') THEN
    CREATE POLICY orders_select_own ON orders FOR SELECT USING (user_id = auth.uid() OR is_admin());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='orders' AND policyname='orders_insert_own') THEN
    CREATE POLICY orders_insert_own ON orders FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='orders' AND policyname='orders_update_admin') THEN
    CREATE POLICY orders_update_admin ON orders FOR UPDATE USING (is_admin());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='orders' AND policyname='orders_delete_admin') THEN
    CREATE POLICY orders_delete_admin ON orders FOR DELETE USING (is_admin());
  END IF;
END $$;

-- Order Items
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='order_items' AND policyname='order_items_select') THEN
    CREATE POLICY order_items_select ON order_items FOR SELECT USING (
      EXISTS (SELECT 1 FROM orders WHERE id = order_id AND (user_id = auth.uid() OR is_admin()))
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='order_items' AND policyname='order_items_insert') THEN
    CREATE POLICY order_items_insert ON order_items FOR INSERT WITH CHECK (
      EXISTS (SELECT 1 FROM orders WHERE id = order_id AND (user_id = auth.uid() OR is_admin()))
    );
  END IF;
END $$;

-- Coupons
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='coupons' AND policyname='coupons_read') THEN
    CREATE POLICY coupons_read ON coupons FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='coupons' AND policyname='coupons_admin_all') THEN
    CREATE POLICY coupons_admin_all ON coupons FOR ALL USING (is_admin());
  END IF;
END $$;

-- Invoice counter
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='invoice_counter' AND policyname='invoice_counter_admin') THEN
    CREATE POLICY invoice_counter_admin ON invoice_counter FOR ALL USING (is_admin());
  END IF;
END $$;

-- Store settings
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='store_settings' AND policyname='settings_read') THEN
    CREATE POLICY settings_read ON store_settings FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='store_settings' AND policyname='settings_admin_all') THEN
    CREATE POLICY settings_admin_all ON store_settings FOR ALL USING (is_admin());
  END IF;
END $$;

-- 7. RPCs
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

-- Retail decrement stock (unit-aware)
CREATE OR REPLACE FUNCTION retail_decrement_stock(
  p_product_id BIGINT,
  p_quantity NUMERIC,
  p_unit_type TEXT DEFAULT 'unit'
) RETURNS VOID AS $$
BEGIN
  IF p_unit_type = 'unit' THEN
    UPDATE products SET stock_quantity = GREATEST(stock_quantity - p_quantity, 0)
    WHERE id::TEXT = p_product_id::TEXT;
  ELSIF p_unit_type = 'weight' THEN
    UPDATE products SET stock_quantity = GREATEST(stock_quantity - (p_quantity / 1000.0), 0)
    WHERE id::TEXT = p_product_id::TEXT;
  ELSE
    UPDATE products SET stock_quantity = GREATEST(stock_quantity - p_quantity, 0)
    WHERE id::TEXT = p_product_id::TEXT;
  END IF;
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
  v_item_product_id TEXT;
  v_item_variant_id TEXT;
BEGIN
  -- Detect order type
  v_detected_type := COALESCE(p_order_type,
    CASE WHEN p_status = 'pending' AND p_order_mode = 'online' THEN 'online_request'
         ELSE 'pos_sale'
    END
  );

  -- Check if any manual items
  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
    product_id TEXT, variant_id TEXT, name TEXT, product_name TEXT,
    quantity NUMERIC, price NUMERIC, line_total NUMERIC,
    source TEXT, is_manual BOOLEAN
  ) LOOP
    IF COALESCE(v_item.is_manual, false) OR v_item.source = 'manual' OR v_item.product_id IS NULL THEN
      v_detected_type := 'manual_sale';
      EXIT;
    END IF;
  END LOOP;

  -- Get invoice number
  SELECT get_next_invoice_no() INTO v_invoice_no;

  -- Calculate subtotal
  SELECT COALESCE(SUM(line_total), 0) INTO v_subtotal
  FROM jsonb_to_recordset(p_items) AS x(line_total NUMERIC);

  -- Create order
  INSERT INTO orders (
    invoice_no, customer_name, phone, address, items, subtotal,
    shipping, total, status, order_mode, order_type,
    delivery_charge, discount_amount, manual_discount_amount,
    manual_discount_type, manual_discount_value, coupon_code, coupon_percentage
  ) VALUES (
    v_invoice_no, p_customer_name, p_phone, p_address, p_items, v_subtotal,
    p_shipping,
    GREATEST(v_subtotal + COALESCE(p_shipping,0) + COALESCE(p_delivery_charge,0)
      - COALESCE(p_discount_amount,0) - COALESCE(p_manual_discount_amount,0), 0),
    p_status, p_order_mode, v_detected_type,
    p_delivery_charge, p_discount_amount, p_manual_discount_amount,
    p_manual_discount_type, p_manual_discount_value, p_coupon_code, p_coupon_percentage
  ) RETURNING id INTO v_order_id;

  -- Insert order items and decrement stock
  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
    product_id TEXT, variant_id TEXT, name TEXT, product_name TEXT,
    variant_name TEXT, tamil_name TEXT, quantity NUMERIC, unit TEXT,
    unit_type TEXT, base_quantity NUMERIC, base_price NUMERIC,
    line_total NUMERIC, image_url TEXT, source TEXT, is_manual BOOLEAN, note TEXT
  ) LOOP
    v_is_manual := COALESCE(v_item.is_manual, false) OR v_item.source = 'manual';

    INSERT INTO order_items (
      order_id, product_id, variant_id, product_name, variant_name,
      product_tamil_name, quantity, unit, unit_type, base_quantity,
      base_price, line_total, image_url, is_manual, note
    ) VALUES (
      v_order_id,
      v_item.product_id,
      v_item.variant_id,
      COALESCE(v_item.product_name, v_item.name, 'Item'),
      v_item.variant_name,
      v_item.tamil_name,
      COALESCE(v_item.quantity, 1),
      COALESCE(v_item.unit, 'piece'),
      COALESCE(v_item.unit_type, 'unit'),
      COALESCE(v_item.base_quantity, 1),
      COALESCE(v_item.base_price, 0),
      COALESCE(v_item.line_total, 0),
      v_item.image_url,
      v_is_manual,
      v_item.note
    );

    -- Decrement stock
    IF NOT v_is_manual AND v_item.product_id IS NOT NULL THEN
      IF v_item.variant_id IS NOT NULL AND v_item.variant_id <> '' THEN
        BEGIN
          UPDATE product_variants
          SET stock = GREATEST(stock - COALESCE(v_item.quantity, 1), 0)
          WHERE id = v_item.variant_id::UUID;
        EXCEPTION WHEN OTHERS THEN
          -- If UUID cast fails, try as text
          UPDATE product_variants
          SET stock = GREATEST(stock - COALESCE(v_item.quantity, 1), 0)
          WHERE id::TEXT = v_item.variant_id;
        END;
      ELSE
        PERFORM retail_decrement_stock(
          v_item.product_id::BIGINT,
          COALESCE(v_item.quantity, 1),
          COALESCE(v_item.unit_type, 'unit')
        );
      END IF;
    END IF;
  END LOOP;

  -- Update coupon usage
  IF p_coupon_code IS NOT NULL AND p_coupon_code <> '' THEN
    UPDATE coupons SET usage_count = COALESCE(usage_count, 0) + 1
    WHERE code = p_coupon_code;
  END IF;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'invoice_no', v_invoice_no
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Indexes
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

-- 9. Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE order_items;
ALTER PUBLICATION supabase_realtime ADD TABLE products;

-- 10. Seed data
-- Categories
INSERT INTO categories (name_en, sort_order) VALUES
  ('Chicken', 1),
  ('Sides', 2),
  ('Burgers & Wraps', 3),
  ('Beverages', 4)
ON CONFLICT DO NOTHING;

-- Store settings
INSERT INTO store_settings (name, owner_name, phone, address, gst_enabled)
SELECT 'Korean Fried Chicken', 'Sulficker Roshan N', '+91 9342489391',
  'Nanjappa Garden, Selvapuram, SBI Bank Opposite, Shivalaya Mahal Road, Komarapalayam, Coimbatore',
  false
WHERE NOT EXISTS (SELECT 1 FROM store_settings);

-- Products
DO $$
DECLARE
  cat_chicken BIGINT; cat_sides BIGINT; cat_wraps BIGINT;
BEGIN
  SELECT id INTO cat_chicken FROM categories WHERE name_en = 'Chicken' LIMIT 1;
  SELECT id INTO cat_sides FROM categories WHERE name_en = 'Sides' LIMIT 1;
  SELECT id INTO cat_wraps FROM categories WHERE name_en = 'Burgers & Wraps' LIMIT 1;

  INSERT INTO products (name, category, category_id, price, description, sort_order, image)
  VALUES
    ('Bone Shot', 'Chicken', cat_chicken, 120.00, 'Crispy Korean fried chicken bone-in pieces, perfectly seasoned and fried to golden perfection.', 1, '/assets/images/default-product.jpg'),
    ('Big Shot', 'Chicken', cat_chicken, 180.00, 'Large boneless chicken pieces with our signature Korean sauce — a crowd favourite.', 2, '/assets/images/default-product.jpg'),
    ('Strips', 'Chicken', cat_chicken, 150.00, 'Tender chicken strips, light and crispy. Served with your choice of dipping sauce.', 3, '/assets/images/default-product.jpg'),
    ('Loaded Fries', 'Sides', cat_sides, 130.00, 'Golden french fries loaded with cheese, sauce, and your choice of chicken topping.', 4, '/assets/images/default-product.jpg'),
    ('French Fries', 'Sides', cat_sides, 70.00, 'Classic crispy french fries, salted and served hot.', 5, '/assets/images/default-product.jpg'),
    ('Wrap', 'Burgers & Wraps', cat_wraps, 140.00, 'Soft tortilla wrap filled with crispy chicken, fresh veggies, and tangy sauce.', 6, '/assets/images/default-product.jpg'),
    ('Burger', 'Burgers & Wraps', cat_wraps, 160.00, 'Juicy chicken burger with lettuce, tomato, cheese, and our special sauce in a soft bun.', 7, '/assets/images/default-product.jpg')
  ON CONFLICT DO NOTHING;
END $$;

-- Invoice counter seed
INSERT INTO invoice_counter (id, counter, year)
SELECT 1, 0, EXTRACT(YEAR FROM NOW())
WHERE NOT EXISTS (SELECT 1 FROM invoice_counter);
