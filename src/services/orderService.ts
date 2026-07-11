import { isSupabaseConfigured, supabase } from '../lib/supabase'
import type { StructuredOrderItem } from '../lib/retail'
import { invoicePdfFile } from '../lib/invoicePdf'
import { uploadInvoicePdf } from '../lib/storage'
import { normalizeStructuredOrderItem } from '../lib/retail'

type CreateOrderInput = {
  customerName: string
  phone: string
  address: string
  items: StructuredOrderItem[]
  shipping: number
  status?: string
  orderMode?: 'online' | 'offline'
  orderType?: 'online_request' | 'pos_sale' | 'manual_sale'
  deliveryCharge?: number
  discountAmount?: number
  manualDiscountAmount?: number
  manualDiscountType?: 'flat' | 'percent'
  manualDiscountValue?: number
  couponCode?: string
  couponPercentage?: number
  totalGst?: number
  gstEnabled?: boolean
}

type CreatedOrder = {
  orderId: string
  invoiceNo: string
  createdAt: string
  invoiceUrl?: string
}

export const createOrderWithStock = async (input: CreateOrderInput): Promise<CreatedOrder> => {
  const customerName   = input.customerName.trim() || 'Customer'
  const phone          = input.phone.trim()
  const address        = input.address.trim()
  const shipping       = Number(input.shipping || 0)
  const status         = input.status || 'pending'
  const orderMode      = input.orderMode || 'online'
  const orderType      = input.orderType || (status === 'pending' && orderMode === 'online' ? 'online_request' : 'pos_sale')
  const deliveryCharge = Number(input.deliveryCharge || 0)
  const discountAmount = Number(input.discountAmount || 0)
  const manualDiscountAmount = Number(input.manualDiscountAmount || 0)
  const manualDiscountType = input.manualDiscountType || 'flat'
  const manualDiscountValue = Number(input.manualDiscountValue || 0)
  const couponCode     = input.couponCode?.trim() || null
  const couponPercentage = Number(input.couponPercentage || 0)
  const totalGst       = Number(input.totalGst || 0)
  const gstEnabled     = Boolean(input.gstEnabled)

  if (!isSupabaseConfigured) {
    throw new Error('Supabase is required to create orders')
  }

  // Match the RPC signature currently defined in the migration files.
  let data: unknown = null
  let error: unknown = null

  const newRpcResult = await supabase.rpc('create_order_with_stock', {
    p_customer_name:     customerName,
    p_phone:             phone,
    p_address:           address,
    p_items:             input.items,
    p_shipping:          shipping,
    p_status:            status,
    p_order_mode:        orderMode,
    p_order_type:        orderType,
    p_delivery_charge:   deliveryCharge,
    p_discount_amount:   discountAmount,
    p_manual_discount_amount: manualDiscountAmount,
    p_manual_discount_type: manualDiscountType,
    p_manual_discount_value: manualDiscountValue,
    p_coupon_code:       couponCode,
    p_coupon_percentage: couponPercentage,
    p_total_gst:         totalGst,
    p_gst_enabled:       gstEnabled,
  })
  data  = newRpcResult.data
  error = newRpcResult.error



  if (error) {
    if (typeof error === 'object' && error !== null && 'message' in error) {
      const err = error as { message: unknown; details?: unknown }
      throw new Error(String(err.message) + (err.details ? ` (${String(err.details)})` : ''))
    }
    throw new Error(String(error))
  }

  const row = Array.isArray(data) ? (data as unknown[])[0] : data
  if (!row || typeof row !== 'object') {
    throw new Error('Order RPC returned an invalid payload')
  }
  const rowObj = row as Record<string, unknown>
  // DB returns camelCase keys (orderId, invoiceNo) OR snake_case (order_id, invoice_no)
  const orderId = String(rowObj.order_id ?? rowObj.orderId ?? rowObj.id ?? '')
  const invoiceNo = String(rowObj.invoice_no ?? rowObj.invoiceNo ?? rowObj.invoiceNo ?? '')
  if (!orderId || !invoiceNo) {
    throw new Error('Order RPC returned an invalid payload')
  }

  // Generate and upload invoice PDF
  let invoiceUrl: string | undefined
  try {
    const pdfFile = await invoicePdfFile({
      invoiceNo,
      date: new Date().toISOString(),
      customerName,
      phone,
      address,
      items: input.items.map(item => normalizeStructuredOrderItem(item as unknown as Record<string, unknown>)),
      subtotal: input.items.reduce((sum, item) => sum + (item.line_total || 0), 0),
      shipping: deliveryCharge,
      discountAmount,
      manualDiscountAmount,
      couponCode,
      gstAmount: totalGst,
      total: input.items.reduce((sum, item) => sum + (item.line_total || 0), 0) + deliveryCharge - discountAmount - manualDiscountAmount + totalGst,
      paymentMode: input.orderMode === 'online' ? 'Online' : 'POS',
    })
    invoiceUrl = await uploadInvoicePdf(pdfFile, invoiceNo)
    
    // Update order with invoice URL
    if (invoiceUrl && isSupabaseConfigured) {
      await supabase.from('orders').update({ invoice_url: invoiceUrl }).eq('id', orderId)
    }
  } catch (err) {
    console.error('Failed to generate/upload invoice PDF:', err)
  }

  return {
    orderId,
    invoiceNo,
    createdAt: new Date().toISOString(),
    invoiceUrl,
  }
}
