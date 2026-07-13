const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'src', 'pages', 'Pos.tsx');
let content = fs.readFileSync(filePath, 'utf8');

// 0. Fix newline syntax error created by rewrite scripts
content = content.replace(/import \{ Invoice \} from '\.\.\/components\/Invoice'\\\\nimport CatalogModal from '\.\.\/components\/CatalogModal'\\\\nimport AddProductModal from '\.\.\/components\/AddProductModal'/,
`import { Invoice } from '../components/Invoice'
import CatalogModal from '../components/CatalogModal'
import AddProductModal from '../components/AddProductModal'`);

// 1. Add GST state variables
content = content.replace(
  "  const searchRef = useRef<HTMLInputElement>(null)",
  "  const [billGstEnabled, setBillGstEnabled] = useState(false)\n  const [gstInput, setGstInput] = useState('')\n  const [gstType, setGstType] = useState<'percent' | 'flat'>('percent')\n  const searchRef = useRef<HTMLInputElement>(null)"
);

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
      const msg = err instanceof Error ? err.message : String(err)
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

fs.writeFileSync(filePath, content, 'utf8');
console.log('Applied logic fixes safely!');
