const { Client } = require('pg');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('Cleaning up unwanted categories...');
    
    // Delete the unwanted categories
    const res = await client.query(`
      DELETE FROM public.categories 
      WHERE name_en IN ('Bridal Shawl', 'Shawl') OR name_ta IN ('Bridal Shawl', 'Shawl')
    `);
    
    console.log(`Deleted ${res.rowCount} unwanted categories.`);
    
  } catch (error) {
    console.error('Error executing SQL:', error);
  } finally {
    await client.end();
  }
}

run();
