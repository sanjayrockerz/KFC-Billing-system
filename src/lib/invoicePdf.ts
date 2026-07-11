import { jsPDF } from 'jspdf'
import { BRAND_ADDRESS, BRAND_EMAIL, BRAND_EN, BRAND_PHONE_DISPLAY, BRAND_WHATSAPP_LINK } from './brand'
import { formatCurrency, formatQuantityDisplay, normalizeStructuredOrderItem } from './retail'

export type InvoicePdfData = {
  invoiceNo: string; date: string; customerName: string; phone: string; address: string
  items: Array<Record<string, unknown>>; subtotal: number; shipping: number; total: number
  discountAmount?: number; manualDiscountAmount?: number; gstAmount?: number; couponCode?: string | null
  paymentMode?: string; amountReceived?: number; balanceReturned?: number; status?: string
}

const money = (value: number) => formatCurrency(Number(value || 0)).replace(/\s+/g, ' ')
const dateText = (value: string) => { const date = new Date(value); return Number.isNaN(date.getTime()) ? '-' : date.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) }

export function createInvoicePdf(data: InvoicePdfData): Blob {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' })
  const pageWidth = doc.internal.pageSize.getWidth(); const pageHeight = doc.internal.pageSize.getHeight()
  const left = 16; const right = pageWidth - 16; const width = right - left
  const ink = '#18202A'; const muted = '#68717C'; const green = '#245C2A'; const paleGreen = '#F1F8F2'; const lightLine = '#E6EAE7'
  let y = 10

  const badge = (data.status || 'COMPLETED').toUpperCase()
  doc.setFillColor('#E8F7EC'); doc.roundedRect(pageWidth / 2 - 14, y - 5, 28, 7, 3.5, 3.5, 'F')
  doc.setFont('helvetica', 'bold'); doc.setFontSize(7); doc.setTextColor('#16A34A'); doc.text(badge, pageWidth / 2, y, { align: 'center' })
  doc.setFont('helvetica', 'normal'); doc.setFontSize(6.5); doc.setTextColor(muted); doc.text(data.invoiceNo, right, y, { align: 'right' })
  y = 22; doc.setDrawColor(lightLine); doc.setLineWidth(0.25); doc.line(left, y, right, y)

  y += 10; doc.setFont('helvetica', 'bold'); doc.setFontSize(7); doc.setTextColor(muted); doc.text('ORDER DATE', left, y); doc.text('CUSTOMER', right, y, { align: 'right' })
  doc.setFontSize(11); doc.setTextColor(ink); doc.text(dateText(data.date), left, y + 7); doc.setFont('helvetica', 'bold'); doc.text(data.customerName || 'Walk-in Customer', right, y + 7, { align: 'right' })
  doc.setFont('helvetica', 'normal'); doc.setFontSize(8); doc.setTextColor(muted); doc.text(data.phone || '-', right, y + 13); doc.text(data.address || 'POS Counter', right, y + 19, { align: 'right', maxWidth: 70 }); if (data.paymentMode) doc.text(`Payment: ${data.paymentMode}`, left, y + 13)
  y += 31; doc.setLineDashPattern([1, 1], 0); doc.line(left, y, right, y); doc.setLineDashPattern([], 0)

  y += 8; doc.setFillColor(paleGreen); doc.rect(left, y, width, 9, 'F'); doc.setFont('helvetica', 'bold'); doc.setFontSize(7.5); doc.setTextColor(green)
  const qtyX = 137; const rateX = 166; const amountX = right - 4
  doc.text('#', left + 4, y + 6); doc.text('PRODUCT', left + 14, y + 6); doc.text('QTY', qtyX, y + 6, { align: 'center' }); doc.text('RATE', rateX, y + 6, { align: 'right' }); doc.text('AMOUNT', amountX, y + 6, { align: 'right' }); y += 16

  data.items.forEach((raw, index) => {
    const item = normalizeStructuredOrderItem(raw); const nameLines = doc.splitTextToSize(item.name || 'Item', 96) as string[]; const qtyLabel = formatQuantityDisplay(item.quantity, item.unit, item.unit_type); const rowHeight = Math.max(15, nameLines.length * 4.2 + 5, qtyLabel.split(' ').length > 1 ? 17 : 15)
    if (y + rowHeight > pageHeight - 58) { doc.addPage(); y = 22 }
    doc.setFont('helvetica', 'normal'); doc.setFontSize(8); doc.setTextColor(muted); doc.text(String(index + 1), left + 4, y + 2)
    doc.setFont('helvetica', 'bold'); doc.setFontSize(9); doc.setTextColor(ink); doc.text(nameLines, left + 14, y + 1, { baseline: 'top' }); doc.setFont('helvetica', 'normal'); doc.setFontSize(7); doc.setTextColor(muted); doc.text(`${item.unit || 'piece'} · ${money(item.base_price)}`, left + 14, y + nameLines.length * 4.2 + 3)
    doc.setFont('helvetica', 'bold'); doc.setFontSize(9); doc.setTextColor(ink); doc.text(String(item.quantity), qtyX, y + 4, { align: 'center' }); doc.setFont('helvetica', 'normal'); doc.setFontSize(8); doc.text(item.unit || 'piece', qtyX, y + 10, { align: 'center' }); doc.setFont('helvetica', 'bold'); doc.setFontSize(9); doc.text(money(item.base_price), rateX, y + 4, { align: 'right' }); doc.text(money(item.line_total), amountX, y + 4, { align: 'right' })
    y += rowHeight; doc.setDrawColor(lightLine); doc.setLineWidth(0.2); doc.line(left, y - 3, right, y - 3)
  })

  y = Math.max(y + 8, pageHeight - 82); const summaryLeft = 133; const rows: Array<[string, string, string]> = [['Subtotal', money(data.subtotal), muted]]
  if ((data.discountAmount || 0) > 0) rows.push([`Coupon${data.couponCode ? ` (${data.couponCode})` : ''}`, `-${money(data.discountAmount || 0)}`, '#198754']); if ((data.manualDiscountAmount || 0) > 0) rows.push(['Manual Discount', `-${money(data.manualDiscountAmount || 0)}`, '#198754']); if ((data.gstAmount || 0) > 0) rows.push(['GST', money(data.gstAmount || 0), muted]); if ((data.amountReceived || 0) > 0) rows.push(['Received', money(data.amountReceived || 0), muted]); if ((data.balanceReturned || 0) > 0) rows.push(['Change', money(data.balanceReturned || 0), '#198754']); rows.push(['Delivery', data.shipping > 0 ? money(data.shipping) : 'FREE', data.shipping > 0 ? muted : '#198754'])
  doc.setFontSize(9); rows.forEach(([label, value, color]) => { doc.setFont('helvetica', 'normal'); doc.setTextColor(color); doc.text(label, summaryLeft, y, { align: 'right' }); doc.setFont('helvetica', 'bold'); doc.text(value, amountX, y, { align: 'right' }); y += 7 })
  doc.setDrawColor(green); doc.setLineWidth(0.6); doc.line(left, y - 4, right, y - 4); doc.setFont('helvetica', 'bold'); doc.setFontSize(14); doc.setTextColor(green); doc.text('TOTAL', summaryLeft, y + 7, { align: 'right' }); doc.text(money(data.total), amountX, y + 7, { align: 'right' })

  const footerY = pageHeight - 29; doc.setDrawColor(lightLine); doc.setLineWidth(0.2); doc.line(left, footerY, right, footerY); doc.setFont('helvetica', 'bold'); doc.setFontSize(8); doc.setTextColor(green); doc.text('Thank you for shopping!', left, footerY + 9); doc.setFont('helvetica', 'normal'); doc.setFontSize(7); doc.setTextColor('#4A8C5A'); doc.text('இங்கு வாங்கியதற்கு மிக்க நன்றி!', left, footerY + 15); doc.setTextColor('#9AA3AA'); doc.text(`Contact: ${BRAND_PHONE_DISPLAY} | Email: ${BRAND_EMAIL}`, left, footerY + 21); doc.text(`WhatsApp: ${BRAND_WHATSAPP_LINK}`, left, footerY + 26); doc.setTextColor(muted); doc.text('Authorised Signature', right - 28, footerY + 21, { align: 'center' }); doc.line(right - 44, footerY + 23, right - 12, footerY + 23); doc.setFont('helvetica', 'bold'); doc.text(BRAND_EN, right - 28, footerY + 28, { align: 'center' })
  return doc.output('blob')
}

export function invoicePdfFile(data: InvoicePdfData): File { return new File([createInvoicePdf(data)], `Invoice-${data.invoiceNo}.pdf`, { type: 'application/pdf' }) }
