/**
 * ============================================================================
 * CHALLENGER M2-R2-2: DEEP ADVERSARIAL EDGE CASE STRESS HARNESS
 * ============================================================================
 */
const http = require('http');
const assert = require('assert');

const TEST_PORT = 3000;

function req(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const r = http.request({
      hostname: '127.0.0.1',
      port: TEST_PORT,
      path,
      method: method.toUpperCase(),
      headers: {
        'Content-Type': 'application/json',
        ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
        ...headers
      }
    }, res => {
      let b = '';
      res.on('data', c => b += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(b) }); }
        catch (_) { resolve({ status: res.statusCode, body: b }); }
      });
    });
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

async function run() {
  console.log('=== CHALLENGER M2-R2-2 INDEPENDENT ADVERSARIAL STRESS TEST ===\n');

  // 0. Ensure server running
  try {
    await req('GET', '/health');
  } catch (_) {
    require('./server.js');
    await new Promise(r => setTimeout(r, 800));
  }

  // 1. SQL Injection on Public Track
  console.log('1. Checking SQL injection on public track endpoint...');
  const sqli = await req('GET', '/api/v1/public/track/' + encodeURIComponent("' OR 1=1 --"));
  assert.strictEqual(sqli.status, 404, `SQL injection in track path should return 404, got ${sqli.status}`);
  console.log('   ✅ PASS: Encoded SQL injection returns strict 404');

  // 2. Auth & Setup Order
  console.log('2. Authenticating customer and placing test order...');
  const login = await req('POST', '/api/v1/auth/login', { phone: '0910000000', password: 'Customer@Nalut2026!Secure' });
  assert.strictEqual(login.status, 200, 'Customer login failed');
  const token = login.body.data.token;
  const auth = { Authorization: 'Bearer ' + token };

  const orderRes = await req('POST', '/api/v1/orders/checkout', {
    store_id: 'store_nalut_ranchello',
    items: [{ product_id: 'prod_nalut_pizza_01', quantity: 1, unit_price_lyd: 25.0 }],
    delivery_address: 'نالوت - الحي الشرقي',
    payment_method: 'cash_on_delivery'
  }, auth);
  assert.strictEqual(orderRes.status, 201, 'Order checkout failed');
  const order = orderRes.body.data;
  console.log(`   ✅ PASS: Order created with ID: ${order.id}, genuine OTP: ${order.otp_code}`);

  // 3. Handover Edge Cases
  console.log('3. Testing Handover code edge cases...');
  await req('POST', `/api/v1/orders/${order.id}/status`, { status: 'accepted' }, auth);
  await req('POST', `/api/v1/orders/${order.id}/status`, { status: 'preparing' }, auth);
  await req('POST', `/api/v1/orders/${order.id}/status`, { status: 'ready_for_pickup' }, auth);

  // Re-fetch order to get assigned handover_code
  const orderReadyRes = await req('GET', `/api/v1/orders?id=${order.id}`, null, auth);
  const readyOrder = orderReadyRes.body.data[0];
  const expectedHandover = readyOrder.handover_code;
  console.log(`   Assigned handover code: ${expectedHandover}`);

  const badHandoverPayloads = [
    { handover_code: 1234 },
    { handover_code: true },
    { handover_code: false },
    { handover_code: null },
    { handover_code: {} },
    { handover_code: [] },
    { handover_code: '1234' },
    { handover_code: '0000' },
    { handover_code: ' ' + expectedHandover + 'X' }
  ];

  for (const p of badHandoverPayloads) {
    const res = await req('POST', `/api/v1/orders/${order.id}/handover`, { ...p, driver_id: 'driver_nalut_01' }, auth);
    assert.strictEqual(res.status, 400, `Expected 400 for bad handover payload ${JSON.stringify(p)}, got ${res.status}`);
  }
  console.log('   ✅ PASS: All 9 adversarial handover edge cases rejected with 400');

  // Legitimate handover
  const goodHandover = await req('POST', `/api/v1/orders/${order.id}/handover`, {
    handover_code: expectedHandover,
    driver_id: 'driver_nalut_01'
  }, auth);
  assert.strictEqual(goodHandover.status, 200, 'Legitimate handover failed');
  console.log('   ✅ PASS: Legitimate handover accepted');

  // 4. Delivery OTP Edge Cases
  console.log('4. Testing Delivery OTP edge cases...');
  const badOtpPayloads = [
    { otp_code: 1234 },
    { otp_code: true },
    { otp_code: false },
    { otp_code: null },
    { otp_code: {} },
    { otp_code: [] },
    { otp_code: '1234' },
    { otp_code: '0000' },
    { otp_code: '   ' },
    { otp_code: order.otp_code + '1' }
  ];

  for (const p of badOtpPayloads) {
    const res = await req('POST', `/api/v1/orders/${order.id}/status`, {
      status: 'delivered',
      driver_id: 'driver_nalut_01',
      ...p
    }, auth);
    assert.strictEqual(res.status, 400, `Expected 400 for bad OTP payload ${JSON.stringify(p)}, got ${res.status}`);
  }
  console.log('   ✅ PASS: All 10 adversarial delivery OTP edge cases rejected with 400');

  // Verify order status is still out_for_delivery
  const checkStatus = await req('GET', `/api/v1/orders?id=${order.id}`, null, auth);
  assert.strictEqual(checkStatus.body.data[0].status, 'out_for_delivery', 'Order status was corrupted by failed OTP attempts');
  console.log('   ✅ PASS: Order status unchanged (still out_for_delivery)');

  // Genuine OTP delivery
  const goodDelivery = await req('POST', `/api/v1/orders/${order.id}/status`, {
    status: 'delivered',
    driver_id: 'driver_nalut_01',
    otp_code: order.otp_code
  }, auth);
  assert.strictEqual(goodDelivery.status, 200, 'Legitimate delivery with OTP failed');
  console.log('   ✅ PASS: Legitimate delivery with genuine OTP succeeded');

  // 5. Public Track Data Sanitization
  console.log('5. Testing Public Tracking data isolation on delivered order...');
  const track = await req('GET', `/api/v1/public/track/${order.id}`);
  assert.strictEqual(track.status, 200, 'Public track request failed');
  const td = track.body.data;
  assert.strictEqual(td.otp_code, undefined, 'otp_code leaked in public track!');
  assert.strictEqual(td.delivery_otp, undefined, 'delivery_otp leaked in public track!');
  assert.strictEqual(td.handover_code, undefined, 'handover_code leaked in public track!');
  if (td.driver) {
    assert.strictEqual(td.driver.pin, undefined, 'Driver pin leaked!');
    assert.strictEqual(td.driver.password, undefined, 'Driver password leaked!');
    assert.strictEqual(td.driver.balance, undefined, 'Driver balance leaked!');
  }
  if (td.store) {
    assert.strictEqual(td.store.pin, undefined, 'Store pin leaked!');
    assert.strictEqual(td.store.password, undefined, 'Store password leaked!');
    assert.strictEqual(td.store.commission, undefined, 'Store commission leaked!');
  }
  console.log('   ✅ PASS: Public tracking completely sanitized (zero secrets leaked)');

  console.log('\n================================================================');
  console.log('🎉 ALL INDEPENDENT ADVERSARIAL STRESS CHECKS PASSED EMPIRICALLY!');
  console.log('================================================================');
  process.exit(0);
}

run().catch(err => {
  console.error('\n❌ STRESS TEST FAILED:', err);
  process.exit(1);
});
