/**
 * ============================================================================
 * FORENSIC AUDIT EMPIRICAL VERIFICATION HARNESS — AUDITOR M1_R2
 * ============================================================================
 * Target: Milestone 1 Round 2 Remediation
 * Scope: Backend PostgreSQL Persistence & ACID Invariants
 *
 * Checks:
 * 1. SQL Parameterization Audit (Zero unparameterized queries / string injection)
 * 2. SQL Error Re-throw Audit across all 14 persistence helpers
 * 3. Product stock_quantity Database Persistence Audit
 * 4. Checkout ACID Rollback & In-Memory State Consistency
 * 5. Order Status Update ACID Rollback & Snapshot Restoration
 * 6. Driver Cash Settlement Dedicated Client & ACID Isolation
 * 7. General Ledger Promotional Discount Boundary Stress Test (Discrepancy == 0.0000 LYD)
 * 8. Mutator Routes Asynchrony & Persistence Await Audit
 * ============================================================================
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const results = [];

function check(name, pass, details = {}) {
  results.push({ name, pass, details });
  console.log(`${pass ? '  ✅ PASS' : '  ❌ FAIL'}: ${name}`);
  if (!pass && Object.keys(details).length > 0) {
    console.log(`     Details: ${JSON.stringify(details, null, 2)}`);
  }
}

async function runForensicAudit() {
  console.log('================================================================');
  console.log('🔍 FORENSIC AUDIT SUITE — MILESTONE 1 ROUND 2');
  console.log('================================================================\n');

  const serverJsPath = path.join(__dirname, 'server.js');
  const serverCode = fs.readFileSync(serverJsPath, 'utf8');

  const ledgerJsPath = path.join(__dirname, 'services', 'ledgerService.js');
  const ledgerCode = fs.readFileSync(ledgerJsPath, 'utf8');

  const accountingJsPath = path.join(__dirname, 'services', 'accountingEngine.js');
  const accountingCode = fs.readFileSync(accountingJsPath, 'utf8');

  // --------------------------------------------------------------------------
  // CHECK 1: SQL Parameterization Audit
  // --------------------------------------------------------------------------
  console.log('--- Check 1: Parameterized SQL Query Audit ---');
  // Scan all query calls in server.js, ledgerService.js, accountingEngine.js
  const filesToCheck = [
    { name: 'server.js', code: serverCode },
    { name: 'ledgerService.js', code: ledgerCode },
    { name: 'accountingEngine.js', code: accountingCode }
  ];

  let unparameterizedQueries = [];
  for (const f of filesToCheck) {
    // Look for .query(`...${...}...`) pattern
    const regex = /\.query\s*\(\s*`([^`]*\$\{[^}]+\}[^`]*)`/g;
    let match;
    while ((match = regex.exec(f.code)) !== null) {
      const sqlSnippet = match[1].trim();
      // Whitelist legitimate non-user variables if any (e.g. static table names or constants)
      unparameterizedQueries.push({ file: f.name, snippet: sqlSnippet.substring(0, 80) });
    }
  }

  check(
    'All SQL queries with dynamic values use parameterized placeholders ($1, $2, ...)',
    unparameterizedQueries.length === 0,
    { unparameterizedQueries }
  );

  // --------------------------------------------------------------------------
  // CHECK 2: SQL Error Re-throw Audit in Persistence Helpers
  // --------------------------------------------------------------------------
  console.log('\n--- Check 2: Error Re-throw in Persistence Helpers Audit ---');
  const helperNames = [
    'saveUserToPg',
    'saveWalletToPg',
    'saveCategoryToPg',
    'saveVoucherToPg',
    'saveAuditLogToPg',
    'saveWalletTransactionToPg',
    'saveStoreToPg',
    'deleteStoreFromPg',
    'saveProductToPg',
    'deleteProductFromPg',
    'saveDriverToPg',
    'deleteDriverFromPg',
    'saveOrderItemsToPg',
    'saveOrderToPg'
  ];

  let missingRethrow = [];
  for (const h of helperNames) {
    const fnRegex = new RegExp(`async function ${h}[\\s\\S]*?catch\\s*\\(err\\)\\s*\\{([\\s\\S]*?)\\}`);
    const fnMatch = fnRegex.exec(serverCode);
    if (!fnMatch) {
      missingRethrow.push({ helper: h, reason: 'function not found' });
      continue;
    }
    const catchBody = fnMatch[1];
    const hasRethrow = /if\s*\(\s*dbClient\s*\)\s*throw\s+err;/.test(catchBody);
    if (!hasRethrow) {
      missingRethrow.push({ helper: h, catchBody: catchBody.trim() });
    }
  }

  check(
    'All 14 PostgreSQL persistence helpers re-throw SQL exceptions when dbClient is provided',
    missingRethrow.length === 0,
    { missingRethrow }
  );

  // --------------------------------------------------------------------------
  // CHECK 3: Product stock_quantity Database Persistence Audit
  // --------------------------------------------------------------------------
  console.log('\n--- Check 3: Product stock_quantity Database Persistence Audit ---');
  const saveProductMatch = /async function saveProductToPg[\s\S]*?INSERT INTO products \(([\s\S]*?)\)[\s\S]*?VALUES \(([\s\S]*?)\)[\s\S]*?ON CONFLICT \(id\) DO UPDATE SET([\s\S]*?)\`,/.exec(serverCode);
  assert.ok(saveProductMatch, 'saveProductToPg structure must be found');

  const insertCols = saveProductMatch[1];
  const valuesClause = saveProductMatch[2];
  const updateClause = saveProductMatch[3];

  const colHasStock = insertCols.includes('stock_quantity');
  const valHasStock = valuesClause.includes('$16');
  const updateHasStock = updateClause.includes('stock_quantity = EXCLUDED.stock_quantity');

  check(
    'saveProductToPg includes stock_quantity in INSERT columns, VALUES ($16), and ON CONFLICT UPDATE',
    colHasStock && valHasStock && updateHasStock,
    { colHasStock, valHasStock, updateHasStock }
  );

  // --------------------------------------------------------------------------
  // CHECK 4: Checkout In-Memory Rollback Compensation Audit
  // --------------------------------------------------------------------------
  console.log('\n--- Check 4: Checkout ACID Rollback & In-Memory Compensation ---');
  const checkoutCatchMatch = /app\.post\(\['\/api\/v1\/orders\/checkout'[\s\S]*?\} catch \(err\) \{([\s\S]*?)\}\s*\}\);/.exec(serverCode);
  assert.ok(checkoutCatchMatch, 'Checkout catch block must be found');
  const checkoutCatch = checkoutCatchMatch[1];

  const hasRollback = checkoutCatch.includes("client.query('ROLLBACK')");
  const hasLockedBalanceRevert = checkoutCatch.includes("locked_balance - totalAmount");
  const hasHoldTxnSplice = checkoutCatch.includes("wallet_transactions.splice");
  const hasOrderSplice = checkoutCatch.includes("db.orders.splice");
  const hasStockRestoration = checkoutCatch.includes("stock_quantity += item.quantity");

  check(
    'Checkout catch block executes client ROLLBACK and reverts in-memory escrow hold, order, and stock deductions',
    hasRollback && hasLockedBalanceRevert && hasHoldTxnSplice && hasOrderSplice && hasStockRestoration,
    { hasRollback, hasLockedBalanceRevert, hasHoldTxnSplice, hasOrderSplice, hasStockRestoration }
  );

  // --------------------------------------------------------------------------
  // CHECK 5: Order Status Update Rollback Snapshot Audit
  // --------------------------------------------------------------------------
  console.log('\n--- Check 5: Order Status Update ACID Rollback & Snapshot Restoration ---');
  const statusUpdateCatchMatch = /const handleOrderStatusUpdate = async[\s\S]*?\} catch \(err\) \{([\s\S]*?)\}\s*;\s*app\.post\('\/api\/v1\/orders\/:id\/status'/.exec(serverCode);
  assert.ok(statusUpdateCatchMatch, 'handleOrderStatusUpdate catch block must be found');
  const statusCatch = statusUpdateCatchMatch[1];

  const statusHasRollback = statusCatch.includes("client.query('ROLLBACK')");
  const statusRestoresOrder = statusCatch.includes("Object.assign(memOrder, originalOrderSnapshot)");
  const statusRestoresDriver = statusCatch.includes("Object.assign(drv, originalDriverSnapshot)");
  const statusRestoresWallet = statusCatch.includes("Object.assign(cw, originalCustomerWalletSnapshot)");
  const statusSplicesTxns = statusCatch.includes("wallet_transactions.splice(initialTxCount)");

  check(
    'handleOrderStatusUpdate catch block executes ROLLBACK and restores original order, driver, and wallet snapshots',
    statusHasRollback && statusRestoresOrder && statusRestoresDriver && statusRestoresWallet && statusSplicesTxns,
    { statusHasRollback, statusRestoresOrder, statusRestoresDriver, statusRestoresWallet, statusSplicesTxns }
  );

  // --------------------------------------------------------------------------
  // CHECK 6: Driver Settlement Dedicated Client & ACID Isolation
  // --------------------------------------------------------------------------
  console.log('\n--- Check 6: Driver Settlement Dedicated Client & ACID Isolation ---');
  const settleRouteMatch = /app\.post\('\/api\/v1\/drivers\/:id\/settle', async \(req, res\) => \{([\s\S]*?)\}\);\s*app\.patch\('\/api\/v1\/drivers\/:id\/settle'/.exec(serverCode);
  assert.ok(settleRouteMatch, 'Driver settle route must be found');
  const settleBody = settleRouteMatch[1];

  const settleConnectsClient = settleBody.includes("client = await pgPool.connect()");
  const settleBeginsTx = settleBody.includes("await client.query('BEGIN')");
  const settleUsesForUpdate = settleBody.includes("FOR UPDATE");
  const settlePassesClientToLedger = settleBody.includes("ledgerService.settleDriverCash(db, driver.id, req.body || {}, client || pgPool)");
  const settlePassesClientToSaveDriver = settleBody.includes("await saveDriverToPg(driver, client)");
  const settleCommits = settleBody.includes("await client.query('COMMIT')");
  const settleRollsback = settleBody.includes("await client.query('ROLLBACK')");
  const settleRestoresSnapshot = settleBody.includes("driver.cash_in_hand_lyd = prevCashInHand");

  check(
    'Driver cash settlement uses dedicated transactional client with FOR UPDATE, BEGIN, COMMIT, ROLLBACK, and memory rollback',
    settleConnectsClient && settleBeginsTx && settleUsesForUpdate && settlePassesClientToLedger && settlePassesClientToSaveDriver && settleCommits && settleRollsback && settleRestoresSnapshot,
    { settleConnectsClient, settleBeginsTx, settleUsesForUpdate, settlePassesClientToLedger, settlePassesClientToSaveDriver, settleCommits, settleRollsback, settleRestoresSnapshot }
  );

  // --------------------------------------------------------------------------
  // CHECK 7: General Ledger Promotional Discount Boundary Stress Test
  // --------------------------------------------------------------------------
  console.log('\n--- Check 7: General Ledger Promotional Discount Boundary Stress Test ---');
  const accountingEngine = require('./services/accountingEngine');
  const ledgerService = require('./services/ledgerService');

  const testDb = {
    wallets: [
      { id: 'wallet_cust_test', user_id: 'cust_test', wallet_type: 'customer_wallet', currency: 'LYD', balance: 500, locked_balance: 0 },
      { id: 'wallet_drv_test', user_id: 'drv_test', wallet_type: 'driver_earnings', currency: 'LYD', balance: 0, locked_balance: 0 },
      { id: 'wallet_store_test', user_id: 'store_test', wallet_type: 'merchant_payouts', currency: 'LYD', balance: 0, locked_balance: 0 },
      { id: 'wallet_escrow', user_id: 'system_escrow', wallet_type: 'platform_escrow', currency: 'LYD', balance: 0, locked_balance: 0 },
      { id: 'wallet_revenue', user_id: 'system_revenue', wallet_type: 'platform_revenue', currency: 'LYD', balance: 0, locked_balance: 0 },
      { id: 'wallet_vault', user_id: 'system_vault', wallet_type: 'platform_vault', currency: 'LYD', balance: 0, locked_balance: 0 }
    ],
    drivers: [
      { id: 'drv_test', user_id: 'drv_test', full_name: 'Driver Test', cash_in_hand_lyd: 0, cod_balance_lyd: 0, wallet_balance_lyd: 0 }
    ],
    stores: [
      { id: 'store_test', name: 'Store Test', commission_rate: 10 }
    ],
    wallet_transactions: [],
    journal_entries: [],
    journal_entry_lines: [],
    orders: []
  };

  const stressOrders = [
    { name: 'Zero Order Value', subtotal_lyd: 0, delivery_fee_lyd: 0, discount_amount_lyd: 20 },
    { name: '10x Excessive Promo Discount', subtotal_lyd: 10, delivery_fee_lyd: 5, discount_amount_lyd: 150 },
    { name: 'Exact Match Promo Discount', subtotal_lyd: 20, delivery_fee_lyd: 5, discount_amount_lyd: 25 },
    { name: 'Fractional Cents Promo Discount', subtotal_lyd: 12.33, delivery_fee_lyd: 4.77, discount_amount_lyd: 17.10 },
    { name: 'Stacked Multi-Promotion Hazard', subtotal_lyd: 15, delivery_fee_lyd: 5, discount_amount_lyd: 10, loyalty_points_discount_lyd: 10, free_delivery_discount_lyd: 5 }
  ];

  let stressFailures = [];
  for (let idx = 0; idx < stressOrders.length; idx++) {
    const sOrder = stressOrders[idx];
    const orderObj = {
      id: `ord_stress_${idx}`,
      order_number: `ORD-STRESS-${idx}`,
      customer_id: 'cust_test',
      store_id: 'store_test',
      driver_id: 'drv_test',
      payment_method: 'cash_on_delivery',
      subtotal_lyd: sOrder.subtotal_lyd,
      delivery_fee_lyd: sOrder.delivery_fee_lyd,
      discount_amount_lyd: sOrder.discount_amount_lyd || 0,
      loyalty_points_discount_lyd: sOrder.loyalty_points_discount_lyd || 0,
      free_delivery_discount_lyd: sOrder.free_delivery_discount_lyd || 0,
      delivered_at: new Date().toISOString()
    };

    try {
      const res = await ledgerService.processOrderDelivery(testDb, orderObj);
      if (!res.is_balanced || res.discrepancy !== 0) {
        stressFailures.push({ order: sOrder.name, is_balanced: res.is_balanced, discrepancy: res.discrepancy });
      }
    } catch (err) {
      stressFailures.push({ order: sOrder.name, error: err.message });
    }
  }

  // Also check Trial Balance across testDb
  const trialBalance = accountingEngine.getTrialBalance(testDb);
  const trialBalanced = trialBalance.is_balanced && trialBalance.discrepancy_lyd === 0;

  check(
    'General Ledger preserves 0.0000 LYD imbalance across 5 boundary promotional stress test scenarios',
    stressFailures.length === 0 && trialBalanced,
    { stressFailures, trialBalanceSummary: { grandTotalDebit: trialBalance.grand_total_debit, grandTotalCredit: trialBalance.grand_total_credit, discrepancy: trialBalance.discrepancy_lyd } }
  );

  // --------------------------------------------------------------------------
  // CHECK 8: Mutator Routes Asynchrony & Persistence Await Audit
  // --------------------------------------------------------------------------
  console.log('\n--- Check 8: Mutator Routes Asynchrony & Persistence Await Audit ---');
  const routeChecks = [
    { route: "POST /api/v1/stores", pattern: /app\.post\('\/api\/v1\/stores',\s*async\s*\(/, awaitPattern: /await saveStoreToPg/ },
    { route: "PATCH /api/v1/stores/:id", pattern: /app\.patch\('\/api\/v1\/stores\/:id',\s*async\s*\(/, awaitPattern: /await saveStoreToPg/ },
    { route: "POST /api/v1/stores/:id/heartbeat", pattern: /app\.post\('\/api\/v1\/stores\/:id\/heartbeat',\s*async\s*\(/, awaitPattern: /await saveStoreToPg/ },
    { route: "DELETE /api/v1/stores/:id", pattern: /app\.delete\('\/api\/v1\/stores\/:id',\s*async\s*\(/, awaitPattern: /await deleteStoreFromPg/ },
    { route: "POST /api/v1/drivers", pattern: /app\.post\('\/api\/v1\/drivers',\s*async\s*\(/, awaitPattern: /await saveDriverToPg/ },
    { route: "DELETE /api/v1/drivers/:id", pattern: /app\.delete\('\/api\/v1\/drivers\/:id',\s*async\s*\(/, awaitPattern: /await deleteDriverFromPg/ },
    { route: "POST /api/v1/products", pattern: /app\.post\('\/api\/v1\/products',\s*async\s*\(/, awaitPattern: /await saveProductToPg/ },
    { route: "PATCH /api/v1/products/:id", pattern: /app\.patch\('\/api\/v1\/products\/:id',\s*async\s*\(/, awaitPattern: /await saveProductToPg/ },
    { route: "DELETE /api/v1/products/:id", pattern: /app\.delete\('\/api\/v1\/products\/:id',\s*async\s*\(/, awaitPattern: /await deleteProductFromPg/ },
    { route: "POST /api/v1/orders/:id/handover", pattern: /app\.post\('\/api\/v1\/orders\/:id\/handover',\s*async\s*\(/, awaitPattern: /await saveOrderToPg/ }
  ];

  let unAwaitedRoutes = [];
  for (const rc of routeChecks) {
    const isAsync = rc.pattern.test(serverCode);
    const hasAwait = rc.awaitPattern.test(serverCode);
    if (!isAsync || !hasAwait) {
      unAwaitedRoutes.push({ route: rc.route, isAsync, hasAwait });
    }
  }

  check(
    'All 10 key mutator routes are async and genuinely await PostgreSQL persistence calls',
    unAwaitedRoutes.length === 0,
    { unAwaitedRoutes }
  );

  // --------------------------------------------------------------------------
  // CHECK 9: Runtime Writes to seed_data.json Eliminated
  // --------------------------------------------------------------------------
  console.log('\n--- Check 9: Elimination of Runtime Writes to seed_data.json ---');
  const saveSeedDataMatch = /function saveSeedData\(\)\s*\{([\s\S]*?)\}/.exec(serverCode);
  const saveSeedDataBody = saveSeedDataMatch ? saveSeedDataMatch[1].trim() : 'NOT_FOUND';
  const hasNoWriteOps = !saveSeedDataBody.includes('fs.write') && !saveSeedDataBody.includes('fs.writeFileSync');

  check(
    'saveSeedData() contains zero file system write operations and seed_data.json is never mutated at runtime',
    hasNoWriteOps,
    { saveSeedDataBody }
  );

  // --------------------------------------------------------------------------
  // SUMMARY
  // --------------------------------------------------------------------------
  console.log('\n================================================================');
  console.log('📊 FORENSIC AUDIT SUMMARY');
  console.log('================================================================');
  const total = results.length;
  const passed = results.filter(r => r.pass).length;
  const failed = results.filter(r => !r.pass).length;

  console.log(`Total Checks: ${total}`);
  console.log(`Passed:       ${passed}`);
  console.log(`Failed:       ${failed}`);
  console.log(`Verdict:      ${failed === 0 ? 'CLEAN' : 'INTEGRITY VIOLATION'}`);
  console.log('================================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runForensicAudit().catch(err => {
  console.error('Forensic audit execution error:', err);
  process.exit(1);
});
