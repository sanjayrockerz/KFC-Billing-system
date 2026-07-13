-- Persist invoice actions/history metadata on completed orders.
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS total_gst NUMERIC(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS invoice_pdf_url TEXT DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_orders_invoice_pdf_url ON public.orders(invoice_pdf_url);
