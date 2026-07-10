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
  const m = 20
  const cw = pw - m * 2

  const GOLD = '#D4A800'
  const DARK = '#1A1A1A'
  const GREY = '#6B7280'

  const setColor = (hex: string) => {
    const r = parseInt(hex.slice(1, 3), 16)
    const g = parseInt(hex.slice(3, 5), 16)
    const b = parseInt(hex.slice(5, 7), 16)
    doc.setTextColor(r, g, b)
  }
  const bold = (size: number) => { doc.setFont('helvetica', 'bold'); doc.setFontSize(size) }
  const norm = (size: number) => { doc.setFont('helvetica', 'normal'); doc.setFontSize(size) }
  const text = (s: string, x: number, y: number, align: 'left' | 'center' | 'right' = 'left') => doc.text(s, x, y, { align })
  const line = (y: number, color = '#E5E7EB') => { doc.setDrawColor(...hexRgb(color)); doc.line(m, y, pw - m, y) }

  let y = m

  // ── Logo ───────────────────────────────────────────────────────
  const logoDataUrl = await loadLogoAsBase64()
  if (logoDataUrl) {
    try { doc.addImage(logoDataUrl, 'PNG', pw / 2 - 14, y, 28, 28) } catch { /* ignore */ }
    y += 32
  }

  // ── Company Header ─────────────────────────────────────────────
  setColor(GOLD); bold(22)
  text(BRAND_EN, pw / 2, y, 'center'); y += 8
  setColor(GREY); norm(8)
  text(BRAND_ADDRESS, pw / 2, y, 'center'); y += 4
  setColor(DARK); norm(8)
  text(`${BRAND_PHONE_DISPLAY}  |  ${BRAND_EMAIL}`, pw / 2, y, 'center'); y += 7

  // Gold thick line
  doc.setDrawColor(212, 168, 0); doc.setLineWidth(0.8)
  doc.line(m, y, pw - m, y)
  doc.setLineWidth(0.2)
  y += 6

  // ── INVOICE Title ──────────────────────────────────────────────
  setColor(GOLD); bold(18)
  text('INVOICE', pw / 2, y, 'center'); y += 7
  setColor(DARK); bold(12)
  text(data.invoiceNo, pw / 2, y, 'center'); y += 5
  setColor(GREY); norm(9)
  text(data.date, pw / 2, y, 'center'); y += 4
  if (data.orderType) {
    setColor(GREY); norm(8)
    text(`Mode: ${data.orderType}`, pw / 2, y, 'center'); y += 3
  }
  y += 4

  doc.setDrawColor(212, 168, 0); doc.setLineWidth(0.4)
  doc.line(m, y, pw - m, y)
  doc.setLineWidth(0.2)
  y += 8

  // ── Two-column layout: Invoice Info | Customer ────────────────
  const colW = (cw - 24) / 2
  const leftX = m
  const rightX = m + colW + 24
  const colY = y

  // Left: Invoice Details
  setColor(GREY); norm(7)
  text('INVOICE', leftX, colY); y = colY + 4.5
  setColor(DARK); bold(11)
  text(`# ${data.invoiceNo}`, leftX, y); y += 5
  setColor(GREY); norm(8)
  text(data.date, leftX, y); y += 4
  if (data.orderType) {
    setColor(GREY); norm(8)
    text(`Mode: ${data.orderType}`, leftX, y); y += 4
  }
  const leftBottom = y

  // Right: Customer Details
  setColor(GREY); norm(7)
  text('CUSTOMER', rightX, colY)
  setColor(DARK); bold(11)
  text(data.customerName || '-', rightX, colY + 4.5)
  const custY = colY + 4.5 + 5
  if (data.phone) { setColor(GREY); norm(8); text(data.phone, rightX, custY) }
  if (data.address) {
    setColor('#9CA3AF'); norm(7)
    const addrLines = splitAddress(data.address, colW - 5)
    addrLines.forEach((l, i) => text(l, rightX, custY + (i ? 3.5 : 4.5), 'left'))
  }
  const rightBottom = custY + (data.address ? splitAddress(data.address, colW - 5).length * 3.5 : 0)

  y = Math.max(leftBottom, rightBottom) + 6

  doc.setDrawColor(212, 168, 0); doc.setLineWidth(0.3)
  doc.line(m, y, pw - m, y)
  doc.setLineWidth(0.2)
  y += 6

  // ── Items Table ───────────────────────────────────────────────
  // Column positions (measured from left margin m)
  const clSn = 0
  const clProd = 8
  const clProdW = cw - 8 - 80
  const clQty = cw - 80
  const clRate = cw - 56
  const clAmt = cw - 28

  // Table header row
  doc.setFillColor(245, 243, 240)
  doc.rect(m, y - 3.5, cw, 6.5, 'F')
  setColor(GREY); bold(7.5)
  text('#', m + clSn + 2, y)
  text('Product', m + clProd + 2, y)
  text('Qty', m + clQty - 1, y, 'right')
  text('Rate', m + clRate - 1, y, 'right')
  text('Amount', m + clAmt - 1, y, 'right')

  const rowH = 6.5
  y += rowH

  // Table rows
  data.items.forEach((item, idx) => {
    if (y > ph - 55) { doc.addPage(); y = m + 10; line(y - 4); y += 6 }

    const rowBottom = y + (item.nameTa ? 8 : rowH) - 1

    // Light row line
    doc.setDrawColor(243, 240, 235); doc.setLineWidth(0.2)
    doc.line(m, rowBottom, pw - m, rowBottom)

    setColor(DARK); norm(8)
    text(String(idx + 1), m + clSn + 2, y + 3.5)
    setColor(DARK); bold(8)
    text(item.name, m + clProd + 2, y + 3.5, 'left')
    if (item.nameTa) {
      setColor('#9CA3AF'); norm(6.5)
      text(item.nameTa, m + clProd + 2, y + 8, 'left')
    }
    setColor(DARK); norm(8)
    text(String(item.qty), m + clQty - 1, y + 3.5, 'right')
    setColor(GREY); norm(8)
    text(formatCurrency(item.rate), m + clRate - 1, y + 3.5, 'right')
    setColor(DARK); bold(8)
    text(formatCurrency(item.lineTotal), m + clAmt - 1, y + 3.5, 'right')

    y = rowBottom + 0.5
  })

  // ── Totals section (right-aligned block) ──────────────────────
  y += 5
  if (y > ph - 70) { doc.addPage(); y = m + 10 }

  const tw = 80
  const tx = pw - m - tw
  const tv = tx + tw

  setColor(GREY); bold(8)
  text('BILL SUMMARY', tx, y); y += 5.5

  const totalRow = (label: string, value: string, color = DARK, vcolor = DARK) => {
    setColor(color); norm(9)
    text(label, tx, y)
    setColor(vcolor); norm(9)
    text(value, tv, y, 'right')
    y += 6
  }

  totalRow('Subtotal', formatCurrency(data.subtotal))

  if (data.discountAmount && data.discountAmount > 0) {
    const label = data.couponCode ? `Coupon (${data.couponCode})` : 'Coupon Discount'
    totalRow(label, `-${formatCurrency(data.discountAmount)}`, '#16A34A', '#16A34A')
  }
  if (data.manualDiscountAmount && data.manualDiscountAmount > 0) {
    totalRow('Manual Discount', `-${formatCurrency(data.manualDiscountAmount)}`, '#16A34A', '#16A34A')
  }
  if (data.gstAmount && data.gstAmount > 0) {
    totalRow('GST', `+${formatCurrency(data.gstAmount)}`)
  }
  if (data.shipping > 0) {
    totalRow('Delivery', formatCurrency(data.shipping))
  } else {
    totalRow('Delivery', 'FREE', '#16A34A', '#16A34A')
  }

  // Gold divider
  doc.setDrawColor(212, 168, 0); doc.setLineWidth(0.7)
  doc.line(tx, y, tv, y)
  doc.setLineWidth(0.2)
  y += 4.5

  setColor(GOLD); bold(14)
  text('Total', tx, y)
  text(formatCurrency(data.total), tv, y, 'right')
  y += 8

  // ── Footer ────────────────────────────────────────────────────
  const fy = ph - 28
  doc.setDrawColor(212, 168, 0); doc.setLineWidth(0.6)
  doc.line(m, fy, pw - m, fy)
  doc.setLineWidth(0.2)
  setColor(GOLD); norm(9)
  text('Thank you for shopping with Korean Fried Chicken!', pw / 2, fy + 5, 'center')
  setColor(GREY); norm(7)
  text(`Contact: ${BRAND_PHONE_DISPLAY}  |  ${BRAND_EMAIL}`, pw / 2, fy + 10, 'center')

  return doc.output('blob')
}

function splitAddress(addr: string, maxW: number): string[] {
  if (!addr) return []
  const lines: string[] = []
  let current = ''
  const words = addr.split(' ')
  for (const w of words) {
    if ((current + ' ' + w).length * 1.2 > maxW) {
      if (current) lines.push(current)
      current = w
    } else {
      current = current ? current + ' ' + w : w
    }
  }
  if (current) lines.push(current)
  return lines.length ? lines : [addr]
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

function hexRgb(hex: string): [number, number, number] {
  const v = parseInt(hex.replace('#', ''), 16)
  return [(v >> 16) & 255, (v >> 8) & 255, v & 255]
}
