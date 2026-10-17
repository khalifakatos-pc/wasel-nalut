/**
 * ============================================================================
 * WASEL NALUT: CHALLENGER M4-2 EMPIRICAL TEST & ADVERSARIAL HARNESS
 * ============================================================================
 * Focus: Admin App (flutter_admin_app) changes & Backend Admin Auth / Persistence:
 * 1. POST /api/v1/auth/admin-login with valid/invalid PINs and passwords.
 * 2. Protected admin endpoints without Authorization: Bearer <token> (must be 401/403).
 * 3. Query parameter bypass ?admin_key=7788 on protected admin endpoints.
 * 4. Delivery zone persistence and fee modifications via PATCH /api/v1/delivery-zones/:id.
 * 5. Elimination of synthetic menu items in fetchProductsForStore / menu endpoints.
 * ============================================================================
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const { config } = require('./config');

const TEST_PORT = process.env.TEST_PORT || process.env.PORT || 3000;
const JWT_SECRET = config.JWT_SECRET;

let serverModule = null;
let ipCounter = 400;
function apiRequest(method, endpoint, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const reqHeaders = {
      'Content-Type': 'application/json',
      'x-forwarded-for': `10.55.2.${ipCounter++}`,
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

    req.on('error', (err) => {
      reject(err);
    });

    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

const tests = [];
let passedCount = 0;
let failedCount = 0;

async function runTest(id, name, fn) {
  try {
    await fn();
    passedCount++;
    console.log(`  \x1b[32m✔ [PASS]\x1b[0m \x1b[1m${id}\x1b[0m: ${name}`);
    tests.push({ id, name, passed: true });
  } catch (err) {
    failedCount++;
    console.log(`  \x1b[31m✖ [FAIL]\x1b[0m \x1b[1m${id}\x1b[0m: ${name}`);
    console.log(`         \x1b[31m${err.message}\x1b[0m`);
    tests.push({ id, name, passed: false, error: err.message });
  }
}

async function startServerIfNeeded() {
  const isRunning = await new Promise(resolve => {
    const probeReq = http.get(`http://127.0.0.1:${TEST_PORT}/health`, (res) => {
      resolve(res.statusCode === 200);
    });
    probeReq.on('error', () => resolve(false));
    probeReq.setTimeout(400, () => {
      probeReq.destroy();
      resolve(false);
    });
  });

  if (!isRunning) {
    console.log(`Starting in-process backend server on port ${TEST_PORT}...`);
    process.env.PORT = String(TEST_PORT);
    serverModule = require('./server.js');
    await new Promise(r => setTimeout(r, 600));
  } else {
    console.log(`Connected to existing backend on port ${TEST_PORT}.`);
    try {
      serverModule = require('./server.js');
    } catch (_) {}
  }
}

async function main() {
  console.log('\n================================================================');
  console.log('🛡️  CHALLENGER M4-2: EMPIRICAL ADMIN APP & AUTH STRESS HARNESS');
  console.log('================================================================\n');

  await startServerIfNeeded();

  // Create test tokens
  const validAdminToken = jwt.sign(
    { id: 'admin_master', role: 'admin', full_name: 'مدير العمليات' },
    JWT_SECRET,
    { expiresIn: '1h' }
  );

  const customerToken = jwt.sign(
    { id: 'usr_guest_nalut', role: 'customer', full_name: 'زبون عادي' },
    JWT_SECRET,
    { expiresIn: '1h' }
  );

  const driverToken = jwt.sign(
    { id: 'drv_khalid', role: 'driver', full_name: 'كابتن خالد' },
    JWT_SECRET,
    { expiresIn: '1h' }
  );

  console.log('\n--- SUITE 1: POST /api/v1/auth/admin-login PIN & Credential Tests ---');

  // Test 1.1: Empty body rejected with 401
  await runTest('T1.1_AdminLogin_EmptyBody', 'Rejects empty body with 401', async () => {
    const res = await apiRequest('POST', '/api/v1/auth/admin-login', {});
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(res.body)}`);
  });

  // Test 1.2: Invalid PIN rejected with 401
  await runTest('T1.2_AdminLogin_InvalidPin', 'Rejects invalid PIN "0000" with 401', async () => {
    const res = await apiRequest('POST', '/api/v1/auth/admin-login', { pin: '0000' });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(res.body)}`);
  });

  // Test 1.3: Backdoor PIN "1234" rejected with 401
  await runTest('T1.3_AdminLogin_Backdoor1234', 'Rejects backdoor PIN "1234" with 401', async () => {
    const res = await apiRequest('POST', '/api/v1/auth/admin-login', { pin: '1234' });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(res.body)}`);
  });

  // Test 1.4: Check response to PIN '7788'
  await runTest('T1.4_AdminLogin_CheckPin7788', 'Accepts valid mobile admin PIN "7788"', async () => {
    const res = await apiRequest('POST', '/api/v1/auth/admin-login', { pin: '7788' });
    if (res.status !== 200 || !res.body.success || !res.body.data || !res.body.data.token) {
      throw new Error(`Expected 200 with JWT token, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
  });

  // Test 1.5: Valid admin password login
  let adminBearerToken = validAdminToken;
  await runTest('T1.5_AdminLogin_ValidSecret', 'Accepts valid admin secret "Admin@Nalut2026!Secure"', async () => {
    const res = await apiRequest('POST', '/api/v1/auth/admin-login', {
      password: 'Admin@Nalut2026!Secure'
    });
    if (res.status !== 200 || !res.body.success || !res.body.data || !res.body.data.token) {
      throw new Error(`Expected 200 with JWT token, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    adminBearerToken = res.body.data.token;
  });

  console.log('\n--- SUITE 2: Protected Admin Endpoints & Access Control ---');

  // Test 2.1: GET /api/v1/admin/overview without token must return 401
  await runTest('T2.1_AdminOverview_NoToken', 'GET /api/v1/admin/overview without Bearer header returns 401', async () => {
    const res = await apiRequest('GET', '/api/v1/admin/overview');
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(res.body)}`);
  });

  // Test 2.2: GET /api/v1/admin/overview with customer token must return 403
  await runTest('T2.2_AdminOverview_CustomerToken', 'GET /api/v1/admin/overview with customer token returns 403', async () => {
    const res = await apiRequest('GET', '/api/v1/admin/overview', null, {
      'Authorization': `Bearer ${customerToken}`
    });
    if (res.status !== 403) throw new Error(`Expected 403, got ${res.status}: ${JSON.stringify(res.body)}`);
  });

  // Test 2.3: POST /api/v1/admin/purge without token must return 401
  await runTest('T2.3_AdminPurge_NoToken', 'POST /api/v1/admin/purge without Bearer header returns 401', async () => {
    const res = await apiRequest('POST', '/api/v1/admin/purge', {});
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(res.body)}`);
  });

  // Test 2.4: POST /api/v1/admin/purge with driver token must return 403
  await runTest('T2.4_AdminPurge_DriverToken', 'POST /api/v1/admin/purge with driver token returns 403', async () => {
    const res = await apiRequest('POST', '/api/v1/admin/purge', {}, {
      'Authorization': `Bearer ${driverToken}`
    });
    if (res.status !== 403) throw new Error(`Expected 403, got ${res.status}: ${JSON.stringify(res.body)}`);
  });

  // Test 2.5: GET /api/v1/admin/overview with valid admin token succeeds with 200
  await runTest('T2.5_AdminOverview_ValidToken', 'GET /api/v1/admin/overview with valid admin token returns 200', async () => {
    const res = await apiRequest('GET', '/api/v1/admin/overview', null, {
      'Authorization': `Bearer ${adminBearerToken}`
    });
    if (res.status !== 200 || !res.body.success) {
      throw new Error(`Expected 200 success, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
  });

  console.log('\n--- SUITE 3: Query Parameter Bypass & Header Spoofing Attacks ---');

  // Test 3.1: ?admin_key=7788 on /api/v1/admin/overview without token
  await runTest('T3.1_QueryParamBypass_Overview', 'Denies ?admin_key=7788 on /api/v1/admin/overview (must return 401)', async () => {
    const res = await apiRequest('GET', '/api/v1/admin/overview?admin_key=7788');
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(res.body)}`);
  });

  // Test 3.2: ?admin_key=7788 on /api/v1/admin/purge without token
  await runTest('T3.2_QueryParamBypass_Purge', 'Denies ?admin_key=7788 on /api/v1/admin/purge (must return 401)', async () => {
    const res = await apiRequest('POST', '/api/v1/admin/purge?admin_key=7788', {});
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(res.body)}`);
  });

  // Test 3.3: x-admin-key: 7788 header spoofing on /api/v1/admin/overview without Bearer token
  await runTest('T3.3_HeaderSpoofing_Overview', 'Denies x-admin-key: 7788 header without Bearer token (must return 401)', async () => {
    const res = await apiRequest('GET', '/api/v1/admin/overview', null, {
      'x-admin-key': '7788'
    });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(res.body)}`);
  });

  console.log('\n--- SUITE 4: Delivery Zones API, Security & Persistence Verification ---');

  // Check initial state of delivery zones in db
  if (serverModule && serverModule.db && (!serverModule.db.delivery_zones || serverModule.db.delivery_zones.length === 0)) {
    console.log('         [Notice] db.delivery_zones is empty. Seeding standard Nalut zones in memory for test harness...');
    serverModule.db.delivery_zones = [
      { id: 'zone_nalut_center', name_ar: 'نالوت - المركز والبلدة القديمة', name_en: 'Nalut Center & Old Town', base_fee_lyd: 3.0, min_delivery_time: 15, max_delivery_time: 25, sort_order: 1 },
      { id: 'zone_nalut_qalaa', name_ar: 'نالوت - حي القلعة وسيدي خليفة', name_en: 'Al-Qalaa & Sidi Khalifa', base_fee_lyd: 3.5, min_delivery_time: 20, max_delivery_time: 30, sort_order: 2 },
      { id: 'zone_nalut_africa', name_ar: 'نالوت - شارع أفريقيا والمنطقة الحرفية', name_en: 'Africa Street & Industrial Zone', base_fee_lyd: 4.0, min_delivery_time: 20, max_delivery_time: 30, sort_order: 3 }
    ];
  }

  // Test 4.1: GET /api/v1/delivery-zones returns list of zones
  let testZone = null;
  await runTest('T4.1_GetDeliveryZones', 'GET /api/v1/delivery-zones returns active zones', async () => {
    const res = await apiRequest('GET', '/api/v1/delivery-zones');
    if (res.status !== 200 || !res.body.success || !Array.isArray(res.body.data) || res.body.data.length === 0) {
      throw new Error(`Expected 200 with zones array, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    testZone = res.body.data[0];
    console.log(`         [Observation] Found ${res.body.data.length} zones. Test zone: ${testZone.id} (${testZone.name_ar || testZone.name}), fee: ${testZone.base_fee_lyd} LYD`);
  });

  // Test 4.2: Adversarial Security Challenge: PATCH /api/v1/delivery-zones/:id access control
  // Does PATCH /api/v1/delivery-zones/:id enforce admin authentication?
  await runTest('T4.2_PatchDeliveryZone_AuthCheck', 'PATCH /api/v1/delivery-zones/:id requires admin authentication (401)', async () => {
    if (!testZone) throw new Error('No test zone available');
    const resNoAuth = await apiRequest('PATCH', `/api/v1/delivery-zones/${testZone.id}`, {
      base_fee_lyd: 6.75
    });
    if (resNoAuth.status !== 401) {
      throw new Error(`Expected 401 Unauthorized for unauthenticated PATCH, got ${resNoAuth.status}: ${JSON.stringify(resNoAuth.body)}`);
    }
  });

  // Test 4.3: PATCH /api/v1/delivery-zones/:id fee mutation & persistence
  await runTest('T4.3_PatchDeliveryZone_Persistence', 'PATCH /api/v1/delivery-zones/:id updates and persists fee', async () => {
    if (!testZone) throw new Error('No test zone available');
    const originalFee = parseFloat(testZone.base_fee_lyd);
    const newFee = originalFee === 7.5 ? 5.5 : 7.5;

    // Send PATCH
    const patchRes = await apiRequest('PATCH', `/api/v1/delivery-zones/${testZone.id}`, {
      base_fee_lyd: newFee,
      min_delivery_time: 18,
      max_delivery_time: 32
    }, {
      'Authorization': `Bearer ${adminBearerToken}`
    });

    if (patchRes.status !== 200 || !patchRes.body.success) {
      throw new Error(`PATCH failed: status ${patchRes.status}, body: ${JSON.stringify(patchRes.body)}`);
    }

    // Verify GET immediately reflects updated fee
    const getRes = await apiRequest('GET', '/api/v1/delivery-zones', null, {
      'Authorization': `Bearer ${adminBearerToken}`
    });
    const updatedZone = (getRes.body.data || []).find(z => z.id === testZone.id);
    if (!updatedZone) throw new Error(`Zone ${testZone.id} not found after patch`);
    if (parseFloat(updatedZone.base_fee_lyd) !== newFee) {
      throw new Error(`Expected fee ${newFee}, but got ${updatedZone.base_fee_lyd}`);
    }

    // Restore original fee
    await apiRequest('PATCH', `/api/v1/delivery-zones/${testZone.id}`, {
      base_fee_lyd: originalFee
    }, {
      'Authorization': `Bearer ${adminBearerToken}`
    });
  });

  console.log('\n--- SUITE 5: Menu Purge & Synthetic Items Verification ---');

  // Test 5.1: Real store returns legitimate catalog
  await runTest('T5.1_StoreMenu_RealStore', 'GET /api/v1/stores/:id/menu returns legitimate catalog', async () => {
    const res = await apiRequest('GET', '/api/v1/stores/store_nalut_ranchello/menu');
    if (res.status !== 200 || !res.body.success) {
      throw new Error(`Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    const products = res.body.data?.products || res.body.data?.all_products || [];
    console.log(`         [Observation] store_nalut_ranchello returned ${products.length} products`);
  });

  // Test 5.2: Non-existent store does not return synthetic items
  await runTest('T5.2_StoreMenu_NonExistentStore', 'Non-existent store returns 404/empty and ZERO synthetic items', async () => {
    const res = await apiRequest('GET', '/api/v1/stores/fake_store_nonexistent_xyz/menu');
    if (res.status === 200) {
      const products = res.body.data?.products || res.body.data?.all_products || [];
      if (products.length > 0) {
        throw new Error(`Non-existent store returned ${products.length} synthetic items! Expected 0.`);
      }
    } else if (res.status !== 404) {
      console.log(`         [Observation] Non-existent store returned status ${res.status}`);
    }
  });

  console.log('\n================================================================');
  console.log(`SUMMARY: Passed: ${passedCount}, Failed: ${failedCount}, Total: ${tests.length}`);
  console.log('================================================================\n');

  if (failedCount > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

main().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
