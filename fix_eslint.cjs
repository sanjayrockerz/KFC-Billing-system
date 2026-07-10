const fs = require('fs');

const file = 'src/pages/Pos.tsx';
let content = fs.readFileSync(file, 'utf8');

// Imports
content = content.replace(/Link, /g, '');
content = content.replace(/, Minus/g, '');
content = content.replace(/ChevronLeft, /g, '');
content = content.replace(/, Wifi, WifiOff, Layers, X/g, '');
content = content.replace(/, BRAND_TA, BRAND_WHATSAPP_LINK/g, '');
content = content.replace(/import \{ getProductImage, onImgError \} from '\.\.\/lib\/utils'\\n/g, '');

// Variables
content = content.replace(/const CAT_COLOR: Record<string, string> = \{[\\s\\S]*?\}\\n/g, '');
content = content.replace(/, error: productError/g, '');
content = content.replace(/  const \\[billingAdjOpen, setBillingAdjOpen\\] = useState\\(false\\)\\n/g, '');
content = content.replace(/  const \\[search, setSearch\\] = useState\\(''(.*?)\\)\\n/g, "  const [search] = useState('')\n");
content = content.replace(/  const \\[activeCategory, setActiveCategory\\] = useState\\('All'\\)\\n/g, "  const [activeCategory] = useState('All')\n");
content = content.replace(/  const \\[mobilePanelView, setMobilePanelView\\] = useState<'catalogue' \\| 'bill'>\\('catalogue'\\)\\n/g, '');
content = content.replace(/  const categories = useMemo\\(\\(\\) => \\{[\\s\\S]*?\\}, \\[products\\]\\)\\n/g, '');
content = content.replace(/  const filtered = useMemo\\(\\(\\) => \\{[\\s\\S]*?\\}, \\[products, search, activeCategory\\]\\)\\n/g, '');
content = content.replace(/  const itemQtyMap = useMemo\\(\\(\\) => \\{[\\s\\S]*?\\}, \\[items\\]\\)\\n/g, '');
content = content.replace(/  const addVariantToItems = \\(product: Product, variant: ProductVariant, qty: number = 1\\) => \\{[\\s\\S]*?\\}\\n/g, '');
content = content.replace(/  const \\[qty, setQty\\] = useState\\(1\\)\\n/g, "  const [qty] = useState(1)\n");
content = content.replace(/  const isInsufficientPayment = paymentMethod === 'cash' && cashReceived !== '' && parseFloat\\(cashReceived\\) < total\\n/g, '');
content = content.replace(/  const change = paymentMethod === 'cash' && cashReceived !== '' \\? Math\\.max\\(0, parseFloat\\(cashReceived\\) - total\\) : 0\\n/g, '');

fs.writeFileSync(file, content);
console.log('Fixed ESLint errors in Pos.tsx');
