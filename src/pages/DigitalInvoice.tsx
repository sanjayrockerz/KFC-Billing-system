import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase, isSupabaseConfigured } from '../lib/supabase'
import { Invoice } from '../components/Invoice'
import { Printer, ArrowLeft, Receipt, MessageCircle, Download } from 'lucide-react'
import { printThermalReceipt } from '../lib/thermalPrint'
import { invoicePdfFile } from '../lib/invoicePdf'
import { normalizeStructuredOrderItem } from '../lib/retail'
import { buildProfessionalWhatsAppMessage } from '../lib/whatsappMessage'
import { normalizePhone, toWhatsAppUrl } from '../lib/phone'

type DigitalInvoiceRow = {
  invoice_no: string; customer_name: string; phone: string; address: string; items: unknown
  total: number; delivery_charge?: number | null; shipping?: number | null
  discount_amount?: number | null; manual_discount_amount?: number | null
  total_gst?: number | null; gst_amount?: number | null; coupon_code?: string | null
  payment_mode?: string | null; payment_method?: string | null; status?: string | null; created_at: string
  invoice_url?: string | null
}

const orderItems = (value: unknown): Record<string, unknown>[] => {
  if (Array.isArray(value)) return value.filter((item): item is Record<string, unknown> => typeof item === 'object' && item !== null)
  if (typeof value === 'string') {
    try { const parsed: unknown = JSON.parse(value); return Array.isArray(parsed) ? parsed.filter((item): item is Record<string, unknown> => typeof item === 'object' && item !== null) : [] } catch { return [] }
  }
  return []
}

