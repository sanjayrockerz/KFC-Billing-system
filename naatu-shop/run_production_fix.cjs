const fs = require('fs');
const path = require('path');
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

    console.log('Running PRODUCTION_FIX.sql...');
    const sql = fs.readFileSync(path.join(__dirname, 'PRODUCTION_FIX.sql'), 'utf8');
    
    await client.query(sql);

    console.log('PRODUCTION_FIX applied successfully!');
    
  } catch (error) {
    console.error('Error executing SQL:', error);
  } finally {
    await client.end();
  }
}

run();
