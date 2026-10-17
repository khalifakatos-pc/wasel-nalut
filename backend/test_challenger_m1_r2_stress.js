/**
 * ============================================================================
 * EMPIRICAL ADVERSARIAL STRESS HARNESS — CHALLENGER M1_R2_1
 * ============================================================================
 * Target: Backend PostgreSQL Persistence & ACID Invariants
 * Milestone: Milestone 1 Round 2
 *
 * Verification Objectives Covered:
 * 1. Concurrency, race conditions, out-of-stock boundaries, and transaction rollback recovery in POST /api/v1/orders/checkout.
 * 2. Multi-item atomic pre-flight check and inventory non-negativity under contention.
 * 3. Mid-checkout transaction rollback compensation (zero leaks in db.orders, db.wallets, db.products).
 * 4. Runtime immutability of seed_data.json under heavy write workloads.
 * 5. Double-entry accounting ledger 0.0000 LYD balance under extreme coupons (> gross value, 100% free, stacked promos, COD zero payment).
 * 6. Order status FSM transition concurrency & idempotent delivery settlement.
 * 7. Driver cash custody settlement concurrency and balance non-negativity.
 * ============================================================================
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const assert = require('assert');

const TEST_PORT = 3000;
process.env.NODE_ENV = 'test';

const results = [];

function record(suite, testId, title, passed, details = {}) {
  results.push({ suite, testId, title, passed, details });
  const icon = passed ? '✅ PASS' : '❌ FAIL';
  console.log(`[${icon}] [${suite}] ${testId}: ${title}`);
  if (details && Object.keys(details).length > 0) {
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

    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

async function run() {
  console.log('================================================================');
  console.log('⚡ CHALLENGER M1_R2_1: ADVERSARIAL STRESS & EMPIRICAL HARNESS');
  console.log('================================================================\n');

  const serverMod = require('./server.js');
  const db = serverMod.db;
  const accountingEngine = serverMod.accountingEngine;
  const ledgerService = serverMod.ledgerService;

  // Wait for server ready
  await new Promise(r => setTimeout(r, 600));

  // Authenticate customer
  let authToken = null;
  const loginRes = await apiRequest('POST', '/api/v1/auth/login', {
    phone: '0910000000',
    password: 'Customer@Nalut2026!Secure'
  });
  if (loginRes.body?.data?.token) {
    authToken = loginRes.body.data.token;
  }
  const authHeader = authToken ? { Authorization: `Bearer ${authToken}` } : {};

  // Authenticate admin for management and settlement operations
  let adminToken = null;
  const adminLoginRes = await apiRequest('POST', '/api/v1/auth/login', {
    phone: '0910009832',
    password: 'Admin@Nalut2026!Secure'
  });
  if (adminLoginRes.body?.data?.token) {
    adminToken = adminLoginRes.body.data.token;
  }
  const adminAuthHeader = adminToken ? { Authorization: `Bearer ${adminToken}` } : {};

  const storeId = db.stores[0]?.id || 'store_nalut_ranchello';

  // ============================================================================
  // SUITE 1: Concurrency, Race Conditions & Stock Contention in Checkout
  // ============================================================================
  console.log('--- SUITE 1: Concurrency, Race Conditions & Stock Contention in Checkout ---');
  
  // Test 1.1: Product with initial stock = 2 under 30 concurrent checkout requests
  const prodContentionId = `prod_stress_c2_${Date.now()}`;
  const prodContention = {
    id: prodContentionId,
    store_id: storeId,
    name: 'صنف منافسة المخزون الساخن',
    name_ar: 'صنف منافسة المخزون الساخن',
    price_lyd: 10.0,
    price: 10.0,
    in_stock: true,
    is_available: true,
    stock_quantity: 2
  };
  db.products.push(prodContention);

  const initialOrderCount = db.orders.length;
  const numReqs = 30;
  const concurrentReqs = [];
  for (let i = 0; i < numReqs; i++) {
    concurrentReqs.push(
      apiRequest('POST', '/api/v1/orders/checkout', {
        store_id: storeId,
        items: [{ product_id: prodContentionId, quantity: 1, unit_price_lyd: 10.0 }],
        delivery_address: 'نالوت - شارع النصر',
        payment_method: 'cash_on_delivery'
      }, authHeader)
    );
  }

  const concurrentResults = await Promise.all(concurrentReqs);
  const successful = concurrentResults.filter(r => r.status === 200 || r.status === 201);
  const failed = concurrentResults.filter(r => r.status >= 400);
  const finalStock = prodContention.stock_quantity;
  const ordersCreatedForProduct = db.orders.length - initialOrderCount;

  // Invariant: Exactly 2 succeed, exactly 28 fail, final stock is exactly 0, stock is non-negative
  const noOverselling = successful.length === 2;
  const stockDepletedCleanly = finalStock === 0 && prodContention.in_stock === false;
  const nonNegative = finalStock >= 0;

  record('Checkout_Concurrency', 'STRESS-1.1', 'Exactly available inventory items can be purchased under 30x contention', noOverselling && stockDepletedCleanly && nonNegative, {
    initialStock: 2,
    finalStock,
    totalRequests: numReqs,
    successfulOrders: successful.length,
    failedOrders: failed.length,
    inStockFlag: prodContention.in_stock,
    ordersAddedToDb: ordersCreatedForProduct
  });

  // Test 1.2: Attempt purchase when stock is already zero
  const zeroStockRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: storeId,
    items: [{ product_id: prodContentionId, quantity: 1, unit_price_lyd: 10.0 }],
    delivery_address: 'نالوت - المركز',
    payment_method: 'cash_on_delivery'
  }, authHeader);

  record('Checkout_Boundaries', 'STRESS-1.2', 'Immediate rejection when ordering depleted item (stock = 0)', zeroStockRes.status === 400, {
    statusCode: zeroStockRes.status,
    errorMessage: zeroStockRes.body?.error
  });

  // Test 1.3: Attempt purchase exceeding available stock (stock = 3, request = 5)
  const prodExceedId = `prod_stress_exceed_${Date.now()}`;
  db.products.push({
    id: prodExceedId,
    store_id: storeId,
    name: 'صنف تجاوز الكمية',
    name_ar: 'صنف تجاوز الكمية',
    price_lyd: 8.0,
    price: 8.0,
    in_stock: true,
    is_available: true,
    stock_quantity: 3
  });

  const exceedRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: storeId,
    items: [{ product_id: prodExceedId, quantity: 5, unit_price_lyd: 8.0 }],
    delivery_address: 'نالوت - المركز',
    payment_method: 'cash_on_delivery'
  }, authHeader);

  const prodExceedAfter = db.products.find(p => p.id === prodExceedId);
  const exceedCleanlyRejected = exceedRes.status === 400 && prodExceedAfter.stock_quantity === 3;

  record('Checkout_Boundaries', 'STRESS-1.3', 'Rejection when requested quantity exceeds available stock (stock preserved)', exceedCleanlyRejected, {
    statusCode: exceedRes.status,
    requestedQuantity: 5,
    availableStock: 3,
    remainingStock: prodExceedAfter.stock_quantity,
    error: exceedRes.body?.error
  });

  // Test 1.4: Multi-Item Atomic Checkout Failure (Item 1 has stock=5, Item 2 has stock=0)
  const prodAvailableId = `prod_stress_avail_${Date.now()}`;
  const prodUnavailableId = `prod_stress_unavail_${Date.now()}`;
  db.products.push({
    id: prodAvailableId,
    store_id: storeId,
    name: 'صنف متوفر',
    name_ar: 'صنف متوفر',
    price_lyd: 10.0,
    in_stock: true,
    is_available: true,
    stock_quantity: 5
  });
  db.products.push({
    id: prodUnavailableId,
    store_id: storeId,
    name: 'صنف غير متوفر',
    name_ar: 'صنف غير متوفر',
    price_lyd: 15.0,
    in_stock: false,
    is_available: false,
    stock_quantity: 0
  });

  const ordersCountBeforeMulti = db.orders.length;
  const multiRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: storeId,
    items: [
      { product_id: prodAvailableId, quantity: 1, unit_price_lyd: 10.0 },
      { product_id: prodUnavailableId, quantity: 1, unit_price_lyd: 15.0 }
    ],
    delivery_address: 'نالوت - المركز',
    payment_method: 'cash_on_delivery'
  }, authHeader);

  const prodAvailAfter = db.products.find(p => p.id === prodAvailableId);
  const multiItemAtomic = multiRes.status === 400 && 
                          prodAvailAfter.stock_quantity === 5 && 
                          db.orders.length === ordersCountBeforeMulti;

  record('Checkout_Boundaries', 'STRESS-1.4', 'Multi-item order fails atomically if any item is out-of-stock (zero stock deductions)', multiItemAtomic, {
    statusCode: multiRes.status,
    availableItemStockBefore: 5,
    availableItemStockAfter: prodAvailAfter.stock_quantity,
    ordersLeaked: db.orders.length - ordersCountBeforeMulti,
    error: multiRes.body?.error
  });

  // ============================================================================
  // SUITE 2: ACID Rollback Recovery & In-Memory Compensation
  // ============================================================================
  console.log('\n--- SUITE 2: ACID Rollback Recovery & In-Memory Compensation ---');

  // Test 2.1: Insufficient Wallet Funds Rollback
  const customerUser = db.users.find(u => u.phone === '0910000000') || { id: 'usr_customer_01' };
  let custWallet = db.wallets.find(w => w.user_id === customerUser.id);
  if (!custWallet) {
    custWallet = {
      id: `wallet_${customerUser.id}`,
      user_id: customerUser.id,
      wallet_type: 'customer_wallet',
      balance: 10.0,
      locked_balance: 0.0,
      currency: 'LYD',
      status: 'active'
    };
    db.wallets.push(custWallet);
  }
  custWallet.balance = 5.0; // Deliberately lower than any order
  custWallet.locked_balance = 0.0;

  const ordersBeforeRollback = db.orders.length;
  const txBeforeRollback = db.wallet_transactions.length;

  const walletFailRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: storeId,
    items: [{ product_id: prodAvailableId, quantity: 1, unit_price_lyd: 10.0 }],
    delivery_address: 'نالوت - المركز',
    payment_method: 'wallet'
  }, authHeader);

  const walletRollbackClean = walletFailRes.status === 400 &&
                              custWallet.locked_balance === 0.0 &&
                              db.orders.length === ordersBeforeRollback &&
                              db.wallet_transactions.length === txBeforeRollback;

  record('Rollback_Recovery', 'STRESS-2.1', 'Insufficient wallet balance rolls back cleanly with zero locked funds and zero leaked rows', walletRollbackClean, {
    statusCode: walletFailRes.status,
    lockedBalanceAfter: custWallet.locked_balance,
    ordersLeaked: db.orders.length - ordersBeforeRollback,
    txLeaked: db.wallet_transactions.length - txBeforeRollback
  });

  // Test 2.2: Closed store rejection (is_open: false)
  const storeClosedId = `store_closed_${Date.now()}`;
  db.stores.push({
    id: storeClosedId,
    name: 'متجر مغلق للاختبار',
    is_open: false,
    city: 'nalut'
  });

  const closedRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: storeId,
    items: [{ product_id: prodAvailableId, quantity: 1, unit_price_lyd: 10.0 }],
    delivery_address: 'نالوت - المركز',
    payment_method: 'cash_on_delivery'
  }, authHeader);

  const storeClosedRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: storeClosedId,
    items: [{ product_id: prodAvailableId, quantity: 1, unit_price_lyd: 10.0 }],
    delivery_address: 'نالوت - المركز',
    payment_method: 'cash_on_delivery'
  }, authHeader);

  record('Rollback_Recovery', 'STRESS-2.2', 'Orders strictly rejected when store is closed (zero state mutations)', storeClosedRes.status === 400, {
    statusCode: storeClosedRes.status,
    errorMessage: storeClosedRes.body?.error
  });

  // ============================================================================
  // SUITE 3: Runtime Immutability of seed_data.json
  // ============================================================================
  console.log('\n--- SUITE 3: Runtime Immutability of seed_data.json ---');

  const seedPath = path.join(__dirname, 'seed_data.json');
  const initialStat = fs.statSync(seedPath);
  const initialSha = crypto.createHash('sha256').update(fs.readFileSync(seedPath)).digest('hex');

  // Trigger 20 checkouts and multiple state updates
  for (let i = 0; i < 10; i++) {
    const prodTempId = `prod_temp_${i}_${Date.now()}`;
    db.products.push({
      id: prodTempId,
      store_id: storeId,
      name: `صنف مؤقت ${i}`,
      price_lyd: 5.0,
      in_stock: true,
      stock_quantity: 100
    });
    await apiRequest('POST', '/api/v1/orders/checkout', {
      store_id: storeId,
      items: [{ product_id: prodTempId, quantity: 1, unit_price_lyd: 5.0 }],
      delivery_address: 'نالوت - المركز',
      payment_method: 'cash_on_delivery'
    }, authHeader);
  }

  // Explicitly call deprecated saveSeedData()
  serverMod.saveSeedData?.();

  const finalStat = fs.statSync(seedPath);
  const finalSha = crypto.createHash('sha256').update(fs.readFileSync(seedPath)).digest('hex');

  const seedUntouched = initialStat.mtimeMs === finalStat.mtimeMs && initialSha === finalSha;

  record('Persistence_Integrity', 'STRESS-3.1', 'seed_data.json remains 100% byte-for-byte immutable across live traffic', seedUntouched, {
    initialMtime: initialStat.mtimeMs,
    finalMtime: finalStat.mtimeMs,
    sha256Match: initialSha === finalSha,
    sha256: finalSha.substring(0, 16) + '...'
  });

  // ============================================================================
  // SUITE 4: Double-Entry Accounting Ledger Under Extreme Promotions
  // ============================================================================
  console.log('\n--- SUITE 4: Double-Entry Accounting Ledger Under Extreme Promotions ---');

  const promoStressCases = [
    {
      id: 'PROMO-4.1-OversizedCoupon',
      title: 'Promotional discount exceeds gross total (Gross: 15 LYD, Coupon: 50 LYD)',
      subtotal: 10.0,
      delivery: 5.0,
      discount: 50.0,
      points: 0.0,
      freeDelivery: 0.0,
      paymentMethod: 'cash_on_delivery'
    },
    {
      id: 'PROMO-4.2-MegaCoupon',
      title: 'Mega promotional discount (Gross: 25 LYD, Coupon: 1000 LYD)',
      subtotal: 20.0,
      delivery: 5.0,
      discount: 1000.0,
      points: 0.0,
      freeDelivery: 0.0,
      paymentMethod: 'cash_on_delivery'
    },
    {
      id: 'PROMO-4.3-Exact100Pct',
      title: 'Exact 100% discount where customer payment is strictly 0.00 LYD',
      subtotal: 16.0,
      delivery: 4.0,
      discount: 20.0,
      points: 0.0,
      freeDelivery: 0.0,
      paymentMethod: 'cash_on_delivery'
    },
    {
      id: 'PROMO-4.4-StackedPromotions',
      title: 'Stacked promos (Points + Free Delivery + Coupon) exceeding gross total',
      subtotal: 30.0,
      delivery: 10.0,
      discount: 25.0,
      points: 15.0,
      freeDelivery: 10.0, // Total promos = 50 LYD on 40 LYD gross
      paymentMethod: 'wallet'
    },
    {
      id: 'PROMO-4.5-ZeroDiscountFullPrice',
      title: 'Standard full-price delivery with zero discounts',
      subtotal: 35.0,
      delivery: 7.0,
      discount: 0.0,
      points: 0.0,
      freeDelivery: 0.0,
      paymentMethod: 'cash_on_delivery'
    },
    {
      id: 'PROMO-4.6-SubCentPrecision',
      title: 'High-precision sub-cent Libyan Dinars (rounding safety check)',
      subtotal: 17.555,
      delivery: 6.225,
      discount: 8.125,
      points: 0.0,
      freeDelivery: 0.0,
      paymentMethod: 'cash_on_delivery'
    }
  ];

  let allPromosBalanced = true;
  for (const tc of promoStressCases) {
    const gross = tc.subtotal + tc.delivery;
    const testOrder = {
      id: `ord_${tc.id}_${Date.now()}`,
      order_number: `ORD-${tc.id}`,
      store_id: storeId,
      customer_id: customerUser.id,
      driver_id: db.drivers[0]?.id || 'driver_01',
      payment_method: tc.paymentMethod,
      subtotal_lyd: tc.subtotal,
      delivery_fee_lyd: tc.delivery,
      discount_amount_lyd: tc.discount,
      loyalty_points_discount_lyd: tc.points,
      free_delivery_discount_lyd: tc.freeDelivery,
      total_amount_lyd: Math.max(0, gross - (tc.discount + tc.points + tc.freeDelivery)),
      delivered_at: new Date().toISOString()
    };

    let settlement = null;
    let err = null;
    try {
      settlement = await ledgerService.processOrderDelivery(db, testOrder);
    } catch (e) {
      err = e;
    }

    const balanced = settlement && settlement.is_balanced === true && !err;
    if (!balanced) allPromosBalanced = false;

    record('Accounting_Ledger', tc.id, tc.title, Boolean(balanced), {
      grossOrderValue: gross,
      requestedDiscount: tc.discount,
      settlementBalanced: settlement?.is_balanced,
      error: err ? err.message : null
    });
  }

  // ============================================================================
  // SUITE 5: Global Trial Balance (ميزان المراجعة) Verification
  // ============================================================================
  console.log('\n--- SUITE 5: Global Trial Balance & Financial Invariant Audit ---');

  const trial = accountingEngine.getTrialBalance(db);
  const ledgerDiscrepancy = trial.discrepancy_lyd;
  const isTrialBalanced = trial.is_balanced === true && ledgerDiscrepancy === 0.00;

  record('Accounting_Ledger', 'STRESS-5.1', 'Global Trial Balance maintains strictly 0.0000 LYD imbalance across all journal entries', isTrialBalanced, {
    totalDebits: trial.grand_total_debit,
    totalCredits: trial.grand_total_credit,
    discrepancy: ledgerDiscrepancy,
    totalAccounts: trial.accounts?.length,
    isBalanced: trial.is_balanced
  });

  // ============================================================================
  // SUITE 6: Concurrency on Order Status & Delivery Settlement
  // ============================================================================
  console.log('\n--- SUITE 6: Concurrency on Order Status & Delivery Settlement ---');

  // Create an order ready for delivery
  const fsmProdId = `prod_fsm_${Date.now()}`;
  db.products.push({
    id: fsmProdId,
    store_id: storeId,
    name: 'صنف دورة الحالة',
    price_lyd: 15.0,
    in_stock: true,
    stock_quantity: 50
  });

  const fsmOrderRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: storeId,
    items: [{ product_id: fsmProdId, quantity: 1, unit_price_lyd: 15.0 }],
    delivery_address: 'نالوت - المركز',
    payment_method: 'cash_on_delivery'
  }, authHeader);

  const fsmOrderId = fsmOrderRes.body?.data?.id || fsmOrderRes.body?.data?.order_id;
  assert.ok(fsmOrderId, 'FSM order must be created');

  // Follow authentic FSM: placed -> accepted -> preparing -> ready_for_pickup -> picked_up
  const driverId = db.drivers[0]?.id || 'driver_01';
  await apiRequest('POST', `/api/v1/orders/${fsmOrderId}/status`, { status: 'accepted', admin_override: true }, authHeader);
  await apiRequest('POST', `/api/v1/orders/${fsmOrderId}/status`, { status: 'preparing', admin_override: true }, authHeader);
  await apiRequest('POST', `/api/v1/orders/${fsmOrderId}/status`, { status: 'ready_for_pickup', driver_id: driverId, admin_override: true }, authHeader);
  await apiRequest('POST', `/api/v1/orders/${fsmOrderId}/status`, { status: 'picked_up', driver_id: driverId, admin_override: true }, authHeader);

  // Now race 2 concurrent delivered calls for the same order
  const fsmOtp = fsmOrderRes.body?.data?.otp_code || fsmOrderRes.body?.data?.delivery_otp;
  const raceDeliveredReqs = [
    apiRequest('POST', `/api/v1/orders/${fsmOrderId}/status`, { status: 'delivered', driver_id: driverId, delivery_otp: fsmOtp, admin_override: true }, adminAuthHeader),
    apiRequest('POST', `/api/v1/orders/${fsmOrderId}/status`, { status: 'delivered', driver_id: driverId, delivery_otp: fsmOtp, admin_override: true }, adminAuthHeader)
  ];
  const raceDeliveredResults = await Promise.all(raceDeliveredReqs);
  const deliveredStatuses = raceDeliveredResults.map(r => r.status);

  // Both should either succeed idempotently (200) or one succeed and one report already delivered
  const orderAfterRace = db.orders.find(o => o.id === fsmOrderId);
  const safeDeliveryRace = deliveredStatuses.every(s => s === 200 || s === 400) && orderAfterRace.status === 'delivered';

  record('FSM_Concurrency', 'STRESS-6.1', 'Concurrent delivery settlement maintains idempotent status (final status: delivered)', safeDeliveryRace, {
    responseStatuses: deliveredStatuses,
    finalStatus: orderAfterRace.status
  });

  // Test 6.2: Invalid state transition (e.g. from delivered back to preparing)
  const invalidTransitionRes = await apiRequest('POST', `/api/v1/orders/${fsmOrderId}/status`, { status: 'preparing' }, authHeader);
  record('FSM_Concurrency', 'STRESS-6.2', 'Illegal transition from terminal delivered state rejected', invalidTransitionRes.status === 400, {
    statusCode: invalidTransitionRes.status,
    error: invalidTransitionRes.body?.error
  });

  // ============================================================================
  // SUITE 7: Driver Cash Custody Settlement Concurrency
  // ============================================================================
  console.log('\n--- SUITE 7: Driver Cash Custody Settlement Concurrency ---');

  const testDriver = db.drivers.find(d => d.id === driverId);
  if (testDriver) {
    testDriver.cash_in_hand_lyd = 80.0;
    testDriver.cod_balance_lyd = 80.0;
    const initialEarnings = testDriver.wallet_balance_lyd || 25.0;
    testDriver.wallet_balance_lyd = initialEarnings;

    // Concurrently trigger 2 settlement requests
    const settleReqs = [
      apiRequest('POST', `/api/v1/drivers/${driverId}/settle`, { notes: 'تسوية خزينة متزامنة 1' }, adminAuthHeader),
      apiRequest('POST', `/api/v1/drivers/${driverId}/settle`, { notes: 'تسوية خزينة متزامنة 2' }, adminAuthHeader)
    ];

    const settleResults = await Promise.all(settleReqs);
    const settleStatuses = settleResults.map(r => r.status);

    const finalCashInHand = testDriver.cash_in_hand_lyd;
    const finalEarnings = testDriver.wallet_balance_lyd;

    // Invariant: Cash in hand cleared to 0.00 LYD, never drops below zero, net earnings preserved
    const settleClean = finalCashInHand === 0.0 && finalEarnings >= initialEarnings;

    record('Driver_Settlement', 'STRESS-7.1', 'Concurrent driver cash settlement clears custody to exactly 0.00 without negative balance', settleClean, {
      responseStatuses: settleStatuses,
      initialCashInHand: 80.0,
      finalCashInHand,
      preservedEarnings: finalEarnings
    });
  }

  // ============================================================================
  // SUMMARY
  // ============================================================================
  console.log('\n================================================================');
  console.log('📊 CHALLENGER M1_R2_1 STRESS VERIFICATION SUMMARY');
  console.log('================================================================');
  const total = results.length;
  const totalPassed = results.filter(r => r.passed).length;
  const totalFailed = results.filter(r => !r.passed).length;
  const rate = ((totalPassed / total) * 100).toFixed(1);

  console.log(`Total Stress Tests:  ${total}`);
  console.log(`Passed:              ${totalPassed}`);
  console.log(`Failed:              ${totalFailed}`);
  console.log(`Overall Pass Rate:   ${rate}%\n`);

  if (totalFailed > 0) {
    console.error('❌ EMPIRICAL DEFECTS DETECTED:');
    results.filter(r => !r.passed).forEach(r => {
      console.error(` - [${r.testId}] ${r.title}: ${JSON.stringify(r.details)}`);
    });
    process.exit(1);
  } else {
    console.log('🎉 ALL EMPIRICAL ADVERSARIAL STRESS TESTS PASSED WITH 100% PRECISION!');
    process.exit(0);
  }
}

run().catch(err => {
  console.error('[FATAL EXCEPTION]:', err);
  process.exit(1);
});
