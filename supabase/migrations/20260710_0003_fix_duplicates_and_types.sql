-- ── Fix duplicate products, UUID→BIGINT cast, unique constraint ──

-- 1. Remove duplicate products keeping only the first inserted per name
DELETE FROM products WHERE id NOT IN (
  SELECT id FROM (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY name ORDER BY created_at ASC, id ASC) AS rn
    FROM products
  ) ranked WHERE rn = 1
);

-- 2. Add unique constraint on product name to prevent future duplicates
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_name_key;
ALTER TABLE products ADD CONSTRAINT products_name_key UNIQUE (name);

-- 3. Fix retail_decrement_stock — was BIGINT, now accepts TEXT (UUID)
DROP FUNCTION IF EXISTS retail_decrement_stock(BIGINT, NUMERIC, TEXT);
DROP FUNCTION IF EXISTS retail_decrement_stock(TEXT, NUMERIC, TEXT);

CREATE OR REPLACE FUNCTION retail_decrement_stock(
  p_product_id TEXT,
  p_quantity NUMERIC,
  p_unit_type TEXT DEFAULT 'unit'
) RETURNS VOID AS $$
BEGIN
  UPDATE products SET stock_quantity = GREATEST(COALESCE(stock_quantity, 0) - p_quantity, 0)
  WHERE id::TEXT = p_product_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION retail_decrement_stock(TEXT, NUMERIC, TEXT) TO anon, authenticated;

-- 4. Re-create create_order_with_stock with fixed call (no ::BIGINT cast)
--    (This is the same as migration 1 but with the cast fix)
DROP FUNCTION IF EXISTS create_order_with_stock(
  TEXT,TEXT,TEXT,JSONB,NUMERIC,TEXT,TEXT,TEXT,NUMERIC,NUMERIC,NUMERIC,TEXT,NUMERIC,TEXT,NUMERIC,NUMERIC,BOOLEAN
);

CREATE OR REPLACE FUNCTION create_order_with_stock(
  p_customer_name TEXT,
  p_phone TEXT,
  p_address TEXT,
  p_items JSONB,
  p_shipping NUMERIC DEFAULT 0,
  p_status TEXT DEFAULT 'pending',
  p_order_mode TEXT DEFAULT 'online',
  p_order_type TEXT DEFAULT NULL,
  p_delivery_charge NUMERIC DEFAULT 0,
  p_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_type TEXT DEFAULT 'flat',
  p_manual_discount_value NUMERIC DEFAULT 0,
  p_coupon_code TEXT DEFAULT NULL,
  p_coupon_percentage NUMERIC DEFAULT 0,
  p_total_gst NUMERIC DEFAULT 0,
  p_gst_enabled BOOLEAN DEFAULT false
) RETURNS JSONB AS $$
DECLARE
  v_order_id UUID;
  v_invoice_no TEXT;
  v_subtotal NUMERIC := 0;
  v_item RECORD;
  v_is_manual BOOLEAN;
  v_detected_type TEXT;
BEGIN
  v_detected_type := COALESCE(p_order_type,
    CASE WHEN p_status = 'pending' AND p_order_mode = 'online' THEN 'online_request'
         ELSE 'pos_sale' END);
  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
    product_id TEXT, variant_id TEXT, name TEXT, product_name TEXT,
    quantity NUMERIC, price NUMERIC, line_total NUMERIC,
    source TEXT, is_manual BOOLEAN
  ) LOOP
    IF COALESCE(v_item.is_manual, false) OR v_item.source = 'manual' OR v_item.product_id IS NULL THEN
      v_detected_type := 'manual_sale'; EXIT; END IF;
  END LOOP;
  SELECT get_next_invoice_no() INTO v_invoice_no;
  SELECT COALESCE(SUM(line_total), 0) INTO v_subtotal
  FROM jsonb_to_recordset(p_items) AS x(line_total NUMERIC);
  INSERT INTO orders (invoice_no, customer_name, phone, address, items, subtotal,
    shipping, total, status, order_mode, order_type,
    delivery_charge, discount_amount, manual_discount_amount,
    manual_discount_type, manual_discount_value, coupon_code, coupon_percentage,
    total_gst, gst_enabled)
  VALUES (v_invoice_no, p_customer_name, p_phone, p_address, p_items, v_subtotal,
    p_shipping,
    GREATEST(v_subtotal + COALESCE(p_shipping,0) + COALESCE(p_delivery_charge,0)
      - COALESCE(p_discount_amount,0) - COALESCE(p_manual_discount_amount,0), 0),
    p_status, p_order_mode, v_detected_type,
    p_delivery_charge, p_discount_amount, p_manual_discount_amount,
    p_manual_discount_type, p_manual_discount_value, p_coupon_code, p_coupon_percentage,
    p_total_gst, p_gst_enabled)
  RETURNING id INTO v_order_id;
  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
    product_id TEXT, variant_id TEXT, name TEXT, product_name TEXT,
    variant_name TEXT, tamil_name TEXT, quantity NUMERIC, unit TEXT,
    unit_type TEXT, base_quantity NUMERIC, base_price NUMERIC,
    line_total NUMERIC, image_url TEXT, source TEXT, is_manual BOOLEAN, note TEXT
  ) LOOP
    v_is_manual := COALESCE(v_item.is_manual, false) OR v_item.source = 'manual';
    INSERT INTO order_items (order_id, product_id, variant_id, product_name, variant_name,
      product_tamil_name, quantity, unit, unit_type, base_quantity,
      base_price, line_total, image_url, is_manual, note)
    VALUES (v_order_id, v_item.product_id, v_item.variant_id,
      COALESCE(v_item.product_name, v_item.name, 'Item'), v_item.variant_name,
      v_item.tamil_name, COALESCE(v_item.quantity, 1), COALESCE(v_item.unit, 'piece'),
      COALESCE(v_item.unit_type, 'unit'), COALESCE(v_item.base_quantity, 1),
      COALESCE(v_item.base_price, 0), COALESCE(v_item.line_total, 0),
      v_item.image_url, v_is_manual, v_item.note);
    IF NOT v_is_manual AND v_item.product_id IS NOT NULL THEN
      IF v_item.variant_id IS NOT NULL AND v_item.variant_id <> '' THEN
        UPDATE product_variants SET stock = GREATEST(COALESCE(stock, 0) - COALESCE(v_item.quantity, 1), 0)
        WHERE id::TEXT = v_item.variant_id;
      ELSE
        PERFORM retail_decrement_stock(v_item.product_id, COALESCE(v_item.quantity, 1), COALESCE(v_item.unit_type, 'unit'));
      END IF;
    END IF;
  END LOOP;
  IF p_coupon_code IS NOT NULL AND p_coupon_code <> '' THEN
    UPDATE coupons SET usage_count = COALESCE(usage_count, 0) + 1 WHERE code = p_coupon_code;
  END IF;
  RETURN jsonb_build_object('order_id', v_order_id, 'invoice_no', v_invoice_no);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
