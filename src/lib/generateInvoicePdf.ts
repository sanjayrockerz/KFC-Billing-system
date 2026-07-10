import jsPDF from 'jspdf'
import { BRAND_EN, BRAND_ADDRESS, BRAND_PHONE_DISPLAY, BRAND_EMAIL } from './brand'
import { formatCurrency } from './retail'

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
  orderType?: string
}

export async function generateInvoicePdf(data: PdfInvoiceData): Promise<Blob> {
  const doc = new jsPDF({ format: 'a4', unit: 'mm' })
  const pw = doc.internal.pageSize.getWidth()
  const ph = doc.internal.pageSize.getHeight()
  const m = 18
  const cw = pw - m * 2

  // ── Colour palette ─────────────────────────────────────────────
  const GOLD = '#D4A800'
  const DARK = '#1A1A1A'
  const GREY = '#6B7280'
  const LIGHT = '#9CA3AF'
  const BG = '#F7F6F2'

  // ── Helper functions ────────────────────────────────────────────
  const setGold = () => doc.setTextColor(212, 168, 0)
  const setDark = () => doc.setTextColor(26, 26, 26)
  const setGrey = () => doc.setTextColor(107, 114, 128)
  const setLight = () => doc.setTextColor(156, 163, 175)
  const setGreen = () => doc.setTextColor(22, 163, 74)
  const b = (text: string, size = 10) => { doc.setFont('helvetica', 'bold'); doc.setFontSize(size); return doc }
  const n = (text: string, size = 10) => { doc.setFont('helvetica', 'normal'); doc.setFontSize(size); return doc }
  const t = (text: string, x: number, y: number, align: 'left' | 'center' | 'right' = 'left') => doc.text(text, x, y, { align })
  const hr = (y: number, color = '#E5E7EB') => { doc.setDrawColor(...hexToRgb(color)); doc.line(m, y, pw - m, y) }
  const spacer = (y: number, gap: number) => y + gap

  let y = m

  // ── Load logo ──────────────────────────────────────────────────
  const logoDataUrl = await loadLogoAsBase64()
  if (logoDataUrl) {
    try { doc.addImage(logoDataUrl, 'PNG', pw / 2 - 16, y, 32, 32) } catch { /* ignore */ }
    y += 36
  }

  // ── Company Header ─────────────────────────────────────────────
  setGold()
  b(BRAND_EN, 20).text(BRAND_EN, pw / 2, y, { align: 'center' }); y += 7
  setGrey()
  n(BRAND_ADDRESS, 8).text(BRAND_ADDRESS, pw / 2, y, { align: 'center' }); y += 4
  setDark()
  n(`${BRAND_PHONE_DISPLAY}  |  ${BRAND_EMAIL}`, 8).text(`${BRAND_PHONE_DISPLAY}  |  ${BRAND_EMAIL}`, pw / 2, y, { align: 'center' }); y += 6

  hr(y, '#D4A800'); y += 4

  // ── Invoice Title ──────────────────────────────────────────────
  setGold()
  b('INVOICE', 16).text('INVOICE', pw / 2, y, { align: 'center' }); y += 6
  setDark()
  b(data.invoiceNo, 11).text(data.invoiceNo, pw / 2, y, { align: 'center' }); y += 4
  setGrey()
  n(data.date, 9).text(data.date, pw / 2, y, { align: 'center' }); y += 3
  if (data.orderType) {
    setGrey()
    n(`Mode: ${data.orderType}`, 8).text(`Mode: ${data.orderType}`, pw / 2, y, { align: 'center' }); y += 3
  }
  y += 4
  hr(y); y += 6

  // ── Two-column: Invoice Info | Customer ────────────────────────
  const colW = (cw - 20) / 2
  const colA_x = m
  const colB_x = m + colW + 20

  // Left column — Invoice details
  setGrey(); n('INVOICE DETAILS', 7).text('INVOICE DETAILS', colA_x, y, { align: 'left' }); y += 4
  setDark(); b(`# ${data.invoiceNo}`, 10).text(`# ${data.invoiceNo}`, colA_x, y); y += 5
  setGrey(); n(`Date: ${data.date}`, 8).text(`Date: ${data.date}`, colA_x, y); y += 4
  if (data.orderType) {
    setGrey(); n(`Type: ${data.orderType}`, 8).text(`Type: ${data.orderType}`, colA_x, y); y += 4
  }

  // Save Y position after left column, then move to right column
  const leftY = y

  // Right column — Customer details (render at same starting Y as left)
  y = m + 6 + 36 + 7 + 4 + 6 + 4 + 6 + 4 + 3 + 3 + 4 + 4 + 6
  // Actually, let me just compute the Y position properly
  // Reset Y for right column to match the left column's "INVOICE DETAILS" Y
  y = m + 36 + 7 + 4 + 4 + 6 + 4 + 6 + 4 + 3 + 3 + 4 + 4 + 6
  // Actually let me just track starting Y and render both columns
  // Let me restart the two-column layout approach:

  // Reset y to the position after the horizontal line
  // Starting Y for two-column layout
  let startY = m + 36 + 7 + 4 + 4 + 6 + 4 + 6 + 4 + 3 + 3 + 4 + 4 + 6

  // Left column
  let lx = m
  let ly = startY
  setGrey(); n('INVOICE', 7).text('INVOICE', lx, ly); ly += 4.5
  setDark(); b(`# ${data.invoiceNo}`, 10).text(`# ${data.invoiceNo}`, lx, ly); ly += 5
  setGrey(); n(data.date, 8).text(data.date, lx, ly); ly += 4
  if (data.orderType) {
    setGrey(); n(`Mode: ${data.orderType}`, 8).text(`Mode: ${data.orderType}`, lx, ly); ly += 4
  }

  // Right column
  let rx = m + colW + 20
  let ry = startY
  setGrey(); n('CUSTOMER', 7).text('CUSTOMER', rx, ry); ry += 4.5
  setDark(); b(data.customerName || '-', 10).text(data.customerName || '-', rx, ry); ry += 5
  if (data.phone) { setGrey(); n(data.phone, 8).text(data.phone, rx, ry); ry += 4 }
  if (data.address) { setLight(); n(data.address, 7).text(data.address, rx, ry); ry += 4 }

  y = Math.max(ly, ry) + 4
  hr(y); y += 6

  // ── Items Table ────────────────────────────────────────────────
  // Column positions
  const colSn = m                  // 8mm
  const colProduct = m + 8         // rest
  const colQty = pw - m - 80      // 20mm
  const colRate = pw - m - 56     // 24mm
  const colAmount = pw - m - 28   // 28mm

  // Table header
  doc.setFillColor(245, 243, 240)
  doc.rect(m, y - 3.5, cw, 6.5, 'F')
  setGrey(); b('#', 8).text('#', colSn + 2, y)
  setGrey(); b('Product', 8).text('Product', colProduct + 2, y)
  setGrey(); b('Qty', 8).text('Qty', colQty - 1, y, { align: 'right' })
  setGrey(); b('Rate', 8).text('Rate', colRate - 1, y, { align: 'right' })
  setGrey(); b('Amount', 8).text('Amount', colAmount - 1, y, { align: 'right' })
  y += 7

  // Table rows
  data.items.forEach((item, idx) => {
    if (y > ph - 45) { doc.addPage(); y = m + 10; hr(y - 4); y += 6 }

    const lineTotal = item.qty * item.rate

    hr(y - 1, '#F3F0EB')
    setDark(); n(String(idx + 1), 9).text(String(idx + 1), colSn + 2, y)
    setDark(); b(item.name, 9).text(item.name, colProduct + 2, y)
    if (item.nameTa) { setLight(); n(item.nameTa, 7).text(item.nameTa, colProduct + 2, y + 3.5) }
    setDark(); n(String(item.qty), 9).text(String(item.qty), colQty - 1, y, { align: 'right' })
    setGrey(); n(formatCurrency(item.rate), 9).text(formatCurrency(item.rate), colRate - 1, y, { align: 'right' })
    setDark(); b(formatCurrency(lineTotal), 9).text(formatCurrency(lineTotal), colAmount - 1, y, { align: 'right' })

    y += item.nameTa ? 9 : 6
  })

  // ── Totals section ─────────────────────────────────────────────
  y += 4
  if (y > ph - 65) { doc.addPage(); y = m + 10 }

  const totalsX = pw - m - 85
  const totalsW = 85
  const labelX = totalsX
  const valueX = totalsX + totalsW

  // Totals label
  setGrey(); b('BILL SUMMARY', 8).text('BILL SUMMARY', labelX, y); y += 5

  n('Subtotal', 10).text('Subtotal', labelX, y)
  setDark(); n(formatCurrency(data.subtotal), 10).text(formatCurrency(data.subtotal), valueX, y, { align: 'right' })
  y += 6.5

  if (data.discountAmount && data.discountAmount > 0) {
    setGreen()
    const label = data.couponCode ? `Coupon (${data.couponCode})` : 'Coupon Discount'
    n(label, 10).text(label, labelX, y)
    n(`-${formatCurrency(data.discountAmount)}`, 10).text(`-${formatCurrency(data.discountAmount)}`, valueX, y, { align: 'right' })
    setDark()
    y += 6.5
  }

  if (data.manualDiscountAmount && data.manualDiscountAmount > 0) {
    setGreen()
    n('Manual Discount', 10).text('Manual Discount', labelX, y)
    n(`-${formatCurrency(data.manualDiscountAmount)}`, 10).text(`-${formatCurrency(data.manualDiscountAmount)}`, valueX, y, { align: 'right' })
    setDark()
    y += 6.5
  }

  if (data.gstAmount && data.gstAmount > 0) {
    setDark()
    n('GST', 10).text('GST', labelX, y)
    n(`+${formatCurrency(data.gstAmount)}`, 10).text(`+${formatCurrency(data.gstAmount)}`, valueX, y, { align: 'right' })
    y += 6.5
  }

  if (data.shipping > 0) {
    setDark()
    n('Delivery', 10).text('Delivery', labelX, y)
    n(formatCurrency(data.shipping), 10).text(formatCurrency(data.shipping), valueX, y, { align: 'right' })
    y += 6.5
  } else {
    setGreen()
    n('Delivery', 10).text('Delivery', labelX, y)
    n('FREE', 10).text('FREE', valueX, y, { align: 'right' })
    setDark()
    y += 6.5
  }

  // Gold divider
  doc.setDrawColor(212, 168, 0)
  doc.setLineWidth(0.6)
  doc.line(labelX, y, valueX, y)
  y += 4.5

  setGold()
  b('Total', 14).text('Total', labelX, y)
  b(formatCurrency(data.total), 14).text(formatCurrency(data.total), valueX, y, { align: 'right' })
  setDark()
  doc.setLineWidth(0.2)

  // ── Footer ──────────────────────────────────────────────────────
  y = ph - 28
  hr(y, '#D4A800'); y += 5
  setGold()
  n('Thank you for shopping with Korean Fried Chicken!', 9).text('Thank you for shopping with Korean Fried Chicken!', pw / 2, y, { align: 'center' }); y += 4
  setGrey()
  n(`Contact: ${BRAND_PHONE_DISPLAY}  |  ${BRAND_EMAIL}`, 7).text(`Contact: ${BRAND_PHONE_DISPLAY}  |  ${BRAND_EMAIL}`, pw / 2, y, { align: 'center' })

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

function hexToRgb(hex: string): [number, number, number] {
  const v = parseInt(hex.replace('#', ''), 16)
  return [(v >> 16) & 255, (v >> 8) & 255, v & 255]
}
