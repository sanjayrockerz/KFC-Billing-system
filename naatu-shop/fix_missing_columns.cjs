const { Client } = require('pg');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('Connecting to Supabase...');
    await client.connect();

    // Fix categories
    await client.query(`
      ALTER TABLE public.categories 
        ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
        ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0,
        ADD COLUMN IF NOT EXISTS name_ta TEXT DEFAULT '';
    `);

    // Fix products
    await client.query(`
      ALTER TABLE public.products
        ADD COLUMN IF NOT EXISTS category_id BIGINT,
        ADD COLUMN IF NOT EXISTS name_ta TEXT DEFAULT '',
        ADD COLUMN IF NOT EXISTS tamil_name TEXT DEFAULT '',
        ADD COLUMN IF NOT EXISTS remedy TEXT[] DEFAULT '{}',
        ADD COLUMN IF NOT EXISTS offer_price NUMERIC(10,2),
        ADD COLUMN IF NOT EXISTS unit_type TEXT DEFAULT 'unit',
        ADD COLUMN IF NOT EXISTS unit_label TEXT DEFAULT 'piece',
        ADD COLUMN IF NOT EXISTS base_quantity NUMERIC(12,3) DEFAULT 1,
        ADD COLUMN IF NOT EXISTS stock_quantity NUMERIC(12,3) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS stock_unit TEXT DEFAULT 'piece',
        ADD COLUMN IF NOT EXISTS allow_decimal_quantity BOOLEAN DEFAULT false,
        ADD COLUMN IF NOT EXISTS predefined_options JSONB DEFAULT '[]',
        ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
        ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0,
        ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT '100g',
        ADD COLUMN IF NOT EXISTS rating NUMERIC(3,1) DEFAULT 4.7,
        ADD COLUMN IF NOT EXISTS description_ta TEXT DEFAULT '',
        ADD COLUMN IF NOT EXISTS benefits_ta TEXT DEFAULT '',
        ADD COLUMN IF NOT EXISTS image_url TEXT DEFAULT '/assets/images/default-herb.jpg',
        ADD COLUMN IF NOT EXISTS has_variants BOOLEAN DEFAULT false,
        ADD COLUMN IF NOT EXISTS sku TEXT,
        ADD COLUMN IF NOT EXISTS barcode TEXT,
        ADD COLUMN IF NOT EXISTS brand TEXT,
        ADD COLUMN IF NOT EXISTS purchase_price NUMERIC(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS mrp NUMERIC(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS gst_percent NUMERIC(5,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS opening_stock NUMERIC(12,3) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS low_stock_alert NUMERIC(12,3) DEFAULT 5,
        ADD COLUMN IF NOT EXISTS supplier TEXT,
        ADD COLUMN IF NOT EXISTS size TEXT,
        ADD COLUMN IF NOT EXISTS color TEXT;
    `);

    // Fix orders
    await client.query(`
      ALTER TABLE public.orders
        ADD COLUMN IF NOT EXISTS order_mode TEXT DEFAULT 'offline',
        ADD COLUMN IF NOT EXISTS order_type TEXT DEFAULT 'pos_sale',
        ADD COLUMN IF NOT EXISTS coupon_code TEXT,
        ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS manual_discount_amount NUMERIC(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS delivery_charge NUMERIC(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS total_gst NUMERIC(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS gst_amount NUMERIC(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'cash',
        ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash',
        ADD COLUMN IF NOT EXISTS invoice_pdf_url TEXT;
    `);

    // Fix order_items
    await client.query(`
      ALTER TABLE public.order_items
        ADD COLUMN IF NOT EXISTS is_manual BOOLEAN DEFAULT false,
        ADD COLUMN IF NOT EXISTS product_name TEXT;
    `);

    console.log('Columns added successfully.');

    console.log('Reloading PostgREST schema cache...');
    await client.query("NOTIFY pgrst, 'reload schema'");
    console.log('Schema cache reloaded.');
    
  } catch (error) {
    console.error('Error executing SQL:', error);
  } finally {
    await client.end();
  }
}

run();
