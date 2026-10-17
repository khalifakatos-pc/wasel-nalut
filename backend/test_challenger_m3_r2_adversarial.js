/**
 * ============================================================================
 * CHALLENGER M3-R2-2: DEEP ADVERSARIAL STRESS TEST & ATTACK HARNESS
 * ============================================================================
 * Focus:
 * 1. POST /api/v1/auth/merchant-login exhaustive variations (Libyan formats,
 *    prefixes +218 / 00218, Arabic-Indic numerals, Persian numerals, mixed,
 *    spacing, punctuation, exact store IDs, case insensitivity, field swapping).
 * 2. Backdoor rejection across all stores (1234, 7788, 9832, Password123!, etc.).
 * 3. Partial digit matching resistance (short strings, sub-7 digit numbers).
 * 4. Token security: expired, malformed, 'none' algorithm, cross-role tampering.
 * 5. Tenant isolation on inventory and catalog updates.
 * ============================================================================
 */

const http = require('http');
const jwt = require('jsonwebtoken');
const { config } = require('./config');

const TEST_PORT = process.env.TEST_PORT || process.env.PORT || 3000;
const JWT_SECRET = config.JWT_SECRET;

let ipCounter = 500;
function apiRequest(method, endpoint, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const reqHeaders = {
      'Content-Type': 'application/json',
      'x-forwarded-for': `10.42.2.${ipCounter++}`,
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

const results = {
  total: 0,
  passed: 0,
  failed: 0,
  findings: []
};

function recordTest(category, name, passed, details = '') {
  results.total++;
  if (passed) {
    results.passed++;
    console.log(`  ✅ [PASS] [${category}] ${name}`);
  } else {
    results.failed++;
    results.findings.push({ category, name, details });
    console.log(`  ❌ [FAIL] [${category}] ${name}: ${details}`);
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
    await new Promise(r => setTimeout(r, 1000));
  }
}

async function runAdversarialSuite() {
  console.log('================================================================');
  console.log('⚔️  CHALLENGER M3-R2-2: ADVERSARIAL STRESS TEST & ATTACK SUITE');
  console.log('================================================================\n');

  await ensureServerRunning();

  // --------------------------------------------------------------------------
  // SUITE 1: Comprehensive Phone Normalization Variations
  // --------------------------------------------------------------------------
  console.log('--- SUITE 1: Libyan Phone Normalization Variations ---');

  // Store: Ranchello (Phone: 0912345002, PIN: 4821)
  const ranchelloVariations = [
    { label: 'E.164 with plus & hyphens (+218-91-2345002)', input: '+218-91-2345002' },
    { label: 'E.164 compact (+218912345002)', input: '+218912345002' },
    { label: 'International 00 prefix (00218912345002)', input: '00218912345002' },
    { label: 'International 00 prefix hyphenated (00218-91-2345002)', input: '00218-91-2345002' },
    { label: 'International 00 prefix spaced (00218 91 234 5002)', input: '00218 91 234 5002' },
    { label: 'Dotted notation (+218.91.234.5002)', input: '+218.91.234.5002' },
    { label: 'Standard local with leading zero (0912345002)', input: '0912345002' },
    { label: 'Local with spaces (091 234 5002)', input: '091 234 5002' },
    { label: 'Local with hyphens (091-234-5002)', input: '091-234-5002' },
    { label: 'National subscriber without leading zero (912345002)', input: '912345002' },
    { label: 'Parenthetical format ((091) 234-5002)', input: '(091) 234-5002' },
    { label: 'Arabic-Indic numerals (٠٩١٢٣٤٥٠٠٢)', input: '٠٩١٢٣٤٥٠٠٢' },
    { label: 'Arabic-Indic with plus (+٢١٨-٩١-٢٣٤٥٠٠٢)', input: '+٢١٨-٩١-٢٣٤٥٠٠٢' },
    { label: 'Arabic-Indic subscriber (٩١٢٣٤٥٠٠٢)', input: '٩١٢٣٤٥٠٠٢' },
    { label: 'Eastern Arabic/Persian numerals (۰۹۱۲۳۴۵۰۰۲)', input: '۰۹۱۲۳۴۵۰۰۲' },
    { label: 'Eastern Arabic/Persian with plus (+۲۱۸-۹۱-۲۳۴۵۰۰۲)', input: '+۲۱۸-۹۱-۲۳۴۵۰۰۲' },
    { label: 'Mixed ASCII and Arabic (091٢٣4٥002)', input: '091٢٣4٥002' }
  ];

  for (const v of ranchelloVariations) {
    const res = await apiRequest('POST', '/api/v1/auth/merchant-login', {
      phone: v.input,
      pin: '4821'
    });
    recordTest('PhoneNorm', `Ranchello login: ${v.label}`,
      res.status === 200 && res.body?.success === true && res.body?.data?.store?.id === 'store_nalut_ranchello',
      `Status: ${res.status}, body: ${JSON.stringify(res.body)}`
    );
  }

  // Also test across ALL 4 stores with their authentic PINs using various formats
  const storeMatrix = [
    { id: 'store_nalut_alhanaa', phone: '+218-91-2345001', pin: '6194', name: 'صيدلية الهناء' },
    { id: 'store_nalut_ranchello', phone: '00218912345002', pin: '4821', name: 'مطعم ومقهى رانشيلو' },
    { id: 'store_nalut_akakus', phone: '٠٩١٢٣٤٥٠٠٣', pin: '7312', name: 'بيتزا أكاكوس' },
    { id: 'store_nalut_rixos', phone: '+۲۱۸-۹۱-۲۳۴۵۰۰۴', pin: '8540', name: 'ريكسوس للتسوق' }
  ];

  for (const s of storeMatrix) {
    const res = await apiRequest('POST', '/api/v1/auth/merchant-login', {
      phone: s.phone,
      pin: s.pin
    });
    recordTest('StoreMatrix', `Store ${s.id} authenticates via ${s.phone}`,
      res.status === 200 && res.body?.success === true && res.body?.data?.store?.id === s.id,
      `Status: ${res.status}`
    );
  }

  // --------------------------------------------------------------------------
  // SUITE 2: Exact Store IDs & Case Sensitivity & Field Swapping
  // --------------------------------------------------------------------------
  console.log('\n--- SUITE 2: Exact Store IDs & Field Swapping ---');

  // Exact lowercase
  const resExactLower = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    store_id: 'store_nalut_ranchello',
    pin: '4821'
  });
  recordTest('StoreId', 'Exact store_id lowercase',
    resExactLower.status === 200 && resExactLower.body?.data?.store?.id === 'store_nalut_ranchello'
  );

  // Exact UPPERCASE
  const resExactUpper = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    store_id: 'STORE_NALUT_RANCHHELLO',
    pin: '4821'
  });
  // Note: store_nalut_ranchello has 1 'h' in db: let's test STORE_NALUT_RANCHHELLO or STORE_NALUT_RANCHHELLO
  const resExactUpperCorrect = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    store_id: 'STORE_NALUT_RANCHHELLO'.replace('RANCHHELLO', 'RANCHHELLO'), // let's check spelling
    pin: '4821'
  });
  const resUpperSpelled = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    store_id: 'STORE_NALUT_RANCHHELLO',
    pin: '4821'
  });
  const resUpperActual = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    store_id: 'STORE_NALUT_RANCHELLO',
    pin: '4821'
  });
  recordTest('StoreId', 'Case-insensitive store_id uppercase (STORE_NALUT_RANCHELLO)',
    resUpperActual.status === 200 && resUpperActual.body?.data?.store?.id === 'store_nalut_ranchello'
  );

  // Field swapping: passing phone in store_id field
  const resPhoneInStoreId = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    store_id: '+218-91-2345002',
    pin: '4821'
  });
  recordTest('FieldSwap', 'Passing phone in store_id field resolves store',
    resPhoneInStoreId.status === 200 && resPhoneInStoreId.body?.data?.store?.id === 'store_nalut_ranchello'
  );

  // Field swapping: passing store_id in phone field
  const resStoreIdInPhone = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    phone: 'store_nalut_ranchello',
    pin: '4821'
  });
  recordTest('FieldSwap', 'Passing store_id in phone field resolves store',
    resStoreIdInPhone.status === 200 && resStoreIdInPhone.body?.data?.store?.id === 'store_nalut_ranchello'
  );

  // --------------------------------------------------------------------------
  // SUITE 3: Adversarial Rejection & Boundary Resistance
  // --------------------------------------------------------------------------
  console.log('\n--- SUITE 3: Adversarial Rejection & Boundary Resistance ---');

  // 3.1 Partial digit matching attacks (must NOT match)
  const shortInputs = ['91', '091', '2345', '912345', '5002'];
  for (const s of shortInputs) {
    const resShort = await apiRequest('POST', '/api/v1/auth/merchant-login', {
      phone: s,
      pin: '4821'
    });
    recordTest('Boundary', `Short digit string "${s}" (< 7 digits) rejected with 404`,
      resShort.status === 404 && resShort.body?.success === false,
      `Status: ${resShort.status}`
    );
  }

  // 3.2 Wrong PIN with normalized phone
  const resWrongPin = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    phone: '+218-91-2345002',
    pin: '9999'
  });
  recordTest('AuthReject', 'Normalized phone with wrong PIN returns 401',
    resWrongPin.status === 401 && resWrongPin.body?.success === false
  );

  // 3.3 Backdoor PINs on each store
  const allBackdoors = ['1234', '7788', '9832', 'Password123!', 'Admin123!', '0000', '1111'];
  for (const bd of allBackdoors) {
    const res = await apiRequest('POST', '/api/v1/auth/merchant-login', {
      phone: '0912345001', // Al-Hanaa
      pin: bd
    });
    recordTest('BackdoorBlock', `Al-Hanaa rejects backdoor PIN "${bd}" with 401`,
      res.status === 401 && res.body?.success === false
    );
  }

  // 3.4 Store A phone with Store B PIN cross-authentication attack
  const resCrossAuth = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    phone: '0912345002', // Ranchello phone
    pin: '6194'          // Al-Hanaa PIN
  });
  recordTest('CrossAuth', 'Cross-store auth (Store A phone + Store B PIN) rejected with 401',
    resCrossAuth.status === 401 && resCrossAuth.body?.success === false
  );

  // 3.5 Malicious payloads & fuzzing
  const fuzzPayloads = [
    { label: 'Long buffer (5000 chars)', body: { phone: '091' + '9'.repeat(5000), pin: '4821' }, expected: [400, 404] },
    { label: 'HTML script injection', body: { phone: '<script>alert("xss")</script>', pin: '4821' }, expected: [400, 404] },
    { label: 'SQL single-quote injection', body: { phone: "0912345002' OR 1=1--", pin: '4821' }, expected: [400, 401, 404] },
    { label: 'Null character payload', body: { phone: "0912345002\0", pin: '4821' }, expected: [200, 400, 404] },
    { label: 'Whitespace only identifier', body: { phone: "    ", pin: '4821' }, expected: [400, 404] }
  ];

  for (const f of fuzzPayloads) {
    const res = await apiRequest('POST', '/api/v1/auth/merchant-login', f.body);
    recordTest('Fuzzing', `Malicious payload: ${f.label} handled gracefully`,
      f.expected.includes(res.status),
      `Status: ${res.status}`
    );
  }

  // --------------------------------------------------------------------------
  // SUITE 4: Token Tampering & Cryptographic Security
  // --------------------------------------------------------------------------
  console.log('\n--- SUITE 4: Token Tampering & Cryptographic Security ---');

  // Obtain genuine token for Ranchello
  const ranchelloAuth = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    store_id: 'store_nalut_ranchello',
    pin: '4821'
  });
  const validToken = ranchelloAuth.body?.data?.token;

  // 4.1 Tampered signature
  const tamperedToken = validToken.slice(0, -6) + 'abcdef';
  const resTampered = await apiRequest('GET', '/api/v1/auth/me', null, {
    'Authorization': `Bearer ${tamperedToken}`
  });
  recordTest('TokenCrypto', 'Tampered JWT signature rejected with 401',
    resTampered.status === 401 && resTampered.body?.success === false
  );

  // 4.2 Algorithm 'none' token
  const noneHeader = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const nonePayload = Buffer.from(JSON.stringify({
    id: 'merch_store_nalut_ranchello',
    store_id: 'store_nalut_ranchello',
    role: 'merchant'
  })).toString('base64url');
  const algNoneToken = `${noneHeader}.${nonePayload}.`;

  const resAlgNone = await apiRequest('GET', '/api/v1/auth/me', null, {
    'Authorization': `Bearer ${algNoneToken}`
  });
  recordTest('TokenCrypto', 'Algorithm "none" attack rejected with 401',
    resAlgNone.status === 401 && resAlgNone.body?.success === false
  );

  // 4.3 Expired token
  const expiredToken = jwt.sign(
    { id: 'merch_store_nalut_ranchello', store_id: 'store_nalut_ranchello', role: 'merchant' },
    JWT_SECRET,
    { expiresIn: -10 } // already expired
  );
  const resExpired = await apiRequest('GET', '/api/v1/auth/me', null, {
    'Authorization': `Bearer ${expiredToken}`
  });
  recordTest('TokenCrypto', 'Expired JWT token rejected with 401',
    resExpired.status === 401 && resExpired.body?.success === false
  );

  // --------------------------------------------------------------------------
  // SUITE 5: Cross-Tenant Inventory Mutation Attacks
  // --------------------------------------------------------------------------
  console.log('\n--- SUITE 5: Cross-Tenant Inventory Mutation Attacks ---');

  // Ranchello token trying to modify Al-Hanaa products/store
  const resCrossStoreHeartbeat = await apiRequest('POST', '/api/v1/stores/store_nalut_alhanaa/heartbeat', null, {
    'Authorization': `Bearer ${validToken}`
  });
  recordTest('TenantSecurity', 'Cross-store heartbeat attack rejected with 403',
    resCrossStoreHeartbeat.status === 403
  );

  const resCrossStoreStatus = await apiRequest('PATCH', '/api/v1/stores/store_nalut_alhanaa', { is_open: false }, {
    'Authorization': `Bearer ${validToken}`
  });
  recordTest('TenantSecurity', 'Cross-store status patch attack rejected with 403',
    resCrossStoreStatus.status === 403
  );

  // --------------------------------------------------------------------------
  // SUMMARY
  // --------------------------------------------------------------------------
  console.log('\n================================================================');
  console.log(`TOTAL ADVERSARIAL CHECKS: ${results.total}`);
  console.log(`PASSED:                   ${results.passed}`);
  console.log(`FAILED:                   ${results.failed}`);
  console.log('================================================================');

  if (results.findings.length > 0) {
    console.log('\nAdversarial Failures:');
    results.findings.forEach((f, i) => {
      console.log(`  ${i + 1}. [${f.category}] ${f.name}: ${f.details}`);
    });
  }

  return results;
}

if (require.main === module) {
  runAdversarialSuite().then(res => {
    process.exit(res.failed > 0 ? 1 : 0);
  }).catch(err => {
    console.error('Adversarial suite error:', err);
    process.exit(2);
  });
}

module.exports = { runAdversarialSuite };
