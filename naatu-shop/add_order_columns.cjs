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
    
    const fixSql = `
      ALTER TABLE public.orders
        ADD COLUMN IF NOT EXISTS manual_discount_amount NUMERIC(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS manual_discount_type TEXT DEFAULT 'flat',
        ADD COLUMN IF NOT EXISTS manual_discount_value NUMERIC(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS coupon_percentage NUMERIC(5,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS total_gst NUMERIC(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash',
        ADD COLUMN IF NOT EXISTS split_details JSONB,
        ADD COLUMN IF NOT EXISTS gst_enabled BOOLEAN DEFAULT false;
    `;
    console.log('Adding missing ZERA POS columns to orders table...');
    await client.query(fixSql);

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
