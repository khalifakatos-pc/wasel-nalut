/**
 * ============================================================================
 * WASEL NALUT UNIFIED ACCOUNTING & GENERAL LEDGER ENGINE (COA & DOUBLE-ENTRY)
 *
 * Implements standard financial accounting with a 5-class Chart of Accounts:
 * 1000 - Assets (الأصول)
 * 2000 - Liabilities (الخصوم والالتزامات)
 * 3000 - Equity (حقوق الملكية)
 * 4000 - Revenue (الإيرادات)
 * 5000 - Expenses (المصروفات)
 *
 * Guarantees mathematical equality: Sum(Debits) == Sum(Credits) with 0.00 discrepancy.
 * ============================================================================
 */

const { v4: uuidv4 } = require('uuid');

// 1. STANDARD CHART OF ACCOUNTS (دليل وشجرة الحسابات المعتمدة)
const CHART_OF_ACCOUNTS = {
  // 1000: ASSETS (الأصول)
  '1010': { code: '1010', nameAr: 'الخزينة والصندوق الرئيسي', nameEn: 'Main Cash Vault', category: 'ASSET', normalBalance: 'DEBIT' },
  '1021': { code: '1021', nameAr: 'مصرف الجمهورية - الحساب الجاري', nameEn: 'Jumhouria Bank Checking', category: 'ASSET', normalBalance: 'DEBIT' },
  '1022': { code: '1022', nameAr: 'مصرف شمال أفريقيا - الحساب الجاري', nameEn: 'North Africa Bank Checking', category: 'ASSET', normalBalance: 'DEBIT' },
  '1031': { code: '1031', nameAr: 'وسيط تسوية سداد (Sadad Clearing)', nameEn: 'Sadad Clearing Account', category: 'ASSET', normalBalance: 'DEBIT' },
  '1032': { code: '1032', nameAr: 'وسيط تسوية لي باي (LyPay Clearing)', nameEn: 'LyPay Clearing Account', category: 'ASSET', normalBalance: 'DEBIT' },
  '1033': { code: '1033', nameAr: 'وسيط تسوية البطاقات المصرفية', nameEn: 'Bank Cards Clearing Account', category: 'ASSET', normalBalance: 'DEBIT' },
  '1040': { code: '1040', nameAr: 'عهد الكباتن النقدية المعلقة (COD Receivable)', nameEn: 'Driver Cash-in-Hand Custody', category: 'ASSET', normalBalance: 'DEBIT' },

  // 2000: LIABILITIES (الخصوم والالتزامات)
  '2010': { code: '2010', nameAr: 'أمانات الضمان المعلق للطلبات (Escrow)', nameEn: 'Platform Order Escrow Pool', category: 'LIABILITY', normalBalance: 'CREDIT' },
  '2020': { code: '2020', nameAr: 'مستحقات وأمانات المطاعم والمتاجر', nameEn: 'Merchants & Kitchens Payable', category: 'LIABILITY', normalBalance: 'CREDIT' },
  '2030': { code: '2030', nameAr: 'صافي أرباح الكباتن المستحقة للصرف', nameEn: 'Drivers Net Earnings Payable', category: 'LIABILITY', normalBalance: 'CREDIT' },
  '2040': { code: '2040', nameAr: 'أرصدة محافظ الزبائن المودعة', nameEn: 'Customer Prepaid Wallets', category: 'LIABILITY', normalBalance: 'CREDIT' },
  '2050': { code: '2050', nameAr: 'مخصص التزامات نقاط المكافآت والولاء', nameEn: 'Loyalty Points Liability', category: 'LIABILITY', normalBalance: 'CREDIT' },

  // 3000: EQUITY (حقوق الملكية)
  '3010': { code: '3010', nameAr: 'رأس مال المنصة المصرح به', nameEn: 'Platform Capital', category: 'EQUITY', normalBalance: 'CREDIT' },
  '3020': { code: '3020', nameAr: 'الأرباح المحتجزة / المتراكمة', nameEn: 'Retained Earnings', category: 'EQUITY', normalBalance: 'CREDIT' },

  // 4000: REVENUES (الإيرادات)
  '4010': { code: '4010', nameAr: 'إيرادات عمولات المتاجر والمطاعم (10-15%)', nameEn: 'Merchant Commission Revenue', category: 'REVENUE', normalBalance: 'CREDIT' },
  '4020': { code: '4020', nameAr: 'حصة المنصة من رسوم التوصيل (20%)', nameEn: 'Platform Delivery Revenue Share', category: 'REVENUE', normalBalance: 'CREDIT' },
  '4030': { code: '4030', nameAr: 'رسوم الخدمات التشغيلية والتقنية', nameEn: 'Platform Service Fee Revenue', category: 'REVENUE', normalBalance: 'CREDIT' },

  // 5000: EXPENSES (المصروفات)
  '5010': { code: '5010', nameAr: 'مصروفات الخصومات الترويجية وكوبونات واصل', nameEn: 'Promotional & Coupon Discounts', category: 'EXPENSE', normalBalance: 'DEBIT' },
  '5020': { code: '5020', nameAr: 'مصروفات حوافز ومكافآت نقاط الولاء', nameEn: 'Loyalty Rewards Redemptions', category: 'EXPENSE', normalBalance: 'DEBIT' },
  '5030': { code: '5030', nameAr: 'مصروفات دعم التوصيل المجاني', nameEn: 'Free Delivery Subsidy Expense', category: 'EXPENSE', normalBalance: 'DEBIT' },
  '5040': { code: '5040', nameAr: 'عمولات بوابات الدفع الإلكتروني المصرفية', nameEn: 'Payment Gateway Fee Expenses', category: 'EXPENSE', normalBalance: 'DEBIT' },
  '5050': { code: '5050', nameAr: 'مصروفات إلغاءات وتعويضات التشغيل', nameEn: 'Order Cancellation Loss & Compensation', category: 'EXPENSE', normalBalance: 'DEBIT' }
};

