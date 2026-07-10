# Korean Fried Chicken Admin

Admin dashboard + POS system for Korean Fried Chicken, Coimbatore.

Built with Vite + React + Supabase.

## Vercel Deployment

- Framework preset: `Vite`
- Build command: `npm run build`
- Output directory: `dist`

Set these environment variables in Vercel:

```dotenv
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```

## Routes

- `/dashboard` — Admin dashboard
- `/pos` — POS billing
- `/login` — Login
- `/invoice/:id` — Digital invoice
