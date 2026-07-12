-- Keep the Billing Panel and category management on one canonical category source.
-- Run this migration once in Supabase SQL Editor.

-- 1. Create category rows for any legacy product category text that has no row.
INSERT INTO public.categories (name_en, name_ta, is_active, sort_order)
SELECT DISTINCT trim(p.category), trim(p.category), true, 0
FROM public.products p
WHERE NULLIF(trim(p.category), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.categories c
    WHERE lower(trim(c.name_en)) = lower(trim(p.category))
  );

-- 2. Backfill every product's category_id and normalize its category text.
UPDATE public.products p
SET category_id = c.id,
    category = c.name_en
FROM public.categories c
WHERE NULLIF(trim(p.category), '') IS NOT NULL
  AND lower(trim(p.category)) = lower(trim(c.name_en));

-- 3. Product writes always resolve category_id to the canonical category row.
CREATE OR REPLACE FUNCTION public.sync_product_category_reference()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  resolved_name TEXT;
BEGIN
  IF NEW.category_id IS NOT NULL THEN
    SELECT c.name_en INTO resolved_name
    FROM public.categories c
    WHERE c.id = NEW.category_id;

    IF resolved_name IS NULL THEN
      NEW.category_id := NULL;
    ELSE
      NEW.category := resolved_name;
    END IF;
  ELSIF NULLIF(trim(COALESCE(NEW.category, '')), '') IS NOT NULL THEN
    SELECT c.id, c.name_en
    INTO NEW.category_id, NEW.category
    FROM public.categories c
    WHERE lower(trim(c.name_en)) = lower(trim(NEW.category))
    ORDER BY c.id
    LIMIT 1;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_product_category_reference ON public.products;
CREATE TRIGGER trg_sync_product_category_reference
BEFORE INSERT OR UPDATE OF category, category_id ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.sync_product_category_reference();

-- 4. Renaming a category updates every product shown in the Billing Panel.
CREATE OR REPLACE FUNCTION public.sync_category_name_to_products()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.name_en IS DISTINCT FROM OLD.name_en THEN
    UPDATE public.products
    SET category = NEW.name_en
    WHERE category_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_category_name_to_products ON public.categories;
CREATE TRIGGER trg_sync_category_name_to_products
AFTER UPDATE OF name_en ON public.categories
FOR EACH ROW
EXECUTE FUNCTION public.sync_category_name_to_products();

-- 5. Deleting a category removes it from Billing Panel without deleting products.
-- Products become unassigned instead of retaining a deleted category name.
CREATE OR REPLACE FUNCTION public.unassign_products_from_deleted_category()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.products
  SET category_id = NULL,
      category = 'Uncategorized'
  WHERE category_id = OLD.id
     OR lower(trim(category)) = lower(trim(OLD.name_en));
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_unassign_products_from_deleted_category ON public.categories;
CREATE TRIGGER trg_unassign_products_from_deleted_category
BEFORE DELETE ON public.categories
FOR EACH ROW
EXECUTE FUNCTION public.unassign_products_from_deleted_category();
