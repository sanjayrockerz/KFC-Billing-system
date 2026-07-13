import { jsPDF } from 'jspdf'
import { BRAND_ADDRESS, BRAND_EN, BRAND_PHONE_DISPLAY } from './brand'
import { formatCurrency, formatQuantityDisplay, normalizeStructuredOrderItem } from './retail'

export type InvoicePdfData = {
  invoiceNo: string
  date: string
  customerName: string
  phone: string
  address: string
  items: Array<Record<string, unknown>>
  subtotal: number
  shipping: number
  total: number
  discountAmount?: number
  manualDiscountAmount?: number
  gstAmount?: number
  couponCode?: string | null
  paymentMode?: string
}

const money = (value: number) => formatCurrency(Number(value || 0)).replace(/\s+/g, ' ')

/** Creates a compact A4 invoice that can be attached as a file to WhatsApp. */
export function createInvoicePdf(data: InvoicePdfData): Blob {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' })
  const pageWidth = 210
  const left = 16
  const right = 194
  const red = '#9e1b32'
  const ink = '#18202a'
  const muted = '#68717c'
  let y = 16

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(8)
  doc.setTextColor(muted)
  doc.text('TAX INVOICE', left, y)
  doc.text(`Invoice: ${data.invoiceNo}`, right, y, { align: 'right' })
  y += 7
  doc.setDrawColor('#d8dce0')
  doc.line(left, y, right, y)
  y += 10

  doc.setTextColor(red)
  doc.setFontSize(18)
  doc.text(BRAND_EN, left, y)
  doc.setFontSize(8)
  doc.setTextColor(muted)
  doc.setFont('helvetica', 'normal')
  doc.text(BRAND_ADDRESS, left, y + 5, { maxWidth: 105 })
  doc.text(`Phone: ${BRAND_PHONE_DISPLAY}`, left, y + 10)
  doc.text(`Date: ${new Date(data.date).toLocaleDateString('en-IN')}`, right, y + 2, { align: 'right' })
  doc.text(`Payment: ${data.paymentMode || 'POS'}`, right, y + 7, { align: 'right' })
  y += 23

  doc.setFillColor('#f8f1f2')
  doc.roundedRect(left, y, right - left, 22, 2, 2, 'F')
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(7)
  doc.setTextColor(muted)
  doc.text('BILL TO', left + 5, y + 7)
  doc.setFontSize(10)
  doc.setTextColor(ink)
  doc.text(data.customerName || 'Walk-in Customer', left + 5, y + 13)
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(8)
  doc.setTextColor(muted)
  doc.text(`${data.phone}${data.address ? `  |  ${data.address}` : ''}`, left + 5, y + 18, { maxWidth: 165 })
  y += 31

  doc.setFillColor(red)
  doc.rect(left, y, right - left, 9, 'F')
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(7)
  doc.setTextColor('#ffffff')
  doc.text('#', left + 4, y + 6)
  doc.text('ITEM DESCRIPTION', left + 14, y + 6)
  doc.text('QTY', 140, y + 6, { align: 'right' })
  doc.text('RATE', 166, y + 6, { align: 'right' })
  doc.text('AMOUNT', right - 4, y + 6, { align: 'right' })
  y += 14

  data.items.forEach((raw, index) => {
    const item = normalizeStructuredOrderItem(raw)
    if (y > 260) { doc.addPage(); y = 20 }
    const name = item.name || 'Item'
    const nameLines = doc.splitTextToSize(name, 105) as string[]
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(8)
    doc.setTextColor(ink)
    doc.text(String(index + 1), left + 4, y)
    doc.text(nameLines, left + 14, y)
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(7)
    doc.setTextColor(muted)
    doc.text(`${formatQuantityDisplay(item.quantity, item.unit, item.unit_type)}`, 140, y, { align: 'right' })
    doc.text(money(item.base_price), 166, y, { align: 'right' })
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(8)
    doc.setTextColor(ink)
    doc.text(money(item.line_total), right - 4, y, { align: 'right' })
    y += Math.max(10, nameLines.length * 4 + 4)
    doc.setDrawColor('#e8eaed')
    doc.line(left, y - 3, right, y - 3)
  })

  y = Math.max(y + 6, 150)
  const rows: Array<[string, string, string]> = [['Subtotal', money(data.subtotal), ink]]
  if ((data.discountAmount || 0) > 0) rows.push([`Coupon${data.couponCode ? ` (${data.couponCode})` : ''}`, `-${money(data.discountAmount || 0)}`, '#198754'])
  if ((data.manualDiscountAmount || 0) > 0) rows.push(['Discount', `-${money(data.manualDiscountAmount || 0)}`, '#198754'])
  if ((data.gstAmount || 0) > 0) rows.push(['GST', money(data.gstAmount || 0), ink])
  rows.push(['Delivery', (data.shipping || 0) > 0 ? money(data.shipping) : 'FREE', ink])
  doc.setFontSize(9)
  rows.forEach(([label, value, color]) => { doc.setFont('helvetica', 'normal'); doc.setTextColor(color); doc.text(label, 143, y, { align: 'right' }); doc.text(value, right - 4, y, { align: 'right' }); y += 7 })
  doc.setDrawColor(red)
  doc.setLineWidth(0.7)
  doc.line(118, y - 3, right, y - 3)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(14)
  doc.setTextColor(red)
  doc.text('TOTAL', 143, y + 6, { align: 'right' })
  doc.text(money(data.total), right - 4, y + 6, { align: 'right' })

  y = 275
  doc.setDrawColor('#d8dce0')
  doc.setLineWidth(0.2)
  doc.line(left, y, right, y)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(8)
  doc.setTextColor(red)
  doc.text('THANK YOU FOR SHOPPING WITH US', pageWidth / 2, y + 8, { align: 'center' })
  return doc.output('blob')
}

export function invoicePdfFile(data: InvoicePdfData): File {
  return new File([createInvoicePdf(data)], `Invoice-${data.invoiceNo}.pdf`, { type: 'application/pdf' })
}
