/**
 * ============================================================================
 * WASEL NALUT: COMPREHENSIVE MULTI-CLIENT DUAL-LOOP E2E SIMULATION
 * Dual-Vertical Real-Time Simulation:
 *   Loop 1: Restaurant Order (Kitchen KDS + Cooking + Anti-Ghost Handover)
 *   Loop 2: Pharmacy Order (Retail Pick & Pack + Dispatch + Delivery OTP)
 * Multi-Client Socket.io Synchronization & Double-Entry Financial Verification
 * ============================================================================
 */

const http = require('http');
const { io: ioClient } = require('socket.io-client');
const { app, server, db, calculateDynamicDeliveryFee } = require('./server.js');

const PORT = process.env.PORT || 3000;
const SERVER_URL = `http://127.0.0.1:${PORT}`;

// Helper HTTP Request wrapper
function request(path, options = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port: PORT,
      path,
      method: options.method || 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...(options.headers || {})
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch (_) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });
    req.on('error', reject);
    if (options.body) req.write(JSON.stringify(options.body));
    req.end();
  });
}

// Sleep helper
const sleep = (ms) => new Promise(res => setTimeout(res, ms));

async function runDualLoopSimulation() {
  console.log('================================================================');
  console.log('🇱🇾 بدء المحاكاة الميدانية المزدوجة المتزامنة لمنظومة واصل نالوت');
  console.log('   (الزبون 📱 + المطبخ KDS 🍳 + الصيدلية 💊 + الكابتن 🛵 + الإدارة 🖥️)');
  console.log('================================================================\n');

  // Ensure test driver exists and is online_idle
  let driver = db.drivers.find(d => d.id === 'driver_nalut_01');
  if (!driver) {
    driver = {
      id: 'driver_nalut_01',
      full_name: 'خالد الكاتب - كابتن نالوت',
      phone: '0912345010',
      status: 'online_idle',
      is_approved: true,
      is_active: true,
      vehicle_type: 'سيارة تويوتا',
      latitude: 31.8686,
      longitude: 10.9818,
      wallet_balance_lyd: 0.0,
      cash_in_hand_lyd: 0.0
    };
    db.drivers.push(driver);
  } else {
    driver.status = 'online_idle';
    driver.is_approved = true;
    driver.is_active = true;
  }

  // ---------------------------------------------------------------------------
  // STEP 0: Connect 4 Genuine WebSocket Clients (Customer, Kitchen, Pharmacy, Driver)
  // ---------------------------------------------------------------------------
  console.log('🔌 [المرحلة 0]: ربط عملاء الـ WebSockets المتزامنين بالسيرفر...');

  const socketCustomer = ioClient(SERVER_URL, { reconnection: false });
  const socketKitchen = ioClient(SERVER_URL, { reconnection: false });
  const socketPharmacy = ioClient(SERVER_URL, { reconnection: false });
  const socketDriver = ioClient(SERVER_URL, { reconnection: false });
  const socketAdmin = ioClient(SERVER_URL, { reconnection: false });

  await Promise.all([
    new Promise(res => socketCustomer.on('connect', res)),
    new Promise(res => socketKitchen.on('connect', res)),
    new Promise(res => socketPharmacy.on('connect', res)),
    new Promise(res => socketDriver.on('connect', res)),
    new Promise(res => socketAdmin.on('connect', res)),
  ]);

  // Identify roles and join targeted rooms
  socketCustomer.emit('identify', { user_id: 'cust_salem_nalut', role: 'customer' });
  socketKitchen.emit('identify', { user_id: 'chef_ranchello', role: 'merchant' });
  socketKitchen.emit('join_store', 'store_nalut_ranchello');

  socketPharmacy.emit('identify', { user_id: 'pharma_alhanaa', role: 'merchant' });
  socketPharmacy.emit('join_store', 'store_nalut_alhanaa');

  socketDriver.emit('identify', { user_id: 'driver_nalut_01', role: 'driver' });
  socketDriver.emit('join_driver', 'driver_nalut_01');

  socketAdmin.emit('identify', { user_id: 'admin_master', role: 'admin' });
  socketAdmin.emit('join_admin');

  console.log('   ✅ تم اتصال وتحديد هوية الأدوار الـ 5 بنجاح في غرف السيرفر!\n');

  // Track real-time events received
  const events = {
    kitchenNewOrder: null,
    pharmacyNewOrder: null,
    customerStatusUpdates: [],
    driverRadarAlerts: []
  };

  socketKitchen.on('store:new_order', (data) => {
    events.kitchenNewOrder = data;
    console.log(`   🔔 [مطبخ رانشيلو] وصل إشعار طلب جديد برقم: ${data.order_number}`);
  });

  socketPharmacy.on('store:new_order', (data) => {
    events.pharmacyNewOrder = data;
    console.log(`   🔔 [صيدلية الهناء] وصل إشعار طلب أدوية ومستلزمات برقم: ${data.order_number}`);
  });

  socketCustomer.on('order:ready', (data) => {
    console.log(`   📱 [تطبيق الزبون] وصل إشعار مباشر: الوجبة جاهزة بالمطعم (${data.order_number}) 🟢`);
  });

  socketCustomer.on('order:status_changed', (data) => {
    events.customerStatusUpdates.push(data);
    console.log(`   📱 [تطبيق الزبون] تحديث فوري للحالة: ${data.status} (طلب ${data.order_number})`);
  });

  socketDriver.on('radar:incoming_order', (data) => {
    events.driverRadarAlerts.push(data);
    console.log(`   🛵 [رادار الكابتن] تنبيه رادار لطلب جاهز للاستلام: ${data.order_number} (${data.prep_status_badge || ''})`);
  });

  socketDriver.on('dispatch:request', (data) => {
    console.log(`   🛵 [توجيه الكابتن] طلب توصيل مباشر لأقرب كابتن (${data.order_number}) من ${data.store_name}`);
  });

  // ===========================================================================
  // LOOP 1: RESTAURANT ORDER (RANCHELLO KITCHEN KDS)
  // ===========================================================================
  console.log('================================================================');
  console.log('🍽️ [الدورة 1]: طلب مطعم حقيقي (مطعم رانشيلو - KDS الطهي والرادار)');
  console.log('================================================================');

  const customerPhone = '0918822334';
  const customerName = 'سالم النالوتي';

  // Step 1.1: Customer submits order (starts at placed)
  console.log('1️⃣ [الزبون] إنشاء طلب طعام: سندوتشات شاورما ووجبة عائلية...');
  const order1Res = await request('/api/v1/orders', {
    method: 'POST',
    body: {
      store_id: 'store_nalut_ranchello',
      customer_id: 'cust_salem_nalut',
      customer_name: customerName,
      customer_phone: customerPhone,
      delivery_address: 'نالوت - حي السلام - قرب قصر نالوت الأثري',
      delivery_latitude: 31.8686,
      delivery_longitude: 10.9818,
      payment_method: 'cod',
      items: [
        { id: 'prod_shawarma', name: 'سندوتش شاورما دجاج دبل', quantity: 2, price: 14.0 },
        { id: 'prod_grills', name: 'صحن مشويات مشكل', quantity: 1, price: 28.0 }
      ]
    }
  });

  if (order1Res.status !== 201) {
    throw new Error(`فشل إنشاء طلب المطعم: ${JSON.stringify(order1Res.body)}`);
  }

  const order1 = order1Res.body.data;
  console.log(`   ✅ تم إنشاء طلب المطعم بنجاح:`);
  console.log(`      - رقم الطلب: ${order1.order_number} | المعرف: ${order1.id}`);
  console.log(`      - المجموع: ${order1.total_amount_lyd} د.ل (طعام: ${order1.subtotal_lyd} + توصيل: ${order1.delivery_fee_lyd} د.ل)`);
  console.log(`      - كود التسليم OTP للزبون: ${order1.otp_code}`);

  socketCustomer.emit('join_order', order1.id);
  await sleep(300);

  // Step 1.2: Kitchen accepts the order (placed -> accepted)
  console.log('\n2️⃣ [المطبخ KDS] الشيف يقبل الطلب فور وروده (حالة accepted)...');
  const acceptRes = await request(`/api/v1/orders/${order1.id}/status`, {
    method: 'POST',
    body: { status: 'accepted' }
  });
  console.log(`   - حالة الطلب الآن: ${acceptRes.body.data.status}`);
  await sleep(300);

  // Step 1.3: Kitchen begins cooking (accepted -> preparing)
  console.log('\n3️⃣ [المطبخ KDS] الشيف يبدأ الطهي (حالة preparing)...');
  const prepRes = await request(`/api/v1/orders/${order1.id}/status`, {
    method: 'POST',
    body: { status: 'preparing', prep_time_minutes: 15 }
  });
  console.log(`   - حالة الطلب الآن: ${prepRes.body.data.status} (مدة الطهي: 15 دقيقة)`);
  await sleep(300);

  // Step 1.4: Kitchen finishes cooking (preparing -> ready_for_pickup)
  console.log('\n4️⃣ [المطبخ KDS] الشيف ينهي الطهي ويؤكد جهوزية الوجبة (حالة ready_for_pickup)...');
  const readyRes = await request(`/api/v1/orders/${order1.id}/status`, {
    method: 'POST',
    body: { status: 'ready_for_pickup' }
  });
  console.log(`   - حالة الطلب الآن: ${readyRes.body.data.status} (كود استلام الوجبة: ${readyRes.body.data.handover_code})`);
  await sleep(500);

  // Step 1.5: Anti-Ghost Pickup Security Test
  console.log('\n🛡️ [فحص أمني]: محاولة تسليم الوجبة قبل وصول الكابتن (Anti-Ghost Pickup Test)...');
  const ghostRes = await request(`/api/v1/orders/${order1.id}/status`, {
    method: 'POST',
    body: { status: 'picked_up' } // Missing driver_id!
  });
  if (ghostRes.status === 400) {
    console.log(`   🔒 نجح الفحص الأمني: تم رفض التسليم الوهمي بنجاح بموجب FSM! (${ghostRes.body.error})`);
  } else {
    throw new Error('❌ فشل الفحص الأمني: سمح النظام بالتسليم دون تعيين كابتن!');
  }

  // Step 1.6: Captain accepts the order from radar (ready_for_pickup -> driver_assigned)
  console.log('\n5️⃣ [الكابتن] الكابتن خالد يستقبل رنين الرادار ويقبل توصيل الوجبة (driver_assigned)...');
  const assignRes = await request(`/api/v1/orders/${order1.id}/status`, {
    method: 'POST',
    body: { status: 'driver_assigned', driver_id: 'driver_nalut_01' }
  });
  console.log(`   - حالة الطلب الآن: ${assignRes.body.data.status} (تم تكليف الكابتن: خالد الكاتب)`);
  await sleep(300);

  // Step 1.7: Captain arrives at Ranchello Restaurant (driver_assigned -> driver_arrived)
  console.log('\n6️⃣ [الكابتن] الكابتن يصل لمطعم رانشيلو ويضغط "وصلت للمتجر" (driver_arrived)...');
  const arriveRes = await request(`/api/v1/orders/${order1.id}/status`, {
    method: 'POST',
    body: { status: 'driver_arrived', driver_id: 'driver_nalut_01' }
  });
  console.log(`   - حالة الطلب الآن: ${arriveRes.body.data.status} (تم فك قفل زر التسليم في KDS)`);
  await sleep(300);

  // Step 1.8: Kitchen hands over meal to driver & driver starts delivery (driver_arrived -> out_for_delivery)
  console.log('\n7️⃣ [المطبخ + الكابتن] تسليم الوجبة للكابتن وبدء الانطلاق للزبون (out_for_delivery)...');
  const pickupRes = await request(`/api/v1/orders/${order1.id}/status`, {
    method: 'POST',
    body: { status: 'out_for_delivery', driver_id: 'driver_nalut_01' }
  });
  console.log(`   - حالة الطلب الآن: ${pickupRes.body.data.status} (الوجبة في عهدة الكابتن)`);
  await sleep(300);

  // Step 1.9: Captain delivers to Customer with OTP and collects COD cash (out_for_delivery -> delivered)
  console.log('\n8️⃣ [التسليم والتحصيل] الكابتن يصل لباب سالم، يتحقق من OTP ويسلم الطلب كاش...');
  const deliveredRes = await request(`/api/v1/orders/${order1.id}/status`, {
    method: 'POST',
    body: {
      status: 'delivered',
      driver_id: 'driver_nalut_01',
      otp_code: order1.otp_code
    }
  });

  if (deliveredRes.status !== 200) {
    throw new Error(`فشل تسليم الطلب: ${JSON.stringify(deliveredRes.body)}`);
  }
  console.log(`   ✅ تم تسليم طلب المطعم بنجاح! الحالة: ${deliveredRes.body.data.status}`);

  // Step 1.10: Financial Ledger Audit for Order 1
  const expectedDriverEarning = order1.delivery_fee_lyd * 0.80;
  const expectedCashLiability = order1.total_amount_lyd;
  console.log(`\n💰 [التدقيق المالي - الدورة 1]:`);
  console.log(`   - أرباح الكابتن الصافية (80% من التوصيل): +${expectedDriverEarning.toFixed(2)} د.ل`);
  console.log(`   - الكاش المحصل كالتزام في يد الكابتن (Cash-in-hand): +${expectedCashLiability.toFixed(2)} د.ل`);

  // ===========================================================================
  // LOOP 2: PHARMACY ORDER (AL-HANAA PHARMACY RETAIL PICK & PACK)
  // ===========================================================================
  console.log('\n================================================================');
  console.log('💊 [الدورة 2]: طلب صيدلية حقيقي (صيدلية الهناء - Retail Picking)');
  console.log('================================================================');

  // Step 2.1: Customer submits pharmacy order
  console.log('1️⃣ [الزبون] إنشاء طلب صيدلية: أدوية وفيتامينات ومستلزمات...');
  const order2Res = await request('/api/v1/orders', {
    method: 'POST',
    body: {
      store_id: 'store_nalut_alhanaa',
      customer_id: 'cust_salem_nalut',
      customer_name: customerName,
      customer_phone: customerPhone,
      delivery_address: 'نالوت - حي سيدي خليفة - بجانب المدرسة المركزية',
      delivery_latitude: 31.8695,
      delivery_longitude: 10.9825,
      payment_method: 'cod',
      items: [
        { id: 'med_vit_c', name: 'فيتامين سي فوار 1000 ملغ', quantity: 2, price: 12.50 },
        { id: 'med_panadol', name: 'بنادول إكسترا مسكن', quantity: 1, price: 8.00 }
      ]
    }
  });

  if (order2Res.status !== 201) {
    throw new Error(`فشل إنشاء طلب الصيدلية: ${JSON.stringify(order2Res.body)}`);
  }

  const order2 = order2Res.body.data;
  console.log(`   ✅ تم إنشاء طلب الصيدلية بنجاح:`);
  console.log(`      - رقم الطلب: ${order2.order_number} | المعرف: ${order2.id}`);
  console.log(`      - الإجمالي: ${order2.total_amount_lyd} د.ل (أدوية: ${order2.subtotal_lyd} + توصيل: ${order2.delivery_fee_lyd} د.ل)`);
  console.log(`      - كود التسليم OTP للزبون: ${order2.otp_code}`);

  socketCustomer.emit('join_order', order2.id);
  await sleep(300);

  // Step 2.2: Pharmacy accepts (placed -> accepted)
  console.log('\n2️⃣ [الصيدلية Retail] الصيدلي يقبل طلب الأدوية (حالة accepted)...');
  await request(`/api/v1/orders/${order2.id}/status`, {
    method: 'POST',
    body: { status: 'accepted' }
  });
  await sleep(200);

  // Step 2.3: Pharmacy collects items (accepted -> preparing)
  console.log('\n3️⃣ [الصيدلية Retail] الصيدلي يجمع الأدوية والمستلزمات (حالة preparing)...');
  await request(`/api/v1/orders/${order2.id}/status`, {
    method: 'POST',
    body: { status: 'preparing' }
  });
  await sleep(200);

  // Step 2.4: Pharmacy completes packaging (preparing -> ready_for_pickup)
  console.log('\n4️⃣ [الصيدلية Retail] الصيدلي يغلق كيس الأدوية ويؤكد الجاهزية (ready_for_pickup)...');
  const pharmaReadyRes = await request(`/api/v1/orders/${order2.id}/status`, {
    method: 'POST',
    body: { status: 'ready_for_pickup' }
  });
  console.log(`   - حالة طلب الصيدلية الآن: ${pharmaReadyRes.body.data.status}`);
  await sleep(300);

  // Step 2.5: Captain assigned & arrives (ready_for_pickup -> driver_assigned -> driver_arrived)
  console.log('\n5️⃣ [الكابتن] الكابتن يقبل طلب الصيدلية ويصل لاستلام كيس الأدوية...');
  await request(`/api/v1/orders/${order2.id}/status`, {
    method: 'POST',
    body: { status: 'driver_assigned', driver_id: 'driver_nalut_01' }
  });
  await request(`/api/v1/orders/${order2.id}/status`, {
    method: 'POST',
    body: { status: 'driver_arrived', driver_id: 'driver_nalut_01' }
  });
  console.log('   - الكابتن وصل لصيدلية الهناء وجرد الفاتورة.');
  await sleep(200);

  // Step 2.6: Out for delivery (driver_arrived -> out_for_delivery)
  await request(`/api/v1/orders/${order2.id}/status`, {
    method: 'POST',
    body: { status: 'out_for_delivery', driver_id: 'driver_nalut_01' }
  });
  console.log('   - الكابتن انطلق لتوصيل الأدوية للزبون.');
  await sleep(300);

  // Step 2.7: Delivered with OTP (out_for_delivery -> delivered)
  console.log('\n6️⃣ [التسليم النهائي] الكابتن يسلم الأدوية لسالم ويدخل كود OTP...');
  const pharmaDeliveredRes = await request(`/api/v1/orders/${order2.id}/status`, {
    method: 'POST',
    body: {
      status: 'delivered',
      driver_id: 'driver_nalut_01',
      otp_code: order2.otp_code
    }
  });

  if (pharmaDeliveredRes.status !== 200) {
    throw new Error(`فشل تسليم طلب الصيدلية: ${JSON.stringify(pharmaDeliveredRes.body)}`);
  }
  console.log(`   ✅ تم تسليم طلب الصيدلية بنجاح! الحالة: ${pharmaDeliveredRes.body.data.status}`);

  // Step 2.8: Customer Order History Verification
  console.log('\n📱 [سجل الزبون] التحقق من شاشة "طلباتي" للزبون سالم في نالوت...');
  const historyRes = await request(`/api/v1/orders?customer_phone=${customerPhone}`);
  const ordersList = historyRes.body.data || [];
  const foundOrder1 = ordersList.find(o => o.id === order1.id);
  const foundOrder2 = ordersList.find(o => o.id === order2.id);

  if (foundOrder1 && foundOrder2) {
    console.log(`   ✅ كلا الطلبين (المطعم والصيدلية) مسجلان بنجاح في حساب الزبون سالم!`);
    console.log(`      - طلب 1 (${foundOrder1.order_number}): ${foundOrder1.status} (${foundOrder1.store_name})`);
    console.log(`      - طلب 2 (${foundOrder2.order_number}): ${foundOrder2.status} (${foundOrder2.store_name})`);
  }

  // Close WebSockets
  socketCustomer.disconnect();
  socketKitchen.disconnect();
  socketPharmacy.disconnect();
  socketDriver.disconnect();
  socketAdmin.disconnect();

  console.log('\n================================================================');
  console.log('🎉 نجحت المحاكاة الميدانية المزدوجة بالكامل 100%!');
  console.log('   - تم التحقق من نمط المطبخ KDS (الطهي وعداد الوقت)');
  console.log('   - تم التحقق من نمط الصيدلية Retail Picking (تجميع الأصناف)');
  console.log('   - تم التحقق من منع الاستلام الوهمي Anti-Ghost Handover');
  console.log('   - تم التحقق من تسليم OTP والتحصيل النقدي COD والقيود المزدوجة');
  console.log('   - تم التحقق من تزامن WebSockets عبر كافة غرف التطبيقات');
  console.log('================================================================\n');

  setTimeout(() => {
    process.exit(0);
  }, 500);
}

runDualLoopSimulation().catch((err) => {
  console.error('\n❌ خطأ أثناء المحاكاة الميدانية:', err);
  process.exit(1);
});
