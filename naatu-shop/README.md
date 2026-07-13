# Zera Admin Billing Template

This project is now prepared as an admin-only Vite + React template for:

- POS billing
- Order management
- Coupon management
- Customer management
- Billing analytics
- Supabase-backed admin workflows

The storefront pages are no longer part of the active app shell used for deployment. Vercel should deploy only the admin experience.

## Vercel Deployment

Deploy the `naatu-shop` folder in Vercel.

- Framework preset: `Vite`
- Build command: `npm run build`
- Output directory: `dist`

Set these environment variables in Vercel:

```dotenv
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```

## Routes

Primary routes in the deployed admin template:

- `/dashboard`
- `/admin`
- `/pos`
- `/whatsapp-center`
- `/pos-analytics`
- `/invoice/:id`
- `/login`

## Branding

Update branding in:

- `src/lib/brand.ts`
- `index.html`
- `public/zera-logo.png`
- `public/favicon.jpg`

## Template Notes

- Product and order data still come from Supabase.
- Invoice generation remains available for billing workflows.
- Storefront-specific SEO and customer browsing flow have been removed from the runtime shell so this can be reused for other branded admin projects.
