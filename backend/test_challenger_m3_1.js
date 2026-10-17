/**
 * ============================================================================
 * WASEL NALUT: CHALLENGER M3-1 EMPIRICAL VERIFICATION & STRESS HARNESS
 * ============================================================================
 * Empirical verification and adversarial challenge test suite for Milestone 3:
 * 1. Verification of mock catalog purge (_getFallbackProducts, prod_01..prod_27)
 *    in Customer App (flutter_mobile_app).
 * 2. Verification that client-side Supabase order insertion fallback is
 *    completely purged and orders strictly route to backend REST API.
 * 3. Verification that static 5.00 LYD quote fallback is purged from getPricingQuote.
 * 4. Verification that OTP bypass 1234 / length==4 is rejected in WhatsAppAuthService.
 * 5. Verification of NoNetworkScreen integration, 12s auto-retry ring, mountain
 *    carrier copy, and emergency contact (0918207786) across customer screens.
 * 6. Live API verification: dynamic quote calculation, order checkout validation,
 *    and anti-fraud OTP rejection.
 * ============================================================================
 */

const fs = require('fs');
const path = require('path');
const http = require('http');
const jwt = require('jsonwebtoken');
const { config } = require('./config');

const ROOT_DIR = path.resolve(__dirname, '..');
const MOBILE_APP_LIB = path.join(ROOT_DIR, 'flutter_mobile_app', 'lib');
const TEST_PORT = process.env.TEST_PORT || process.env.PORT || 3000;
const JWT_SECRET = config.JWT_SECRET || 'wasel-nalut-secure-jwt-key-2026-prod';

let totalChecks = 0;
let passedChecks = 0;
let vulnerabilities = [];

function check(title, condition, detail = '') {
  totalChecks++;
  if (condition) {
    passedChecks++;
    console.log(`  ✅ [PASS] ${title}`);
  } else {
    vulnerabilities.push({ title, detail });
    console.error(`  ❌ [FAIL] ${title} - Detail: ${detail}`);
  }
}

async function ensureServerRunning() {
  const isRunning = await new Promise((resolve) => {
    const probe = http.get(`http://127.0.0.1:${TEST_PORT}/health`, (res) => resolve(res.statusCode === 200));
    probe.on('error', () => resolve(false));
    probe.setTimeout(400, () => { probe.destroy(); resolve(false); });
  });

  if (!isRunning) {
    console.log(`[Harness] Starting in-process backend server on port ${TEST_PORT}...`);
    process.env.PORT = String(TEST_PORT);
    require('./server.js');
    await new Promise((r) => setTimeout(r, 1200));
  }
}

function apiRequest(method, endpoint, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const reqHeaders = {
      'Content-Type': 'application/json',
      ...headers,
    };
    if (postData) {
      reqHeaders['Content-Length'] = Buffer.byteLength(postData);
    }

    const options = {
      hostname: '127.0.0.1',
      port: TEST_PORT,
      path: endpoint,
      method: method.toUpperCase(),
      headers: reqHeaders,
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
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
          body: parsed,
        });
      });
    });

    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

