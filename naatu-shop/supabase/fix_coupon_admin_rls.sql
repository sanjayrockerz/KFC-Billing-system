-- Fix coupon admin RLS for the Zera admin template.
-- Run this once in Supabase SQL Editor for the target project where
-- coupon creation/update/delete is failing with:
--   new row violates row-level security policy for table "coupons"

BEGIN;

-- Keep app_metadata.role in sync when profiles.role changes.
CREATE OR REPLACE FUNCTION public.sync_role_to_auth()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    UPDATE auth.users
    SET raw_app_meta_data =
      COALESCE(raw_app_meta_data, '{}'::jsonb) ||
      jsonb_build_object('role', NEW.role)
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_role_to_auth ON public.profiles;
CREATE TRIGGER trg_sync_role_to_auth
  AFTER UPDATE OF role ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_role_to_auth();

-- Make admin checks work from either profiles.role or JWT app_metadata.role.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
  OR COALESCE((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin';
$$;

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS coupons_admin_all ON public.coupons;
DROP POLICY IF EXISTS coupons_auth_read ON public.coupons;

CREATE POLICY coupons_admin_all ON public.coupons
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY coupons_auth_read ON public.coupons
  FOR SELECT TO authenticated
  USING (is_active = true OR public.is_admin());

COMMIT;

-- After running this:
-- 1. Make sure your user row in public.profiles has role = 'admin'
-- 2. Sign out and sign back in once so the refreshed JWT also carries the role