class AccountingEngine {
  constructor() {
    this.CHART_OF_ACCOUNTS = CHART_OF_ACCOUNTS;
  }

  round(num) {
    return Math.round((Number(num) || 0) * 100) / 100;
  }

  /**
   * Initializes the accounting structures in db object if not present.
   */
  ensureAccountingTables(db) {
    if (!db.journal_entries) db.journal_entries = [];
    if (!db.journal_entry_lines) db.journal_entry_lines = [];
  }

  /**
   * Records a balanced double-entry Journal Entry with audit verification.
   *
   * @param {Object} db - In-memory DB
   * @param {Object} params
   * @param {string} [params.entryNumber]
   * @param {string} params.referenceId - Order ID, Voucher ID, or Transaction ID
   * @param {string} params.transactionType - 'order_settlement' | 'cod_vault_deposit' | 'merchant_payout' | 'driver_payout' | 'wallet_topup' | 'adjustment'
   * @param {string} params.narration - Official Arabic accounting description
   * @param {Array<{accountCode: string, debit: number, credit: number, entityType?: string, entityId?: string, note?: string}>} params.lines
   * @param {Object} [params.pgPool] - Optional PostgreSQL pool
   * @returns {Object} Created journal entry with lines and verification status
   */
  async recordJournalEntry(db, { entryNumber, referenceId, transactionType, narration, lines, pgPool = null }) {
    this.ensureAccountingTables(db);

    if (!Array.isArray(lines) || lines.length < 2) {
      throw new Error('A valid journal entry requires at least two lines (one debit and one credit).');
    }

    let totalDebit = 0;
    let totalCredit = 0;
    const validatedLines = [];

    const seq = db.journal_entries.length + 1;
    const currentYear = new Date().getFullYear();
    const finalEntryNumber = entryNumber || `JRN-${currentYear}-${String(seq).padStart(5, '0')}`;
    const entryId = `jrn_${uuidv4().substring(0, 8)}`;
    const createdAt = new Date().toISOString();

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const account = CHART_OF_ACCOUNTS[line.accountCode];
      if (!account) {
        throw new Error(`Invalid account code: ${line.accountCode}. Must belong to Chart of Accounts.`);
      }

      const debit = this.round(line.debit || 0);
      const credit = this.round(line.credit || 0);

      if (debit > 0 && credit > 0) {
        throw new Error(`Line ${i + 1} cannot have both debit and credit amounts.`);
      }
      if (debit === 0 && credit === 0) {
        continue; // Skip zero line
      }

      totalDebit += debit;
      totalCredit += credit;

      const lineObj = {
        id: `line_${entryId}_${i + 1}`,
        journal_entry_id: entryId,
        entry_number: finalEntryNumber,
        line_number: i + 1,
        account_code: line.accountCode,
        account_name_ar: account.nameAr,
        account_category: account.category,
        debit: debit,
        credit: credit,
        entity_type: line.entityType || null, // 'driver' | 'store' | 'customer' | 'bank' | 'platform'
        entity_id: line.entityId || null,
        note: line.note || narration,
        created_at: createdAt
      };

      validatedLines.push(lineObj);
    }

