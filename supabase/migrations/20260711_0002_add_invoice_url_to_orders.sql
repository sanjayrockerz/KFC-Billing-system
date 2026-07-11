-- Add invoice_url column to orders table for PDF invoice download links
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS invoice_url TEXT;