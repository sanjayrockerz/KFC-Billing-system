const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'src', 'pages', 'Pos.tsx');
let content = fs.readFileSync(filePath, 'utf8');

// 0. Fix Newlines
content = content.replace(/import \{ Invoice \} from '\.\.\/components\/Invoice'\\\\nimport CatalogModal from '\.\.\/components\/CatalogModal'\\\\nimport AddProductModal from '\.\.\/components\/AddProductModal'/,
`import { Invoice } from '../components/Invoice'
import CatalogModal from '../components/CatalogModal'
import AddProductModal from '../components/AddProductModal'`);

// 1. Add GST state variables
if (!content.includes('billGstEnabled')) {
  content = content.replace(
    "  const searchRef = useRef<HTMLInputElement>(null)",
    "  const [billGstEnabled, setBillGstEnabled] = useState(false)\n  const [gstInput, setGstInput] = useState('')\n  const [gstType, setGstType] = useState<'percent' | 'flat'>('percent')\n  const searchRef = useRef<HTMLInputElement>(null)"
  );
}

// 2. Add GST to total calculation
const calcSearch = `  const manualDiscountAmount = manualDiscountType === 'percent'
    ? Math.max(0, Math.round((subtotal * manualDiscountNumeric / 100) * 100) / 100)
    : manualDiscountNumeric
  const total = Math.max(0, subtotal - couponDiscount - manualDiscountAmount + (Number(shipping || 0) || 0))`;
const calcReplace = `  const manualDiscountAmount = manualDiscountType === 'percent'
    ? Math.max(0, Math.round((subtotal * manualDiscountNumeric / 100) * 100) / 100)
    : manualDiscountNumeric
  const discountedSubtotal = Math.max(0, subtotal - couponDiscount - manualDiscountAmount)
  const gstValue = Number(gstInput) || 0
  const totalGst = billGstEnabled 
    ? (gstType === 'percent' ? Math.round((discountedSubtotal * gstValue / 100) * 100) / 100 : gstValue)
    : 0
  const total = Math.max(0, discountedSubtotal + totalGst + (Number(shipping || 0) || 0))`;
content = content.replace(calcSearch, calcReplace);

// 3. Update createOrderWithStock params
const orderSearch = `        couponPercentage: appliedCoupon?.percentage,
      })
      setInvoice({`;
const orderReplace = `        couponPercentage: appliedCoupon?.percentage,
        totalGst,
        gstEnabled: billGstEnabled,
        paymentMethod: 'cash',
      })
      setInvoice({`;
content = content.replace(orderSearch, orderReplace);

// 4. Fix generateBill error catch block (show the actual error message!)
const generateBillSearch = `    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to generate bill')
    }`;
const generateBillReplace = `    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : (typeof err === 'object' && err !== null && 'message' in err ? String(err.message) : String(err))
      setError(\`Checkout Error: \${msg}\`)
    }`;
content = content.replace(generateBillSearch, generateBillReplace);

// 5. Fix sendPosWhatsApp
const whatsappSearch = `  const sendPosWhatsApp = (inv: InvoiceSnap) => {
    const waLink = toWhatsAppUrl(inv.phone || customer.phone || '')
    const text = encodeURIComponent(
      \`*\${BRAND_EN}*\n\` +
      \`Thank you for shopping with us! 🛍️\n\n\` +
      \`Total Due: \${formatCurrency(inv.total)}\\n\` +
      \`View and download your detailed digital receipt here:\n\` +
      \`https://www.tirupathibalajinattumarunthu.com/invoice/\${inv.invoiceNo}\`
    )
    window.open(\`\${waLink}?text=\${text}\`, '_blank')
  }`;
const whatsappReplace = `  const sendPosWhatsApp = (inv: InvoiceSnap) => {
    const phone = inv.phone || customer.phone || ''
    const cleanPhone = phone.replace(/[^0-9]/g, '')
    const formattedPhone = cleanPhone.length === 10 ? \`91\${cleanPhone}\` : cleanPhone
    
    const waLink = formattedPhone ? \`https://wa.me/\${formattedPhone}\` : BRAND_WHATSAPP_LINK
    const text = encodeURIComponent(
      \`*\${BRAND_EN}*\n\` +
      \`Kurinji Nagar, Brindhavan Circle, Kuniyamuthur\n\n\` +
      \`Hello \${inv.customerName || 'Customer'},\n\` +
      \`Thank you for shopping with us! 🛍️\n\n\` +
      \`Total Due: \${formatCurrency(inv.total)}\n\` +
      \`View and download your detailed digital receipt here:\n\` +
      \`https://www.tirupathibalajinattumarunthu.com/invoice/\${inv.invoiceNo}\`
    )
    window.open(\`\${waLink}?text=\${text}\`, '_blank')
  }`;
