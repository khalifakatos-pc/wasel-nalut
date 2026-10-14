/**
 * ============================================================================
 * WASEL NALUT DOUBLE-ENTRY FINANCIAL LEDGER & COD SETTLEMENT SERVICE (R2)
 *
 * Implements strict double-entry bookkeeping with 0.00 LYD discrepancy.
 * Decouples Driver Net Earnings (wallet_balance_lyd) from Driver Cash-in-Hand
 * Custody Liability (cash_in_hand_lyd / cod_balance_lyd).
 * ============================================================================
 */

const { v4: uuidv4 } = require('uuid');
const accountingEngine = require('./accountingEngine');

const SYSTEM_WALLETS = {
  ESCROW: '00000000-0000-0000-0000-000000000001',
  REVENUE: '00000000-0000-0000-0000-000000000002',
  VAULT: '00000000-0000-0000-0000-000000000003'
};

class LedgerService {
  constructor() {
    this.SYSTEM_WALLETS = SYSTEM_WALLETS;
  }

  /**
   * Helper to round monetary amounts to 2 decimal places.
   */
  round(amount) {
    return Math.round((Number(amount) || 0) * 100) / 100;
  }

  /**
   * Processes double-entry financial settlement when an order transitions to 'delivered'.
   *
   * @param {Object} db In-memory database cache
   * @param {Object} order The delivered order object
   * @param {Object} [pgPool] Optional PostgreSQL connection pool
   * @returns {Object} Settlement summary with transactions and verification status
   */
  async processOrderDelivery(db, order, pgPool = null) {
    if (!order) throw new Error('Order is required for delivery financial settlement');

    if (!db.wallet_transactions) db.wallet_transactions = [];
    if (!db.wallets) db.wallets = [];

    const deliveryFee = this.round(order.delivery_fee_lyd || 0);
    const subtotal = this.round(order.subtotal_lyd || (order.total_amount_lyd - deliveryFee) || 0);
    const discountLyd = this.round(order.discount_amount_lyd || 0);
    const pointsDiscountLyd = this.round(order.loyalty_points_discount_lyd || 0);
    const freeDeliveryDiscountLyd = this.round(order.free_delivery_discount_lyd || 0);
    const totalPromotions = this.round(discountLyd + pointsDiscountLyd + freeDeliveryDiscountLyd);

    const grossOrderValue = this.round(subtotal + deliveryFee + (order.service_fee_lyd || 0));
    let customerBilledAmount = this.round(order.total_amount_lyd !== undefined ? order.total_amount_lyd : (grossOrderValue - totalPromotions));
    // If order.total_amount_lyd was passed as gross, reduce it by promotions:
    if (Math.abs(customerBilledAmount - grossOrderValue) < 0.01 && totalPromotions > 0) {
      customerBilledAmount = this.round(grossOrderValue - totalPromotions);
    }

    const isCod = ['cash_on_delivery', 'cash', 'cod'].includes(String(order.payment_method || '').toLowerCase());

    // 1. Commission Calculation
    const store = db.stores ? db.stores.find(s => s.id === order.store_id) : null;
    const commissionPct = (store && store.commission_rate !== undefined)
      ? Number(store.commission_rate) / 100
      : 0.10; // Default 10%

    const commissionLyd = this.round(subtotal * commissionPct);
    const merchantNet = this.round(subtotal - commissionLyd);

    // 2. Driver Net Earnings (80% of delivery fee)
    const driverEarnings = this.round(deliveryFee * 0.80);

    // 3. Platform Revenue (20% of delivery fee + store commission + service fee)
    const platformDeliveryShare = this.round(deliveryFee * 0.20);
    const serviceFee = this.round(order.service_fee_lyd || 0);
    const platformRevenue = this.round(platformDeliveryShare + commissionLyd + serviceFee);

    // Mathematical balance assertion check:
    // Total Debits = Customer Payment (Cash or Bank) + Marketing/Loyalty Discounts Absorbed by Platform
    // Total Credits = Merchant Net + Driver Earnings + Platform Revenue
    const totalDebits = this.round(customerBilledAmount + totalPromotions);
    const totalCredits = this.round(merchantNet + driverEarnings + platformRevenue);
    const discrepancy = this.round(Math.abs(totalDebits - totalCredits));

    if (discrepancy > 0.01) {
      console.warn(`[Ledger] Warning: Order ${order.id} imbalance detected: Debits=${totalDebits}, Credits=${totalCredits}, Discrepancy=${discrepancy}`);
    }

    // --- State Mutations ---

    // A. Driver Wallet & Liability Updates
    let driver = null;
    let driverWallet = null;
    if (order.driver_id && db.drivers) {
      driver = db.drivers.find(d => d.id === order.driver_id);
      if (driver) {
        // Driver Net Earnings: credit Driver's wallet_balance_lyd with exactly 80% of delivery fee
        driver.wallet_balance_lyd = this.round((driver.wallet_balance_lyd || 0) + driverEarnings);

        // Driver Cash Custody Liability: record customerBilledAmount as cash_in_hand_lyd if COD
        if (isCod) {
          driver.cash_in_hand_lyd = this.round((driver.cash_in_hand_lyd || 0) + customerBilledAmount);
          driver.cod_balance_lyd = this.round((driver.cod_balance_lyd || 0) + customerBilledAmount);
        }

        // Driver wallet record
        driverWallet = db.wallets.find(w => w.user_id === driver.user_id || w.id === `wallet_${driver.id}`);
        if (!driverWallet) {
          driverWallet = {
            id: `wallet_${driver.user_id || driver.id}`,
            user_id: driver.user_id || driver.id,
            wallet_type: 'driver_earnings',
            currency: 'LYD',
            balance: driver.wallet_balance_lyd,
            status: 'active'
          };
          db.wallets.push(driverWallet);
        } else {
          driverWallet.balance = this.round((driverWallet.balance || 0) + driverEarnings);
        }
      }
    }

    // B. Merchant Wallet Update
    let merchantWallet = null;
    const merchantId = store ? (store.merchant_id || store.owner_user_id || store.id) : order.store_id;
    if (merchantId) {
      merchantWallet = db.wallets.find(w => w.user_id === merchantId || w.id === `wallet_${merchantId}`);
      if (!merchantWallet) {
        merchantWallet = {
          id: `wallet_${merchantId}`,
          user_id: merchantId,
          wallet_type: 'merchant_payouts',
          currency: 'LYD',
          balance: merchantNet,
          status: 'active'
        };
        db.wallets.push(merchantWallet);
      } else {
        merchantWallet.balance = this.round((merchantWallet.balance || 0) + merchantNet);
      }
    }

    // C. Platform Revenue Wallet Update
    let revWallet = db.wallets.find(w => w.wallet_type === 'platform_revenue' || w.id === SYSTEM_WALLETS.REVENUE);
    if (!revWallet) {
      revWallet = {
        id: SYSTEM_WALLETS.REVENUE,
        user_id: null,
        wallet_type: 'platform_revenue',
        currency: 'LYD',
        balance: platformRevenue,
        status: 'active'
      };
      db.wallets.push(revWallet);
    } else {
      revWallet.balance = this.round((revWallet.balance || 0) + platformRevenue);
    }

    // D. Customer Wallet Escrow Release (if wallet payment)
    let customerWallet = null;
    if (!isCod && order.payment_method === 'wallet') {
      customerWallet = db.wallets.find(w => w.user_id === order.customer_id);
      if (customerWallet) {
        customerWallet.locked_balance = Math.max(0, this.round((customerWallet.locked_balance || 0) - totalAmount));
        customerWallet.balance = Math.max(0, this.round((customerWallet.balance || 0) - totalAmount));
      }
    }

    // --- Balanced Double-Entry Ledger Rows ---
    const nowIso = new Date().toISOString();
    const batchId = `batch_${order.id}_${Date.now()}`;
    const txRows = [];

    if (isCod) {
      // 1. Debit Driver Cash-in-Hand Liability
      txRows.push({
        id: `txn_${uuidv4().substring(0, 8)}`,
        batch_id: batchId,
        order_id: order.id,
        wallet_id: driverWallet ? driverWallet.id : `wallet_driver_${order.driver_id}`,
        entry_type: 'DEBIT',
        account_type: 'cash_in_hand',
        entity_type: 'driver',
        entity_id: order.driver_id,
        amount: customerBilledAmount,
        currency: 'LYD',
        status: 'completed',
        description: `استلام نقد من الزبون عند التوصيل (COD) لطلب رقم ${order.order_number || order.id}`,
        created_at: nowIso
      });
    } else {
      // 1. Debit Customer Escrow
      txRows.push({
        id: `txn_${uuidv4().substring(0, 8)}`,
        batch_id: batchId,
        order_id: order.id,
        wallet_id: customerWallet ? customerWallet.id : SYSTEM_WALLETS.ESCROW,
        entry_type: 'DEBIT',
        account_type: 'customer_escrow',
        entity_type: 'customer',
        entity_id: order.customer_id,
        amount: customerBilledAmount,
        currency: 'LYD',
        status: 'completed',
        description: `تسوية الضمان المالي المودع لطلب رقم ${order.order_number || order.id}`,
        created_at: nowIso
      });
    }

    if (discountLyd > 0) {
      txRows.push({
        id: `txn_${uuidv4().substring(0, 8)}`,
        batch_id: batchId,
        order_id: order.id,
        wallet_id: SYSTEM_WALLETS.REVENUE,
        entry_type: 'DEBIT',
        account_type: 'marketing_discount',
        entity_type: 'platform',
        entity_id: 'marketing',
        amount: discountLyd,
        currency: 'LYD',
        status: 'completed',
        description: `كوبون خصم ترويجي للمنصة لطلب رقم ${order.order_number || order.id}`,
        created_at: nowIso
      });
    }

    if (pointsDiscountLyd > 0) {
      txRows.push({
        id: `txn_${uuidv4().substring(0, 8)}`,
        batch_id: batchId,
        order_id: order.id,
        wallet_id: SYSTEM_WALLETS.REVENUE,
        entry_type: 'DEBIT',
        account_type: 'loyalty_redemption',
        entity_type: 'customer',
        entity_id: order.customer_id,
        amount: pointsDiscountLyd,
        currency: 'LYD',
        status: 'completed',
        description: `خصم استبدال نقاط ولاء لطلب رقم ${order.order_number || order.id}`,
        created_at: nowIso
      });
    }

    if (freeDeliveryDiscountLyd > 0) {
      txRows.push({
        id: `txn_${uuidv4().substring(0, 8)}`,
        batch_id: batchId,
        order_id: order.id,
        wallet_id: SYSTEM_WALLETS.REVENUE,
        entry_type: 'DEBIT',
        account_type: 'free_delivery_subsidy',
        entity_type: 'platform',
        entity_id: 'marketing',
        amount: freeDeliveryDiscountLyd,
        currency: 'LYD',
        status: 'completed',
        description: `دعم التوصيل المجاني لطلب رقم ${order.order_number || order.id}`,
        created_at: nowIso
      });
    }

    // 2. Credit Merchant Payable (Subtotal - Commission)
    txRows.push({
      id: `txn_${uuidv4().substring(0, 8)}`,
      batch_id: batchId,
      order_id: order.id,
      wallet_id: merchantWallet ? merchantWallet.id : `wallet_${merchantId}`,
      counterparty_wallet_id: isCod ? (driverWallet ? driverWallet.id : null) : SYSTEM_WALLETS.ESCROW,
      entry_type: 'CREDIT',
      account_type: 'merchant_payable',
      entity_type: 'merchant',
      entity_id: merchantId,
      amount: merchantNet,
      currency: 'LYD',
      status: 'completed',
      description: `مستحقات بيع طلب رقم ${order.order_number || order.id} (بعد خصم عمولة ${(commissionPct * 100).toFixed(0)}%)`,
      created_at: nowIso
    });

    // 3. Credit Driver Earnings (80% of Delivery Fee)
    txRows.push({
      id: `txn_${uuidv4().substring(0, 8)}`,
      batch_id: batchId,
      order_id: order.id,
      wallet_id: driverWallet ? driverWallet.id : `wallet_driver_${order.driver_id}`,
      counterparty_wallet_id: isCod ? (driverWallet ? driverWallet.id : null) : SYSTEM_WALLETS.ESCROW,
      entry_type: 'CREDIT',
      account_type: 'driver_earnings',
      entity_type: 'driver',
      entity_id: order.driver_id,
      amount: driverEarnings,
      currency: 'LYD',
      status: 'completed',
      description: `أرباح توصيل طلب رقم ${order.order_number || order.id} (80% من رسوم التوصيل)`,
      created_at: nowIso
    });

    // 4. Credit Platform Revenue (20% Delivery Fee + Store Commission + Service Fee)
    txRows.push({
      id: `txn_${uuidv4().substring(0, 8)}`,
      batch_id: batchId,
      order_id: order.id,
      wallet_id: revWallet.id,
      counterparty_wallet_id: isCod ? (driverWallet ? driverWallet.id : null) : SYSTEM_WALLETS.ESCROW,
      entry_type: 'CREDIT',
      account_type: 'platform_revenue',
      entity_type: 'platform',
      entity_id: 'platform',
      amount: platformRevenue,
      currency: 'LYD',
      status: 'completed',
      description: `إيرادات المنصة من طلب رقم ${order.order_number || order.id} (عمولة متجر + 20% توصيل)`,
      created_at: nowIso
    });

    // 5. Official Standard General Ledger Journal Entry (COA)
    const journalLines = [];

    if (isCod) {
      journalLines.push({
        accountCode: '1040',
        debit: customerBilledAmount,
        credit: 0,
        entityType: 'driver',
        entityId: order.driver_id,
        note: `تحصيل كاش من الزبون (COD) لطلب #${order.order_number || order.id}`
      });
    } else {
      const pMethod = String(order.payment_method || '').toLowerCase();
      let bankCode = '1033';
      if (pMethod.includes('sadad')) bankCode = '1031';
      else if (pMethod.includes('lypay')) bankCode = '1032';
      else if (pMethod.includes('wallet')) bankCode = '2040';

      journalLines.push({
        accountCode: bankCode,
        debit: customerBilledAmount,
        credit: 0,
        entityType: pMethod.includes('wallet') ? 'customer' : 'bank',
        entityId: pMethod.includes('wallet') ? order.customer_id : pMethod,
        note: `دفع إلكتروني لطلب #${order.order_number || order.id}`
      });
    }

    if (discountLyd > 0) {
      journalLines.push({
        accountCode: '5010',
        debit: discountLyd,
        credit: 0,
        entityType: 'platform',
        entityId: 'marketing',
        note: `كوبون خصم ترويجي للمنصة لطلب #${order.order_number || order.id}`
      });
    }

    if (pointsDiscountLyd > 0) {
      journalLines.push({
        accountCode: '5020',
        debit: pointsDiscountLyd,
        credit: 0,
        entityType: 'customer',
        entityId: order.customer_id,
        note: `خصم استبدال نقاط ولاء لطلب #${order.order_number || order.id}`
      });
    }

    if (freeDeliveryDiscountLyd > 0) {
      journalLines.push({
        accountCode: '5030',
        debit: freeDeliveryDiscountLyd,
        credit: 0,
        entityType: 'platform',
        entityId: 'marketing',
        note: `دعم التوصيل المجاني لطلب #${order.order_number || order.id}`
      });
    }

    // Credits
    journalLines.push({
      accountCode: '2020',
      debit: 0,
      credit: merchantNet,
      entityType: 'store',
      entityId: merchantId,
      note: `صافي مستحق المتجر بعد خصم العمولة (${subtotal} - ${commissionLyd})`
    });

    journalLines.push({
      accountCode: '2030',
      debit: 0,
      credit: driverEarnings,
      entityType: 'driver',
      entityId: order.driver_id,
      note: `أرباح الكابتن من التوصيل (${deliveryFee} * 80%)`
    });

    journalLines.push({
      accountCode: '4010',
      debit: 0,
      credit: commissionLyd,
      entityType: 'platform',
      entityId: 'platform',
      note: `إيراد عمولة بيع الوجبات (${(commissionPct * 100).toFixed(0)}%)`
    });

    journalLines.push({
      accountCode: '4020',
      debit: 0,
      credit: platformDeliveryShare,
      entityType: 'platform',
      entityId: 'platform',
      note: `حصة المنصة من رسوم التوصيل (${deliveryFee} * 20%)`
    });

    if (serviceFee > 0) {
      journalLines.push({
        accountCode: '4030',
        debit: 0,
        credit: serviceFee,
        entityType: 'platform',
        entityId: 'platform',
        note: 'رسوم خدمات تشغيلية وتقنية'
      });
    }

    let journalEntry = null;
    try {
      journalEntry = await accountingEngine.recordJournalEntry(db, {
        referenceId: order.id,
        transactionType: 'order_settlement',
        narration: `تسوية حسابات طلب رقم ${order.order_number || order.id} في نالوت`,
        lines: journalLines,
        pgPool
      });
    } catch (jErr) {
      console.warn('[AccountingEngine Entry Warning]:', jErr.message);
    }

    // Commit to in-memory ledger
    db.wallet_transactions.push(...txRows);

    // Commit to PostgreSQL if active
    if (pgPool) {
      try {
        for (const row of txRows) {
          await pgPool.query(`
            INSERT INTO wallet_transactions (
              id, wallet_id, counterparty_wallet_id, order_id,
              transaction_type, account_type, entity_type, entry_type,
              amount, currency, status, description, created_at
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            ON CONFLICT (id) DO NOTHING
          `, [
            row.id, row.wallet_id, row.counterparty_wallet_id || null, row.order_id,
            row.account_type, row.account_type, row.entity_type, row.entry_type,
            row.amount, row.currency, row.status, row.description, row.created_at
          ]);
        }

        if (driver) {
          await pgPool.query(`
            UPDATE drivers
            SET wallet_balance_lyd = $1,
                cash_in_hand_lyd = $2,
                cod_balance_lyd = $3
            WHERE id = $4
          `, [
            driver.wallet_balance_lyd,
            driver.cash_in_hand_lyd || 0,
            driver.cod_balance_lyd || 0,
            driver.id
          ]);
        }
      } catch (err) {
        console.error('[Ledger PG commit error]:', err.message);
      }
    }

    return {
      order_id: order.id,
      total_debits: totalDebits,
      total_credits: totalCredits,
      discrepancy: discrepancy,
      driver_earnings: driverEarnings,
      driver_cash_in_hand: driver ? driver.cash_in_hand_lyd : 0,
      merchant_net: merchantNet,
      platform_revenue: platformRevenue,
      transactions_count: txRows.length,
      is_balanced: discrepancy === 0.00
    };
  }

