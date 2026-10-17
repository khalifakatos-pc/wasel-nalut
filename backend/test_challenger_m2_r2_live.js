/**
 * ============================================================================
 * WASEL NALUT: CHALLENGER M2-R2-1 EMPIRICAL LIVE PENETRATION HARNESS
 * ============================================================================
 * Independent adversarial challenge verification:
 * 1. Backdoor credential attacks across Driver, Merchant, and Super Admin logins.
 * 2. Unauthenticated mutation attacks on PATCH /api/v1/drivers/:id and POST /api/v1/stores/:id/heartbeat.
 * 3. Adversarial injection attacks (SQLi, NoSQL object injection, empty secrets).
 * 4. Legitimate credential validation to ensure no operational denial-of-service.
 * ============================================================================
 */

const http = require('http');

const TEST_PORT = process.env.TEST_PORT || process.env.PORT || 3000;

let ipCounter = 100;
function apiRequest(method, endpoint, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const postData = body !== null ? JSON.stringify(body) : null;
    const reqHeaders = {
      'Content-Type': 'application/json',
      'x-forwarded-for': `192.168.10.${ipCounter++}`,
      ...headers
    };
    if (postData !== null) {
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
    if (postData !== null) req.write(postData);
    req.end();
  });
}

async function ensureServer() {
  const isUp = await new Promise(resolve => {
    const probe = http.get(`http://127.0.0.1:${TEST_PORT}/health`, res => resolve(res.statusCode === 200));
    probe.on('error', () => resolve(false));
    probe.setTimeout(300, () => { probe.destroy(); resolve(false); });
  });

  if (!isUp) {
    console.log(`[Harness] Starting backend server on port ${TEST_PORT}...`);
    process.env.PORT = String(TEST_PORT);
    require('./server.js');
    await new Promise(r => setTimeout(r, 800));
  }
}

const BACKDOORS = ['1234', 'Password123!', 'Admin123!', '7788', '9832'];
const DRIVERS = ['0912345678', '0923456789'];
const STORES = ['store_nalut_ranchello', 'store_nalut_alhanaa', 'store_nalut_akakus', 'store_nalut_rixos'];

const results = {
  total: 0,
  passed: 0,
  failed: 0,
  entries: []
};

function record(suite, desc, condition, actualInfo) {
  results.total++;
  if (condition) {
    results.passed++;
    console.log(`  ✅ [PASS] [${suite}] ${desc}`);
  } else {
    results.failed++;
    console.log(`  ❌ [FAIL] [${suite}] ${desc} -> ${actualInfo}`);
    results.entries.push({ suite, desc, actualInfo });
  }
}

