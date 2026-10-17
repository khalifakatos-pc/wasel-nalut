/**
 * ============================================================================
 * INDEPENDENT ADVERSARIAL CHALLENGER SUITE: M4-R2-2
 * ============================================================================
 * Agent: Challenger M4-R2-2
 * Purpose: Empirically stress-test Admin App, Admin Auth, PIN Security,
 *          Bypass rejection, and Delivery Zone access control.
 * ============================================================================
 */

const http = require('http');
const jwt = require('jsonwebtoken');
const { config } = require('./config');

const TEST_PORT = process.env.TEST_PORT || process.env.PORT || 3000;
const JWT_SECRET = config.JWT_SECRET;

let serverModule = null;
let ipCounter = 700;

function apiRequest(method, endpoint, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const reqHeaders = {
      'Content-Type': 'application/json',
      'x-forwarded-for': `10.99.7.${ipCounter++}`,
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

const results = [];
let passCount = 0;
let failCount = 0;

async function check(name, fn) {
  try {
    await fn();
    passCount++;
    console.log(`  \x1b[32m✔ [PASS]\x1b[0m ${name}`);
    results.push({ name, passed: true });
  } catch (err) {
    failCount++;
    console.log(`  \x1b[31m✖ [FAIL]\x1b[0m ${name}: ${err.message}`);
    results.push({ name, passed: false, error: err.message });
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

async function run() {
  console.log('\n================================================================');
  console.log('⚔️  CHALLENGER M4-R2-2: DEEP ADVERSARIAL STRESS TEST SUITE');
  console.log('================================================================\n');

  await startServerIfNeeded();

  // Tokens
  const customerToken = jwt.sign({ id: 'usr_adv_test', role: 'customer' }, JWT_SECRET, { expiresIn: '1h' });
  const driverToken = jwt.sign({ id: 'drv_adv_test', role: 'driver' }, JWT_SECRET, { expiresIn: '1h' });
  const merchantToken = jwt.sign({ id: 'mer_adv_test', role: 'merchant' }, JWT_SECRET, { expiresIn: '1h' });

  console.log('\n--- SECTION 1: Adversarial PIN & Auth Bypass Rejection ---');

  await check('Backdoor PIN 1234 returns 401', async () => {
    const res = await apiRequest('POST', '/api/v1/auth/admin-login', { pin: '1234' });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  await check('Backdoor PIN 0000 returns 401', async () => {
    const res = await apiRequest('POST', '/api/v1/auth/admin-login', { pin: '0000' });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  await check('Legacy PIN 9832 returns 401', async () => {
    const res = await apiRequest('POST', '/api/v1/auth/admin-login', { pin: '9832' });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  await check('Arbitrary string PIN "admin" returns 401', async () => {
    const res = await apiRequest('POST', '/api/v1/auth/admin-login', { pin: 'admin' });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  await check('Empty body returns 401', async () => {
    const res = await apiRequest('POST', '/api/v1/auth/admin-login', {});
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  await check('PIN 7788 succeeds with 200 and valid JWT token', async () => {
    const res = await apiRequest('POST', '/api/v1/auth/admin-login', { pin: '7788' });
    if (res.status !== 200 || !res.body.success || !res.body.data || !res.body.data.token) {
      throw new Error(`Expected 200 with JWT, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    const decoded = jwt.verify(res.body.data.token, JWT_SECRET);
    if (decoded.role !== 'admin') throw new Error(`Expected admin role, got ${decoded.role}`);
  });

  await check('Password Admin@Nalut2026!Secure succeeds with 200 and valid JWT token', async () => {
    const res = await apiRequest('POST', '/api/v1/auth/admin-login', { password: 'Admin@Nalut2026!Secure' });
    if (res.status !== 200 || !res.body.success || !res.body.data?.token) {
      throw new Error(`Expected 200 with JWT, got ${res.status}`);
    }
  });

  // Obtain legitimate admin token for subsequent tests
  const adminLoginRes = await apiRequest('POST', '/api/v1/auth/admin-login', { pin: '7788' });
  const adminToken = adminLoginRes.body.data.token;

  console.log('\n--- SECTION 2: Query Parameter Bypass & Header Spoofing ---');

  await check('GET /api/v1/admin/overview?admin_key=7788 returns 401 without Bearer token', async () => {
    const res = await apiRequest('GET', '/api/v1/admin/overview?admin_key=7788');
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  await check('POST /api/v1/admin/purge?admin_key=7788 returns 401 without Bearer token', async () => {
    const res = await apiRequest('POST', '/api/v1/admin/purge?admin_key=7788', {});
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  await check('PATCH /api/v1/delivery-zones/zone_nalut_center?admin_key=7788 returns 401 without Bearer token', async () => {
    const res = await apiRequest('PATCH', '/api/v1/delivery-zones/zone_nalut_center?admin_key=7788', { base_fee_lyd: 10 });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  await check('x-admin-key: 7788 header returns 401 without Bearer token', async () => {
    const res = await apiRequest('GET', '/api/v1/admin/overview', null, { 'x-admin-key': '7788' });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  await check('x-admin-key: 9832 header returns 401 without Bearer token', async () => {
    const res = await apiRequest('GET', '/api/v1/admin/overview', null, { 'x-admin-key': '9832' });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  console.log('\n--- SECTION 3: Role-Based Access Control on Admin Endpoints ---');

  await check('Customer token on GET /api/v1/admin/overview returns 403', async () => {
    const res = await apiRequest('GET', '/api/v1/admin/overview', null, { 'Authorization': `Bearer ${customerToken}` });
    if (res.status !== 403) throw new Error(`Expected 403, got ${res.status}`);
  });

  await check('Driver token on GET /api/v1/admin/overview returns 403', async () => {
    const res = await apiRequest('GET', '/api/v1/admin/overview', null, { 'Authorization': `Bearer ${driverToken}` });
    if (res.status !== 403) throw new Error(`Expected 403, got ${res.status}`);
  });

  await check('Merchant token on GET /api/v1/admin/overview returns 403', async () => {
    const res = await apiRequest('GET', '/api/v1/admin/overview', null, { 'Authorization': `Bearer ${merchantToken}` });
    if (res.status !== 403) throw new Error(`Expected 403, got ${res.status}`);
  });

  await check('Customer token on PATCH /api/v1/delivery-zones/zone_nalut_center returns 403', async () => {
    const res = await apiRequest('PATCH', '/api/v1/delivery-zones/zone_nalut_center', { base_fee_lyd: 9.9 }, { 'Authorization': `Bearer ${customerToken}` });
    if (res.status !== 403) throw new Error(`Expected 403, got ${res.status}`);
  });

  await check('Driver token on PATCH /api/v1/delivery-zones/zone_nalut_center returns 403', async () => {
    const res = await apiRequest('PATCH', '/api/v1/delivery-zones/zone_nalut_center', { base_fee_lyd: 9.9 }, { 'Authorization': `Bearer ${driverToken}` });
    if (res.status !== 403) throw new Error(`Expected 403, got ${res.status}`);
  });

  console.log('\n--- SECTION 4: Delivery Zones Data & Persistence ---');

  let initialZones = [];
  await check('GET /api/v1/delivery-zones returns all 6 authentic Nalut zones', async () => {
    const res = await apiRequest('GET', '/api/v1/delivery-zones');
    if (res.status !== 200 || !res.body.success || !Array.isArray(res.body.data)) {
      throw new Error(`Expected 200 with data array, got ${res.status}`);
    }
    initialZones = res.body.data;
    if (initialZones.length !== 6) {
      throw new Error(`Expected exactly 6 zones, found ${initialZones.length}`);
    }
    const zoneIds = initialZones.map(z => z.id);
    const required = [
      'zone_nalut_center',
      'zone_nalut_qalaa',
      'zone_nalut_africa',
      'zone_nalut_airport',
      'zone_nalut_talat',
      'zone_nalut_kabaw_road'
    ];
    for (const reqId of required) {
      if (!zoneIds.includes(reqId)) throw new Error(`Missing expected zone ${reqId}`);
    }
  });

  await check('Admin token can PATCH delivery zone and persistence is immediate', async () => {
    const targetZone = initialZones.find(z => z.id === 'zone_nalut_center') || initialZones[0];
    const originalFee = parseFloat(targetZone.base_fee_lyd);
    const testFee = 4.75;

    const patchRes = await apiRequest('PATCH', `/api/v1/delivery-zones/${targetZone.id}`, {
      base_fee_lyd: testFee
    }, {
      'Authorization': `Bearer ${adminToken}`
    });

    if (patchRes.status !== 200 || !patchRes.body.success) {
      throw new Error(`PATCH failed: status ${patchRes.status}`);
    }

    // Verify GET returns updated fee
    const getRes = await apiRequest('GET', '/api/v1/delivery-zones');
    const updated = (getRes.body.data || []).find(z => z.id === targetZone.id);
    if (!updated || parseFloat(updated.base_fee_lyd) !== testFee) {
      throw new Error(`Updated fee not reflected in GET: expected ${testFee}, got ${updated?.base_fee_lyd}`);
    }

    // Revert back to original fee
    await apiRequest('PATCH', `/api/v1/delivery-zones/${targetZone.id}`, {
      base_fee_lyd: originalFee
    }, {
      'Authorization': `Bearer ${adminToken}`
    });
  });

  console.log('\n================================================================');
  console.log(`TOTAL ADVERSARIAL CHECKS: ${passCount + failCount}`);
  console.log(`Passed: ${passCount}`);
  console.log(`Failed: ${failCount}`);
  console.log('================================================================\n');

  if (failCount > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

run().catch(err => {
  console.error('Fatal adversarial harness error:', err);
  process.exit(1);
});
