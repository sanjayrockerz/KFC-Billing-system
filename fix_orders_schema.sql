ALTER TABLE orders ADD COLUMN IF NOT EXISTS invoice_no TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS items JSONB NOT NULL DEFAULT '[]';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS subtotal NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipping NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS total NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Product table compatibility patch for multilingual/admin dashboard fields.
ALTER TABLE products ADD COLUMN IF NOT EXISTS name_ta TEXT DEFAULT '';
ALTER TABLE products ADD COLUMN IF NOT EXISTS offer_price NUMERIC(10,2);
ALTER TABLE products ADD COLUMN IF NOT EXISTS description_ta TEXT DEFAULT '';
ALTER TABLE products ADD COLUMN IF NOT EXISTS benefits_ta TEXT DEFAULT '';
ALTER TABLE products ADD COLUMN IF NOT EXISTS remedy TEXT[] DEFAULT '{}';
ALTER TABLE products ADD COLUMN IF NOT EXISTS image TEXT DEFAULT '/assets/images/default-herb.jpg';
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_url TEXT;

UPDATE products
SET image = COALESCE(NULLIF(image, ''), image_url, '/assets/images/default-herb.jpg')
WHERE image IS NULL OR image = '';

-- Ensure admin role field exists before policies reference it.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS mobile TEXT DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT;
UPDATE public.profiles SET role = 'customer' WHERE role IS NULL OR role = '';

DROP POLICY IF EXISTS "Users can insert own orders" ON orders;
DROP POLICY IF EXISTS "Users can read own orders" ON orders;
DROP POLICY IF EXISTS "Admins can read all orders" ON orders;

CREATE POLICY "Users can insert own orders" ON orders
FOR INSERT
WITH CHECK (auth.uid()::TEXT = user_id::TEXT OR user_id IS NULL);

CREATE POLICY "Users can read own orders" ON orders
FOR SELECT
USING (auth.uid()::TEXT = user_id::TEXT);

CREATE POLICY "Admins can read all orders" ON orders
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid() AND COALESCE(p.role, 'customer') = 'admin'
  )
);
