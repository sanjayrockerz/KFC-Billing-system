-- Reconcile the order RPC after the POS/GST migrations.
--
-- PostgreSQL resolves overloaded functions by argument types.  The old
-- migrations left two 19-argument functions with the same types but a
-- different order for p_gst_enabled / p_payment_method / p_split_details.
-- Named RPC calls therefore fail with "could not choose the best candidate".

-- Do not rely on a hand-written signature here. The database may contain
-- older 6/15/19-argument versions, and the two 19-argument versions differ
-- only by parameter order. Remove every overload by name first.
DO $$
DECLARE
  fn RECORD;
BEGIN
  FOR fn IN
    SELECT oid::regprocedure AS signature
    FROM pg_proc
    WHERE pronamespace = 'public'::regnamespace
      AND proname = 'create_order_with_stock'
      AND prokind = 'f'
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || fn.signature;
  END LOOP;
END;
$$;

DROP FUNCTION IF EXISTS public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT,
  NUMERIC, NUMERIC, NUMERIC, TEXT, NUMERIC, TEXT, NUMERIC,
  TEXT, JSONB, BOOLEAN
);

DROP FUNCTION IF EXISTS public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT,
  NUMERIC, NUMERIC, NUMERIC, TEXT, NUMERIC, TEXT, NUMERIC,
  BOOLEAN, TEXT, JSONB
);

DROP FUNCTION IF EXISTS public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT,
  NUMERIC, NUMERIC, NUMERIC, TEXT, NUMERIC, TEXT, NUMERIC,
  NUMERIC, BOOLEAN, TEXT, JSONB
);

