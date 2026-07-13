-- Create invoices storage bucket for PDF invoices
-- Run this in Supabase SQL Editor after deployment

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'invoices',
  'invoices',
  true,
  5242880, -- 5MB limit
  ARRAY['application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Public read policy for invoices
DROP POLICY IF EXISTS invoices_public_read ON storage.objects;
CREATE POLICY invoices_public_read ON storage.objects
  FOR SELECT USING (bucket_id = 'invoices');

-- Admin upload policy for invoices
DROP POLICY IF EXISTS invoices_admin_upload ON storage.objects;
CREATE POLICY invoices_admin_upload ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'invoices' AND public.is_admin()
  );

-- Admin update policy for invoices
DROP POLICY IF EXISTS invoices_admin_update ON storage.objects;
CREATE POLICY invoices_admin_update ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'invoices' AND public.is_admin()
  )
  WITH CHECK (
    bucket_id = 'invoices' AND public.is_admin()
  );

-- Admin delete policy for invoices
DROP POLICY IF EXISTS invoices_admin_delete ON storage.objects;
CREATE POLICY invoices_admin_delete ON storage.objects
  FOR DELETE USING (
    bucket_id = 'invoices' AND public.is_admin()
  );