export default function DigitalInvoice() {
  const { id } = useParams()
  const [invoice, setInvoice] = useState<DigitalInvoiceRow | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    async function loadInvoice() {
      if (!isSupabaseConfigured) { setError('Database connection not configured'); setLoading(false); return }
      try {
        const { data, error: loadError } = await supabase.from('orders').select('*').eq('invoice_no', id).single()
        if (loadError) throw loadError
        if (!data) throw new Error('Invoice not found')
        setInvoice(data as DigitalInvoiceRow)
      } catch (err: unknown) { setError(err instanceof Error ? err.message : 'Invoice not found') }
      finally { setLoading(false) }
    }
    if (id) void loadInvoice()
  }, [id])

  if (loading) return <div className="min-h-screen bg-[#f9faf6] flex items-center justify-center"><span className="w-8 h-8 border-4 border-[#F0E6C8] border-t-yellow-dark rounded-full animate-spin" /></div>
  if (error || !invoice) return <div className="min-h-screen bg-[#f9faf6] flex flex-col items-center justify-center text-center p-6"><h1 className="text-2xl font-bold text-yellow-dark mb-2">Invoice Not Found</h1><p className="text-gray-500 mb-6">{error}</p><Link to="/" className="px-6 py-2 bg-yellow text-white rounded-full font-bold hover:bg-yellow-dark transition">Return Home</Link></div>

  const rawItems = orderItems(invoice.items)
  const normalizedItems = rawItems.map(item => normalizeStructuredOrderItem(item))
  const invoiceItems = normalizedItems.map((item, index) => ({
    name: item.name, nameTa: typeof rawItems[index]?.nameTa === 'string' ? rawItems[index].nameTa as string : null, qty: item.quantity, quantity: item.quantity,
    unit: item.unit, unit_type: item.unit_type, base_quantity: item.base_quantity,
    base_price: item.base_price, line_total: item.line_total, price: item.base_price,
  }))
  const shipping = Number(invoice.delivery_charge || invoice.shipping || 0)
  const discount = Number(invoice.discount_amount || 0)
  const subtotal = normalizedItems.reduce((sum, item) => sum + item.line_total, 0) || Number(invoice.total || 0) - shipping + discount

  const downloadPdf = async () => {
    // If invoice URL is stored, use it directly
    if (invoice.invoice_url) {
      const link = document.createElement('a')
      link.href = invoice.invoice_url
      link.download = `Invoice-${invoice.invoice_no}.pdf`
      link.target = '_blank'
      link.click()
      return
    }

    // Otherwise generate on-the-fly
    const file = await invoicePdfFile({
      invoiceNo: invoice.invoice_no, date: invoice.created_at, customerName: invoice.customer_name,
      phone: invoice.phone, address: invoice.address, items: normalizedItems as unknown as Array<Record<string, unknown>>,
      subtotal, shipping, total: Number(invoice.total || 0), discountAmount: discount,
      manualDiscountAmount: Number(invoice.manual_discount_amount || 0), gstAmount: Number(invoice.total_gst || invoice.gst_amount || 0),
      couponCode: invoice.coupon_code, paymentMode: invoice.payment_mode || invoice.payment_method || undefined,
    })
    const url = URL.createObjectURL(file); const link = document.createElement('a'); link.href = url; link.download = file.name; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000)
  }

  const shareOnWhatsApp = async () => {
    if (!invoice) return

    const items = normalizedItems.map(item => ({
      name: item.name,
      qty: item.quantity,
      unit: item.unit,
      unitType: item.unit_type as 'unit' | 'weight' | 'volume' | 'bundle',
      rate: item.base_price,
      lineTotal: item.line_total,
    }))

    const subtotalCalc = items.reduce((sum, item) => sum + item.lineTotal, 0)

    const whatsAppMessage = buildProfessionalWhatsAppMessage({
      customerName: invoice.customer_name,
      phone: invoice.phone,
      invoiceNumber: invoice.invoice_no,
      invoiceDate: invoice.created_at,
      paymentMode: invoice.payment_mode || invoice.payment_method || 'POS',
      items,
      subtotal: subtotalCalc,
      couponDiscount: discount,
      manualDiscountAmount: Number(invoice.manual_discount_amount || 0),
      shipping,
      gstAmount: Number(invoice.total_gst || invoice.gst_amount || 0),
      total: Number(invoice.total || 0),
      invoiceUrl: invoice.invoice_url,
    })

    const phoneNumber = normalizePhone(invoice.phone) || ''
    const waUrl = toWhatsAppUrl(phoneNumber, whatsAppMessage)
    window.open(waUrl, '_blank')
  }

  return (
    <div className="min-h-screen bg-[#f9faf6] font-sans pb-12 print:bg-white print:pb-0">
      <div className="bg-[#f9faf6] p-4 sticky top-0 z-50 print:hidden flex items-center justify-between max-w-4xl mx-auto">
        <Link to="/" className="flex items-center gap-2 text-yellow-dark hover:text-[#2d5a27] font-semibold text-sm transition-colors bg-white border border-[#F0E6C8]/40 px-4 py-2 rounded-full shadow-sm"><ArrowLeft size={16} /> Back</Link>
        <div className="flex items-center gap-2">
          <button onClick={() => void downloadPdf()} className="flex items-center gap-2 bg-[#881337] text-white px-5 py-2 rounded-full font-bold text-sm shadow-md hover:bg-[#6c0f2c] transition-colors"><Printer size={16} /> PDF</button>
          {invoice.invoice_url && (
            <a href={invoice.invoice_url} target="_blank" rel="noopener noreferrer" className="flex items-center gap-2 bg-blue-600 text-white px-5 py-2 rounded-full font-bold text-sm shadow-md hover:bg-blue-700 transition-colors"><Download size={16} /> Download</a>
          )}
          <button onClick={() => void shareOnWhatsApp()} className="flex items-center gap-2 bg-green-600 text-white px-5 py-2 rounded-full font-bold text-sm shadow-md hover:bg-green-700 transition-colors"><MessageCircle size={16} /> WhatsApp</button>
          <button onClick={() => printThermalReceipt({ invoiceNo: invoice.invoice_no, date: invoice.created_at, customerName: invoice.customer_name, phone: invoice.phone, items: normalizedItems.map(item => ({ name: item.name, qty: item.quantity, unit: item.unit, price: item.base_price, line_total: item.line_total })), subtotal, shipping, couponDiscount: discount, totalGst: Number(invoice.total_gst || invoice.gst_amount || 0), total: Number(invoice.total || 0) })} className="flex items-center gap-2 bg-yellow-dark text-white px-5 py-2 rounded-full font-bold text-sm shadow-md hover:bg-yellow-dark transition-colors"><Receipt size={16} /> Print Receipt</button>
        </div>
      </div>
      <div className="max-w-3xl mx-auto mt-4 print:mt-0 px-2 sm:px-0"><div className="bg-white shadow-xl rounded-2xl overflow-hidden print:shadow-none print:rounded-none border border-[#F0E6C8]/20 print:border-none"><Invoice invoiceNo={invoice.invoice_no} date={invoice.created_at} customerName={invoice.customer_name} phone={invoice.phone} address={invoice.address} items={invoiceItems} subtotal={subtotal} shipping={shipping} discountAmount={discount} manualDiscountAmount={Number(invoice.manual_discount_amount || 0)} gstAmount={Number(invoice.total_gst || invoice.gst_amount || 0)} couponCode={invoice.coupon_code} total={Number(invoice.total || 0)} status={invoice.status || 'completed'} paymentMode={invoice.payment_mode || invoice.payment_method || undefined} /></div></div>
    </div>
  )
}
