-- ==============================================================================
-- WASEL SUPER-APP NALUT (واصل نالوت)
-- INSERT OFFICIAL PARTNER STORES & PRODUCTS INTO SUPABASE CLOUD
-- ==============================================================================

-- 1. Enable public read and insert access (RLS Policies)
ALTER TABLE IF EXISTS public.stores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read stores" ON public.stores;
CREATE POLICY "Allow public read stores" ON public.stores FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public insert stores" ON public.stores;
CREATE POLICY "Allow public insert stores" ON public.stores FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public update stores" ON public.stores;
CREATE POLICY "Allow public update stores" ON public.stores FOR UPDATE USING (true);

ALTER TABLE IF EXISTS public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read products" ON public.products;
CREATE POLICY "Allow public read products" ON public.products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public insert products" ON public.products;
CREATE POLICY "Allow public insert products" ON public.products FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public update products" ON public.products;
CREATE POLICY "Allow public update products" ON public.products FOR UPDATE USING (true);

-- 2. Insert the 4 Real Nalut Partner Stores
INSERT INTO public.stores (
  id, name, name_en, type, rating, review_count, 
  delivery_time_min, delivery_time_max, min_order_lyd, base_delivery_fee_lyd, 
  latitude, longitude, city, district, logo_url, banner_url, is_open, is_featured
) VALUES
(
  'store_nalut_alhanaa',
  'صيدلية الهناء',
  'Al-Hanaa Pharmacy',
  'pharmacy',
  4.9,
  94,
  15,
  30,
  10.00,
  5.00,
  31.877755,
  10.978004,
  'nalut',
  'مقابل جزيرة مصرف الجمهورية، نالوت',
  'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1576602976047-174e57a47881?auto=format&fit=crop&w=800&q=80',
  true,
  true
),
(
  'store_nalut_ranchello',
  'مطعم ومقهى رانشيلو',
  'Ranchello Restaurant & Cafe',
  'restaurant',
  4.8,
  165,
  25,
  45,
  15.00,
  5.00,
  31.862130,
  10.986878,
  'nalut',
  'شارع أفريقيا، نالوت',
  'https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80',
  true,
  true
),
(
  'store_nalut_akakus',
  'بيتزا أكاكوس',
  'Pizza Akakus',
  'restaurant',
  4.7,
  142,
  20,
  35,
  15.00,
  5.00,
  31.881501,
  10.975753,
  'nalut',
  'شارع تونس، نالوت',
  'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1579751626657-72bc17010498?auto=format&fit=crop&w=800&q=80',
  true,
  true
),
(
  'store_nalut_rixos',
  'ريكسوس للتسوق',
  'Rixos Shopping Market',
  'grocery',
  4.8,
  210,
  30,
  50,
  20.00,
  5.00,
  31.892879,
  10.965377,
  'nalut',
  'المدخل الرئيسي - نالوت',
  'https://images.unsplash.com/photo-1578916171728-46686eac8d58?auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=800&q=80',
  true,
  true
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  name_en = EXCLUDED.name_en,
  type = EXCLUDED.type,
  district = EXCLUDED.district,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  is_open = EXCLUDED.is_open,
  is_featured = EXCLUDED.is_featured;

-- 3. Insert Authentic Products for the Stores
INSERT INTO public.products (id, store_id, name_ar, price_lyd, desc_ar, in_stock, is_popular, unit)
VALUES
  -- صيدلية الهناء
  ('prod_alhanaa_01', 'store_nalut_alhanaa', 'بنادول إكسترا أحمر (24 قرص)', 5.00, 'مسكن للصداع والآلام وخافض حرارة سريع المفعول', true, true, 'علبة'),
  ('prod_alhanaa_02', 'store_nalut_alhanaa', 'فيتامين سي فوار 1000 مجم بنكهة البرتقال', 12.00, 'فوار لتقوية المناعة ومقاومة نزلات البرد', true, true, 'أنبوب'),
  ('prod_alhanaa_03', 'store_nalut_alhanaa', 'غسول سيرافي للبشرة العادية والجافة (236 مل)', 65.00, 'CeraVe Hydrating Cleanser منظف ومرطب للبشرة بحمض الهيالورونيك والسيراميد', true, true, 'عبوة'),
  ('prod_alhanaa_04', 'store_nalut_alhanaa', 'كريم ديرميديك واقي شمس طبي SPF 50+', 58.00, 'Dermedic Sun Protection حماية فائقة من أشعة الشمس للبشرة الحساسة', true, false, 'أنبوب'),
  ('prod_alhanaa_05', 'store_nalut_alhanaa', 'بخاخ أوتريفين للأنف للكبار (Otrivin 0.1%)', 8.50, 'مزيل لاحتقان الأنف ومساعد على التنفس السريع', true, true, 'بخاخ'),
  ('prod_alhanaa_06', 'store_nalut_alhanaa', 'حقيبة إسعافات أولية منزلية متكاملة', 35.00, 'تحتوي على شاش معقم، لاصقات جروح، مطهر بيتادين، قطن طبي، ومقص طبي', true, false, 'حقيبة'),

  -- مطعم رانشيلو (نالوت - 33 صنف حقيقي من شاشات الكاشير)
  ('prod_ranchello_box_big', 'store_nalut_ranchello', 'بوكس كبير', 140.00, 'بوكس رانشيلو الحجم الكبير المناسب للعزائم والجمعات العائلية', true, true, 'بوكس'),
  ('prod_ranchello_meal_family', 'store_nalut_ranchello', 'وجبة عائلية', 60.00, 'وجبة مشويات ودجاج تكفي العائلة مع مقبلات وسلطات وبطاطا', true, true, 'وجبة'),
  ('prod_ranchello_family_box', 'store_nalut_ranchello', 'فاميلي بوكس', 40.00, 'بوكس عائلي مميز بتشكيلة سندوتشات وسناكس وبطاطا مقلية', true, true, 'بوكس'),
  ('prod_ranchello_family_mix_box', 'store_nalut_ranchello', 'بوكس عائلي مشكل', 40.00, 'تشكيلة مشاوي مشكلة وسندوتشات عائلية مع الصوصات', true, true, 'بوكس'),
  ('prod_ranchello_box_shish', 'store_nalut_ranchello', 'بوكس شيش', 32.00, 'بوكس شيش طاووق فاخر مع بطاطا وخبز صاج وثومية رانشيلو', true, true, 'بوكس'),
  ('prod_ranchello_happiness_cheese', 'store_nalut_ranchello', 'بوكس السعادة بالجبنة', 31.00, 'بوكس السعادة المميز مغطى بجبنة شيدر وموزاريلا ذائبة ومقرمشات', true, true, 'بوكس'),
  ('prod_ranchello_happiness_box', 'store_nalut_ranchello', 'بوكس السعادة', 29.00, 'بوكس السعادة الكلاسيكي المفضل لزبائن رانشيلو مع الصوصات الخاصة', true, true, 'بوكس'),
  ('prod_ranchello_meal_chicken_full', 'store_nalut_ranchello', 'وجبة دجاجة كاملة', 45.00, 'دجاجة كاملة مشوية على الفحم مع الأرز والبطاطا والسلطة', true, true, 'وجبة'),
  ('prod_ranchello_meal_half_chicken', 'store_nalut_ranchello', 'وجبة نص دجاجة', 25.00, 'نصف دجاجة مشوية متبلة تقدم مع الأرز والبطاطا والمقبلات', true, true, 'وجبة'),
  ('prod_ranchello_meal_mix', 'store_nalut_ranchello', 'وجبة مشكلة', 23.00, 'تشكيلة مشاوي رانشيلو المشكلة مع الأرز والخبز والصوصات', true, true, 'وجبة'),
  ('prod_ranchello_meal_shish_tawook', 'store_nalut_ranchello', 'وجبة شيش طاووق', 22.00, 'أسياخ شيش طاووق صدور دجاج متبلة مع بطاطا وثومية وخبز صاج', true, true, 'وجبة'),
  ('prod_ranchello_meal_shawarma', 'store_nalut_ranchello', 'وجبة شاورما', 22.00, 'وجبة شاورما عربي مقطعة مع بطاطا مقلية وثومية ومخللات', true, true, 'وجبة'),
  ('prod_ranchello_meal_kebab', 'store_nalut_ranchello', 'وجبة كباب', 21.00, 'وجبة كباب لحم مشوي على الفحم تقدم مع الأرز والسلطة المشوية', true, true, 'وجبة'),
  ('prod_ranchello_half_chicken_plain', 'store_nalut_ranchello', 'نص دجاجة حاف', 15.00, 'نصف دجاجة مشوية حاف بدون أرز أو إضافات جانبية', true, false, 'وجبة'),
  ('prod_ranchello_scallop_fatira_big', 'store_nalut_ranchello', 'سكالوب فطيرة كبير', 23.00, 'سكالوب دجاج مقرمش في خبز الفطيرة الليبية الطازجة بالحجم الكبير', true, true, 'فطيرة'),
  ('prod_ranchello_scallop_fatira_small', 'store_nalut_ranchello', 'سكالوب فطيرة صغير', 19.00, 'سكالوب دجاج في خبز الفطيرة الليبية الساخنة بحجم فردي', true, true, 'فطيرة'),
  ('prod_ranchello_shawarma_double', 'store_nalut_ranchello', 'شاورما دبل', 18.00, 'سندوتش شاورما بحجم مضاعف وإضافات غنية', true, true, 'سندوتش'),
  ('prod_ranchello_scallop_regular', 'store_nalut_ranchello', 'سكالوب', 16.00, 'سندوتش سكالوب دجاج مقرمش كلاسيكي مع البطاطا والسلطات', true, true, 'سندوتش'),
  ('prod_ranchello_burger_double', 'store_nalut_ranchello', 'همبورغر دبل', 16.00, 'همبورغر قطعتين لحم طازج مع شرائح الجبن والخس وصوص البرجر', true, true, 'سندوتش'),
  ('prod_ranchello_fajita_regular', 'store_nalut_ranchello', 'فاهيتا عادية', 12.00, 'سندوتش فاهيتا دجاج متبلة مع الفلفل الرومي والبصل والبهارات', true, false, 'سندوتش'),
  ('prod_ranchello_shish_cheese', 'store_nalut_ranchello', 'شيش بالجبنة', 12.00, 'سندوتش شيش طاووق مع جبنة موزاريلا ذائبة', true, true, 'سندوتش'),
  ('prod_ranchello_scallop_manwi', 'store_nalut_ranchello', 'سكالوب مانوي', 11.00, 'سندوتش سكالوب دجاج خفيف مع صوص المايونيز والماسترد', true, false, 'سندوتش'),
  ('prod_ranchello_shawarma_cheese', 'store_nalut_ranchello', 'شاورما بالجبنة', 11.00, 'سندوتش شاورما دجاج مع جبنة ذائبة وثومية', true, true, 'سندوتش'),
  ('prod_ranchello_diwan_regular', 'store_nalut_ranchello', 'ديوان عادي', 11.00, 'سندوتش ديوان رانشيلو المتبل الشهير', true, false, 'سندوتش'),
  ('prod_ranchello_shawarma_regular', 'store_nalut_ranchello', 'شاورما', 10.00, 'سندوتش شاورما دجاج كلاسيك بالثومية والمخلل والبطاطا', true, true, 'سندوتش'),
  ('prod_ranchello_burger_regular', 'store_nalut_ranchello', 'همبورغر عادية', 9.00, 'همبورغر لحم فردي كلاسيكي مع الطماطم والخس والمايونيز', true, true, 'سندوتش'),
  ('prod_ranchello_burger_chicken', 'store_nalut_ranchello', 'همبورغر دجاج', 8.00, 'برجر صدر دجاج مقرمش مع صوص المايونيز والخس', true, true, 'سندوتش'),
  ('prod_ranchello_eggs_cheese', 'store_nalut_ranchello', 'دحي بالجبنة', 4.00, 'سندوتش بيض مقلي بالجبنة الطازجة', true, false, 'سندوتش'),
  ('prod_ranchello_plate_kebab', 'store_nalut_ranchello', 'كباب صحن', 18.00, 'صحن كباب لحم مشوي على الفحم مع الطماطم والفلفل المشوي والخبز', true, true, 'صحن'),
  ('prod_ranchello_shish_rice', 'store_nalut_ranchello', 'شيش أرز', 17.00, 'قطع شيش طاووق متبلة فوق طبق الأرز البسمتي المفلفل', true, true, 'صحن'),
  ('prod_ranchello_rice_fries_plate', 'store_nalut_ranchello', 'صحن رز وبطاطا', 15.00, 'صحن أرز بالخلطة مع بطاطا مقلية مقرمشة', true, false, 'صحن'),
  ('prod_ranchello_plate_shish', 'store_nalut_ranchello', 'شيش صحن', 13.00, 'صحن شيش طاووق مفرد مع الصوص والسلطات والخبز', true, true, 'صحن'),
  ('prod_ranchello_lentil_soup', 'store_nalut_ranchello', 'شوربة عدس', 5.00, 'شوربة عدس دافئة ومغذية مع الخبز المحمص والليمون', true, true, 'صحن'),

  -- بيتزا أكاكوس
  ('prod_akakus_01', 'store_nalut_akakus', 'بيتزا أكاكوس الخاصة (حجم كبير)', 30.00, 'صلصة إيطالية خاصة، دجاج، لحم مفروم، فطر، زيتون، وجبنة موزاريلا غنية', true, true, 'بيتزا'),
  ('prod_akakus_02', 'store_nalut_akakus', 'بيتزا تونة ليبية بالزيتون الأسود', 24.00, 'تونة فاخرة، بصل مكرمل، فلفل أخضر، زيتون أسود، وجبنة موزاريلا', true, true, 'بيتزا'),
  ('prod_akakus_03', 'store_nalut_akakus', 'بيتزا باربيكيو تشيكن', 26.00, 'قطع صدر دجاج متبلة بصوص الباربيكيو المدخن مع الموزاريلا', true, false, 'بيتزا'),
  ('prod_akakus_04', 'store_nalut_akakus', 'بيتزا مارغريتا كلاسيك', 20.00, 'صلصة الطماطم الإيطالية، ريحان طازج، وجبنة موزاريلا أصيلة', true, true, 'بيتزا'),
  ('prod_akakus_05', 'store_nalut_akakus', 'أصابع جبنة الموزاريلا المقلية (5 قطع)', 12.00, 'أصابع موزاريلا مقرمشة وذابحة مع صلصة المارينارا الإيطالية', true, false, 'علبة'),
  ('prod_akakus_06', 'store_nalut_akakus', 'كالزوني إيطالي محشي لحم وجبن', 18.00, 'فطيرة كالزوني مخبوزة على الحجر محشية لحم مفروم وجبنة موزاريلا وصلصة', true, false, 'قطعة'),

  -- ريكسوس للتسوق
  ('prod_rixos_01', 'store_nalut_rixos', 'زيت زيتون جبل نفوسة البكر الممتاز (قارورة 1 لتر)', 25.00, 'زيت زيتون طبيعي معصور على البارد من مزارع الجبل بنالوت', true, true, 'قارورة'),
  ('prod_rixos_02', 'store_nalut_rixos', 'كرتونة حليب المعمورة كامل الدسم (12 عبوة × 1 لتر)', 45.00, 'حليب معقم ومبستر كامل الدسم عالي الجودة لجميع أفراد الأسرة', true, true, 'كرتونة'),
  ('prod_rixos_03', 'store_nalut_rixos', 'طماطم معجون البستان (باكيت 10 علب)', 22.00, 'معجون طماطم مركز للمأكولات الليبية التقليدية', true, true, 'باكيت'),
  ('prod_rixos_04', 'store_nalut_rixos', 'سكر الأسرة ناعم (كيس 5 كجم)', 18.50, 'سكر أبيض نقي ومصفى عالي الجودة', true, false, 'كيس'),
  ('prod_rixos_05', 'store_nalut_rixos', 'مكرونة ليبية مشكلة (باكت 10 أكياس)', 17.50, 'تشكيلة مكرونة خرز وريشة وسباغيتي من القمح الصلب', true, true, 'باكيت'),
  ('prod_rixos_06', 'store_nalut_rixos', 'باكيت مياه نالوت المعدنية النقية (6 قوارير × 1.5 لتر)', 6.50, 'مياه شرب طبيعية نقية ومعقمة من ينابيع الجبل', true, true, 'باكيت'),
  ('prod_rixos_07', 'store_nalut_rixos', 'مسحوق غسيل أوتوماتيك أومو (3 كجم)', 26.00, 'تنظيف قوي وإزالة أصعب البقع برائحة الانتعاش', true, false, 'كيس')
ON CONFLICT (id) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  price_lyd = EXCLUDED.price_lyd,
  desc_ar = EXCLUDED.desc_ar,
  in_stock = EXCLUDED.in_stock,
  is_popular = EXCLUDED.is_popular,
  unit = EXCLUDED.unit;
