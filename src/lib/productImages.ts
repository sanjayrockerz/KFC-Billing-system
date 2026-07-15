import type { Product } from '../store/store'
import type { SyntheticEvent } from 'react'

export const PLACEHOLDER = '/logo.png'

export function getProductImage(product?: Partial<Product> | null): string {
  if (!product) return PLACEHOLDER
  return product.imageUrl || product.image || PLACEHOLDER
}

export function resolveProductImage(product?: Partial<Product> | null): string {
  return getProductImage(product)
}

export function onImgError(event: SyntheticEvent<HTMLImageElement>) {
  event.currentTarget.src = PLACEHOLDER
}
