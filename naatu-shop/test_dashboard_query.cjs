const { Client } = require('pg');

const connectionString = 'postgresql://postgres.ilchttmxwqjplueabrem:UwGYnimfV2z1IXSH@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    // Run the exact query from Dashboard.tsx
    const res = await client.query(`
      SELECT id, invoice_no, customer_name, phone, address, created_at, total, status, order_mode, order_type, user_id, items, coupon_code, discount_amount, manual_discount_amount, delivery_charge, total_gst, gst_amount, payment_mode, payment_method, invoice_pdf_url
      FROM public.orders
      ORDER BY created_at DESC
      LIMIT 10
    `);
    console.log(`Success! Fetched ${res.rowCount} rows.`);
  } catch (error) {
    console.error('ERROR running query:', error.message);
  } finally {
    await client.end();
  }
}
run();
