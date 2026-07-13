const bcrypt = require('bcryptjs')
const { PrismaClient } = require('@prisma/client')

const prisma = new PrismaClient()

const products = [
  { name: 'Sukku Powder', category: 'Herbal Powder', price: 80, description: 'Traditional dry ginger powder used in Siddha medicine.', benefits: 'Aids digestion, relieves cold and cough.', imageUrl: '/assets/images/sukku-powder.svg', stock: 50 },
  { name: 'Thippili Powder', category: 'Herbal Powder', price: 90, description: 'Long pepper powder for respiratory wellness.', benefits: 'Supports lungs and immunity.', imageUrl: '/assets/images/thippili-powder.svg', stock: 40 },
  { name: 'Athimathuram Root', category: 'Herbal Root', price: 120, description: 'Liquorice root widely used in traditional remedies.', benefits: 'Soothes throat and reduces inflammation.', imageUrl: '/assets/images/athimathuram-root.svg', stock: 35 },
  { name: 'Nilavembu Powder', category: 'Herbal Powder', price: 70, description: 'Andrographis-based powder known for immune support.', benefits: 'Supports fever management and immunity.', imageUrl: '/assets/images/nilavembu-powder.svg', stock: 60 },
  { name: 'Triphala Powder', category: 'Herbal Powder', price: 95, description: 'Classic blend of three healing fruits.', benefits: 'Improves digestion and detoxification.', imageUrl: '/assets/images/triphala-powder.svg', stock: 45 },
  { name: 'Thuthuvalai Powder', category: 'Herbal Powder', price: 85, description: 'Respiratory support herb powder.', benefits: 'Helps breathing and immunity.', imageUrl: '/assets/images/thuthuvalai-powder.svg', stock: 30 },
  { name: 'Avarampoo Powder', category: 'Herbal Powder', price: 60, description: 'Flower powder with cooling properties.', benefits: 'Supports skin wellness and digestion.', imageUrl: '/assets/images/avarampoo-powder.svg', stock: 55 },
  { name: 'Nannari Root Powder', category: 'Herbal Root', price: 110, description: 'Cooling root powder used as blood purifier.', benefits: 'Supports skin health and cooling.', imageUrl: '/assets/images/nannari-root.svg', stock: 25 },
  { name: 'Ashwagandha Powder', category: 'Herbal Powder', price: 150, description: 'Adaptogenic herb powder for vitality.', benefits: 'Reduces stress and boosts energy.', imageUrl: '/assets/images/ashwagandha-powder.svg', stock: 70 },
  { name: 'Bhringaraj Powder', category: 'Herbal Powder', price: 100, description: 'Herb known for hair and scalp wellness.', benefits: 'Supports hair growth and scalp health.', imageUrl: '/assets/images/bhringaraj-powder.svg', stock: 40 },
  { name: 'Amla Powder', category: 'Herbal Powder', price: 75, description: 'Vitamin C rich gooseberry powder.', benefits: 'Supports immunity and hair health.', imageUrl: '/assets/images/amla-powder.svg', stock: 80 },
  { name: 'Neem Powder', category: 'Herbal Powder', price: 65, description: 'Natural antiseptic leaf powder.', benefits: 'Supports skin purification.', imageUrl: '/assets/images/neem-powder.svg', stock: 60 },
  { name: 'Tulsi Powder', category: 'Herbal Powder', price: 70, description: 'Holy basil powder for daily herbal use.', benefits: 'Supports immunity and stress relief.', imageUrl: '/assets/images/tulsi-powder.svg', stock: 55 },
  { name: 'Shatavari Powder', category: 'Herbal Powder', price: 130, description: 'Traditional women wellness herb.', benefits: 'Supports hormone balance and immunity.', imageUrl: '/assets/images/shatavari-powder.svg', stock: 30 },
  { name: 'Haritaki Powder', category: 'Herbal Powder', price: 85, description: 'Digestive and rejuvenating herb powder.', benefits: 'Supports digestion and detox.', imageUrl: '/assets/images/haritaki-powder.svg', stock: 45 },
  { name: 'Bringraj Hair Oil', category: 'Herbal Oil', price: 180, description: 'Herbal oil for scalp nourishment.', benefits: 'Supports hair growth and reduces breakage.', imageUrl: '/assets/images/bringraj-hair-oil.svg', stock: 35 },
  { name: 'Neem Oil', category: 'Herbal Oil', price: 120, description: 'Cold-pressed neem seed oil.', benefits: 'Supports skin and scalp care.', imageUrl: '/assets/images/neem-oil.svg', stock: 40 },
  { name: 'Sesame Hair Oil', category: 'Herbal Oil', price: 150, description: 'Traditional sesame base hair oil.', benefits: 'Conditions hair and scalp.', imageUrl: '/assets/images/sesame-hair-oil.svg', stock: 50 },
  { name: 'Coconut-Brahmi Oil', category: 'Herbal Oil', price: 160, description: 'Coconut oil infused with brahmi.', benefits: 'Supports scalp cooling and relaxation.', imageUrl: '/assets/images/coconut-brahmi-oil.svg', stock: 45 },
  { name: 'Castor Oil', category: 'Herbal Oil', price: 90, description: 'Cold-pressed castor oil.', benefits: 'Supports hair and skin moisture.', imageUrl: '/assets/images/castor-oil.svg', stock: 60 },
  { name: 'Moringa Leaf Powder', category: 'Herbal Leaf', price: 40, description: 'Nutrient-rich leaf powder.', benefits: 'Supports nutrition and immunity.', imageUrl: '/assets/images/moringa-leaf-powder.svg', stock: 70 },
  { name: 'Dried Tulsi Leaves', category: 'Herbal Leaf', price: 50, description: 'Sun-dried basil leaves.', benefits: 'Supports respiratory comfort.', imageUrl: '/assets/images/dried-tulsi-leaves.svg', stock: 65 },
  { name: 'Black Pepper (Milagu)', category: 'Herbal Spice', price: 60, description: 'Whole pepper spice.', benefits: 'Supports digestion and warmth.', imageUrl: '/assets/images/black-pepper.svg', stock: 80 },
  { name: 'Dried Ginger (Sukku)', category: 'Herbal Spice', price: 75, description: 'Whole dried ginger root.', benefits: 'Supports digestion and cold relief.', imageUrl: '/assets/images/dried-ginger.svg', stock: 55 },
  { name: 'Cinnamon Sticks', category: 'Herbal Spice', price: 80, description: 'Premium cinnamon bark sticks.', benefits: 'Supports metabolism and warmth.', imageUrl: '/assets/images/cinnamon-sticks.svg', stock: 50 },
  { name: 'Cardamom Pods', category: 'Herbal Spice', price: 250, description: 'Aromatic cardamom pods.', benefits: 'Supports digestion and fresh breath.', imageUrl: '/assets/images/cardamom-pods.svg', stock: 30 },
  { name: 'Raw Turmeric Powder', category: 'Herbal Powder', price: 70, description: 'Pure turmeric powder.', benefits: 'Supports immunity and skin health.', imageUrl: '/assets/images/raw-turmeric-powder.svg', stock: 90 },
  { name: 'Kumkumadi Face Oil', category: 'Herbal Oil', price: 350, description: 'Traditional facial herbal oil.', benefits: 'Supports glow and tone.', imageUrl: '/assets/images/kumkumadi-face-oil.svg', stock: 20 },
  { name: 'Trikatu Churna', category: 'Herbal Powder', price: 100, description: 'Three-spice churna blend.', benefits: 'Supports metabolism and digestion.', imageUrl: '/assets/images/trikatu-churna.svg', stock: 40 },
  { name: 'Vetiver Root (Khus)', category: 'Herbal Root', price: 90, description: 'Cooling aromatic root.', benefits: 'Supports cooling and relaxation.', imageUrl: '/assets/images/vetiver-root.svg', stock: 35 },
  { name: 'Brahmi Powder', category: 'Herbal Powder', price: 110, description: 'Memory-supportive herb powder.', benefits: 'Supports calm focus.', imageUrl: '/assets/images/brahmi-powder.svg', stock: 45 },
  { name: 'Mulethi Sticks', category: 'Herbal Root', price: 80, description: 'Dried liquorice sticks.', benefits: 'Supports throat comfort.', imageUrl: '/assets/images/mulethi-sticks.svg', stock: 50 },
  { name: 'Shilajit (Purified)', category: 'Mineral Herb', price: 450, description: 'Purified mineral resin product.', benefits: 'Supports vitality and stamina.', imageUrl: '/assets/images/shilajit.svg', stock: 15 },
  { name: 'Guggul Tablets', category: 'Herbal Tablet', price: 200, description: 'Convenient guggul tablets.', benefits: 'Supports metabolism and joints.', imageUrl: '/assets/images/guggul-tablets.svg', stock: 30 },
  { name: 'Aloe Vera Gel', category: 'Herbal Gel', price: 130, description: 'Pure aloe vera gel.', benefits: 'Supports skin hydration.', imageUrl: '/assets/images/aloe-vera-gel.svg', stock: 55 },
  { name: 'Fenugreek Powder', category: 'Herbal Powder', price: 55, description: 'Fenugreek seed powder.', benefits: 'Supports hair and digestion.', imageUrl: '/assets/images/fenugreek-powder.svg', stock: 80 },
  { name: 'Kalmegh Powder', category: 'Herbal Powder', price: 75, description: 'Bitter immunity herb powder.', benefits: 'Supports fever and immunity.', imageUrl: '/assets/images/kalmegh-powder.svg', stock: 40 },
  { name: 'Shikakai Powder', category: 'Herbal Powder', price: 60, description: 'Natural hair cleansing powder.', benefits: 'Supports scalp cleansing.', imageUrl: '/assets/images/shikakai-powder.svg', stock: 65 },
  { name: 'Soapnut (Reetha)', category: 'Herbal Product', price: 65, description: 'Natural saponin-rich cleanser.', benefits: 'Supports natural wash and scalp care.', imageUrl: '/assets/images/soapnut-reetha.svg', stock: 50 },
  { name: 'Saffron (Kesar)', category: 'Herbal Spice', price: 800, description: 'Premium saffron threads.', benefits: 'Supports mood and antioxidant wellness.', imageUrl: '/assets/images/saffron-kesar.svg', stock: 10 },
]

async function main() {
  await prisma.orderItem.deleteMany()
  await prisma.order.deleteMany()
  await prisma.favorite.deleteMany()
  await prisma.product.deleteMany()
  await prisma.user.deleteMany()

  await prisma.product.createMany({ data: products })

  const adminPasswordHash = await bcrypt.hash('Admin@123', 10)
  await prisma.user.create({
    data: {
      name: 'Admin User',
      email: 'admin@srisiddha.com',
      passwordHash: adminPasswordHash,
      role: 'admin',
    },
  })

  const customerPasswordHash = await bcrypt.hash('Customer@123', 10)
  await prisma.user.create({
    data: {
      name: 'Demo Customer',
      email: 'customer@srisiddha.com',
      passwordHash: customerPasswordHash,
      role: 'customer',
    },
  })

  console.log('Seed completed: 40 products + demo users created.')
}

main()
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })

