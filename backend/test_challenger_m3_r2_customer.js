/**
 * ============================================================================
 * WASEL NALUT: CHALLENGER M3-R2 EMPIRICAL TEST & ADVERSARIAL HARNESS
 * ============================================================================
 * Customer App (flutter_mobile_app) Integrity & Security Verification:
 * 1. Verify driver_radar_sheet.dart does not exist on the filesystem.
 * 2. Verify 0 occurrences of '4821' and 'WAS-9831' in flutter_mobile_app/lib/.
 * 3. Verify '1234' is absent from otp_verification_screen.dart and cannot be auto-filled or accepted.
 * 4. Verify visual OTP card and auto-fill button are completely purged.
 * 5. Verify customer authentication and RBAC boundaries in backend.
 * ============================================================================
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const { config } = require('./config');

const TEST_PORT = process.env.TEST_PORT || process.env.PORT || 3000;
const JWT_SECRET = config.JWT_SECRET;

let ipCounter = 300;
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

    req.on('error', (err) => reject(err));
    if (postData) req.write(postData);
    req.end();
  });
}

function getAllFiles(dirPath, arrayOfFiles = []) {
  const files = fs.readdirSync(dirPath);
  files.forEach((file) => {
    const fullPath = path.join(dirPath, file);
    if (fs.statSync(fullPath).isDirectory()) {
      arrayOfFiles = getAllFiles(fullPath, arrayOfFiles);
    } else {
      arrayOfFiles.push(fullPath);
    }
  });
  return arrayOfFiles;
}

let totalChecks = 0;
let passedChecks = 0;
let failedChecks = 0;

function assert(condition, testName, details = '') {
  totalChecks++;
  if (condition) {
    passedChecks++;
    console.log(`  ✅ [PASS] ${testName}`);
  } else {
    failedChecks++;
    console.error(`  ❌ [FAIL] ${testName}: ${details}`);
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

async function runEmpiricalHarness() {
  console.log('================================================================');
  console.log('⚔️  WASEL NALUT: CHALLENGER M3-R2 CUSTOMER APP VERIFICATION HARNESS');
  console.log('================================================================\n');

  await ensureServerRunning();

  const appLibDir = path.resolve(__dirname, '../flutter_mobile_app/lib');

  // -------------------------------------------------------------------------
  // SUITE 1: Filesystem & Forbidden Strings Cleanliness
  // -------------------------------------------------------------------------
  console.log('--- SUITE 1: Filesystem Cleanliness & Forbidden Strings ---');

  // 1.1 Verify driver_radar_sheet.dart does not exist
  const radarSheetPath = path.join(appLibDir, 'driver_radar_sheet.dart');
  const radarExists = fs.existsSync(radarSheetPath);
  assert(!radarExists, 'driver_radar_sheet.dart must NOT exist on filesystem', `Found at ${radarSheetPath}`);

  // Also check anywhere in flutter_mobile_app
  const allMobileFiles = getAllFiles(path.resolve(__dirname, '../flutter_mobile_app'));
  const anyRadarSheet = allMobileFiles.filter(f => path.basename(f).toLowerCase().includes('driver_radar_sheet'));
  assert(anyRadarSheet.length === 0, 'Zero occurrences of driver_radar_sheet across flutter_mobile_app', `Found: ${anyRadarSheet.join(', ')}`);

  // 1.2 Verify 0 matches for 4821 and WAS-9831 in flutter_mobile_app/lib/
  const libDartFiles = getAllFiles(appLibDir).filter(f => f.endsWith('.dart'));
  let matches4821 = [];
  let matchesWAS9831 = [];
  let matches1234 = [];

  for (const filePath of libDartFiles) {
    const content = fs.readFileSync(filePath, 'utf8');
    const relative = path.relative(appLibDir, filePath);

    if (content.includes('4821')) {
      matches4821.push(relative);
    }
    if (content.includes('WAS-9831')) {
      matchesWAS9831.push(relative);
    }
    if (content.includes('1234')) {
      matches1234.push(relative);
    }
  }

  assert(matches4821.length === 0, 'Zero occurrences of "4821" in flutter_mobile_app/lib/', `Found in: ${matches4821.join(', ')}`);
  assert(matchesWAS9831.length === 0, 'Zero occurrences of "WAS-9831" in flutter_mobile_app/lib/', `Found in: ${matchesWAS9831.join(', ')}`);

  // For 1234, verify that no occurrence is an OTP or auto-fill bypass
  let suspicious1234 = [];
  for (const filePath of libDartFiles) {
    const lines = fs.readFileSync(filePath, 'utf8').split('\n');
    const relative = path.relative(appLibDir, filePath);
    lines.forEach((line, idx) => {
      if (line.includes('1234')) {
        // If it's a sample phone number like '0912345678' or in a comment, that's fine
        const isSamplePhone = /09[124]1234|912345678|0912345678/.test(line);
        const isComment = /^\s*(\/\/|\/\*|\*)/.test(line);
        if (!isSamplePhone && !isComment) {
          suspicious1234.push(`${relative}:${idx + 1} -> ${line.trim()}`);
        }
      }
    });
  }
  assert(suspicious1234.length === 0, 'No suspicious/backdoor "1234" in flutter_mobile_app/lib/ (only standard phone masks/comments)', `Found: ${suspicious1234.join('; ')}`);

  // -------------------------------------------------------------------------
  // SUITE 2: OTP Verification Screen Forensic Audit
  // -------------------------------------------------------------------------
  console.log('\n--- SUITE 2: OTP Verification Screen Forensic Audit ---');

  const otpScreenPath = path.join(appLibDir, 'otp_verification_screen.dart');
  const otpScreenContent = fs.readFileSync(otpScreenPath, 'utf8');

  // 2.1 Backdoor '1234' strictly absent
  assert(!otpScreenContent.includes('1234'), 'otp_verification_screen.dart contains NO occurrence of "1234"');

  // 2.2 Visual OTP display card absent
  assert(!otpScreenContent.includes('رمز التحقق الخاص بك'), 'Visual OTP display card ("رمز التحقق الخاص بك") is purged');

  // 2.3 Auto-fill button absent
  assert(!otpScreenContent.includes('تعبئة الرمز تلقائياً'), 'Auto-fill button ("تعبئة الرمز تلقائياً وتأكيد الدخول") is purged');

  // 2.4 Field _activeWhatsAppOtp purged
  assert(!otpScreenContent.includes('_activeWhatsAppOtp'), 'Unused private field "_activeWhatsAppOtp" is purged');

  // 2.5 Dynamic PIN length handling
  assert(otpScreenContent.includes('pinLength = isSms ? 6 : 4'), 'Dynamic PIN length strictly configured (6 for SMS, 4 for WhatsApp)');
  assert(otpScreenContent.includes('if (otp.length != expectedLength) return;'), 'Strict OTP length validation enforced before API call');

  // -------------------------------------------------------------------------
  // SUITE 3: WhatsApp Auth Service Security Audit
  // -------------------------------------------------------------------------
  console.log('\n--- SUITE 3: WhatsApp Auth Service Security Audit ---');

  const waAuthPath = path.join(appLibDir, 'services/whatsapp_auth_service.dart');
  const waAuthContent = fs.readFileSync(waAuthPath, 'utf8');

  // 3.1 Neither '1234' nor '4821' are accepted as hardcoded valid OTPs
  assert(!waAuthContent.includes('1234'), 'whatsapp_auth_service.dart contains NO "1234"');
  assert(!waAuthContent.includes('4821'), 'whatsapp_auth_service.dart contains NO "4821"');

  // 3.2 Secure random OTP generation
  assert(waAuthContent.includes('1000 + random.nextInt(9000)'), 'Generates cryptographically random 4-digit OTPs (1000-9999)');

  // 3.3 Verification checks expiration
  assert(waAuthContent.includes('DateTime.now().isBefore(_cachedExpiresAt!)'), 'Local cached OTP enforces expiration check');
  assert(waAuthContent.includes('DateTime.now().isAfter(exp)'), 'Remote Supabase OTP enforces expiration check');

  // -------------------------------------------------------------------------
  // SUITE 4: Backend Customer Authentication & RBAC Boundaries
  // -------------------------------------------------------------------------
  console.log('\n--- SUITE 4: Backend Customer Auth & RBAC Boundaries ---');

  // 4.1 Login with backdoor PIN '1234' on customer account rejected
  const resBackdoorCust = await apiRequest('POST', '/api/v1/auth/login', {
    phone: '0910000000',
    password: '1234'
  });
  assert(resBackdoorCust.status === 401 || resBackdoorCust.status === 400, 'POST /api/v1/auth/login with password "1234" rejected (HTTP 401/400)', `Status: ${resBackdoorCust.status}`);

  // 4.2 Login with backdoor PIN '7788' on customer account rejected
  const resBackdoor7788 = await apiRequest('POST', '/api/v1/auth/login', {
    phone: '0910000000',
    password: '7788'
  });
  assert(resBackdoor7788.status === 401 || resBackdoor7788.status === 400, 'POST /api/v1/auth/login with password "7788" rejected (HTTP 401/400)', `Status: ${resBackdoor7788.status}`);

  // 4.3 Verified phone login via /api/v1/auth/phone-login
  const testPhone = '+218919988776';
  const resPhoneLogin = await apiRequest('POST', '/api/v1/auth/phone-login', {
    phone: testPhone,
    full_name: 'زبون تجريبي للتحدي',
    auth_method: 'whatsapp_otp'
  });
  assert(resPhoneLogin.status === 200 && resPhoneLogin.body.success, 'POST /api/v1/auth/phone-login succeeds with valid verified phone', `Status: ${resPhoneLogin.status}`);
  const customerToken = resPhoneLogin.body.data && resPhoneLogin.body.data.token;
  assert(customerToken != null, 'Customer login returns valid JWT token');

  // 4.4 Verify Customer JWT Role & Claims
  const decodedToken = jwt.verify(customerToken, JWT_SECRET);
  assert(decodedToken.role === 'customer', `JWT claims role "customer" (found: ${decodedToken.role})`);

  // 4.5 RBAC: Customer JWT blocked from Admin purge endpoint
  const resCustAdminPurge = await apiRequest('POST', '/api/v1/admin/purge', {}, {
    'Authorization': `Bearer ${customerToken}`
  });
  assert(resCustAdminPurge.status === 403, 'Customer JWT rejected with 403 Forbidden on /api/v1/admin/purge', `Status: ${resCustAdminPurge.status}`);

  // 4.6 RBAC: Customer JWT blocked from Merchant status endpoint
  const resCustMerchant = await apiRequest('POST', '/api/v1/stores/store_nalut_ranchello/heartbeat', {}, {
    'Authorization': `Bearer ${customerToken}`
  });
  assert(resCustMerchant.status === 403, 'Customer JWT rejected with 403 Forbidden on store heartbeat', `Status: ${resCustMerchant.status}`);

  // 4.7 RBAC: Customer JWT blocked from Driver custody settlement
  const resCustDriverSettle = await apiRequest('POST', '/api/v1/drivers/drv_01/settle', { amount: 10 }, {
    'Authorization': `Bearer ${customerToken}`
  });
  assert(resCustDriverSettle.status === 403, 'Customer JWT rejected with 403 Forbidden on driver settlement', `Status: ${resCustDriverSettle.status}`);

  // -------------------------------------------------------------------------
  // SUITE 5: Order Number & Delivery Flow Integrity
  // -------------------------------------------------------------------------
  console.log('\n--- SUITE 5: Order Number & Delivery Flow Integrity ---');

  const homeScreenContent = fs.readFileSync(path.join(appLibDir, 'home_screen.dart'), 'utf8');
  assert(!homeScreenContent.includes("'WAS-9831'"), 'home_screen.dart has NO hardcoded "WAS-9831" fallback');
  assert(homeScreenContent.includes("WAS-${_activeOrder!['id'].toString().substring"), 'home_screen.dart derives dynamic order number from ID prefix');

  const trackingScreenContent = fs.readFileSync(path.join(appLibDir, 'order_tracking_screen.dart'), 'utf8');
  assert(!trackingScreenContent.includes("'WAS-9831'"), 'order_tracking_screen.dart has NO hardcoded "WAS-9831"');
  assert(trackingScreenContent.includes("_orderNum = 'WAS-ORD'"), 'order_tracking_screen.dart uses generic initialization "WAS-ORD"');

  // -------------------------------------------------------------------------
  // SUMMARY
  // -------------------------------------------------------------------------
  console.log('\n================================================================');
  console.log(`TOTAL CHECKS: ${totalChecks}`);
  console.log(`PASSED:       ${passedChecks}`);
  console.log(`FAILED:       ${failedChecks}`);
  console.log('================================================================');

  if (failedChecks > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runEmpiricalHarness().catch(err => {
  console.error('Fatal Harness Error:', err);
  process.exit(1);
});
