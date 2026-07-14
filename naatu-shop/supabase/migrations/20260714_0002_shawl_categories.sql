-- This catalog is for shawls only. Remove the unrelated seeded herbal
-- categories and make the two real catalog categories canonical.

INSERT INTO public.categories (name_en, name_ta, is_active, sort_order)
VALUES
  ('Shawl', '', TRUE, 1),
  ('Bridal Shawl', '', TRUE, 2)
ON CONFLICT (name_en) DO UPDATE
SET is_active = TRUE;

-- Assign existing shawl products from their names. The category_id trigger
-- keeps the legacy category text in sync with the master table.
UPDATE public.products p
SET category_id = c.id
FROM public.categories c
WHERE c.name_en = CASE
  WHEN LOWER(COALESCE(p.name, '')) LIKE '%bridal%shawl%'
    OR LOWER(COALESCE(p.name, '')) LIKE '%wedding%shawl%'
  THEN 'Bridal Shawl'
  ELSE 'Shawl'
END
AND LOWER(COALESCE(p.name, '')) LIKE '%shawl%';

-- Clear stale links before removing unrelated category rows.
UPDATE public.products
SET category = '', category_id = NULL
WHERE category_id IN (
  SELECT id FROM public.categories
  WHERE LOWER(name_en) NOT IN ('shawl', 'bridal shawl')
)
OR LOWER(COALESCE(category, '')) LIKE 'herbal%';

DELETE FROM public.categories
WHERE LOWER(name_en) NOT IN ('shawl', 'bridal shawl');
