-- Hotfix for duplicate invoice numbers during POS billing.
-- Run this entire file in Supabase SQL Editor if sale completion fails with:
-- duplicate key value violates unique constraint "orders_invoice_no_key"

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no TEXT UNIQUE,
  user_id UUID,
  customer_name TEXT NOT NULL DEFAULT 'Customer',
  phone TEXT,
  address TEXT,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  subtotal NUMERIC(10,2) NOT NULL DEFAULT 0,
  shipping NUMERIC(10,2) NOT NULL DEFAULT 0,
  total NUMERIC(10,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id BIGINT,
  variant_id UUID,
  product_name TEXT NOT NULL,
  quantity NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS invoice_no TEXT,
  ADD COLUMN IF NOT EXISTS user_id UUID,
  ADD COLUMN IF NOT EXISTS customer_name TEXT DEFAULT 'Customer',
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS items JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS subtotal NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS shipping NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS order_mode TEXT DEFAULT 'offline',
  ADD COLUMN IF NOT EXISTS order_type TEXT DEFAULT 'pos_sale',
  ADD COLUMN IF NOT EXISTS delivery_charge NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS manual_discount_amount NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS manual_discount_type TEXT DEFAULT 'flat',
  ADD COLUMN IF NOT EXISTS manual_discount_value NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS coupon_code TEXT,
  ADD COLUMN IF NOT EXISTS coupon_percentage NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_gst NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gst_enabled BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS split_details JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS invoice_pdf_url TEXT,
  ADD COLUMN IF NOT EXISTS invoice_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS receipt_printed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS product_id BIGINT,
  ADD COLUMN IF NOT EXISTS variant_id UUID,
  ADD COLUMN IF NOT EXISTS product_name TEXT,
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS product_tamil_name TEXT,
  ADD COLUMN IF NOT EXISTS tamil_name TEXT,
  ADD COLUMN IF NOT EXISTS quantity NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'piece',
  ADD COLUMN IF NOT EXISTS unit_type TEXT DEFAULT 'unit',
  ADD COLUMN IF NOT EXISTS base_quantity NUMERIC(10,2) DEFAULT 1,
  ADD COLUMN IF NOT EXISTS base_price NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS line_total NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS is_manual BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS discount NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gst_amount NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gst_rate NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

CREATE UNIQUE INDEX IF NOT EXISTS idx_kfc_orders_invoice_no_unique
ON public.orders(invoice_no)
WHERE invoice_no IS NOT NULL;

CREATE OR REPLACE FUNCTION public.get_next_invoice_no()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next INTEGER;
  v_invoice_no TEXT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('kfc_invoice_no'));

  SELECT COALESCE(MAX(NULLIF(SUBSTRING(invoice_no FROM '^KFC-([0-9]+)$'), '')::INTEGER), 0) + 1
  INTO v_next
  FROM public.orders
  WHERE invoice_no ~ '^KFC-[0-9]+$';

  LOOP
    v_invoice_no := 'KFC-' || LPAD(v_next::TEXT, 5, '0');
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.orders WHERE invoice_no = v_invoice_no
    );
    v_next := v_next + 1;
  END LOOP;

  RETURN v_invoice_no;
END;
$$;

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
  p_gst_enabled            BOOLEAN DEFAULT FALSE,
  p_payment_method         TEXT DEFAULT 'cash',
  p_split_details          JSONB DEFAULT '{}'::jsonb
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
  v_qty NUMERIC(10,2);
  v_invoice_attempt INTEGER := 0;
BEGIN
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'At least one order item is required';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_subtotal := v_subtotal + COALESCE(NULLIF(v_item->>'line_total', '')::NUMERIC, 0);
  END LOOP;

  v_total := GREATEST(0, v_subtotal + COALESCE(p_total_gst, 0)
    + COALESCE(p_delivery_charge, 0) + COALESCE(p_shipping, 0)
    - COALESCE(p_discount_amount, 0) - COALESCE(p_manual_discount_amount, 0));

  LOOP
    v_invoice_attempt := v_invoice_attempt + 1;
    v_invoice_no := public.get_next_invoice_no();

    BEGIN
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
        COALESCE(p_coupon_percentage, 0), COALESCE(p_total_gst, 0), COALESCE(p_gst_enabled, FALSE),
        COALESCE(NULLIF(TRIM(p_payment_method), ''), 'cash'),
        COALESCE(NULLIF(TRIM(p_payment_method), ''), 'cash'), COALESCE(p_split_details, '{}'::jsonb)
      ) RETURNING id INTO v_order_id;

      EXIT;
    EXCEPTION WHEN unique_violation THEN
      IF v_invoice_attempt >= 10 THEN
        RAISE;
      END IF;
    END;
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := CASE
      WHEN COALESCE(v_item->>'id', v_item->>'product_id', '') ~ '^[0-9]+$'
      THEN COALESCE(v_item->>'id', v_item->>'product_id')::BIGINT
      ELSE NULL
    END;
    v_variant_id := CASE
      WHEN COALESCE(v_item->>'variant_id', '') ~ '^[0-9a-fA-F-]{36}$'
      THEN (v_item->>'variant_id')::UUID
      ELSE NULL
    END;
    v_qty := COALESCE(NULLIF(v_item->>'quantity', '')::NUMERIC, 0);

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
      v_qty, COALESCE(NULLIF(v_item->>'unit', ''), 'piece'),
      COALESCE(NULLIF(v_item->>'unit_type', ''), 'unit'),
      COALESCE(NULLIF(v_item->>'base_quantity', '')::NUMERIC, 1),
      COALESCE(NULLIF(v_item->>'base_price', '')::NUMERIC, 0),
      COALESCE(NULLIF(v_item->>'line_total', '')::NUMERIC, 0),
      NULLIF(v_item->>'image_url', ''),
      COALESCE((v_item->>'source') = 'manual', FALSE),
      COALESCE(NULLIF(v_item->>'discount', '')::NUMERIC, 0),
      COALESCE(NULLIF(v_item->>'gst_amount', '')::NUMERIC, 0),
      COALESCE(NULLIF(v_item->>'gst_rate', '')::NUMERIC, 0)
    );

    IF v_product_id IS NOT NULL THEN
      UPDATE public.products
      SET stock_quantity = GREATEST(COALESCE(stock_quantity, 0) - v_qty, 0),
          stock = GREATEST(FLOOR(COALESCE(stock_quantity, 0) - v_qty), 0)::INTEGER,
          updated_at = NOW()
      WHERE id = v_product_id;
    END IF;

    IF v_variant_id IS NOT NULL AND to_regclass('public.product_variants') IS NOT NULL THEN
      UPDATE public.product_variants
      SET stock = GREATEST(COALESCE(stock, 0) - v_qty, 0),
          updated_at = NOW()
      WHERE id = v_variant_id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('orderId', v_order_id, 'invoiceNo', v_invoice_no, 'createdAt', NOW());
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_next_invoice_no() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT,
  NUMERIC, NUMERIC, NUMERIC, TEXT, NUMERIC, TEXT, NUMERIC,
  NUMERIC, BOOLEAN, TEXT, JSONB
) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
