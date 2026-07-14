const { Client } = require('pg');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('Dropping health_tags table...');
    await client.query('DROP TABLE IF EXISTS public.health_tags CASCADE;');
    console.log('Dropped health_tags.');
  } catch (error) {
    console.error(error);
  } finally {
    await client.end();
  }
}
run();
