-- Public invoice pages do not have an authenticated Supabase session.
-- Keep orders protected by RLS and expose only the exact invoice requested.
CREATE OR REPLACE FUNCTION public.get_public_invoice_by_number(p_invoice_no TEXT)
RETURNS SETOF public.orders
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT o.*
  FROM public.orders AS o
  WHERE o.invoice_no = NULLIF(BTRIM(p_invoice_no), '')
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_public_invoice_by_number(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_invoice_by_number(TEXT) TO anon, authenticated;
