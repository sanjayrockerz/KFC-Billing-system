# Korean Fried Chicken Deployment Checklist

1. Add Supabase values to `.env.local` or hosting environment variables.
2. Run `supabase/migrations/20260715_0001_kfc_catalog_backend_sync.sql`.
3. Run `npm run build`.
4. Open `/admin-login` and sign in with the admin password.
5. Confirm categories, products, coupons, billing, WhatsApp invoice links, and `/invoice/:invoiceNo`.
