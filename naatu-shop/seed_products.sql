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
  ('Pooja Essentials', 'பூஜை அத்தியாவசியங்கள்', true, 10),
  ('Ritual Ingredients', 'சடங்கு பொருட்கள்', true, 20),
  ('Dairy & Fluids', 'பால் மற்றும் திரவங்கள்', true, 30),
  ('Ritual Bundles', 'சடங்கு தொகுப்புகள்', true, 40),
  ('Fruits & Flowers', 'பழம் மற்றும் மலர்கள்', true, 50),
  ('Household Utility', 'வீட்டு பயன்பாடு', true, 60)
ON CONFLICT (name_en) DO UPDATE
SET name_ta = EXCLUDED.name_ta,
    is_active = EXCLUDED.is_active,
    sort_order = EXCLUDED.sort_order;

WITH seed_data AS (
  SELECT * FROM (VALUES
    -- UNIT
    ('Kungumam', 'குங்குமம்', 'Pooja Essentials', 20::NUMERIC, NULL::NUMERIC, 'unit', 'piece', 1::NUMERIC, 180::NUMERIC, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Kungumam packet', 10),
    ('Vibhoothi', 'விபூதி', 'Pooja Essentials', 15, NULL, 'unit', 'piece', 1, 220, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Sacred ash packet', 11),
    ('Karpooram', 'கர்பூரம்', 'Pooja Essentials', 35, NULL, 'unit', 'piece', 1, 140, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Camphor tablets', 12),
    ('Oodhupathi', 'ஊதுபத்தி', 'Pooja Essentials', 40, NULL, 'unit', 'piece', 1, 120, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Incense stick bundle', 13),
    ('Kali Paakku', 'காளி பாக்கு', 'Ritual Ingredients', 30, NULL, 'unit', 'piece', 1, 90, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Ritual areca mix', 14),
    ('Kottai Paakku', 'கொட்டை பாக்கு', 'Ritual Ingredients', 28, NULL, 'unit', 'piece', 1, 110, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Whole areca nut pack', 15),
    ('Navagraha Bit', 'நவகிரக பிட்டு', 'Pooja Essentials', 55, NULL, 'unit', 'piece', 1, 70, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Navagraha offering set', 16),
    ('Veshti Thundu', 'வேஷ்டி துண்டு', 'Pooja Essentials', 120, NULL, 'unit', 'piece', 1, 45, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Small veshti cloth', 17),
    ('Kalasa Sombu', 'கலச சொம்பு', 'Pooja Essentials', 180, NULL, 'unit', 'piece', 1, 35, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Kalasa vessel', 18),
    ('Thambala Thattu', 'தாம்பாள தட்டு', 'Pooja Essentials', 240, NULL, 'unit', 'piece', 1, 28, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Pooja plate', 19),
    ('Kuthu Vilakku', 'குத்துவிளக்கு', 'Pooja Essentials', 450, NULL, 'unit', 'piece', 1, 18, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Traditional lamp', 20),
    ('Swami Padam', 'சுவாமி படம்', 'Pooja Essentials', 90, NULL, 'unit', 'piece', 1, 60, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Divine photo frame', 21),
    ('News Paper', 'செய்தித்தாள்', 'Household Utility', 8, NULL, 'unit', 'piece', 1, 600, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Packing newspaper sheet', 22),
    ('Sengal', 'செங்கல்', 'Household Utility', 14, NULL, 'unit', 'piece', 1, 300, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Brick unit', 23),
    ('Manal', 'மணல்', 'Household Utility', 25, NULL, 'unit', 'piece', 1, 150, 'piece', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Sand packet', 24),

    -- WEIGHT
    ('Manjal Podi', 'மஞ்சள் பொடி', 'Ritual Ingredients', 50, NULL, 'weight', 'g', 100, 12000, 'g', true, '[{"quantity":100,"unit":"g","label":"100g"},{"quantity":250,"unit":"g","label":"250g"},{"quantity":500,"unit":"g","label":"500g"}]'::JSONB, '/assets/images/default-herb.jpg', 'Turmeric powder', 110),
    ('Sandhanam', 'சந்தனம்', 'Ritual Ingredients', 130, NULL, 'weight', 'g', 50, 6000, 'g', true, '[{"quantity":50,"unit":"g","label":"50g"},{"quantity":100,"unit":"g","label":"100g"}]'::JSONB, '/assets/images/default-herb.jpg', 'Sandal powder', 111),
    ('Elakkai', 'ஏலக்காய்', 'Ritual Ingredients', 120, NULL, 'weight', 'g', 50, 3500, 'g', true, '[{"quantity":50,"unit":"g","label":"50g"},{"quantity":100,"unit":"g","label":"100g"},{"quantity":250,"unit":"g","label":"250g"}]'::JSONB, '/assets/images/default-herb.jpg', 'Cardamom', 112),
    ('Mundhiri', 'முந்திரி', 'Ritual Ingredients', 95, NULL, 'weight', 'g', 100, 8000, 'g', true, '[{"quantity":100,"unit":"g","label":"100g"},{"quantity":250,"unit":"g","label":"250g"},{"quantity":500,"unit":"g","label":"500g"}]'::JSONB, '/assets/images/default-herb.jpg', 'Cashew nuts', 113),
    ('Dhiratchai', 'திராட்சை', 'Ritual Ingredients', 55, NULL, 'weight', 'g', 100, 9000, 'g', true, '[{"quantity":100,"unit":"g","label":"100g"},{"quantity":250,"unit":"g","label":"250g"}]'::JSONB, '/assets/images/default-herb.jpg', 'Raisins', 114),
    ('Kalkandu', 'கல்கண்டு', 'Ritual Ingredients', 45, NULL, 'weight', 'g', 100, 14000, 'g', true, '[{"quantity":100,"unit":"g","label":"100g"},{"quantity":250,"unit":"g","label":"250g"},{"quantity":500,"unit":"g","label":"500g"}]'::JSONB, '/assets/images/default-herb.jpg', 'Rock sugar', 115),
    ('Naattu Sarkkarai', 'நாட்டு சர்க்கரை', 'Ritual Ingredients', 40, NULL, 'weight', 'g', 100, 18000, 'g', true, '[{"quantity":100,"unit":"g","label":"100g"},{"quantity":500,"unit":"g","label":"500g"},{"quantity":1000,"unit":"g","label":"1kg"}]'::JSONB, '/assets/images/default-herb.jpg', 'Country sugar', 116),
    ('Arisi Pori', 'அரிசி பொறி', 'Ritual Ingredients', 30, NULL, 'weight', 'g', 100, 15000, 'g', true, '[{"quantity":100,"unit":"g","label":"100g"},{"quantity":250,"unit":"g","label":"250g"}]'::JSONB, '/assets/images/default-herb.jpg', 'Puffed rice', 117),
    ('Nelpori', 'நெல் பொறி', 'Ritual Ingredients', 32, NULL, 'weight', 'g', 100, 9000, 'g', true, '[{"quantity":100,"unit":"g","label":"100g"},{"quantity":250,"unit":"g","label":"250g"}]'::JSONB, '/assets/images/default-herb.jpg', 'Paddy puff', 118),
    ('Pacharisi', 'பச்சரிசி', 'Ritual Ingredients', 38, NULL, 'weight', 'g', 100, 30000, 'g', true, '[{"quantity":500,"unit":"g","label":"500g"},{"quantity":1000,"unit":"g","label":"1kg"}]'::JSONB, '/assets/images/default-herb.jpg', 'Raw rice', 119),
    ('Navadhaniyam Set', 'நவதானியம் செட்', 'Ritual Ingredients', 160, NULL, 'weight', 'g', 500, 6000, 'g', false, '[{"quantity":500,"unit":"g","label":"500g"}]'::JSONB, '/assets/images/default-herb.jpg', 'Nine grain mix', 120),
    ('Samithu Kattu', 'சமித்து கட்டு', 'Ritual Ingredients', 70, NULL, 'weight', 'g', 500, 10000, 'g', false, '[{"quantity":500,"unit":"g","label":"500g"},{"quantity":1000,"unit":"g","label":"1kg"}]'::JSONB, '/assets/images/default-herb.jpg', 'Sacred twig bundle by weight', 121),
    ('Dharbai Kattu', 'தர்பை கட்டு', 'Ritual Ingredients', 85, NULL, 'weight', 'g', 250, 5000, 'g', false, '[{"quantity":250,"unit":"g","label":"250g"},{"quantity":500,"unit":"g","label":"500g"}]'::JSONB, '/assets/images/default-herb.jpg', 'Dharbai grass pack', 122),
    ('Kolamavu', 'கோலமாவு', 'Ritual Ingredients', 28, NULL, 'weight', 'g', 500, 22000, 'g', true, '[{"quantity":500,"unit":"g","label":"500g"},{"quantity":1000,"unit":"g","label":"1kg"}]'::JSONB, '/assets/images/default-herb.jpg', 'Kolam powder', 123),
    ('Arugampul', 'அருகம்புல்', 'Ritual Ingredients', 42, NULL, 'weight', 'g', 250, 4000, 'g', true, '[{"quantity":250,"unit":"g","label":"250g"},{"quantity":500,"unit":"g","label":"500g"}]'::JSONB, '/assets/images/default-herb.jpg', 'Bermuda grass', 124),

    -- VOLUME
    ('Paal', 'பால்', 'Dairy & Fluids', 32, NULL, 'volume', 'ml', 500, 24000, 'ml', true, '[{"quantity":500,"unit":"ml","label":"500ml"},{"quantity":1000,"unit":"ml","label":"1L"}]'::JSONB, '/assets/images/default-herb.jpg', 'Milk', 210),
    ('Then', 'தேன்', 'Dairy & Fluids', 190, NULL, 'volume', 'ml', 500, 12000, 'ml', true, '[{"quantity":250,"unit":"ml","label":"250ml"},{"quantity":500,"unit":"ml","label":"500ml"}]'::JSONB, '/assets/images/default-herb.jpg', 'Honey', 211),
    ('Nei', 'நெய்', 'Dairy & Fluids', 260, NULL, 'volume', 'ml', 500, 8000, 'ml', true, '[{"quantity":200,"unit":"ml","label":"200ml"},{"quantity":500,"unit":"ml","label":"500ml"}]'::JSONB, '/assets/images/default-herb.jpg', 'Ghee', 212),
    ('Panneer Bottle', 'பன்னீர் பாட்டில்', 'Dairy & Fluids', 35, NULL, 'volume', 'ml', 200, 10000, 'ml', true, '[{"quantity":200,"unit":"ml","label":"200ml"},{"quantity":500,"unit":"ml","label":"500ml"}]'::JSONB, '/assets/images/default-herb.jpg', 'Rose water bottle', 213),
    ('Mineral Water', 'மினரல் வாட்டர்', 'Dairy & Fluids', 20, NULL, 'volume', 'ml', 1000, 36000, 'ml', true, '[{"quantity":500,"unit":"ml","label":"500ml"},{"quantity":1000,"unit":"ml","label":"1L"}]'::JSONB, '/assets/images/default-herb.jpg', 'Mineral water', 214),

    -- BUNDLE / MIXED
    ('Poornahuthi Saamaan', 'பூர்ணாஹுதி சாமான்', 'Ritual Bundles', 650, NULL, 'bundle', 'bundle', 1, 40, 'bundle', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Complete poornahuthi material set', 310),
    ('Poornahuthi Pattu Thuni', 'பூர்ணாஹுதி பட்டு துணி', 'Ritual Bundles', 220, NULL, 'bundle', 'bundle', 1, 55, 'bundle', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Silk cloth set for poornahuthi', 311),
    ('Pazha Vagaigal', 'பழ வகைகள்', 'Fruits & Flowers', 180, NULL, 'bundle', 'bundle', 1, 65, 'bundle', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Mixed fruit offering bundle', 312),
    ('Flowers', 'மலர்கள்', 'Fruits & Flowers', 90, NULL, 'bundle', 'bundle', 1, 120, 'bundle', false, '[]'::JSONB, '/assets/images/default-herb.jpg', 'Flower bundle', 313)
  ) AS v(
    name,
    tamil_name,
    category_name,
    price,
    offer_price,
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
  s.offer_price,
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
