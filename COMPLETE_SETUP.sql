-- ============================================================================
-- SRI SIDDHA HERBAL E-COMMERCE COMPLETE SETUP SCRIPT
-- ============================================================================
-- Run this entire script in Supabase SQL Editor to fully setup the database
-- This script includes: schema patches, RLS policies, and 40 product seeds
-- ============================================================================

-- ============================================================================
-- STEP 1: CREATE TABLES (if they don't exist)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.products (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  name_ta TEXT DEFAULT '',
  category TEXT NOT NULL,
  price NUMERIC(10,2) NOT NULL,
  offer_price NUMERIC(10,2),
  description TEXT,
  description_ta TEXT DEFAULT '',
  benefits TEXT,
  benefits_ta TEXT DEFAULT '',
  remedy TEXT[] DEFAULT '{}',
  image_url TEXT,
  image TEXT DEFAULT '/assets/images/default-herb.jpg',
  stock INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.orders (
  id BIGSERIAL PRIMARY KEY,
  invoice_no TEXT UNIQUE,
  user_id UUID REFERENCES auth.users ON DELETE SET NULL,
  customer_name TEXT,
  phone TEXT,
  address TEXT,
  items JSONB NOT NULL DEFAULT '[]',
  subtotal NUMERIC(10,2) NOT NULL DEFAULT 0,
  shipping NUMERIC(10,2) NOT NULL DEFAULT 0,
  total NUMERIC(10,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  email TEXT UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  mobile TEXT DEFAULT '',
  role TEXT DEFAULT 'customer',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- STEP 2: SCHEMA COMPATIBILITY PATCHES
-- ============================================================================

-- Orders table schema enhancements
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS invoice_no TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users ON DELETE SET NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS items JSONB NOT NULL DEFAULT '[]';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS subtotal NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS shipping NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS total NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- Products table schema enhancements
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS name_ta TEXT DEFAULT '';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS offer_price NUMERIC(10,2);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS description_ta TEXT DEFAULT '';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS benefits_ta TEXT DEFAULT '';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS remedy TEXT[] DEFAULT '{}';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image TEXT DEFAULT '/assets/images/default-herb.jpg';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Fix image field consistency
UPDATE public.products
SET image = COALESCE(NULLIF(image, ''), image_url, '/assets/images/default-herb.jpg')
WHERE image IS NULL OR image = '';

-- Profiles table schema enhancements
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS mobile TEXT DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'customer';

-- Ensure admin role field is properly initialized
UPDATE public.profiles SET role = 'customer' WHERE role IS NULL OR role = '';

-- ============================================================================
-- STEP 3: ENABLE ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 4: CREATE ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Products policies (public read, admin write)
DROP POLICY IF EXISTS "products_public_read" ON public.products;
CREATE POLICY "products_public_read" ON public.products
FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "products_admin_write" ON public.products;
CREATE POLICY "products_admin_write" ON public.products
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND COALESCE(p.role, 'customer') = 'admin'
  )
);

DROP POLICY IF EXISTS "products_admin_update" ON public.products;
CREATE POLICY "products_admin_update" ON public.products
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND COALESCE(p.role, 'customer') = 'admin'
  )
);

DROP POLICY IF EXISTS "products_admin_delete" ON public.products;
CREATE POLICY "products_admin_delete" ON public.products
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND COALESCE(p.role, 'customer') = 'admin'
  )
);

-- Orders policies
DROP POLICY IF EXISTS "orders_users_insert" ON public.orders;
CREATE POLICY "orders_users_insert" ON public.orders
FOR INSERT WITH CHECK (auth.uid()::TEXT = user_id::TEXT OR user_id IS NULL);

DROP POLICY IF EXISTS "orders_users_read" ON public.orders;
CREATE POLICY "orders_users_read" ON public.orders
FOR SELECT USING (auth.uid()::TEXT = user_id::TEXT);

DROP POLICY IF EXISTS "orders_admins_read" ON public.orders;
CREATE POLICY "orders_admins_read" ON public.orders
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND COALESCE(p.role, 'customer') = 'admin'
  )
);

