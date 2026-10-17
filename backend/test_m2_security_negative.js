/**
 * ============================================================================
 * WASEL NALUT: MILESTONE 2 NEGATIVE SECURITY & ADVERSARIAL VERIFICATION SUITE
 * ============================================================================
 * Tests strict security guards, anti-backdoor enforcement, RBAC, OTP custody,
 * administrative route protection, and field sanitization.
 * ============================================================================
 */

const http = require('http');

const TEST_PORT = process.env.TEST_PORT || process.env.PORT || 3000;

function apiRequest(method, endpoint, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const reqHeaders = {
      'Content-Type': 'application/json',
      ...headers
    };
    if (postData) {
      reqHeaders['Content-Length'] = Buffer.byteLength(postData);
    }

    const options = {
      hostname: '127.0.0.1',
      port: TEST_PORT,
      path: endpoint,
      method: method.toUpperCase(),
      headers: reqHeaders
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        let parsed = null;
        try {
          parsed = JSON.parse(data);
        } catch (_) {
          parsed = data;
        }
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: parsed
        });
      });
    });

    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

function assert(condition, message) {
  if (!condition) throw new Error(message || 'Assertion failed');
}

async function runSecuritySuite() {
  console.log('\n================================================================');
  console.log('🔒 STARTING M2 SECURITY & ANTI-BACKDOOR ADVERSARIAL TESTS');
  console.log('================================================================\n');

  // Start in-process server if not running
  const isRunning = await new Promise(resolve => {
    const probe = http.get(`http://127.0.0.1:${TEST_PORT}/health`, res => resolve(res.statusCode === 200));
    probe.on('error', () => resolve(false));
    probe.setTimeout(400, () => { probe.destroy(); resolve(false); });
  });

  if (!isRunning) {
    process.env.PORT = String(TEST_PORT);
    require('./server.js');
    await new Promise(r => setTimeout(r, 600));
  }

  // 1. Get customer and admin tokens
  const custRes = await apiRequest('POST', '/api/v1/auth/login', {
    phone: '0910000000',
    password: 'Customer@Nalut2026!Secure'
  });
  const customerToken = custRes.body?.data?.token;
  assert(customerToken, 'Customer login failed to obtain JWT');
  const custAuth = { Authorization: `Bearer ${customerToken}` };

  const admRes = await apiRequest('POST', '/api/v1/auth/login', {
    phone: '0910009832',
    password: 'Admin@Nalut2026!Secure'
  });
  const adminToken = admRes.body?.data?.token;
  assert(adminToken, 'Admin login failed to obtain JWT');
  const admAuth = { Authorization: `Bearer ${adminToken}` };

  // Create test order
  const storeRes = await apiRequest('GET', '/api/v1/stores?city=nalut');
  const store = storeRes.body?.data?.[0] || { id: 'store_nalut_ranchello' };

  const chkRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: store.id,
    items: [{ product_id: 'prod_nalut_sec_01', quantity: 1, unit_price_lyd: 20.0 }],
    delivery_address: 'نالوت - المركز الأمني',
    payment_method: 'cash_on_delivery'
  }, custAuth);
  const testOrder = chkRes.body?.data || chkRes.body;
  assert(testOrder && testOrder.id, 'Security test order checkout failed');

  let passedCount = 0;

  // TEST 1: Reject unauthenticated /status call
  try {
    const unauthStatus = await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, { status: 'accepted' });
    assert(unauthStatus.status === 401, `Expected 401 for unauthenticated /status, got ${unauthStatus.status}`);
    console.log('  ✅ [PASS] SEC-01: Rejection (401) on /orders/:id/status without Bearer token');
    passedCount++;
  } catch (e) { console.error('  ❌ [FAIL] SEC-01:', e.message); }

  // TEST 2: Reject non-admin /settle call with 403 Forbidden
  try {
    const custSettle = await apiRequest('POST', '/api/v1/drivers/driver_nalut_01/settle', { notes: 'Hack' }, custAuth);
    assert(custSettle.status === 403, `Expected 403 Forbidden for customer calling /settle, got ${custSettle.status}`);
    console.log('  ✅ [PASS] SEC-02: Rejection (403) on /drivers/:id/settle with customer token');
    passedCount++;
  } catch (e) { console.error('  ❌ [FAIL] SEC-02:', e.message); }

  // Advance order to ready_for_pickup
  await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, { status: 'accepted' }, custAuth);
  await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, { status: 'preparing' }, custAuth);
  await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, { status: 'ready_for_pickup' }, custAuth);

  // TEST 3: Reject handover with backdoor '1234' or wrong code
  try {
    const badHandover = await apiRequest('POST', `/api/v1/orders/${testOrder.id}/handover`, {
      handover_code: '1234',
      driver_id: 'driver_nalut_01'
    }, custAuth);
    assert(badHandover.status === 400, `Expected 400 for backdoor handover_code '1234', got ${badHandover.status}`);
    console.log('  ✅ [PASS] SEC-03: Rejection (400) on /handover with backdoor code "1234"');
    passedCount++;
  } catch (e) { console.error('  ❌ [FAIL] SEC-03:', e.message); }

  // Advance order to picked_up
  await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, {
    status: 'picked_up',
    driver_id: 'driver_nalut_01'
  }, custAuth);

  // TEST 4: Reject delivered status with backdoor OTP '1234'
  try {
    const backdoorOtp = await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, {
      status: 'delivered',
      driver_id: 'driver_nalut_01',
      otp_code: '1234'
    }, custAuth);
    assert(backdoorOtp.status === 400, `Expected 400 for backdoor OTP '1234', got ${backdoorOtp.status}`);
    console.log('  ✅ [PASS] SEC-04: Rejection (400) on status="delivered" with backdoor OTP "1234"');
    passedCount++;
  } catch (e) { console.error('  ❌ [FAIL] SEC-04:', e.message); }

  // TEST 5: Reject delivered status with missing OTP
  try {
    const missingOtp = await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, {
      status: 'delivered',
      driver_id: 'driver_nalut_01'
    }, custAuth);
    assert(missingOtp.status === 400, `Expected 400 for missing OTP, got ${missingOtp.status}`);
    console.log('  ✅ [PASS] SEC-05: Rejection (400) on status="delivered" with missing OTP');
    passedCount++;
  } catch (e) { console.error('  ❌ [FAIL] SEC-05:', e.message); }

  // Complete delivery with genuine OTP
  const validDeliver = await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, {
    status: 'delivered',
    driver_id: 'driver_nalut_01',
    otp_code: testOrder.otp_code
  }, custAuth);
  assert(validDeliver.status === 200, 'Valid OTP delivery failed');

  // TEST 6: Public tracking returns 404 on nonexistent order (no fallback to db.orders[0])
  try {
    const nonExistTrack = await apiRequest('GET', '/api/v1/public/track/ord_strictly_non_existent_123');
    assert(nonExistTrack.status === 404, `Expected 404 for nonexistent tracking ID, got ${nonExistTrack.status}`);
    console.log('  ✅ [PASS] SEC-06: Strict 404 on /public/track/:id for nonexistent orders (no fallback)');
    passedCount++;
  } catch (e) { console.error('  ❌ [FAIL] SEC-06:', e.message); }

  // TEST 7: Public tracking strips delivery OTP and OTP code
  try {
    const trackRes = await apiRequest('GET', `/api/v1/public/track/${testOrder.id}`);
    assert(trackRes.status === 200, 'Tracking request failed');
    const trackData = trackRes.body?.data || trackRes.body;
    assert(trackData.delivery_otp === undefined, 'Public tracking leaked delivery_otp!');
    assert(trackData.otp_code === undefined, 'Public tracking leaked otp_code!');
    console.log('  ✅ [PASS] SEC-07: Public tracking payload strips delivery_otp and otp_code credentials');
    passedCount++;
  } catch (e) { console.error('  ❌ [FAIL] SEC-07:', e.message); }

  // TEST 8: Public GET /stores strips sensitive PINs and passwords
  try {
    const storesGet = await apiRequest('GET', '/api/v1/stores');
    const storeList = storesGet.body?.data || storesGet.body || [];
    assert(storeList.length > 0, 'No stores returned');
    for (const s of storeList) {
      assert(s.pin === undefined, `Store ${s.id} leaked PIN!`);
      assert(s.password === undefined, `Store ${s.id} leaked password!`);
      assert(s.password_hash === undefined, `Store ${s.id} leaked password_hash!`);
    }
    console.log('  ✅ [PASS] SEC-08: GET /stores response strips pin, password, and password_hash');
    passedCount++;
  } catch (e) { console.error('  ❌ [FAIL] SEC-08:', e.message); }

  // TEST 9: Public GET /drivers strips sensitive PINs and passwords
  try {
    const driversGet = await apiRequest('GET', '/api/v1/drivers');
    const driverList = driversGet.body?.data || driversGet.body || [];
    assert(driverList.length > 0, 'No drivers returned');
    for (const d of driverList) {
      assert(d.pin === undefined, `Driver ${d.id} leaked PIN!`);
      assert(d.password === undefined, `Driver ${d.id} leaked password!`);
      assert(d.password_hash === undefined, `Driver ${d.id} leaked password_hash!`);
    }
    console.log('  ✅ [PASS] SEC-09: GET /drivers response strips pin, password, and password_hash');
    passedCount++;
  } catch (e) { console.error('  ❌ [FAIL] SEC-09:', e.message); }

  // TEST 10: Admin routes reject legacy PIN bypass attempts without Bearer token
  try {
    const legacyPurge = await apiRequest('POST', '/api/v1/admin/purge', { pin: '9832' });
    assert(legacyPurge.status === 401, `Expected 401 for /admin/purge with legacy PIN 9832, got ${legacyPurge.status}`);
    console.log('  ✅ [PASS] SEC-10: Legacy PIN 9832 rejected with 401 on /admin/purge (Bearer token required)');
    passedCount++;
  } catch (e) { console.error('  ❌ [FAIL] SEC-10:', e.message); }

  console.log('\n================================================================');
  console.log(`🛡️  M2 SECURITY VERIFICATION COMPLETE: ${passedCount}/10 CHECKS PASSED`);
  console.log('================================================================\n');

  if (passedCount !== 10) {
    process.exit(1);
  }
  process.exit(0);
}

runSecuritySuite().catch(err => {
  console.error('Security suite fatal error:', err);
  process.exit(1);
});