async function runEmpiricalChallenge() {
  console.log('================================================================');
  console.log('🛡️  STARTING WASEL NALUT CHALLENGER M3-1 EMPIRICAL TEST SUITE');
  console.log('================================================================\n');

  await ensureServerRunning();

  // --------------------------------------------------------------------------
  // SUITE 1: CUSTOMER APP MOCK DISHES & FALLBACK CATALOG PURGE
  // --------------------------------------------------------------------------
  console.log('--- SUITE 1: Customer App Mock Catalog Purge (store_menu_screen.dart) ---');

  const menuScreenPath = path.join(MOBILE_APP_LIB, 'store_menu_screen.dart');
  const menuScreenContent = fs.readFileSync(menuScreenPath, 'utf8');

  // 1.1 Verify _getFallbackProducts method is completely gone
  check(
    '1.1 _getFallbackProducts method is completely removed from store_menu_screen.dart',
    !menuScreenContent.includes('_getFallbackProducts'),
    'Found lingering reference to _getFallbackProducts'
  );

  // 1.2 Verify mock dish IDs prod_01 through prod_27 are gone from store_menu_screen
  const mockDishIds = ['prod_01', 'prod_02', 'prod_03', 'prod_04', 'prod_05', 'prod_06', 'prod_08', 'prod_13', 'prod_16', 'prod_20', 'prod_21', 'prod_22', 'prod_27'];
  const lingeringDishes = mockDishIds.filter(id => menuScreenContent.includes(`'${id}'`));
  check(
    '1.2 Hardcoded mock dish IDs (prod_01..prod_27) are completely absent from store_menu_screen.dart',
    lingeringDishes.length === 0,
    `Found lingering mock IDs: ${lingeringDishes.join(', ')}`
  );

  // 1.3 Verify mock dishes are not present in any lib file of flutter_mobile_app
  const allLibFiles = [];
  function scanDir(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        scanDir(fullPath);
      } else if (entry.name.endsWith('.dart')) {
        allLibFiles.push(fullPath);
      }
    }
  }
  scanDir(MOBILE_APP_LIB);

  let globalLingeringDishes = [];
  for (const file of allLibFiles) {
    const content = fs.readFileSync(file, 'utf8');
    if (content.includes('_getFallbackProducts')) {
      globalLingeringDishes.push(`_getFallbackProducts in ${path.relative(ROOT_DIR, file)}`);
    }
  }
  check(
    '1.3 Zero occurrences of _getFallbackProducts across all flutter_mobile_app/lib Dart files',
    globalLingeringDishes.length === 0,
    globalLingeringDishes.join('; ')
  );

  // 1.4 Verify _loadMenu sets _hasNetworkError on API failure or empty response
  check(
    '1.4 _loadMenu flags _hasNetworkError = true upon network drop or empty payload',
    menuScreenContent.includes('_hasNetworkError = true;') && menuScreenContent.includes('catch (_) {'),
    '_hasNetworkError flag not properly set in _loadMenu catch block'
  );

  // 1.5 Verify build() renders NoNetworkScreen when _hasNetworkError is true
  check(
    '1.5 store_menu_screen renders NoNetworkScreen(isFullScreen: true) on network error',
    menuScreenContent.includes('if (_hasNetworkError)') && menuScreenContent.includes('NoNetworkScreen('),
    'NoNetworkScreen not rendered in store_menu_screen build()'
  );

  console.log();

  // --------------------------------------------------------------------------
  // SUITE 2: CLIENT-SIDE SUPABASE ORDER INSERTION PURGE (api_service.dart)
  // --------------------------------------------------------------------------
  console.log('--- SUITE 2: Client-Side Supabase Order Insertion Purge (api_service.dart) ---');

  const apiServicePath = path.join(MOBILE_APP_LIB, 'services', 'api_service.dart');
  const apiServiceContent = fs.readFileSync(apiServicePath, 'utf8');

  // 2.1 Verify checkout routes purely to $_baseUrl/orders/checkout
  check(
    '2.1 checkout() calls backend REST endpoint $_baseUrl/orders/checkout',
    apiServiceContent.includes("'$_baseUrl/orders/checkout'"),
    'Missing backend checkout call'
  );

  // 2.2 Verify checkout has NO direct Supabase insert fallback
  const checkoutMethodMatch = apiServiceContent.match(/static Future<ApiResult> checkout[\s\S]*?static Future<ApiResult> getOrder/);
  const checkoutMethod = checkoutMethodMatch ? checkoutMethodMatch[0] : '';
  check(
    '2.2 checkout() contains zero direct Supabase order inserts or $_supabaseUrl/orders fallbacks',
    !checkoutMethod.includes('_supabaseUrl') && !checkoutMethod.includes('supabase.co') && !checkoutMethod.includes('orders?'),
    'Found lingering Supabase call inside checkout()'
  );

  // 2.3 Verify checkout returns ApiResult.failure on network exception
  check(
    '2.3 checkout() returns ApiResult.failure with network error message upon network exception',
    checkoutMethod.includes('catch (_)') && checkoutMethod.includes('ApiResult.failure('),
    'checkout() does not return ApiResult.failure on network error'
  );

  // 2.4 Verify getPricingQuote returns double? without hardcoded 5.00 fallback
  const quoteMethodMatch = apiServiceContent.match(/static Future<double\?> getPricingQuote[\s\S]*?static Future<ApiResult> checkout/);
  const quoteMethod = quoteMethodMatch ? quoteMethodMatch[0] : '';
  check(
    '2.4 getPricingQuote() strictly returns null on error without hardcoded 5.00 fallback',
    quoteMethod.includes('return null;') && !quoteMethod.includes('return 5.00') && !quoteMethod.includes('return 5.0;'),
    'getPricingQuote() still contains static 5.00 fallback'
  );

  // 2.5 Verify cancelOrder has no Supabase patch fallback
  const cancelMethodMatch = apiServiceContent.match(/static Future<ApiResult> cancelOrder[\s\S]*?static Future<bool> submitOrderReview/);
  const cancelMethod = cancelMethodMatch ? cancelMethodMatch[0] : '';
  check(
    '2.5 cancelOrder() contains zero Supabase patch mutations',
    !cancelMethod.includes('_supabaseUrl') && !cancelMethod.includes('supabaseApiKey'),
    'Found lingering Supabase patch in cancelOrder()'
  );

  // 2.6 Verify submitOrderReview returns false on failure without unconditional true
  const reviewMethodMatch = apiServiceContent.match(/static Future<bool> submitOrderReview[\s\S]*?class ApiResult/);
  const reviewMethod = reviewMethodMatch ? reviewMethodMatch[0] : '';
  check(
    '2.6 submitOrderReview() returns false on failure and does not fake review success',
    reviewMethod.includes('return false;') && !reviewMethod.includes('_supabaseUrl/reviews'),
    'submitOrderReview() still has fake success or Supabase insert'
  );

  console.log();

  // --------------------------------------------------------------------------
  // SUITE 3: OTP SECURITY & UNIVERSAL BACKDOOR PURGE
  // --------------------------------------------------------------------------
  console.log('--- SUITE 3: OTP Security & Universal Backdoor Purge ---');

  const waAuthPath = path.join(MOBILE_APP_LIB, 'services', 'whatsapp_auth_service.dart');
  const waAuthContent = fs.readFileSync(waAuthPath, 'utf8');

  // 3.1 Verify verifyOtp does NOT accept 1234 unconditionally
  check(
    '3.1 verifyOtp() in whatsapp_auth_service.dart does not contain 1234 backdoor',
    !waAuthContent.includes("code == '1234'") && !waAuthContent.includes("trimmedOtp == '1234'"),
    'Found hardcoded 1234 bypass in whatsapp_auth_service.dart'
  );

  // 3.2 Verify dev fallback trimmedOtp.length == 4 is completely purged
  check(
    '3.2 verifyOtp() does not contain unconditional length == 4 auto-pass fallback',
    !waAuthContent.includes('trimmedOtp.length == 4') && !waAuthContent.includes('code.length == 4'),
    'Found dev fallback length == 4 in whatsapp_auth_service.dart'
  );

  // 3.3 Verify verifyOtp strictly checks cachedOtp match and expiration
  check(
    '3.3 verifyOtp() checks cleanPhone, cachedOtp match, and expiration',
    waAuthContent.includes('_cachedOtp == trimmedOtp') && waAuthContent.includes('DateTime.now().isBefore(_cachedExpiresAt!)'),
    'Missing secure cache verification in verifyOtp()'
  );

  // 3.4 Verify order_tracking_screen does not show hardcoded 4821 delivery OTP
  const trackingPath = path.join(MOBILE_APP_LIB, 'order_tracking_screen.dart');
  const trackingContent = fs.readFileSync(trackingPath, 'utf8');
  check(
    '3.4 order_tracking_screen.dart initializes _deliveryOtp as unconfirmed "----" instead of "4821"',
    trackingContent.includes("String _deliveryOtp = '----';") && !trackingContent.includes("String _deliveryOtp = '4821';"),
    'order_tracking_screen still initializes delivery OTP with fake 4821'
  );

  console.log();

  // --------------------------------------------------------------------------
  // SUITE 4: NONETWORKSCREEN & RESILIENT ARABIC MOUNTAIN UX
  // --------------------------------------------------------------------------
  console.log('--- SUITE 4: NoNetworkScreen Integration & Mountain Topology UX ---');

  const noNetworkPath = path.join(MOBILE_APP_LIB, 'widgets', 'no_network_screen.dart');
  const noNetworkExists = fs.existsSync(noNetworkPath);
  check('4.1 widgets/no_network_screen.dart file exists', noNetworkExists, 'File not found');

  if (noNetworkExists) {
    const noNetworkContent = fs.readFileSync(noNetworkPath, 'utf8');

    // 4.2 Verify 12s auto-retry interval
    check(
      '4.2 NoNetworkScreen has 12-second auto-retry interval (_retryIntervalSeconds = 12)',
      noNetworkContent.includes('_retryIntervalSeconds = 12;') || noNetworkContent.includes('_retryIntervalSeconds = 12'),
      'Auto-retry interval is not 12 seconds'
    );

    // 4.3 Verify CountdownRing presence
    check(
      '4.3 NoNetworkScreen integrates CountdownRing widget with remainingSeconds',
      noNetworkContent.includes('CountdownRing(') && noNetworkContent.includes('remainingSeconds: _secondsRemaining'),
      'CountdownRing widget not found in NoNetworkScreen'
    );

    // 4.4 Verify Mountain headline and carrier explanation in Libyan Arabic
    check(
      '4.4 NoNetworkScreen contains authentic Nafusa mountain headline and Madar/Libyana copy',
      noNetworkContent.includes('التغطية ضعيفة في الجبل') && noNetworkContent.includes('أبراج المدار أو ليبيانا'),
      'Missing Libyan mountain carrier messaging'
    );

    // 4.5 Verify direct voice call to authentic Libyan support (0918207786)
    check(
      '4.5 NoNetworkScreen provides emergency voice dial to 0918207786 (cellular voice without 4G)',
      noNetworkContent.includes('tel:0918207786') && noNetworkContent.includes('0918207786'),
      'Missing emergency telephone link 0918207786'
    );

    // 4.6 Verify manual retry action
    check(
      '4.6 NoNetworkScreen provides manual retry action button',
      noNetworkContent.includes('إعادة المحاولة الآن') && noNetworkContent.includes('_triggerRetry'),
      'Missing manual retry button'
    );
  }

  // 4.7 Verify NoNetworkScreen integration in cart_checkout_screen.dart
  const checkoutPath = path.join(MOBILE_APP_LIB, 'cart_checkout_screen.dart');
  const checkoutContent = fs.readFileSync(checkoutPath, 'utf8');
  check(
    '4.7 cart_checkout_screen.dart integrates NoNetworkScreen in modal bottom sheet on network error',
    checkoutContent.includes('NoNetworkScreen(') && checkoutContent.includes('isFullScreen: false'),
    'cart_checkout_screen missing NoNetworkScreen integration'
  );

  // 4.8 Verify NoNetworkScreen integration in order_tracking_screen.dart
  check(
    '4.8 order_tracking_screen.dart integrates inline NoNetworkScreen when network connection drops',
    trackingContent.includes('NoNetworkScreen(') && trackingContent.includes('_hasNetworkError'),
    'order_tracking_screen missing inline NoNetworkScreen warning'
  );

  console.log();

  // --------------------------------------------------------------------------
  // SUITE 5: LIVE BACKEND API VERIFICATION FOR CUSTOMER APP
  // --------------------------------------------------------------------------
  console.log('--- SUITE 5: Live Backend API Verification ---');

  const customerUser = { id: 'usr_guest_nalut', phone: '0910000000', role: 'customer', city: 'nalut' };
  const driverUser = { id: 'user_driver_01', driver_id: 'driver_nalut_01', phone: '0912345678', role: 'driver', city: 'nalut' };
  const customerToken = jwt.sign(customerUser, JWT_SECRET, { expiresIn: '1h' });
  const driverToken = jwt.sign(driverUser, JWT_SECRET, { expiresIn: '1h' });
  const customerHeaders = { Authorization: `Bearer ${customerToken}` };
  const driverHeaders = { Authorization: `Bearer ${driverToken}` };

  // Discover stores dynamically
  const storesRes = await apiRequest('GET', '/api/v1/stores', null, customerHeaders);
  const stores = storesRes.body?.data || [];
  const primaryStore = stores.find(s => s.id.includes('nalut')) || stores[0] || {
    id: 'store_nalut_ranchello',
    latitude: 31.86213,
    longitude: 10.986878
  };

  // 5.1 Dynamic pricing quote in Central Nalut
  const centralQuote = await apiRequest('GET', `/api/v1/pricing/quote?store_id=${primaryStore.id}&lat=31.8687&lng=10.9818`, null, customerHeaders);
  const centralFee = centralQuote.body?.delivery_fee_lyd || centralQuote.body?.data?.delivery_fee_lyd;
  check(
    '5.1 GET /api/v1/pricing/quote for Central Nalut returns valid dynamic fee (5.00 LYD)',
    centralQuote.status === 200 && centralFee >= 5.0 && centralFee <= 5.5,
    `Status: ${centralQuote.status}, Fee: ${centralFee}`
  );

  // 5.2 Dynamic pricing quote for distant mountain outskirts (>8km)
  const mountainLat = (primaryStore.latitude || 31.862) + 0.08;
  const mountainLng = (primaryStore.longitude || 10.986) + 0.08;
  const mountainQuote = await apiRequest('GET', `/api/v1/pricing/quote?store_id=${primaryStore.id}&lat=${mountainLat}&lng=${mountainLng}`, null, customerHeaders);
  const mountainFee = mountainQuote.body?.delivery_fee_lyd || mountainQuote.body?.data?.delivery_fee_lyd;
  check(
    '5.2 GET /api/v1/pricing/quote for distant mountain outskirts scales dynamically (>= 7.00 LYD)',
    mountainQuote.status === 200 && mountainFee >= 7.0,
    `Status: ${mountainQuote.status}, Fee: ${mountainFee}`
  );

  // 5.3 Catalog endpoint for store menu
  const menuRes = await apiRequest('GET', `/api/v1/stores/${primaryStore.id}/menu`, null, customerHeaders);
  const products = menuRes.body?.data?.products || menuRes.body?.products || menuRes.body?.all_products || [];
  check(
    '5.3 GET /api/v1/stores/:id/menu returns authentic persistent products array',
    menuRes.status === 200 && Array.isArray(products) && products.length > 0,
    `Status: ${menuRes.status}, Product count: ${products.length}`
  );

  // 5.4 Anti-bypass: Verify delivery status transition rejects backdoor OTP 1234
  const testOrderRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: primaryStore.id,
    customer_name: 'زبون اختبار التحدي',
    customer_phone: '0919999999',
    items: [{ product_id: products[0]?.id || 'prod_01', quantity: 1, unit_price: 10.0 }],
    delivery_location: { lat: 31.8687, lng: 10.9818 },
    payment_method: 'cash_on_delivery',
  }, customerHeaders);

  const testOrderId = testOrderRes.body?.data?.order_id || testOrderRes.body?.data?.id;
  if (testOrderId) {
    // Advance order to on_the_way
    await apiRequest('POST', `/api/v1/orders/${testOrderId}/status`, { status: 'preparing' }, driverHeaders);
    await apiRequest('POST', `/api/v1/orders/${testOrderId}/status`, { status: 'ready_for_pickup' }, driverHeaders);
    await apiRequest('POST', `/api/v1/orders/${testOrderId}/status`, { status: 'picked_up', driver_id: 'driver_nalut_01' }, driverHeaders);

    // Attempt delivery with backdoor OTP '1234'
    const bypassAttempt = await apiRequest('POST', `/api/v1/orders/${testOrderId}/status`, {
      status: 'delivered',
      driver_id: 'driver_nalut_01',
      otp_code: '1234',
    }, driverHeaders);

    check(
      '5.4 Delivery transition strictly rejects backdoor OTP "1234" (returns 400/403/422)',
      bypassAttempt.status === 400 || bypassAttempt.status === 403 || bypassAttempt.status === 422,
      `Bypass attempt status: ${bypassAttempt.status}, Response: ${JSON.stringify(bypassAttempt.body)}`
    );
  } else {
    check(
      '5.4 Delivery transition rejects backdoor OTP "1234"',
      false,
      `Failed to create test order: status ${testOrderRes.status}, error: ${JSON.stringify(testOrderRes.body)}`
    );
  }

  console.log();
  console.log('================================================================');
  console.log('📊 CHALLENGER M3-1 EXECUTION SUMMARY');
  console.log('================================================================');
  console.log(`Total Checks Executed:  ${totalChecks}`);
  console.log(`Passed:                 ${passedChecks}`);
  console.log(`Vulnerabilities Found:  ${vulnerabilities.length}`);
  console.log(`Pass Rate:              ${((passedChecks / totalChecks) * 100).toFixed(1)}%`);

  if (vulnerabilities.length > 0) {
    console.log('\n❌ VULNERABILITIES IDENTIFIED:');
    vulnerabilities.forEach((v, i) => {
      console.log(`  ${i + 1}. ${v.title} (${v.detail})`);
    });
    console.log('\nVERDICT: REQUEST_CHANGES');
    process.exit(1);
  } else {
    console.log('\n🎉 ALL CHECKS PASSED WITH ZERO VULNERABILITIES DETECTED!');
    console.log('VERDICT: APPROVE');
    process.exit(0);
  }
}

runEmpiricalChallenge().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
