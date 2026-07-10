-- Retail POS sample seed script
-- This script is additive: it does not truncate products.

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS name_ta TEXT DEFAULT '';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS tamil_name TEXT DEFAULT '';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category_id BIGINT REFERENCES public.categories(id) ON DELETE SET NULL;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS unit_type TEXT DEFAULT 'unit';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS unit_label TEXT DEFAULT 'piece';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS base_quantity NUMERIC(12,3) DEFAULT 1;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS stock_quantity NUMERIC(12,3) DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS stock_unit TEXT DEFAULT 'piece';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS allow_decimal_quantity BOOLEAN DEFAULT false;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS predefined_options JSONB DEFAULT '[]'::JSONB;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image TEXT DEFAULT '/assets/images/default-herb.jpg';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url TEXT DEFAULT '/assets/images/default-herb.jpg';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS rating NUMERIC(3,1) DEFAULT 4.7;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS remedy TEXT[] DEFAULT '{}';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS offer_price NUMERIC(10,2);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS stock INTEGER DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT '';

INSERT INTO public.categories (name_en, name_ta, is_active, sort_order)
VALUES
  ('Chicken', 'சிக்கன்', true, 10),
  ('Sides', 'சைட்ஸ்', true, 20),
  ('Burgers & Wraps', 'பர்கர் & ரேப்', true, 30),
  ('Beverages', 'பானங்கள்', true, 40),
  ('Combos', 'காம்போஸ்', true, 50)
ON CONFLICT (name_en) DO UPDATE
SET name_ta = EXCLUDED.name_ta,
    is_active = EXCLUDED.is_active,
    sort_order = EXCLUDED.sort_order;

WITH seed_data AS (
  SELECT * FROM (VALUES
    ('Bone Shot', 'போன் ஷாட்', 'Chicken', 150, 'unit', 'piece', 1, 50, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Crispy bone-in fried chicken shot', 10),
    ('Big Shot', 'பிக் ஷாட்', 'Chicken', 250, 'unit', 'piece', 1, 50, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Large boneless fried chicken', 20),
    ('Strips', 'ஸ்ட்ரிப்ஸ்', 'Chicken', 180, 'unit', 'piece', 1, 50, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Crispy chicken strips', 30),
    ('Loaded Fries', 'லோடட் பிரைஸ்', 'Sides', 200, 'unit', 'piece', 1, 40, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Fries loaded with cheese, chicken & sauce', 40),
    ('French Fries', 'பிரெஞ்சு பிரைஸ்', 'Sides', 100, 'unit', 'piece', 1, 60, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Classic crispy french fries', 50),
    ('Wrap', 'ரேப்', 'Burgers & Wraps', 180, 'unit', 'piece', 1, 40, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Chicken wrap with fresh veggies & sauce', 60),
    ('Burger', 'பர்கர்', 'Burgers & Wraps', 200, 'unit', 'piece', 1, 40, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Crispy chicken burger with lettuce & mayo', 70)
  ) AS v(
    name,
    tamil_name,
    category_name,
    price,
    unit_type,
    unit_label,
    base_quantity,
    stock_quantity,
    stock_unit,
    allow_decimal_quantity,
    predefined_options,
    image_url,
    description,
    sort_order
  )
)
INSERT INTO public.products (
  name,
  name_ta,
  tamil_name,
  category,
  category_id,
  remedy,
  price,
  offer_price,
  description,
  benefits,
  image,
  image_url,
  stock,
  stock_quantity,
  stock_unit,
  unit,
  unit_type,
  unit_label,
  base_quantity,
  allow_decimal_quantity,
  predefined_options,
  is_active,
  sort_order,
  rating
)
SELECT
  s.name,
  s.tamil_name,
  s.tamil_name,
  s.category_name,
  c.id,
  '{}'::TEXT[],
  s.price,
  NULL,
  s.description,
  s.description,
  s.image_url,
  s.image_url,
  GREATEST(0, FLOOR(s.stock_quantity)::INTEGER),
  s.stock_quantity,
  s.stock_unit,
  CASE
    WHEN s.unit_type IN ('weight', 'volume') THEN CONCAT(s.base_quantity::TEXT, s.unit_label)
    ELSE s.unit_label
  END,
  s.unit_type,
  s.unit_label,
  s.base_quantity,
  s.allow_decimal_quantity,
  s.predefined_options,
  true,
  s.sort_order,
  4.7
FROM seed_data s
LEFT JOIN public.categories c ON c.name_en = s.category_name
WHERE NOT EXISTS (
  SELECT 1
  FROM public.products p
  WHERE LOWER(p.name) = LOWER(s.name)
);

UPDATE public.products
SET category_id = c.id
FROM public.categories c
WHERE public.products.category_id IS NULL
  AND public.products.category = c.name_en;

SELECT COUNT(*) AS seeded_products FROM public.products;
