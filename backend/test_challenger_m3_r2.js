/**
 * ============================================================================
 * WASEL NALUT: CHALLENGER M3-R2-1 EMPIRICAL VERIFICATION HARNESS
 * ============================================================================
 * Scope: Customer App (flutter_mobile_app) & System Integrity
 * 1. Verify 1234 cannot be auto-filled or accepted as a valid OTP.
 * 2. Verify driver_radar_sheet.dart does not exist on the filesystem.
 * 3. Verify 0 matches for 4821 and WAS-9831 in flutter_mobile_app/lib/.
 * 4. Verify static analysis cleanliness (flutter analyze lib: 0 issues).
 * 5. Run and verify backend test suites:
 *    - test_accounting_engine.js (7/7 passing, 0.0000 LYD imbalance)
 *    - test_e2e_order_lifecycle.js (50/50 passing)
 * ============================================================================
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

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

function getAllDartFiles(dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    const fullPath = path.join(dir, file);
    const stat = fs.statSync(fullPath);
    if (stat && stat.isDirectory()) {
      results = results.concat(getAllDartFiles(fullPath));
    } else if (file.endsWith('.dart')) {
      results.push(fullPath);
    }
  });
  return results;
}

async function runChallengerSuite() {
  console.log('================================================================');
  console.log('⚔️  WASEL NALUT: CHALLENGER M3-R2-1 EMPIRICAL VERIFICATION HARNESS');
  console.log('================================================================\n');

  const rootDir = path.resolve(__dirname, '..');
  const customerLibDir = path.join(rootDir, 'flutter_mobile_app', 'lib');

  // --------------------------------------------------------------------------
  // SUITE 1: Filesystem Absence of driver_radar_sheet.dart
  // --------------------------------------------------------------------------
  console.log('--- SUITE 1: Filesystem Absence of driver_radar_sheet.dart ---');
  const radarSheetPath = path.join(customerLibDir, 'driver_radar_sheet.dart');
  const radarSheetExists = fs.existsSync(radarSheetPath);
  recordTest(
    'FilePurge',
    'driver_radar_sheet.dart does not exist in flutter_mobile_app/lib/',
    !radarSheetExists,
    radarSheetExists ? `File still exists at ${radarSheetPath}` : ''
  );

  // Search entire repo for any rogue copy of driver_radar_sheet.dart
  let allRadarFiles = [];
  try {
    const gitLs = execSync('git ls-files "*driver_radar_sheet*"', { cwd: rootDir, encoding: 'utf8' }).trim();
    if (gitLs) allRadarFiles = gitLs.split('\n');
  } catch (_) {}
  recordTest(
    'FilePurge',
    'driver_radar_sheet.dart is absent from git tracking across entire repository',
    allRadarFiles.length === 0,
    `Found tracked copies: ${allRadarFiles.join(', ')}`
  );

  // --------------------------------------------------------------------------
  // SUITE 2: Zero Matches for 4821 and WAS-9831 in flutter_mobile_app/lib/
  // --------------------------------------------------------------------------
  console.log('\n--- SUITE 2: Zero Matches for 4821 and WAS-9831 in flutter_mobile_app/lib/ ---');
  const dartFiles = getAllDartFiles(customerLibDir);
  console.log(`[Scan] Scanning ${dartFiles.length} Dart source files in flutter_mobile_app/lib/...`);

  let matches4821 = [];
  let matchesWAS9831 = [];

  for (const file of dartFiles) {
    const relPath = path.relative(rootDir, file);
    const content = fs.readFileSync(file, 'utf8');

    if (content.includes('4821')) {
      matches4821.push(relPath);
    }
    if (content.includes('WAS-9831')) {
      matchesWAS9831.push(relPath);
    }
  }

  recordTest(
    'StringPurge',
    '0 occurrences of "4821" in flutter_mobile_app/lib/',
    matches4821.length === 0,
    `Matches found in: ${matches4821.join(', ')}`
  );

  recordTest(
    'StringPurge',
    '0 occurrences of "WAS-9831" in flutter_mobile_app/lib/',
    matchesWAS9831.length === 0,
    `Matches found in: ${matchesWAS9831.join(', ')}`
  );

  // --------------------------------------------------------------------------
  // SUITE 3: OTP Verification Screen & 1234 Backdoor Eradication
  // --------------------------------------------------------------------------
  console.log('\n--- SUITE 3: OTP Verification Screen & 1234 Backdoor Eradication ---');
  const otpScreenPath = path.join(customerLibDir, 'otp_verification_screen.dart');
  const otpContent = fs.readFileSync(otpScreenPath, 'utf8');

  // Check 1: No visual OTP card showing OTP
  const hasVisualOtpCard = otpContent.includes('رمز التحقق الخاص بك:');
  recordTest(
    'OTPSecurity',
    'otp_verification_screen.dart: Visual OTP display card is purged',
    !hasVisualOtpCard,
    'Found "رمز التحقق الخاص بك:" in otp_verification_screen.dart'
  );

  // Check 2: No auto-fill button
  const hasAutoFillBtn = otpContent.includes('تعبئة الرمز تلقائياً');
  recordTest(
    'OTPSecurity',
    'otp_verification_screen.dart: Auto-fill button is purged',
    !hasAutoFillBtn,
    'Found "تعبئة الرمز تلقائياً" in otp_verification_screen.dart'
  );

  // Check 3: No _activeWhatsAppOtp field
  const hasActiveWhatsAppOtp = otpContent.includes('_activeWhatsAppOtp');
  recordTest(
    'OTPSecurity',
    'otp_verification_screen.dart: _activeWhatsAppOtp state field is purged',
    !hasActiveWhatsAppOtp,
    'Found _activeWhatsAppOtp field in otp_verification_screen.dart'
  );

  // Check 4: No hardcoded '1234' in otp_verification_screen.dart
  const has1234InOtpScreen = otpContent.includes('1234');
  recordTest(
    'OTPSecurity',
    'otp_verification_screen.dart: Zero occurrences of "1234"',
    !has1234InOtpScreen,
    'Found "1234" in otp_verification_screen.dart'
  );

  // Check 5: WhatsAppAuthService does not accept 1234 backdoor
  const waAuthPath = path.join(customerLibDir, 'services', 'whatsapp_auth_service.dart');
  const waAuthContent = fs.readFileSync(waAuthPath, 'utf8');
  const has1234InWaAuth = waAuthContent.includes('1234');
  recordTest(
    'OTPSecurity',
    'whatsapp_auth_service.dart: Zero backdoor "1234" bypass checks',
    !has1234InWaAuth,
    'Found "1234" in whatsapp_auth_service.dart'
  );

  // Check 6: WhatsAppAuthService uses random 4-digit generation
  const hasRandomOtp = waAuthContent.includes('1000 + random.nextInt(9000)');
  recordTest(
    'OTPSecurity',
    'whatsapp_auth_service.dart: Generates non-deterministic secure random 4-digit OTP',
    hasRandomOtp,
    'Missing secure random 4-digit OTP generation logic'
  );

  // --------------------------------------------------------------------------
  // SUITE 4: Static Analysis Verification (flutter analyze lib)
  // --------------------------------------------------------------------------
  console.log('\n--- SUITE 4: Static Analysis Verification (flutter analyze lib) ---');
  let analyzeOutput = '';
  let analyzePassed = false;
  try {
    analyzeOutput = execSync('flutter analyze lib', {
      cwd: path.join(rootDir, 'flutter_mobile_app'),
      encoding: 'utf8',
      timeout: 120000
    });
    analyzePassed = analyzeOutput.includes('No issues found!');
  } catch (err) {
    analyzeOutput = (err.stdout || '') + (err.stderr || '');
    analyzePassed = analyzeOutput.includes('No issues found!');
  }

  recordTest(
    'StaticAnalysis',
    'flutter analyze lib in flutter_mobile_app reports 0 issues',
    analyzePassed,
    analyzePassed ? '' : `Output: ${analyzeOutput}`
  );

  // --------------------------------------------------------------------------
  // SUITE 5: Backend Test Suites Execution
  // --------------------------------------------------------------------------
  console.log('\n--- SUITE 5: Backend Test Suites Execution ---');
  
  // 5.1 Accounting Engine
  let accountingOutput = '';
  let accountingPassed = false;
  try {
    accountingOutput = execSync('node backend/test_accounting_engine.js', {
      cwd: rootDir,
      encoding: 'utf8',
      timeout: 30000
    });
    accountingPassed = accountingOutput.includes('ALL 7 ACCOUNTING & GENERAL LEDGER TESTS PASSED SUCCESSFULLY!') &&
                       accountingOutput.includes('0.0000 LYD discrepancy');
  } catch (err) {
    accountingOutput = (err.stdout || '') + (err.stderr || '');
  }

  recordTest(
    'BackendSuites',
    'node backend/test_accounting_engine.js passes (7/7 tests, 0.0000 LYD imbalance)',
    accountingPassed,
    accountingPassed ? '' : `Accounting test failed: ${accountingOutput.slice(-300)}`
  );

  // 5.2 E2E Order Lifecycle
  let e2eOutput = '';
  let e2ePassed = false;
  try {
    e2eOutput = execSync('node backend/test_e2e_order_lifecycle.js', {
      cwd: rootDir,
      encoding: 'utf8',
      timeout: 60000
    });
    const cleanE2E = e2eOutput.replace(/\x1b\[[0-9;]*m/g, '');
    e2ePassed = cleanE2E.includes('100% OF TESTS PASSED! ALL 50 TESTS VERIFIED SUCCESSFULLY.') &&
                cleanE2E.includes('50 │      0 │     50');
  } catch (err) {
    e2eOutput = (err.stdout || '') + (err.stderr || '');
  }

  recordTest(
    'BackendSuites',
    'node backend/test_e2e_order_lifecycle.js passes (50/50 tests)',
    e2ePassed,
    e2ePassed ? '' : `E2E lifecycle test failed: ${e2eOutput.slice(-300)}`
  );

  // --------------------------------------------------------------------------
  // Summary
  // --------------------------------------------------------------------------
  console.log('\n================================================================');
  console.log('  CHALLENGER M3-R2-1 VERIFICATION SUMMARY');
  console.log('================================================================');
  console.log(`  TOTAL CHECKS: ${results.total}`);
  console.log(`  PASSED:       ${results.passed}`);
  console.log(`  FAILED:       ${results.failed}`);
  console.log('================================================================');

  if (results.failed > 0) {
    console.log('\n❌ VERDICT: REQUEST_CHANGES');
    process.exit(1);
  } else {
    console.log('\n🎉 VERDICT: APPROVE');
    process.exit(0);
  }
}

runChallengerSuite().catch(err => {
  console.error('Fatal test harness error:', err);
  process.exit(1);
});
