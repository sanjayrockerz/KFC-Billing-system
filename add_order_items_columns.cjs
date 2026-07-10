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
      ALTER TABLE public.order_items
        ADD COLUMN IF NOT EXISTS name TEXT,
        ADD COLUMN IF NOT EXISTS tamil_name TEXT,
        ADD COLUMN IF NOT EXISTS image_url TEXT,
        ADD COLUMN IF NOT EXISTS discount NUMERIC(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS gst_amount NUMERIC(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS gst_rate NUMERIC(5,2) DEFAULT 0;
    `;
    console.log('Adding missing columns to order_items table...');
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
