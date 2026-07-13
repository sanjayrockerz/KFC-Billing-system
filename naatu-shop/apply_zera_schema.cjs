const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('Connecting to Supabase...');
    await client.connect();
    
    console.log('Running zera_pos_schema.sql...');
    const seedSql = fs.readFileSync(path.join(__dirname, 'zera_pos_schema.sql'), 'utf8');
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
