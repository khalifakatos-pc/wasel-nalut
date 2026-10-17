/**
 * ============================================================================
 * INDEPENDENT EMPIRICAL CHALLENGER DEEP VERIFICATION SUITE — M1 RECHECK
 * ============================================================================
 * Target: Complete adversarial testing of server.js M1 remediation
 * Probing:
 * 1. Parameter tampering variants for adminOverride across all roles
 * 2. OTP enforcement under forged adminOverride
 * 3. Terminal state reassignment prevention
 * 4. Driver status enum validation ('online_idle' vs 'available')
 * 5. Purge PIN enforcement (rejecting null, empty, wrong, legacy PIN 1234)
 * 6. Order deletion cache consistency using order_number
 * ============================================================================
 */

const assert = require('assert');
const http = require('http');
const jwt = require('jsonwebtoken');

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'wasel-nalut-secure-jwt-key-2026-prod';

const results = [];

function logTest(id, desc, passed, details = {}) {
  results.push({ id, desc, passed, details });
  const mark = passed ? '✅ PASS' : '❌ FAIL';
  console.log(`[${mark}] ${id}: ${desc}`);
  if (details && Object.keys(details).length > 0) {
    console.log(`       Details: ${JSON.stringify(details)}`);
  }
}

function req(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const data = body !== null ? JSON.stringify(body) : null;
    const headers = { 'Content-Type': 'application/json' };
    if (data) headers['Content-Length'] = Buffer.byteLength(data);
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const r = http.request({
      hostname: '127.0.0.1',
      port: PORT,
      path,
      method: method.toUpperCase(),
      headers
    }, (res) => {
      let str = '';
      res.on('data', chunk => str += chunk);
      res.on('end', () => {
        let json = null;
        try { json = JSON.parse(str); } catch (_) { json = str; }
        resolve({ status: res.statusCode, headers: res.headers, body: json });
      });
    });
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

async function runEmpiricalDeepSuite() {
  console.log('================================================================');
  console.log('🔬 INDEPENDENT EMPIRICAL CHALLENGER DEEP AUDIT');
  console.log('================================================================\n');

  const server = require('./server.js');
  const db = server.db;

  const JWT_SECRET = process.env.JWT_SECRET || 'wasel-nalut-secure-jwt-key-2026-prod';

  await new Promise(r => setTimeout(r, 600));

  const adminToken = jwt.sign({
    id: 'admin_test_m1',
    sub: 'admin_test_m1',
    role: 'admin',
    phone: '0910009832'
  }, JWT_SECRET, { expiresIn: '1h' });

  const customerToken = jwt.sign({
    id: 'cust_adv_test',
    sub: 'cust_adv_test',
    role: 'customer',
    phone: '0919999999'
  }, JWT_SECRET, { expiresIn: '1h' });

  const driverToken = jwt.sign({
    id: 'drv_adv_01',
    sub: 'drv_adv_01',
    role: 'driver',
    driver_id: 'drv_adv_01',
    phone: '0918888888'
  }, JWT_SECRET, { expiresIn: '1h' });

  // Setup test drivers in db
  if (!db.drivers.find(d => d.id === 'drv_adv_01')) {
    db.drivers.push({
      id: 'drv_adv_01',
      name: 'Adversarial Driver 1',
      phone: '0918888888',
      status: 'online_idle',
      active_order_id: null,
      cod_balance_lyd: 0.0
    });
  }
  if (!db.drivers.find(d => d.id === 'drv_adv_02')) {
    db.drivers.push({
      id: 'drv_adv_02',
      name: 'Adversarial Driver 2',
      phone: '0917777777',
      status: 'online_idle',
      active_order_id: null,
      cod_balance_lyd: 0.0
    });
  }

  // ==========================================================================
  // SECTION 1: FORGERY FUZZING ON adminOverride
  // ==========================================================================
  console.log('--- TEST GROUP 1: Parameter Tampering & Forgery Fuzzing ---');

  const tamperingPayloads = [
    { adminOverride: true },
    { admin_override: true },
    { adminOverride: 'true' },
    { admin_override: '1' },
    { adminOverride: 1 },
    { adminOverride: {} },
    { adminOverride: [] }
  ];

  let allTamperingBlocked = true;
  for (let i = 0; i < tamperingPayloads.length; i++) {
    const payload = tamperingPayloads[i];
    const testOrd = {
      id: `ord_fuzz_${i}`,
      order_number: `ORD-FUZZ-${i}`,
      customer_id: 'cust_adv_test',
      status: 'placed',
      total_amount_lyd: 25.0,
      delivery_otp: '4321',
      created_at: new Date().toISOString()
    };
    db.orders.push(testOrd);

    // Customer attempts to jump placed -> delivered with tampering payload
    const res = await req('POST', `/api/v1/orders/${testOrd.id}/status`, {
      status: 'delivered',
      ...payload
    }, customerToken);

    // Must be rejected with 400 Bad Request
    const blocked = res.status === 400 && testOrd.status === 'placed';
    if (!blocked) {
      allTamperingBlocked = false;
      console.error(`  FAIL on payload:`, payload, `Response:`, res.status, res.body);
    }
  }
  logTest('EMP-1.1', 'All 7 parameter tampering variations for adminOverride blocked from customer', allTamperingBlocked);

  // Driver attempting same tampering
  let driverTamperingBlocked = true;
  for (let i = 0; i < 3; i++) {
    const testOrd = {
      id: `ord_drv_fuzz_${i}`,
      order_number: `ORD-DRV-FUZZ-${i}`,
      customer_id: 'cust_adv_test',
      driver_id: 'drv_adv_01',
      status: 'out_for_delivery',
      delivery_otp: '5566',
      total_amount_lyd: 30.0,
      created_at: new Date().toISOString()
    };
    db.orders.push(testOrd);

    // Driver attempts to complete delivery with forged adminOverride and NO OTP
    const res = await req('POST', `/api/v1/orders/${testOrd.id}/status`, {
      status: 'delivered',
      adminOverride: true
    }, driverToken);

    const blocked = res.status === 400 && testOrd.status === 'out_for_delivery';
    if (!blocked) {
      driverTamperingBlocked = false;
      console.error(`  Driver bypass succeeded! Status:`, res.status, res.body);
    }
  }
  logTest('EMP-1.2', 'Driver cannot bypass OTP requirement via forged adminOverride', driverTamperingBlocked);

  // Driver completing delivery WITH valid OTP
  const validDeliveryOrd = {
    id: 'ord_valid_delivery_01',
    order_number: 'ORD-VALID-DEL',
    customer_id: 'cust_adv_test',
    driver_id: 'drv_adv_01',
    status: 'out_for_delivery',
    delivery_otp: '7890',
    total_amount_lyd: 30.0,
    created_at: new Date().toISOString()
  };
  db.orders.push(validDeliveryOrd);

  const validDelRes = await req('POST', `/api/v1/orders/${validDeliveryOrd.id}/status`, {
    status: 'delivered',
    otp_code: '7890'
  }, driverToken);

  const deliverySuccess = validDelRes.status === 200 && validDeliveryOrd.status === 'delivered';
  logTest('EMP-1.3', 'Driver transitions out_for_delivery -> delivered with valid OTP succeeds', deliverySuccess, {
    statusCode: validDelRes.status
  });

  // ==========================================================================
  // SECTION 2: TERMINAL ORDER REASSIGNMENT GUARDS
  // ==========================================================================
  console.log('\n--- TEST GROUP 2: Terminal State Reassignment Guards ---');

  // Test 2.1: Reassigning a delivered order
  const deliveredOrd = {
    id: 'ord_term_delivered',
    order_number: 'ORD-TERM-DEL',
    customer_id: 'cust_adv_test',
    driver_id: 'drv_adv_01',
    status: 'delivered',
    total_amount_lyd: 40.0,
    created_at: new Date().toISOString()
  };
  db.orders.push(deliveredOrd);

  const reassignDeliveredRes = await req('POST', `/api/v1/orders/${deliveredOrd.id}/reassign`, {
    driver_id: 'drv_adv_02'
  }, adminToken);

  const deliveredBlocked = reassignDeliveredRes.status === 400 &&
    reassignDeliveredRes.body?.error?.includes('لا يمكن إعادة إسناد كابتن لطلب منتهٍ بحالة: delivered');
  logTest('EMP-2.1', 'Reassign driver on delivered order strictly blocked (400)', deliveredBlocked, {
    statusCode: reassignDeliveredRes.status,
    error: reassignDeliveredRes.body?.error
  });

  // Test 2.2: Reassigning a cancelled order
  const cancelledOrd = {
    id: 'ord_term_cancelled',
    order_number: 'ORD-TERM-CAN',
    customer_id: 'cust_adv_test',
    driver_id: 'drv_adv_01',
    status: 'cancelled',
    total_amount_lyd: 40.0,
    created_at: new Date().toISOString()
  };
  db.orders.push(cancelledOrd);

  const reassignCancelledRes = await req('POST', `/api/v1/orders/${cancelledOrd.id}/reassign`, {
    driver_id: 'drv_adv_02'
  }, adminToken);

  const cancelledBlocked = reassignCancelledRes.status === 400 &&
    reassignCancelledRes.body?.error?.includes('لا يمكن إعادة إسناد كابتن لطلب منتهٍ بحالة: cancelled');
  logTest('EMP-2.2', 'Reassign driver on cancelled order strictly blocked (400)', cancelledBlocked, {
    statusCode: reassignCancelledRes.status,
    error: reassignCancelledRes.body?.error
  });

  // Test 2.3: Reassigning active order and verifying driver status is 'online_idle' (NOT 'available')
  const activeOrd = {
    id: 'ord_active_reassign',
    order_number: 'ORD-ACT-REAS',
    customer_id: 'cust_adv_test',
    driver_id: 'drv_adv_01',
    status: 'preparing',
    total_amount_lyd: 40.0,
    created_at: new Date().toISOString()
  };
  db.orders.push(activeOrd);

  const drv1 = db.drivers.find(d => d.id === 'drv_adv_01');
  const drv2 = db.drivers.find(d => d.id === 'drv_adv_02');
  drv1.status = 'busy_delivery';
  drv1.active_order_id = activeOrd.id;
  drv2.status = 'online_idle';
  drv2.active_order_id = null;

  const validReassignRes = await req('POST', `/api/v1/orders/${activeOrd.id}/reassign`, {
    driver_id: 'drv_adv_02'
  }, adminToken);

  const passReassign = validReassignRes.status === 200 &&
    activeOrd.driver_id === 'drv_adv_02' &&
    drv1.status === 'online_idle' && // Critical enum check!
    drv1.active_order_id === null &&
    drv2.status === 'busy_delivery' &&
    drv2.active_order_id === activeOrd.id;

  logTest('EMP-2.3', 'Active order reassign resets previous driver to online_idle (not available)', passReassign, {
    statusCode: validReassignRes.status,
    prevDriverStatus: drv1.status,
    newDriverStatus: drv2.status
  });

  // ==========================================================================
  // SECTION 3: PURGE SECURITY & MANDATORY PIN PROBES
  // ==========================================================================
  console.log('\n--- TEST GROUP 3: Purge Security & Mandatory PIN ---');

  const purgeTestCases = [
    { desc: 'Missing body', body: null, expectedStatus: 401 },
    { desc: 'Empty body {}', body: {}, expectedStatus: 401 },
    { desc: 'Null PIN { pin: null }', body: { pin: null }, expectedStatus: 401 },
    { desc: 'Empty string PIN { pin: "" }', body: { pin: "" }, expectedStatus: 401 },
    { desc: 'Legacy Backdoor PIN 1234 { pin: "1234" }', body: { pin: "1234" }, expectedStatus: 401 },
    { desc: 'Wrong PIN { pin: "0000" }', body: { pin: "0000" }, expectedStatus: 401 }
  ];

  let allPurgeGuardsPassed = true;
  for (const tc of purgeTestCases) {
    const res = await req('POST', '/api/v1/admin/orders/purge', tc.body, adminToken);
    const passed = res.status === tc.expectedStatus && res.body?.success === false;
    if (!passed) {
      allPurgeGuardsPassed = false;
      console.error(`  Purge guard failed on ${tc.desc}: got ${res.status}`);
    }
  }
  logTest('EMP-3.1', 'Purge rejects missing, empty, wrong, and backdoor PIN (1234) with 401', allPurgeGuardsPassed);

  // Non-admin sending correct PIN 7788
  const nonAdminPurgeRes = await req('POST', '/api/v1/admin/orders/purge', { pin: '7788' }, customerToken);
  const nonAdminBlocked = nonAdminPurgeRes.status === 403;
  logTest('EMP-3.2', 'Non-admin with correct PIN 7788 blocked with 403 Forbidden', nonAdminBlocked, {
    statusCode: nonAdminPurgeRes.status
  });

  // ==========================================================================
  // SECTION 4: ORDER DELETION CACHE CONSISTENCY (order_number)
  // ==========================================================================
  console.log('\n--- TEST GROUP 4: Order Deletion Cache Consistency ---');

  const delOrd = {
    id: 'ord_uuid_delete_check',
    order_number: 'ORD-DELETE-CHECK-99',
    customer_id: 'cust_adv_test',
    status: 'placed',
    total_amount_lyd: 15.0,
    created_at: new Date().toISOString()
  };
  db.orders.push(delOrd);

  // Delete via order_number (verifying o.order_number === order.order_number fix)
  const delRes = await req('DELETE', `/api/v1/admin/orders/${delOrd.order_number}`, null, adminToken);
  const inDbAfter = db.orders.find(o => o.id === delOrd.id || o.order_number === delOrd.order_number);
  const delPassed = delRes.status === 200 && !inDbAfter;

  logTest('EMP-4.1', 'Order deleted by order_number cleanly removed from in-memory cache', delPassed, {
    statusCode: delRes.status,
    foundInDbAfter: Boolean(inDbAfter)
  });

  // ==========================================================================
  // FINAL SUMMARY
  // ==========================================================================
  console.log('\n================================================================');
  console.log('🏁 EMPIRICAL DEEP VERIFICATION SUMMARY');
  console.log('================================================================');
  const passCount = results.filter(r => r.passed).length;
  const failCount = results.filter(r => !r.passed).length;
  console.log(`Total Invariant Probes: ${results.length}`);
  console.log(`Passed: ${passCount}`);
  console.log(`Failed: ${failCount}`);

  if (failCount === 0) {
    console.log('\n🎉 ALL DEEP EMPIRICAL CHALLENGER PROBES PASSED PERFECTLY!');
  } else {
    console.log('\n❌ EMPIRICAL FAILURES DETECTED!');
  }

  return { total: results.length, passed: passCount, failed: failCount, results };
}

if (require.main === module) {
  runEmpiricalDeepSuite().then(s => {
    process.exit(s.failed > 0 ? 1 : 0);
  }).catch(e => {
    console.error('Fatal Test Crash:', e);
    process.exit(2);
  });
}

module.exports = { runEmpiricalDeepSuite };
