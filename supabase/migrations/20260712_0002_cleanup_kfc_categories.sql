-- Keep the KFC catalog on its four canonical categories.
-- This repairs rows created by the legacy category sync migration, including
-- case/spacing duplicates and unrelated values such as HI, ADSSA, and MANUAL.

CREATE TEMP TABLE canonical_category_ids ON COMMIT DROP AS
SELECT canonical_name,
       MIN(id) AS id
FROM (
  SELECT id, 'Chicken'::text AS canonical_name FROM public.categories WHERE lower(trim(name_en)) = 'chicken'
  UNION ALL
  SELECT id, 'Sides'::text FROM public.categories WHERE lower(trim(name_en)) = 'sides'
  UNION ALL
  SELECT id, 'Burgers & Wraps'::text FROM public.categories WHERE lower(trim(name_en)) = 'burgers & wraps'
  UNION ALL
  SELECT id, 'Beverages'::text FROM public.categories WHERE lower(trim(name_en)) = 'beverages'
) matches
GROUP BY canonical_name;

INSERT INTO public.categories (name_en, name_ta, is_active, sort_order)
SELECT canonical_name, '', true, row_number() OVER (ORDER BY canonical_name)
FROM (VALUES
  ('Chicken'::text),
  ('Sides'::text),
  ('Burgers & Wraps'::text),
  ('Beverages'::text)
) required(canonical_name)
WHERE NOT EXISTS (
  SELECT 1 FROM canonical_category_ids existing
  WHERE existing.canonical_name = required.canonical_name
);

TRUNCATE canonical_category_ids;

INSERT INTO canonical_category_ids (canonical_name, id)
SELECT canonical_name,
       MIN(id)
FROM (
  SELECT id, 'Chicken'::text AS canonical_name FROM public.categories WHERE lower(trim(name_en)) = 'chicken'
  UNION ALL
  SELECT id, 'Sides'::text FROM public.categories WHERE lower(trim(name_en)) = 'sides'
  UNION ALL
  SELECT id, 'Burgers & Wraps'::text FROM public.categories WHERE lower(trim(name_en)) = 'burgers & wraps'
  UNION ALL
  SELECT id, 'Beverages'::text FROM public.categories WHERE lower(trim(name_en)) = 'beverages'
) matches
GROUP BY canonical_name;

UPDATE public.categories c
SET name_en = ids.canonical_name,
    name_ta = COALESCE(NULLIF(trim(c.name_ta), ''), ids.canonical_name),
    is_active = true,
    sort_order = CASE ids.canonical_name
      WHEN 'Chicken' THEN 1
      WHEN 'Sides' THEN 2
      WHEN 'Burgers & Wraps' THEN 3
      WHEN 'Beverages' THEN 4
    END
FROM canonical_category_ids ids
WHERE c.id = ids.id;

UPDATE public.products p
SET category_id = ids.id,
    category = ids.canonical_name
FROM canonical_category_ids ids
WHERE lower(trim(COALESCE(p.category, ''))) = lower(ids.canonical_name)
   OR p.category_id IN (
     SELECT c.id FROM public.categories c
     WHERE lower(trim(c.name_en)) = lower(ids.canonical_name)
   );

UPDATE public.products
SET category_id = NULL,
    category = 'Uncategorized'
WHERE lower(trim(COALESCE(category, ''))) NOT IN (
  'chicken', 'sides', 'burgers & wraps', 'beverages'
);

DELETE FROM public.categories c
WHERE NOT EXISTS (SELECT 1 FROM canonical_category_ids ids WHERE ids.id = c.id)
   OR c.id NOT IN (SELECT MIN(id) FROM public.categories GROUP BY lower(trim(name_en)));
