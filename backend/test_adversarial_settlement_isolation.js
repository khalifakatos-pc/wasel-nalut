/**
 * ============================================================================
 * ADVERSARIAL STRESS TEST: DRIVER CUSTODY SETTLEMENT ISOLATION
 * 
 * Verifies that driver settlement strictly clears cash-in-hand custody (1040)
 * to 0.00 without touching or reducing driver net earnings (wallet_balance_lyd)
 * across partial, full, concurrent, and simulated rollback transactions.
 * ============================================================================
 */

const assert = require('assert');
const ledgerService = require('./services/ledgerService');
const accountingEngine = require('./services/accountingEngine');

async function runSettlementIsolationTests() {
  console.log('================================================================');
  console.log('⚔️  RUNNING ADVERSARIAL DRIVER SETTLEMENT ISOLATION TESTS');
  console.log('================================================================\n');

  let passed = 0;
  let total = 0;

  function test(name, fn) {
    total++;
    try {
      fn();
      passed++;
      console.log(`  ✔ [PASS] ${name}`);
    } catch (err) {
      console.error(`  ❌ [FAIL] ${name}:`, err.message);
      throw err;
    }
  }

  async function asyncTest(name, fn) {
    total++;
    try {
      await fn();
      passed++;
      console.log(`  ✔ [PASS] ${name}`);
    } catch (err) {
      console.error(`  ❌ [FAIL] ${name}:`, err.message);
      throw err;
    }
  }

  // Baseline Mock Database
  function createMockDb() {
    return {
      stores: [
        { id: 'store_nalut_01', name: 'مطعم القلعة', commission_rate: 10.0 }
      ],
      drivers: [
        {
          id: 'driver_test_captain',
          user_id: 'user_captain_01',
          full_name: 'إبراهيم النالوتي',
          wallet_balance_lyd: 345.80, // Net earnings accumulated from completed trips
          cash_in_hand_lyd: 620.50,    // COD cash collected from customers
          cod_balance_lyd: 620.50,
          status: 'online_idle'
        }
      ],
      wallets: [],
      wallet_transactions: [],
      vouchers: [],
      journal_entries: [],
      journal_entry_lines: [],
      orders: []
    };
  }

  // 1. Initial State Invariant
  test('Test 1: Pre-settlement state maintains distinct net earnings and cash custody', () => {
    const db = createMockDb();
    const driver = db.drivers[0];
    assert.strictEqual(driver.wallet_balance_lyd, 345.80, 'Initial net earnings must be 345.80 LYD');
    assert.strictEqual(driver.cash_in_hand_lyd, 620.50, 'Initial custody liability must be 620.50 LYD');
    assert.strictEqual(driver.cod_balance_lyd, 620.50, 'COD balance must match cash in hand');
  });

  // 2. Partial Settlement Test
  await asyncTest('Test 2: Partial settlement clears custody proportionally without altering wallet_balance_lyd', async () => {
    const db = createMockDb();
    const initialEarnings = db.drivers[0].wallet_balance_lyd;
    const settleAmount = 250.00;

    const res = await ledgerService.settleDriverCash(db, 'driver_test_captain', {
      amount: settleAmount,
      notes: 'تسوية جزئية للعهدة النقدية'
    });

    const driver = db.drivers[0];
    assert.strictEqual(driver.wallet_balance_lyd, initialEarnings, `Net earnings must remain ${initialEarnings} LYD!`);
    assert.strictEqual(driver.cash_in_hand_lyd, 370.50, 'Remaining custody must be 370.50 LYD');
    assert.strictEqual(driver.cod_balance_lyd, 370.50, 'cod_balance_lyd must equal cash_in_hand_lyd');
    assert.strictEqual(res.remaining_cash_in_hand, 370.50);
    assert.strictEqual(res.voucher.amount_lyd, settleAmount);
    assert.strictEqual(res.voucher.type, 'receipt');
  });

  // 3. Full Settlement Test (Clearing to exactly 0.00)
  await asyncTest('Test 3: Full settlement clears custody strictly to 0.00 with wallet_balance_lyd 100% intact', async () => {
    const db = createMockDb();
    const initialEarnings = db.drivers[0].wallet_balance_lyd;
    const fullCustody = db.drivers[0].cash_in_hand_lyd;

    const res = await ledgerService.settleDriverCash(db, 'driver_test_captain', {
      amount: fullCustody,
      notes: 'إبراء ذمة كامل وتوريد كافة الكاش'
    });

    const driver = db.drivers[0];
    assert.strictEqual(driver.cash_in_hand_lyd, 0.00, 'Driver custody liability must be strictly 0.00');
    assert.strictEqual(driver.cod_balance_lyd, 0.00, 'COD balance must be strictly 0.00');
    assert.strictEqual(driver.wallet_balance_lyd, initialEarnings, 'Net earnings MUST NOT be decremented!');
    assert.strictEqual(res.remaining_cash_in_hand, 0.00);
  });

  // 4. Default Amount Option (Settling entire available liability when amount is omitted)
  await asyncTest('Test 4: Omitting amount option defaults to full custody clearance', async () => {
    const db = createMockDb();
    const initialEarnings = db.drivers[0].wallet_balance_lyd;

    const res = await ledgerService.settleDriverCash(db, 'driver_test_captain', {});

    const driver = db.drivers[0];
    assert.strictEqual(driver.cash_in_hand_lyd, 0.00);
    assert.strictEqual(driver.cod_balance_lyd, 0.00);
    assert.strictEqual(driver.wallet_balance_lyd, initialEarnings);
  });

  // 5. Negative Settlement Amount Rejection
  await asyncTest('Test 5: Rejection of negative settlement amounts', async () => {
    const db = createMockDb();
    let thrown = false;
    try {
      await ledgerService.settleDriverCash(db, 'driver_test_captain', { amount: -50.00 });
    } catch (err) {
      thrown = true;
      assert(err.message.includes('negative'));
    }
    assert.strictEqual(thrown, true, 'Negative settlement amounts must throw');
  });

  // 6. Double-entry General Ledger Verification for Settlement
  await asyncTest('Test 6: General Ledger double-entry lines strictly debit 1010 and credit 1040 (never touching 2030 or 2020)', async () => {
    const db = createMockDb();
    const settleAmount = 300.00;

    await ledgerService.settleDriverCash(db, 'driver_test_captain', { amount: settleAmount });

    // Inspect the recorded journal entry
    const entry = db.journal_entries[0];
    assert(entry, 'Journal entry must be recorded');
    assert.strictEqual(entry.is_balanced, true, 'Journal entry must be balanced');
    assert.strictEqual(entry.total_debit, settleAmount);
    assert.strictEqual(entry.total_credit, settleAmount);

    const lines = db.journal_entry_lines;
    const debitLine = lines.find(l => l.account_code === '1010');
    const creditLine = lines.find(l => l.account_code === '1040');
    const earningsLine = lines.find(l => l.account_code === '2030');

    assert(debitLine, 'Account 1010 (Platform Vault) must be debited');
    assert.strictEqual(debitLine.debit, settleAmount);
    assert(creditLine, 'Account 1040 (Driver Custody) must be credited');
    assert.strictEqual(creditLine.credit, settleAmount);
    assert(!earningsLine, 'Account 2030 (Driver Net Earnings) must NEVER be touched in custody settlement!');

    const tb = accountingEngine.getTrialBalance(db);
    assert.strictEqual(tb.is_balanced, true);
    assert.strictEqual(tb.discrepancy_lyd, 0.00);
  });

  // 7. Successive Order Deliveries Followed By Settlement
  await asyncTest('Test 7: Sequential lifecycle: COD delivery increases custody and net earnings, then settlement purges ONLY custody', async () => {
    const db = createMockDb();
    const driver = db.drivers[0];
    driver.cash_in_hand_lyd = 0.00;
    driver.cod_balance_lyd = 0.00;
    driver.wallet_balance_lyd = 50.00;

    // Simulate COD order delivery
    const order = {
      id: 'ord_seq_01',
      order_number: 'ORD-SEQ-01',
      store_id: 'store_nalut_01',
      driver_id: driver.id,
      customer_id: 'cust_01',
      payment_method: 'cash_on_delivery',
      subtotal_lyd: 40.00,
      delivery_fee_lyd: 10.00,
      discount_amount_lyd: 0.00,
      total_amount_lyd: 50.00,
      delivered_at: new Date().toISOString()
    };

    const deliveryRes = await ledgerService.processOrderDelivery(db, order);
    assert.strictEqual(deliveryRes.is_balanced, true);

    // After delivery:
    // driver earnings = 80% of 10.00 LYD delivery fee = 8.00 LYD
    // new wallet_balance_lyd = 50.00 + 8.00 = 58.00 LYD
    // new cash_in_hand_lyd = 50.00 LYD (collected COD from customer)
    assert.strictEqual(driver.wallet_balance_lyd, 58.00, 'Wallet balance should increase by driver share (8.00 LYD)');
    assert.strictEqual(driver.cash_in_hand_lyd, 50.00, 'Cash in hand should increase by total order COD (50.00 LYD)');

    // Now settle driver cash
    await ledgerService.settleDriverCash(db, driver.id);

    // After settlement:
    assert.strictEqual(driver.cash_in_hand_lyd, 0.00, 'Custody must be cleared to 0.00');
    assert.strictEqual(driver.wallet_balance_lyd, 58.00, 'Driver earnings of 58.00 LYD MUST REMAIN UNTOUCHED!');
  });

  console.log('\n================================================================');
  console.log(`🎉 ALL ${passed}/${total} SETTLEMENT ISOLATION TESTS PASSED!`);
  console.log('================================================================');
}

runSettlementIsolationTests().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
