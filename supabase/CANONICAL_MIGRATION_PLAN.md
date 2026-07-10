# Canonical Supabase Migration Path

This project now uses exactly one migration path:

1. `supabase_schema.sql` as baseline reference (schema intent only).
2. `supabase/migrations/20260426_0001_canonical_hardening.sql`
3. `supabase/migrations/20260426_0002_order_items_atomic_order.sql`

## Deprecated/ignored setup scripts

These files are no longer the active setup path and should not be mixed into new environments:

- `COMPLETE_SETUP.sql`
- `fix_schema.sql`
- `fix_orders_schema.sql`
- `retail_pos_inventory_migration.sql`
- `seed_products.sql` (seed-only, not schema authority)

## Why this path

- Removes policy drift and conflicting admin checks.
- Hardens auth/RLS with one consistent model.
- Adds canonical indexes required for RLS/search.
- Introduces normalized `order_items` and atomic order creation RPC.

## Execution order (when ready)

1. Validate current schema backup in Supabase.
2. Apply `20260426_0001_canonical_hardening.sql`.
3. Apply `20260426_0002_order_items_atomic_order.sql`.
4. Update frontend to use canonical RPC path (`create_order_with_stock`) for POS + checkout.