-- Profiles policies
DROP POLICY IF EXISTS "profiles_public_read" ON public.profiles;
CREATE POLICY "profiles_public_read" ON public.profiles
FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "profiles_own_update" ON public.profiles;
CREATE POLICY "profiles_own_update" ON public.profiles
FOR UPDATE USING (auth.uid() = id);

-- ============================================================================
-- STEP 5: SEED 40 HERBAL PRODUCTS
-- ============================================================================

-- Delete existing products to avoid duplicates (optional - comment out to keep existing)
-- DELETE FROM public.products;

-- Insert products if table is empty
INSERT INTO public.products (name, category, price, description, benefits, image_url, stock)
SELECT * FROM (VALUES
  ('Sukku Powder', 'Herbal Powder', 80, 'Traditional dry ginger powder (Sukku) used as a key ingredient in Siddha medicine for centuries.', 'Aids digestion, relieves cold & cough, reduces bloating.', '/assets/images/sukku-powder.svg', 50),
  ('Thippili Powder', 'Herbal Powder', 90, 'Long pepper (Piper longum) powder used for respiratory conditions in traditional medicine.', 'Relieves cough, improves lung health, enhances immunity.', '/assets/images/thippili-powder.svg', 40),
  ('Athimathuram Root', 'Herbal Root', 120, 'Liquorice root (Glycyrrhiza glabra) – a fundamental Siddha herb for throat and skin.', 'Soothes sore throat, anti-inflammatory, improves complexion.', '/assets/images/athimathuram-root.svg', 35),
  ('Nilavembu Powder', 'Herbal Powder', 70, 'Andrographis paniculata powder – the ''King of Bitters'' in Siddha medicine.', 'Boosts immunity, reduces fever, anti-viral properties.', '/assets/images/nilavembu-powder.svg', 60),
  ('Triphala Powder', 'Herbal Powder', 95, 'Time-tested blend of three fruits – Amla, Haritaki, Bibhitaki.', 'Improves digestion, detoxifies body, promotes eye health.', '/assets/images/triphala-powder.svg', 45),
  ('Thuthuvalai Powder', 'Herbal Powder', 85, 'Purple-flowered turkey berry (Solanum trilobatum) powder – essential respiratory herb.', 'Treats respiratory issues, relieves asthma, boosts immunity.', '/assets/images/thuthuvalai-powder.svg', 30),
  ('Avarampoo Powder', 'Herbal Powder', 60, 'Senna auriculata flower powder – widely used in Siddha wellness.', 'Improves skin complexion, balances blood sugar, aids digestion.', '/assets/images/avarampoo-powder.svg', 55),
  ('Nannari Root Powder', 'Herbal Root', 110, 'Indian sarsaparilla (Hemidesmus indicus) root – a cooling blood purifier.', 'Purifies blood, cools body heat, improves skin health.', '/assets/images/nannari-root.svg', 25),
  ('Ashwagandha Powder', 'Herbal Powder', 150, 'Withania somnifera – one of the most celebrated Ayurvedic adaptogenic herbs.', 'Reduces stress, boosts energy, enhances immunity.', '/assets/images/ashwagandha-powder.svg', 70),
  ('Bhringaraj Powder', 'Herbal Powder', 100, 'Eclipta alba – the king of hair herbs in Ayurvedic tradition.', 'Promotes hair growth, reduces hair fall, improves scalp health.', '/assets/images/bhringaraj-powder.svg', 40),
  ('Amla Powder', 'Herbal Powder', 75, 'Indian gooseberry – nature''s richest source of Vitamin C.', 'Boosts immunity, improves hair texture, anti-ageing.', '/assets/images/amla-powder.svg', 80),
  ('Neem Powder', 'Herbal Powder', 65, 'Azadirachta indica powder – powerful natural antiseptic.', 'Purifies blood, treats skin disorders, anti-bacterial.', '/assets/images/neem-powder.svg', 60),
  ('Tulsi Powder', 'Herbal Powder', 70, 'Holy basil (Ocimum tenuiflorum) – the queen of Ayurvedic herbs.', 'Relieves stress, improves respiratory health, anti-viral.', '/assets/images/tulsi-powder.svg', 55),
  ('Shatavari Powder', 'Herbal Powder', 130, 'Asparagus racemosus – a key wellness herb in Ayurveda.', 'Balances hormones, reduces stress, boosts immunity.', '/assets/images/shatavari-powder.svg', 30),
  ('Haritaki Powder', 'Herbal Powder', 85, 'Terminalia chebula – called the ''King of Medicine'' in Tibet.', 'Powerful digestive, detoxifies body, rejuvenating herb.', '/assets/images/haritaki-powder.svg', 45),
  ('Bringraj Hair Oil', 'Herbal Oil', 180, 'Cold-pressed Bhringaraj oil – the ultimate hair nourishment oil.', 'Promotes hair growth, prevents greying, strengthens follicles.', '/assets/images/bringraj-hair-oil.svg', 35),
  ('Neem Oil', 'Herbal Oil', 120, 'Cold-pressed virgin Neem seed oil for skin & scalp care.', 'Anti-fungal, treats dandruff, reduces skin inflammation.', '/assets/images/neem-oil.svg', 40),
  ('Sesame Hair Oil', 'Herbal Oil', 150, 'Traditional Indian sesame oil infused with herbal extracts.', 'Deeply conditions hair, prevents dandruff, relieves stress.', '/assets/images/sesame-hair-oil.svg', 50),
  ('Coconut-Brahmi Oil', 'Herbal Oil', 160, 'Pure coconut base infused with Brahmi extract for mental clarity.', 'Cools scalp, improves memory, promotes thick healthy hair.', '/assets/images/coconut-brahmi-oil.svg', 45),
  ('Castor Oil', 'Herbal Oil', 90, 'Pure cold-pressed castor oil – traditional all-purpose remedy.', 'Thickens eyebrows & lashes, gentle laxative, moisturises skin.', '/assets/images/castor-oil.svg', 60),
  ('Moringa Leaf Powder', 'Herbal Leaf', 40, 'Dried drumstick tree (Moringa) leaves – a nutritional powerhouse.', 'Rich in iron and vitamins, boosts immunity, fights malnutrition.', '/assets/images/moringa-leaf-powder.svg', 70),
  ('Dried Tulsi Leaves', 'Herbal Leaf', 50, 'Sun-dried sacred basil leaves for teas and herbal decoctions.', 'Fights infection, soothes throat irritation, stress relief.', '/assets/images/dried-tulsi-leaves.svg', 65),
  ('Black Pepper (Milagu)', 'Herbal Spice', 60, 'Sun-dried whole black pepper – ''King of Spices'' in Siddha.', 'Stimulates digestion, relieves cold, potent antioxidant.', '/assets/images/black-pepper.svg', 80),
  ('Dried Ginger (Sukku)', 'Herbal Spice', 75, 'Sun-dried whole ginger root – cornerstone of Tamil herbal medicine.', 'Relieves nausea, improves digestion, warms the body.', '/assets/images/dried-ginger.svg', 55),
  ('Cinnamon Sticks', 'Herbal Spice', 80, 'Premium Ceylon cinnamon (Cinnamomum verum) bark sticks.', 'Regulates blood sugar, anti-inflammatory, improves heart health.', '/assets/images/cinnamon-sticks.svg', 50),
  ('Cardamom Pods', 'Herbal Spice', 250, 'Green cardamom pods with intense aroma – premium Siddha spice.', 'Freshens breath, aids digestion, relieves stress and anxiety.', '/assets/images/cardamom-pods.svg', 30),
  ('Raw Turmeric Powder', 'Herbal Powder', 70, 'Pure sun-dried raw turmeric (Curcuma longa) from organic farms.', 'Powerful anti-inflammatory, boosts immunity, brightens skin.', '/assets/images/raw-turmeric-powder.svg', 90),
  ('Kumkumadi Face Oil', 'Herbal Oil', 350, 'Luxury Ayurvedic facial oil with saffron and 16 precious herbs.', 'Brightens skin, reduces dark spots, powerful anti-ageing treatment.', '/assets/images/kumkumadi-face-oil.svg', 20),
  ('Trikatu Churna', 'Herbal Powder', 100, 'Three-spice powder: ginger, black pepper, and long pepper.', 'Boosts metabolism, clears congestion, enhances digestion.', '/assets/images/trikatu-churna.svg', 40),
  ('Vetiver Root (Khus)', 'Herbal Root', 90, 'Chrysopogon zizanioides root – a cooling and calming herb.', 'Reduces body heat, calms nervous system, treats acne.', '/assets/images/vetiver-root.svg', 35),
  ('Brahmi Powder', 'Herbal Powder', 110, 'Bacopa monnieri – the premier brain tonic of Ayurveda.', 'Enhances memory, reduces anxiety, promotes healthy sleep.', '/assets/images/brahmi-powder.svg', 45),
  ('Mulethi Sticks', 'Herbal Root', 80, 'Whole dried licorice root sticks for chewing and decoctions.', 'Soothes digestive tract, relieves cough, natural sweetener.', '/assets/images/mulethi-sticks.svg', 50),
  ('Shilajit (Purified)', 'Mineral Herb', 450, 'Purified Himalayan shilajit – ancient mineral resin for vitality.', 'Powerful adaptogen, boosts energy, anti-ageing, improves vitality.', '/assets/images/shilajit.svg', 15),
  ('Guggul Tablets', 'Herbal Tablet', 200, 'Commiphora mukul resin in convenient tablet form.', 'Lowers cholesterol, reduces inflammation, supports joints.', '/assets/images/guggul-tablets.svg', 30),
  ('Aloe Vera Gel', 'Herbal Gel', 130, 'Pure cold-pressed Aloe barbadensis leaf gel.', 'Soothes sunburn, moisturises skin, aids digestion.', '/assets/images/aloe-vera-gel.svg', 55),
  ('Fenugreek Powder', 'Herbal Powder', 55, 'Dried fenugreek (Methi) seed powder – a versatile kitchen herb.', 'Controls blood sugar, promotes hair growth, aids lactation.', '/assets/images/fenugreek-powder.svg', 80),
  ('Kalmegh Powder', 'Herbal Powder', 75, 'Andrographis paniculata leaf powder – potent bitter herb.', 'Reduces fever, clears liver toxins, powerful anti-viral herb.', '/assets/images/kalmegh-powder.svg', 40),
  ('Shikakai Powder', 'Herbal Powder', 60, 'Acacia concinna pod powder – the original natural shampoo.', 'Gently cleanses scalp, promotes hair growth, conditions hair.', '/assets/images/shikakai-powder.svg', 65),
  ('Soapnut (Reetha)', 'Herbal Product', 65, 'Sapindus mukorossi – natural saponin-rich cleanser.', 'Natural shampoo, treats dandruff, gentle antifungal properties.', '/assets/images/soapnut-reetha.svg', 50),
  ('Saffron (Kesar)', 'Herbal Spice', 800, 'Pure A-grade Kashmiri Kesar saffron threads.', 'Lightens skin tone, uplifts mood, potent antioxidant and immunity booster.', '/assets/images/saffron-kesar.svg', 10)
) AS t(name, category, price, description, benefits, image_url, stock)
WHERE NOT EXISTS (SELECT 1 FROM public.products WHERE name = t.name)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 6: VERIFY SETUP
-- ============================================================================

SELECT COUNT(*) as "Total Products Seeded" FROM public.products;
SELECT COUNT(*) as "Admin Roles" FROM public.profiles WHERE role = 'admin';

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================
-- Your e-commerce database is now ready!
-- All 40 herbal products have been seeded with full schema support.
-- RLS policies are configured for public product browsing and admin management.
-- ============================================================================
