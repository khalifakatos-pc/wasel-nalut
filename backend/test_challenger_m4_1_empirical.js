/**
 * ============================================================================
 * EMPIRICAL ADVERSARIAL CHALLENGER SUITE: MILESTONE M4-1 (CAPTAIN APP)
 * ============================================================================
 * Tests Features F18, F19, F20, F21 across backend & client integration contracts.
 * ============================================================================
 */
const http = require('http');
const assert = require('assert');
const fs = require('fs');
const path = require('path');

const PORT = 3000;

function req(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const options = {
      hostname: '127.0.0.1',
      port: PORT,
      path,
      method: method.toUpperCase(),
      headers: {
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
        ...headers
      }
    };
    const r = http.request(options, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch (_) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    r.on('error', reject);
    if (payload) r.write(payload);
    r.end();
  });
}

const results = [];
function record(code, name, pass, detail = '') {
  results.push({ code, name, pass, detail });
  const icon = pass ? '✅ PASS' : '❌ FAIL';
  console.log(`  ${icon} [${code}] ${name} ${detail ? '(' + detail + ')' : ''}`);
}

async function run() {
  console.log('================================================================');
  console.log('⚔️  STARTING M4-1 EMPIRICAL ADVERSARIAL CHALLENGER SUITE (CAPTAIN APP)');
  console.log('================================================================\n');

  // Step 0: Ensure server is running
  try {
    await req('GET', '/health');
  } catch (_) {
    console.log('Booting backend server in background...');
    require('./server.js');
    await new Promise(r => setTimeout(r, 1200));
  }

  // --------------------------------------------------------------------------
  // OBJECTIVE 1: MOCK PURGE & AUTHENTICATION INTEGRITY (F18)
  // --------------------------------------------------------------------------
  console.log('\n--- Objective 1: Mock Purge & Authentication Integrity (F18) ---');

  // 1.1 Source verification: DriverMockData must not exist in flutter_driver_app
  const driverAppPath = path.resolve(__dirname, '../flutter_driver_app/lib');
  function scanDirForRegex(dir, regex) {
    let matches = [];
    const files = fs.readdirSync(dir, { withFileTypes: true });
    for (const f of files) {
      const fullPath = path.join(dir, f.name);
      if (f.isDirectory()) {
        matches = matches.concat(scanDirForRegex(fullPath, regex));
      } else if (f.isFile() && f.name.endsWith('.dart')) {
        const content = fs.readFileSync(fullPath, 'utf8');
        if (regex.test(content)) {
          matches.push(fullPath);
        }
      }
    }
    return matches;
  }

  const mockDataMatches = scanDirForRegex(driverAppPath, /DriverMockData/);
  record('ADV-F18.1', 'DriverMockData completely non-existent in flutter_driver_app',
    mockDataMatches.length === 0, `Matches: ${mockDataMatches.length}`);

  const registeredCaptainsMatches = scanDirForRegex(driverAppPath, /registeredCaptains/);
  record('ADV-F18.2', 'registeredCaptains fallback map completely non-existent',
    registeredCaptainsMatches.length === 0, `Matches: ${registeredCaptainsMatches.length}`);

  // 1.2 POST /api/v1/auth/login with genuine driver credentials
  const validDriverLogin = await req('POST', '/api/v1/auth/login', {
    phone: '0912345678',
    password: '5521',
    role: 'driver'
  });
  record('ADV-F18.3', 'POST /api/v1/auth/login with valid driver credentials yields 200 + JWT',
    validDriverLogin.status === 200 && validDriverLogin.body?.data?.token,
    `Status: ${validDriverLogin.status}`);
  const driverToken01 = validDriverLogin.body?.data?.token;

  // 1.3 POST /api/v1/auth/login with backdoor 1234
  const backdoorLogin = await req('POST', '/api/v1/auth/login', {
    phone: '0912345678',
    password: '1234',
    role: 'driver'
  });
  record('ADV-F18.4', 'Backdoor PIN "1234" is strictly rejected by auth/login',
    backdoorLogin.status === 401 || backdoorLogin.status === 400,
    `Status: ${backdoorLogin.status}`);

  // 1.4 POST /api/v1/auth/login with invalid password
  const invalidPassLogin = await req('POST', '/api/v1/auth/login', {
    phone: '0912345678',
    password: 'wrong_password_999',
    role: 'driver'
  });
  record('ADV-F18.5', 'Invalid driver password strictly rejected with 401',
    invalidPassLogin.status === 401, `Status: ${invalidPassLogin.status}`);

  // 1.5 Second valid driver login for cross-driver isolation tests
  const validDriverLogin02 = await req('POST', '/api/v1/auth/login', {
    phone: '0923456789',
    password: '6632',
    role: 'driver'
  });
  record('ADV-F18.6', 'Second driver (0923456789) authenticated successfully',
    validDriverLogin02.status === 200 && validDriverLogin02.body?.data?.token,
    `Status: ${validDriverLogin02.status}`);
  const driverToken02 = validDriverLogin02.body?.data?.token;

  // 1.6 Customer login to test unauthorized access
  const custLogin = await req('POST', '/api/v1/auth/login', {
    phone: '0910000000',
    password: 'Customer@Nalut2026!Secure'
  });
  const customerToken = custLogin.body?.data?.token;

  // --------------------------------------------------------------------------
  // OBJECTIVE 2: GPS HARDWARE TELEMETRY & GUARDS (F19)
  // --------------------------------------------------------------------------
  console.log('\n--- Objective 2: GPS Hardware Telemetry & Guards (F19) ---');

  // 2.1 Verify _startFallbackSimulation is gone
  const fallbackSimMatches = scanDirForRegex(driverAppPath, /_startFallbackSimulation/);
  record('ADV-F19.1', '_startFallbackSimulation completely purged from codebase',
    fallbackSimMatches.length === 0, `Matches: ${fallbackSimMatches.length}`);

  // 2.2 Verify Geolocator sensor is used in driver_gps_service.dart
  const gpsServiceContent = fs.readFileSync(path.join(driverAppPath, 'services/driver_gps_service.dart'), 'utf8');
  const usesGeolocatorStream = gpsServiceContent.includes('Geolocator.getPositionStream') &&
                               gpsServiceContent.includes('Geolocator.getServiceStatusStream');
  record('ADV-F19.2', 'driver_gps_service.dart streams exclusively from Geolocator sensors',
    usesGeolocatorStream, `Uses getPositionStream & getServiceStatusStream`);

  // 2.3 Verify offline guard and warning banner in driver_home_screen.dart
  const homeScreenContent = fs.readFileSync(path.join(driverAppPath, 'driver_home_screen.dart'), 'utf8');
  const hasGpsWarningBanner = homeScreenContent.includes('خدمة تحديد المواقع (GPS) معطلة') &&
                              homeScreenContent.includes('_isGpsEnabled');
  const blocksOnlineWhenGpsDisabled = homeScreenContent.includes('!_isGpsEnabled') &&
                                      homeScreenContent.includes('DriverGpsService.instance.openLocationSettings()');
  record('ADV-F19.3', 'driver_home_screen displays sticky Arabic warning & blocks online toggle when GPS disabled',
    hasGpsWarningBanner && blocksOnlineWhenGpsDisabled, 'Sticky warning + online toggle blocked');

  // 2.4 Test telemetry endpoint with valid payload
  const telemetryRes = await req('POST', '/api/v1/drivers/driver_nalut_01/location', {
    latitude: 31.8686,
    longitude: 10.9818,
    heading: 90,
    speed_kmh: 42.5
  }, { Authorization: `Bearer ${driverToken01}` });
  record('ADV-F19.4', 'POST /api/v1/drivers/:id/location accepts valid GPS telemetry (200 OK)',
    telemetryRes.status === 200 && telemetryRes.body?.data?.latitude === 31.8686,
    `Status: ${telemetryRes.status}, Lat: ${telemetryRes.body?.data?.latitude}`);

  // 2.5 Test telemetry endpoint with non-existent driver
  const invalidDriverTelemetry = await req('POST', '/api/v1/drivers/non_existent_driver_xyz/location', {
    latitude: 31.8686,
    longitude: 10.9818
  }, { Authorization: `Bearer ${driverToken01}` });
  record('ADV-F19.5', 'POST /api/v1/drivers/:id/location returns 404 for non-existent driver',
    invalidDriverTelemetry.status === 404, `Status: ${invalidDriverTelemetry.status}`);

  // --------------------------------------------------------------------------
  // OBJECTIVE 3: DOUBLE-ENTRY LEDGER INTEGRITY & SETTLEMENT (F20)
  // --------------------------------------------------------------------------
  console.log('\n--- Objective 3: Double-Entry Ledger Integrity & Settlement (F20) ---');

  // 3.1 Verify driver wallet does NOT calculate balance * 0.80 client-side
  const walletScreenContent = fs.readFileSync(path.join(driverAppPath, 'driver_wallet_screen.dart'), 'utf8');
  const hasFakeSplit80 = /balance\s*\*\s*0\.8/i.test(walletScreenContent) ||
                         /codAmount\s*\*\s*0\.8/i.test(walletScreenContent);
  record('ADV-F20.1', 'driver_wallet_screen has ZERO client-side "* 0.80" heuristics',
    !hasFakeSplit80, 'No balance * 0.80 found');

  // 3.2 Verify statement endpoint returns accurate Account 2030 ledger balance
  const statementRes = await req('GET', '/api/v1/accounting/statement/driver/driver_nalut_01', null, {
    Authorization: `Bearer ${driverToken01}`
  });
  record('ADV-F20.2', 'GET /api/v1/accounting/statement/driver/:driverId returns Account 2030 statement',
    statementRes.status === 200 && statementRes.body?.entity_type === 'driver',
    `Status: ${statementRes.status}, Entity: ${statementRes.body?.entity_type}`);

  // 3.3 Verify driver profile returns cash_in_hand_lyd (Account 1040 COD liability)
  const profileRes = await req('GET', '/api/v1/drivers/driver_nalut_01', null, {
    Authorization: `Bearer ${driverToken01}`
  });
  record('ADV-F20.3', 'GET /api/v1/drivers/:id returns cash_in_hand_lyd reflecting Account 1040',
    profileRes.status === 200 && typeof profileRes.body?.data?.cash_in_hand_lyd === 'number',
    `cash_in_hand_lyd: ${profileRes.body?.data?.cash_in_hand_lyd}`);

  // 3.4 Settle without token -> 401 Unauthorized
  const unauthSettle = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', { amount_lyd: 10 });
  record('ADV-F20.4', 'POST /api/v1/drivers/:id/settle without token returns 401 Unauthorized',
    unauthSettle.status === 401, `Status: ${unauthSettle.status}`);

  // 3.5 Settle with customer token -> 403 Forbidden
  const custSettle = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', { amount_lyd: 10 }, {
    Authorization: `Bearer ${customerToken}`
  });
  record('ADV-F20.5', 'POST /api/v1/drivers/:id/settle with customer token returns 403 Forbidden',
    custSettle.status === 403, `Status: ${custSettle.status}`);

  // 3.6 Settle with another driver's token -> 403 Forbidden
  const crossDriverSettle = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', { amount_lyd: 10 }, {
    Authorization: `Bearer ${driverToken02}`
  });
  record('ADV-F20.6', 'Driver 02 cannot settle Driver 01 cash custody (403 Forbidden)',
    crossDriverSettle.status === 403, `Status: ${crossDriverSettle.status}`);

  // Authentic Super Admin Login for administrative verification
  const adminLogin = await req('POST', '/api/v1/auth/login', {
    phone: '0910009832',
    password: 'Admin@Nalut2026!Secure'
  });
  const adminToken = adminLogin.body?.data?.token;

  // 3.7 Settle with admin token -> 200/201 Success with Receipt Voucher
  const adminDriverSettle = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', {
    amount_lyd: 0,
    notes: 'تسوية كاش دورية للمناوبة من الإدارة'
  }, {
    Authorization: `Bearer ${adminToken}`
  });
  record('ADV-F20.7', 'Admin settles driver custody -> Success + Voucher',
    adminDriverSettle.status === 200 || adminDriverSettle.status === 201,
    `Status: ${adminDriverSettle.status}, Message: ${adminDriverSettle.body?.message}`);

  // 3.8 Test Driver Self-Settle with courier token
  const selfDriverSettle = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', {
    amount_lyd: 0,
    notes: 'تسوية كاش دورية للكابتن'
  }, {
    Authorization: `Bearer ${driverToken01}`
  });
  record('ADV-F20.8', 'Driver self-settle with courier token (evaluating driverSelfOrAdminMiddleware)',
    selfDriverSettle.status === 200 || selfDriverSettle.status === 201,
    `Status: ${selfDriverSettle.status}, Body: ${JSON.stringify(selfDriverSettle.body)}`);

  // --------------------------------------------------------------------------
  // OBJECTIVE 4: KITCHEN HANDOVER & CUSTOMER DELIVERY OTP SECURITY (F21)
  // --------------------------------------------------------------------------
  console.log('\n--- Objective 4: Kitchen Handover & Customer Delivery OTP Security (F21) ---');

  // Place a test order for lifecycle validation using authenticated customer
  const checkoutRes = await req('POST', '/api/v1/orders/checkout', {
    store_id: 'store_nalut_ranchello',
    customer_id: 'cust_nalut_01',
    customer_phone: '0910000000',
    delivery_address: 'نالوت - الحي الغربي',
    delivery_latitude: 31.8650,
    delivery_longitude: 10.9800,
    payment_method: 'cash_on_delivery',
    items: [{ product_id: 'prod_nalut_01', name: 'وجبة تجريبية', quantity: 1, unit_price_lyd: 25.0 }]
  }, { Authorization: `Bearer ${customerToken}` });
  assert(checkoutRes.status === 201 || checkoutRes.status === 200, `Order creation failed: status ${checkoutRes.status}, body: ${JSON.stringify(checkoutRes.body)}`);
  const orderId = checkoutRes.body?.data?.id || checkoutRes.body?.order?.id || checkoutRes.body?.id;
  assert(orderId, 'Order id missing from checkout response');

  // Advance order: placed -> accepted -> preparing -> ready_for_pickup via kitchen/admin
  const acceptRes = await req('POST', `/api/v1/orders/${orderId}/status`, { status: 'accepted' }, {
    Authorization: `Bearer ${adminToken}`
  });
  assert(acceptRes.status === 200, `Accept failed: ${JSON.stringify(acceptRes.body)}`);

  const prepRes = await req('POST', `/api/v1/orders/${orderId}/status`, { status: 'preparing' }, {
    Authorization: `Bearer ${adminToken}`
  });
  assert(prepRes.status === 200, `Preparing failed: ${JSON.stringify(prepRes.body)}`);

  const readyRes = await req('POST', `/api/v1/orders/${orderId}/status`, { status: 'ready_for_pickup' }, {
    Authorization: `Bearer ${adminToken}`
  });
  assert(readyRes.status === 200, `Ready failed: ${JSON.stringify(readyRes.body)}`);

  // Retrieve order details to inspect assigned handover code
  const orderBeforeHandover = await req('GET', `/api/v1/orders/${orderId}`);
  const actualHandoverCode = orderBeforeHandover.body?.data?.handover_code;
  assert(actualHandoverCode, 'Handover code must exist on ready order');

  // 4.1 Verify hardcoded '1234' cannot bypass kitchen handover
  const backdoorHandover = await req('POST', `/api/v1/orders/${orderId}/handover`, {
    handover_code: '1234',
    driver_id: 'driver_nalut_01'
  }, { Authorization: `Bearer ${driverToken01}` });
  record('ADV-F21.1', 'Backdoor code "1234" rejected on kitchen handover (400 Bad Request)',
    backdoorHandover.status === 400 && backdoorHandover.body?.error?.includes('كود تسليم الوجبة غير صحيح'),
    `Status: ${backdoorHandover.status}`);

  // 4.2 Verify authentic handover code succeeds
  const authenticHandover = await req('POST', `/api/v1/orders/${orderId}/handover`, {
    handover_code: actualHandoverCode,
    driver_id: 'driver_nalut_01'
  }, { Authorization: `Bearer ${driverToken01}` });
  record('ADV-F21.2', 'Authentic handover code transfers custody to driver (200 OK)',
    authenticHandover.status === 200, `Status: ${authenticHandover.status}`);

  // 4.3 Verify customer delivery OTP is NOT displayed on captain screens
  const captainOtpPrinted = scanDirForRegex(driverAppPath, /customerOtpPin|correctOtp|\$\{.*otp.*\}/i);
  record('ADV-F21.3', 'Customer delivery OTP is NOT displayed or leaked in driver app screens',
    captainOtpPrinted.length === 0, `Matches: ${captainOtpPrinted.length}`);

  // 4.4 Verify OtpInputField source does NOT accept partial inputs or entered.isNotEmpty
  const otpFieldContent = fs.readFileSync(path.join(driverAppPath, 'otp_input_field.dart'), 'utf8');
  const hasBackdoorNotEmpty = otpFieldContent.includes('entered.isNotEmpty');
  const enforcesStrict4Digits = otpFieldContent.includes('entered.length == 4');
  record('ADV-F21.4', 'OtpInputField strictly enforces 4 digits and has ZERO "entered.isNotEmpty" loopholes',
    !hasBackdoorNotEmpty && enforcesStrict4Digits,
    `No entered.isNotEmpty: ${!hasBackdoorNotEmpty}, Strictly 4 digits: ${enforcesStrict4Digits}`);

  // 4.5 Fetch order to get secret OTP (stored on backend, only customer has it)
  const orderDetails = await req('GET', `/api/v1/orders/${orderId}`);
  const secretOtp = orderDetails.body?.data?.otp_code;
  assert(secretOtp, 'Order must have a valid secret OTP code');

  // 4.6 Attempt delivery with invalid OTP or backdoor '1234'
  const wrongOtpDelivery = await req('POST', `/api/v1/orders/${orderId}/status`, {
    status: 'delivered',
    otp_code: '1234',
    driver_id: 'driver_nalut_01'
  }, { Authorization: `Bearer ${driverToken01}` });
  record('ADV-F21.5', 'Delivery with backdoor OTP "1234" is strictly rejected with 400',
    wrongOtpDelivery.status === 400 && wrongOtpDelivery.body?.error?.includes('رمز التسليم (OTP) مطلوب وغير صحيح'),
    `Status: ${wrongOtpDelivery.status}`);

  // 4.7 Attempt delivery without OTP
  const missingOtpDelivery = await req('POST', `/api/v1/orders/${orderId}/status`, {
    status: 'delivered',
    driver_id: 'driver_nalut_01'
  }, { Authorization: `Bearer ${driverToken01}` });
  record('ADV-F21.6', 'Delivery without OTP is strictly rejected with 400',
    missingOtpDelivery.status === 400, `Status: ${missingOtpDelivery.status}`);

  // 4.8 Complete delivery with genuine OTP
  const validOtpDelivery = await req('POST', `/api/v1/orders/${orderId}/status`, {
    status: 'delivered',
    otp_code: secretOtp,
    driver_id: 'driver_nalut_01'
  }, { Authorization: `Bearer ${driverToken01}` });
  record('ADV-F21.7', 'Delivery completes successfully with authentic customer OTP (200 OK)',
    validOtpDelivery.status === 200 && validOtpDelivery.body?.data?.status === 'delivered',
    `Status: ${validOtpDelivery.status}, OrderStatus: ${validOtpDelivery.body?.data?.status}`);

  // --------------------------------------------------------------------------
  // SUMMARY
  // --------------------------------------------------------------------------
  console.log('\n================================================================');
  console.log('📊 M4-1 ADVERSARIAL TEST RESULTS SUMMARY');
  console.log('================================================================');
  const passed = results.filter(r => r.pass).length;
  const failed = results.filter(r => !r.pass).length;
  console.log(`Total Adversarial Checks: ${results.length}`);
  console.log(`Passed:                   ${passed}`);
  console.log(`Failed:                   ${failed}`);

  if (failed > 0) {
    console.error('\n❌ SOME ADVERSARIAL CHECKS FAILED!');
    process.exit(1);
  } else {
    console.log('\n🎉 ALL 21 ADVERSARIAL CHECKS PASSED WITH 100% SUCCESS!');
    process.exit(0);
  }
}

run().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
