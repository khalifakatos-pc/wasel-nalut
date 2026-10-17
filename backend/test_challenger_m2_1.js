/**
 * ============================================================================
 * WASEL NALUT: CHALLENGER M2-1 ADVERSARIAL PENETRATION HARNESS
 * ============================================================================
 * Comprehensive empirical challenge and penetration test suite for Milestone 2:
 * 1. Penetration attempt with backdoor PINs/passwords (1234, Password123!,
 *    Admin123!, 7788, 9832) on login routes.
 * 2. Penetration attempt with query parameters (?admin_key=7788, ?admin_key=9832)
 *    and header (x-admin-key: 7788, x-admin-key: 9832) on admin endpoints.
 * 3. Administrative operations RBAC stress-testing (/admin/purge, /admin/seed,
 *    /stores, /drivers, /settle) under no token, malformed token, customer token,
 *    and driver token.
 * 4. Forensic credential sanitization check (GET /stores, GET /drivers must not leak
 *    pin, password, or password_hash).
 * 5. Handover code and delivery OTP anti-bypass verification.
 * 6. Adversarial mutator injections and unguarded route analysis.
 * ============================================================================
 */

const http = require('http');
const jwt = require('jsonwebtoken');
const { config } = require('./config');

const TEST_PORT = process.env.TEST_PORT || process.env.PORT || 3000;
const JWT_SECRET = config.JWT_SECRET;

