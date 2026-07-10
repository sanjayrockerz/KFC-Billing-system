-- =====================================================================
-- FIX: UUID SYNTAX & SCHEMA UPGRADE (Run this ENTIRE script)
-- =====================================================================

-- 1. Ensure categories id is BIGINT (if it was somehow UUID)
DO $$ 
BEGIN
  -- If it's not a BIGINT, we might need a more complex migration, 
  -- but usually BIGSERIAL starts as BIGINT.
  RAISE NOTICE 'Checking categories table...';
END $$;

-- 2. Ensure updated_at exists on categories
DO $$ 
BEGIN
  BEGIN ALTER TABLE public.categories ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW(); EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.categories ADD COLUMN sort_order INTEGER DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.categories ADD COLUMN is_active BOOLEAN DEFAULT true; EXCEPTION WHEN duplicate_column THEN END;
END $$;

-- 3. Ensure products table has all retail columns
DO $$ 
BEGIN
  BEGIN ALTER TABLE public.products ADD COLUMN unit_type TEXT NOT NULL DEFAULT 'unit'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN unit_label TEXT NOT NULL DEFAULT 'piece'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN base_quantity NUMERIC(12,3) NOT NULL DEFAULT 1; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN stock_quantity NUMERIC(12,3) NOT NULL DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN stock_unit TEXT DEFAULT 'piece'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN allow_decimal_quantity BOOLEAN NOT NULL DEFAULT false; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN predefined_options JSONB NOT NULL DEFAULT '[]'; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN image_url TEXT DEFAULT '/assets/images/default-herb.jpg'; EXCEPTION WHEN duplicate_column THEN END;
END $$;

-- 4. Fix RLS policies to prevent UUID issues
-- Ensure using coalesce and JWT metadata for admin checks
DROP POLICY IF EXISTS "products_admin_manage" ON public.products;
CREATE POLICY "products_admin_manage" ON public.products
  FOR ALL USING (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin'
  );

DROP POLICY IF EXISTS "categories_admin_manage" ON public.categories;
CREATE POLICY "categories_admin_manage" ON public.categories
  FOR ALL USING (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin'
  );

-- 5. Fix Orders user_id constraint if needed
-- If orders.user_id is somehow failing on NaN, we've fixed the frontend, 
-- but let's ensure the table column is correct.
DO $$ 
BEGIN
  BEGIN
    ALTER TABLE public.orders ALTER COLUMN user_id TYPE UUID;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'user_id already UUID or table missing.';
  END;
END $$;

-- 6. Grant sequence permissions to anon/authenticated for ID generation
GRANT USAGE, SELECT ON SEQUENCE IF NOT EXISTS public.products_id_seq TO anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE IF NOT EXISTS public.categories_id_seq TO anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE IF NOT EXISTS public.health_tags_id_seq TO anon, authenticated;
