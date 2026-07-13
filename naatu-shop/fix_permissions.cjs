const { Client } = require('pg');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('Connected to DB');
    
    const grantSql = `
      GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon;
      GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
      
      -- Also make sure the new columns are fully accessible by anon
      GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
      GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
    `;
    console.log('Granting permissions...');
    await client.query(grantSql);

    console.log('Reloading PostgREST schema cache...');
    await client.query("NOTIFY pgrst, 'reload schema'");
    
    console.log('Permissions updated!');
  } catch (err) {
    console.error(err);
  } finally {
    await client.end();
  }
}

run();
