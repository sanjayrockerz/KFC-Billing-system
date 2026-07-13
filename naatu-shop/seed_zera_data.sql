-- Seed Data for ZERA
TRUNCATE public.categories CASCADE;
-- Seed script for ZERA POS

-- 1. Create Default Categories
INSERT INTO public.categories (name_en, name_ta) VALUES
('Fartha', 'Fartha'),
('Shawl', 'Shawl'),
('Bridal Shawl', 'Bridal Shawl'),
('Tops', 'Tops'),
('Saree Shawl', 'Saree Shawl'),
('Chudithar', 'Chudithar'),
('Accessories', 'Accessories')
ON CONFLICT DO NOTHING;

-- 2. Create Example Products for 'Shawl'
DO $$
DECLARE
  shawl_cat_id BIGINT;
  bridal_cat_id BIGINT;
  prod_id BIGINT;
BEGIN
  -- Get category IDs
  SELECT id INTO shawl_cat_id FROM public.categories WHERE name_en = 'Shawl' LIMIT 1;
  SELECT id INTO bridal_cat_id FROM public.categories WHERE name_en = 'Bridal Shawl' LIMIT 1;

  IF shawl_cat_id IS NOT NULL THEN
    -- Premium Shawl
    INSERT INTO public.products (name, category, category_id, price, stock, is_active, unit_type, purchase_price, mrp, sku)
    VALUES ('Premium Shawl', 'Shawl', shawl_cat_id, 800, 50, true, 'unit', 500, 1000, 'SHW-PREM')
    RETURNING id INTO prod_id;

    -- Cotton Shawl
    INSERT INTO public.products (name, category, category_id, price, stock, is_active, unit_type, purchase_price, mrp, sku)
    VALUES ('Cotton Shawl', 'Shawl', shawl_cat_id, 400, 100, true, 'unit', 250, 600, 'SHW-COT');

    -- Silk Shawl
    INSERT INTO public.products (name, category, category_id, price, stock, is_active, unit_type, purchase_price, mrp, sku)
    VALUES ('Silk Shawl', 'Shawl', shawl_cat_id, 1200, 30, true, 'unit', 800, 1500, 'SHW-SILK');

    -- Wedding Shawl
    INSERT INTO public.products (name, category, category_id, price, stock, is_active, unit_type, purchase_price, mrp, sku)
    VALUES ('Wedding Shawl', 'Shawl', shawl_cat_id, 1500, 20, true, 'unit', 1000, 2000, 'SHW-WED');
  END IF;

  IF bridal_cat_id IS NOT NULL THEN
    -- Bridal Shawl Variants Example (Main Product)
    INSERT INTO public.products (name, category, category_id, price, stock, is_active, unit_type)
    VALUES ('Bridal Shawl Collection', 'Bridal Shawl', bridal_cat_id, 2000, 100, true, 'unit')
    RETURNING id INTO prod_id;

    -- Variants: Red, Blue, White, Black / Free Size, S, M, L, XL
    -- Just a few examples
    INSERT INTO public.product_variants (product_id, size, color, price, stock, sku)
    VALUES 
    (prod_id, 'S', 'Red', 2000, 10, 'BR-RED-S'),
    (prod_id, 'M', 'Red', 2000, 15, 'BR-RED-M'),
    (prod_id, 'Free Size', 'Blue', 2200, 5, 'BR-BLU-FS'),
    (prod_id, 'L', 'White', 2000, 20, 'BR-WHI-L');
  END IF;
END $$;
