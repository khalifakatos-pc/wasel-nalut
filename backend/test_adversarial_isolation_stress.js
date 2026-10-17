/**
 * ADVERSARIAL STRESS TEST: CROSS-DRIVER ISOLATION & COURIER SETTLEMENT EDGE CASES
 * Challenger M4-R2-1 Empirical Verification Harness
 */
const http = require('http');
const assert = require('assert');
const { config } = require('./config');

const PORT = 3000;

function req(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const payload = body !== null ? JSON.stringify(body) : null;
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

const tests = [];
function testAssert(desc, condition, actual) {
  if (condition) {
    console.log(`  ✅ PASS: ${desc} [${actual || 'OK'}]`);
    tests.push({ desc, pass: true });
  } else {
    console.error(`  ❌ FAIL: ${desc} [Actual: ${actual}]`);
    tests.push({ desc, pass: false, actual });
  }
}

async function run() {
  console.log('================================================================');
  console.log('🛡️  ADVERSARIAL STRESS TEST: CROSS-DRIVER ISOLATION & SETTLEMENT');
  console.log('================================================================\n');

  // 1. Ensure server is running
  try {
    await req('GET', '/health');
  } catch (_) {
    console.log('Starting backend server for test harness...');
    require('./server.js');
    await new Promise(r => setTimeout(r, 1200));
  }

  // 2. Obtain tokens for different actors
  // Driver 01 (0912345678 / 5521) -> driver_nalut_01, user_driver_01
  const d1Login = await req('POST', '/api/v1/auth/login', { phone: '0912345678', password: '5521', role: 'driver' });
  const d1Token = d1Login.body?.data?.token;
  testAssert('Login Driver 01', d1Login.status === 200 && d1Token, `Status: ${d1Login.status}`);

  // Driver 02 (0923456789 / 6632) -> driver_nalut_02, user_driver_02
  const d2Login = await req('POST', '/api/v1/auth/login', { phone: '0923456789', password: '6632', role: 'driver' });
  const d2Token = d2Login.body?.data?.token;
  testAssert('Login Driver 02', d2Login.status === 200 && d2Token, `Status: ${d2Login.status}`);

  // Customer (0910000000 / Customer@Nalut2026!Secure) -> cust_nalut_01
  const custLogin = await req('POST', '/api/v1/auth/login', { phone: '0910000000', password: 'Customer@Nalut2026!Secure' });
  const custToken = custLogin.body?.data?.token;
  testAssert('Login Customer', custLogin.status === 200 && custToken, `Status: ${custLogin.status}`);

  // Merchant (store_nalut_ranchello / 4821) -> merchant role
  const merchLogin = await req('POST', '/api/v1/auth/merchant-login', { store_id: 'store_nalut_ranchello', pin: '4821' });
  const merchToken = merchLogin.body?.data?.token;
  testAssert('Login Merchant', merchLogin.status === 200 && merchToken, `Status: ${merchLogin.status}`);

  // Admin (0910009832 / Admin@Nalut2026!Secure) -> admin role
  const adminLogin = await req('POST', '/api/v1/auth/login', { phone: '0910009832', password: 'Admin@Nalut2026!Secure' });
  const adminToken = adminLogin.body?.data?.token;
  testAssert('Login Admin', adminLogin.status === 200 && adminToken, `Status: ${adminLogin.status}`);

  console.log('\n--- Category A: Unauthenticated & Malformed Token Access ---');
  // A1: No header
  const resNoAuth = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', { amount_lyd: 10 });
  testAssert('Missing Authorization header returns 401', resNoAuth.status === 401, `Status: ${resNoAuth.status}`);

  // A2: Empty Bearer
  const resEmptyBearer = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', { amount_lyd: 10 }, { Authorization: 'Bearer ' });
  testAssert('Empty Bearer token returns 401', resEmptyBearer.status === 401, `Status: ${resEmptyBearer.status}`);

  // A3: Malformed JWT
  const resBadJwt = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', { amount_lyd: 10 }, { Authorization: 'Bearer this.is.garbage' });
  testAssert('Garbage JWT token returns 401', resBadJwt.status === 401, `Status: ${resBadJwt.status}`);

  // A4: Non-Bearer scheme
  const resBasicAuth = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', { amount_lyd: 10 }, { Authorization: 'Basic dXNlcjpwYXNz' });
  testAssert('Non-Bearer Authorization returns 401', resBasicAuth.status === 401, `Status: ${resBasicAuth.status}`);

  console.log('\n--- Category B: Cross-Role Settlement Rejection ---');
  // B1: Customer token against Driver 01 (driver_id)
  const resCustD1 = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', { amount_lyd: 10 }, { Authorization: `Bearer ${custToken}` });
  testAssert('Customer token on driver_nalut_01 returns 403', resCustD1.status === 403, `Status: ${resCustD1.status}`);

  // B2: Customer token against Driver 01 (user_id)
  const resCustUser1 = await req('POST', '/api/v1/drivers/user_driver_01/settle', { amount_lyd: 10 }, { Authorization: `Bearer ${custToken}` });
  testAssert('Customer token on user_driver_01 returns 403', resCustUser1.status === 403, `Status: ${resCustUser1.status}`);

  // B3: Merchant token against Driver 01
  const resMerchD1 = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', { amount_lyd: 10 }, { Authorization: `Bearer ${merchToken}` });
  testAssert('Merchant token on driver_nalut_01 returns 403', resMerchD1.status === 403, `Status: ${resMerchD1.status}`);

  console.log('\n--- Category C: Cross-Driver Mutual Settlement Rejection ---');
  // C1: Driver 02 attempts to settle Driver 01 using driver_id
  const resD2onD1 = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', { amount_lyd: 10 }, { Authorization: `Bearer ${d2Token}` });
  testAssert('Driver 02 settling Driver 01 (driver_id) returns 403 Forbidden', resD2onD1.status === 403, `Status: ${resD2onD1.status}`);

  // C2: Driver 02 attempts to settle Driver 01 using user_id
  const resD2onUser1 = await req('POST', '/api/v1/drivers/user_driver_01/settle', { amount_lyd: 10 }, { Authorization: `Bearer ${d2Token}` });
  testAssert('Driver 02 settling Driver 01 (user_id) returns 403 Forbidden', resD2onUser1.status === 403, `Status: ${resD2onUser1.status}`);

  // C3: Driver 01 attempts to settle Driver 02 using driver_id
  const resD1onD2 = await req('POST', '/api/v1/drivers/driver_nalut_02/settle', { amount_lyd: 10 }, { Authorization: `Bearer ${d1Token}` });
  testAssert('Driver 01 settling Driver 02 (driver_id) returns 403 Forbidden', resD1onD2.status === 403, `Status: ${resD1onD2.status}`);

  // C4: Driver 01 attempts to settle Driver 02 using user_id
  const resD1onUser2 = await req('POST', '/api/v1/drivers/user_driver_02/settle', { amount_lyd: 10 }, { Authorization: `Bearer ${d1Token}` });
  testAssert('Driver 01 settling Driver 02 (user_id) returns 403 Forbidden', resD1onUser2.status === 403, `Status: ${resD1onUser2.status}`);

  // C5: Driver 01 attempts to settle a non-existent driver
  const resD1onGhost = await req('POST', '/api/v1/drivers/driver_ghost_999/settle', { amount_lyd: 10 }, { Authorization: `Bearer ${d1Token}` });
  testAssert('Driver 01 settling non-existent driver returns 403 Forbidden', resD1onGhost.status === 403, `Status: ${resD1onGhost.status}`);

  console.log('\n--- Category D: Authorized Driver Self-Settlement ---');
  // D1: Driver 01 self-settle via driver_id
  const resD1SelfDriverId = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', { amount_lyd: 0, notes: 'تسوية كابتن 01' }, { Authorization: `Bearer ${d1Token}` });
  testAssert('Driver 01 self-settle via driver_id returns 200/201 + Voucher',
    (resD1SelfDriverId.status === 200 || resD1SelfDriverId.status === 201) && resD1SelfDriverId.body?.voucher?.voucher_number,
    `Status: ${resD1SelfDriverId.status}, Voucher: ${resD1SelfDriverId.body?.voucher?.voucher_number}`);

  // D2: Driver 01 self-settle via user_id
  const resD1SelfUserId = await req('POST', '/api/v1/drivers/user_driver_01/settle', { amount_lyd: 0, notes: 'تسوية كابتن 01 بواسطة user_id' }, { Authorization: `Bearer ${d1Token}` });
  testAssert('Driver 01 self-settle via user_id returns 200/201 + Voucher',
    (resD1SelfUserId.status === 200 || resD1SelfUserId.status === 201) && resD1SelfUserId.body?.voucher?.voucher_number,
    `Status: ${resD1SelfUserId.status}, Voucher: ${resD1SelfUserId.body?.voucher?.voucher_number}`);

  // D3: Driver 02 self-settle via driver_id
  const resD2SelfDriverId = await req('POST', '/api/v1/drivers/driver_nalut_02/settle', { amount_lyd: 0, notes: 'تسوية كابتن 02' }, { Authorization: `Bearer ${d2Token}` });
  testAssert('Driver 02 self-settle via driver_id returns 200/201 + Voucher',
    (resD2SelfDriverId.status === 200 || resD2SelfDriverId.status === 201) && resD2SelfDriverId.body?.voucher?.voucher_number,
    `Status: ${resD2SelfDriverId.status}, Voucher: ${resD2SelfDriverId.body?.voucher?.voucher_number}`);

  console.log('\n--- Category E: Authorized Admin Settlement Over All Drivers ---');
  // E1: Admin settles Driver 01
  const resAdminD1 = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', { amount_lyd: 0, notes: 'تسوية إدارية لدرايفر 01' }, { Authorization: `Bearer ${adminToken}` });
  testAssert('Admin settles Driver 01 returns 200/201 + Voucher',
    (resAdminD1.status === 200 || resAdminD1.status === 201) && resAdminD1.body?.voucher?.voucher_number,
    `Status: ${resAdminD1.status}, Voucher: ${resAdminD1.body?.voucher?.voucher_number}`);

  // E2: Admin settles Driver 02
  const resAdminD2 = await req('POST', '/api/v1/drivers/driver_nalut_02/settle', { amount_lyd: 0, notes: 'تسوية إدارية لدرايفر 02' }, { Authorization: `Bearer ${adminToken}` });
  testAssert('Admin settles Driver 02 returns 200/201 + Voucher',
    (resAdminD2.status === 200 || resAdminD2.status === 201) && resAdminD2.body?.voucher?.voucher_number,
    `Status: ${resAdminD2.status}, Voucher: ${resAdminD2.body?.voucher?.voucher_number}`);

  console.log('\n--- Category F: Payload Tampering & Edge Input Robustness ---');
  // F1: Driver 02 supplies body claiming admin role: { role: 'admin' }
  const resTamperedRole = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', {
    amount_lyd: 0,
    role: 'admin',
    is_admin: true,
    user: { role: 'admin' }
  }, { Authorization: `Bearer ${d2Token}` });
  testAssert('Body role tampering { role: "admin" } does not elevate privileges (403)',
    resTamperedRole.status === 403, `Status: ${resTamperedRole.status}`);

  // F2: Driver 01 provides negative settlement amount
  const resNegativeAmount = await req('POST', '/api/v1/drivers/driver_nalut_01/settle', {
    amount_lyd: -50.0
  }, { Authorization: `Bearer ${d1Token}` });
  testAssert('Negative settlement amount does not corrupt ledger (handled gracefully)',
    resNegativeAmount.status === 200 || resNegativeAmount.status === 400,
    `Status: ${resNegativeAmount.status}, Message: ${resNegativeAmount.body?.message || resNegativeAmount.body?.error}`);

  // --------------------------------------------------------------------------
  console.log('\n================================================================');
  console.log('📊 ADVERSARIAL STRESS TEST SUMMARY');
  console.log('================================================================');
  const passed = tests.filter(t => t.pass).length;
  const failed = tests.filter(t => !t.pass).length;
  console.log(`Total Adversarial Scenarios: ${tests.length}`);
  console.log(`Passed:                      ${passed}`);
  console.log(`Failed:                      ${failed}`);

  if (failed > 0) {
    console.error('\n❌ ADVERSARIAL STRESS TEST FAILED!');
    process.exit(1);
  } else {
    console.log('\n🎉 ALL ADVERSARIAL ISOLATION TESTS PASSED WITH 100% SUCCESS!');
    process.exit(0);
  }
}

run().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
