-- The dashboard uses a separate portal password and intentionally does not
-- call supabase.auth.signInWithPassword. Its browser requests therefore use
-- the anon role. Allow that portal to manage only the catalog tables it edits.
-- Public product/category data is already readable; this adds the missing
-- INSERT/UPDATE/DELETE path for category and product management.

DROP POLICY IF EXISTS products_portal_manage ON public.products;
CREATE POLICY products_portal_manage
ON public.products
FOR ALL TO anon
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS categories_portal_manage ON public.categories;
CREATE POLICY categories_portal_manage
ON public.categories
FOR ALL TO anon
USING (true)
WITH CHECK (true);
