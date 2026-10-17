/**
 * ============================================================================
 * EMPIRICAL ADVERSARIAL STRESS & VERIFICATION SUITE — CHALLENGER M1_1
 * ============================================================================
 * Target: FSM State Machine & Admin Override Logic
 * Files Audited: backend/services/orderService.js & backend/server.js
 *
 * Requirements Tested:
 * 1. Unauthenticated / non-admin attempts to skip states or transition backwards -> must be strictly REJECTED (400 / 401).
 * 2. Authenticated admin with adminOverride: true forcing transitions to every stage:
 *    - placed, preparing, ready_for_pickup, out_for_delivery, delivered, cancelled -> must SUCCEED (200).
 * 3. Invalid/nonsense status names (e.g. 'flying', 'hacked') with adminOverride -> must be REJECTED (400).
 * 4. Adversarial Edge Case: Parameter Tampering & Privilege Escalation Vulnerability Check
 *    - Does backend allow non-admin callers to bypass FSM transitions or cancel in-flight/delivered orders
 *      by forging { adminOverride: true } in the request body?
 * ============================================================================
 */

const assert = require('assert');
const http = require('http');
const jwt = require('jsonwebtoken');
const orderService = require('./services/orderService');

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'wasel-nalut-secure-jwt-key-2026-prod';

const testResults = [];

function recordResult(testId, name, passed, details = {}) {
  testResults.push({ testId, name, passed, details });
  const icon = passed ? '✅ PASS' : '❌ FAIL';
  console.log(`[${icon}] ${testId}: ${name}`);
  if (details && Object.keys(details).length > 0) {
    console.log(`       Info: ${JSON.stringify(details)}`);
  }
}

function makeHttpRequest(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const payload = body !== null ? JSON.stringify(body) : null;
    const headers = {
      'Content-Type': 'application/json'
    };
    if (payload) {
      headers['Content-Length'] = Buffer.byteLength(payload);
    }
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request({
      hostname: '127.0.0.1',
      port: PORT,
      path,
      method: method.toUpperCase(),
      headers
    }, (res) => {
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
          statusCode: res.statusCode,
          headers: res.headers,
          body: parsed
        });
      });
    });

    req.on('error', reject);
    if (payload) {
      req.write(payload);
    }
    req.end();
  });
}

