export const CATALOG_CATEGORIES = [
  'Chicken',
  'Sides',
  'Burgers & Wraps',
  'Beverages',
] as const

const categoryKeys = new Map(
  CATALOG_CATEGORIES.map(category => [category.toLowerCase(), category]),
)

export function canonicalCatalogCategory(value: unknown): string | null {
  const key = String(value ?? '').trim().toLowerCase()
  return categoryKeys.get(key) ?? null
}
