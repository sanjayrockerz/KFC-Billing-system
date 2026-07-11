import { createInvoicePdf } from './invoicePdf'

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
  paymentMode?: string
  amountReceived?: number
  balanceReturned?: number
}

export async function generateInvoicePdf(data: PdfInvoiceData): Promise<Blob> {
  return createInvoicePdf({
    invoiceNo: data.invoiceNo,
    date: data.date,
    customerName: data.customerName,
    phone: data.phone,
    address: data.address,
    items: data.items.map(item => ({
      name: item.name,
      nameTa: item.nameTa,
      quantity: item.qty,
      unit: item.unit,
      unit_type: item.unitType,
      base_price: item.rate,
      line_total: item.lineTotal,
    })),
    subtotal: data.subtotal,
    shipping: data.shipping,
    discountAmount: data.discountAmount,
    couponCode: data.couponCode,
    manualDiscountAmount: data.manualDiscountAmount,
    gstAmount: data.gstAmount,
    total: data.total,
    paymentMode: data.paymentMode || data.orderType,
    amountReceived: data.amountReceived,
    balanceReturned: data.balanceReturned,
  })
}