async function runAdversarialFsmSuite() {
  console.log('================================================================');
  console.log('🛡️  CHALLENGER M1_1: FSM & ADMIN OVERRIDE ADVERSARIAL SUITE');
  console.log('================================================================\n');

  // Load backend server
  const serverModule = require('./server.js');
  const db = serverModule.db;

  const JWT_SECRET = process.env.JWT_SECRET || 'wasel-nalut-secure-jwt-key-2026-prod';

  // Wait for server initialization
  await new Promise(r => setTimeout(r, 600));

  // Generate test tokens
  const adminToken = jwt.sign({
    id: 'admin_master',
    sub: 'admin_master',
    role: 'admin',
    phone: '0910009832'
  }, JWT_SECRET, { expiresIn: '1h' });

  const customerToken = jwt.sign({
    id: 'usr_guest_nalut',
    sub: 'usr_guest_nalut',
    role: 'customer',
    phone: '0910000000'
  }, JWT_SECRET, { expiresIn: '1h' });

  const driverToken = jwt.sign({
    id: 'driver_nalut_01',
    sub: 'driver_nalut_01',
    role: 'driver',
    driver_id: 'driver_nalut_01',
    phone: '0912345678'
  }, JWT_SECRET, { expiresIn: '1h' });

  // ==========================================================================
  // SECTION 1: UNIT-LEVEL FSM INTEGRITY (orderService.validateTransition)
  // ==========================================================================
  console.log('--- SECTION 1: Pure FSM Transition Matrix & Logic Verification ---\n');

  // Test 1.1: Legitimate sequential progression
  const seqTransitions = [
    ['pending', 'placed'],
    ['placed', 'accepted'],
    ['accepted', 'preparing'],
    ['preparing', 'ready_for_pickup'],
    ['ready_for_pickup', 'driver_assigned'],
    ['driver_assigned', 'driver_arrived'],
    ['driver_arrived', 'picked_up', { driver_id: 'driver_01' }],
    ['picked_up', 'out_for_delivery'],
    ['out_for_delivery', 'delivered']
  ];
  let allSeqValid = true;
  for (const [from, to, opts] of seqTransitions) {
    const res = orderService.validateTransition(from, to, opts || {});
    if (!res.valid) {
      allSeqValid = false;
      console.error(`  Sequence failed: ${from} -> ${to}: ${res.error}`);
    }
  }
  recordResult('T1.1', 'Legitimate sequential progression through lifecycle', allSeqValid);

  // Test 1.2: Idempotency & Equivalent Aliases
  const idempPlaced = orderService.validateTransition('placed', 'placed');
  const idempDelivered = orderService.validateTransition('delivered', 'delivered');
  const aliasPickup = orderService.validateTransition('picked_up', 'out_for_delivery');
  const aliasOut = orderService.validateTransition('out_for_delivery', 'picked_up');
  const passT1_2 = idempPlaced.valid && idempPlaced.isIdempotent &&
                   idempDelivered.valid && idempDelivered.isIdempotent &&
                   aliasPickup.valid && aliasPickup.isIdempotent &&
                   aliasOut.valid && aliasOut.isIdempotent;
  recordResult('T1.2', 'Idempotent self-transitions & pickup equivalent aliases', passT1_2);

  // Test 1.3: Non-admin state skipping without adminOverride (must be rejected)
  const skipPlacedToReady = orderService.validateTransition('placed', 'ready_for_pickup', { isAdmin: false });
  const skipPlacedToDelivered = orderService.validateTransition('placed', 'delivered', { isAdmin: false });
  const skipPreparingToDelivered = orderService.validateTransition('preparing', 'delivered', { isAdmin: false });
  const passT1_3 = !skipPlacedToReady.valid && skipPlacedToReady.statusCode === 400 &&
                   !skipPlacedToDelivered.valid && skipPlacedToDelivered.statusCode === 400 &&
                   !skipPreparingToDelivered.valid && skipPreparingToDelivered.statusCode === 400;
  recordResult('T1.3', 'Non-admin state skipping strictly rejected (400)', passT1_3, {
    skipPlacedToReadyError: skipPlacedToReady.error,
    skipPlacedToDeliveredError: skipPlacedToDelivered.error
  });

  // Test 1.4: Non-admin backward transitions without adminOverride (must be rejected)
  const backReadyToPreparing = orderService.validateTransition('ready_for_pickup', 'preparing', { isAdmin: false });
  const backOutToPlaced = orderService.validateTransition('out_for_delivery', 'placed', { isAdmin: false });
  const backDeliveredToPreparing = orderService.validateTransition('delivered', 'preparing', { isAdmin: false });
  const passT1_4 = !backReadyToPreparing.valid && backReadyToPreparing.statusCode === 400 &&
                   !backOutToPlaced.valid && backOutToPlaced.statusCode === 400 &&
                   !backDeliveredToPreparing.valid && backDeliveredToPreparing.statusCode === 400;
  recordResult('T1.4', 'Non-admin backward transitions strictly rejected (400)', passT1_4, {
    backReadyToPreparingError: backReadyToPreparing.error,
    backDeliveredToPreparingError: backDeliveredToPreparing.error
  });

  // Test 1.5: Non-admin terminal states (delivered & cancelled are final without override)
  const nonAdminDeliveredToCancelled = orderService.validateTransition('delivered', 'cancelled', { isAdmin: false });
  const nonAdminCancelledToPlaced = orderService.validateTransition('cancelled', 'placed', { isAdmin: false });
  const passT1_5 = !nonAdminDeliveredToCancelled.valid && nonAdminDeliveredToCancelled.statusCode === 400 &&
                   !nonAdminCancelledToPlaced.valid && nonAdminCancelledToPlaced.statusCode === 400;
  recordResult('T1.5', 'Non-admin transitions out of terminal states rejected (400)', passT1_5);

  // Test 1.6: Non-admin in-flight cancellation protection
  const cancelPreparing = orderService.validateTransition('preparing', 'cancelled', { isAdmin: false });
  const cancelReady = orderService.validateTransition('ready_for_pickup', 'cancelled', { isAdmin: false });
  const cancelOut = orderService.validateTransition('out_for_delivery', 'cancelled', { isAdmin: false });
  const passT1_6 = !cancelPreparing.valid && cancelPreparing.statusCode === 400 &&
                   !cancelReady.valid && cancelReady.statusCode === 400 &&
                   !cancelOut.valid && cancelOut.statusCode === 400;
  recordResult('T1.6', 'Non-admin in-flight cancellations rejected (400)', passT1_6, {
    cancelPreparingError: cancelPreparing.error
  });

  // Test 1.7: Admin with adminOverride forcing transitions to every required stage
  const requiredAdminStages = ['placed', 'preparing', 'ready_for_pickup', 'out_for_delivery', 'delivered', 'cancelled'];
  let allAdminStagesPass = true;
  const adminStageDetails = {};
  for (const st of requiredAdminStages) {
    // Force transition from arbitrary state (e.g. delivered or placed)
    const fromState = st === 'placed' ? 'delivered' : 'placed';
    const res = orderService.validateTransition(fromState, st, { adminOverride: true, isAdmin: true });
    adminStageDetails[`${fromState}->${st}`] = { valid: res.valid, adminOverride: res.adminOverride };
    if (!res.valid) allAdminStagesPass = false;
  }
  recordResult('T1.7', 'Admin with adminOverride forcing transitions to all 6 required stages', allAdminStagesPass, adminStageDetails);

  // Test 1.8: Admin with adminOverride backwards & terminal overrides
  const adminBack = orderService.validateTransition('ready_for_pickup', 'preparing', { adminOverride: true });
  const adminDeliveredCancel = orderService.validateTransition('delivered', 'cancelled', { adminOverride: true });
  const adminCancelledResurrect = orderService.validateTransition('cancelled', 'placed', { adminOverride: true });
  const passT1_8 = adminBack.valid && adminBack.adminOverride &&
                   adminDeliveredCancel.valid && adminDeliveredCancel.isCancellation &&
                   adminCancelledResurrect.valid && adminCancelledResurrect.adminOverride;
  recordResult('T1.8', 'Admin backward transitions & terminal overrides permitted', passT1_8);

  // Test 1.9: Nonsense / invalid status names with adminOverride
  const nonsenseStatuses = ['flying', 'hacked', 'DROP TABLE orders;', '', null, undefined, 9999];
  let allNonsenseRejected = true;
  const nonsenseDetails = {};
  for (const ns of nonsenseStatuses) {
    const res = orderService.validateTransition('placed', ns, { adminOverride: true, isAdmin: true });
    nonsenseDetails[String(ns)] = { valid: res.valid, statusCode: res.statusCode };
    if (res.valid !== false || res.statusCode !== 400) {
      allNonsenseRejected = false;
    }
  }
  recordResult('T1.9', 'Invalid/nonsense status names with adminOverride strictly rejected (400)', allNonsenseRejected, nonsenseDetails);


  // ==========================================================================
  // SECTION 2: HTTP INTEGRATION & SECURITY (REST API ENDPOINTS)
  // ==========================================================================
  console.log('\n--- SECTION 2: HTTP Integration & Endpoint Security Verification ---\n');

  // Test 2.1: Unauthenticated request to POST /orders/:id/status
  const unauthRes = await makeHttpRequest('POST', '/api/v1/orders/ord_test_unauth/status', { status: 'preparing' });
  const passT2_1 = unauthRes.statusCode === 401;
  recordResult('T2.1', 'Unauthenticated request to /orders/:id/status rejected (401)', passT2_1, {
    statusCode: unauthRes.statusCode,
    body: unauthRes.body
  });

  // Test 2.2: Unauthenticated request to POST /orders/:id/cancel
  const unauthCancelRes = await makeHttpRequest('POST', '/api/v1/orders/ord_test_unauth/cancel', { reason: 'test' });
  const passT2_2 = unauthCancelRes.statusCode === 401;
  recordResult('T2.2', 'Unauthenticated request to /orders/:id/cancel rejected (401)', passT2_2, {
    statusCode: unauthCancelRes.statusCode,
    body: unauthCancelRes.body
  });

  // Test 2.3: Non-admin legitimate rejection of state skipping without adminOverride
  const orderSkip = {
    id: 'ord_http_skip_01',
    order_number: 'ORD-HTTP-SKIP',
    customer_id: 'usr_guest_nalut',
    status: 'placed',
    total_amount_lyd: 45.0,
    created_at: new Date().toISOString()
  };
  db.orders.push(orderSkip);

  const nonAdminSkipRes = await makeHttpRequest(
    'POST',
    `/api/v1/orders/${orderSkip.id}/status`,
    { status: 'ready_for_pickup' },
    customerToken
  );
  const passT2_3 = nonAdminSkipRes.statusCode === 400 && !nonAdminSkipRes.body?.success;
  recordResult('T2.3', 'Non-admin HTTP state skip without adminOverride rejected (400)', passT2_3, {
    statusCode: nonAdminSkipRes.statusCode,
    error: nonAdminSkipRes.body?.error
  });

  // Test 2.4: Non-admin legitimate rejection of backward transition without adminOverride
  const orderBack = {
    id: 'ord_http_back_01',
    order_number: 'ORD-HTTP-BACK',
    customer_id: 'usr_guest_nalut',
    status: 'ready_for_pickup',
    total_amount_lyd: 45.0,
    created_at: new Date().toISOString()
  };
  db.orders.push(orderBack);

  const nonAdminBackRes = await makeHttpRequest(
    'POST',
    `/api/v1/orders/${orderBack.id}/status`,
    { status: 'preparing' },
    customerToken
  );
  const passT2_4 = nonAdminBackRes.statusCode === 400 && !nonAdminBackRes.body?.success;
  recordResult('T2.4', 'Non-admin HTTP backward transition without adminOverride rejected (400)', passT2_4, {
    statusCode: nonAdminBackRes.statusCode,
    error: nonAdminBackRes.body?.error
  });

  // Test 2.5: Authenticated admin with adminOverride forcing transitions to every stage
  const httpStages = ['placed', 'preparing', 'ready_for_pickup', 'out_for_delivery', 'delivered', 'cancelled'];
  let allHttpAdminPassed = true;
  const httpAdminDetails = {};

  for (const targetStage of httpStages) {
    const testOrd = {
      id: `ord_http_adm_${targetStage}`,
      order_number: `ORD-ADM-${targetStage.toUpperCase()}`,
      customer_id: 'usr_guest_nalut',
      status: targetStage === 'placed' ? 'preparing' : 'placed',
      total_amount_lyd: 35.0,
      created_at: new Date().toISOString()
    };
    db.orders.push(testOrd);

    const res = await makeHttpRequest(
      'POST',
      `/api/v1/orders/${testOrd.id}/status`,
      { status: targetStage, adminOverride: true },
      adminToken
    );

    const isSuccess = res.statusCode === 200 && res.body?.success === true && testOrd.status === targetStage;
    if (!isSuccess) allHttpAdminPassed = false;
    httpAdminDetails[targetStage] = {
      statusCode: res.statusCode,
      success: res.body?.success,
      resultingStatus: testOrd.status
    };
  }
  recordResult('T2.5', 'Admin HTTP forced transitions to all 6 stages succeed (200)', allHttpAdminPassed, httpAdminDetails);

  // Test 2.6: Authenticated admin with invalid/nonsense status names
  const httpNonsense = ['flying', 'hacked', 'DROP TABLE orders;'];
  let allHttpNonsenseRejected = true;
  const httpNonsenseDetails = {};

  for (const ns of httpNonsense) {
    const testOrd = {
      id: `ord_http_adm_ns_${ns.replace(/[^a-z0-9]/gi, '')}`,
      order_number: 'ORD-ADM-NS',
      customer_id: 'usr_guest_nalut',
      status: 'placed',
      total_amount_lyd: 35.0,
      created_at: new Date().toISOString()
    };
    db.orders.push(testOrd);

    const res = await makeHttpRequest(
      'POST',
      `/api/v1/orders/${testOrd.id}/status`,
      { status: ns, adminOverride: true },
      adminToken
    );

    const isRejected = res.statusCode === 400 && res.body?.success === false;
    if (!isRejected) allHttpNonsenseRejected = false;
    httpNonsenseDetails[ns] = {
      statusCode: res.statusCode,
      success: res.body?.success,
      error: res.body?.error
    };
  }
  recordResult('T2.6', 'Admin HTTP invalid/nonsense status rejected (400)', allHttpNonsenseRejected, httpNonsenseDetails);

  // Test 2.7: Administrative endpoint authorization (reassign, delete, purge)
  const reassignRes = await makeHttpRequest('POST', '/api/v1/orders/123/reassign', { driver_id: 'driver_nalut_01' }, customerToken);
  const deleteRes = await makeHttpRequest('DELETE', '/api/v1/admin/orders/123', null, customerToken);
  const purgeRes = await makeHttpRequest('POST', '/api/v1/admin/orders/purge', { pin: '7788' }, customerToken);
  const passT2_7 = reassignRes.statusCode === 403 && deleteRes.statusCode === 403 && purgeRes.statusCode === 403;
  recordResult('T2.7', 'Admin management routes (reassign, delete, purge) protected against non-admin (403)', passT2_7, {
    reassignStatus: reassignRes.statusCode,
    deleteStatus: deleteRes.statusCode,
    purgeStatus: purgeRes.statusCode
  });


  // ==========================================================================
  // SECTION 3: ADVERSARIAL CHALLENGE — PRIVILEGE ESCALATION VIA PARAMETER TAMPERING
  // ==========================================================================
  console.log('\n--- SECTION 3: Adversarial Challenge — Parameter Tampering & Privilege Escalation ---\n');

  // Vulnerability Hypothesis:
  // In backend/server.js:3821 and backend/server.js:4160:
  // `const isAdmin = Boolean(req.body.adminOverride || req.body.admin_override || req.user?.role === 'admin');`
  // If an unprivileged customer sends `{ adminOverride: true }`, backend evaluates isAdmin = true!
  // This allows non-admins to:
  // 1. Force state transitions (e.g. placed -> delivered)
  // 2. Bypass OTP delivery verification
  // 3. Cancel in-flight or already-delivered orders and trigger financial reversal!

  // Vulnerability Test 3.1: Non-admin forcing 'delivered' status with { adminOverride: true }
  const orderVuln1 = {
    id: 'ord_vuln_escalate_01',
    order_number: 'ORD-VULN-01',
    customer_id: 'usr_guest_nalut',
    status: 'placed',
    total_amount_lyd: 50.0,
    created_at: new Date().toISOString()
  };
  db.orders.push(orderVuln1);

  const vulnStatusRes = await makeHttpRequest(
    'POST',
    `/api/v1/orders/${orderVuln1.id}/status`,
    { status: 'delivered', adminOverride: true },
    customerToken // Signed as role: 'customer'!
  );

  const vuln1Escalated = vulnStatusRes.statusCode === 200 && orderVuln1.status === 'delivered';
  recordResult(
    'T3.1',
    'Adversarial Probe: Non-admin forging adminOverride to force status & bypass OTP',
    !vuln1Escalated, // PASS if secure (NOT escalated), FAIL if vulnerability exists
    {
      expected: '403 Forbidden or 400 Bad Request (Non-admin cannot use adminOverride)',
      actualStatusCode: vulnStatusRes.statusCode,
      orderStatusAfterRequest: orderVuln1.status,
      vulnerabilityConfirmed: vuln1Escalated
    }
  );

  // Vulnerability Test 3.2: Non-admin cancelling in-flight 'preparing' order with { adminOverride: true }
  const orderVuln2 = {
    id: 'ord_vuln_escalate_02',
    order_number: 'ORD-VULN-02',
    customer_id: 'usr_guest_nalut',
    status: 'preparing',
    total_amount_lyd: 50.0,
    created_at: new Date().toISOString()
  };
  db.orders.push(orderVuln2);

  const vulnCancelRes = await makeHttpRequest(
    'POST',
    `/api/v1/orders/${orderVuln2.id}/cancel`,
    { reason: 'Customer forged override', adminOverride: true },
    customerToken // Signed as role: 'customer'!
  );

  const vuln2Escalated = vulnCancelRes.statusCode === 200 && orderVuln2.status === 'cancelled';
  recordResult(
    'T3.2',
    'Adversarial Probe: Non-admin forging adminOverride in /cancel to cancel preparing order',
    !vuln2Escalated, // PASS if secure (NOT escalated), FAIL if vulnerability exists
    {
      expected: '403 Forbidden or 400 Bad Request (Cannot cancel preparing order without real admin role)',
      actualStatusCode: vulnCancelRes.statusCode,
      orderStatusAfterRequest: orderVuln2.status,
      vulnerabilityConfirmed: vuln2Escalated
    }
  );

  // Vulnerability Test 3.3: Non-admin cancelling 'delivered' order with { adminOverride: true }
  const orderVuln3 = {
    id: 'ord_vuln_escalate_03',
    order_number: 'ORD-VULN-03',
    customer_id: 'usr_guest_nalut',
    status: 'delivered',
    total_amount_lyd: 50.0,
    created_at: new Date().toISOString()
  };
  db.orders.push(orderVuln3);

  const vulnCancelDeliveredRes = await makeHttpRequest(
    'POST',
    `/api/v1/orders/${orderVuln3.id}/cancel`,
    { reason: 'Customer forged override on delivered order', adminOverride: true },
    customerToken
  );

  const vuln3Escalated = vulnCancelDeliveredRes.statusCode === 200 && orderVuln3.status === 'cancelled';
  recordResult(
    'T3.3',
    'Adversarial Probe: Non-admin forging adminOverride to cancel delivered order',
    !vuln3Escalated,
    {
      expected: '403 Forbidden or 400 Bad Request',
      actualStatusCode: vulnCancelDeliveredRes.statusCode,
      orderStatusAfterRequest: orderVuln3.status,
      vulnerabilityConfirmed: vuln3Escalated
    }
  );

  // ==========================================================================
  // SUITE SUMMARY
  // ==========================================================================
  console.log('\n================================================================');
  console.log('📊 EMPIRICAL ADVERSARIAL SUITE SUMMARY');
  console.log('================================================================');
  const passedCount = testResults.filter(t => t.passed).length;
  const failedCount = testResults.filter(t => !t.passed).length;
  console.log(`Total Tests Run: ${testResults.length}`);
  console.log(`Passed: ${passedCount}`);
  console.log(`Failed / Vulnerabilities Detected: ${failedCount}`);

  if (failedCount > 0) {
    console.log('\n⚠️  SECURITY DEFICIENCIES FOUND:');
    testResults.filter(t => !t.passed).forEach(t => {
      console.log(`  - [${t.testId}] ${t.name}: ${JSON.stringify(t.details)}`);
    });
  } else {
    console.log('\n🎉 ALL ADVERSARIAL TESTS PASSED WITH ZERO VULNERABILITIES!');
  }

  return { total: testResults.length, passed: passedCount, failed: failedCount, results: testResults };
}

if (require.main === module) {
  runAdversarialFsmSuite().then(summary => {
    process.exit(summary.failed > 0 ? 1 : 0);
  }).catch(err => {
    console.error('Test Suite Crashed:', err);
    process.exit(2);
  });
}

module.exports = { runAdversarialFsmSuite };
