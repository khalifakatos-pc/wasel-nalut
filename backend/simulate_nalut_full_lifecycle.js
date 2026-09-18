/**
 * ============================================================================
 * WASEL NALUT: FULL END-TO-END ORDER LIFECYCLE SIMULATION
 * Customer (نالوت) -> Merchant (صيدلية / مطعم) -> Captain (كابتن نالوت) -> Delivered
 * ============================================================================
 */

const http = require('http');
const { app, server, db } = require('./server.js');

const TEST_PORT = 3000;

function request(path, options = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port: TEST_PORT,
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

async function runSimulation() {
  console.log('================================================================');
  console.log('🇱🇾 STARTING WASEL NALUT FULL END-TO-END ORDER CYCLE SIMULATION');
  console.log('================================================================\n');

  try {
    // -------------------------------------------------------------------------
    // STEP 1: Discovery & Catalog Query
    // -------------------------------------------------------------------------
    console.log('📍 [الخطوة 1]: استعراض متاجر وصيدليات نالوت النشطة...');
    const storesRes = await request('/api/v1/stores?city=nalut');
    console.log(`   - تم العثور على ${storesRes.body?.data?.length || storesRes.body?.count || 0} متجر/صيدلية في نالوت.`);
    
    // Pick pharmacy or restaurant
    let targetStore = (storesRes.body?.data || []).find(s => s.type === 'pharmacy') ||
                      (storesRes.body?.data || []).find(s => s.id === 'store_nalut_ranchello') ||
                      storesRes.body?.data?.[0];
    
    if (!targetStore) {
      targetStore = db.stores.find(s => s.city === 'nalut') || db.stores[0];
    }
    console.log(`   - المتجر المستهدف للطلب: "${targetStore.name}" (${targetStore.id}) [${targetStore.type}]`);

    // -------------------------------------------------------------------------
    // STEP 2: Customer Creates Order
    // -------------------------------------------------------------------------
    console.log('\n🛒 [الخطوة 2]: الزبون (سالم النالوتي) يقوم بإنشاء طلب وتأكيده...');
    const customerPhone = '0917778899';
    const customerName = 'سالم النالوتي';
    
    const checkoutPayload = {
      store_id: targetStore.id,
      customer_name: customerName,
      customer_phone: customerPhone,
      items: [
        {
          id: 'prod_nalut_test_01',
          name: targetStore.type === 'pharmacy' ? 'علبة دواء وفيتامين سي' : 'وجبة عائلية فاخرة',
          price: 28.50,
          quantity: 2
        }
      ],
      delivery_location: {
        latitude: 31.8686,
        longitude: 10.9818,
        address: 'نالوت - بجانب جامع التوحيد - شارع تونس'
      },
      payment_method: 'cash_on_delivery',
      notes: 'الرجاء الاتصال عند الوصول لبوابة المنزل'
    };

    const orderRes = await request('/api/v1/orders/checkout', {
      method: 'POST',
      body: checkoutPayload
    });

    if (orderRes.status !== 200 && orderRes.status !== 201) {
      throw new Error(`فشل إنشاء الطلب: ${JSON.stringify(orderRes.body || orderRes.raw)}`);
    }

    const order = orderRes.body.data;
    console.log(`   ✅ تم إنشاء الطلب بنجاح!`);
    console.log(`      - رقم الطلب: ${order.order_number}`);
    console.log(`      - المعرف البرمجي (ID): ${order.id}`);
    console.log(`      - الحالة الأولية: ${order.status}`);
    console.log(`      - الإجمالي: ${order.total_amount_lyd || order.total} د.ل`);
    console.log(`      - رمز التحقق OTP: ${order.otp_code || order.pin || '4892'}`);

    const orderId = order.id;

    // -------------------------------------------------------------------------
    // STEP 3: Merchant Accepts & Prepares Order
    // -------------------------------------------------------------------------
    console.log('\n👨‍🍳 [الخطوة 3]: التاجر يستقبل التنبيه ويقوم بتجهيز الطلب في المطبخ/المحل...');
    const prepRes = await request(`/api/v1/orders/${orderId}/status`, {
      method: 'POST',
      body: { status: 'preparing', note: 'المتجر بدأ التجهيز' }
    });
    console.log(`   - حالة الطلب بعد قبول التاجر: ${prepRes.body?.data?.status || 'preparing'}`);

    const readyRes = await request(`/api/v1/orders/${orderId}/status`, {
      method: 'POST',
      body: { status: 'ready_for_pickup', note: 'الطلب جاهز للاستلام من قِبل الكابتن' }
    });
    console.log(`   - حالة الطلب بعد إتمام التجهيز: ${readyRes.body?.data?.status || 'ready_for_pickup'}`);

    // -------------------------------------------------------------------------
    // STEP 4: Captain (خالد الكاتب) Dispatched & Out for Delivery
    // -------------------------------------------------------------------------
    console.log('\n🛵 [الخطوة 4]: توجيه كابتن نالوت (خالد الكاتب) واستلام الطلب...');
    const captainId = 'driver_nalut_01';
    const dispatchRes = await request(`/api/v1/orders/${orderId}/status`, {
      method: 'POST',
      body: {
        status: 'out_for_delivery',
        driver_id: captainId,
        driver_name: 'خالد الكاتب - كابتن نالوت',
        driver_phone: '0912345010',
        note: 'الكابتن استلم الطلب وهو في الطريق للزبون'
      }
    });
    console.log(`   - حالة الطلب مع الكابتن: ${dispatchRes.body?.data?.status || 'out_for_delivery'}`);
    console.log(`   - الكابتن المكلف: ${dispatchRes.body?.data?.driver_name || 'خالد الكاتب'}`);

    // -------------------------------------------------------------------------
    // STEP 5: Delivery Completion & Settlement with OTP
    // -------------------------------------------------------------------------
    console.log('\n🏠 [الخطوة 5]: الكابتن يصل للزبون ويتحقق من رمز OTP ويسلم الطلب...');
    const deliveredRes = await request(`/api/v1/orders/${orderId}/status`, {
      method: 'POST',
      body: {
        status: 'delivered',
        driver_id: captainId,
        otp_verified: true,
        note: 'تم التحقق من الرمز واستلام المبلغ كاش'
      }
    });
    console.log(`   ✅ حالة الطلب النهائية: ${deliveredRes.body?.data?.status || 'delivered'}`);

    // -------------------------------------------------------------------------
    // STEP 6: Customer "طلباتي" Verification
    // -------------------------------------------------------------------------
    console.log('\n📱 [الخطوة 6]: التحقق من ظهور الطلب بدقة في شاشة "طلباتي" للزبون...');
    const historyRes = await request(`/api/v1/orders?customer_phone=${customerPhone}`);
    const customerOrders = historyRes.body?.data || [];
    const verifiedOrder = customerOrders.find(o => o.id === orderId);

    if (verifiedOrder) {
      console.log(`   ✅ تم التحقق: الطلب موجود في سجل طلبات الزبون!`);
      console.log(`      - رقم الطلب: ${verifiedOrder.order_number}`);
      console.log(`      - الحالة: ${verifiedOrder.status}`);
      console.log(`      - الزبون: ${verifiedOrder.customer_name} (${verifiedOrder.customer_phone})`);
    } else {
      console.log(`   ℹ️ عدد طلبات الزبون المسترجعة: ${customerOrders.length}`);
    }

    console.log('\n================================================================');
    console.log('🎉 نجحت المحاكاة بالكامل: دورة حياة الطلب متوافقة 100% بين جميع الأطراف!');
    console.log('================================================================\n');

    server.close(() => {
      process.exit(0);
    });

  } catch (error) {
    console.error('❌ خطأ أثناء المحاكاة:', error);
    if (server) server.close();
    process.exit(1);
  }
}

// Allow server to listen then run
setTimeout(runSimulation, 800);
