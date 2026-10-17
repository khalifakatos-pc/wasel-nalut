/**
 * ============================================================================
 * EMPIRICAL ADVERSARIAL STRESS & VERIFICATION SUITE — CHALLENGER M1_1
 * ============================================================================
 * Target: Backend PostgreSQL Persistence & In-Memory Elimination
 * Orchestrator Milestone: Milestone 1
 *
 * Objectives Verified:
 * 1. Concurrency, race conditions, and rollback guarantees in POST /api/v1/orders/checkout and status updates.
 * 2. Stock non-negativity and overselling under concurrent purchases.
 * 3. Mid-checkout failures (insufficient funds, out of stock) clean rollback (zero leaked rows/locks).
 * 4. Zero runtime writes to seed_data.json.
 * 5. Repository and SQL persistence fidelity (stock_quantity and error propagation).
 * ============================================================================
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const assert = require('assert');

const TEST_PORT = 3000;
process.env.NODE_ENV = 'test';

const testResults = [];

function recordTest(testId, title, passed, details = {}) {
  testResults.push({ testId, title, passed, details });
  const status = passed ? '✅ PASS' : '❌ FAIL';
  console.log(`[${status}] ${testId}: ${title}`);
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

    req.on('error', (err) => {
      reject(err);
    });

    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

async function runChallengerSuite() {
  console.log('================================================================');
  console.log('🛡️  CHALLENGER M1_1: EMPIRICAL ADVERSARIAL VERIFICATION SUITE');
  console.log('================================================================\n');

  // Load server module
  const serverMod = require('./server.js');
  const db = serverMod.db;
  const accountingEngine = serverMod.accountingEngine;
  const ledgerService = serverMod.ledgerService;

  // Ensure server has started
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
  const storeId = db.stores[0]?.id || 'store_nalut_ranchello';

  // --------------------------------------------------------------------------
  // TEST 1: Stock Non-Negativity under Concurrent Contention (Objective 2)
  // --------------------------------------------------------------------------
  console.log('--- TEST 1: Stock Non-Negativity under Concurrent Checkout Contention ---');
  const stockProdId = `prod_stock_contention_${Date.now()}`;
  const stockProduct = {
    id: stockProdId,
    store_id: storeId,
    name: 'صنف فحص عدم السالبية',
    name_ar: 'صنف فحص عدم السالبية',
    price_lyd: 12.0,
    price: 12.0,
    in_stock: true,
    is_available: true,
    stock_quantity: 3
  };
  db.products.push(stockProduct);

  const numConcurrent = 15;
  const batchRequests = [];
  for (let i = 0; i < numConcurrent; i++) {
    batchRequests.push(
      apiRequest('POST', '/api/v1/orders/checkout', {
        store_id: storeId,
        items: [{ product_id: stockProdId, quantity: 1, unit_price_lyd: 12.0 }],
        delivery_address: 'نالوت - المركز',
        payment_method: 'cash_on_delivery'
      }, authHeader)
    );
  }

  const batchResults = await Promise.all(batchRequests);
  const successOrders = batchResults.filter(r => r.status === 200 || r.status === 201);
  const failedOrders = batchResults.filter(r => r.status >= 400);
  const finalStock = stockProduct.stock_quantity;

  const stockIsNonNegative = finalStock >= 0;
  recordTest(
    'M1.1-TC01',
    'Stock cannot drop below zero under concurrent purchases',
    stockIsNonNegative,
    {
      initialStock: 3,
      finalStock,
      totalConcurrentRequests: numConcurrent,
      successfulOrders: successOrders.length,
      failedOrders: failedOrders.length
    }
  );

  // --------------------------------------------------------------------------
  // TEST 2: Concurrency & Overselling Prevention (Objective 1)
  // --------------------------------------------------------------------------
  console.log('\n--- TEST 2: Overselling Race Condition Prevention ---');
  // For initial stock = 3, exactly 3 should succeed and 12 should be rejected
  const noOverselling = successOrders.length <= 3;
  recordTest(
    'M1.1-TC02',
    'Overselling Race Condition: Orders created cannot exceed available inventory',
    noOverselling,
    {
      initialStock: 3,
      ordersCreated: successOrders.length,
      oversoldExcess: Math.max(0, successOrders.length - 3)
    }
  );

  // --------------------------------------------------------------------------
  // TEST 3: Mid-Checkout Failure Rollback - Insufficient Wallet Balance (Objective 3)
  // --------------------------------------------------------------------------
  console.log('\n--- TEST 3: Mid-Checkout Failure Rollback (Insufficient Wallet Funds) ---');
  const poorUserId = `user_poor_${Date.now()}`;
  const poorWallet = {
    id: `wallet_${poorUserId}`,
    user_id: poorUserId,
    wallet_type: 'customer_wallet',
    currency: 'LYD',
    balance: 5.00,
    locked_balance: 0.00,
    status: 'active'
  };
  db.wallets.push(poorWallet);
  db.users.push({
    id: poorUserId,
    phone: '0917777777',
    full_name: 'زبون الرصيد المنخفض',
    role: 'customer',
    password: 'Customer@Nalut2026!Secure'
  });

  const poorLogin = await apiRequest('POST', '/api/v1/auth/login', {
    phone: '0917777777',
    password: 'Customer@Nalut2026!Secure'
  });
  const poorToken = poorLogin.body?.data?.token;
  const poorAuth = poorToken ? { Authorization: `Bearer ${poorToken}` } : {};

  const ordersCountBefore = db.orders.length;
  const txCountBefore = db.wallet_transactions.length;
  const lockedBefore = poorWallet.locked_balance;

  const poorRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: storeId,
    items: [{ product_id: db.products[0].id, quantity: 2 }],
    delivery_address: 'نالوت - المركز',
    payment_method: 'wallet'
  }, poorAuth);

  const ordersCountAfter = db.orders.length;
  const txCountAfter = db.wallet_transactions.length;
  const lockedAfter = poorWallet.locked_balance;

  const rejected400 = poorRes.status === 400;
  const noOrderLeak = ordersCountAfter === ordersCountBefore;
  const noTxLeak = txCountAfter === txCountBefore;
  const noLockLeak = lockedAfter === lockedBefore;

  recordTest(
    'M1.1-TC03',
    'Mid-checkout insufficient funds rolls back cleanly with zero leaked rows or locks',
    rejected400 && noOrderLeak && noTxLeak && noLockLeak,
    {
      statusCode: poorRes.status,
      ordersLeaked: ordersCountAfter - ordersCountBefore,
      transactionsLeaked: txCountAfter - txCountBefore,
      lockedBalanceBefore: lockedBefore,
      lockedBalanceAfter: lockedAfter
    }
  );

  // --------------------------------------------------------------------------
  // TEST 4: Mid-Checkout Out of Stock Preflight Rollback (Objective 3)
  // --------------------------------------------------------------------------
  console.log('\n--- TEST 4: Mid-Checkout Out of Stock Preflight Rollback ---');
  const oosId = `prod_oos_test_${Date.now()}`;
  db.products.push({
    id: oosId,
    store_id: storeId,
    name: 'صنف نافد تماماً',
    name_ar: 'صنف نافد تماماً',
    price_lyd: 15.0,
    price: 15.0,
    in_stock: false,
    is_available: false,
    stock_quantity: 0
  });

  const ordersPreOos = db.orders.length;
  const oosRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: storeId,
    items: [{ product_id: oosId, quantity: 1 }],
    delivery_address: 'نالوت - المركز',
    payment_method: 'cash_on_delivery'
  }, authHeader);
  const ordersPostOos = db.orders.length;

  recordTest(
    'M1.1-TC04',
    'Mid-checkout out-of-stock rolls back cleanly with zero leaked rows',
    oosRes.status === 400 && ordersPostOos === ordersPreOos,
    {
      statusCode: oosRes.status,
      errorMessage: oosRes.body?.error,
      ordersLeaked: ordersPostOos - ordersPreOos
    }
  );

  // --------------------------------------------------------------------------
  // TEST 5: Zero Runtime Writes to seed_data.json (Objective 4)
  // --------------------------------------------------------------------------
  console.log('\n--- TEST 5: Runtime Immutability of seed_data.json ---');
  const seedPath = path.join(__dirname, 'seed_data.json');
  const mtimeInitial = fs.statSync(seedPath).mtimeMs;
  const hashInitial = crypto.createHash('sha256').update(fs.readFileSync(seedPath)).digest('hex');

  // Perform multiple live operations (checkout, status transitions)
  for (let i = 0; i < 4; i++) {
    const oRes = await apiRequest('POST', '/api/v1/orders/checkout', {
      store_id: storeId,
      items: [{ product_id: db.products[0].id, quantity: 1 }],
      delivery_address: 'نالوت - المركز',
      payment_method: 'cash_on_delivery'
    }, authHeader);
    const orderId = oRes.body?.data?.id;
    if (orderId) {
      await apiRequest('POST', `/api/v1/orders/${orderId}/status`, { status: 'preparing' }, authHeader);
      await apiRequest('POST', `/api/v1/orders/${orderId}/status`, { status: 'ready_for_pickup' }, authHeader);
    }
  }

  const mtimeFinal = fs.statSync(seedPath).mtimeMs;
  const hashFinal = crypto.createHash('sha256').update(fs.readFileSync(seedPath)).digest('hex');

  const fileUntouched = mtimeInitial === mtimeFinal && hashInitial === hashFinal;
  recordTest(
    'M1.1-TC05',
    'Validate that zero runtime writes occur to seed_data.json',
    fileUntouched,
    {
      mtimeBefore: mtimeInitial,
      mtimeAfter: mtimeFinal,
      sha256Match: hashInitial === hashFinal
    }
  );

  // --------------------------------------------------------------------------
  // TEST 6: Order Status Transitions Concurrency & FSM Atomicity (Objective 1)
  // --------------------------------------------------------------------------
  console.log('\n--- TEST 6: Order Status Transition Concurrency & Race Conditions ---');
  const fsmRes = await apiRequest('POST', '/api/v1/orders/checkout', {
    store_id: storeId,
    items: [{ product_id: db.products[0].id, quantity: 1 }],
    delivery_address: 'نالوت - المركز',
    payment_method: 'cash_on_delivery'
  }, authHeader);
  const fsmOrderId = fsmRes.body?.data?.id;

  // Prepare order
  await apiRequest('POST', `/api/v1/orders/${fsmOrderId}/status`, { status: 'preparing' }, authHeader);

  // Fire conflicting status updates simultaneously: cancel vs ready_for_pickup
  const [trans1, trans2] = await Promise.all([
    apiRequest('POST', `/api/v1/orders/${fsmOrderId}/status`, { status: 'ready_for_pickup' }, authHeader),
    apiRequest('POST', `/api/v1/orders/${fsmOrderId}/status`, { status: 'cancelled', cancellation_reason: 'driver delayed' }, authHeader)
  ]);

  const fsmOrder = db.orders.find(o => o.id === fsmOrderId);
  const validStatus = ['ready_for_pickup', 'cancelled'].includes(fsmOrder?.status);

  recordTest(
    'M1.1-TC06',
    'Order status update concurrency maintains strict FSM state validity',
    validStatus,
    {
      transition1Status: trans1.status,
      transition2Status: trans2.status,
      finalOrderStatus: fsmOrder?.status
    }
  );

  // --------------------------------------------------------------------------
  // TEST 7: Code Audit: saveProductToPg Omits stock_quantity (Defect Finding)
  // --------------------------------------------------------------------------
  console.log('\n--- TEST 7: PostgreSQL saveProductToPg stock_quantity Persistence Audit ---');
  const serverCode = fs.readFileSync(path.join(__dirname, 'server.js'), 'utf-8');
  const saveProductRegex = /async function saveProductToPg[\s\S]*?INSERT INTO products[\s\S]*?VALUES[\s\S]*?ON CONFLICT \(id\) DO UPDATE SET([\s\S]*?)\`,/;
  const match = saveProductRegex.exec(serverCode);
  const updateClause = match ? match[1] : '';
  const persistsStock = updateClause.includes('stock_quantity');

  recordTest(
    'M1.1-TC07',
    'PostgreSQL saveProductToPg persists stock_quantity to Database',
    persistsStock,
    {
      persistsStock,
      finding: persistsStock ? 'OK' : 'CRITICAL DEFECT: saveProductToPg omits stock_quantity from both INSERT and ON CONFLICT UPDATE; stock deductions are lost in PostgreSQL'
    }
  );

  // --------------------------------------------------------------------------
  // TEST 8: Code Audit: saveOrderToPg Swallows SQL Errors without Re-throwing
  // --------------------------------------------------------------------------
  console.log('\n--- TEST 8: SQL Error Swallowing in saveOrderToPg (False Commit Hazard) ---');
  const saveOrderMatch = /async function saveOrderToPg[\s\S]*?catch \(err\) \{([\s\S]*?)\}/.exec(serverCode);
  const saveOrderCatch = saveOrderMatch ? saveOrderMatch[1] : '';
  const rethrowsInSaveOrder = saveOrderCatch.includes('throw');

  recordTest(
    'M1.1-TC08',
    'PostgreSQL saveOrderToPg re-throws SQL errors to trigger transaction ROLLBACK',
    rethrowsInSaveOrder,
    {
      rethrows: rethrowsInSaveOrder,
      finding: rethrowsInSaveOrder ? 'OK' : 'CRITICAL DEFECT: saveOrderToPg catches and swallows SQL errors without re-throwing, causing failed queries to falsely COMMIT'
    }
  );

  // --------------------------------------------------------------------------
  // TEST 9: In-Memory Leak on Mid-Checkout Transaction Exception
  // --------------------------------------------------------------------------
  console.log('\n--- TEST 9: In-Memory Leak on Mid-Checkout Transaction Exception ---');
  const checkoutCatchMatch = /app\.post\(\['\/api\/v1\/orders\/checkout'[\s\S]*?\} catch \(err\) \{([\s\S]*?)\}\s*\}\);/.exec(serverCode);
  const checkoutCatchBlock = checkoutCatchMatch ? checkoutCatchMatch[1] : '';

  const revertsLockedBalance = checkoutCatchBlock.includes('locked_balance') || checkoutCatchBlock.includes('customerWallet');
  const revertsOrders = checkoutCatchBlock.includes('db.orders') || checkoutCatchBlock.includes('pop') || checkoutCatchBlock.includes('splice');
  const cleanCatchReversion = revertsLockedBalance && revertsOrders;

  recordTest(
    'M1.1-TC09',
    'In-memory cache rolls back escrow hold and orders if mid-checkout transaction fails',
    cleanCatchReversion,
    {
      revertsLockedBalance,
      revertsOrders,
      finding: cleanCatchReversion ? 'OK' : 'HIGH DEFECT: If an exception throws mid-checkout after line 3000, customerWallet.locked_balance, db.wallet_transactions, and db.orders remain corrupted in memory'
    }
  );

  // --------------------------------------------------------------------------
  // TEST 10: Promo Discount Exceeding Order Subtotal (Ledger Discrepancy Hazard)
  // --------------------------------------------------------------------------
  console.log('\n--- TEST 10: Oversized Promo Discount Ledger Balance Verification ---');
  const promoOrder = {
    id: `ord_promo_hazard_${Date.now()}`,
    order_number: 'ORD-PROMO-HAZARD',
    store_id: storeId,
    customer_id: 'cust_01',
    driver_id: 'driver_01',
    payment_method: 'cash_on_delivery',
    subtotal_lyd: 5.0,
    delivery_fee_lyd: 4.0,
    discount_amount_lyd: 15.0, // Discount > (subtotal + delivery_fee)
    total_amount_lyd: 0.0,
    delivered_at: new Date().toISOString()
  };

  let ledgerBalanced = false;
  let ledgerError = null;
  try {
    const settlement = await ledgerService.processOrderDelivery(db, promoOrder);
    ledgerBalanced = settlement.is_balanced === true;
  } catch (err) {
    ledgerError = err.message;
  }

  recordTest(
    'M1.1-TC10',
    'Double-entry General Ledger settlement balances when promotion discount exceeds gross total',
    ledgerBalanced,
    {
      ledgerBalanced,
      error: ledgerError,
      finding: ledgerBalanced ? 'OK' : 'MEDIUM DEFECT: When promotional discounts exceed order total, ledgerService debits the full coupon amount without clamping to gross order value, causing unbalanced journal entry'
    }
  );

  // --------------------------------------------------------------------------
  // SUMMARY
  // --------------------------------------------------------------------------
  console.log('\n================================================================');
  console.log('📊 CHALLENGER M1_1 VERIFICATION SUMMARY');
  console.log('================================================================');
  const total = testResults.length;
  const passed = testResults.filter(r => r.passed).length;
  const failed = testResults.filter(r => !r.passed).length;

  console.log(`Total Verification Checks: ${total}`);
  console.log(`Passed:                   ${passed}`);
  console.log(`Failed:                   ${failed}`);
  console.log(`Overall Pass Rate:        ${((passed / total) * 100).toFixed(1)}%`);
  console.log('================================================================\n');

  setTimeout(() => {
    process.exit(failed > 0 ? 1 : 0);
  }, 500);
}

runChallengerSuite().catch(err => {
  console.error('Fatal challenger harness error:', err);
  process.exit(1);
});
