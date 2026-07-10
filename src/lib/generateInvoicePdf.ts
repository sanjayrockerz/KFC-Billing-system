import jsPDF from 'jspdf'
import { BRAND_EN, BRAND_ADDRESS, BRAND_PHONE_DISPLAY } from './brand'
import { formatCurrency, formatQuantityDisplay } from './retail'

export interface PdfInvoiceItem {
  name: string
  nameTa?: string | null
  qty: number
  unit: string
  unitType: string
  rate: number
  lineTotal: number
}

export interface PdfInvoiceData {
  invoiceNo: string
  date: string
  customerName: string
  phone: string
  address: string
  items: PdfInvoiceItem[]
  subtotal: number
  shipping: number
  discountAmount?: number
  couponCode?: string | null
  manualDiscountAmount?: number
  gstAmount?: number
  total: number
}

export async function generateInvoicePdf(data: PdfInvoiceData): Promise<Blob> {
  const doc = new jsPDF({ format: 'a4', unit: 'mm' })
  const pw = doc.internal.pageSize.getWidth()
  const ph = doc.internal.pageSize.getHeight()
  const m = 20
  const cw = pw - m * 2
  let y = m

  // ── Helper functions ────────────────────────────────────────────
  const bold = (text: string, size = 10) => { doc.setFont('helvetica', 'bold'); doc.setFontSize(size); return doc }
  const normal = (text: string, size = 10) => { doc.setFont('helvetica', 'normal'); doc.setFontSize(size); return doc }
  const text = (text: string, x: number, y: number, align: 'left' | 'center' | 'right' = 'left') => doc.text(text, x, y, { align })
  const line = (y: number) => { doc.setDrawColor(200); doc.line(m, y, pw - m, y) }

  // ── Load logo as base64 ─────────────────────────────────────────
  const logoDataUrl = await loadLogoAsBase64()
  if (logoDataUrl) {
    try { doc.addImage(logoDataUrl, 'PNG', pw / 2 - 18, y, 36, 36) } catch { /* ignore */ }
    y += 40
  }

  // ── Header ──────────────────────────────────────────────────────
  bold(BRAND_EN, 22).text(BRAND_EN, pw / 2, y, { align: 'center' }); y += 8
  normal(BRAND_ADDRESS, 9).text(BRAND_ADDRESS, pw / 2, y, { align: 'center' }); y += 5
  normal(`📞 ${BRAND_PHONE_DISPLAY}`, 9).text(`📞 ${BRAND_PHONE_DISPLAY}`, pw / 2, y, { align: 'center' }); y += 8

  line(y); y += 4

  // ── Invoice Title ───────────────────────────────────────────────
  bold('INVOICE', 16).text('INVOICE', pw / 2, y, { align: 'center' }); y += 6
  normal(data.invoiceNo, 11).text(data.invoiceNo, pw / 2, y, { align: 'center' }); y += 10

  // ── Meta Row: Date | Customer ───────────────────────────────────
  const col1X = m
  const col2X = pw / 2 + 5

  normal('Order Date', 8).text('Order Date', col1X, y); y += 4
  bold(data.date, 10).text(data.date, col1X, y); y += 6

  y = y - 10 // reset y for second column
  normal('Customer', 8).text('Customer', col2X, y); y += 4
  bold(data.customerName || '-', 10).text(data.customerName || '-', col2X, y); y += 5
  normal(data.phone || '', 9).text(data.phone || '', col2X, y); y += 5
  if (data.address) {
    normal(data.address, 9).text(data.address, col2X, y); y += 5
  }

  y = Math.max(y, m + 50) + 4
  line(y); y += 6

  // ── Items Table ─────────────────────────────────────────────────
  const tableHeaders = ['#', 'Product', 'Qty', 'Rate', 'Amount']
  const colWidths = [8, null, 20, 28, 32]
  const colX: number[] = []
  let cx = m
  colWidths.forEach((w, i) => {
    colX.push(cx)
    cx += w || (cw - colWidths.filter((_, j) => j < i).reduce((s, w) => s + (w || 0), 0) - colWidths.filter((_, j) => j > i).reduce((s, w) => s + (w || 0), 0))
  })
  // Actually let me compute properly
  const fixedW = colWidths.filter(w => w !== null).reduce((s, w) => s + w, 0) as number
  const nameW = cw - fixedW
  const headerXs = [m, m + 8, m + 8 + nameW, m + 8 + nameW + 20, m + 8 + nameW + 20 + 28]

  doc.setFillColor(255, 253, 245)
  doc.rect(m, y - 4, cw, 7, 'F')
  bold('#', 8).text('#', headerXs[0] + 3, y)
  bold('Product', 8).text('Product', headerXs[1] + 3, y)
  bold('Qty', 8).text('Qty', headerXs[2] + nameW - 3, y, { align: 'right' })
  bold('Rate', 8).text('Rate', headerXs[3] - 3, y, { align: 'right' })
  bold('Amount', 8).text('Amount', headerXs[4] - 3, y, { align: 'right' })
  y += 8

  data.items.forEach((item, idx) => {
    if (y > ph - 50) { doc.addPage(); y = m + 10 }

    normal(String(idx + 1), 9).text(String(idx + 1), headerXs[0] + 3, y)
    bold(item.name, 9).text(item.name, headerXs[1] + 3, y)
    if (item.nameTa) {
      normal(item.nameTa, 8).text(item.nameTa, headerXs[1] + 3, y + 4)
    }
    const qtyDisplay = formatQuantityDisplay(item.qty, item.unit, item.unitType as any)
    normal(qtyDisplay, 9).text(qtyDisplay, headerXs[2] + nameW - 3, y, { align: 'right' })
    const rateStr = formatCurrency(item.rate)
    normal(rateStr, 9).text(rateStr, headerXs[3] - 3, y, { align: 'right' })
    const amtStr = formatCurrency(item.lineTotal)
    bold(amtStr, 9).text(amtStr, headerXs[4] - 3, y, { align: 'right' })

    const rowH = item.nameTa ? 10 : 6
    y += rowH
    doc.setDrawColor(240)
    doc.line(m, y - 2, pw - m, y - 2)
  })

  // ── Totals ──────────────────────────────────────────────────────
  y += 6
  if (y > ph - 60) { doc.addPage(); y = m + 10 }

  const totalsX = pw - m - 70
  const totalsW = 70

  normal('Subtotal', 10).text('Subtotal', totalsX, y)
  normal(formatCurrency(data.subtotal), 10).text(formatCurrency(data.subtotal), totalsX + totalsW, y, { align: 'right' })
  y += 7

  if (data.discountAmount && data.discountAmount > 0) {
    const label = data.couponCode ? `Coupon (${data.couponCode})` : 'Coupon'
    doc.setTextColor(22, 163, 74)
    normal(label, 10).text(label, totalsX, y)
    normal(`-${formatCurrency(data.discountAmount)}`, 10).text(`-${formatCurrency(data.discountAmount)}`, totalsX + totalsW, y, { align: 'right' })
    doc.setTextColor(0)
    y += 7
  }

  if (data.manualDiscountAmount && data.manualDiscountAmount > 0) {
    doc.setTextColor(22, 163, 74)
    normal('Manual Discount', 10).text('Manual Discount', totalsX, y)
    normal(`-${formatCurrency(data.manualDiscountAmount)}`, 10).text(`-${formatCurrency(data.manualDiscountAmount)}`, totalsX + totalsW, y, { align: 'right' })
    doc.setTextColor(0)
    y += 7
  }

  if (data.gstAmount && data.gstAmount > 0) {
    normal('GST', 10).text('GST', totalsX, y)
    normal(`+${formatCurrency(data.gstAmount)}`, 10).text(`+${formatCurrency(data.gstAmount)}`, totalsX + totalsW, y, { align: 'right' })
    y += 7
  }

  if (data.shipping > 0) {
    normal('Delivery', 10).text('Delivery', totalsX, y)
    normal(formatCurrency(data.shipping), 10).text(formatCurrency(data.shipping), totalsX + totalsW, y, { align: 'right' })
    y += 7
  } else {
    doc.setTextColor(22, 163, 74)
    normal('Delivery', 10).text('Delivery', totalsX, y)
    normal('FREE', 10).text('FREE', totalsX + totalsW, y, { align: 'right' })
    doc.setTextColor(0)
    y += 7
  }

  doc.setDrawColor(212, 168, 0)
  doc.setLineWidth(0.5)
  doc.line(totalsX, y, totalsX + totalsW, y)
  y += 4

  doc.setTextColor(212, 168, 0)
  bold('Total', 14).text('Total', totalsX, y)
  bold(formatCurrency(data.total), 14).text(formatCurrency(data.total), totalsX + totalsW, y, { align: 'right' })
  doc.setTextColor(0)
  doc.setLineWidth(0.2)

  // ── Footer ──────────────────────────────────────────────────────
  y = ph - 30
  doc.setDrawColor(200)
  doc.line(m, y, pw - m, y)
  y += 6

  doc.setTextColor(150)
  normal('Thank you for shopping with Korean Fried Chicken!', 9).text('Thank you for shopping with Korean Fried Chicken!', pw / 2, y, { align: 'center' })
  y += 5
  normal(`Contact: ${BRAND_PHONE_DISPLAY}`, 8).text(`Contact: ${BRAND_PHONE_DISPLAY}`, pw / 2, y, { align: 'center' })
  doc.setTextColor(0)

  return doc.output('blob')
}

function loadLogoAsBase64(): Promise<string | null> {
  return new Promise((resolve) => {
    const img = new Image()
    img.crossOrigin = 'anonymous'
    img.onload = () => {
      const c = document.createElement('canvas')
      c.width = img.width
      c.height = img.height
      const ctx = c.getContext('2d')
      if (!ctx) { resolve(null); return }
      ctx.drawImage(img, 0, 0)
      resolve(c.toDataURL('image/png'))
    }
    img.onerror = () => resolve(null)
    img.src = '/logo.png'
  })
}
