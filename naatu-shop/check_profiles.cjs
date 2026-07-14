const { Client } = require('pg');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    const res = await client.query('SELECT id, email, role FROM public.profiles;');
    console.log(`Found ${res.rowCount} profiles.`);
    if (res.rowCount > 0) {
      console.log(res.rows);
    }
  } catch (error) {
    console.error(error);
  } finally {
    await client.end();
  }
}
run();
