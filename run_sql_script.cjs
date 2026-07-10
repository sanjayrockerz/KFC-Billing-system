const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: {
      rejectUnauthorized: false
    }
  });

  try {
    console.log('Connecting to Supabase...');
    await client.connect();
    
    const fixSql = `
      ALTER TABLE public.products ADD COLUMN IF NOT EXISTS has_variants BOOLEAN NOT NULL DEFAULT false;

      ALTER TABLE public.product_variants
        ADD COLUMN IF NOT EXISTS variant_name TEXT,
        ADD COLUMN IF NOT EXISTS size_label TEXT,
        ADD COLUMN IF NOT EXISTS weight_value NUMERIC(10,3),
        ADD COLUMN IF NOT EXISTS weight_unit TEXT,
        ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT false,
        ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS image_url TEXT,
        ADD COLUMN IF NOT EXISTS group_name TEXT;

      ALTER TABLE public.orders
        ADD COLUMN IF NOT EXISTS order_mode TEXT,
        ADD COLUMN IF NOT EXISTS order_type TEXT,
        ADD COLUMN IF NOT EXISTS coupon_code TEXT,
        ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(10,2),
        ADD COLUMN IF NOT EXISTS delivery_charge NUMERIC(10,2);
    `;
    console.log('Fixing schema columns...');
    await client.query(fixSql);

    console.log('Running seed script...');
    const seedSql = fs.readFileSync(path.join(__dirname, 'seed_zera_data.sql'), 'utf8');
    await client.query(seedSql);

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
