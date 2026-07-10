# New Shop Setup Guide

Spin up a fully branded admin billing system for a new store in under 2 minutes.

## One-Command Setup

```powershell
# From naatu-shop/ directory:
.\scripts\new-shop.ps1 -ShopName "Your Store" -ShopNameTamil "உங்கள் கடை" -ShopPhone "+91 9876543210" -ShopPhoneE164 "919876543210"
```

### Full Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `ShopName` | ✅ | English store name (e.g. "My Herbal Store") |
| `ShopNameTamil` | ✅ | Tamil store name |
| `ShopPhone` | ✅ | Display phone (e.g. "+91 9876543210") |
| `ShopPhoneE164` | ✅ | E164 phone (e.g. "919876543210") |
| `SupabaseUrl` | - | New Supabase project URL |
| `SupabaseAnonKey` | - | New Supabase anon key |
| `ShopEmail` | - | Store email |
| `ShopAddress` | - | Store address |
| `Subtitle` | - | Tagline (default: "Admin Dashboard") |
| `NewRepoDir` | - | Output directory (default: `../<shopname>-admin`) |
| `MaroonHex` | - | Primary color hex (default: `#8B1C31`) |
| `MaroonDarkHex` | - | Dark primary hex (default: `#601424`) |

## What the Script Does

1. **Copies** the entire `naatu-shop/` to a new folder
2. **Rewrites** `src/lib/brand.ts` with your new brand info
3. **Updates** `index.html` title, meta, Open Graph tags
4. **Replaces** all "Zera Admin Billing", "ZERA", "zera-logo", localStorage keys, and store names across every source file
5. **Generates** a fresh `.env.example` with your Supabase credentials
6. **Renames** logo asset (`zera-logo.png` → `<shopname>-logo.png`)
7. **Inits** a new git repo and makes the initial commit

## After the Script — Manual Steps

### 1. Logo
Replace `public/<shopname>-logo.png` with your actual store logo (recommended: 200×60px PNG).

### 2. Colors (optional)
Edit `tailwind.config.js` to change the maroon palette:

```js
maroon: {
  DEFAULT: '#8B1C31',   // ← primary brand color
  dark: '#601424',      // ← darker shade
}
```

Search the codebase for `#8B1C31` and `#601424` if you want to replace all occurrences.

### 3. Supabase
Run the Supabase migration SQL from `supabase/` in your new Supabase project's SQL Editor, then copy credentials to `.env`.

### 4. Git Remote & Deploy

```bash
cd <your-new-shop-dir>
git remote add origin https://github.com/your-org/your-new-repo.git
git push -u origin main
```

Deploy on Vercel:
- Import the new repo
- Add env vars (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`)
- Root directory: `./` (not `naatu-shop/`)
- Build command: `cd naatu-shop && npm install && npm run build`
- Output directory: `naatu-shop/dist`

### 5. Verify
Visit your deployed site. The name, logo, phone, WhatsApp link, email, and address should all reflect the new brand.

## What Stays the Same

- All features (POS billing, catalog, coupons, WhatsApp center, analytics, thermal printing, digital invoice)
- All business logic (GST, discounts, stock management)
- All page layouts and UX
- Recharts, Supabase, Lucide icons, Tailwind

Only branding and credentials change.