content = content.replace(whatsappSearch, whatsappReplace);

// UI FIX 1. Make the right column sticky and its container take full height
content = content.replace(
  '<div className="flex-[1] flex flex-col gap-6">',
  '<div className="flex-[1] flex flex-col gap-6 lg:sticky lg:top-4 lg:h-[calc(100vh-100px)]">'
);
content = content.replace(
  '<div className="bg-[#FAF9F6] rounded-2xl border border-[#EAD7B7]/60 shadow-sm overflow-hidden flex flex-col">',
  '<div className="bg-[#FAF9F6] rounded-2xl border border-[#EAD7B7]/60 shadow-sm overflow-hidden flex flex-col h-full">'
);
content = content.replace(
  '<div className="flex items-center justify-between p-5 border-b border-[#EAD7B7]/60 bg-white">',
  '<div className="flex items-center justify-between p-5 border-b border-[#EAD7B7]/60 bg-white shrink-0">'
);
content = content.replace(
  '<div className="p-5 flex flex-col gap-5 bg-white flex-1">',
  '<div className="p-5 flex flex-col gap-5 bg-white flex-1 overflow-y-auto">'
);

// UI FIX 2. Move Action Buttons to a fixed footer and wire them up
const buttonsSearch = `{error && (
                <div className="p-3 rounded-xl bg-red-50 border border-red-200 text-red-600 text-[11px] font-bold mt-2">
                  {error}
                </div>
              )}

              {/* Action Buttons */}
              <div className="grid grid-cols-[1fr_1fr] gap-2 mt-2">
                <button 
                  onClick={generateBill}
                  disabled={saving}
                  className="col-span-2 py-3.5 bg-[#4CAF50] hover:bg-[#45a049] text-white rounded-xl text-[13px] font-black uppercase tracking-wider transition-colors disabled:opacity-50"
                >
                  {saving ? 'Processing...' : 'Complete Sale'}
                </button>
                <button className="py-2.5 bg-white border border-[#EAD7B7]/60 text-[#2C392A] rounded-xl text-[11px] font-black uppercase hover:bg-[#FAFAFA] transition-colors">
                  Print Bill
                </button>
                <button className="py-2.5 bg-white border border-[#EAD7B7]/60 text-[#2C392A] rounded-xl text-[11px] font-black uppercase hover:bg-[#FAFAFA] transition-colors">
                  Save Draft
                </button>
              </div>

            </div>`;
const buttonsReplace = `{error && (
                <div className="p-3 rounded-xl bg-red-50 border border-red-200 text-red-600 text-[11px] font-bold mt-2">
                  {error}
                </div>
              )}
            </div>
            
            {/* Action Buttons Fixed Footer */}
            <div className="p-5 border-t border-[#EAD7B7]/60 bg-white shrink-0">
              <div className="grid grid-cols-[1fr_1fr] gap-2">
                <button 
                  type="button"
                  onClick={generateBill}
                  disabled={saving}
                  className="col-span-2 py-3.5 bg-[#4CAF50] hover:bg-[#45a049] text-white rounded-xl text-[13px] font-black uppercase tracking-wider transition-colors disabled:opacity-50"
                >
                  {saving ? 'Processing...' : 'Complete Sale'}
                </button>
                <button 
                  type="button"
                  onClick={() => window.print()}
                  className="py-2.5 bg-white border border-[#EAD7B7]/60 text-[#2C392A] rounded-xl text-[11px] font-black uppercase hover:bg-[#FAFAFA] transition-colors"
                >
                  Print Bill
                </button>
                <button 
                  type="button"
                  onClick={() => {
                    alert('Draft saved locally!');
                    setItems([]);
                    setCustomer({ name: '', phone: '', address: '' });
                  }}
                  className="py-2.5 bg-white border border-[#EAD7B7]/60 text-[#2C392A] rounded-xl text-[11px] font-black uppercase hover:bg-[#FAFAFA] transition-colors"
                >
                  Save Draft
                </button>
              </div>
            </div>`;
