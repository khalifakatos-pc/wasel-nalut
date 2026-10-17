/**
 * ============================================================================
 * WASEL NALUT: CHALLENGER M3-2 EMPIRICAL TEST & ADVERSARIAL HARNESS
 * ============================================================================
 * Focus: Merchant App (flutter_merchant_app) changes & Backend Auth Security:
 * 1. POST /api/v1/auth/merchant-login with valid/invalid PINs, store_id, phone,
 *    formatted numbers, and backdoor bypasses.
 * 2. Authorization: Bearer <token> enforcement on protected routes.
 * 3. Strict Tenant Isolation enforcement (cross-store management attacks).
 * 4. Role-based access control (merchant token blocked from admin endpoints).
 * 5. Static code audit & empirical verification of Flutter Merchant App changes.
 * ============================================================================
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const { config } = require('./config');

const TEST_PORT = process.env.TEST_PORT || process.env.PORT || 3000;
const JWT_SECRET = config.JWT_SECRET;

let ipCounter = 200;
function apiRequest(method, endpoint, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const reqHeaders = {
      'Content-Type': 'application/json',
      'x-forwarded-for': `10.42.1.${ipCounter++}`,
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

function recordTest(suite, name, passed, details = '') {
  results.total++;
  if (passed) {
    results.passed++;
    console.log(`  ✅ [PASS] [${suite}] ${name}`);
  } else {
    results.failed++;
    results.findings.push({ suite, name, details });
    console.log(`  ❌ [FAIL] [${suite}] ${name}: ${details}`);
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

async function runEmpiricalSuite() {
  console.log('================================================================');
  console.log('⚔️  WASEL NALUT: CHALLENGER M3-2 EMPIRICAL VERIFICATION HARNESS');
  console.log('================================================================\n');

  await ensureServerRunning();

  // ==========================================================================
  // SUITE 1: POST /api/v1/auth/merchant-login Authentication & Adversarial Edge Cases
  // ==========================================================================
  console.log('--- SUITE 1: POST /api/v1/auth/merchant-login Authentication ---');

  // 1.1 Valid login with store_id
  const resValidStore = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    store_id: 'store_nalut_ranchello',
    pin: '4821'
  });
  recordTest('Auth', 'Valid PIN with store_id returns 200 & JWT', 
    resValidStore.status === 200 && 
    resValidStore.body?.success === true && 
    typeof resValidStore.body?.data?.token === 'string' &&
    resValidStore.body?.data?.store?.id === 'store_nalut_ranchello',
    `Status ${resValidStore.status}, body: ${JSON.stringify(resValidStore.body)}`
  );

  const ranchelloToken = resValidStore.body?.data?.token;

  // 1.2 Valid login with phone
  const resValidPhone = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    phone: '0912345002',
    pin: '4821'
  });
  recordTest('Auth', 'Valid PIN with phone returns 200 & JWT',
    resValidPhone.status === 200 &&
    resValidPhone.body?.success === true &&
    resValidPhone.body?.data?.store?.id === 'store_nalut_ranchello',
    `Status ${resValidPhone.status}`
  );

  // 1.3 Formatted Libyan phone (+218-91-2345002)
  const resFormattedPhone = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    phone: '+218-91-2345002',
    pin: '4821'
  });
  recordTest('Auth', 'Formatted phone with country code (+218-91-2345002) resolves store',
    resFormattedPhone.status === 200 &&
    resFormattedPhone.body?.success === true &&
    resFormattedPhone.body?.data?.store?.id === 'store_nalut_ranchello',
    `Status ${resFormattedPhone.status}`
  );

  // 1.4 Invalid PIN with store_id
  const resInvalidPinStore = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    store_id: 'store_nalut_ranchello',
    pin: '0000'
  });
  recordTest('Auth', 'Invalid PIN with store_id returns 401',
    resInvalidPinStore.status === 401 && resInvalidPinStore.body?.success === false,
    `Status ${resInvalidPinStore.status}`
  );

  // 1.5 Invalid PIN with phone
  const resInvalidPinPhone = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    phone: '0912345002',
    pin: '9999'
  });
  recordTest('Auth', 'Invalid PIN with phone returns 401',
    resInvalidPinPhone.status === 401 && resInvalidPinPhone.body?.success === false,
    `Status ${resInvalidPinPhone.status}`
  );

  // 1.6 Backdoor PIN attempts on stores
  const backdoors = ['1234', '7788', '9832', 'Password123!', 'Admin123!'];
  for (const bd of backdoors) {
    const resBd = await apiRequest('POST', '/api/v1/auth/merchant-login', {
      store_id: 'store_nalut_ranchello',
      pin: bd
    });
    recordTest('Backdoors', `Backdoor PIN "${bd}" rejected with 401 on store_nalut_ranchello`,
      resBd.status === 401 && resBd.body?.success === false,
      `Status ${resBd.status}`
    );
  }

  // 1.7 Missing credentials
  const resMissing = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    pin: '4821'
  });
  recordTest('Auth', 'Missing store_id and phone returns 400 Bad Request',
    resMissing.status === 400 && resMissing.body?.success === false,
    `Status ${resMissing.status}`
  );

  // 1.8 Non-existent store ID
  const resNonExistent = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    store_id: 'store_nonexistent_999',
    pin: '4821'
  });
  recordTest('Auth', 'Non-existent store ID returns 404 Not Found',
    resNonExistent.status === 404 && resNonExistent.body?.success === false,
    `Status ${resNonExistent.status}`
  );

  // 1.9 Non-existent phone number
  const resNonExistentPhone = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    phone: '0999999999',
    pin: '4821'
  });
  recordTest('Auth', 'Non-existent phone returns 404 Not Found',
    resNonExistentPhone.status === 404 && resNonExistentPhone.body?.success === false,
    `Status ${resNonExistentPhone.status}`
  );

  // 1.10 SQL injection payload attempt
  const resSqli = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    store_id: "' OR '1'='1",
    pin: "' OR '1'='1"
  });
  recordTest('Security', 'SQL injection attack string returns 404 or 401',
    (resSqli.status === 404 || resSqli.status === 401) && resSqli.body?.success === false,
    `Status ${resSqli.status}`
  );

  // ==========================================================================
  // SUITE 2: Protected Routes & Bearer Token Enforcement
  // ==========================================================================
  console.log('\n--- SUITE 2: Protected Routes & Bearer Token Enforcement ---');

  // 2.1 GET /api/v1/auth/me without token
  const resMeNoToken = await apiRequest('GET', '/api/v1/auth/me');
  recordTest('ProtectedRoutes', 'GET /api/v1/auth/me without token returns 401',
    resMeNoToken.status === 401 && resMeNoToken.body?.success === false,
    `Status ${resMeNoToken.status}`
  );

  // 2.2 GET /api/v1/auth/me with invalid token
  const resMeInvalidToken = await apiRequest('GET', '/api/v1/auth/me', null, {
    'Authorization': 'Bearer invalid_garbage_token_12345'
  });
  recordTest('ProtectedRoutes', 'GET /api/v1/auth/me with invalid token returns 401',
    resMeInvalidToken.status === 401 && resMeInvalidToken.body?.success === false,
    `Status ${resMeInvalidToken.status}`
  );

  // 2.3 GET /api/v1/auth/me with valid merchant token
  const resMeValid = await apiRequest('GET', '/api/v1/auth/me', null, {
    'Authorization': `Bearer ${ranchelloToken}`
  });
  recordTest('ProtectedRoutes', 'GET /api/v1/auth/me with merchant token returns 200 & role "merchant"',
    resMeValid.status === 200 && resMeValid.body?.data?.user?.role === 'merchant',
    `Status ${resMeValid.status}`
  );

  // 2.4 POST /api/v1/orders/checkout without token returns 401
  const resCheckoutNoToken = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: 'store_nalut_ranchello',
    items: [{ id: 'prod_ranchello_shawarma_beef', quantity: 1, price_lyd: 18.0 }]
  });
  recordTest('ProtectedRoutes', 'POST /api/v1/orders/checkout without token returns 401',
    resCheckoutNoToken.status === 401,
    `Status ${resCheckoutNoToken.status}`
  );

  // 2.5 POST /api/v1/orders/:id/handover without token returns 401
  const resHandoverNoToken = await apiRequest('POST', '/api/v1/orders/ORD-001/handover', {
    handover_code: '1234'
  });
  recordTest('ProtectedRoutes', 'POST /api/v1/orders/:id/handover without token returns 401',
    resHandoverNoToken.status === 401,
    `Status ${resHandoverNoToken.status}`
  );

  // 2.6 POST /api/v1/orders/:id/status without token returns 401
  const resStatusNoToken = await apiRequest('POST', '/api/v1/orders/ORD-001/status', {
    status: 'preparing'
  });
  recordTest('ProtectedRoutes', 'POST /api/v1/orders/:id/status without token returns 401',
    resStatusNoToken.status === 401,
    `Status ${resStatusNoToken.status}`
  );

  // ==========================================================================
  // SUITE 3: Tenant Isolation & RBAC Protection
  // ==========================================================================
  console.log('\n--- SUITE 3: Tenant Isolation & RBAC Protection ---');

  // Authenticate as a second store: store_nalut_alhanaa
  const resAlhanaaLogin = await apiRequest('POST', '/api/v1/auth/merchant-login', {
    store_id: 'store_nalut_alhanaa',
    pin: '6194'
  });
  const alhanaaToken = resAlhanaaLogin.body?.data?.token;

  // 3.1 Store A merchant manages Store A -> Allowed (200)
  const resStoreAOwn = await apiRequest('POST', '/api/v1/stores/store_nalut_ranchello/heartbeat', null, {
    'Authorization': `Bearer ${ranchelloToken}`
  });
  recordTest('TenantIsolation', 'Store A merchant heartbeats Store A -> 200 OK',
    resStoreAOwn.status === 200 && resStoreAOwn.body?.success === true,
    `Status ${resStoreAOwn.status}`
  );

  // 3.2 Cross-tenant attack: Store A merchant attempts to manage Store B -> FORBIDDEN (403)
  const resCrossTenantHeartbeat = await apiRequest('POST', '/api/v1/stores/store_nalut_alhanaa/heartbeat', null, {
    'Authorization': `Bearer ${ranchelloToken}`
  });
  recordTest('TenantIsolation', 'Cross-tenant attack: Store A merchant heartbeats Store B -> 403 Forbidden',
    resCrossTenantHeartbeat.status === 403 && resCrossTenantHeartbeat.body?.success === false,
    `Status ${resCrossTenantHeartbeat.status}, error: ${resCrossTenantHeartbeat.body?.error}`
  );

  // 3.3 Cross-tenant patch: Store A merchant tries to patch Store B status -> FORBIDDEN (403)
  const resCrossTenantPatch = await apiRequest('PATCH', '/api/v1/stores/store_nalut_alhanaa', { is_open: false }, {
    'Authorization': `Bearer ${ranchelloToken}`
  });
  recordTest('TenantIsolation', 'Cross-tenant attack: Store A merchant patches Store B -> 403 Forbidden',
    resCrossTenantPatch.status === 403 && resCrossTenantPatch.body?.success === false,
    `Status ${resCrossTenantPatch.status}, error: ${resCrossTenantPatch.body?.error}`
  );

  // 3.4 Merchant attempts to invoke admin route (/api/v1/admin/purge) -> FORBIDDEN (403)
  const resMerchantAdminPurge = await apiRequest('POST', '/api/v1/admin/purge', {}, {
    'Authorization': `Bearer ${ranchelloToken}`
  });
  recordTest('RBAC', 'Merchant token invoking /api/v1/admin/purge returns 403 Forbidden',
    resMerchantAdminPurge.status === 403 && resMerchantAdminPurge.body?.success === false,
    `Status ${resMerchantAdminPurge.status}`
  );

  // 3.5 Customer token attempting to modify store -> FORBIDDEN (403)
  const customerToken = jwt.sign({ id: 'usr_cust_1', role: 'customer' }, JWT_SECRET, { expiresIn: '1h' });
  const resCustomerStoreMod = await apiRequest('POST', '/api/v1/stores/store_nalut_ranchello/heartbeat', null, {
    'Authorization': `Bearer ${customerToken}`
  });
  recordTest('RBAC', 'Customer token attempting store management returns 403 Forbidden',
    resCustomerStoreMod.status === 403,
    `Status ${resCustomerStoreMod.status}`
  );

  // ==========================================================================
  // SUITE 4: Codebase Static & Forensic Audit (Merchant App)
  // ==========================================================================
  console.log('\n--- SUITE 4: Flutter Merchant App Codebase Verification ---');

  const merchantDir = path.resolve(__dirname, '../flutter_merchant_app');
  const kdsScreenPath = path.join(merchantDir, 'lib/kds_screen.dart');
  const loginScreenPath = path.join(merchantDir, 'lib/merchant_login_screen.dart');
  const mainDartPath = path.join(merchantDir, 'lib/main.dart');
  const servicePath = path.join(merchantDir, 'lib/services/merchant_supabase_service.dart');

  const kdsContent = fs.readFileSync(kdsScreenPath, 'utf8');
  const loginContent = fs.readFileSync(loginScreenPath, 'utf8');
  const mainContent = fs.readFileSync(mainDartPath, 'utf8');
  const serviceContent = fs.readFileSync(servicePath, 'utf8');

  // 4.1 Verify simulated kitchen orders cannot be triggered in kds_screen.dart
  const hasSimulateMethod = kdsContent.includes('_simulateNewIncomingOrder');
  const hasTestOrderFab = kdsContent.includes('طلب تجريبي للمطبخ');
  recordTest('ClientPurge', 'kds_screen.dart: _simulateNewIncomingOrder purged',
    !hasSimulateMethod,
    hasSimulateMethod ? 'Found _simulateNewIncomingOrder' : ''
  );
  recordTest('ClientPurge', 'kds_screen.dart: FAB "طلب تجريبي للمطبخ 🔔" purged',
    !hasTestOrderFab,
    hasTestOrderFab ? 'Found test order FAB' : ''
  );

  // 4.2 Verify synthetic receipt rcp_nalut_001 purged
  const hasSyntheticReceipt = serviceContent.includes('rcp_nalut_001');
  recordTest('ClientPurge', 'merchant_supabase_service.dart: synthetic receipt rcp_nalut_001 purged',
    !hasSyntheticReceipt,
    hasSyntheticReceipt ? 'Found rcp_nalut_001' : ''
  );

  // 4.3 Verify fast store switcher purged from merchant_login_screen.dart
  const hasFastStoreSelect = loginContent.includes('_handleFastStoreSelect');
  const hasFastStoreChips = loginContent.includes('مطعم رانشيلو 🌯');
  recordTest('ClientPurge', 'merchant_login_screen.dart: _handleFastStoreSelect purged',
    !hasFastStoreSelect,
    hasFastStoreSelect ? 'Found _handleFastStoreSelect' : ''
  );
  recordTest('ClientPurge', 'merchant_login_screen.dart: 1-click store shortcut chips purged',
    !hasFastStoreChips,
    hasFastStoreChips ? 'Found 1-click shortcut chips' : ''
  );

  // 4.4 Verify fast store switcher and modal purged from main.dart
  const hasSwitchStore = mainContent.includes('_switchStore');
  const hasStoreModal = mainContent.includes('_showStoreSwitcherModal');
  const hasSwitchButton = mainContent.includes("'تبديل'") || mainContent.includes('"تبديل"');
  recordTest('ClientPurge', 'main.dart: _switchStore method purged',
    !hasSwitchStore,
    hasSwitchStore ? 'Found _switchStore' : ''
  );
  recordTest('ClientPurge', 'main.dart: _showStoreSwitcherModal purged',
    !hasStoreModal,
    hasStoreModal ? 'Found _showStoreSwitcherModal' : ''
  );
  recordTest('ClientPurge', 'main.dart: "تبديل" quick switcher button purged',
    !hasSwitchButton,
    hasSwitchButton ? 'Found تبديل button' : ''
  );

  // 4.5 Verify Authorization: Bearer <token> attached to requests in merchant_supabase_service.dart
  const hasBackendHeaders = serviceContent.includes('backendHeaders');
  const hasBearerHeader = serviceContent.includes("'Authorization': 'Bearer \$jwtToken'") || 
                          serviceContent.includes('"Authorization": "Bearer \$jwtToken"');
  recordTest('ClientAuth', 'merchant_supabase_service.dart: defines backendHeaders with Bearer $jwtToken',
    hasBackendHeaders && hasBearerHeader,
    `hasBackendHeaders: ${hasBackendHeaders}, hasBearerHeader: ${hasBearerHeader}`
  );

  // 4.6 Verify updateProductStock returns false on failure
  const defIdx = serviceContent.indexOf('static Future<bool> updateProductStock(');
  const updateProductStockCode = serviceContent.substring(
    defIdx,
    defIdx + 1200
  ).replace(/\r\n/g, '\n');
  const returnsFalseOnFailure = updateProductStockCode.includes('return false;\n  }');
  recordTest('StockLogic', 'merchant_supabase_service.dart: updateProductStock returns false on failure (unconditional true removed)',
    returnsFalseOnFailure,
    'updateProductStock must return false on error'
  );

  // 4.7 Adversarial UI check: Does UI handle / await updateProductStock return value?
  // Let's inspect main.dart line where updateProductStock is invoked:
  const mainProductUpdateCall = mainContent.substring(
    mainContent.indexOf('_onProductUpdated('),
    mainContent.indexOf('_onProductUpdated(') + 400
  );
  const isAwaitedInMain = mainProductUpdateCall.includes('await MerchantSupabaseService.updateProductStock') ||
                          mainProductUpdateCall.includes('.then(');

  // We record this as an empirical finding:
  recordTest('StockUIPropagation', 'Adversarial: UI captures and handles updateProductStock return value or failure callback',
    isAwaitedInMain,
    'In main.dart: _onProductUpdated invokes MerchantSupabaseService.updateProductStock without await or error handler, so failure boolean is discarded by UI.'
  );

  // ==========================================================================
  // FINAL SUMMARY
  // ==========================================================================
  console.log('\n================================================================');
  console.log(`TOTAL CHECKS: ${results.total}`);
  console.log(`PASSED:       ${results.passed}`);
  console.log(`FAILED:       ${results.failed}`);
  console.log('================================================================');

  if (results.findings.length > 0) {
    console.log('\nFindings / Adversarial Observations:');
    results.findings.forEach((f, i) => {
      console.log(`  ${i + 1}. [${f.suite}] ${f.name}: ${f.details}`);
    });
  }

  return results;
}

if (require.main === module) {
  runEmpiricalSuite().then(res => {
    process.exit(res.failed > 0 ? 1 : 0);
  }).catch(err => {
    console.error('Harness fatal error:', err);
    process.exit(2);
  });
}

module.exports = { runEmpiricalSuite };
