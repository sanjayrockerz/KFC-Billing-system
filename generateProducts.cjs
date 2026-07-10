const fs = require('fs');

const categories = [
  'Herbal Powder', 'Herbal Oil', 'Herbal Root', 'Herbal Spice', 'Herbal Gel', 
  'Mineral Herb', 'Herbal Tablet', 'Herbal Leaf', 'Herbal Product'
];

const tags = [
  'Cold & Cough', 'Digestion', 'Hair Growth', 'Immunity', 'Skin Care', 
  'Stress', 'Fever', 'Joint Pain', 'Diabetes', 'Weight Loss'
];

const images = {
  'Herbal Powder': 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80',
  'Herbal Oil': 'https://images.unsplash.com/photo-1608500218861-010f3a4bba8b?w=400&q=80',
  'Herbal Root': 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80',
  'Herbal Spice': 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&q=80',
  'Herbal Gel': 'https://images.unsplash.com/photo-1615397323759-4ac9fc2726bb?w=400&q=80',
  'Mineral Herb': 'https://images.unsplash.com/photo-1611078817293-61b474136e65?w=400&q=80',
  'Herbal Tablet': 'https://images.unsplash.com/photo-1584308666744-24d5e4a81b2e?w=400&q=80',
  'Herbal Leaf': 'https://images.unsplash.com/photo-1628498846897-400d8b4c74a9?w=400&q=80',
  'Herbal Product': 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80'
};

