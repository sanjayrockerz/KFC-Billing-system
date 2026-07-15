# Korean Fried Chicken Deployment Checklist

1. Add Supabase values to `.env.local` or hosting environment variables.
2. Run `supabase/migrations/20260715_0001_kfc_catalog_backend_sync.sql`.
3. If sale completion shows `orders_invoice_no_key`, run `supabase/migrations/20260715_0002_fix_invoice_collision.sql`.
4. Run `npm run build`.
5. Open `/admin-login` and sign in with the admin password.
6. Confirm categories, products, coupons, billing, WhatsApp invoice links, and `/invoice/:invoiceNo`.
