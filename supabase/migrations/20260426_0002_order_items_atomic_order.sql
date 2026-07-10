-- Canonical migration 0002: normalized order items + atomic order creation
-- Run after 0001.

-- -------------------------------------------------------------------
-- Order items (normalized, analytics/search friendly)
-- -------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id BIGINT REFERENCES public.products(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  product_tamil_name TEXT,
  quantity NUMERIC(12,3) NOT NULL DEFAULT 0,
  unit TEXT NOT NULL DEFAULT 'piece',
  unit_type TEXT NOT NULL DEFAULT 'unit',
  base_quantity NUMERIC(12,3) NOT NULL DEFAULT 1,
  base_price NUMERIC(10,2) NOT NULL DEFAULT 0,
  line_total NUMERIC(10,2) NOT NULL DEFAULT 0,
  image_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT order_items_unit_type_check CHECK (unit_type IN ('unit', 'weight', 'volume', 'bundle'))
);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS order_items_user_select ON public.order_items;
DROP POLICY IF EXISTS order_items_admin_all ON public.order_items;

CREATE POLICY order_items_user_select ON public.order_items
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.orders o
    WHERE o.id = order_items.order_id
      AND o.user_id = auth.uid()
  )
);

CREATE POLICY order_items_admin_all ON public.order_items
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON public.order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_name ON public.order_items(product_name);

-- -------------------------------------------------------------------
-- Atomic order creation RPC
-- -------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_order_with_stock(
  p_customer_name TEXT,
  p_phone TEXT,
  p_address TEXT,
  p_items JSONB,
  p_shipping NUMERIC DEFAULT 0,
  p_status TEXT DEFAULT 'pending'
)
RETURNS TABLE(order_id UUID, invoice_no TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requester UUID := auth.uid();
  v_invoice_no TEXT;
  v_order_id UUID;
  v_subtotal NUMERIC(10,2) := 0;
  v_total NUMERIC(10,2) := 0;
  v_item JSONB;
  v_product_id BIGINT;
  v_name TEXT;
  v_tamil_name TEXT;
  v_quantity NUMERIC(12,3);
  v_unit TEXT;
  v_unit_type TEXT;
  v_base_quantity NUMERIC(12,3);
  v_base_price NUMERIC(10,2);
  v_line_total NUMERIC(10,2);
  v_image_url TEXT;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'At least one order item is required';
  END IF;

  v_invoice_no := public.get_next_invoice_no();

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_line_total := COALESCE((v_item->>'line_total')::NUMERIC, 0);
    v_subtotal := v_subtotal + v_line_total;
  END LOOP;

  v_total := v_subtotal + COALESCE(p_shipping, 0);

  INSERT INTO public.orders (
    invoice_no,
    user_id,
    customer_name,
    phone,
    address,
    items,
    subtotal,
    shipping,
    total,
    status
  )
  VALUES (
    v_invoice_no,
    v_requester,
    COALESCE(NULLIF(TRIM(p_customer_name), ''), 'Customer'),
    COALESCE(NULLIF(TRIM(p_phone), ''), ''),
    COALESCE(NULLIF(TRIM(p_address), ''), ''),
    p_items,
    v_subtotal,
    COALESCE(p_shipping, 0),
    v_total,
    COALESCE(NULLIF(TRIM(p_status), ''), 'pending')
  )
  RETURNING id INTO v_order_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := NULLIF(v_item->>'product_id', '')::BIGINT;
    v_name := COALESCE(NULLIF(v_item->>'name', ''), 'Product');
    v_tamil_name := NULLIF(v_item->>'tamil_name', '');
    v_quantity := COALESCE((v_item->>'quantity')::NUMERIC, 0);
    v_unit := COALESCE(NULLIF(v_item->>'unit', ''), 'piece');
    v_unit_type := COALESCE(NULLIF(v_item->>'unit_type', ''), 'unit');
    v_base_quantity := COALESCE((v_item->>'base_quantity')::NUMERIC, 1);
    v_base_price := COALESCE((v_item->>'base_price')::NUMERIC, 0);
    v_line_total := COALESCE((v_item->>'line_total')::NUMERIC, 0);
    v_image_url := NULLIF(v_item->>'image_url', '');

    INSERT INTO public.order_items (
      order_id,
      product_id,
      product_name,
      product_tamil_name,
      quantity,
      unit,
      unit_type,
      base_quantity,
      base_price,
      line_total,
      image_url
    )
    VALUES (
      v_order_id,
      v_product_id,
      v_name,
      v_tamil_name,
      v_quantity,
      v_unit,
      v_unit_type,
      v_base_quantity,
      v_base_price,
      v_line_total,
      v_image_url
    );

    IF v_product_id IS NOT NULL THEN
      PERFORM public.retail_decrement_stock(v_product_id, v_quantity, v_unit);
    END IF;
  END LOOP;

  RETURN QUERY SELECT v_order_id, v_invoice_no;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_order_with_stock(TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.create_order_with_stock(TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT) FROM anon;