const products = [];
const namesList = [
  { n: 'Amukkara Chooranam', ta: 'அமுக்கரா சூரணம்', c: 'Herbal Powder', r: ['Stress', 'Immunity'], ut: 'weight', ul: 'g', bq: 100, p: 150 },
  { n: 'Nilavembu Kudineer', ta: 'நிலவேம்பு குடிநீர்', c: 'Herbal Powder', r: ['Fever', 'Immunity'], ut: 'weight', ul: 'g', bq: 100, p: 120 },
  { n: 'Kaba Sura Kudineer', ta: 'கபசுர குடிநீர்', c: 'Herbal Powder', r: ['Cold & Cough', 'Fever'], ut: 'weight', ul: 'g', bq: 100, p: 130 },
  { n: 'Thoothuvalai Podi', ta: 'தூதுவளை பொடி', c: 'Herbal Powder', r: ['Cold & Cough', 'Immunity'], ut: 'weight', ul: 'g', bq: 100, p: 110 },
  { n: 'Karisalanganni Podi', ta: 'கரிசலாங்கண்ணி பொடி', c: 'Herbal Powder', r: ['Hair Growth', 'Digestion'], ut: 'weight', ul: 'g', bq: 100, p: 140 },
  { n: 'Vasambu Podi', ta: 'வசம்பு பொடி', c: 'Herbal Powder', r: ['Digestion', 'Immunity'], ut: 'weight', ul: 'g', bq: 50, p: 80 },
  { n: 'Neem Powder', ta: 'வேப்பிலை பொடி', c: 'Herbal Powder', r: ['Skin Care', 'Diabetes'], ut: 'weight', ul: 'g', bq: 100, p: 90 },
  { n: 'Moringa Powder', ta: 'முருங்கை பொடி', c: 'Herbal Powder', r: ['Immunity', 'Joint Pain'], ut: 'weight', ul: 'g', bq: 100, p: 160 },
  { n: 'Triphala Chooranam', ta: 'திரிபலா சூரணம்', c: 'Herbal Powder', r: ['Digestion', 'Weight Loss'], ut: 'weight', ul: 'g', bq: 100, p: 150 },
  { n: 'Adhatoda Powder', ta: 'ஆடாதோடா பொடி', c: 'Herbal Powder', r: ['Cold & Cough', 'Fever'], ut: 'weight', ul: 'g', bq: 100, p: 130 },
  
  { n: 'Karpooravalli Thailam', ta: 'கற்பூரவள்ளி தைலம்', c: 'Herbal Oil', r: ['Cold & Cough', 'Joint Pain'], ut: 'volume', ul: 'ml', bq: 100, p: 200 },
  { n: 'Neelibhringadi Thailam', ta: 'நீலிபிருங்காதி தைலம்', c: 'Herbal Oil', r: ['Hair Growth', 'Stress'], ut: 'volume', ul: 'ml', bq: 100, p: 250 },
  { n: 'Pinda Thailam', ta: 'பிண்ட தைலம்', c: 'Herbal Oil', r: ['Joint Pain', 'Skin Care'], ut: 'volume', ul: 'ml', bq: 100, p: 220 },
  { n: 'Castor Oil (Amanakku)', ta: 'ஆமணக்கு எண்ணெய்', c: 'Herbal Oil', r: ['Digestion', 'Hair Growth'], ut: 'volume', ul: 'ml', bq: 200, p: 180 },
  { n: 'Sesame Oil (Nallennai)', ta: 'நல்லெண்ணெய்', c: 'Herbal Oil', r: ['Joint Pain', 'Skin Care'], ut: 'volume', ul: 'ml', bq: 500, p: 350 },
  { n: 'Mahamasha Thailam', ta: 'மகாமாஷ தைலம்', c: 'Herbal Oil', r: ['Joint Pain', 'Stress'], ut: 'volume', ul: 'ml', bq: 100, p: 280 },
  { n: 'Kumkumadi Thailam', ta: 'குங்குமாதி தைலம்', c: 'Herbal Oil', r: ['Skin Care'], ut: 'volume', ul: 'ml', bq: 25, p: 450 },
  { n: 'Arugan Thailam', ta: 'அருகன் தைலம்', c: 'Herbal Oil', r: ['Skin Care', 'Hair Growth'], ut: 'volume', ul: 'ml', bq: 100, p: 210 },
  
  { n: 'Ashwagandha Root', ta: 'அஸ்வகந்தா வேர்', c: 'Herbal Root', r: ['Stress', 'Immunity'], ut: 'weight', ul: 'g', bq: 100, p: 300 },
  { n: 'Sarsaparilla Root', ta: 'நன்னாரி வேர்', c: 'Herbal Root', r: ['Digestion', 'Skin Care'], ut: 'weight', ul: 'g', bq: 100, p: 250 },
  { n: 'Korai Kizhangu', ta: 'கோரை கிழங்கு', c: 'Herbal Root', r: ['Digestion', 'Weight Loss'], ut: 'weight', ul: 'g', bq: 100, p: 180 },
  { n: 'Vettiver', ta: 'வெட்டிவேர்', c: 'Herbal Root', r: ['Stress', 'Skin Care'], ut: 'weight', ul: 'g', bq: 50, p: 150 },
  { n: 'Athimathuram Root', ta: 'அதிமதுரம் வேர்', c: 'Herbal Root', r: ['Cold & Cough', 'Digestion'], ut: 'weight', ul: 'g', bq: 100, p: 220 },
  { n: 'Sitharathai Root', ta: 'சித்தரத்தை வேர்', c: 'Herbal Root', r: ['Cold & Cough', 'Joint Pain'], ut: 'weight', ul: 'g', bq: 100, p: 240 },
  { n: 'Poolankilangu', ta: 'பூலாங்கிழங்கு', c: 'Herbal Root', r: ['Skin Care', 'Fever'], ut: 'weight', ul: 'g', bq: 100, p: 190 },
  
  { n: 'Black Pepper', ta: 'மிளகு', c: 'Herbal Spice', r: ['Cold & Cough', 'Digestion'], ut: 'weight', ul: 'g', bq: 200, p: 350 },
  { n: 'Dry Ginger (Sukku)', ta: 'சுக்கு', c: 'Herbal Spice', r: ['Digestion', 'Joint Pain'], ut: 'weight', ul: 'g', bq: 100, p: 180 },
  { n: 'Cardamom (Elakkai)', ta: 'ஏலக்காய்', c: 'Herbal Spice', r: ['Digestion', 'Skin Care'], ut: 'weight', ul: 'g', bq: 50, p: 400 },
  { n: 'Clove (Krambu)', ta: 'கிராம்பு', c: 'Herbal Spice', r: ['Cold & Cough', 'Joint Pain'], ut: 'weight', ul: 'g', bq: 50, p: 250 },
  { n: 'Turmeric (Manjal)', ta: 'மஞ்சள்', c: 'Herbal Spice', r: ['Skin Care', 'Immunity'], ut: 'weight', ul: 'g', bq: 250, p: 150 },
  { n: 'Fenugreek (Vendhayam)', ta: 'வெந்தயம்', c: 'Herbal Spice', r: ['Diabetes', 'Hair Growth'], ut: 'weight', ul: 'g', bq: 250, p: 120 },
  { n: 'Cinnamon (Pattai)', ta: 'பட்டை', c: 'Herbal Spice', r: ['Weight Loss', 'Diabetes'], ut: 'weight', ul: 'g', bq: 100, p: 200 },
  { n: 'Cumin (Seeragam)', ta: 'சீரகம்', c: 'Herbal Spice', r: ['Digestion', 'Weight Loss'], ut: 'weight', ul: 'g', bq: 200, p: 220 },
  
  { n: 'Aloe Vera Gel', ta: 'கற்றாழை ஜெல்', c: 'Herbal Gel', r: ['Skin Care', 'Hair Growth'], ut: 'weight', ul: 'g', bq: 150, p: 180 },
  { n: 'Kuppaimeni Gel', ta: 'குப்பைமேனி ஜெல்', c: 'Herbal Gel', r: ['Skin Care', 'Fever'], ut: 'weight', ul: 'g', bq: 100, p: 160 },
  { n: 'Vettiver Gel', ta: 'வெட்டிவேர் ஜெல்', c: 'Herbal Gel', r: ['Skin Care', 'Stress'], ut: 'weight', ul: 'g', bq: 100, p: 200 },
  { n: 'Tulsi Anti-Acne Gel', ta: 'துளசி ஜெல்', c: 'Herbal Gel', r: ['Skin Care', 'Immunity'], ut: 'weight', ul: 'g', bq: 100, p: 150 },
  
  { n: 'Shilajit Extract', ta: 'சிலாஜித்', c: 'Mineral Herb', r: ['Immunity', 'Stress'], ut: 'weight', ul: 'g', bq: 20, p: 950 },
  { n: 'Padikaram (Alum)', ta: 'படிகாரம்', c: 'Mineral Herb', r: ['Skin Care', 'Joint Pain'], ut: 'weight', ul: 'g', bq: 100, p: 90 },
  { n: 'Loha Bhasma', ta: 'லோக பஸ்மா', c: 'Mineral Herb', r: ['Immunity', 'Hair Growth'], ut: 'weight', ul: 'g', bq: 10, p: 350 },
  { n: 'Kavikkal (Red Ochre)', ta: 'கவிக்கல்', c: 'Mineral Herb', r: ['Skin Care'], ut: 'weight', ul: 'g', bq: 100, p: 120 },
  
  { n: 'Brahmi Vati', ta: 'பிரம்மி மாத்திரை', c: 'Herbal Tablet', r: ['Stress', 'Memory'], ut: 'unit', ul: 'capsules', bq: 60, p: 250 },
  { n: 'Arjuna Tablet', ta: 'அர்ஜுனா மாத்திரை', c: 'Herbal Tablet', r: ['Stress', 'Immunity'], ut: 'unit', ul: 'capsules', bq: 60, p: 220 },
  { n: 'Vallarai Tablet', ta: 'வல்லாரை மாத்திரை', c: 'Herbal Tablet', r: ['Stress', 'Fatigue'], ut: 'unit', ul: 'capsules', bq: 60, p: 200 },
  { n: 'Madhumehari Tablet', ta: 'நீரிழிவு மாத்திரை', c: 'Herbal Tablet', r: ['Diabetes', 'Weight Loss'], ut: 'unit', ul: 'capsules', bq: 100, p: 350 },
  { n: 'Amla Extract Capsule', ta: 'நெல்லிக்காய் மாத்திரை', c: 'Herbal Tablet', r: ['Immunity', 'Hair Growth'], ut: 'unit', ul: 'capsules', bq: 60, p: 280 },
  { n: 'Manasamithini Tablet', ta: 'மனசமிதிநி மாத்திரை', c: 'Herbal Tablet', r: ['Stress', 'Digestion'], ut: 'unit', ul: 'capsules', bq: 60, p: 240 },
  
  { n: 'Dry Tulsi Leaves', ta: 'துளசி இலை', c: 'Herbal Leaf', r: ['Fever', 'Cold & Cough'], ut: 'weight', ul: 'g', bq: 50, p: 90 },
  { n: 'Dry Neem Leaves', ta: 'வேப்பிலை', c: 'Herbal Leaf', r: ['Skin Care', 'Diabetes'], ut: 'weight', ul: 'g', bq: 100, p: 80 },
  { n: 'Mint Leaves (Pudina)', ta: 'புதினா இலை', c: 'Herbal Leaf', r: ['Digestion', 'Weight Loss'], ut: 'weight', ul: 'g', bq: 50, p: 120 },
  { n: 'Curry Leaves', ta: 'கறிவேப்பிலை', c: 'Herbal Leaf', r: ['Hair Growth', 'Digestion'], ut: 'weight', ul: 'g', bq: 100, p: 110 },
  { n: 'Senna Leaves', ta: 'நிலாவாரை', c: 'Herbal Leaf', r: ['Digestion', 'Skin Care'], ut: 'weight', ul: 'g', bq: 100, p: 150 },
  { n: 'Siriyanangai Leaves', ta: 'சிறியாநங்கை இலை', c: 'Herbal Leaf', r: ['Diabetes', 'Fever'], ut: 'weight', ul: 'g', bq: 50, p: 180 },
  { n: 'Keezhanelli Leaves', ta: 'கீழாநெல்லி இலை', c: 'Herbal Leaf', r: ['Digestion', 'Immunity'], ut: 'weight', ul: 'g', bq: 100, p: 160 },
  
  { n: 'Siddha Hair Wash Pack', ta: 'சிகைக்காய் தூள்', c: 'Herbal Product', r: ['Hair Growth'], ut: 'weight', ul: 'g', bq: 200, p: 220 },
  { n: 'Pancha Karpam Bathing Powder', ta: 'பஞ்ச கற்பம்', c: 'Herbal Product', r: ['Skin Care', 'Stress'], ut: 'weight', ul: 'g', bq: 250, p: 280 },
  { n: 'Avarampoo Bath Powder', ta: 'ஆவாரம்பூ குளியல் பொடி', c: 'Herbal Product', r: ['Skin Care', 'Fever'], ut: 'weight', ul: 'g', bq: 200, p: 250 },
  { n: 'Herbal Tooth Powder', ta: 'மூலிகை பல்பொடி', c: 'Herbal Product', r: ['Immunity'], ut: 'weight', ul: 'g', bq: 100, p: 140 },
  { n: 'Triphala Honey Blend', ta: 'திரிபலா தேன் கலவை', c: 'Herbal Product', r: ['Digestion', 'Weight Loss'], ut: 'weight', ul: 'g', bq: 250, p: 400 },
  { n: 'Siddha Chyawanprash', ta: 'சித்தா சியவன்ப்ராஷ்', c: 'Herbal Product', r: ['Immunity', 'Stress'], ut: 'weight', ul: 'g', bq: 500, p: 550 },
  { n: 'Navadhanya Mix', ta: 'நவதானிய மாவு', c: 'Herbal Product', r: ['Weight Loss', 'Diabetes'], ut: 'weight', ul: 'g', bq: 500, p: 300 }
];