async function run() {
  console.log('================================================================');
  console.log('⚔️  CHALLENGER M2-R2-1: LIVE PENETRATION & MUTATION TEST HARNESS');
  console.log('================================================================\n');

  await ensureServer();

  // --------------------------------------------------------------------------
  // PART 1: LIVE PENETRATION ATTEMPTS WITH BACKDOOR CREDENTIALS
  // --------------------------------------------------------------------------
  console.log('--- PART 1: Live Backdoor Credential Penetration (Driver, Merchant, Admin) ---');

  // 1.1 Driver Logins
  for (const phone of DRIVERS) {
    for (const secret of BACKDOORS) {
      const res = await apiRequest('POST', '/api/v1/auth/login', { phone, password: secret });
      record('PEN-1.1-DRIVER', `Driver ${phone} rejects backdoor "${secret}" with 401`,
        res.status === 401, `Status: ${res.status}, Body: ${JSON.stringify(res.body)}`);
    }
  }

  // 1.2 Merchant Logins
  for (const store_id of STORES) {
    for (const pin of BACKDOORS) {
      const res = await apiRequest('POST', '/api/v1/auth/merchant-login', { store_id, pin });
      record('PEN-1.2-MERCHANT', `Merchant ${store_id} rejects backdoor PIN "${pin}" with 401`,
        res.status === 401, `Status: ${res.status}, Body: ${JSON.stringify(res.body)}`);
    }
  }

  // 1.3 Super Admin Logins (by phone and by role)
  for (const secret of BACKDOORS) {
    const resRole = await apiRequest('POST', '/api/v1/auth/login', { role: 'admin', password: secret });
    record('PEN-1.3-ADMIN-ROLE', `Admin (role) rejects backdoor "${secret}" with 401`,
      resRole.status === 401, `Status: ${resRole.status}, Body: ${JSON.stringify(resRole.body)}`);

    const resPhone = await apiRequest('POST', '/api/v1/auth/login', { phone: '0910009832', password: secret });
    record('PEN-1.3-ADMIN-PHONE', `Admin (phone 0910009832) rejects backdoor "${secret}" with 401`,
      resPhone.status === 401, `Status: ${resPhone.status}, Body: ${JSON.stringify(resPhone.body)}`);
  }

  // 1.4 Customer Logins (Seeded usr_guest_nalut, 0910000000)
  for (const secret of BACKDOORS) {
    const resCust = await apiRequest('POST', '/api/v1/auth/login', { phone: '0910000000', password: secret });
    record('PEN-1.4-CUSTOMER', `Customer 0910000000 rejects backdoor "${secret}" with 401`,
      resCust.status === 401, `Status: ${resCust.status}, Body: ${JSON.stringify(resCust.body)}`);
  }

  // 1.5 Verify Customer authenticates with rotated secure password
  const resValidCust = await apiRequest('POST', '/api/v1/auth/login', {
    phone: '0910000000',
    password: 'Customer@Nalut2026!Secure'
  });
  record('PEN-1.5-CUSTOMER-VALID', 'Customer 0910000000 successfully authenticates with rotated secure password',
    resValidCust.status === 200 && Boolean(resValidCust.body?.data?.token),
    `Status: ${resValidCust.status}, Token: ${resValidCust.body?.data?.token ? 'OK' : 'MISSING'}`);

  // --------------------------------------------------------------------------
  // PART 2: UNAUTHENTICATED MUTATION ATTEMPTS
  // --------------------------------------------------------------------------
  console.log('\n--- PART 2: Unauthenticated Mutation Injections ---');

  // 2.1 Unauthenticated PATCH /api/v1/drivers/:id
  const driverMutations = [
    { endpoint: '/api/v1/drivers/driver_nalut_01', body: { wallet_balance_lyd: 50000, status: 'online' } },
    { endpoint: '/api/v1/drivers/driver_nalut_02', body: { cash_in_hand_lyd: 0, is_active: false } },
    { endpoint: '/drivers/driver_nalut_01', body: { wallet_balance_lyd: 99999 } },
    { endpoint: '/drivers/driver_nalut_02', body: { phone: '0999999999' } }
  ];

  for (const mut of driverMutations) {
    const res = await apiRequest('PATCH', mut.endpoint, mut.body);
    const isProtected = res.status === 401 || res.status === 403;
    record('MUT-2.1-DRIVER-PATCH', `Unauthenticated PATCH ${mut.endpoint} rejected with 401/403`,
      isProtected, `Status: ${res.status}, Body: ${JSON.stringify(res.body)}`);
  }

  // 2.2 Unauthenticated POST /api/v1/stores/:id/heartbeat
  const heartbeatMutations = [
    { endpoint: '/api/v1/stores/store_nalut_ranchello/heartbeat', body: {} },
    { endpoint: '/api/v1/stores/store_nalut_alhanaa/heartbeat', body: {} },
    { endpoint: '/api/v1/stores/store_nalut_akakus/heartbeat', body: {} },
    { endpoint: '/api/v1/stores/store_nalut_rixos/heartbeat', body: {} },
    { endpoint: '/stores/store_nalut_ranchello/heartbeat', body: {} }
  ];

  for (const hb of heartbeatMutations) {
    const res = await apiRequest('POST', hb.endpoint, hb.body);
    const isProtected = res.status === 401 || res.status === 403;
    record('MUT-2.2-STORE-HEARTBEAT', `Unauthenticated POST ${hb.endpoint} rejected with 401/403`,
      isProtected, `Status: ${res.status}, Body: ${JSON.stringify(res.body)}`);
  }

  // --------------------------------------------------------------------------
  // PART 3: ADVERSARIAL INJECTION & EDGE-CASE ATTACKS
  // --------------------------------------------------------------------------
  console.log('\n--- PART 3: Adversarial Injections & Edge Cases ---');

  const injections = [
    { name: 'Empty string PIN', val: '' },
    { name: 'SQL injection string', val: "' OR '1'='1" },
    { name: 'SQL comment string', val: "admin'--" },
    { name: 'Boolean object injection', val: { $ne: null } },
    { name: 'Whitespace string', val: '    ' },
    { name: 'Null value', val: null }
  ];

  for (const inj of injections) {
    const resDriver = await apiRequest('POST', '/api/v1/auth/login', { phone: '0912345678', password: inj.val });
    record('INJ-3.1-DRIVER-EDGE', `Driver login rejects ${inj.name}`,
      resDriver.status === 400 || resDriver.status === 401, `Status: ${resDriver.status}`);

    const resStore = await apiRequest('POST', '/api/v1/auth/merchant-login', { store_id: 'store_nalut_ranchello', pin: inj.val });
    record('INJ-3.2-STORE-EDGE', `Merchant login rejects ${inj.name}`,
      resStore.status === 400 || resStore.status === 401, `Status: ${resStore.status}`);
  }

  // --------------------------------------------------------------------------
  // PART 4: OPERATIONAL VALIDITY WITH AUTHENTIC CREDENTIALS
  // --------------------------------------------------------------------------
  console.log('\n--- PART 4: Operational Availability with Genuine Credentials ---');

  // Authentic Driver Logins
  const driverAuth01 = await apiRequest('POST', '/api/v1/auth/login', { phone: '0912345678', password: '5521' });
  record('OP-4.1-GENUINE-DRIVER', 'Driver 0912345678 accepts genuine PIN 5521 (200 OK)',
    driverAuth01.status === 200 && driverAuth01.body?.data?.token, `Status: ${driverAuth01.status}`);

  const driverAuth02 = await apiRequest('POST', '/api/v1/auth/login', { phone: '0923456789', password: '6632' });
  record('OP-4.2-GENUINE-DRIVER', 'Driver 0923456789 accepts genuine PIN 6632 (200 OK)',
    driverAuth02.status === 200 && driverAuth02.body?.data?.token, `Status: ${driverAuth02.status}`);

  // Authentic Merchant Logins
  const storePointers = [
    { store_id: 'store_nalut_ranchello', pin: '4821' },
    { store_id: 'store_nalut_alhanaa', pin: '6194' },
    { store_id: 'store_nalut_akakus', pin: '7312' },
    { store_id: 'store_nalut_rixos', pin: '8540' }
  ];
  for (const sp of storePointers) {
    const storeRes = await apiRequest('POST', '/api/v1/auth/merchant-login', sp);
    record('OP-4.3-GENUINE-MERCHANT', `Merchant ${sp.store_id} accepts genuine PIN ${sp.pin} (200 OK)`,
      storeRes.status === 200 && storeRes.body?.data?.token, `Status: ${storeRes.status}`);
  }

  // Authentic Super Admin Login
  const adminRes = await apiRequest('POST', '/api/v1/auth/login', {
    phone: '0910009832',
    password: 'Admin@Nalut2026!Secure'
  });
  record('OP-4.4-GENUINE-ADMIN', 'Super Admin accepts genuine secret Admin@Nalut2026!Secure (200 OK)',
    adminRes.status === 200 && adminRes.body?.data?.token, `Status: ${adminRes.status}`);

  // --------------------------------------------------------------------------
  // SUMMARY & VERDICT
  // --------------------------------------------------------------------------
  console.log('\n================================================================');
  console.log('📊 CHALLENGER M2-R2-1 EMPIRICAL RESULTS SUMMARY');
  console.log('================================================================');
  console.log(`Total Checks Executed:  ${results.total}`);
  console.log(`Passed:                 ${results.passed}`);
  console.log(`Failed:                 ${results.failed}`);
  const passRate = ((results.passed / results.total) * 100).toFixed(1);
  console.log(`Pass Rate:              ${passRate}%`);
  console.log('================================================================');

  if (results.failed > 0) {
    console.log('\n❌ DEFECTS DETECTED:');
    results.entries.forEach(e => console.log(` - [${e.suite}] ${e.desc}: ${e.actualInfo}`));
    console.log('\nVERDICT: REQUEST_CHANGES');
    process.exit(1);
  } else {
    console.log('\n🛡️ VERIFICATION VERDICT: APPROVE');
    console.log('All backdoor attempts rejected with 401.');
    console.log('All unauthenticated mutations rejected with 401/403.');
    console.log('All genuine credentials authorized cleanly.');
    process.exit(0);
  }
}

run().catch(err => {
  console.error('[Harness Error]', err);
  process.exit(1);
});
