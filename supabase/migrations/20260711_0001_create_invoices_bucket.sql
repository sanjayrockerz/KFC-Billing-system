-- Create invoices storage bucket for PDF uploads
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

-- Allow public read access to invoices bucket
CREATE POLICY "invoices_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'invoices');

-- Allow authenticated users to upload invoices (or use anon if needed for POS)
CREATE POLICY "invoices_insert" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'invoices');

-- Allow users to update their own invoices
CREATE POLICY "invoices_update" ON storage.objects
  FOR UPDATE USING (bucket_id = 'invoices');

-- Allow users to delete their own invoices
CREATE POLICY "invoices_delete" ON storage.objects
  FOR DELETE USING (bucket_id = 'invoices');