let sql = `
-- ═══════════════════════════════════════════════════════════════════════
-- 8. SEED MOCK PRODUCTS (61 Full Items for Dashboard)
-- ═══════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF (SELECT COUNT(*) FROM public.products) < 60 THEN
    DELETE FROM public.products;
    
    INSERT INTO public.products (
      name, name_ta, tamil_name, category, category_id, remedy, price, offer_price, description, 
      benefits, image, image_url, stock, stock_quantity, stock_unit, unit, unit_type, unit_label, base_quantity, allow_decimal_quantity
    ) VALUES
`;

const rows = namesList.map((p, i) => {
  const imgUrl = images[p.c];
  const catId = categories.indexOf(p.c) + 1;
  const desc = `Premium ${p.c} formulated using authentic Siddha practices. Trusted for generations to relieve symptoms linked to ${p.r.join(' and ')}.`;
  const ben = `Naturally targets ${p.r.join(', ')} while boosting overall vitality.`;
  const remedyStr = `ARRAY[${p.r.map(r => `'${r}'`).join(', ')}]`;
  const unitStr = p.ut === 'unit' ? p.bq + ' ' + p.ul : p.bq + p.ul;
  
  return `    ('${p.n.replace(/'/g, "''")}', '${p.ta.replace(/'/g, "''")}', '${p.ta.replace(/'/g, "''")}', '${p.c}', ${catId}, ${remedyStr}, ${p.p}, ${p.p > 100 ? p.p - 10 : 'NULL'}, '${desc.replace(/'/g, "''")}', '${ben.replace(/'/g, "''")}', '${imgUrl}', '${imgUrl}', 100, 100, '${p.ul}', '${unitStr}', '${p.ut}', '${p.ul}', ${p.bq}, ${p.ut === 'unit' ? 'false' : 'true'})`;
});

sql += rows.join(',\n') + ';\n  END IF;\nEND $$;\n';

fs.writeFileSync('c:\\\\Users\\\\motis\\\\Downloads\\\\Naatu Marundhu Shop\\\\naatu-shop\\\\generateProducts.js-output', sql);
