-- ==============================================================================
-- ZERA POS SCHEMA UPGRADE SCRIPT
-- ==============================================================================

-- 1. Store Settings Table
CREATE TABLE IF NOT EXISTS public.store_settings (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name           TEXT NOT NULL DEFAULT 'ZERA',
  owner_name     TEXT DEFAULT 'Sulficker Roshan N',
  phone          TEXT DEFAULT '9342489391',
  address        TEXT DEFAULT 'Kurinji Nagar, Brindhavan Circle, Kuniyamuthur',
  gst_enabled    BOOLEAN DEFAULT false,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for Store Settings
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "store_settings_read" ON public.store_settings;
DROP POLICY IF EXISTS "store_settings_manage" ON public.store_settings;
CREATE POLICY "store_settings_read" ON public.store_settings FOR SELECT TO public USING (true);
CREATE POLICY "store_settings_manage" ON public.store_settings FOR ALL TO authenticated USING (coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin');

-- Insert default store settings if empty
INSERT INTO public.store_settings (name, owner_name, phone, address, gst_enabled)
SELECT 'ZERA', 'Sulficker Roshan N', '9342489391', 'ZERA, Kurinji Nagar, Brindhavan Circle, Kuniyamuthur', true
WHERE NOT EXISTS (SELECT 1 FROM public.store_settings);

-- 2. Add New Columns to Products
DO $$ 
BEGIN
  BEGIN ALTER TABLE public.products ADD COLUMN sku TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN barcode TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN brand TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN purchase_price NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN mrp NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN gst_percent NUMERIC(5,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN opening_stock NUMERIC(12,3) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN low_stock_alert NUMERIC(12,3) DEFAULT 5; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN supplier TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN size TEXT; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.products ADD COLUMN color TEXT; EXCEPTION WHEN duplicate_column THEN END;
END $$;

-- 3. Product Variants Table
CREATE TABLE IF NOT EXISTS public.product_variants (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id  BIGINT REFERENCES public.products(id) ON DELETE CASCADE,
  sku         TEXT,
  barcode     TEXT,
  size        TEXT,
  color       TEXT,
  purchase_price NUMERIC(10,2) DEFAULT 0,
  mrp         NUMERIC(10,2) DEFAULT 0,
  price       NUMERIC(10,2) DEFAULT 0,
  stock       NUMERIC(12,3) DEFAULT 0,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for Product Variants
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "product_variants_read" ON public.product_variants;
DROP POLICY IF EXISTS "product_variants_manage" ON public.product_variants;
CREATE POLICY "product_variants_read" ON public.product_variants FOR SELECT TO public USING (is_active = true);
CREATE POLICY "product_variants_manage" ON public.product_variants FOR ALL TO authenticated USING (coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin');

-- 4. Add New Columns to Orders
DO $$ 
BEGIN
  BEGIN ALTER TABLE public.orders ADD COLUMN discount_type TEXT DEFAULT 'amount' CHECK (discount_type IN ('amount', 'percent')); EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN discount_value NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN gst_enabled BOOLEAN DEFAULT false; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN total_gst NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN payment_method TEXT DEFAULT 'cash' CHECK (payment_method IN ('cash', 'upi', 'card', 'split')); EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.orders ADD COLUMN split_details JSONB DEFAULT '{}'; EXCEPTION WHEN duplicate_column THEN END;
END $$;

-- 5. Add New Columns to Order Items
DO $$ 
BEGIN
  BEGIN ALTER TABLE public.order_items ADD COLUMN variant_id UUID REFERENCES public.product_variants(id) ON DELETE SET NULL; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.order_items ADD COLUMN discount NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.order_items ADD COLUMN gst_amount NUMERIC(10,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
  BEGIN ALTER TABLE public.order_items ADD COLUMN gst_rate NUMERIC(5,2) DEFAULT 0; EXCEPTION WHEN duplicate_column THEN END;
END $$;

-- 6. Update create_order_with_stock RPC to handle ZERA POS fields
CREATE OR REPLACE FUNCTION public.create_order_with_stock(
    p_customer_name TEXT,
    p_phone TEXT,
    p_address TEXT,
    p_items JSONB,
    p_shipping NUMERIC,
    p_status TEXT,
    p_order_mode TEXT,
    p_order_type TEXT,
    p_delivery_charge NUMERIC DEFAULT 0,
    p_discount_amount NUMERIC DEFAULT 0,
    p_manual_discount_amount NUMERIC DEFAULT 0,
    p_manual_discount_type TEXT DEFAULT 'flat',
    p_manual_discount_value NUMERIC DEFAULT 0,
    p_coupon_code TEXT DEFAULT NULL,
    p_coupon_percentage NUMERIC DEFAULT 0,
    p_total_gst NUMERIC DEFAULT 0,
    p_payment_method TEXT DEFAULT 'cash',
    p_split_details JSONB DEFAULT '{}',
    p_gst_enabled BOOLEAN DEFAULT false
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order_id UUID;
    v_invoice_no TEXT;
    v_item JSONB;
    v_subtotal NUMERIC := 0;
    v_total NUMERIC := 0;
    v_effective_discount NUMERIC;
    v_seq BIGINT;
    v_year TEXT;
BEGIN
    -- Validate params
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Order must contain at least one item';
    END IF;

    -- Subtotal calculation
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_subtotal := v_subtotal + COALESCE((v_item->>'line_total')::NUMERIC, 0);
    END LOOP;

    -- Totals calculation
    v_effective_discount := p_discount_amount + p_manual_discount_amount;
    v_total := v_subtotal + p_total_gst - v_effective_discount + p_delivery_charge + p_shipping;
    IF v_total < 0 THEN v_total := 0; END IF;

    -- Generate Invoice No
    v_year := to_char(now(), 'YYYY');
    INSERT INTO public.invoice_counter (year, counter, id)
    VALUES (v_year::int, 1, 1)
    ON CONFLICT (id)
    DO UPDATE SET counter = public.invoice_counter.counter + 1
    RETURNING counter INTO v_seq;

    v_invoice_no := 'INV-' || v_year || '-' || lpad(v_seq::text, 4, '0');

    -- Insert Order
    INSERT INTO public.orders (
        invoice_no, user_id, customer_name, phone, address, items,
        subtotal, shipping, total, status, order_mode, order_type,
        delivery_charge, discount_amount, manual_discount_amount,
        manual_discount_type, manual_discount_value, coupon_code, coupon_percentage,
        total_gst, payment_method, split_details, gst_enabled
    ) VALUES (
        v_invoice_no, auth.uid(), p_customer_name, p_phone, p_address, p_items,
        v_subtotal, p_shipping, v_total, p_status, p_order_mode, p_order_type,
        p_delivery_charge, p_discount_amount, p_manual_discount_amount,
        p_manual_discount_type, p_manual_discount_value, p_coupon_code, p_coupon_percentage,
        p_total_gst, p_payment_method, p_split_details, p_gst_enabled
    ) RETURNING id INTO v_order_id;

    -- Process Items and Deduct Stock
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        -- Deduct stock logic (Product)
        IF v_item->>'id' IS NOT NULL THEN
           UPDATE public.products
           SET 
             stock_quantity = stock_quantity - COALESCE((v_item->>'quantity')::NUMERIC, 0),
             stock = stock - COALESCE((v_item->>'quantity')::NUMERIC, 0)
           WHERE id = (v_item->>'id')::BIGINT;
        END IF;

        -- Deduct stock logic (Variant)
        IF v_item->>'variant_id' IS NOT NULL THEN
           UPDATE public.product_variants
           SET stock = stock - COALESCE((v_item->>'quantity')::NUMERIC, 0)
           WHERE id = (v_item->>'variant_id')::UUID;
        END IF;

        -- Insert Order Item
        INSERT INTO public.order_items (
            order_id, product_id, variant_id, name, product_name, tamil_name, quantity, unit,
            unit_type, base_quantity, base_price, line_total, image_url,
            discount, gst_amount, gst_rate
        ) VALUES (
            v_order_id,
            (v_item->>'id')::BIGINT,
            (v_item->>'variant_id')::UUID,
            v_item->>'name',
            v_item->>'name',
            v_item->>'tamil_name',
            COALESCE((v_item->>'quantity')::NUMERIC, 0),
            v_item->>'unit',
            v_item->>'unit_type',
            COALESCE((v_item->>'base_quantity')::NUMERIC, 0),
            COALESCE((v_item->>'base_price')::NUMERIC, 0),
            COALESCE((v_item->>'line_total')::NUMERIC, 0),
            v_item->>'image_url',
            COALESCE((v_item->>'discount')::NUMERIC, 0),
            COALESCE((v_item->>'gst_amount')::NUMERIC, 0),
            COALESCE((v_item->>'gst_rate')::NUMERIC, 0)
        );
    END LOOP;

    RETURN jsonb_build_object(
        'orderId', v_order_id,
        'invoiceNo', v_invoice_no,
        'createdAt', now()
    );
END;
$$;
