const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'src', 'pages', 'Pos.tsx');
let content = fs.readFileSync(filePath, 'utf8');

// Fix the \` backslash before backtick
content = content.replace(/\\\\\`/g, '\`');
// Fix the \n literal in import
content = content.replace(
  "import { Invoice } from '../components/Invoice'\\nimport CatalogModal from '../components/CatalogModal'\\nimport AddProductModal from '../components/AddProductModal'",
  "import { Invoice } from '../components/Invoice'\\nimport CatalogModal from '../components/CatalogModal'\\nimport AddProductModal from '../components/AddProductModal'"
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed Pos.tsx syntax errors');
