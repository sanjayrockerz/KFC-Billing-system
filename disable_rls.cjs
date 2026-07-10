const { Client } = require('pg');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('Connected to DB');
    
    const sql = `
      ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
      ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;
      ALTER TABLE public.order_items DISABLE ROW LEVEL SECURITY;
      ALTER TABLE public.categories DISABLE ROW LEVEL SECURITY;
      ALTER TABLE public.product_variants DISABLE ROW LEVEL SECURITY;
      
      -- Just in case, add an open policy if RLS gets re-enabled
      DROP POLICY IF EXISTS "Enable all access for all users" ON public.products;
      CREATE POLICY "Enable all access for all users" ON public.products FOR ALL USING (true) WITH CHECK (true);
    `;
    console.log('Disabling RLS on tables...');
    await client.query(sql);

    console.log('Reloading PostgREST schema cache...');
    await client.query("NOTIFY pgrst, 'reload schema'");
    
    console.log('RLS disabled successfully!');
  } catch (err) {
    console.error(err);
  } finally {
    await client.end();
  }
}

run();
