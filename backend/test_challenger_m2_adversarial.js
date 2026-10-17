/**
 * ============================================================================
 * EMPIRICAL ADVERSARIAL STRESS & VERIFICATION SUITE — CHALLENGER M2_2
 * ============================================================================
 * Target: Order Custody, Delivery OTP, Public Tracking & Accounting Invariants
 * Orchestrator Milestone: Milestone 2
 *
 * Requirements Verified:
 * 1. Handover spoofing: '/orders/:id/handover' rejects '1234' and invalid codes.
 * 2. Delivery OTP spoofing: status 'delivered' rejects '1234' and omitted/invalid OTPs.
 * 3. Pre-flight state integrity: failed OTP attempts do NOT mutate order status,
 *    driver balance, or cash_in_hand in memory or database.
 * 4. Public tracking integrity: '/api/v1/public/track/:id' strips OTPs/credentials,
 *    and non-existent order IDs return strict 404 (no fallback).
 * 5. Accounting invariant check: 'node backend/test_accounting_engine.js' 7/7 pass
 *    with exactly 0.0000 LYD imbalance.
 * 6. E2E test suite check: 'node backend/test_e2e_order_lifecycle.js' 50/50 pass.
 * ============================================================================
 */

const http = require('http');
const assert = require('assert');
const { execSync } = require('child_process');

const TEST_PORT = process.env.TEST_PORT || process.env.PORT || 3000;
process.env.NODE_ENV = 'test';

const testResults = [];
let inProcessServer = null;

function recordTest(testId, title, passed, details = {}) {
  testResults.push({ testId, title, passed, details });
  const status = passed ? '✅ PASS' : '❌ FAIL';
  console.log(`[${status}] ${testId}: ${title}`);
  if (details && Object.keys(details).length > 0 && !passed) {
    console.log(`       Details: ${JSON.stringify(details, null, 2)}`);
  }
}