CREATE FUNCTION public.create_order_with_stock(
  p_customer_name          TEXT,
  p_phone                  TEXT,
  p_address                TEXT,
  p_items                  JSONB,
  p_shipping               NUMERIC DEFAULT 0,
  p_status                 TEXT DEFAULT 'pending',
  p_order_mode             TEXT DEFAULT 'offline',
  p_order_type             TEXT DEFAULT 'pos_sale',
  p_delivery_charge        NUMERIC DEFAULT 0,
  p_discount_amount        NUMERIC DEFAULT 0,
  p_manual_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_type   TEXT DEFAULT 'flat',
  p_manual_discount_value  NUMERIC DEFAULT 0,
  p_coupon_code            TEXT DEFAULT NULL,
  p_coupon_percentage      NUMERIC DEFAULT 0,
  p_total_gst              NUMERIC DEFAULT 0,
  p_gst_enabled            BOOLEAN DEFAULT false,
  p_payment_method         TEXT DEFAULT 'cash',
  p_split_details          JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice_no TEXT;
  v_order_id UUID;
  v_subtotal NUMERIC(10,2) := 0;
  v_total NUMERIC(10,2);
  v_item JSONB;
  v_product_id BIGINT;
  v_variant_id UUID;
BEGIN
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'At least one order item is required';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_subtotal := v_subtotal + COALESCE((v_item->>'line_total')::NUMERIC, 0);
  END LOOP;

  v_total := GREATEST(0, v_subtotal + COALESCE(p_total_gst, 0)
    + COALESCE(p_delivery_charge, 0) + COALESCE(p_shipping, 0)
    - COALESCE(p_discount_amount, 0) - COALESCE(p_manual_discount_amount, 0));
  v_invoice_no := public.get_next_invoice_no();

  INSERT INTO public.orders (
    invoice_no, user_id, customer_name, phone, address, items,
    subtotal, shipping, total, status, order_mode, order_type,
    delivery_charge, discount_amount, manual_discount_amount,
    manual_discount_type, manual_discount_value, coupon_code,
    coupon_percentage, total_gst, gst_enabled, payment_method,
    payment_mode, split_details
  ) VALUES (
    v_invoice_no, auth.uid(), COALESCE(NULLIF(TRIM(p_customer_name), ''), 'Customer'),
    COALESCE(NULLIF(TRIM(p_phone), ''), ''), COALESCE(NULLIF(TRIM(p_address), ''), ''),
    p_items, v_subtotal, COALESCE(p_shipping, 0), v_total,
    COALESCE(NULLIF(TRIM(p_status), ''), 'pending'),
    COALESCE(NULLIF(TRIM(p_order_mode), ''), 'offline'),
    COALESCE(NULLIF(TRIM(p_order_type), ''), 'pos_sale'),
    COALESCE(p_delivery_charge, 0), COALESCE(p_discount_amount, 0),
    COALESCE(p_manual_discount_amount, 0), COALESCE(NULLIF(TRIM(p_manual_discount_type), ''), 'flat'),
    COALESCE(p_manual_discount_value, 0), NULLIF(TRIM(COALESCE(p_coupon_code, '')), ''),
    COALESCE(p_coupon_percentage, 0), COALESCE(p_total_gst, 0), COALESCE(p_gst_enabled, false),
    COALESCE(NULLIF(TRIM(p_payment_method), ''), 'cash'),
    COALESCE(NULLIF(TRIM(p_payment_method), ''), 'cash'), COALESCE(p_split_details, '{}')
  ) RETURNING id INTO v_order_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := NULLIF(COALESCE(v_item->>'id', v_item->>'product_id'), '')::BIGINT;
    v_variant_id := NULLIF(v_item->>'variant_id', '')::UUID;
    INSERT INTO public.order_items (
      order_id, product_id, variant_id, product_name, name,
      product_tamil_name, tamil_name, quantity, unit, unit_type,
      base_quantity, base_price, line_total, image_url, is_manual,
      discount, gst_amount, gst_rate
    ) VALUES (
      v_order_id, v_product_id, v_variant_id,
      COALESCE(NULLIF(v_item->>'name', ''), 'Product'),
      COALESCE(NULLIF(v_item->>'name', ''), 'Product'),
      NULLIF(v_item->>'tamil_name', ''), NULLIF(v_item->>'tamil_name', ''),
      COALESCE((v_item->>'quantity')::NUMERIC, 0), COALESCE(NULLIF(v_item->>'unit', ''), 'piece'),
      COALESCE(NULLIF(v_item->>'unit_type', ''), 'unit'), COALESCE((v_item->>'base_quantity')::NUMERIC, 1),
      COALESCE((v_item->>'base_price')::NUMERIC, 0), COALESCE((v_item->>'line_total')::NUMERIC, 0),
      NULLIF(v_item->>'image_url', ''), COALESCE((v_item->>'source') = 'manual', false),
      COALESCE((v_item->>'discount')::NUMERIC, 0), COALESCE((v_item->>'gst_amount')::NUMERIC, 0),
      COALESCE((v_item->>'gst_rate')::NUMERIC, 0)
    );
    IF v_product_id IS NOT NULL THEN
      UPDATE public.products
      SET stock_quantity = GREATEST(COALESCE(stock_quantity, 0) - COALESCE((v_item->>'quantity')::NUMERIC, 0), 0),
          stock = GREATEST(FLOOR(COALESCE(stock_quantity, 0) - COALESCE((v_item->>'quantity')::NUMERIC, 0)), 0)::INTEGER,
          updated_at = NOW()
      WHERE id = v_product_id;
    END IF;
    IF v_variant_id IS NOT NULL THEN
      UPDATE public.product_variants
      SET stock = GREATEST(COALESCE(stock, 0) - COALESCE((v_item->>'quantity')::NUMERIC, 0), 0), updated_at = NOW()
      WHERE id = v_variant_id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('orderId', v_order_id, 'invoiceNo', v_invoice_no, 'createdAt', NOW());
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT,
  NUMERIC, NUMERIC, NUMERIC, TEXT, NUMERIC, TEXT, NUMERIC,
  NUMERIC, BOOLEAN, TEXT, JSONB
) TO authenticated;
