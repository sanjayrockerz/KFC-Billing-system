import { BRAND_PHONE_DISPLAY } from './brand'
import { formatCurrency } from './retail'

export type WhatsAppLineItem = {
  name: string
  qty: number
  unit: string
  unitType: 'unit' | 'weight' | 'volume' | 'bundle'
  rate: number
  lineTotal: number
}

type BuildWhatsAppMessageInput = {
  customerName?: string
  phone?: string
  invoiceNumber: string
  invoiceDate?: string
  paymentMode?: string
  items: WhatsAppLineItem[]
  subtotal: number
  couponDiscount?: number
  manualDiscountAmount?: number
  shipping?: number
  gstAmount?: number
  total: number
  invoiceUrl?: string
}

const divider = '-'.repeat(18)
const emoji = {
  shoppingBag: String.fromCodePoint(0x1F6CD, 0xFE0F),
  receipt: String.fromCodePoint(0x1F9FE),
  shoppingCart: String.fromCodePoint(0x1F6D2),
  money: String.fromCodePoint(0x1F4B0),
  document: String.fromCodePoint(0x1F4C4),
  heart: String.fromCodePoint(0x2764, 0xFE0F),
  pin: String.fromCodePoint(0x1F4CD),
  phone: String.fromCodePoint(0x1F4DE),
  smile: String.fromCodePoint(0x1F60A),
}

export const buildProfessionalWhatsAppMessage = (input: BuildWhatsAppMessageInput) => {
  const dateStr = input.invoiceDate || new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
  const customerName = input.customerName || 'Valued Customer'
  const phone = input.phone || '-'
  const paymentMode = input.paymentMode || 'POS'

  const itemLines = input.items.map(item => (
    `\u2022 ${item.name}\n  Qty : ${item.qty} \u00D7 ${formatCurrency(item.rate)}\n  Amount : ${formatCurrency(item.lineTotal)}`
  ))

  const couponLine = (input.couponDiscount || 0) > 0
    ? `Coupon Discount    : -${formatCurrency(input.couponDiscount || 0)}` : ''

  const manualLine = (input.manualDiscountAmount || 0) > 0
    ? `Manual Discount    : -${formatCurrency(input.manualDiscountAmount || 0)}` : ''

  const gstLine = (input.gstAmount || 0) > 0
    ? `GST                : ${formatCurrency(input.gstAmount || 0)}` : ''

  const deliveryLine = (input.shipping || 0) > 0
    ? `Delivery Charges   : ${formatCurrency(input.shipping || 0)}` : ''

  return [
    `${emoji.shoppingBag} *Thank you for shopping with Korean Fried Chicken!*`,
    '',
    `Dear *${customerName}*,`,
    '',
    `We truly appreciate your purchase and hope you enjoyed your shopping experience with us.`,
    '',
    divider,
    `${emoji.receipt} *INVOICE SUMMARY*`,
    divider,
    '',
    `Invoice No : ${input.invoiceNumber}`,
    `Date : ${dateStr}`,
    '',
    `Customer : ${customerName}`,
    `Phone : ${phone}`,
    '',
    divider,
    `${emoji.shoppingCart} *ITEMS PURCHASED*`,
    divider,
    '',
    ...itemLines,
    '',
    divider,
    `${emoji.money} *BILL SUMMARY*`,
    divider,
    '',
    `Subtotal           : ${formatCurrency(input.subtotal)}`,
    couponLine,
    manualLine,
    gstLine,
    deliveryLine,
    '',
    divider,
    `*Grand Total : ${formatCurrency(input.total)}*`,
    divider,
    '',
    `Payment Mode : ${paymentMode}`,
    '',
    input.invoiceUrl ? `${emoji.document} *Download Invoice:*\n${input.invoiceUrl}` : '',
    '',
    `We sincerely thank you for choosing *Korean Fried Chicken*. ${emoji.heart}`,
    '',
    `We look forward to serving you again.`,
    '',
    `${emoji.pin} *Korean Fried Chicken*`,
    `Nanjappa Garden, Selvapuram,`,
    `SBI Bank Opposite, Shivalaya Mahal Road,`,
    `Komarapalayam, Coimbatore`,
    '',
    `${emoji.phone} ${BRAND_PHONE_DISPLAY}`,
    '',
    `Have a wonderful day! ${emoji.smile}`,
  ].filter(Boolean).join('\n')
}
