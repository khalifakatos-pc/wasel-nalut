/**
 * ============================================================================
 * WASEL NALUT: CHALLENGER M2-R3-1 EMPIRICAL CUSTOMER AUTH & PENETRATION HARNESS
 * ============================================================================
 * Dedicated empirical challenger test verifying:
 * 1. Seeded customer (0910000000) strictly rejects backdoor PINs & passwords
 *    ('1234', 'Password123!', 'Admin123!', '7788', '9832') with HTTP 401.
 * 2. Seeded customer strictly rejects adversarial injection vectors (empty, null,
 *    array, object injection, SQLi, common passwords).
 * 3. Seeded customer successfully authenticates with 'Customer@Nalut2026!Secure'
 *    returning HTTP 200, valid JWT, and customer wallet info.
 * 4. Customer JWT capabilities are strictly isolated (GET /me 200, admin 403,
 *    driver mutation 403, store mutation 403).
 * ============================================================================
 */

const http = require('http');

const TEST_PORT = process.env.TEST_PORT || process.env.PORT || 3000;

let ipCounter = 200;
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

const BACKDOOR_CREDENTIALS = ['1234', 'Password123!', 'Admin123!', '7788', '9832'];
const CUSTOMER_PHONE = '0910000000';
const VALID_CUSTOMER_PASSWORD = 'Customer@Nalut2026!Secure';

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
  console.log('⚔️  CHALLENGER M2-R3-1: CUSTOMER AUTHENTICATION HARDENING HARNESS');
  console.log('================================================================\n');

  await ensureServer();

  // --------------------------------------------------------------------------
  // PART 1: LIVE BACKDOOR PENETRATION AGAINST SEEDED CUSTOMER (0910000000)
  // --------------------------------------------------------------------------
  console.log('--- PART 1: Backdoor Credential Penetration on Seeded Customer ---');

  for (const backdoor of BACKDOOR_CREDENTIALS) {
    const res = await apiRequest('POST', '/api/v1/auth/login', {
      phone: CUSTOMER_PHONE,
      password: backdoor
    });
    record(
      'PEN-M2R3-1.1-BACKDOOR',
      `Customer ${CUSTOMER_PHONE} rejects backdoor "${backdoor}" with HTTP 401`,
      res.status === 401,
      `Status: ${res.status}, Body: ${JSON.stringify(res.body)}`
    );
  }

  // --------------------------------------------------------------------------
  // PART 2: ADVERSARIAL INJECTION VECTORS AGAINST CUSTOMER AUTH
  // --------------------------------------------------------------------------
  console.log('\n--- PART 2: Adversarial & Edge Case Attacks on Customer Auth ---');

  const adversarialCases = [
    { label: 'Empty string password', body: { phone: CUSTOMER_PHONE, password: '' }, expectedStatuses: [400, 401] },
    { label: 'Null password', body: { phone: CUSTOMER_PHONE, password: null }, expectedStatuses: [400, 401] },
    { label: 'Missing password field', body: { phone: CUSTOMER_PHONE }, expectedStatuses: [400, 401] },
    { label: 'Whitespace password', body: { phone: CUSTOMER_PHONE, password: '   ' }, expectedStatuses: [401] },
    { label: 'SQL Injection string', body: { phone: CUSTOMER_PHONE, password: "' OR '1'='1" }, expectedStatuses: [401] },
    { label: 'SQL comment injection', body: { phone: CUSTOMER_PHONE, password: "admin'--" }, expectedStatuses: [401] },
    { label: 'Array injection', body: { phone: CUSTOMER_PHONE, password: ['Customer@Nalut2026!Secure'] }, expectedStatuses: [401] },
    { label: 'Object injection', body: { phone: CUSTOMER_PHONE, password: { "$ne": null } }, expectedStatuses: [401] },
    { label: 'Common password "password"', body: { phone: CUSTOMER_PHONE, password: 'password' }, expectedStatuses: [401] },
    { label: 'Common password "123456"', body: { phone: CUSTOMER_PHONE, password: '123456' }, expectedStatuses: [401] },
    { label: 'Case variation "customer@nalut2026!secure"', body: { phone: CUSTOMER_PHONE, password: 'customer@nalut2026!secure' }, expectedStatuses: [401] }
  ];

  for (const ac of adversarialCases) {
    const res = await apiRequest('POST', '/api/v1/auth/login', ac.body);
    const pass = ac.expectedStatuses.includes(res.status);
    record(
      'PEN-M2R3-1.2-ADVERSARIAL',
      `Customer auth rejects ${ac.label} with HTTP ${ac.expectedStatuses.join('/')}`,
      pass,
      `Status: ${res.status}, Body: ${JSON.stringify(res.body)}`
    );
  }

  // --------------------------------------------------------------------------
  // PART 3: GENUINE CUSTOMER LOGIN WITH ROTATED CREDENTIAL
  // --------------------------------------------------------------------------
  console.log('\n--- PART 3: Legitimate Customer Login Verification ---');

  const validRes = await apiRequest('POST', '/api/v1/auth/login', {
    phone: CUSTOMER_PHONE,
    password: VALID_CUSTOMER_PASSWORD
  });

  const hasToken = Boolean(validRes.body?.data?.token);
  const token = validRes.body?.data?.token;
  const user = validRes.body?.data?.user;
  const wallet = validRes.body?.data?.wallet;

  record(
    'PEN-M2R3-1.3-GENUINE-LOGIN',
    `Customer login with "${VALID_CUSTOMER_PASSWORD}" returns HTTP 200`,
    validRes.status === 200,
    `Status: ${validRes.status}, Body: ${JSON.stringify(validRes.body)}`
  );

  record(
    'PEN-M2R3-1.3-JWT-PRESENT',
    'Customer login response contains non-empty JWT bearer token',
    hasToken && typeof token === 'string' && token.split('.').length === 3,
    `Token: ${token ? 'Valid 3-part JWT' : 'Missing/Invalid'}`
  );

  record(
    'PEN-M2R3-1.3-USER-IDENTITY',
    `Customer identity matches seeded usr_guest_nalut (${CUSTOMER_PHONE})`,
    user && user.id === 'usr_guest_nalut' && user.phone === CUSTOMER_PHONE && user.role === 'customer',
    `User: ${JSON.stringify(user)}`
  );

  record(
    'PEN-M2R3-1.3-WALLET-INTEGRITY',
    'Customer wallet attached with valid positive balance',
    wallet && wallet.user_id === 'usr_guest_nalut' && wallet.balance === 250,
    `Wallet: ${JSON.stringify(wallet)}`
  );

  // --------------------------------------------------------------------------
  // PART 4: ROLE ISOLATION & PRIVILEGE BOUNDARY VERIFICATION
  // --------------------------------------------------------------------------
  console.log('\n--- PART 4: Role Isolation & Authorization Boundaries ---');

  if (hasToken) {
    // 4.1 Access /api/v1/auth/me with customer token
    const meRes = await apiRequest('GET', '/api/v1/auth/me', null, {
      'Authorization': `Bearer ${token}`
    });
    record(
      'PEN-M2R3-1.4-ME-PROFILE',
      'Customer JWT grants access to /api/v1/auth/me (HTTP 200)',
      meRes.status === 200 && meRes.body?.data?.user?.id === 'usr_guest_nalut',
      `Status: ${meRes.status}, Body: ${JSON.stringify(meRes.body)}`
    );

    // 4.2 Customer token blocked from Admin routes
    const adminPurgeRes = await apiRequest('POST', '/api/v1/admin/purge', {}, {
      'Authorization': `Bearer ${token}`
    });
    record(
      'PEN-M2R3-1.4-ROLE-ADMIN-BLOCK',
      'Customer JWT cannot invoke POST /api/v1/admin/purge (HTTP 403 Forbidden)',
      adminPurgeRes.status === 403,
      `Status: ${adminPurgeRes.status}`
    );

    const adminSeedRes = await apiRequest('POST', '/api/v1/admin/seed', {}, {
      'Authorization': `Bearer ${token}`
    });
    record(
      'PEN-M2R3-1.4-ROLE-ADMIN-SEED-BLOCK',
      'Customer JWT cannot invoke POST /api/v1/admin/seed (HTTP 403 Forbidden)',
      adminSeedRes.status === 403,
      `Status: ${adminSeedRes.status}`
    );

    // 4.3 Customer token blocked from Driver mutations
    const driverPatchRes = await apiRequest('PATCH', '/api/v1/drivers/driver_nalut_01', { status: 'online' }, {
      'Authorization': `Bearer ${token}`
    });
    record(
      'PEN-M2R3-1.4-ROLE-DRIVER-MUTATION-BLOCK',
      'Customer JWT cannot modify driver state via PATCH /api/v1/drivers/:id (HTTP 403)',
      driverPatchRes.status === 403,
      `Status: ${driverPatchRes.status}`
    );

    // 4.4 Customer token blocked from Store heartbeat mutation
    const storeHbRes = await apiRequest('POST', '/api/v1/stores/store_nalut_ranchello/heartbeat', {}, {
      'Authorization': `Bearer ${token}`
    });
    record(
      'PEN-M2R3-1.4-ROLE-STORE-HEARTBEAT-BLOCK',
      'Customer JWT cannot mutate store heartbeat (HTTP 403)',
      storeHbRes.status === 403,
      `Status: ${storeHbRes.status}`
    );
  }

  // --------------------------------------------------------------------------
  // FINAL SUMMARY
  // --------------------------------------------------------------------------
  console.log('\n================================================================');
  console.log('📊 CHALLENGER M2-R3-1 CUSTOMER PENETRATION RESULTS SUMMARY');
  console.log('================================================================');
  console.log(`Total Checks Executed:  ${results.total}`);
  console.log(`Passed:                 ${results.passed}`);
  console.log(`Failed:                 ${results.failed}`);
  console.log(`Pass Rate:              ${((results.passed / results.total) * 100).toFixed(1)}%`);
  console.log('================================================================\n');

  if (results.failed === 0) {
    console.log('🛡️ VERDICT: APPROVE');
    console.log('All backdoor attempts rejected with HTTP 401.');
    console.log('Customer account authenticated securely with genuine rotated password.');
    console.log('Customer JWT role boundaries strictly enforced.');
    process.exit(0);
  } else {
    console.error('❌ VERDICT: REQUEST_CHANGES');
    console.error('Failed checks detected:');
    results.entries.forEach(e => console.error(` - [${e.suite}] ${e.desc}: ${e.actualInfo}`));
    process.exit(1);
  }
}

run().catch(err => {
  console.error('[Harness] Fatal Error:', err);
  process.exit(1);
});
