-- Admin template setup for inventory + POS billing + analytics
-- Run after your core schema/migrations. Safe to re-run.

-- Required billing columns used by the admin app
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS order_mode TEXT NOT NULL DEFAULT 'offline',
  ADD COLUMN IF NOT EXISTS order_type TEXT NOT NULL DEFAULT 'pos_sale',
  ADD COLUMN IF NOT EXISTS delivery_charge NUMERIC(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS coupon_code TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS coupon_percentage NUMERIC(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS manual_discount_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS manual_discount_type TEXT NOT NULL DEFAULT 'flat',
  ADD COLUMN IF NOT EXISTS manual_discount_value NUMERIC(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS is_manual BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS public.coupons (
  id BIGSERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  percentage NUMERIC(5,2) NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  expiry_date DATE,
  usage_limit INTEGER,
  usage_count INTEGER NOT NULL DEFAULT 0,
  min_order_value NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS coupons_admin_all ON public.coupons;
DROP POLICY IF EXISTS coupons_auth_read ON public.coupons;
CREATE POLICY coupons_admin_all ON public.coupons
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
CREATE POLICY coupons_auth_read ON public.coupons
  FOR SELECT TO authenticated
  USING (is_active = true);

INSERT INTO public.categories (name_en, name_ta, is_active, sort_order)
VALUES
  ('Shirts', 'Shirts', true, 1),
  ('T-Shirts', 'T-Shirts', true, 2),
  ('Jeans', 'Jeans', true, 3),
  ('Trousers', 'Trousers', true, 4),
  ('Accessories', 'Accessories', true, 5),
  ('Footwear', 'Footwear', true, 6)
ON CONFLICT (name_en) DO UPDATE
SET is_active = EXCLUDED.is_active,
    sort_order = EXCLUDED.sort_order;

DO $$
DECLARE
  cat_shirts BIGINT;
  cat_tshirts BIGINT;
  cat_jeans BIGINT;
  cat_trousers BIGINT;
  cat_accessories BIGINT;
  cat_footwear BIGINT;
BEGIN
  SELECT id INTO cat_shirts FROM public.categories WHERE name_en = 'Shirts';
  SELECT id INTO cat_tshirts FROM public.categories WHERE name_en = 'T-Shirts';
  SELECT id INTO cat_jeans FROM public.categories WHERE name_en = 'Jeans';
  SELECT id INTO cat_trousers FROM public.categories WHERE name_en = 'Trousers';
  SELECT id INTO cat_accessories FROM public.categories WHERE name_en = 'Accessories';
  SELECT id INTO cat_footwear FROM public.categories WHERE name_en = 'Footwear';

  INSERT INTO public.products (
    name, name_ta, tamil_name, category, category_id, remedy, price, offer_price,
    unit_type, unit_label, base_quantity, stock_quantity, stock_unit, allow_decimal_quantity,
    predefined_options, description, description_ta, benefits, benefits_ta,
    image, image_url, stock, unit, rating, is_active, sort_order
  )
  SELECT *
  FROM (
    VALUES
      ('Plain Shirt', 'Plain Shirt', 'Plain Shirt', 'Shirts', cat_shirts, ARRAY['Catalog'], 1000::numeric, NULL::numeric, 'unit', 'pc', 1::numeric, 80::numeric, 'pc', false, '[]'::jsonb, 'Classic full-sleeve shirt for billing demo.', '', 'Inventory Demo', '', '', '', 80, '1pc', 4.8::numeric, true, 1),
      ('Formal White Shirt', 'Formal White Shirt', 'Formal White Shirt', 'Shirts', cat_shirts, ARRAY['Catalog'], 1450::numeric, 1299::numeric, 'unit', 'pc', 1::numeric, 45::numeric, 'pc', false, '[]'::jsonb, 'Formal office shirt with slim silhouette.', '', 'Inventory Demo', '', '', '', 45, '1pc', 4.8::numeric, true, 2),
      ('Polo T-Shirt', 'Polo T-Shirt', 'Polo T-Shirt', 'T-Shirts', cat_tshirts, ARRAY['Catalog'], 899::numeric, 799::numeric, 'unit', 'pc', 1::numeric, 72::numeric, 'pc', false, '[]'::jsonb, 'Smart casual polo for quick POS demos.', '', 'Inventory Demo', '', '', '', 72, '1pc', 4.7::numeric, true, 3),
      ('Graphic Tee', 'Graphic Tee', 'Graphic Tee', 'T-Shirts', cat_tshirts, ARRAY['Catalog'], 699::numeric, NULL::numeric, 'unit', 'pc', 1::numeric, 58::numeric, 'pc', false, '[]'::jsonb, 'Graphic t-shirt seeded for analytics charts.', '', 'Inventory Demo', '', '', '', 58, '1pc', 4.6::numeric, true, 4),
      ('Blue Jeans', 'Blue Jeans', 'Blue Jeans', 'Jeans', cat_jeans, ARRAY['Catalog'], 1799::numeric, 1599::numeric, 'unit', 'pc', 1::numeric, 33::numeric, 'pc', false, '[]'::jsonb, 'Denim product used in seeded POS orders.', '', 'Inventory Demo', '', '', '', 33, '1pc', 4.8::numeric, true, 5),
      ('Black Chinos', 'Black Chinos', 'Black Chinos', 'Trousers', cat_trousers, ARRAY['Catalog'], 1499::numeric, NULL::numeric, 'unit', 'pc', 1::numeric, 27::numeric, 'pc', false, '[]'::jsonb, 'Slim chinos for inventory and billing tests.', '', 'Inventory Demo', '', '', '', 27, '1pc', 4.7::numeric, true, 6),
      ('Leather Belt', 'Leather Belt', 'Leather Belt', 'Accessories', cat_accessories, ARRAY['Catalog'], 599::numeric, 499::numeric, 'unit', 'pc', 1::numeric, 39::numeric, 'pc', false, '[]'::jsonb, 'Accessory item for coupon and order mix testing.', '', 'Inventory Demo', '', '', '', 39, '1pc', 4.5::numeric, true, 7),
      ('Canvas Shoes', 'Canvas Shoes', 'Canvas Shoes', 'Footwear', cat_footwear, ARRAY['Catalog'], 1999::numeric, 1799::numeric, 'unit', 'pair', 1::numeric, 22::numeric, 'pair', false, '[]'::jsonb, 'Footwear demo product for higher bill values.', '', 'Inventory Demo', '', '', '', 22, '1pair', 4.7::numeric, true, 8)
  ) AS seed_rows (
    name, name_ta, tamil_name, category, category_id, remedy, price, offer_price,
    unit_type, unit_label, base_quantity, stock_quantity, stock_unit, allow_decimal_quantity,
    predefined_options, description, description_ta, benefits, benefits_ta,
    image, image_url, stock, unit, rating, is_active, sort_order
  )
  WHERE NOT EXISTS (
    SELECT 1 FROM public.products p WHERE p.name = seed_rows.name
  );
END $$;

INSERT INTO public.coupons (code, percentage, is_active, usage_limit, usage_count, min_order_value)
VALUES
  ('WELCOME10', 10, true, 100, 0, 1000),
  ('FLAT5', 5, true, 200, 0, 500),
  ('VIP15', 15, true, 50, 0, 2500)
ON CONFLICT (code) DO UPDATE
SET percentage = EXCLUDED.percentage,
    is_active = EXCLUDED.is_active,
    usage_limit = EXCLUDED.usage_limit,
    min_order_value = EXCLUDED.min_order_value;

DO $$
DECLARE
  shirt_id BIGINT;
  polo_id BIGINT;
  jeans_id BIGINT;
  belt_id BIGINT;
  shoe_id BIGINT;
BEGIN
  SELECT id INTO shirt_id FROM public.products WHERE name = 'Plain Shirt' LIMIT 1;
  SELECT id INTO polo_id FROM public.products WHERE name = 'Polo T-Shirt' LIMIT 1;
  SELECT id INTO jeans_id FROM public.products WHERE name = 'Blue Jeans' LIMIT 1;
  SELECT id INTO belt_id FROM public.products WHERE name = 'Leather Belt' LIMIT 1;
  SELECT id INTO shoe_id FROM public.products WHERE name = 'Canvas Shoes' LIMIT 1;

  INSERT INTO public.orders (
    id, invoice_no, user_id, customer_name, phone, address, items, subtotal, shipping, total, status,
    order_mode, order_type, delivery_charge, discount_amount, coupon_code, coupon_percentage,
    manual_discount_amount, manual_discount_type, manual_discount_value, created_at, updated_at
  )
  VALUES
    ('00000000-0000-0000-0000-000000000101', 'INV-TEMPLATE-001', NULL, 'Arun Kumar', '9876543210', 'Walk-in Counter', '[]'::jsonb, 1000, 0, 1000, 'completed', 'offline', 'pos_sale', 0, 0, '', 0, 0, 'flat', 0, NOW() - INTERVAL '25 days', NOW()),
    ('00000000-0000-0000-0000-000000000102', 'INV-TEMPLATE-002', NULL, 'Deepa R', '9123456780', 'Walk-in Counter', '[]'::jsonb, 2398, 0, 2158.20, 'completed', 'offline', 'pos_sale', 0, 239.80, 'WELCOME10', 10, 0, 'flat', 0, NOW() - INTERVAL '18 days', NOW()),
    ('00000000-0000-0000-0000-000000000103', 'INV-TEMPLATE-003', NULL, 'Vignesh S', '9988776655', 'Online POS', '[]'::jsonb, 1799, 90, 1889, 'completed', 'online', 'pos_sale', 90, 0, '', 0, 0, 'flat', 0, NOW() - INTERVAL '11 days', NOW()),
    ('00000000-0000-0000-0000-000000000104', 'INV-TEMPLATE-004', NULL, 'Meena K', '9012345678', 'Walk-in Counter', '[]'::jsonb, 2498, 0, 2398, 'completed', 'offline', 'pos_sale', 0, 0, '', 0, 100, 'flat', 100, NOW() - INTERVAL '7 days', NOW()),
    ('00000000-0000-0000-0000-000000000105', 'INV-TEMPLATE-005', NULL, 'Rahul P', '9090909090', 'Walk-in Counter', '[]'::jsonb, 599, 0, 599, 'completed', 'offline', 'manual_sale', 0, 0, '', 0, 0, 'flat', 0, NOW() - INTERVAL '3 days', NOW()),
    ('00000000-0000-0000-0000-000000000106', 'INV-TEMPLATE-006', NULL, 'Sowmya N', '9345678901', 'Walk-in Counter', '[]'::jsonb, 2898, 60, 2668, 'pending', 'offline', 'pos_sale', 60, 0, '', 0, 230, 'flat', 230, NOW() - INTERVAL '1 day', NOW())
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.order_items (
    order_id, product_id, product_name, product_tamil_name, quantity, unit, unit_type, base_quantity, base_price, line_total, image_url, is_manual, created_at
  )
  VALUES
    ('00000000-0000-0000-0000-000000000101', shirt_id, 'Plain Shirt', 'Plain Shirt', 1, 'pc', 'unit', 1, 1000, 1000, '', false, NOW() - INTERVAL '25 days'),
    ('00000000-0000-0000-0000-000000000102', polo_id, 'Polo T-Shirt', 'Polo T-Shirt', 1, 'pc', 'unit', 1, 899, 899, '', false, NOW() - INTERVAL '18 days'),
    ('00000000-0000-0000-0000-000000000102', jeans_id, 'Blue Jeans', 'Blue Jeans', 1, 'pc', 'unit', 1, 1499, 1499, '', false, NOW() - INTERVAL '18 days'),
    ('00000000-0000-0000-0000-000000000103', shoe_id, 'Canvas Shoes', 'Canvas Shoes', 1, 'pair', 'unit', 1, 1799, 1799, '', false, NOW() - INTERVAL '11 days'),
    ('00000000-0000-0000-0000-000000000104', jeans_id, 'Blue Jeans', 'Blue Jeans', 1, 'pc', 'unit', 1, 1799, 1799, '', false, NOW() - INTERVAL '7 days'),
    ('00000000-0000-0000-0000-000000000104', belt_id, 'Leather Belt', 'Leather Belt', 1, 'pc', 'unit', 1, 699, 699, '', false, NOW() - INTERVAL '7 days'),
    ('00000000-0000-0000-0000-000000000105', NULL, 'Custom Alteration', NULL, 1, 'pc', 'unit', 1, 599, 599, NULL, true, NOW() - INTERVAL '3 days'),
    ('00000000-0000-0000-0000-000000000106', shirt_id, 'Plain Shirt', 'Plain Shirt', 2, 'pc', 'unit', 1, 1000, 2000, '', false, NOW() - INTERVAL '1 day'),
    ('00000000-0000-0000-0000-000000000106', belt_id, 'Leather Belt', 'Leather Belt', 1, 'pc', 'unit', 1, 898, 898, '', false, NOW() - INTERVAL '1 day')
  ON CONFLICT DO NOTHING;

  UPDATE public.orders o
  SET items = (
    SELECT jsonb_agg(
      jsonb_build_object(
        'product_id', oi.product_id,
        'name', oi.product_name,
        'tamil_name', oi.product_tamil_name,
        'quantity', oi.quantity,
        'unit', oi.unit,
        'unit_type', oi.unit_type,
        'base_quantity', oi.base_quantity,
        'base_price', oi.base_price,
        'line_total', oi.line_total,
        'image_url', oi.image_url,
        'is_manual', oi.is_manual
      ) ORDER BY oi.id
    )
    FROM public.order_items oi
    WHERE oi.order_id = o.id
  )
  WHERE o.id IN (
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000105',
    '00000000-0000-0000-0000-000000000106'
  );

  UPDATE public.coupons
  SET usage_count = 1
  WHERE code = 'WELCOME10';
END $$;

NOTIFY pgrst, 'reload schema';
