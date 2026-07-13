-- Keep Billing Panel product categories and public.categories in sync.
-- Safe to run once in Supabase SQL Editor; statements are idempotent.

-- 1) Make sure every existing category string used by an active/inactive
-- product has a row in the category master table.
INSERT INTO public.categories (name_en, name_ta, is_active, sort_order)
SELECT DISTINCT BTRIM(p.category), '', TRUE, 0
FROM public.products p
WHERE NULLIF(BTRIM(COALESCE(p.category, '')), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.categories c
    WHERE LOWER(BTRIM(c.name_en)) = LOWER(BTRIM(p.category))
  );

-- 2) Backfill the foreign-key relationship for existing products.
UPDATE public.products p
SET category_id = c.id
FROM public.categories c
WHERE p.category_id IS NULL
  AND NULLIF(BTRIM(COALESCE(p.category, '')), '') IS NOT NULL
  AND LOWER(BTRIM(c.name_en)) = LOWER(BTRIM(p.category));

-- 3) Category IDs are canonical: product.category always mirrors the master
-- category name used by the Billing Panel's filters.
CREATE OR REPLACE FUNCTION public.sync_product_category_name()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.category_id IS NOT NULL THEN
    SELECT c.name_en INTO NEW.category
    FROM public.categories c
    WHERE c.id = NEW.category_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_product_category_name ON public.products;
CREATE TRIGGER trg_sync_product_category_name
BEFORE INSERT OR UPDATE OF category_id ON public.products
FOR EACH ROW EXECUTE FUNCTION public.sync_product_category_name();

-- 4) Renaming a category updates every product immediately.
CREATE OR REPLACE FUNCTION public.sync_category_name_to_products()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.name_en IS DISTINCT FROM OLD.name_en THEN
    UPDATE public.products
    SET category = NEW.name_en,
        updated_at = NOW()
    WHERE category_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_category_name_to_products ON public.categories;
CREATE TRIGGER trg_sync_category_name_to_products
AFTER UPDATE OF name_en ON public.categories
FOR EACH ROW EXECUTE FUNCTION public.sync_category_name_to_products();

-- 5) Deleting a category removes it from Billing Panel filters too. The
-- category_id FK is ON DELETE SET NULL; clear the denormalized text first.
CREATE OR REPLACE FUNCTION public.clear_deleted_category_from_products()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.products
  SET category = '',
      category_id = NULL,
      updated_at = NOW()
  WHERE category_id = OLD.id;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_clear_deleted_category_from_products ON public.categories;
CREATE TRIGGER trg_clear_deleted_category_from_products
BEFORE DELETE ON public.categories
FOR EACH ROW EXECUTE FUNCTION public.clear_deleted_category_from_products();