  /**
   * Settles a driver's collected cash-in-hand liability at the central hub.
   * Clears cash_in_hand_lyd and cod_balance_lyd to 0.0 while preserving driver.wallet_balance_lyd intact!
   *
   * @param {Object} db In-memory database cache
   * @param {string} driverId The driver's ID
   * @param {Object} [options] Settlement options (e.g., custom voucher notes, requested amount)
   * @param {Object} [pgPool] Optional PostgreSQL pool
   * @returns {Object} Settlement result with voucher and updated driver state
   */
  async settleDriverCash(db, driverId, options = {}, pgPool = null) {
    if (!db.drivers) throw new Error('Drivers collection not initialized');

    const driver = db.drivers.find(d => d.id === driverId);
    if (!driver) {
      throw new Error(`Driver not found: ${driverId}`);
    }

    const availableLiability = parseFloat(
      driver.cash_in_hand_lyd !== undefined
        ? driver.cash_in_hand_lyd
        : (driver.cod_balance_lyd || 0)
    ) || 0.0;

    const settledAmount = options.amount !== undefined
      ? this.round(options.amount)
      : this.round(availableLiability);

    if (settledAmount < 0) {
      throw new Error('Settlement amount cannot be negative');
    }

    // Generate formal voucher REC-YYYY-XXXX
    if (!db.vouchers) db.vouchers = [];
    const year = new Date().getFullYear();
    const suffix = Math.floor(1000 + Math.random() * 9000);
    const voucherNumber = `REC-${year}-${suffix}`;

    const voucher = {
      id: `vouch_${Date.now()}`,
      voucher_number: voucherNumber,
      type: 'receipt',
      beneficiary_name: driver.full_name || 'كابتن نالوت',
      beneficiary_role: 'captain',
      beneficiary_id: driver.id,
      amount_lyd: settledAmount,
      payment_method: 'cash',
      notes: options.notes || 'توريد عهدة نقدية (COD) واستلام الكاش وإبراء ذمة الكابتن',
      created_by: options.created_by || 'إدارة واصل - نالوت',
      created_at: new Date().toISOString()
    };

    db.vouchers.unshift(voucher);

    // CRITICAL REQUIREMENT:
    // Clear cash_in_hand_lyd and cod_balance_lyd to 0.0.
    // PRESERVE driver.wallet_balance_lyd (net earnings) intact!
    driver.cash_in_hand_lyd = Math.max(0, this.round(availableLiability - settledAmount));
    driver.cod_balance_lyd = driver.cash_in_hand_lyd;
    // driver.wallet_balance_lyd remains untouched!

    // Balanced settlement transactions in ledger
    const nowIso = new Date().toISOString();
    const batchId = `settle_${driver.id}_${Date.now()}`;
    const txRows = [
      // 1. Debit Platform Vault (treasury collects physical cash)
      {
        id: `txn_${uuidv4().substring(0, 8)}`,
        batch_id: batchId,
        wallet_id: SYSTEM_WALLETS.VAULT,
        entry_type: 'DEBIT',
        account_type: 'platform_vault',
        entity_type: 'platform',
        entity_id: 'central_hub_nalut',
        amount: settledAmount,
        currency: 'LYD',
        status: 'completed',
        description: `استلام عهدة نقدية من الكابتن ${driver.full_name || driver.id} بموجب سند ${voucherNumber}`,
        created_at: nowIso
      },
      // 2. Credit Driver Cash in Hand (clearing captain's custody liability)
      {
        id: `txn_${uuidv4().substring(0, 8)}`,
        batch_id: batchId,
        wallet_id: `wallet_${driver.id}`,
        entry_type: 'CREDIT',
        account_type: 'cash_in_hand',
        entity_type: 'driver',
        entity_id: driver.id,
        amount: settledAmount,
        currency: 'LYD',
        status: 'completed',
        description: `إبراء ذمة الكابتن ${driver.full_name || driver.id} من العهدة النقدية بموجب سند ${voucherNumber}`,
        created_at: nowIso
      }
    ];

    if (!db.wallet_transactions) db.wallet_transactions = [];
    db.wallet_transactions.push(...txRows);

    // Record official Journal Entry in General Ledger:
    // Debit 1010 (Vault), Credit 1040 (Driver Custody)
    let journalEntry = null;
    try {
      journalEntry = await accountingEngine.recordJournalEntry(db, {
        entryNumber: `JRN-REC-${voucherNumber}`,
        referenceId: voucher.id,
        transactionType: 'cod_vault_deposit',
        narration: `توريد عهدة نقدية لخزينة المنصة من الكابتن ${driver.full_name || driver.id} بموجب سند قبض رقم ${voucherNumber}`,
        lines: [
          {
            accountCode: '1010',
            debit: settledAmount,
            credit: 0,
            entityType: 'platform',
            entityId: 'central_vault_nalut',
            note: `إيداع نقدي بالخزينة الرئيسية بسند ${voucherNumber}`
          },
          {
            accountCode: '1040',
            debit: 0,
            credit: settledAmount,
            entityType: 'driver',
            entityId: driver.id,
            note: `إبراء ذمة الكابتن من العهدة النقدية بسند ${voucherNumber}`
          }
        ],
        pgPool
      });
    } catch (jErr) {
      console.warn('[AccountingEngine Settle Warning]:', jErr.message);
    }

    // PostgreSQL sync if available
    if (pgPool) {
      try {
        await pgPool.query(`
          UPDATE drivers
          SET cash_in_hand_lyd = $1,
              cod_balance_lyd = $2
          WHERE id = $3
        `, [driver.cash_in_hand_lyd, driver.cod_balance_lyd, driver.id]);

        for (const row of txRows) {
          await pgPool.query(`
            INSERT INTO wallet_transactions (
              id, wallet_id, order_id, transaction_type, account_type,
              entity_type, entry_type, amount, currency, status, description, created_at
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            ON CONFLICT (id) DO NOTHING
          `, [
            row.id, row.wallet_id, null, 'settlement', row.account_type,
            row.entity_type, row.entry_type, row.amount, row.currency,
            row.status, row.description, row.created_at
          ]);
        }
      } catch (err) {
        console.error('[Ledger PG settlement error]:', err.message);
      }
    }

    return {
      driver,
      settled_amount: settledAmount,
      remaining_cash_in_hand: driver.cash_in_hand_lyd,
      net_earnings_preserved: driver.wallet_balance_lyd,
      voucher,
      journal_entry: journalEntry,
      is_balanced: true,
      discrepancy: 0.00
    };
  }

