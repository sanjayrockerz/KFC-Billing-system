import { jsPDF } from 'jspdf'
import { BRAND_ADDRESS, BRAND_EMAIL, BRAND_EN, BRAND_PHONE_DISPLAY } from './brand'
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
  amountReceived?: number
  balanceReturned?: number
}

const money = (value: number) => formatCurrency(Number(value || 0)).replace(/\s+/g, ' ')
const dateText = (value: string) => new Date(value).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })

/** Aligned A4 invoice used by POS sharing and the public digital invoice. */
export function createInvoicePdf(data: InvoicePdfData): Blob {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' })
  const pageWidth = doc.internal.pageSize.getWidth()
  const pageHeight = doc.internal.pageSize.getHeight()
  const left = 16
  const right = pageWidth - 16
  const width = right - left
  const gold = '#D4A800'
  const green = '#245C2A'
  const ink = '#18202A'
  const muted = '#68717C'
  let y = 16

  doc.setFont('helvetica', 'bold'); doc.setFontSize(8); doc.setTextColor(muted)
  doc.text('INVOICE', left, y)
  doc.text(`Invoice: ${data.invoiceNo}`, right, y, { align: 'right' })
  y += 7; doc.setDrawColor('#D8DCE0'); doc.line(left, y, right, y); y += 10

  doc.setTextColor(gold); doc.setFontSize(18); doc.text(BRAND_EN, left, y)
  doc.setFont('helvetica', 'normal'); doc.setFontSize(8); doc.setTextColor(muted)
  doc.text(BRAND_ADDRESS, left, y + 5, { maxWidth: 108 })
  doc.text(`Phone: ${BRAND_PHONE_DISPLAY}`, left, y + 10)
  doc.text(`Date: ${dateText(data.date)}`, right, y + 2, { align: 'right' })
  doc.text(`Payment: ${data.paymentMode || 'POS'}`, right, y + 7, { align: 'right' })
  y += 23

  doc.setFillColor('#FFF9E8'); doc.roundedRect(left, y, width, 22, 2, 2, 'F')
  doc.setFont('helvetica', 'bold'); doc.setFontSize(7); doc.setTextColor(muted); doc.text('BILL TO', left + 5, y + 7)
  doc.setFontSize(10); doc.setTextColor(ink); doc.text(data.customerName || 'Walk-in Customer', left + 5, y + 13)
  doc.setFont('helvetica', 'normal'); doc.setFontSize(8); doc.setTextColor(muted)
  doc.text(`${data.phone || '-'}${data.address ? `  |  ${data.address}` : ''}`, left + 5, y + 18, { maxWidth: width - 10 })
  y += 31

  doc.setFillColor(green); doc.rect(left, y, width, 9, 'F')
  doc.setFont('helvetica', 'bold'); doc.setFontSize(7); doc.setTextColor('#FFFFFF')
  doc.text('#', left + 4, y + 6); doc.text('PRODUCT', left + 14, y + 6)
  doc.text('QTY', 142, y + 6, { align: 'right' }); doc.text('RATE', 168, y + 6, { align: 'right' }); doc.text('AMOUNT', right - 4, y + 6, { align: 'right' })
  y += 14

  data.items.forEach((raw, index) => {
    const item = normalizeStructuredOrderItem(raw)
    const nameTa = typeof raw.nameTa === 'string' ? raw.nameTa : typeof raw.tamil_name === 'string' ? raw.tamil_name : ''
    if (y > pageHeight - 58) { doc.addPage(); y = 20 }
    const nameLines = doc.splitTextToSize(item.name || 'Item', 106) as string[]
    const rowHeight = Math.max(11, nameLines.length * 4.2 + (nameTa ? 4 : 0) + 3)
    doc.setFont('helvetica', 'normal'); doc.setFontSize(8); doc.setTextColor(muted)
    doc.text(String(index + 1), left + 4, y + 1)
    doc.setFont('helvetica', 'bold'); doc.setFontSize(9); doc.setTextColor(ink)
    doc.text(nameLines, left + 14, y + 1, { baseline: 'top' })
    if (nameTa) { doc.setFont('helvetica', 'normal'); doc.setFontSize(7); doc.setTextColor(muted); doc.text(nameTa, left + 14, y + nameLines.length * 4.2 + 2) }
    doc.setFont('helvetica', 'bold'); doc.setFontSize(9); doc.setTextColor(ink)
    doc.text(formatQuantityDisplay(item.quantity, item.unit, item.unit_type), 142, y + 3, { align: 'right' })
    doc.text(money(item.base_price), 168, y + 3, { align: 'right' })
    doc.text(money(item.line_total), right - 4, y + 3, { align: 'right' })
    y += rowHeight
    doc.setDrawColor('#E8EAED'); doc.setLineWidth(0.2); doc.line(left, y - 3, right, y - 3)
  })

  y = Math.max(y + 8, 150)
  const rows: Array<[string, string, string]> = [['Subtotal', money(data.subtotal), ink]]
  if ((data.discountAmount || 0) > 0) rows.push([`Coupon${data.couponCode ? ` (${data.couponCode})` : ''}`, `-${money(data.discountAmount || 0)}`, '#198754'])
  if ((data.manualDiscountAmount || 0) > 0) rows.push(['Manual Discount', `-${money(data.manualDiscountAmount || 0)}`, '#198754'])
  if ((data.gstAmount || 0) > 0) rows.push(['GST', money(data.gstAmount || 0), ink])
  if ((data.amountReceived || 0) > 0) rows.push(['Received', money(data.amountReceived || 0), ink])
  if ((data.balanceReturned || 0) > 0) rows.push(['Change', money(data.balanceReturned || 0), '#198754'])
  rows.push(['Delivery', (data.shipping || 0) > 0 ? money(data.shipping) : 'FREE', '#198754'])
  doc.setFontSize(9)
  rows.forEach(([label, value, color]) => { doc.setFont('helvetica', 'normal'); doc.setTextColor(color); doc.text(label, 145, y, { align: 'right' }); doc.text(value, right - 4, y, { align: 'right' }); y += 7 })
  doc.setDrawColor(green); doc.setLineWidth(0.7); doc.line(118, y - 3, right, y - 3)
  doc.setFont('helvetica', 'bold'); doc.setFontSize(14); doc.setTextColor(green)
  doc.text('TOTAL', 145, y + 6, { align: 'right' }); doc.text(money(data.total), right - 4, y + 6, { align: 'right' })

  const footerY = pageHeight - 25
  doc.setDrawColor('#D8DCE0'); doc.setLineWidth(0.2); doc.line(left, footerY, right, footerY)
  doc.setFont('helvetica', 'bold'); doc.setFontSize(8); doc.setTextColor(green); doc.text('THANK YOU FOR SHOPPING WITH US', pageWidth / 2, footerY + 8, { align: 'center' })
  doc.setFont('helvetica', 'normal'); doc.setFontSize(7); doc.setTextColor(muted); doc.text(`${BRAND_EMAIL}  |  ${BRAND_PHONE_DISPLAY}`, pageWidth / 2, footerY + 14, { align: 'center' })
  return doc.output('blob')
}

export function invoicePdfFile(data: InvoicePdfData): File {
  return new File([createInvoicePdf(data)], `Invoice-${data.invoiceNo}.pdf`, { type: 'application/pdf' })
}