    totalDebit = this.round(totalDebit);
    totalCredit = this.round(totalCredit);
    const discrepancy = this.round(Math.abs(totalDebit - totalCredit));

    if (discrepancy > 0.001) {
      throw new Error(`Double-entry balance check failed! Total Debits (${totalDebit} LYD) != Total Credits (${totalCredit} LYD). Discrepancy: ${discrepancy} LYD`);
    }

    const entryObj = {
      id: entryId,
      entry_number: finalEntryNumber,
      reference_id: referenceId,
      transaction_type: transactionType,
      narration: narration,
      total_debit: totalDebit,
      total_credit: totalCredit,
      discrepancy: 0.00,
      is_balanced: true,
      lines_count: validatedLines.length,
      lines: validatedLines,
      created_at: createdAt
    };

    // Commit in-memory
    db.journal_entries.unshift(entryObj);
    db.journal_entry_lines.push(...validatedLines);

    // Commit to PostgreSQL if pool or client is available
    if (pgPool && typeof pgPool.query === 'function') {
      try {
        await pgPool.query(
          `INSERT INTO journal_entries 
            (id, entry_number, reference_id, transaction_type, narration, total_debit, total_credit, discrepancy, is_balanced, lines_count, created_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
           ON CONFLICT (id) DO NOTHING`,
          [
            entryObj.id,
            entryObj.entry_number,
            entryObj.reference_id,
            entryObj.transaction_type,
            entryObj.narration,
            entryObj.total_debit,
            entryObj.total_credit,
            entryObj.discrepancy || 0.00,
            true,
            entryObj.lines_count,
            entryObj.created_at
          ]
        );

        for (const l of validatedLines) {
          await pgPool.query(
            `INSERT INTO journal_entry_lines
              (id, journal_entry_id, entry_number, line_number, account_code, account_name_ar, account_category, debit, credit, entity_type, entity_id, note, created_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
             ON CONFLICT (id) DO NOTHING`,
            [
              l.id,
              l.journal_entry_id,
              l.entry_number,
              l.line_number,
              l.account_code,
              l.account_name_ar || null,
              l.account_category || null,
              l.debit,
              l.credit,
              l.entity_type || null,
              l.entity_id || null,
              l.note || null,
              l.created_at
            ]
          );
        }
      } catch (err) {
        console.warn(`[AccountingEngine] Note: PG journal persistence: ${err.message}`);
      }
    }

