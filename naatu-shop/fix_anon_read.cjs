const { Client } = require('pg');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    
    // Add an anon select policy to orders so the dashboard works
    await client.query(`
      DROP POLICY IF EXISTS orders_anon_select ON public.orders;
      CREATE POLICY orders_anon_select ON public.orders FOR SELECT TO anon USING (true);
    `);
    
    console.log('Added anon select policy for orders.');
  } catch (error) {
    console.error(error);
  } finally {
    await client.end();
  }
}
run();