  /**
   * Disburses a merchant's payout request, issuing an official Payment Voucher (PAY-YYYY-XXXX)
   * and generating the corresponding double-entry Journal Entry (Debit 2020, Credit 1021/1010).
   */
  async disburseMerchantPayout(db, { storeId, amount, paymentMethod = 'مصرف الجمهورية', destinationAccount = '', notes = '', pgPool = null }) {
    const payoutAmount = this.round(amount);
    if (payoutAmount <= 0) throw new Error('مبلغ الصرف يجب أن يكون أكبر من صفر');

    const year = new Date().getFullYear();
    const suffix = Math.floor(1000 + Math.random() * 9000);
    const voucherNumber = `PAY-${year}-${suffix}`;

    const store = (db.stores || []).find(s => s.id === storeId);
    const storeName = store ? store.name : 'متجر نالوت';

    // Deduct from merchant wallet
    const merchantId = store ? (store.merchant_id || store.owner_user_id || store.id) : storeId;
    let merchantWallet = db.wallets ? db.wallets.find(w => w.user_id === merchantId || w.id === `wallet_${merchantId}`) : null;
    if (merchantWallet) {
      merchantWallet.balance = Math.max(0, this.round((merchantWallet.balance || 0) - payoutAmount));
    }

    const voucher = {
      id: `vouch_pay_${Date.now()}`,
      voucher_number: voucherNumber,
      type: 'payment',
      beneficiary_name: storeName,
      beneficiary_role: 'merchant',
      beneficiary_id: merchantId,
      amount_lyd: payoutAmount,
      payment_method: paymentMethod,
      destination_account: destinationAccount,
      notes: notes || `صرف مستحقات أرباح لـ ${storeName}`,
      created_by: 'إدارة واصل - نالوت',
      created_at: new Date().toISOString()
    };

    if (!db.vouchers) db.vouchers = [];
    db.vouchers.unshift(voucher);

    // Journal Entry: Debit 2020 (Merchants Payable), Credit 1021 (Bank) or 1010 (Vault)
    const isCashOrVault = String(paymentMethod).includes('كاش') || String(paymentMethod).includes('خزينة');
    const creditAccount = isCashOrVault ? '1010' : '1021';
    let journalEntry = null;
    try {
      journalEntry = await accountingEngine.recordJournalEntry(db, {
        entryNumber: `JRN-PAY-${voucherNumber}`,
        referenceId: voucher.id,
        transactionType: 'merchant_payout',
        narration: `صرف مستحقات متجر ${storeName} بموجب سند صرف رقم ${voucherNumber}`,
        lines: [
          {
            accountCode: '2020',
            debit: payoutAmount,
            credit: 0,
            entityType: 'store',
            entityId: merchantId,
            note: `تخفيض التزام مستحقات ${storeName} بسند صرف ${voucherNumber}`
          },
          {
            accountCode: creditAccount,
            debit: 0,
            credit: payoutAmount,
            entityType: 'bank',
            entityId: creditAccount === '1010' ? 'vault' : 'bank_jumhouria',
            note: `صرف القيمة عبر ${paymentMethod} بسند ${voucherNumber}`
          }
        ],
        pgPool
      });
    } catch (jErr) {
      console.warn('[AccountingEngine Payout Warning]:', jErr.message);
    }

    return {
      success: true,
      voucher,
      journal_entry: journalEntry,
      store_name: storeName,
      payout_amount: payoutAmount,
      remaining_wallet_balance: merchantWallet ? merchantWallet.balance : 0
    };
  }

  /**
   * Verifies overall ledger mathematical balance (Total Debits == Total Credits).
   */
  verifyLedgerIntegrity(db) {
    if (!db || !Array.isArray(db.wallet_transactions)) {
      return { total_debits: 0, total_credits: 0, discrepancy: 0, is_balanced: true };
    }

    let totalDebits = 0;
    let totalCredits = 0;

    for (const tx of db.wallet_transactions) {
      const amt = Number(tx.amount) || 0;
      if (tx.entry_type === 'DEBIT') {
        totalDebits += amt;
      } else if (tx.entry_type === 'CREDIT') {
        totalCredits += amt;
      }
    }

    totalDebits = this.round(totalDebits);
    totalCredits = this.round(totalCredits);
    const discrepancy = this.round(Math.abs(totalDebits - totalCredits));

    return {
      total_debits: totalDebits,
      total_credits: totalCredits,
      discrepancy: discrepancy,
      is_balanced: discrepancy === 0.00
    };
  }
}

module.exports = new LedgerService();
module.exports.LedgerService = LedgerService;
module.exports.SYSTEM_WALLETS = SYSTEM_WALLETS;