    return entryObj;
  }

  /**
   * Generates a Trial Balance (ميزان المراجعة بالأرصدة والمجاميع)
   * Verifies that total debits equal total credits across the entire system.
   */
  getTrialBalance(db) {
    this.ensureAccountingTables(db);

    const accountsMap = {};
    for (const [code, info] of Object.entries(CHART_OF_ACCOUNTS)) {
      accountsMap[code] = {
        code: code,
        nameAr: info.nameAr,
        nameEn: info.nameEn,
        category: info.category,
        normalBalance: info.normalBalance,
        totalDebit: 0.00,
        totalCredit: 0.00,
        netBalance: 0.00,
        entriesCount: 0
      };
    }

    // Aggregate from all journal lines
    for (const line of db.journal_entry_lines) {
      if (accountsMap[line.account_code]) {
        accountsMap[line.account_code].totalDebit += (line.debit || 0);
        accountsMap[line.account_code].totalCredit += (line.credit || 0);
        accountsMap[line.account_code].entriesCount += 1;
      }
    }

    let grandTotalDebit = 0.00;
    let grandTotalCredit = 0.00;

    const accountsList = Object.values(accountsMap).map((acc) => {
      acc.totalDebit = this.round(acc.totalDebit);
      acc.totalCredit = this.round(acc.totalCredit);
      grandTotalDebit += acc.totalDebit;
      grandTotalCredit += acc.totalCredit;

      // Net balance calculation according to normal balance
      if (acc.normalBalance === 'DEBIT') {
        acc.netBalance = this.round(acc.totalDebit - acc.totalCredit);
      } else {
        acc.netBalance = this.round(acc.totalCredit - acc.totalDebit);
      }
      return acc;
    });

    grandTotalDebit = this.round(grandTotalDebit);
    grandTotalCredit = this.round(grandTotalCredit);
    const discrepancy = this.round(Math.abs(grandTotalDebit - grandTotalCredit));

    return {
      success: true,
      as_of: new Date().toISOString(),
      is_balanced: discrepancy === 0.00,
      grand_total_debit: grandTotalDebit,
      grand_total_credit: grandTotalCredit,
      discrepancy_lyd: discrepancy,
      accounts: accountsList
    };
  }

  /**
   * Generates the General Ledger feed with optional account filter and pagination.
   */
  getGeneralLedger(db, { accountCode = null, limit = 50, page = 1 } = {}) {
    this.ensureAccountingTables(db);

    let entries = db.journal_entries;
    if (accountCode) {
      entries = entries.filter((e) =>
        e.lines && e.lines.some((l) => l.account_code === accountCode)
      );
    }

    const total = entries.length;
    const startIndex = (page - 1) * limit;
    const paginated = entries.slice(startIndex, startIndex + limit);

    return {
      success: true,
      total_entries: total,
      page: page,
      limit: limit,
      total_pages: Math.ceil(total / limit) || 1,
      entries: paginated
    };
  }

  /**
   * Generates an official daily Z-Audit report computed strictly from posted Journal Entries.
   * Completely eliminates floating estimates like `totalOrders * 5.0`!
   */
  getDailyZReport(db, dateStr = null) {
    this.ensureAccountingTables(db);

    const targetDate = dateStr || new Date().toISOString().split('T')[0];

    // Filter journal lines for the target date
    const dayLines = db.journal_entry_lines.filter((l) => {
      const lineDate = (l.created_at || '').split('T')[0];
      return lineDate === targetDate;
    });

    // 1. Gross GMV: All customer payments and COD receivables (1040, 1031, 1032, 1021 debited for orders)
    let grossGmv = 0.00;
    // 2. Platform Revenue: Credits on 4010 (commission), 4020 (delivery share), 4030 (service fee)
    let platformCommission = 0.00;
    let platformDeliveryShare = 0.00;
    let platformServiceFee = 0.00;
    // 3. Merchants Payouts: Credits on 2020 (Merchants Payable)
    let merchantsShare = 0.00;
    // 4. Drivers Payouts: Credits on 2030 (Drivers Net Earnings)
    let driversEarnings = 0.00;
    // 5. Cash In Custody (COD): Net change in 1040
    let codDebits = 0.00;
    let codCredits = 0.00;
    // 6. Cash Collected to Vault: Debits on 1010
    let cashCollectedToVault = 0.00;
    // 7. Marketing Discounts absorbed: Debits on 5010, 5020, 5030
    let marketingDiscountsAbsorbed = 0.00;

    for (const line of dayLines) {
      const code = line.account_code;
      const debit = line.debit || 0;
      const credit = line.credit || 0;

      if (code === '1040') {
        codDebits += debit;
        codCredits += credit;
      }
      if (code === '1010') {
        cashCollectedToVault += debit;
      }
      if (code === '2020') {
        merchantsShare += credit;
      }
      if (code === '2030') {
        driversEarnings += credit;
      }
      if (code === '4010') {
        platformCommission += credit;
      }
      if (code === '4020') {
        platformDeliveryShare += credit;
      }
      if (code === '4030') {
        platformServiceFee += credit;
      }
      if (['5010', '5020', '5030'].includes(code)) {
        marketingDiscountsAbsorbed += debit;
      }
    }

    grossGmv = this.round(merchantsShare + driversEarnings + platformCommission + platformDeliveryShare + platformServiceFee);
    const platformTotalRevenue = this.round(platformCommission + platformDeliveryShare + platformServiceFee);
    const netCodPendingToday = this.round(codDebits - codCredits);

    // Total active liability across all drivers in the system
    let totalDriverCashLiability = 0.00;
    if (Array.isArray(db.drivers)) {
      totalDriverCashLiability = db.drivers.reduce((sum, d) =>
        sum + (parseFloat(d.cash_in_hand_lyd !== undefined ? d.cash_in_hand_lyd : (d.cod_balance_lyd || 0)) || 0), 0);
    }
    totalDriverCashLiability = this.round(totalDriverCashLiability);

    // Completed orders count today
    const completedOrdersToday = (db.orders || []).filter((o) =>
      o.status === 'delivered' && (o.delivered_at || o.created_at || '').startsWith(targetDate)
    ).length;

    return {
      success: true,
      audit_date: targetDate,
      is_closed: false,
      audit_code: `Z-AUDIT-${targetDate.replace(/-/g, '')}`,
      total_orders: completedOrdersToday,
      total_gmv_lyd: grossGmv,
      platform_revenue_lyd: platformTotalRevenue,
      merchants_payout_lyd: this.round(merchantsShare),
      drivers_payout_lyd: this.round(driversEarnings), // EXACT ledger earnings, no fake * 5.0!
      cash_collected_lyd: this.round(cashCollectedToVault),
      cash_pending_lyd: totalDriverCashLiability,
      marketing_discounts_lyd: this.round(marketingDiscountsAbsorbed),
      accounting_breakdown: {
        merchant_commission_4010: this.round(platformCommission),
        delivery_margin_4020: this.round(platformDeliveryShare),
        service_fees_4030: this.round(platformServiceFee),
        merchants_payable_2020: this.round(merchantsShare),
        drivers_payable_2030: this.round(driversEarnings),
        vault_deposits_1010: this.round(cashCollectedToVault),
        daily_cod_collected_1040: this.round(codDebits),
        daily_cod_cleared_1040: this.round(codCredits)
      }
    };
  }

  /**
   * Generates a partner statement (store or driver) derived from General Ledger lines.
   */
  getPartnerStatement(db, { entityType, entityId }) {
    this.ensureAccountingTables(db);

    const relevantLines = db.journal_entry_lines.filter((l) =>
      l.entity_id === entityId || (l.entity_type === entityType && l.entity_id === entityId)
    );

    let grossSalesOrServices = 0.00;
    let platformCommission = 0.00;
    let netEarned = 0.00;
    let totalDisbursed = 0.00;

    for (const l of relevantLines) {
      if (entityType === 'store') {
        // Merchant subledger
        if (l.account_code === '2020') {
          netEarned += (l.credit || 0); // Earned
          totalDisbursed += (l.debit || 0); // Withdrawn/Disbursed
        }
      } else if (entityType === 'driver') {
        // Driver subledger
        if (l.account_code === '2030') {
          netEarned += (l.credit || 0);
          totalDisbursed += (l.debit || 0);
        }
      }
    }

    netEarned = this.round(netEarned);
    totalDisbursed = this.round(totalDisbursed);
    const netRemainingPayable = this.round(netEarned - totalDisbursed);

    return {
      success: true,
      entity_type: entityType,
      entity_id: entityId,
      gross_sales_lyd: this.round(netEarned + platformCommission),
      platform_commission_lyd: platformCommission,
      net_earned_lyd: netEarned,
      total_disbursed_lyd: totalDisbursed,
      net_payable_remaining_lyd: Math.max(0, netRemainingPayable),
      transaction_lines: relevantLines
    };
  }
}

module.exports = new AccountingEngine();
