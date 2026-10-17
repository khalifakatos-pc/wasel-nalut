/**
 * ============================================================================
 * EMPIRICAL ADVERSARIAL STRESS & VERIFICATION SUITE — CHALLENGER M1_2
 * ============================================================================
 * Focus:
 * 1. Data Zero State Endpoints & Seed Integrity
 * 2. Driver Custody Balance Resets (COD Cash in Hand)
 * 3. Double-Entry Cancellation Settlement (COD & Wallet) with 0.0000 LYD imbalance
 * 4. Selective Admin Orders Purge (/api/v1/admin/orders/purge) Catalog Conservation
 * 5. Admin FSM Lifecycle Override & RBAC Penetration
 * ============================================================================
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const jwt = require('jsonwebtoken');
const PORT = process.env.PORT || 3000;

// Helper for HTTP requests
function httpRequest(method, endpoint, body = null, headers = {}) {
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
      port: PORT,
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

const testResults = [];
function recordResult(section, testName, passed, details = null) {
  testResults.push({ section, testName, passed, details });
  const icon = passed ? '✅ PASS' : '❌ FAIL';
  console.log(`  ${icon} [${section}] ${testName}`);
  if (!passed && details) {
    console.error(`      Detail:`, details);
  }
}

async function runAdversarialM12Suite() {
  console.log('================================================================');
  console.log('🛡️  CHALLENGER M1_2: EMPIRICAL ADVERSARIAL STRESS SUITE');
  console.log('================================================================\n');

  // Boot server in process (loads .env)
  const serverMod = require('./server.js');
  const JWT_SECRET = process.env.JWT_SECRET || 'wasel-nalut-secure-jwt-key-2026-prod';
  const db = serverMod.db;
  const ledgerService = serverMod.ledgerService;
  const accountingEngine = serverMod.accountingEngine;
  const orderService = require('./services/orderService');

  // Give server time to bind
  await new Promise(r => setTimeout(r, 600));

  // Generate tokens for testing
  const adminToken = jwt.sign(
    { id: 'admin_master', sub: 'admin_master', role: 'admin', full_name: 'مدير واصل' },
    JWT_SECRET,
    { expiresIn: '1h' }
  );

  const customerToken = jwt.sign(
    { id: 'usr_guest_nalut', sub: 'usr_guest_nalut', role: 'customer', full_name: 'زبون عادي' },
    JWT_SECRET,
    { expiresIn: '1h' }
  );

  // ==========================================================================
  // SUITE 1: Seed Data Zero State & Catalog Preservation Invariants
  // ==========================================================================
  console.log('--- SUITE 1: Seed Data Zero State & Catalog Preservation Invariants ---');
  const seedPath = path.join(__dirname, 'seed_data.json');
  const seed = JSON.parse(fs.readFileSync(seedPath, 'utf8'));

  // Orders zeroed
  const seedOrdersZeroed = Array.isArray(seed.orders) && seed.orders.length === 0;
  recordResult('SUITE 1', 'seed_data.json orders array is strictly empty []', seedOrdersZeroed, { length: seed.orders?.length });

  // Driver liabilities zeroed
  let driverLiabilitiesZeroed = true;
  let driverDetails = [];
  for (const d of (seed.drivers || [])) {
    const ok = d.active_order_id === null &&
               d.cod_balance_lyd === 0 &&
               d.cash_in_hand_lyd === 0 &&
               d.status === 'offline' &&
               d.is_active === false;
    if (!ok) driverLiabilitiesZeroed = false;
    driverDetails.push({ id: d.id, active_order_id: d.active_order_id, cod: d.cod_balance_lyd, cash: d.cash_in_hand_lyd, status: d.status, is_active: d.is_active });
  }
  recordResult('SUITE 1', 'All drivers in seed_data.json have 0 COD/Cash liability & null active order', driverLiabilitiesZeroed, driverDetails);

  // Wallets locked balance zeroed
  let walletsZeroed = true;
  for (const w of (seed.wallets || [])) {
    if (w.locked_balance !== undefined && w.locked_balance !== 0) {
      walletsZeroed = false;
    }
  }
  recordResult('SUITE 1', 'All wallets in seed_data.json have 0 locked_balance', walletsZeroed);

  // Catalog preservation
  const storesCountOk = seed.stores?.length === 4;
  recordResult('SUITE 1', 'Catalog Preservation: exactly 4 stores preserved', storesCountOk, { count: seed.stores?.length });

  const productsCountOk = seed.products?.length === 52;
  recordResult('SUITE 1', 'Catalog Preservation: exactly 52 products preserved', productsCountOk, { count: seed.products?.length });

  const categoriesCountOk = seed.categories?.length === 6;
  recordResult('SUITE 1', 'Catalog Preservation: exactly 6 categories preserved', categoriesCountOk, { count: seed.categories?.length });

  const driversCountOk = seed.drivers?.length === 2;
  recordResult('SUITE 1', 'Catalog Preservation: exactly 2 drivers preserved', driversCountOk, { count: seed.drivers?.length });

  // ==========================================================================
  // SUITE 2: Live Zero-State HTTP Endpoints
  // ==========================================================================
  console.log('\n--- SUITE 2: Live Zero-State HTTP Endpoints ---');

  // 2.1 GET /api/v1/orders
  const resAllOrders = await httpRequest('GET', '/api/v1/orders');
  const allOrdersEmpty = resAllOrders.status === 200 &&
                         resAllOrders.body.success === true &&
                         resAllOrders.body.count === 0 &&
                         Array.isArray(resAllOrders.body.data) &&
                         resAllOrders.body.data.length === 0;
  recordResult('SUITE 2', 'GET /api/v1/orders returns count: 0 and data: []', allOrdersEmpty, resAllOrders.body);

  // 2.2 GET /api/v1/orders with query filters
  const resDeliveredFilter = await httpRequest('GET', '/api/v1/orders?status=delivered');
  const deliveredFilterEmpty = resDeliveredFilter.status === 200 && resDeliveredFilter.body.count === 0 && resDeliveredFilter.body.data.length === 0;
  recordResult('SUITE 2', 'GET /api/v1/orders?status=delivered returns count: 0 and data: []', deliveredFilterEmpty);

  const resCustomerFilter = await httpRequest('GET', '/api/v1/orders?customer_id=usr_guest_nalut');
  const customerFilterEmpty = resCustomerFilter.status === 200 && resCustomerFilter.body.count === 0 && resCustomerFilter.body.data.length === 0;
  recordResult('SUITE 2', 'GET /api/v1/orders?customer_id=... returns count: 0 and data: []', customerFilterEmpty);

  const resDriverFilter = await httpRequest('GET', '/api/v1/orders?driver_id=driver_nalut_01');
  const driverFilterEmpty = resDriverFilter.status === 200 && resDriverFilter.body.count === 0 && resDriverFilter.body.data.length === 0;
  recordResult('SUITE 2', 'GET /api/v1/orders?driver_id=... returns count: 0 and data: []', driverFilterEmpty);

  const resNonExistent = await httpRequest('GET', '/api/v1/orders?id=non_existent_uuid_9999');
  const nonExistentEmpty = resNonExistent.status === 200 && resNonExistent.body.count === 0 && resNonExistent.body.data.length === 0;
  recordResult('SUITE 2', 'GET /api/v1/orders?id=non_existent returns count: 0 and data: []', nonExistentEmpty);

  // ==========================================================================
  // SUITE 3: Double-Entry Cancellation Settlement & Driver Custody Reset Stress
  // ==========================================================================
  console.log('\n--- SUITE 3: Double-Entry Cancellation Settlement & Driver Custody Resets ---');

  // Test isolated database instance for accounting
  const isolatedDb = {
    drivers: [
      {
        id: 'drv_stress_01',
        user_id: 'usr_drv_stress_01',
        full_name: 'كابتن اختبار الإلغاء',
        wallet_balance_lyd: 0.00,
        cash_in_hand_lyd: 0.00,
        cod_balance_lyd: 0.00,
        status: 'online_idle'
      }
    ],
    stores: [
      {
        id: 'store_stress_01',
        name: 'مطعم نالوت التجريبي',
        merchant_id: 'merchant_stress_01',
        commission_rate: 10.0
      }
    ],
    wallets: [
      {
        id: 'wallet_cust_stress_01',
        user_id: 'usr_cust_stress_01',
        wallet_type: 'customer_wallet',
        balance: 200.00,
        locked_balance: 0.00,
        currency: 'LYD'
      },
      {
        id: '00000000-0000-0000-0000-000000000002',
        user_id: 'system_revenue',
        wallet_type: 'platform_revenue',
        balance: 0.00,
        locked_balance: 0.00,
        currency: 'LYD'
      }
    ],
    wallet_transactions: [],
    vouchers: [],
    journal_entries: [],
    journal_entry_lines: [],
    orders: []
  };

  // --- 3.1 COD Standard Order Delivery & Cancellation ---
  const codOrder = {
    id: 'ord_cod_stress_01',
    order_number: 'ORD-COD-101',
    store_id: 'store_stress_01',
    driver_id: 'drv_stress_01',
    customer_id: 'usr_cust_stress_01',
    payment_method: 'cash_on_delivery',
    subtotal_lyd: 40.00,
    delivery_fee_lyd: 10.00,
    service_fee_lyd: 2.00,
    discount_amount_lyd: 0.00,
    total_amount_lyd: 52.00, // 40 + 10 + 2 = 52.00
    delivered_at: new Date().toISOString()
  };
  isolatedDb.orders.push(codOrder);

  // Deliver COD Order
  const codDeliveryRes = await ledgerService.processOrderDelivery(isolatedDb, codOrder);
  const codDeliveredBalanced = codDeliveryRes.is_balanced && codDeliveryRes.discrepancy === 0.00;
  const codDriverCustodyHeld = isolatedDb.drivers[0].cash_in_hand_lyd === 52.00;
  recordResult('SUITE 3', 'COD Delivery: balanced delivery settlement & 52.00 LYD custody bound', codDeliveredBalanced && codDriverCustodyHeld, {
    discrepancy: codDeliveryRes.discrepancy,
    driverCash: isolatedDb.drivers[0].cash_in_hand_lyd
  });

  // Check Account 1040 before cancellation
  const tbCodDelivered = accountingEngine.getTrialBalance(isolatedDb);
  const acc1040Before = tbCodDelivered.accounts.find(a => a.code === '1040')?.netBalance || 0;
  recordResult('SUITE 3', 'COD Delivery: Account 1040 holds debit balance of 52.00 LYD', acc1040Before === 52.00, { acc1040Before });

  // Cancel COD Order
  const codReversalRes = await ledgerService.reverseOrderSettlement(isolatedDb, codOrder);
  const codReversalOk = codReversalRes.success === true && codReversalRes.reversed_cod === 52.00;
  const codDriverCustodyZeroed = isolatedDb.drivers[0].cash_in_hand_lyd === 0.00 && isolatedDb.drivers[0].cod_balance_lyd === 0.00;
  const codDriverEarningsZeroed = isolatedDb.drivers[0].wallet_balance_lyd === 0.00;
  recordResult('SUITE 3', 'COD Cancellation: driver cash_in_hand_lyd & cod_balance_lyd strictly zeroed to 0.00 LYD', codDriverCustodyZeroed, {
    cash_in_hand: isolatedDb.drivers[0].cash_in_hand_lyd,
    cod_balance: isolatedDb.drivers[0].cod_balance_lyd
  });
  recordResult('SUITE 3', 'COD Cancellation: driver wallet earnings debited back to 0.00 LYD', codDriverEarningsZeroed, {
    wallet_balance: isolatedDb.drivers[0].wallet_balance_lyd
  });

  const tbCodAfter = accountingEngine.getTrialBalance(isolatedDb);
  const acc1040After = tbCodAfter.accounts.find(a => a.code === '1040')?.netBalance || 0;
  const acc2030After = tbCodAfter.accounts.find(a => a.code === '2030')?.netBalance || 0;
  const acc2020After = tbCodAfter.accounts.find(a => a.code === '2020')?.netBalance || 0;
  const codTrialBalanceZeroDiscrepancy = tbCodAfter.is_balanced && tbCodAfter.discrepancy_lyd === 0.0000;

  recordResult('SUITE 3', 'COD Cancellation: Account 1040 net balance strictly 0.00 LYD', acc1040After === 0.00, { acc1040After });
  recordResult('SUITE 3', 'COD Cancellation: Accounts 2020 & 2030 net balances strictly 0.00 LYD', acc2020After === 0.00 && acc2030After === 0.00, { acc2020After, acc2030After });
  recordResult('SUITE 3', 'COD Cancellation: Trial balance discrepancy strictly 0.0000 LYD', codTrialBalanceZeroDiscrepancy, { discrepancy: tbCodAfter.discrepancy_lyd });

  // --- 3.2 Wallet Order Delivery & Cancellation ---
  const initialCustBalance = isolatedDb.wallets.find(w => w.user_id === 'usr_cust_stress_01').balance;
  const walletOrder = {
    id: 'ord_wallet_stress_02',
    order_number: 'ORD-WAL-202',
    store_id: 'store_stress_01',
    driver_id: 'drv_stress_01',
    customer_id: 'usr_cust_stress_01',
    payment_method: 'wallet',
    subtotal_lyd: 60.00,
    delivery_fee_lyd: 10.00,
    service_fee_lyd: 0.00,
    discount_amount_lyd: 0.00,
    total_amount_lyd: 70.00,
    delivered_at: new Date().toISOString()
  };
  isolatedDb.orders.push(walletOrder);

  // Deliver Wallet Order
  await ledgerService.processOrderDelivery(isolatedDb, walletOrder);
  const custWalletAfterDelivery = isolatedDb.wallets.find(w => w.user_id === 'usr_cust_stress_01').balance;
  const driverCashUntouched = isolatedDb.drivers[0].cash_in_hand_lyd === 0.00;
  recordResult('SUITE 3', 'Wallet Delivery: customer wallet debited 70.00 LYD & driver cash untouched (0.00 LYD)', custWalletAfterDelivery === (initialCustBalance - 70.00) && driverCashUntouched, {
    custBalance: custWalletAfterDelivery,
    driverCash: isolatedDb.drivers[0].cash_in_hand_lyd
  });

  // Cancel Wallet Order
  const walletReversalRes = await ledgerService.reverseOrderSettlement(isolatedDb, walletOrder);
  const custWalletRefunded = isolatedDb.wallets.find(w => w.user_id === 'usr_cust_stress_01').balance;
  const walletReversalSuccess = walletReversalRes.success && custWalletRefunded === initialCustBalance;
  recordResult('SUITE 3', 'Wallet Cancellation: customer wallet fully refunded +70.00 LYD (returned to initial balance)', walletReversalSuccess, {
    restoredBalance: custWalletRefunded,
    expected: initialCustBalance
  });

  const tbWalletAfter = accountingEngine.getTrialBalance(isolatedDb);
  const walletTbBalanced = tbWalletAfter.is_balanced && tbWalletAfter.discrepancy_lyd === 0.0000;
  recordResult('SUITE 3', 'Wallet Cancellation: Trial balance discrepancy strictly 0.0000 LYD', walletTbBalanced, {
    discrepancy: tbWalletAfter.discrepancy_lyd
  });

  // --- 3.3 Complex Promotions (Voucher + Loyalty + Subsidy) Cancellation under COD ---
  const promoOrder = {
    id: 'ord_promo_stress_03',
    order_number: 'ORD-PRM-303',
    store_id: 'store_stress_01',
    driver_id: 'drv_stress_01',
    customer_id: 'usr_cust_stress_01',
    payment_method: 'cash_on_delivery',
    subtotal_lyd: 100.00,
    delivery_fee_lyd: 15.00,
    service_fee_lyd: 2.00, // Gross = 117.00
    discount_amount_lyd: 10.00, // Voucher
    loyalty_points_discount_lyd: 5.00, // Points
    free_delivery_discount_lyd: 15.00, // Free delivery
    total_amount_lyd: 87.00, // 117 - (10 + 5 + 15) = 87.00 net COD billed
    delivered_at: new Date().toISOString()
  };
  isolatedDb.orders.push(promoOrder);

  await ledgerService.processOrderDelivery(isolatedDb, promoOrder);
  const tbPromoBefore = accountingEngine.getTrialBalance(isolatedDb);
  assert.strictEqual(tbPromoBefore.discrepancy_lyd, 0.0000, 'Pre-reversal trial balance must be 0.0000');
  assert.strictEqual(isolatedDb.drivers[0].cash_in_hand_lyd, 87.00, 'Driver must hold 87.00 net COD custody');

  await ledgerService.reverseOrderSettlement(isolatedDb, promoOrder);
  const tbPromoAfter = accountingEngine.getTrialBalance(isolatedDb);
  const promoReversalBalanced = tbPromoAfter.is_balanced && tbPromoAfter.discrepancy_lyd === 0.0000;
  const promoDriverCashZeroed = isolatedDb.drivers[0].cash_in_hand_lyd === 0.00;
  const promoAcc1040Zeroed = (tbPromoAfter.accounts.find(a => a.code === '1040')?.netBalance || 0) === 0.00;

  recordResult('SUITE 3', 'Complex Promo Cancellation: Account 1040 and driver custody strictly zeroed to 0.00 LYD', promoDriverCashZeroed && promoAcc1040Zeroed, {
    driverCash: isolatedDb.drivers[0].cash_in_hand_lyd,
    acc1040: tbPromoAfter.accounts.find(a => a.code === '1040')?.netBalance
  });
  recordResult('SUITE 3', 'Complex Promo Cancellation: Marketing discount reversal strictly preserves 0.0000 LYD trial balance', promoReversalBalanced, {
    discrepancy: tbPromoAfter.discrepancy_lyd
  });

  // --- 3.4 Rapid Randomized Multi-Order Accumulation & Cancellation Stress (20 Orders) ---
  console.log('  Testing 20 randomized orders delivery & reversal stress sequence...');
  const multiOrders = [];
  let multiSuccess = true;

  for (let i = 1; i <= 20; i++) {
    const isCod = i % 2 !== 0;
    const subtotal = Math.round((20 + Math.random() * 80) * 100) / 100;
    const delivery = 10.00;
    const discount = i % 3 === 0 ? 5.00 : 0.00;
    const total = Math.round((subtotal + delivery - discount) * 100) / 100;

    const ord = {
      id: `ord_random_stress_${i}`,
      order_number: `ORD-RND-${1000 + i}`,
      store_id: 'store_stress_01',
      driver_id: 'drv_stress_01',
      customer_id: 'usr_cust_stress_01',
      payment_method: isCod ? 'cash_on_delivery' : 'wallet',
      subtotal_lyd: subtotal,
      delivery_fee_lyd: delivery,
      discount_amount_lyd: discount,
      total_amount_lyd: total,
      delivered_at: new Date().toISOString()
    };
    multiOrders.push(ord);
    isolatedDb.orders.push(ord);

    await ledgerService.processOrderDelivery(isolatedDb, ord);
    const tbCheck = accountingEngine.getTrialBalance(isolatedDb);
    if (!tbCheck.is_balanced || tbCheck.discrepancy_lyd !== 0.0000) {
      multiSuccess = false;
      console.error(`Discrepancy at delivery step ${i}:`, tbCheck.discrepancy_lyd);
      break;
    }
  }

  // Now reverse all 20 orders in reverse order
  for (let i = multiOrders.length - 1; i >= 0; i--) {
    const ord = multiOrders[i];
    await ledgerService.reverseOrderSettlement(isolatedDb, ord);
    const tbCheck = accountingEngine.getTrialBalance(isolatedDb);
    if (!tbCheck.is_balanced || tbCheck.discrepancy_lyd !== 0.0000) {
      multiSuccess = false;
      console.error(`Discrepancy at reversal step ${i}:`, tbCheck.discrepancy_lyd);
      break;
    }
  }

  const tbFinalMulti = accountingEngine.getTrialBalance(isolatedDb);
  const finalDriverCash = isolatedDb.drivers[0].cash_in_hand_lyd;
  const finalDriverCod = isolatedDb.drivers[0].cod_balance_lyd;
  const finalAcc1040 = tbFinalMulti.accounts.find(a => a.code === '1040')?.netBalance || 0;

  recordResult(
    'SUITE 3',
    'Rapid Multi-Order Stress: 20 sequential delivered orders reversed with strict 0.0000 LYD imbalance at every step',
    multiSuccess && tbFinalMulti.is_balanced && tbFinalMulti.discrepancy_lyd === 0.0000,
    { discrepancy: tbFinalMulti.discrepancy_lyd }
  );
  recordResult(
    'SUITE 3',
    'Rapid Multi-Order Stress: final driver custody & Account 1040 strictly 0.00 LYD',
    finalDriverCash === 0.00 && finalDriverCod === 0.00 && finalAcc1040 === 0.00,
    { finalDriverCash, finalDriverCod, finalAcc1040 }
  );

  // ==========================================================================
  // SUITE 4: Selective Admin Orders Purge Security & Catalog Non-Destruction
  // ==========================================================================
  console.log('\n--- SUITE 4: Selective Admin Orders Purge Security & Catalog Non-Destruction ---');

  // 4.1 Security & Auth Rejections
  const resNoAuth = await httpRequest('POST', '/api/v1/admin/orders/purge', { pin: '7788' });
  recordResult('SUITE 4', 'Purge without Authorization header returns HTTP 401', resNoAuth.status === 401);

  const resCustAuth = await httpRequest('POST', '/api/v1/admin/orders/purge', { pin: '7788' }, {
    Authorization: `Bearer ${customerToken}`
  });
  recordResult('SUITE 4', 'Purge with non-admin customer token returns HTTP 403 Forbidden', resCustAuth.status === 403);

  const resInvalidPin = await httpRequest('POST', '/api/v1/admin/orders/purge', { pin: '9999' }, {
    Authorization: `Bearer ${adminToken}`
  });
  recordResult('SUITE 4', 'Purge with wrong security PIN returns HTTP 401 with error message', resInvalidPin.status === 401 && resInvalidPin.body.error.includes('PIN'), resInvalidPin.body);

  // 4.2 Seed live memory with disposable test orders, driver liabilities, and locked balances
  db.orders.push({
    id: 'ord_temp_purge_01',
    order_number: 'ORD-TEMP-01',
    status: 'placed',
    total_amount_lyd: 45.00
  });
  if (db.drivers && db.drivers[0]) {
    db.drivers[0].active_order_id = 'ord_temp_purge_01';
    db.drivers[0].cash_in_hand_lyd = 88.00;
    db.drivers[0].cod_balance_lyd = 88.00;
    db.drivers[0].status = 'busy_delivery';
    db.drivers[0].is_active = true;
  }
  if (db.wallets && db.wallets[0]) {
    db.wallets[0].locked_balance = 30.00;
  }

  // 4.3 Execute Admin Purge with valid PIN
  const resPurgeSuccess = await httpRequest('POST', '/api/v1/admin/orders/purge', { pin: '7788' }, {
    Authorization: `Bearer ${adminToken}`
  });
  recordResult('SUITE 4', 'Purge with Admin token & PIN 7788 returns HTTP 200 success', resPurgeSuccess.status === 200 && resPurgeSuccess.body.success === true, resPurgeSuccess.body);

  // 4.4 Verify Zeroing of Orders & Liabilities in Memory
  const memOrdersZero = db.orders.length === 0;
  recordResult('SUITE 4', 'Post-Purge: db.orders array is strictly empty [] (0 orders)', memOrdersZero, { count: db.orders.length });

  let memDriversZero = true;
  for (const d of (db.drivers || [])) {
    if (d.active_order_id !== null || d.cod_balance_lyd !== 0.00 || d.cash_in_hand_lyd !== 0.00 || d.status !== 'offline' || d.is_active !== false) {
      memDriversZero = false;
    }
  }
  recordResult('SUITE 4', 'Post-Purge: all drivers active_order_id null, COD 0.00 LYD, status offline', memDriversZero);

  let memWalletsUnlocked = true;
  for (const w of (db.wallets || [])) {
    if (w.locked_balance !== 0.00) memWalletsUnlocked = false;
  }
  recordResult('SUITE 4', 'Post-Purge: all wallets locked_balance reset to 0.00 LYD', memWalletsUnlocked);

  // 4.5 CRITICAL: Verify Non-Destruction of Catalog (Stores, Products, Categories, Drivers)
  const storesPreserved = db.stores.length === 4;
  recordResult('SUITE 4', 'Post-Purge Catalog Preservation: 4 stores preserved in memory', storesPreserved, { count: db.stores.length });

  const productsPreserved = db.products.length === 52;
  recordResult('SUITE 4', 'Post-Purge Catalog Preservation: 52 products preserved in memory', productsPreserved, { count: db.products.length });

  const categoriesPreserved = db.categories.length === 6;
  recordResult('SUITE 4', 'Post-Purge Catalog Preservation: 6 categories preserved in memory', categoriesPreserved, { count: db.categories.length });

  const driversPreserved = db.drivers.length === 2;
  recordResult('SUITE 4', 'Post-Purge Catalog Preservation: 2 drivers preserved in memory', driversPreserved, { count: db.drivers.length });

  // 4.6 Verify seed_data.json on disk was updated properly and catalog preserved
  const diskSeedAfter = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
  const diskOrdersZero = diskSeedAfter.orders.length === 0;
  const diskStoresOk = diskSeedAfter.stores.length === 4;
  const diskProductsOk = diskSeedAfter.products.length === 52;
  const diskCategoriesOk = diskSeedAfter.categories.length === 6;
  const diskDriversOk = diskSeedAfter.drivers.length === 2;
  recordResult(
    'SUITE 4',
    'Post-Purge Disk Preservation: seed_data.json on disk has 0 orders, 4 stores, 52 products, 6 categories, 2 drivers',
    diskOrdersZero && diskStoresOk && diskProductsOk && diskCategoriesOk && diskDriversOk,
    { orders: diskSeedAfter.orders.length, stores: diskSeedAfter.stores.length, products: diskSeedAfter.products.length, drivers: diskSeedAfter.drivers.length }
  );

  // ==========================================================================
  // SUITE 5: Admin FSM Override & RBAC Penetration Testing
  // ==========================================================================
  console.log('\n--- SUITE 5: Admin FSM Override & RBAC Penetration Testing ---');

  // 5.1 Non-Admin FSM Enforcement
  const tNonAdminSkip = orderService.validateTransition('placed', 'ready_for_pickup', { isAdmin: false });
  recordResult('SUITE 5', 'Non-admin cannot skip lifecycle phases (placed -> ready_for_pickup)', tNonAdminSkip.valid === false);

  const tNonAdminBackward = orderService.validateTransition('ready_for_pickup', 'preparing', { isAdmin: false });
  recordResult('SUITE 5', 'Non-admin cannot transition backward (ready_for_pickup -> preparing)', tNonAdminBackward.valid === false);

  const tNonAdminCancelDelivered = orderService.validateTransition('delivered', 'cancelled', { isAdmin: false });
  recordResult('SUITE 5', 'Non-admin cannot cancel a delivered order (delivered -> cancelled)', tNonAdminCancelDelivered.valid === false);

  const tNonAdminCancelInFlight = orderService.validateTransition('out_for_delivery', 'cancelled', { isAdmin: false });
  recordResult('SUITE 5', 'Non-admin cannot cancel in-flight delivery (out_for_delivery -> cancelled)', tNonAdminCancelInFlight.valid === false);

  // 5.2 Admin Override Permitted Transitions
  const tAdminSkip = orderService.validateTransition('placed', 'ready_for_pickup', { adminOverride: true, isAdmin: true });
  recordResult('SUITE 5', 'Admin override permits jumping to ready_for_pickup', tAdminSkip.valid === true);

  const tAdminBackward = orderService.validateTransition('ready_for_pickup', 'preparing', { adminOverride: true, isAdmin: true });
  recordResult('SUITE 5', 'Admin override permits moving backwards to preparing', tAdminBackward.valid === true);

  const tAdminCancelDelivered = orderService.validateTransition('delivered', 'cancelled', { adminOverride: true, isAdmin: true });
  recordResult('SUITE 5', 'Admin override permits cancelling a delivered order', tAdminCancelDelivered.valid === true && tAdminCancelDelivered.isCancellation === true);

  const tAdminForceDelivered = orderService.validateTransition('placed', 'delivered', { adminOverride: true, isAdmin: true });
  recordResult('SUITE 5', 'Admin override permits jumping placed directly to delivered', tAdminForceDelivered.valid === true);

  // 5.3 Admin Reassignment Route Security
  const resReassignNoAuth = await httpRequest('POST', '/api/v1/orders/ord_dummy/reassign', { driver_id: 'driver_nalut_02' });
  recordResult('SUITE 5', 'Reassign driver without token returns HTTP 401', resReassignNoAuth.status === 401);

  const resReassignCust = await httpRequest('POST', '/api/v1/orders/ord_dummy/reassign', { driver_id: 'driver_nalut_02' }, {
    Authorization: `Bearer ${customerToken}`
  });
  recordResult('SUITE 5', 'Reassign driver with customer token returns HTTP 403 Forbidden', resReassignCust.status === 403);

  // 5.4 Admin Single Order Delete Route Security
  const resDeleteNoAuth = await httpRequest('DELETE', '/api/v1/admin/orders/ord_dummy');
  recordResult('SUITE 5', 'Delete single order without token returns HTTP 401', resDeleteNoAuth.status === 401);

  const resDeleteCust = await httpRequest('DELETE', '/api/v1/admin/orders/ord_dummy', null, {
    Authorization: `Bearer ${customerToken}`
  });
  recordResult('SUITE 5', 'Delete single order with customer token returns HTTP 403 Forbidden', resDeleteCust.status === 403);

  // 5.5 Cancellation Route Idempotency
  db.orders.push({
    id: 'ord_idempotent_test_99',
    order_number: 'ORD-IDEM-99',
    status: 'cancelled',
    payment_method: 'cash_on_delivery',
    total_amount_lyd: 50.00
  });

  const resCancelAgain = await httpRequest('POST', '/api/v1/orders/ord_idempotent_test_99/cancel', {
    reason: 'إلغاء ثان مكرر',
    adminOverride: true
  }, {
    Authorization: `Bearer ${adminToken}`
  });
  const cancelIdempotent = resCancelAgain.status === 200 && resCancelAgain.body.message.includes('ملغى مسبقاً');
  recordResult('SUITE 5', 'Cancellation route idempotency: re-cancelling already cancelled order returns harmless idempotent message', cancelIdempotent, resCancelAgain.body);

  // Clean up test order
  db.orders = db.orders.filter(o => o.id !== 'ord_idempotent_test_99');

  // 5.6 Admin Driver Reassignment Flow
  db.orders.push({
    id: 'ord_reassign_test_01',
    order_number: 'ORD-REASSIGN-01',
    status: 'out_for_delivery',
    driver_id: 'driver_nalut_01',
    total_amount_lyd: 35.00
  });
  const drv1 = db.drivers.find(d => d.id === 'driver_nalut_01');
  const drv2 = db.drivers.find(d => d.id === 'driver_nalut_02');
  if (drv1) { drv1.status = 'busy_delivery'; drv1.active_order_id = 'ord_reassign_test_01'; }

  const resReassignOk = await httpRequest('POST', '/api/v1/orders/ord_reassign_test_01/reassign', {
    driver_id: 'driver_nalut_02'
  }, {
    Authorization: `Bearer ${adminToken}`
  });
  const reassignSuccess = resReassignOk.status === 200 &&
                          resReassignOk.body.success === true &&
                          drv1.active_order_id === null &&
                          drv1.status === 'available' &&
                          drv2.active_order_id === 'ord_reassign_test_01' &&
                          drv2.status === 'busy_delivery';
  recordResult('SUITE 5', 'Admin driver reassignment: releases previous driver (null/available) and binds new driver (busy_delivery)', reassignSuccess, {
    prevDriver: { active: drv1?.active_order_id, status: drv1?.status },
    newDriver: { active: drv2?.active_order_id, status: drv2?.status }
  });

  // 5.7 Admin Delete Single Order Flow
  const resDeleteOk = await httpRequest('DELETE', '/api/v1/admin/orders/ord_reassign_test_01', null, {
    Authorization: `Bearer ${adminToken}`
  });
  const orderStillExists = db.orders.some(o => o.id === 'ord_reassign_test_01');
  const deleteSuccess = resDeleteOk.status === 200 &&
                        resDeleteOk.body.success === true &&
                        !orderStillExists &&
                        drv2.active_order_id === null;
  recordResult('SUITE 5', 'Admin single order deletion: cascades to remove order and release driver binding', deleteSuccess, {
    deleted: !orderStillExists,
    driverActive: drv2?.active_order_id
  });

  // Reset driver states back to offline / null
  if (drv1) { drv1.status = 'offline'; drv1.active_order_id = null; }
  if (drv2) { drv2.status = 'offline'; drv2.active_order_id = null; }

  // ==========================================================================
  // FINAL VERDICT & SUMMARY
  // ==========================================================================
  console.log('\n================================================================');
  const totalTests = testResults.length;
  const passedTests = testResults.filter(t => t.passed).length;
  const failedTests = testResults.filter(t => !t.passed).length;

  console.log(`TOTAL ADVERSARIAL STRESS TESTS: ${totalTests}`);
  console.log(`PASSED: ${passedTests}`);
  console.log(`FAILED: ${failedTests}`);

  if (failedTests > 0) {
    console.error('\n❌ CHALLENGE FAILED: BUGS DETECTED IN WORKER IMPLEMENTATION');
    process.exit(1);
  } else {
    console.log('\n🎉 ALL ADVERSARIAL STRESS CHALLENGES PASSED EMPIRICALLY!');
    console.log('VERDICT: APPROVE');
    console.log('================================================================');
    process.exit(0);
  }
}

runAdversarialM12Suite().catch(err => {
  console.error('Fatal crash during adversarial suite execution:', err);
  process.exit(1);
});
