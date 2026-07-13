const { Client } = require('pg');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('Restoring store settings to Naatu Herbal Store...');
    
    // Update store settings to Naatu
    const res = await client.query(`
      UPDATE public.store_settings 
      SET 
        name = 'Naatu Herbal Store', 
        owner_name = 'Naatu Admin',
        address = 'Naatu Herbal Store',
        phone = ''
    `);
    
    console.log(`Updated ${res.rowCount} store settings rows.`);
    
  } catch (error) {
    console.error('Error executing SQL:', error);
  } finally {
    await client.end();
  }
}

run();
