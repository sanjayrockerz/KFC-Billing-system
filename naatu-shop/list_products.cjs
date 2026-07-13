const { Client } = require('pg');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    const res = await client.query('SELECT id, name, category FROM public.products');
    console.log(`Found ${res.rowCount} products.`);
    if (res.rowCount > 0) {
      console.log(res.rows.slice(0, 10)); // just print first 10
    }
    
    // Also delete any products that belong to the herbal categories
    const delRes = await client.query(`
      DELETE FROM public.products
      WHERE category IN (
        'Pooja Items', 'Herbal Powder', 'Herbal Oil', 
        'Spices & Condiments', 'Grains & Pulses', 
        'Honey & Liquids', 'Bundle Packages'
      )
    `);
    console.log(`Deleted ${delRes.rowCount} Herbal products.`);
    
  } catch (error) {
    console.error(error);
  } finally {
    await client.end();
  }
}
run();
