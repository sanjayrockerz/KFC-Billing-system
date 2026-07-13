const { Client } = require('pg');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('Restoring ZERA settings and deleting Herbal stuff...');
    
    // 1. Restore store settings to ZERA
    await client.query(`
      UPDATE public.store_settings 
      SET 
        name = 'ZERA', 
        owner_name = 'Sulficker Roshan N',
        address = 'ZERA, Kurinji Nagar, Brindhavan Circle, Kuniyamuthur',
        phone = '9342489391'
    `);
    
    // 2. Re-insert Bridal Shawl and Shawl if they are missing
    await client.query(`
      INSERT INTO public.categories (name_en, name_ta, is_active, sort_order)
      VALUES 
        ('Bridal Shawl', '', true, 0),
        ('Shawl', '', true, 0)
      ON CONFLICT DO NOTHING;
    `);

    // 3. Delete ALL herbal categories! 
    const res = await client.query(`
      DELETE FROM public.categories 
      WHERE name_en IN (
        'Pooja Items', 'Herbal Powder', 'Herbal Oil', 
        'Spices & Condiments', 'Grains & Pulses', 
        'Honey & Liquids', 'Bundle Packages'
      )
    `);
    console.log(`Deleted ${res.rowCount} Herbal categories.`);
    
  } catch (error) {
    console.error('Error executing SQL:', error);
  } finally {
    await client.end();
  }
}

run();