function apiRequest(method, endpoint, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const reqHeaders = {
      'Content-Type': 'application/json',
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

    req.on('error', (err) => {
      reject(err);
    });

    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

async function ensureServerRunning() {
  const isRunning = await new Promise(resolve => {
    const probe = http.get(`http://127.0.0.1:${TEST_PORT}/health`, res => resolve(res.statusCode === 200));
    probe.on('error', () => resolve(false));
    probe.setTimeout(500, () => { probe.destroy(); resolve(false); });
  });

  if (!isRunning) {
    console.log(`[Setup] Starting in-process server on port ${TEST_PORT}...`);
    process.env.PORT = String(TEST_PORT);
    const serverMod = require('./server.js');
    inProcessServer = serverMod.server;
    await new Promise(r => setTimeout(r, 800));
  }
}

async function closeInProcessServer() {
  if (inProcessServer) {
    console.log('[Teardown] Gracefully closing in-process HTTP server for child processes...');
    await new Promise(resolve => {
      inProcessServer.close(() => resolve());
    });
    inProcessServer = null;
    await new Promise(r => setTimeout(r, 500));
  }
}

async function runAdversarialSuite() {
  console.log('================================================================');
  console.log('⚔️  STARTING CHALLENGER M2-2 EMPIRICAL ADVERSARIAL TEST HARNESS');
  console.log('================================================================\n');

  await ensureServerRunning();

  // Obtain test tokens
  const custRes = await apiRequest('POST', '/api/v1/auth/login', {
    phone: '0910000000',
    password: 'Customer@Nalut2026!Secure'
  });
  const customerToken = custRes.body?.data?.token;
  assert(customerToken, 'Customer login failed to obtain JWT');
  const custAuth = { Authorization: `Bearer ${customerToken}` };

  const admRes = await apiRequest('POST', '/api/v1/auth/login', {
    phone: '0910009832',
    password: 'Admin@Nalut2026!Secure'
  });
  const adminToken = admRes.body?.data?.token;
  assert(adminToken, 'Admin login failed to obtain JWT');
  const admAuth = { Authorization: `Bearer ${adminToken}` };

  // ============================================================================
  // SUITE 1: HANDOVER SPOOFING & CUSTODY TRANSFER ADVERSARIAL ATTACKS
  // ============================================================================
  console.log('\n--- SUITE 1: Kitchen Handover Spoofing Attacks ---');

  // Create order for Handover testing
  const storeRes = await apiRequest('GET', '/api/v1/stores?city=nalut');
  const testStore = storeRes.body?.data?.[0] || { id: 'store_nalut_ranchello' };

  const order1Res = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: testStore.id,
    items: [{ product_id: 'prod_nalut_pizza_01', quantity: 1, unit_price_lyd: 25.0 }],
    delivery_address: 'نالوت - شارع المجاهدين',
    payment_method: 'cash_on_delivery'
  }, custAuth);
  const order1 = order1Res.body?.data || order1Res.body;
  assert(order1 && order1.id, 'Order 1 checkout failed');

  // Test 1.1: Handover attempt when order is still in 'placed' status (not ready_for_pickup)
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order1.id}/handover`, {
      handover_code: '1234',
      driver_id: 'driver_nalut_01'
    }, custAuth);
    const passed = res.status === 400 && res.body?.success === false;
    recordTest('TC-1.1-HANDOVER-PREMATURE-PLACED', 'Reject handover when order is in placed status', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-1.1-HANDOVER-PREMATURE-PLACED', 'Reject handover when order is in placed status', false, { error: err.message });
  }

  // Advance order through strict FSM: placed -> accepted -> preparing
  await apiRequest('POST', `/api/v1/orders/${order1.id}/status`, { status: 'accepted' }, custAuth);
  await apiRequest('POST', `/api/v1/orders/${order1.id}/status`, { status: 'preparing' }, custAuth);

  // Test 1.2: Handover attempt when order is in 'preparing' status
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order1.id}/handover`, {
      handover_code: '1234',
      driver_id: 'driver_nalut_01'
    }, custAuth);
    const passed = res.status === 400 && res.body?.success === false;
    recordTest('TC-1.2-HANDOVER-PREMATURE-PREPARING', 'Reject handover when order is in preparing status', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-1.2-HANDOVER-PREMATURE-PREPARING', 'Reject handover when order is in preparing status', false, { error: err.message });
  }

  // Advance order to 'ready_for_pickup'
  await apiRequest('POST', `/api/v1/orders/${order1.id}/status`, { status: 'ready_for_pickup' }, custAuth);

  // Test 1.3: Handover attempt with universal backdoor '1234'
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order1.id}/handover`, {
      handover_code: '1234',
      driver_id: 'driver_nalut_01'
    }, custAuth);
    const passed = res.status === 400 && res.body?.success === false;
    recordTest('TC-1.3-HANDOVER-BACKDOOR-1234', 'Reject handover with universal backdoor code 1234', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-1.3-HANDOVER-BACKDOOR-1234', 'Reject handover with universal backdoor code 1234', false, { error: err.message });
  }

  // Test 1.4: Handover attempt with invalid wrong code '9999'
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order1.id}/handover`, {
      handover_code: '9999',
      driver_id: 'driver_nalut_01'
    }, custAuth);
    const passed = res.status === 400 && res.body?.success === false;
    recordTest('TC-1.4-HANDOVER-WRONG-CODE', 'Reject handover with wrong code 9999', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-1.4-HANDOVER-WRONG-CODE', 'Reject handover with wrong code 9999', false, { error: err.message });
  }

  // Test 1.5: Handover attempt with omitted / empty code
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order1.id}/handover`, {
      driver_id: 'driver_nalut_01'
    }, custAuth);
    const passed = res.status === 400 && res.body?.success === false;
    recordTest('TC-1.5-HANDOVER-OMITTED-CODE', 'Reject handover with omitted code', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-1.5-HANDOVER-OMITTED-CODE', 'Reject handover with omitted code', false, { error: err.message });
  }

  // Test 1.6: Handover attempt with SQL injection / malicious string
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order1.id}/handover`, {
      handover_code: "' OR '1'='1",
      driver_id: 'driver_nalut_01'
    }, custAuth);
    const passed = res.status === 400 && res.body?.success === false;
    recordTest('TC-1.6-HANDOVER-INJECTION-STRING', 'Reject handover with SQL injection code string', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-1.6-HANDOVER-INJECTION-STRING', 'Reject handover with SQL injection code string', false, { error: err.message });
  }

  // Test 1.7: Handover attempt on non-existent order
  try {
    const res = await apiRequest('POST', '/api/v1/orders/ord_non_existent_9999/handover', {
      handover_code: '1234',
      driver_id: 'driver_nalut_01'
    }, custAuth);
    const passed = res.status === 404 && res.body?.success === false;
    recordTest('TC-1.7-HANDOVER-NONEXISTENT-ORDER', 'Return 404 for handover on non-existent order', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-1.7-HANDOVER-NONEXISTENT-ORDER', 'Return 404 for handover on non-existent order', false, { error: err.message });
  }

  // Test 1.8: Handover with legitimate expected code
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order1.id}/handover`, {
      handover_code: order1.handover_code,
      driver_id: 'driver_nalut_01'
    }, custAuth);
    const passed = res.status === 200 && (res.body?.data?.status === 'out_for_delivery' || res.body?.order?.status === 'out_for_delivery');
    recordTest('TC-1.8-HANDOVER-GENUINE-CODE', 'Accept handover with authentic handover code', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-1.8-HANDOVER-GENUINE-CODE', 'Accept handover with authentic handover code', false, { error: err.message });
  }

  // ============================================================================
  // SUITE 2: DELIVERY OTP SPOOFING & STATUS ATTACKS
  // ============================================================================
  console.log('\n--- SUITE 2: Delivery OTP Spoofing Attacks ---');

  // Create order for Delivery OTP testing
  const order2Res = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: testStore.id,
    items: [{ product_id: 'prod_nalut_pizza_01', quantity: 1, unit_price_lyd: 30.0 }],
    delivery_address: 'نالوت - الحي الشرقي',
    payment_method: 'cash_on_delivery'
  }, custAuth);
  const order2 = order2Res.body?.data || order2Res.body;
  assert(order2 && order2.id, 'Order 2 checkout failed');

  // Test 2.1: Premature delivery attempt when order is still in 'placed'
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order2.id}/status`, {
      status: 'delivered',
      driver_id: 'driver_nalut_01',
      otp_code: order2.otp_code
    }, custAuth);
    const passed = res.status === 400 && res.body?.success === false;
    recordTest('TC-2.1-DELIVERY-PREMATURE-PLACED', 'Reject delivery status when order is still in placed state', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-2.1-DELIVERY-PREMATURE-PLACED', 'Reject delivery status when order is still in placed state', false, { error: err.message });
  }

  // Advance order through strict FSM: placed -> accepted -> preparing -> ready_for_pickup -> picked_up
  await apiRequest('POST', `/api/v1/orders/${order2.id}/status`, { status: 'accepted' }, custAuth);
  await apiRequest('POST', `/api/v1/orders/${order2.id}/status`, { status: 'preparing' }, custAuth);
  await apiRequest('POST', `/api/v1/orders/${order2.id}/status`, { status: 'ready_for_pickup' }, custAuth);
  await apiRequest('POST', `/api/v1/orders/${order2.id}/status`, {
    status: 'picked_up',
    driver_id: 'driver_nalut_01'
  }, custAuth);

  // Test 2.2: Delivery attempt with backdoor OTP '1234'
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order2.id}/status`, {
      status: 'delivered',
      driver_id: 'driver_nalut_01',
      otp_code: '1234'
    }, custAuth);
    const passed = res.status === 400 && res.body?.success === false;
    recordTest('TC-2.2-DELIVERY-BACKDOOR-1234', 'Reject delivery with universal backdoor OTP 1234', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-2.2-DELIVERY-BACKDOOR-1234', 'Reject delivery with universal backdoor OTP 1234', false, { error: err.message });
  }

  // Test 2.3: Delivery attempt with omitted OTP
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order2.id}/status`, {
      status: 'delivered',
      driver_id: 'driver_nalut_01'
    }, custAuth);
    const passed = res.status === 400 && res.body?.success === false;
    recordTest('TC-2.3-DELIVERY-OMITTED-OTP', 'Reject delivery with omitted OTP', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-2.3-DELIVERY-OMITTED-OTP', 'Reject delivery with omitted OTP', false, { error: err.message });
  }

  // Test 2.4: Delivery attempt with empty string or whitespace OTP
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order2.id}/status`, {
      status: 'delivered',
      driver_id: 'driver_nalut_01',
      otp_code: '    '
    }, custAuth);
    const passed = res.status === 400 && res.body?.success === false;
    recordTest('TC-2.4-DELIVERY-WHITESPACE-OTP', 'Reject delivery with whitespace OTP', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-2.4-DELIVERY-WHITESPACE-OTP', 'Reject delivery with whitespace OTP', false, { error: err.message });
  }

  // Test 2.5: Delivery attempt with wrong 4-digit code '0000'
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order2.id}/status`, {
      status: 'delivered',
      driver_id: 'driver_nalut_01',
      otp_code: '0000'
    }, custAuth);
    const passed = res.status === 400 && res.body?.success === false;
    recordTest('TC-2.5-DELIVERY-WRONG-OTP', 'Reject delivery with wrong 4-digit OTP 0000', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-2.5-DELIVERY-WRONG-OTP', 'Reject delivery with wrong 4-digit OTP 0000', false, { error: err.message });
  }

  // Test 2.6: Delivery attempt with SQL injection / non-numeric string
  try {
    const res = await apiRequest('POST', `/api/v1/orders/${order2.id}/status`, {
      status: 'delivered',
      driver_id: 'driver_nalut_01',
      otp_code: "' OR '1'='1"
    }, custAuth);
    const passed = res.status === 400 && res.body?.success === false;
    recordTest('TC-2.6-DELIVERY-INJECTION-OTP', 'Reject delivery with injection string OTP', passed, { status: res.status, body: res.body });
  } catch (err) {
    recordTest('TC-2.6-DELIVERY-INJECTION-OTP', 'Reject delivery with injection string OTP', false, { error: err.message });
  }

  // ============================================================================
  // SUITE 3: PRE-FLIGHT STATE INTEGRITY & BALANCE IMMUTABILITY
  // ============================================================================
  console.log('\n--- SUITE 3: Pre-Flight State Integrity & Balance Immutability ---');

  // Fetch driver initial state
  const driversBefore = await apiRequest('GET', '/api/v1/drivers');
  const dListBefore = driversBefore.body?.data || driversBefore.body || [];
  const targetDriver = dListBefore.find(d => d.id === 'driver_nalut_01') || dListBefore[0];
  assert(targetDriver, 'Target driver not found');

  const initialDriverBalance = Number(targetDriver.balance || targetDriver.wallet_balance || 0);
  const initialCashInHand = Number(targetDriver.cash_in_hand || 0);

  // Check order2 status right before burst attack
  const orderCheckBefore = await apiRequest('GET', `/api/v1/orders?id=${order2.id}`, null, custAuth);
  const orderStateBefore = (orderCheckBefore.body?.data || orderCheckBefore.body || [])[0];
  const initialOrderStatus = orderStateBefore?.status;

  // Execute burst of 10 consecutive invalid OTP delivery attempts
  const attackPayloads = [
    { otp_code: '1234' },
    { otp_code: '0000' },
    { otp_code: '' },
    { otp_code: null },
    { otp_code: '9999' },
    { otp_code: 'abcd' },
    { otp_code: "' OR 1=1 --" },
    { otp_code: '123456' },
    { otp_code: '-1' },
    { otp_code: '7788' }
  ];

  let allRejectionsSucceeded = true;
  for (const atk of attackPayloads) {
    const res = await apiRequest('POST', `/api/v1/orders/${order2.id}/status`, {
      status: 'delivered',
      driver_id: targetDriver.id,
      ...atk
    }, custAuth);
    if (res.status !== 400) {
      allRejectionsSucceeded = false;
      console.error(`Attack payload failed to reject with 400:`, atk, `Got: ${res.status}`);
    }
  }

  // Test 3.1: All 10 invalid delivery OTP attempts were rejected
  recordTest('TC-3.1-BURST-REJECTIONS', 'Burst of 10 invalid delivery OTP attempts rejected with 400', allRejectionsSucceeded);

  // Test 3.2: Verify order status was NOT mutated
  const orderCheckAfter = await apiRequest('GET', `/api/v1/orders?id=${order2.id}`, null, custAuth);
  const orderStateAfter = (orderCheckAfter.body?.data || orderCheckAfter.body || [])[0];
  const orderStatusPreserved = orderStateAfter && orderStateAfter.status === initialOrderStatus && orderStateAfter.status !== 'delivered';
  recordTest('TC-3.2-ORDER-STATUS-IMMUTABLE', 'Order status remained untouched (not delivered) after failed OTP burst', orderStatusPreserved, {
    before: initialOrderStatus,
    after: orderStateAfter?.status
  });

  // Test 3.3: Verify driver balance was NOT mutated
  const driversAfter = await apiRequest('GET', '/api/v1/drivers');
  const dListAfter = driversAfter.body?.data || driversAfter.body || [];
  const targetDriverAfter = dListAfter.find(d => d.id === targetDriver.id);
  const currentDriverBalance = Number(targetDriverAfter.balance || targetDriverAfter.wallet_balance || 0);
  const currentCashInHand = Number(targetDriverAfter.cash_in_hand || 0);

  const balancePreserved = Math.abs(currentDriverBalance - initialDriverBalance) < 0.0001;
  recordTest('TC-3.3-DRIVER-BALANCE-IMMUTABLE', 'Driver wallet balance remained strictly unchanged after failed OTP attempts', balancePreserved, {
    before: initialDriverBalance,
    after: currentDriverBalance
  });

  // Test 3.4: Verify driver cash_in_hand was NOT mutated
  const cashInHandPreserved = Math.abs(currentCashInHand - initialCashInHand) < 0.0001;
  recordTest('TC-3.4-DRIVER-CASH-IMMUTABLE', 'Driver cash_in_hand liability remained strictly unchanged after failed OTP attempts', cashInHandPreserved, {
    before: initialCashInHand,
    after: currentCashInHand
  });

  // Test 3.5: Legitimate delivery with genuine OTP succeeds and correctly updates state & balance
  const legitDelivery = await apiRequest('POST', `/api/v1/orders/${order2.id}/status`, {
    status: 'delivered',
    driver_id: targetDriver.id,
    otp_code: order2.otp_code
  }, custAuth);
  const legitPassed = legitDelivery.status === 200 && (legitDelivery.body?.data?.status === 'delivered' || legitDelivery.body?.order?.status === 'delivered');
  recordTest('TC-3.5-GENUINE-OTP-SETTLEMENT', 'Legitimate delivery with genuine OTP succeeds and triggers settlement', legitPassed, {
    status: legitDelivery.status
  });

  // ============================================================================
  // SUITE 4: PUBLIC TRACKING INTEGRITY & CREDENTIAL LEAKAGE PROBING
  // ============================================================================
  console.log('\n--- SUITE 4: Public Tracking Integrity & Leakage Tests ---');

  // Test 4.1: Public track returns strict 404 on nonexistent ID (no fallback to db.orders[0])
  try {
    const res = await apiRequest('GET', '/api/v1/public/track/ord_strictly_non_existent_random_873618');
    const passed = res.status === 404 && res.body?.success === false;
    recordTest('TC-4.1-PUBLIC-TRACK-404-NONEXISTENT', 'Public tracking returns strict 404 on nonexistent order ID without fallback', passed, {
      status: res.status,
      body: res.body
    });
  } catch (err) {
    recordTest('TC-4.1-PUBLIC-TRACK-404-NONEXISTENT', 'Public tracking returns strict 404 on nonexistent order ID without fallback', false, { error: err.message });
  }

  // Test 4.2: Public track with tricky / null IDs
  const trickyIds = ['null', 'undefined', 'not_found_order', '0'];
  let trickyIdsPassed = true;
  for (const tid of trickyIds) {
    const res = await apiRequest('GET', `/api/v1/public/track/${tid}`);
    if (res.status !== 404) {
      trickyIdsPassed = false;
      console.error(`Tricky ID ${tid} returned status ${res.status} instead of 404`);
    }
  }
  recordTest('TC-4.2-PUBLIC-TRACK-TRICKY-IDS', 'Public tracking returns 404 for pathological IDs (null, undefined, not_found)', trickyIdsPassed);

  // Test 4.3: Public track strips delivery_otp and otp_code on active and delivered orders
  try {
    const trackActive = await apiRequest('GET', `/api/v1/public/track/${order1.id}`);
    const trackDelivered = await apiRequest('GET', `/api/v1/public/track/${order2.id}`);

    const activeData = trackActive.body?.data || trackActive.body || {};
    const deliveredData = trackDelivered.body?.data || trackDelivered.body || {};

    const activeLeaksOtp = activeData.delivery_otp !== undefined || activeData.otp_code !== undefined;
    const deliveredLeaksOtp = deliveredData.delivery_otp !== undefined || deliveredData.otp_code !== undefined;

    const otpsStripped = !activeLeaksOtp && !deliveredLeaksOtp;
    recordTest('TC-4.3-PUBLIC-TRACK-STRIPS-OTP', 'Public tracking strictly strips delivery_otp and otp_code from responses', otpsStripped, {
      activeDataKeys: Object.keys(activeData),
      deliveredDataKeys: Object.keys(deliveredData)
    });
  } catch (err) {
    recordTest('TC-4.3-PUBLIC-TRACK-STRIPS-OTP', 'Public tracking strictly strips delivery_otp and otp_code from responses', false, { error: err.message });
  }

  // Test 4.4: Public track strips handover_code
  try {
    const trackActive = await apiRequest('GET', `/api/v1/public/track/${order1.id}`);
    const activeData = trackActive.body?.data || trackActive.body || {};
    const handoverStripped = activeData.handover_code === undefined;
    recordTest('TC-4.4-PUBLIC-TRACK-STRIPS-HANDOVER', 'Public tracking strictly strips handover_code from responses', handoverStripped);
  } catch (err) {
    recordTest('TC-4.4-PUBLIC-TRACK-STRIPS-HANDOVER', 'Public tracking strictly strips handover_code from responses', false, { error: err.message });
  }

  // Test 4.5: Driver and Store sub-objects in public track strip secrets
  try {
    const trackActive = await apiRequest('GET', `/api/v1/public/track/${order1.id}`);
    const activeData = trackActive.body?.data || trackActive.body || {};
    const driverObj = activeData.driver || {};
    const storeObj = activeData.store || {};

    const driverSecure = driverObj.pin === undefined && driverObj.password === undefined && driverObj.password_hash === undefined && driverObj.balance === undefined;
    const storeSecure = storeObj.pin === undefined && storeObj.password === undefined && storeObj.password_hash === undefined && storeObj.commission === undefined;

    recordTest('TC-4.5-PUBLIC-TRACK-STRIPS-ENTITY-SECRETS', 'Public tracking strips driver & store internal secrets (PIN, password, balance)', driverSecure && storeSecure, {
      driverKeys: Object.keys(driverObj),
      storeKeys: Object.keys(storeObj)
    });
  } catch (err) {
    recordTest('TC-4.5-PUBLIC-TRACK-STRIPS-ENTITY-SECRETS', 'Public tracking strips driver & store internal secrets', false, { error: err.message });
  }

  // Close in-process server so subsequent test processes can run cleanly on TEST_PORT
  await closeInProcessServer();

  // ============================================================================
  // SUITE 5: ACCOUNTING INVARIANT EMPIRICAL VERIFICATION
  // ============================================================================
  console.log('\n--- SUITE 5: Double-Entry Accounting Invariant Checks ---');

  try {
    const accountingOutput = execSync('node backend/test_accounting_engine.js', { encoding: 'utf-8' });
    const hasZeroDiscrepancy = accountingOutput.includes('0.0000 LYD discrepancy') || accountingOutput.includes('0.0000 LYD');
    const hasAllPassed = accountingOutput.includes('ALL 7 ACCOUNTING & GENERAL LEDGER TESTS PASSED SUCCESSFULLY');
    const accountingPassed = hasZeroDiscrepancy && hasAllPassed;

    recordTest('TC-5.1-ACCOUNTING-TRIAL-BALANCE-ZERO-IMBALANCE', 'General Ledger maintains exactly 0.0000 LYD imbalance across all accounts', accountingPassed, {
      hasZeroDiscrepancy,
      hasAllPassed
    });
  } catch (err) {
    recordTest('TC-5.1-ACCOUNTING-TRIAL-BALANCE-ZERO-IMBALANCE', 'General Ledger maintains exactly 0.0000 LYD imbalance across all accounts', false, { error: err.message });
  }

  // ============================================================================
  // SUITE 6: E2E ORDER LIFECYCLE 50/50 TEST SUITE VERIFICATION
  // ============================================================================
  console.log('\n--- SUITE 6: E2E Order Lifecycle Test Suite (50 Tests) ---');

  try {
    const e2eOutput = execSync('node backend/test_e2e_order_lifecycle.js', { encoding: 'utf-8' });
    const has50Passed = e2eOutput.includes('50') && (e2eOutput.includes('100% OF TESTS PASSED') || e2eOutput.includes('ALL 50 TESTS VERIFIED SUCCESSFULLY'));

    recordTest('TC-6.1-E2E-50-TESTS-PASS', 'Full E2E order lifecycle test suite passes 50/50 tests with 0 failures', has50Passed);
  } catch (err) {
    recordTest('TC-6.1-E2E-50-TESTS-PASS', 'Full E2E order lifecycle test suite passes 50/50 tests with 0 failures', false, { error: err.message });
  }

  // ============================================================================
  // SUMMARY REPORT & VERDICT
  // ============================================================================
  console.log('\n================================================================');
  console.log('📊 CHALLENGER M2-2 VERIFICATION SUMMARY');
  console.log('================================================================');

  const total = testResults.length;
  const passed = testResults.filter(t => t.passed).length;
  const failed = total - passed;
  const passRate = ((passed / total) * 100).toFixed(1);

  console.log(`Total Checks:      ${total}`);
  console.log(`Passed:            ${passed}`);
  console.log(`Failed:            ${failed}`);
  console.log(`Pass Rate:         ${passRate}%`);
  console.log('================================================================\n');

  if (failed > 0) {
    console.error(`❌ VERDICT: REQUEST_CHANGES (${failed} tests failed)`);
    process.exit(1);
  } else {
    console.log('🎉 VERDICT: APPROVE (100% of empirical challenge tests passed!)');
    process.exit(0);
  }
}

runAdversarialSuite().catch(err => {
  console.error('Fatal error in adversarial test harness:', err);
  process.exit(1);
});