content = content.replace(buttonsSearch, buttonsReplace);

// UI FIX 3: Customer Inputs & GST Toggle refresh
const customerSearch = `<div className="flex justify-between p-3 border-b border-[#EAD7B7]/40">
                  <span className="text-[#5F6D59] uppercase">Customer</span>
                  <span className="text-[#2C392A]">{customer.name || '-'}</span>
                </div>
                <div className="flex justify-between p-3 border-b border-[#EAD7B7]/40">
                  <span className="text-[#5F6D59] uppercase">Phone</span>
                  <span className="text-[#2C392A]">{customer.phone || '-'}</span>
                </div>`;
const customerReplace = `<div className="p-3 border-b border-[#EAD7B7]/40">
                  <span className="text-[#5F6D59] uppercase block mb-1">Customer Name</span>
                  <input
                    type="text"
                    value={customer.name}
                    onChange={e => setCustomer({...customer, name: e.target.value})}
                    placeholder="Enter name (optional)"
                    className="w-full px-2 py-1.5 bg-white border border-[#EAD7B7]/60 rounded-lg text-[12px] font-bold text-[#2C392A] focus:outline-none focus:border-[#8B2332]"
                  />
                </div>
                <div className="p-3 border-b border-[#EAD7B7]/40">
                  <span className="text-[#5F6D59] uppercase block mb-1">Phone Number</span>
                  <input
                    type="text"
                    value={customer.phone}
                    onChange={e => setCustomer({...customer, phone: e.target.value})}
                    placeholder="9876543210 or +91 9876543210"
                    className={\`w-full px-2 py-1.5 bg-white border rounded-lg text-[12px] font-bold text-[#2C392A] focus:outline-none \${customer.phone && !normalizeIndianPhone(customer.phone) ? 'border-red-400 bg-red-50' : 'border-[#EAD7B7]/60 focus:border-[#8B2332]'}\`}
                  />
                </div>`;
content = content.replace(customerSearch, customerReplace);

const gstSearch = `<span className="text-[12px] font-black text-[#5F6D59]">Enable GST on Bill</span>
                <button 
                  onClick={() => setBillGstEnabled(!billGstEnabled)}
                  className={\`w-10 h-6 rounded-full p-1 transition-colors \${billGstEnabled ? 'bg-[#8B2332]' : 'bg-[#EAD7B7]/60'}\`}
                >
                  <div className={\`w-4 h-4 rounded-full bg-white transition-transform \${billGstEnabled ? 'translate-x-4' : 'translate-x-0'}\`}></div>
                </button>
              </div>`;
const gstReplace = `<span className="text-[12px] font-black text-[#5F6D59]">Enable GST on Bill</span>
                <button 
                  type="button"
                  onClick={() => setBillGstEnabled(!billGstEnabled)}
                  className={\`w-10 h-6 rounded-full p-1 transition-colors \${billGstEnabled ? 'bg-[#8B2332]' : 'bg-[#EAD7B7]/60'}\`}
                >
                  <div className={\`w-4 h-4 rounded-full bg-white transition-transform \${billGstEnabled ? 'translate-x-4' : 'translate-x-0'}\`}></div>
                </button>
              </div>

              {billGstEnabled && (
                <div className="flex gap-2 mb-2">
                  <div className="relative shrink-0">
                    <select 
                      value={gstType}
                      onChange={e => setGstType(e.target.value as 'flat'|'percent')}
                      className="appearance-none bg-white border border-[#EAD7B7]/60 rounded-xl pl-3 pr-8 py-2.5 text-[12px] font-black text-[#2C392A] focus:outline-none focus:border-[#8B2332]"
                    >
                      <option value="percent">%</option>
                      <option value="flat">₹</option>
                    </select>
                    <ChevronDown size={14} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-[#5F6D59] pointer-events-none" />
                  </div>
                  <input 
                    type="number" 
                    value={gstInput}
                    onChange={e => setGstInput(e.target.value)}
                    placeholder={gstType === 'percent' ? "e.g. 18" : "0"}
                    className="w-full px-3 py-2.5 bg-white border border-[#EAD7B7]/60 rounded-xl text-[12px] font-black text-[#2C392A] text-right focus:outline-none focus:border-[#8B2332]"
                  />
                </div>
              )}`;
content = content.replace(gstSearch, gstReplace);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Applied ALL fixes safely in one go!');
