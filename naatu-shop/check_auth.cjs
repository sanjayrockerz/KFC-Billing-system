const { Client } = require('pg');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    
    // Check users in auth.users
    const users = await client.query('SELECT id, email, raw_app_meta_data FROM auth.users;');
    console.log(`Found ${users.rowCount} users in auth.users.`);
    if (users.rowCount > 0) {
      console.log(users.rows);
    }

    // Check user_id on orders
    const orders = await client.query('SELECT id, user_id FROM public.orders LIMIT 5;');
    console.log('Orders user_ids:', orders.rows.map(o => o.user_id));

  } catch (error) {
    console.error(error);
  } finally {
    await client.end();
  }
}
run();
