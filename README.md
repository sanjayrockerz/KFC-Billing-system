# Korean Fried Chicken Billing System

Standalone React + Supabase billing/admin system for Korean Fried Chicken.

## Business Details

- Business: Korean Fried Chicken
- Owner: Sulficker Roshan N
- Phone: +91 9342489391
- Address: Nanjappa Garden Selvapuram, Shivalaya Mahal Road, SBI Bank Opposite, Komarapalayam, Coimbatore

## Catalog

- Bone Shot
- Big Shot
- Strips
- Loaded Fries
- French Fries
- Wrap
- Burger

## Local Setup

```bash
npm install
npm run dev
```

Create `.env.local` from `.env.example`:

```bash
VITE_SUPABASE_URL=your-supabase-url
VITE_SUPABASE_ANON_KEY=your-supabase-anon-key
```

## Supabase Setup

Run this migration in Supabase SQL Editor:

```text
supabase/migrations/20260715_0001_kfc_catalog_backend_sync.sql
```

It creates/syncs:

- categories and products
- coupons
- orders and order_items
- invoice number generation
- order creation RPC
- public invoice lookup RPC
- RLS policies required by the local password-protected admin portal

## Admin Access

- Admin password: `sulficker11`
- Staff/POS password: `staff123`

## Main Routes

- `/admin-login`
- `/dashboard`
- `/pos`
- `/invoice/:invoiceNo`

## Build

```bash
npm run build
```
