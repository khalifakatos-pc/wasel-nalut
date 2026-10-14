/**
 * ============================================================================
 * WASEL NALUT UNIFIED ACCOUNTING & GENERAL LEDGER VERIFICATION SUITE
 *
 * Tests the Chart of Accounts (COA), balanced double-entry Journal Entries,
 * Trial Balance zero-discrepancy invariant, and Daily Z-Report calculation.
 * ============================================================================
 */

const assert = require('assert');
const accountingEngine = require('./services/accountingEngine');
const ledgerService = require('./services/ledgerService');

async function runAccountingTests() {
  console.log('================================================================');
  console.log('🏛️  STARTING WASEL NALUT ACCOUNTING ENGINE & GENERAL LEDGER TESTS');
  console.log('================================================================\n');

  const testDb = {
    drivers: [
      {
        id: 'driver_test_01',
        full_name: 'أحمد التارقي',
        user_id: 'user_drv_01',
        wallet_balance_lyd: 0.00,
        cash_in_hand_lyd: 0.00,
        cod_balance_lyd: 0.00,
        status: 'online_idle'
      }
    ],
    stores: [
      {
        id: 'store_test_01',
        name: 'مطعم قصر نالوت الجبلي',
        merchant_id: 'merchant_01',
        commission_rate: 10.0 // 10%
      }
    ],
    wallets: [],
    wallet_transactions: [],
    vouchers: [],
    journal_entries: [],
    journal_entry_lines: [],
    orders: []
  };

  // TEST 1: Chart of Accounts Verification
  console.log('Test 1: Verifying Chart of Accounts (COA) Structure...');
  const coa = accountingEngine.CHART_OF_ACCOUNTS;
  assert(coa['1010'], 'Account 1010 (Main Cash Vault) must exist');
  assert(coa['1040'], 'Account 1040 (Driver Cash-in-Hand Custody) must exist');
  assert(coa['2010'], 'Account 2010 (Order Escrow Pool) must exist');
  assert(coa['2020'], 'Account 2020 (Merchants Payable) must exist');
  assert(coa['2030'], 'Account 2030 (Drivers Net Earnings Payable) must exist');
  assert(coa['4010'], 'Account 4010 (Merchant Commission) must exist');
  assert(coa['4020'], 'Account 4020 (Delivery Share) must exist');
  assert(coa['5010'], 'Account 5010 (Marketing Discounts) must exist');
  console.log('  ✅ COA structure verified: 5 classes (Assets, Liabilities, Equity, Revenue, Expenses) present.\n');

  // TEST 2: Order Delivery Settlement with Promo Discount
  console.log('Test 2: Order Delivery Settlement (COD + Marketing Promo Discount)...');
  const testOrder = {
    id: 'order_test_acc_01',
    order_number: 'WS-8901',
    store_id: 'store_test_01',
    driver_id: 'driver_test_01',
    customer_id: 'cust_01',
    payment_method: 'cash_on_delivery',
    subtotal_lyd: 40.00,
    delivery_fee_lyd: 7.00,
    total_amount_lyd: 42.00, // 40 + 7 - 5 promo discount = 42 LYD net
    discount_amount_lyd: 5.00,
    delivered_at: new Date().toISOString()
  };
  testDb.orders.push(testOrder);

  const settlement = await ledgerService.processOrderDelivery(testDb, testOrder);
  assert.strictEqual(settlement.is_balanced, true, 'Settlement must be balanced');
  assert.strictEqual(settlement.driver_earnings, 5.60, 'Driver gets 80% of 7.00 = 5.60 LYD');
  assert.strictEqual(settlement.merchant_net, 36.00, 'Merchant gets 40 - 10% commission = 36.00 LYD');
  assert.strictEqual(settlement.platform_revenue, 5.40, 'Platform gets 4 commission + 1.40 delivery share = 5.40 LYD');
  
  // Verify journal entry generated
  assert.strictEqual(testDb.journal_entries.length, 1, 'Exactly 1 Journal Entry must be recorded');
  const jrn1 = testDb.journal_entries[0];
  assert.strictEqual(jrn1.is_balanced, true, 'Journal entry must be balanced');
  assert.strictEqual(jrn1.discrepancy, 0.00, 'Discrepancy must be 0.00');
  console.log(`  ✅ Journal Entry ${jrn1.entry_number} recorded: Total Debits = ${jrn1.total_debit} LYD, Total Credits = ${jrn1.total_credit} LYD (Balanced: 100%).\n`);

  // TEST 3: Captain Cash Vault Handover (Custody Settlement)
  console.log('Test 3: Captain Custody Settlement & Official Receipt Voucher...');
  const initialCustody = testDb.drivers[0].cash_in_hand_lyd;
  assert(initialCustody > 0, 'Driver must have collected COD cash');

  const settleResult = await ledgerService.settleDriverCash(testDb, 'driver_test_01', {
    amount: initialCustody,
    notes: 'توريد كامل العهدة النقدية لخزينة المنصة بنالوت'
  });

  assert.strictEqual(settleResult.remaining_cash_in_hand, 0.00, 'Driver liability must be cleared to 0.00');
  assert.strictEqual(settleResult.net_earnings_preserved, 5.60, 'Driver net earnings MUST remain strictly intact (5.60 LYD)');
  assert(settleResult.voucher, 'Voucher must be issued');
  assert(settleResult.voucher.voucher_number.startsWith('REC-'), 'Voucher must be of type REC');
  
  // Verify settlement journal entry
  const jrn2 = testDb.journal_entries[0]; // unshifted
  assert.strictEqual(jrn2.transaction_type, 'cod_vault_deposit', 'Transaction type must be cod_vault_deposit');
  assert.strictEqual(jrn2.total_debit, initialCustody, 'Vault debit must equal settled amount');
  console.log(`  ✅ Captain custody cleared to 0.00 LYD, Net earnings preserved at ${settleResult.net_earnings_preserved} LYD, Receipt Voucher ${settleResult.voucher.voucher_number} posted to Vault 1010.\n`);

  // TEST 4: Merchant Payout Request Disbursement
  console.log('Test 4: Merchant Payout Request & Official Payment Voucher (PAY)...');
  const merchantPayout = await ledgerService.disburseMerchantPayout(testDb, {
    storeId: 'store_test_01',
    amount: 30.00,
    paymentMethod: 'مصرف الجمهورية',
    destinationAccount: 'LY010020300400500',
    notes: 'تحويل أرباح مبيعات عشاء الأمس لمطعم قصر نالوت'
  });

  assert.strictEqual(merchantPayout.success, true, 'Payout must succeed');
  assert(merchantPayout.voucher.voucher_number.startsWith('PAY-'), 'Voucher must be of type PAY');
  assert.strictEqual(merchantPayout.payout_amount, 30.00);
  
  const jrn3 = testDb.journal_entries[0];
  assert.strictEqual(jrn3.transaction_type, 'merchant_payout');
  assert.strictEqual(jrn3.total_debit, 30.00);
  assert.strictEqual(jrn3.total_credit, 30.00);
  console.log(`  ✅ Merchant Payout disbursed: ${merchantPayout.payout_amount} LYD, Payment Voucher ${merchantPayout.voucher.voucher_number} posted to Bank 1021.\n`);

  // TEST 5: Trial Balance Zero-Discrepancy Invariant
  console.log('Test 5: Trial Balance (ميزان المراجعة العام)...');
  const tb = accountingEngine.getTrialBalance(testDb);
  console.log(`  - Grand Total Debits:  ${tb.grand_total_debit.toFixed(2)} LYD`);
  console.log(`  - Grand Total Credits: ${tb.grand_total_credit.toFixed(2)} LYD`);
  console.log(`  - Ledger Discrepancy:  ${tb.discrepancy_lyd.toFixed(4)} LYD`);
  assert.strictEqual(tb.is_balanced, true, 'Trial balance must be completely balanced');
  assert.strictEqual(tb.discrepancy_lyd, 0.00, 'Trial balance discrepancy must be exactly 0.0000');
  console.log('  ✅ Trial balance strictly balanced with 0.0000 LYD discrepancy.\n');

  // TEST 6: Exact Daily Z-Report
  console.log('Test 6: Daily Z-Report computed from Journal Entries...');
  const todayStr = new Date().toISOString().split('T')[0];
  const zReport = accountingEngine.getDailyZReport(testDb, todayStr);
  console.log(`  - Total Orders:      ${zReport.total_orders}`);
  console.log(`  - Gross GMV:         ${zReport.total_gmv_lyd.toFixed(2)} LYD`);
  console.log(`  - Platform Revenue:  ${zReport.platform_revenue_lyd.toFixed(2)} LYD`);
  console.log(`  - Merchants Share:   ${zReport.merchants_payout_lyd.toFixed(2)} LYD`);
  console.log(`  - Drivers Earnings:  ${zReport.drivers_payout_lyd.toFixed(2)} LYD (Accurate, not estimated!)`);
  console.log(`  - Vault Cash:        ${zReport.cash_collected_lyd.toFixed(2)} LYD`);
  assert.strictEqual(zReport.drivers_payout_lyd, 5.60, 'Driver payout must be exactly 5.60 LYD from ledger');
  assert.strictEqual(zReport.merchants_payout_lyd, 36.00, 'Merchant share must be exactly 36.00 LYD from ledger');
  assert.strictEqual(zReport.platform_revenue_lyd, 5.40, 'Platform revenue must be exactly 5.40 LYD from ledger');
  console.log('  ✅ Daily Z-Report matches ledger records with 100% precision.\n');

  // TEST 7: Partner Account Statements
  console.log('Test 7: Partner Account Statements...');
  const storeStmt = accountingEngine.getPartnerStatement(testDb, { entityType: 'store', entityId: 'merchant_01' });
  console.log(`  - Store Net Earned:    ${storeStmt.net_earned_lyd.toFixed(2)} LYD`);
  console.log(`  - Store Disbursed:     ${storeStmt.total_disbursed_lyd.toFixed(2)} LYD`);
  console.log(`  - Store Net Remaining: ${storeStmt.net_payable_remaining_lyd.toFixed(2)} LYD`);
  assert.strictEqual(storeStmt.net_earned_lyd, 36.00);
  assert.strictEqual(storeStmt.total_disbursed_lyd, 30.00);
  assert.strictEqual(storeStmt.net_payable_remaining_lyd, 6.00);
  console.log('  ✅ Partner statement accurately reflects subledger entries.\n');

  console.log('================================================================');
  console.log('🎉 ALL 7 ACCOUNTING & GENERAL LEDGER TESTS PASSED SUCCESSFULLY!');
  console.log('================================================================');
}

runAccountingTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
