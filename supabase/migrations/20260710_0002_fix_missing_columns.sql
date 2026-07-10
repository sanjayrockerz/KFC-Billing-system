-- ── Korean Fried Chicken — Fix Missing Columns & Clean Old Data ──
-- Run THIS after 20260710_0001 if you still get schema errors.
-- Also safe to run standalone on a fresh project.

-- 1. Add missing columns to products (idempotent)
DO $$ BEGIN
  ALTER TABLE products ADD COLUMN IF NOT EXISTS stock NUMERIC(10,3) DEFAULT 0;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE products ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'piece';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE products ADD COLUMN IF NOT EXISTS remedy JSONB DEFAULT '[]'::jsonb;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE products ADD COLUMN IF NOT EXISTS purchase_price NUMERIC(10,2) DEFAULT 0;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE products ADD COLUMN IF NOT EXISTS mrp NUMERIC(10,2) DEFAULT 0;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE products ADD COLUMN IF NOT EXISTS gst_percent NUMERIC(5,2) DEFAULT 0;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE products ADD COLUMN IF NOT EXISTS opening_stock NUMERIC(10,3) DEFAULT 0;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE products ADD COLUMN IF NOT EXISTS low_stock_alert NUMERIC(10,3) DEFAULT 5;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE products ADD COLUMN IF NOT EXISTS supplier TEXT;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE products ADD COLUMN IF NOT EXISTS size TEXT;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE products ADD COLUMN IF NOT EXISTS color TEXT;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 2. Add missing columns to product_variants
DO $$ BEGIN
  ALTER TABLE product_variants ADD COLUMN IF NOT EXISTS group_name TEXT;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 3. Add stock column to products if using stock_quantity as fallback
UPDATE products SET stock = stock_quantity WHERE stock IS NULL AND stock_quantity IS NOT NULL;
UPDATE products SET stock_quantity = stock WHERE stock_quantity IS NULL AND stock IS NOT NULL;
UPDATE products SET stock = 100 WHERE stock IS NULL;

-- 4. Clear old seed data (shawl products, herbal stuff from old template)
DELETE FROM order_items;
DELETE FROM orders;
DELETE FROM product_variants;
DELETE FROM products WHERE name NOT IN ('Bone Shot','Big Shot','Strips','Loaded Fries','French Fries','Wrap','Burger');
DELETE FROM categories WHERE name_en NOT IN ('Chicken','Sides','Burgers & Wraps','Beverages');

-- 5. Remove default image placeholders
ALTER TABLE products ALTER COLUMN image SET DEFAULT '';
ALTER TABLE products ALTER COLUMN image_url SET DEFAULT '';

-- 7. Re-ensure KFC categories exist
INSERT INTO categories (name_en, sort_order) VALUES
  ('Chicken', 1), ('Sides', 2), ('Burgers & Wraps', 3), ('Beverages', 4)
ON CONFLICT DO NOTHING;

-- 8. Re-ensure KFC products exist
DO $$
DECLARE
  cat_chicken BIGINT; cat_sides BIGINT; cat_wraps BIGINT;
BEGIN
  SELECT id INTO cat_chicken FROM categories WHERE name_en = 'Chicken' LIMIT 1;
  SELECT id INTO cat_sides FROM categories WHERE name_en = 'Sides' LIMIT 1;
  SELECT id INTO cat_wraps FROM categories WHERE name_en = 'Burgers & Wraps' LIMIT 1;

  INSERT INTO products (name, category, category_id, price, stock, description, sort_order) VALUES
    ('Bone Shot', 'Chicken', cat_chicken, 120.00, 100, 'Crispy Korean fried chicken bone-in pieces.', 1),
    ('Big Shot', 'Chicken', cat_chicken, 180.00, 100, 'Large boneless chicken pieces with Korean sauce.', 2),
    ('Strips', 'Chicken', cat_chicken, 150.00, 100, 'Tender crispy chicken strips with dip.', 3),
    ('Loaded Fries', 'Sides', cat_sides, 130.00, 100, 'Fries loaded with cheese, sauce & chicken topping.', 4),
    ('French Fries', 'Sides', cat_sides, 70.00, 100, 'Classic crispy salted french fries.', 5),
    ('Wrap', 'Burgers & Wraps', cat_wraps, 140.00, 100, 'Tortilla wrap with crispy chicken, veggies & sauce.', 6),
    ('Burger', 'Burgers & Wraps', cat_wraps, 160.00, 100, 'Chicken burger with lettuce, tomato, cheese & sauce.', 7)
  ON CONFLICT DO NOTHING;
END $$;

-- 9. Update store settings
INSERT INTO store_settings (name, owner_name, phone, address, gst_enabled)
SELECT 'Korean Fried Chicken', 'Sulficker Roshan N', '+91 9342489391',
  'Nanjappa Garden, Selvapuram, SBI Bank Opposite, Shivalaya Mahal Road, Komarapalayam, Coimbatore', false
WHERE NOT EXISTS (SELECT 1 FROM store_settings);

-- 10. Ensure RLS policies allow public access
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS products_public ON products;
CREATE POLICY products_public ON products FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS variants_public ON product_variants;
CREATE POLICY variants_public ON product_variants FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS categories_public ON categories;
CREATE POLICY categories_public ON categories FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS orders_public ON orders;
CREATE POLICY orders_public ON orders FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS order_items_public ON order_items;
CREATE POLICY order_items_public ON order_items FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS coupons_public ON coupons;
CREATE POLICY coupons_public ON coupons FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE invoice_counter ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS invoice_counter_public ON invoice_counter;
CREATE POLICY invoice_counter_public ON invoice_counter FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE store_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS settings_public ON store_settings;
CREATE POLICY settings_public ON store_settings FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profiles_public ON profiles;
CREATE POLICY profiles_public ON profiles FOR ALL USING (true) WITH CHECK (true);
