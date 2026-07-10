const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'src', 'pages', 'Pos.tsx');
let content = fs.readFileSync(filePath, 'utf8');

content = content.replace(
  "const waLink = toWhatsAppUrl(inv.phone || customer.phone || '')",
  "const waLink = BRAND_WHATSAPP_LINK"
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Updated WhatsApp link in Pos.tsx');