let ipCounter = 1;
function apiRequest(method, endpoint, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const reqHeaders = {
      'Content-Type': 'application/json',
      'x-forwarded-for': `10.42.0.${ipCounter++}`,
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

const BACKDOOR_CREDENTIALS = ['1234', 'Password123!', 'Admin123!', '7788', '9832'];

const results = {
  total: 0,
  passed: 0,
  failed: 0,
  vulnerabilities: []
};

function recordTest(suite, name, passed, details = '') {
  results.total++;
  if (passed) {
    results.passed++;
    console.log(`  ✅ [PASS] [${suite}] ${name}`);
  } else {
    results.failed++;
    results.vulnerabilities.push({ suite, name, details });
    console.log(`  ❌ [VULNERABILITY] [${suite}] ${name}: ${details}`);
  }
}

async function ensureServerRunning() {
  const isRunning = await new Promise(resolve => {
    const probe = http.get(`http://127.0.0.1:${TEST_PORT}/health`, res => resolve(res.statusCode === 200));
    probe.on('error', () => resolve(false));
    probe.setTimeout(400, () => { probe.destroy(); resolve(false); });
  });

  if (!isRunning) {
    console.log(`[Harness] Starting in-process backend server on port ${TEST_PORT}...`);
    process.env.PORT = String(TEST_PORT);
    require('./server.js');
    await new Promise(r => setTimeout(r, 800));
  }
}

async function runPenetrationSuite() {
  console.log('================================================================');
  console.log('⚔️  WASEL NALUT: EMPIRICAL CHALLENGER M2-1 PENETRATION HARNESS');
  console.log('================================================================\n');

  await ensureServerRunning();

  // Create valid tokens using official JWT_SECRET for RBAC tests
  const customerUser = { id: 'usr_guest_nalut', phone: '0910000000', role: 'customer', city: 'nalut' };
  const driverUser = { id: 'user_driver_01', phone: '0912345678', role: 'driver', city: 'nalut' };
  const adminUser = { id: 'admin_master', phone: '0910009832', role: 'admin', city: 'nalut' };

  const validCustomerToken = jwt.sign(customerUser, JWT_SECRET, { expiresIn: '1h' });
  const validDriverToken = jwt.sign(driverUser, JWT_SECRET, { expiresIn: '1h' });
  const validAdminToken = jwt.sign(adminUser, JWT_SECRET, { expiresIn: '1h' });
  const malformedToken = 'Bearer invalid.malformed.jwt.token.string';

  const custAuth = { Authorization: `Bearer ${validCustomerToken}` };
  const driverAuth = { Authorization: `Bearer ${validDriverToken}` };
  const adminAuth = { Authorization: `Bearer ${validAdminToken}` };
  const malformedAuth = { Authorization: malformedToken };

  // ==========================================================================
  // SUITE 1: PENETRATION ATTEMPTS WITH BACKDOOR PINS/PASSWORDS ON LOGIN ROUTES
  // ==========================================================================
  console.log('\n--- SUITE 1: Backdoor PINs & Passwords on Login Routes ---');

  // Register a dedicated user with a distinct strong password to test customer auth
  const strongPasswordCust = 'WaselStrongSec#2026';
  const testCustPhone = '0919998877';
  await apiRequest('POST', '/api/v1/auth/register', {
    full_name: 'زبون تجريبي أمني',
    phone: testCustPhone,
    password: strongPasswordCust
  });

  // 1.1 Customer login with backdoor passwords against dedicated customer
  for (const backdoor of BACKDOOR_CREDENTIALS) {
    const res = await apiRequest('POST', '/api/v1/auth/login', {
      phone: testCustPhone,
      password: backdoor
    });
    const isRejected = res.status === 401;
    recordTest('SUITE-1.1-CUSTOMER', `Login with backdoor "${backdoor}" on registered customer`, isRejected,
      `Expected 401, got ${res.status}. Body: ${JSON.stringify(res.body)}`);
  }

  // 1.1b Seeded customer (usr_guest_nalut: 0910000000) penetration assertions rejecting Password123! and backdoors
  for (const backdoor of BACKDOOR_CREDENTIALS) {
    const res = await apiRequest('POST', '/api/v1/auth/login', {
      phone: '0910000000',
      password: backdoor
    });
    const isRejected = res.status === 401;
    recordTest('SUITE-1.1-SEEDED-CUSTOMER', `Seeded customer 0910000000 rejects backdoor "${backdoor}" with HTTP 401`, isRejected,
      `Expected 401, got ${res.status}. Status 200 indicates backdoor credential accepted! Body: ${JSON.stringify(res.body)}`);
  }

  // 1.1c Seeded customer authenticates successfully with rotated password
  const validSeedRes = await apiRequest('POST', '/api/v1/auth/login', {
    phone: '0910000000',
    password: 'Customer@Nalut2026!Secure'
  });
  const validSeedPass = validSeedRes.status === 200 && Boolean(validSeedRes.body?.data?.token);
  recordTest('SUITE-1.1-SEEDED-CUSTOMER', 'Seeded customer 0910000000 logs in with rotated secure password', validSeedPass,
    `Expected 200 with JWT, got ${validSeedRes.status}`);

  // 1.2 Driver login with backdoor passwords (phone: 0912345678)
  for (const backdoor of BACKDOOR_CREDENTIALS) {
    const res = await apiRequest('POST', '/api/v1/auth/login', {
      phone: '0912345678',
      password: backdoor
    });
    const isRejected = res.status === 401;
    recordTest('SUITE-1.2-DRIVER-01', `Driver 0912345678 login with backdoor "${backdoor}"`, isRejected,
      `Expected 401, got ${res.status}. Status 200 indicates unauthenticated driver login accepted! Token: ${res.body?.data?.token ? 'LEAKED' : 'none'}`);
  }

  // 1.3 Driver login with backdoor passwords (phone: 0923456789)
  for (const backdoor of BACKDOOR_CREDENTIALS) {
    const res = await apiRequest('POST', '/api/v1/auth/login', {
      phone: '0923456789',
      password: backdoor
    });
    const isRejected = res.status === 401;
    recordTest('SUITE-1.3-DRIVER-02', `Driver 0923456789 login with backdoor "${backdoor}"`, isRejected,
      `Expected 401, got ${res.status}. Status 200 indicates driver login accepted!`);
  }

  // 1.4 Admin login with backdoor passwords
  for (const backdoor of BACKDOOR_CREDENTIALS) {
    const resRole = await apiRequest('POST', '/api/v1/auth/login', {
      role: 'admin',
      password: backdoor
    });
    const isRejectedRole = resRole.status === 401;
    recordTest('SUITE-1.4-ADMIN-ROLE', `Admin login by role with backdoor "${backdoor}"`, isRejectedRole,
      `Expected 401, got ${resRole.status}.`);

    const resPhone = await apiRequest('POST', '/api/v1/auth/login', {
      phone: '0910009832',
      password: backdoor
    });
    const isRejectedPhone = resPhone.status === 401;
    recordTest('SUITE-1.4-ADMIN-PHONE', `Admin login by phone with backdoor "${backdoor}"`, isRejectedPhone,
      `Expected 401, got ${resPhone.status}.`);
  }

  // 1.5 Merchant login with backdoor PINs (/api/v1/auth/merchant-login)
  for (const backdoor of BACKDOOR_CREDENTIALS) {
    const resRanchello = await apiRequest('POST', '/api/v1/auth/merchant-login', {
      store_id: 'store_nalut_ranchello',
      pin: backdoor
    });
    const isRejectedRanchello = resRanchello.status === 401;
    recordTest('SUITE-1.5-MERCHANT-RANCH', `Merchant store_nalut_ranchello login with PIN "${backdoor}"`, isRejectedRanchello,
      `Expected 401, got ${resRanchello.status}. Status 200 indicates store accepted backdoor PIN!`);

    const resAlhanaa = await apiRequest('POST', '/api/v1/auth/merchant-login', {
      store_id: 'store_nalut_alhanaa',
      pin: backdoor
    });
    const isRejectedAlhanaa = resAlhanaa.status === 401;
    recordTest('SUITE-1.5-MERCHANT-ALHANAA', `Merchant store_nalut_alhanaa login with PIN "${backdoor}"`, isRejectedAlhanaa,
      `Expected 401, got ${resAlhanaa.status}. Status 200 indicates store accepted backdoor PIN!`);
  }

  // ==========================================================================
  // SUITE 2: PENETRATION ATTEMPTS WITH QUERY PARAMS & HEADERS ON ADMIN ENDPOINTS
  // ==========================================================================
  console.log('\n--- SUITE 2: Query Params & Header Bypass Attempts on Admin Endpoints ---');

  const adminQueryVectors = [
    { method: 'POST', endpoint: '/api/v1/admin/purge?admin_key=7788', body: {} },
    { method: 'POST', endpoint: '/api/v1/admin/purge?admin_key=9832', body: {} },
    { method: 'POST', endpoint: '/api/v1/admin/seed?admin_key=7788', body: {} },
    { method: 'POST', endpoint: '/api/v1/admin/seed?admin_key=9832', body: {} },
    { method: 'GET', endpoint: '/api/v1/admin/overview?admin_key=7788', body: null },
    { method: 'GET', endpoint: '/api/v1/admin/overview?admin_key=9832', body: null },
    { method: 'POST', endpoint: '/admin/purge?admin_key=9832', body: {} },
    { method: 'GET', endpoint: '/admin/overview?admin_key=7788', body: null }
  ];

  for (const vec of adminQueryVectors) {
    const res = await apiRequest(vec.method, vec.endpoint, vec.body);
    const passed = res.status === 401;
    recordTest('SUITE-2.1-QUERY-BYPASS', `${vec.method} ${vec.endpoint} rejected with 401`, passed,
      `Expected 401, got ${res.status}`);
  }

  const adminHeaderVectors = [
    { method: 'POST', endpoint: '/api/v1/admin/purge', body: {}, headers: { 'x-admin-key': '7788' } },
    { method: 'POST', endpoint: '/api/v1/admin/purge', body: {}, headers: { 'x-admin-key': '9832' } },
    { method: 'POST', endpoint: '/api/v1/admin/seed', body: {}, headers: { 'x-admin-key': '7788' } },
    { method: 'POST', endpoint: '/api/v1/admin/seed', body: {}, headers: { 'x-admin-key': '9832' } },
    { method: 'GET', endpoint: '/api/v1/admin/overview', body: null, headers: { 'x-admin-key': '7788' } },
    { method: 'GET', endpoint: '/api/v1/admin/overview', body: null, headers: { 'x-admin-key': '9832' } },
    { method: 'POST', endpoint: '/admin/purge', body: {}, headers: { 'x-admin-key': '9832' } },
    { method: 'GET', endpoint: '/admin/overview', body: null, headers: { 'x-admin-key': '7788' } }
  ];

  for (const vec of adminHeaderVectors) {
    const res = await apiRequest(vec.method, vec.endpoint, vec.body, vec.headers);
    const passed = res.status === 401;
    const headerStr = JSON.stringify(vec.headers);
    recordTest('SUITE-2.2-HEADER-BYPASS', `${vec.method} ${vec.endpoint} with ${headerStr} rejected with 401`, passed,
      `Expected 401, got ${res.status}`);
  }

  // ==========================================================================
  // SUITE 3: ADMINISTRATIVE OPERATIONS ACCESS CONTROL (RBAC)
  // ==========================================================================
  console.log('\n--- SUITE 3: Administrative Operations RBAC Enforcement ---');

  const adminEndpoints = [
    { method: 'POST', endpoint: '/api/v1/admin/purge', body: {} },
    { method: 'POST', endpoint: '/api/v1/admin/seed', body: {} },
    { method: 'POST', endpoint: '/api/v1/stores', body: { name: 'متجر اختبار هجومي' } },
    { method: 'DELETE', endpoint: '/api/v1/stores/store_nalut_ranchello', body: null },
    { method: 'POST', endpoint: '/api/v1/drivers', body: { full_name: 'كابتن اختبار هجومي', phone: '0919990000' } },
    { method: 'DELETE', endpoint: '/api/v1/drivers/driver_nalut_01', body: null },
    { method: 'POST', endpoint: '/api/v1/drivers/driver_nalut_01/settle', body: { amount_lyd: 10 } },
    { method: 'PATCH', endpoint: '/api/v1/drivers/driver_nalut_01/settle', body: { amount_lyd: 10 } },
    // Root alias versions
    { method: 'POST', endpoint: '/admin/purge', body: {} },
    { method: 'POST', endpoint: '/admin/seed', body: {} },
    { method: 'POST', endpoint: '/stores', body: { name: 'متجر اختبار هجومي' } },
    { method: 'DELETE', endpoint: '/stores/store_nalut_ranchello', body: null },
    { method: 'POST', endpoint: '/drivers', body: { full_name: 'كابتن اختبار هجومي', phone: '0919990000' } },
    { method: 'DELETE', endpoint: '/drivers/driver_nalut_01', body: null }
  ];

  for (const ep of adminEndpoints) {
    // 3.1 Without token -> 401
    const resNoToken = await apiRequest(ep.method, ep.endpoint, ep.body);
    const passedNoToken = resNoToken.status === 401;
    recordTest('SUITE-3.1-NO-TOKEN', `${ep.method} ${ep.endpoint} without token rejected (401)`, passedNoToken,
      `Expected 401, got ${resNoToken.status}`);

    // 3.2 With malformed token -> 401
    const resMalformed = await apiRequest(ep.method, ep.endpoint, ep.body, malformedAuth);
    const passedMalformed = resMalformed.status === 401;
    recordTest('SUITE-3.2-MALFORMED', `${ep.method} ${ep.endpoint} with malformed token rejected (401)`, passedMalformed,
      `Expected 401, got ${resMalformed.status}`);

    // 3.3 With customer token -> 403 Forbidden
    const resCust = await apiRequest(ep.method, ep.endpoint, ep.body, custAuth);
    const passedCust = resCust.status === 403;
    recordTest('SUITE-3.3-CUST-TOKEN', `${ep.method} ${ep.endpoint} with customer token rejected (403)`, passedCust,
      `Expected 403, got ${resCust.status}`);

    // 3.4 With driver token -> 403 Forbidden
    const resDriver = await apiRequest(ep.method, ep.endpoint, ep.body, driverAuth);
    const passedDriver = resDriver.status === 403;
    recordTest('SUITE-3.4-DRIVER-TOKEN', `${ep.method} ${ep.endpoint} with driver token rejected (403)`, passedDriver,
      `Expected 403, got ${resDriver.status}`);
  }

  // ==========================================================================
  // SUITE 4: CREDENTIAL SANITIZATION & LEAKAGE VERIFICATION
  // ==========================================================================
  console.log('\n--- SUITE 4: Credential Sanitization (GET /stores & GET /drivers) ---');

  const checkNoLeaks = (obj, entityType, id) => {
    const leaks = [];
    if (!obj) return leaks;
    if (obj.pin !== undefined) leaks.push(`pin="${obj.pin}"`);
    if (obj.password !== undefined) leaks.push(`password="${obj.password}"`);
    if (obj.password_hash !== undefined) leaks.push(`password_hash="${obj.password_hash}"`);
    return leaks;
  };

  // 4.1 GET /api/v1/stores
  const getStoresRes = await apiRequest('GET', '/api/v1/stores');
  const storeList = getStoresRes.body?.data || [];
  let storeLeakCount = 0;
  for (const s of storeList) {
    const leaks = checkNoLeaks(s, 'Store', s.id);
    if (leaks.length > 0) {
      storeLeakCount++;
      recordTest('SUITE-4.1-STORES', `Store ${s.id} does not leak credentials`, false, `Leaked: ${leaks.join(', ')}`);
    }
  }
  if (storeLeakCount === 0) {
    recordTest('SUITE-4.1-STORES', `All ${storeList.length} stores in GET /api/v1/stores sanitized`, true);
  }

  // 4.2 GET /api/v1/stores/:id
  const singleStoreRes = await apiRequest('GET', '/api/v1/stores/store_nalut_ranchello');
  const singleStore = singleStoreRes.body?.data || singleStoreRes.body;
  const singleStoreLeaks = checkNoLeaks(singleStore, 'Store', 'store_nalut_ranchello');
  recordTest('SUITE-4.2-SINGLE-STORE', 'GET /api/v1/stores/store_nalut_ranchello sanitized', singleStoreLeaks.length === 0,
    `Leaked: ${singleStoreLeaks.join(', ')}`);

  // 4.3 GET /api/v1/drivers
  const getDriversRes = await apiRequest('GET', '/api/v1/drivers');
  const driverList = getDriversRes.body?.data || [];
  let driverLeakCount = 0;
  for (const d of driverList) {
    const leaks = checkNoLeaks(d, 'Driver', d.id);
    if (leaks.length > 0) {
      driverLeakCount++;
      recordTest('SUITE-4.3-DRIVERS', `Driver ${d.id} does not leak credentials`, false, `Leaked: ${leaks.join(', ')}`);
    }
  }
  if (driverLeakCount === 0) {
    recordTest('SUITE-4.3-DRIVERS', `All ${driverList.length} drivers in GET /api/v1/drivers sanitized`, true);
  }

  // 4.4 GET /api/v1/drivers/:id
  const singleDriverRes = await apiRequest('GET', '/api/v1/drivers/driver_nalut_01');
  const singleDriver = singleDriverRes.body?.data || singleDriverRes.body;
  const singleDriverLeaks = checkNoLeaks(singleDriver, 'Driver', 'driver_nalut_01');
  recordTest('SUITE-4.4-SINGLE-DRIVER', 'GET /api/v1/drivers/driver_nalut_01 sanitized', singleDriverLeaks.length === 0,
    `Leaked: ${singleDriverLeaks.join(', ')}`);

  // 4.5 Root aliases /stores and /drivers
  const rootStoresRes = await apiRequest('GET', '/stores');
  const rootStoreList = rootStoresRes.body?.data || [];
  let rootStoreLeaks = 0;
  for (const s of rootStoreList) {
    const leaks = checkNoLeaks(s, 'Store', s.id);
    if (leaks.length > 0) rootStoreLeaks++;
  }
  recordTest('SUITE-4.5-ROOT-STORES', `Root alias GET /stores (${rootStoreList.length} stores) sanitized`, rootStoreLeaks === 0,
    `Found leaks in ${rootStoreLeaks} stores`);

  const rootDriversRes = await apiRequest('GET', '/drivers');
  const rootDriverList = rootDriversRes.body?.data || [];
  let rootDriverLeaks = 0;
  for (const d of rootDriverList) {
    const leaks = checkNoLeaks(d, 'Driver', d.id);
    if (leaks.length > 0) rootDriverLeaks++;
  }
  recordTest('SUITE-4.6-ROOT-DRIVERS', `Root alias GET /drivers (${rootDriverList.length} drivers) sanitized`, rootDriverLeaks === 0,
    `Found leaks in ${rootDriverLeaks} drivers`);

  // ==========================================================================
  // SUITE 5: CUSTODY, HANDOVER & DELIVERY OTP INTEGRITY
  // ==========================================================================
  console.log('\n--- SUITE 5: Custody, Handover Code & Delivery OTP Integrity ---');

  // Create an order for testing
  const checkoutRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: 'store_nalut_ranchello',
    items: [{ product_id: 'prod_nalut_sec_01', quantity: 1, unit_price_lyd: 20.0 }],
    delivery_address: 'نالوت - المركز الأمني للتحدي',
    payment_method: 'cash_on_delivery'
  }, custAuth);
  const testOrder = checkoutRes.body?.data || checkoutRes.body;

  if (testOrder && testOrder.id) {
    // 5.1 Public tracking does NOT leak OTP and returns 404 for nonexistent order
    const nonExistTrack = await apiRequest('GET', '/api/v1/public/track/ord_adversarial_non_existent');
    recordTest('SUITE-5.1-TRACK-404', 'Public track returns 404 on nonexistent order ID', nonExistTrack.status === 404,
      `Expected 404, got ${nonExistTrack.status}`);

    const trackRes = await apiRequest('GET', `/api/v1/public/track/${testOrder.id}`);
    const trackData = trackRes.body?.data || trackRes.body;
    const leaksOtp = trackData.delivery_otp !== undefined || trackData.otp_code !== undefined;
    recordTest('SUITE-5.2-TRACK-NO-OTP', 'Public track does not leak delivery_otp or otp_code', !leaksOtp,
      `Track response leaked: otp_code=${trackData.otp_code}, delivery_otp=${trackData.delivery_otp}`);

    // Advance order to ready_for_pickup
    await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, { status: 'accepted' }, custAuth);
    await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, { status: 'preparing' }, custAuth);
    await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, { status: 'ready_for_pickup' }, custAuth);

    // 5.3 Handover rejection with backdoor '1234'
    const badHandover = await apiRequest('POST', `/api/v1/orders/${testOrder.id}/handover`, {
      handover_code: '1234',
      driver_id: 'driver_nalut_01'
    }, driverAuth);
    recordTest('SUITE-5.3-HANDOVER-1234', 'Handover rejected with backdoor code "1234"', badHandover.status === 400,
      `Expected 400, got ${badHandover.status}`);

    // 5.4 Handover rejection with missing code
    const missingHandover = await apiRequest('POST', `/api/v1/orders/${testOrder.id}/handover`, {
      driver_id: 'driver_nalut_01'
    }, driverAuth);
    recordTest('SUITE-5.4-HANDOVER-MISSING', 'Handover rejected with missing code', missingHandover.status === 400,
      `Expected 400, got ${missingHandover.status}`);

    // Advance order to picked_up
    await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, {
      status: 'picked_up',
      driver_id: 'driver_nalut_01'
    }, driverAuth);

    // 5.5 Delivery rejection with backdoor OTP '1234'
    const badOtp = await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, {
      status: 'delivered',
      driver_id: 'driver_nalut_01',
      otp_code: '1234'
    }, driverAuth);
    recordTest('SUITE-5.5-DELIVERY-OTP-1234', 'Delivery status rejected with backdoor OTP "1234"', badOtp.status === 400,
      `Expected 400, got ${badOtp.status}`);

    // 5.6 Delivery rejection with missing OTP
    const missingOtp = await apiRequest('POST', `/api/v1/orders/${testOrder.id}/status`, {
      status: 'delivered',
      driver_id: 'driver_nalut_01'
    }, driverAuth);
    recordTest('SUITE-5.6-DELIVERY-OTP-MISSING', 'Delivery status rejected with missing OTP', missingOtp.status === 400,
      `Expected 400, got ${missingOtp.status}`);
  } else {
    recordTest('SUITE-5-SETUP', 'Checkout for custody tests succeeded', false, `Checkout returned: ${JSON.stringify(checkoutRes.body)}`);
  }

  // ==========================================================================
  // SUITE 6: ADVERSARIAL MUTATOR INJECTIONS & UNGUARDED ROUTES
  // ==========================================================================
  console.log('\n--- SUITE 6: Adversarial Mutator Injections & Unguarded Routes ---');

  // 6.1 Test PATCH /api/v1/drivers/:id without authentication
  const unauthDriverPatch = await apiRequest('PATCH', '/api/v1/drivers/driver_nalut_01', {
    wallet_balance_lyd: 999999,
    status: 'online'
  });
  const driverPatchProtected = unauthDriverPatch.status === 401 || unauthDriverPatch.status === 403;
  recordTest('SUITE-6.1-DRIVER-PATCH-AUTH', 'PATCH /api/v1/drivers/:id requires authentication', driverPatchProtected,
    `Expected 401/403, got ${unauthDriverPatch.status}. Unauthenticated caller altered driver state!`);

  // 6.2 Test POST /api/v1/stores/:id/heartbeat without authentication
  const unauthStoreHeartbeat = await apiRequest('POST', '/api/v1/stores/store_nalut_ranchello/heartbeat', {});
  const storeHeartbeatProtected = unauthStoreHeartbeat.status === 401 || unauthStoreHeartbeat.status === 403;
  recordTest('SUITE-6.2-STORE-HEARTBEAT-AUTH', 'POST /api/v1/stores/:id/heartbeat requires authentication', storeHeartbeatProtected,
    `Expected 401/403, got ${unauthStoreHeartbeat.status}. Unauthenticated caller can force-open stores!`);

  // ==========================================================================
  // FINAL REPORT & METRICS
  // ==========================================================================
  console.log('\n================================================================');
  console.log('📊 CHALLENGER M2-1 EMPIRICAL VERIFICATION SUMMARY');
  console.log('================================================================');
  console.log(`Total Checks Executed:  ${results.total}`);
  console.log(`Passed:                 ${results.passed}`);
  console.log(`Vulnerabilities Found:  ${results.failed}`);
  const passRate = ((results.passed / results.total) * 100).toFixed(1);
  console.log(`Pass Rate:              ${passRate}%`);
  console.log('================================================================');

  if (results.vulnerabilities.length > 0) {
    console.log('\n🚨 CONFIRMED VULNERABILITIES LIST:');
    results.vulnerabilities.forEach((v, i) => {
      console.log(`  ${i + 1}. [${v.suite}] ${v.name}`);
      console.log(`     Details: ${v.details}`);
    });
    console.log('\n⚠️ VERDICT: REQUEST_CHANGES');
    process.exit(1);
  } else {
    console.log('\n🎉 ALL CHECKS PASSED WITH ZERO VULNERABILITIES DETECTED!');
    console.log('VERDICT: APPROVE');
    process.exit(0);
  }
}

runPenetrationSuite().catch(err => {
  console.error('[Harness Fatal Error]:', err);
  process.exit(1);
});
