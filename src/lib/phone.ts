import { BRAND_WHATSAPP_LINK } from './brand'

const MY_CODE = '60'

/**
 * Normalizes any Malaysian phone input to the 11-12 digit form 60XXXXXXXXX.
 *
 * Accepted inputs:
 *   0123456789          → 60123456789
 *   012-345 6789        → 60123456789
 *   +60123456789        → 60123456789
 *   +60 12-345 6789     → 60123456789
 *   60123456789         → 60123456789 (already normalized)
 *   1123456789          → 601123456789
 *
 * Returns null for anything that cannot be reduced to a valid
 * Malaysian mobile number (starts with 1 after country code).
 */
export function normalizePhone(input: string): string | null {
  if (!input) return null

  const raw = input.replace(/\D/g, '')
  if (!raw) return null

  let digits = raw

  if (digits.startsWith('60')) {
    // keep as-is
  } else if (digits.startsWith('+60') || digits.startsWith('0060')) {
    digits = '60' + digits.replace(/^0{0,2}60/, '')
  } else if (digits.startsWith('0')) {
    digits = '60' + digits.slice(1)
  } else {
    // assume subscriber digits without country code (e.g. 1123456789)
    digits = '60' + digits
  }

  // After +60, subscriber portion must start with 1 and be 9-10 digits
  // Total E.164 with 60: 11-12 digits
  if (!/^601\d{8,9}$/.test(digits)) return null

  return digits
}

/** Returns true when the input can be normalized to a valid Malaysian number. */
export function isValidPhone(input: string): boolean {
  return normalizePhone(input) !== null
}

/**
 * Returns the subscriber number without country code (after +60).
 * Useful for display or storing in DB alongside a known +60 prefix.
 */
export function getSubscriberDigits(input: string): string | null {
  const normalized = normalizePhone(input)
  return normalized ? normalized.slice(2) : null
}

/**
 * Builds a wa.me URL for the given Malaysian phone number.
 * Falls back to the store's WhatsApp link if the number is invalid.
 */
export function toWhatsAppUrl(phone: string, fallback?: string): string {
  const normalized = normalizePhone(phone)
  if (normalized) return `https://wa.me/${normalized}`
  return fallback ?? BRAND_WHATSAPP_LINK
}
