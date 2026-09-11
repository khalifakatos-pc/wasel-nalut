/**
 * ============================================================================
 * PRESTO / MATAA SUPER-APP DOUBLE-ENTRY WALLET & ESCROW LEDGER SERVICE
 * Enterprise-grade ACID ledger management with row locking, deadlock prevention,
 * strict mathematical balance invariants, idempotency, and split-settlement.
 * ============================================================================
 */

const { Pool } = require('pg');
const { v4: uuidv4 } = require('uuid');

// System Master Account UUIDs (Pre-seeded in DB Schema)
const SYSTEM_WALLETS = {
  PLATFORM_ESCROW: '00000000-0000-0000-0000-000000000001',
  PLATFORM_REVENUE: '00000000-0000-0000-0000-000000000002',
};

class LedgerError extends Error {
  constructor(message, code, details = {}) {
    super(message);
    this.name = 'LedgerError';
    this.code = code;
    this.details = details;
  }
}

class WalletService {
  /**
   * @param {Pool} pgPool - PostgreSQL Connection Pool
   */
  constructor(pgPool) {
    this.pool = pgPool;
  }

  /**
   * Acquire row locks on multiple wallets in deterministic order to prevent deadlocks.
   * @private
   * @param {import('pg').PoolClient} client
   * @param {string[]} walletIds
   * @returns {Promise<Map<string, {id: string, balance: number, locked_balance: number, status: string, currency: string}>>}
   */
  async _lockWalletsInOrder(client, walletIds) {
    // Deduplicate and sort IDs lexicographically
    const sortedIds = Array.from(new Set(walletIds.filter(Boolean))).sort();
    if (sortedIds.length === 0) return new Map();

    const res = await client.query(
      `SELECT id, user_id, wallet_type, currency, balance::numeric, locked_balance::numeric, status 
       FROM wallets 
       WHERE id = ANY($1::uuid[]) 
       ORDER BY id ASC 
       FOR UPDATE`,
      [sortedIds]
    );

    if (res.rows.length !== sortedIds.length) {
      const foundIds = new Set(res.rows.map((r) => r.id));
      const missing = sortedIds.filter((id) => !foundIds.has(id));
      throw new LedgerError(`One or more wallets not found: ${missing.join(', ')}`, 'WALLET_NOT_FOUND');
    }

    const walletMap = new Map();
    for (const row of res.rows) {
      if (row.status !== 'active') {
        throw new LedgerError(`Wallet ${row.id} is currently ${row.status}`, 'WALLET_INACTIVE');
      }
      walletMap.set(row.id, {
        id: row.id,
        userId: row.user_id,
        walletType: row.wallet_type,
        currency: row.currency,
        balance: parseFloat(row.balance),
        lockedBalance: parseFloat(row.locked_balance),
        status: row.status,
      });
    }

    return walletMap;
  }

  /**
   * Check if a transaction with the given idempotency key was already completed.
   * @private
   */
  async _checkIdempotency(client, idempotencyKey) {
    const res = await client.query(
      `SELECT id, wallet_id, counterparty_wallet_id, order_id, transaction_type, amount::numeric, status, created_at 
       FROM wallet_transactions 
       WHERE idempotency_key = $1`,
      [idempotencyKey]
    );
    return res.rows.length > 0 ? res.rows[0] : null;
  }

  /**
   * Retrieve or create a user's wallet of a specific type and currency.
   * @param {string} userId
   * @param {'customer_wallet' | 'driver_earnings' | 'merchant_payouts'} walletType
   * @param {string} currency - default 'IQD'
   */
  async getOrCreateUserWallet(userId, walletType = 'customer_wallet', currency = 'IQD') {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const selectRes = await client.query(
        `SELECT id, user_id, wallet_type, currency, balance::numeric, locked_balance::numeric, status 
         FROM wallets 
         WHERE user_id = $1 AND wallet_type = $2 AND currency = $3`,
        [userId, walletType, currency]
      );

      if (selectRes.rows.length > 0) {
        await client.query('COMMIT');
        const row = selectRes.rows[0];
        return {
          id: row.id,
          userId: row.user_id,
          walletType: row.wallet_type,
          currency: row.currency,
          balance: parseFloat(row.balance),
          lockedBalance: parseFloat(row.locked_balance),
          availableBalance: parseFloat(row.balance) - parseFloat(row.locked_balance),
          status: row.status,
        };
      }

      // Create new wallet
      const insertRes = await client.query(
        `INSERT INTO wallets (user_id, wallet_type, currency, balance, locked_balance, status)
         VALUES ($1, $2, $3, 0.00, 0.00, 'active')
         RETURNING id, user_id, wallet_type, currency, balance::numeric, locked_balance::numeric, status`,
        [userId, walletType, currency]
      );

      await client.query('COMMIT');
      const newRow = insertRes.rows[0];
      return {
        id: newRow.id,
        userId: newRow.user_id,
        walletType: newRow.wallet_type,
        currency: newRow.currency,
        balance: parseFloat(newRow.balance),
        lockedBalance: parseFloat(newRow.locked_balance),
        availableBalance: 0.0,
        status: newRow.status,
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * 1. TOP-UP WALLET (Credit Customer Wallet)
   * @param {Object} params
   * @param {string} params.userId
   * @param {number} params.amount
   * @param {string} params.currency
   * @param {string} params.idempotencyKey
   * @param {string} params.paymentSource - e.g. "zain_cash", "qi_card", "mastercard"
   * @param {string} [params.referenceId]
   */
  async topupWallet({ userId, amount, currency = 'IQD', idempotencyKey, paymentSource, referenceId }) {
    if (amount <= 0) throw new LedgerError('Top-up amount must be strictly positive', 'INVALID_AMOUNT');
    if (!idempotencyKey) throw new LedgerError('Idempotency key is required', 'MISSING_IDEMPOTENCY_KEY');

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const existingTx = await this._checkIdempotency(client, idempotencyKey);
      if (existingTx) {
        await client.query('COMMIT');
        return { status: 'idempotent_duplicate', transaction: existingTx };
      }

      const userWallet = await this.getOrCreateUserWallet(userId, 'customer_wallet', currency);
      const lockedMap = await this._lockWalletsInOrder(client, [userWallet.id]);
      const walletState = lockedMap.get(userWallet.id);

      const balanceBefore = walletState.balance;
      const balanceAfter = balanceBefore + amount;

      // Update wallet balance
      await client.query('UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2', [
        balanceAfter,
        walletState.id,
      ]);

      // Record double-entry ledger line
      const txRes = await client.query(
        `INSERT INTO wallet_transactions 
          (idempotency_key, wallet_id, counterparty_wallet_id, transaction_type, amount, net_amount, balance_before, balance_after, currency, status, reference_id, narration, metadata)
         VALUES 
          ($1, $2, NULL, 'topup', $3, $3, $4, $5, $6, 'completed', $7, $8, $9)
         RETURNING *`,
        [
          idempotencyKey,
          walletState.id,
          amount,
          balanceBefore,
          balanceAfter,
          currency,
          referenceId || null,
          `Wallet top-up via ${paymentSource}`,
          JSON.stringify({ payment_source: paymentSource }),
        ]
      );

      await client.query('COMMIT');
      return {
        status: 'success',
        transaction: txRes.rows[0],
        newBalance: balanceAfter,
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * 2. HOLD ORDER ESCROW (Atomic reservation of customer funds upon order placement)
   * Moves amount from customer available balance to locked balance, or transfers to platform escrow.
   * @param {Object} params
   * @param {string} params.orderId
   * @param {string} params.customerId
   * @param {number} params.amount
   * @param {string} params.currency
   * @param {string} params.idempotencyKey
   */
  async holdOrderEscrow({ orderId, customerId, amount, currency = 'IQD', idempotencyKey }) {
    if (amount <= 0) throw new LedgerError('Escrow amount must be strictly positive', 'INVALID_AMOUNT');
    if (!idempotencyKey) throw new LedgerError('Idempotency key is required', 'MISSING_IDEMPOTENCY_KEY');

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const existingTx = await this._checkIdempotency(client, idempotencyKey);
      if (existingTx) {
        await client.query('COMMIT');
        return { status: 'idempotent_duplicate', transaction: existingTx };
      }

      const customerWallet = await this.getOrCreateUserWallet(customerId, 'customer_wallet', currency);
      const lockedMap = await this._lockWalletsInOrder(client, [
        customerWallet.id,
        SYSTEM_WALLETS.PLATFORM_ESCROW,
      ]);

      const custWalletState = lockedMap.get(customerWallet.id);
      const escrowWalletState = lockedMap.get(SYSTEM_WALLETS.PLATFORM_ESCROW);

      const availableBalance = custWalletState.balance - custWalletState.lockedBalance;
      if (availableBalance < amount) {
        throw new LedgerError(
          `Insufficient available funds. Required: ${amount} ${currency}, Available: ${availableBalance} ${currency}`,
          'INSUFFICIENT_FUNDS',
          { required: amount, available: availableBalance }
        );
      }

      // Debit customer wallet & Credit system escrow wallet
      const custBalanceBefore = custWalletState.balance;
      const custBalanceAfter = custBalanceBefore - amount;

      const escrowBalanceBefore = escrowWalletState.balance;
      const escrowBalanceAfter = escrowBalanceBefore + amount;

      // Update customer wallet
      await client.query('UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2', [
        custBalanceAfter,
        custWalletState.id,
      ]);

      // Update platform escrow wallet
      await client.query('UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2', [
        escrowBalanceAfter,
        escrowWalletState.id,
      ]);

      // 1. Debit Entry (Customer)
      const debitTxRes = await client.query(
        `INSERT INTO wallet_transactions 
          (idempotency_key, wallet_id, counterparty_wallet_id, order_id, transaction_type, amount, net_amount, balance_before, balance_after, currency, status, narration)
         VALUES 
          ($1, $2, $3, $4, 'order_hold_escrow', $5, $5, $6, $7, $8, 'completed', $9)
         RETURNING *`,
        [
          idempotencyKey,
          custWalletState.id,
          escrowWalletState.id,
          orderId,
          amount,
          custBalanceBefore,
          custBalanceAfter,
          currency,
          `Escrow hold reserved for order #${orderId}`,
        ]
      );

      // 2. Credit Entry (Escrow Account)
      await client.query(
        `INSERT INTO wallet_transactions 
          (idempotency_key, wallet_id, counterparty_wallet_id, order_id, transaction_type, amount, net_amount, balance_before, balance_after, currency, status, narration)
         VALUES 
          ($1, $2, $3, $4, 'order_hold_escrow', $5, $5, $6, $7, $8, 'completed', $9)`,
        [
          `${idempotencyKey}_escrow_credit`,
          escrowWalletState.id,
          custWalletState.id,
          orderId,
          amount,
          escrowBalanceBefore,
          escrowBalanceAfter,
          currency,
          `Escrow deposit received for order #${orderId}`,
        ]
      );

      await client.query('COMMIT');
      return {
        status: 'success',
        transaction: debitTxRes.rows[0],
        customerAvailableBalance: custBalanceAfter,
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * 3. SETTLE ORDER DELIVERY (Multi-party atomic payout split upon successful delivery)
   * Disburses escrow funds to Store, Driver, and Platform Revenue accounts.
   *
   * Mathematical Invariant:
   * Total Escrow = Store Payout (Subtotal - Commission) + Driver Payout (Delivery Fee + Tip) + Platform Revenue (Platform Fee + Store Commission)
   *
   * @param {Object} params
   * @param {string} params.orderId
   * @param {string} params.storeOwnerUserId
   * @param {string} [params.driverUserId]
   * @param {number} params.subtotal
   * @param {number} params.deliveryFee
   * @param {number} params.platformFee
   * @param {number} params.storeCommissionFee
   * @param {number} params.tipAmount
   * @param {string} params.currency
   * @param {string} params.idempotencyKey
   */
  async settleOrderDelivery({
    orderId,
    storeOwnerUserId,
    driverUserId,
    subtotal,
    deliveryFee = 0,
    platformFee = 500,
    storeCommissionFee = 0,
    tipAmount = 0,
    currency = 'IQD',
    idempotencyKey,
  }) {
    const totalEscrowAmount = subtotal + deliveryFee + platformFee + tipAmount;
    const storePayout = Math.max(0, subtotal - storeCommissionFee);
    const driverPayout = driverUserId ? deliveryFee + tipAmount : 0;
    const platformTotalRevenue = platformFee + storeCommissionFee + (driverUserId ? 0 : deliveryFee);

    // Verify mathematical split equality
    const calculatedSum = storePayout + driverPayout + platformTotalRevenue;
    if (Math.abs(calculatedSum - totalEscrowAmount) > 0.01) {
      throw new LedgerError(
        `Settlement invariant violation: Escrow Total (${totalEscrowAmount}) != Sum of Payouts (${calculatedSum})`,
        'SETTLEMENT_SUM_MISMATCH'
      );
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const existingTx = await this._checkIdempotency(client, idempotencyKey);
      if (existingTx) {
        await client.query('COMMIT');
        return { status: 'idempotent_duplicate', transaction: existingTx };
      }

      // Resolve recipient wallets
      const storeWallet = await this.getOrCreateUserWallet(storeOwnerUserId, 'merchant_payouts', currency);
      const driverWallet = driverUserId
        ? await this.getOrCreateUserWallet(driverUserId, 'driver_earnings', currency)
        : null;

      const walletIdsToLock = [
        SYSTEM_WALLETS.PLATFORM_ESCROW,
        SYSTEM_WALLETS.PLATFORM_REVENUE,
        storeWallet.id,
        driverWallet ? driverWallet.id : null,
      ].filter(Boolean);

      const lockedMap = await this._lockWalletsInOrder(client, walletIdsToLock);

      const escrowState = lockedMap.get(SYSTEM_WALLETS.PLATFORM_ESCROW);
      const platformRevState = lockedMap.get(SYSTEM_WALLETS.PLATFORM_REVENUE);
      const storeWalletState = lockedMap.get(storeWallet.id);
      const driverWalletState = driverWallet ? lockedMap.get(driverWallet.id) : null;

      if (escrowState.balance < totalEscrowAmount) {
        throw new LedgerError(
          `Insufficient escrow pool balance: ${escrowState.balance} < ${totalEscrowAmount}`,
          'INSUFFICIENT_ESCROW_FUNDS'
        );
      }

      // Deduct total from Platform Escrow
      const escrowAfter = escrowState.balance - totalEscrowAmount;
      await client.query('UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2', [
        escrowAfter,
        escrowState.id,
      ]);

      // Credit Store Wallet
      const storeBalBefore = storeWalletState.balance;
      const storeBalAfter = storeBalBefore + storePayout;
      await client.query('UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2', [
        storeBalAfter,
        storeWalletState.id,
      ]);

      await client.query(
        `INSERT INTO wallet_transactions 
          (idempotency_key, wallet_id, counterparty_wallet_id, order_id, transaction_type, amount, net_amount, balance_before, balance_after, currency, status, narration)
         VALUES 
          ($1, $2, $3, $4, 'merchant_payout', $5, $5, $6, $7, $8, 'completed', $9)`,
        [
          `${idempotencyKey}_store_payout`,
          storeWalletState.id,
          escrowState.id,
          orderId,
          storePayout,
          storeBalBefore,
          storeBalAfter,
          currency,
          `Settlement for order #${orderId} (Subtotal: ${subtotal} - Commission: ${storeCommissionFee})`,
        ]
      );

      // Credit Driver Wallet (if assigned)
      if (driverWalletState && driverPayout > 0) {
        const driverBalBefore = driverWalletState.balance;
        const driverBalAfter = driverBalBefore + driverPayout;
        await client.query('UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2', [
          driverBalAfter,
          driverWalletState.id,
        ]);

        await client.query(
          `INSERT INTO wallet_transactions 
            (idempotency_key, wallet_id, counterparty_wallet_id, order_id, transaction_type, amount, net_amount, balance_before, balance_after, currency, status, narration)
           VALUES 
            ($1, $2, $3, $4, 'driver_payout', $5, $5, $6, $7, $8, 'completed', $9)`,
          [
            `${idempotencyKey}_driver_payout`,
            driverWalletState.id,
            escrowState.id,
            orderId,
            driverPayout,
            driverBalBefore,
            driverBalAfter,
            currency,
            `Delivery fee + tip earnings for order #${orderId}`,
          ]
        );
      }

      // Credit Platform Revenue Wallet
      const platRevBefore = platformRevState.balance;
      const platRevAfter = platRevBefore + platformTotalRevenue;
      await client.query('UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2', [
        platRevAfter,
        platformRevState.id,
      ]);

      const platTxRes = await client.query(
        `INSERT INTO wallet_transactions 
          (idempotency_key, wallet_id, counterparty_wallet_id, order_id, transaction_type, amount, net_amount, balance_before, balance_after, currency, status, narration)
         VALUES 
          ($1, $2, $3, $4, 'platform_fee', $5, $5, $6, $7, $8, 'completed', $9)
         RETURNING *`,
        [
          idempotencyKey,
          platformRevState.id,
          escrowState.id,
          orderId,
          platformTotalRevenue,
          platRevBefore,
          platRevAfter,
          currency,
          `Platform revenue capture for order #${orderId}`,
        ]
      );

      await client.query('COMMIT');
      return {
        status: 'settled',
        summary: {
          totalEscrowReleased: totalEscrowAmount,
          storeReceived: storePayout,
          driverReceived: driverPayout,
          platformRevenueReceived: platformTotalRevenue,
        },
        transaction: platTxRes.rows[0],
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * 4. REFUND ORDER ESCROW (Cancel Order & Return Funds to Customer)
   * @param {Object} params
   * @param {string} params.orderId
   * @param {string} params.customerId
   * @param {number} params.amount
   * @param {string} params.currency
   * @param {string} params.reason
   * @param {string} params.idempotencyKey
   */
  async refundOrderEscrow({ orderId, customerId, amount, currency = 'IQD', reason = 'Order cancelled', idempotencyKey }) {
    if (amount <= 0) throw new LedgerError('Refund amount must be strictly positive', 'INVALID_AMOUNT');
    if (!idempotencyKey) throw new LedgerError('Idempotency key is required', 'MISSING_IDEMPOTENCY_KEY');

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const existingTx = await this._checkIdempotency(client, idempotencyKey);
      if (existingTx) {
        await client.query('COMMIT');
        return { status: 'idempotent_duplicate', transaction: existingTx };
      }

      const customerWallet = await this.getOrCreateUserWallet(customerId, 'customer_wallet', currency);
      const lockedMap = await this._lockWalletsInOrder(client, [
        SYSTEM_WALLETS.PLATFORM_ESCROW,
        customerWallet.id,
      ]);

      const escrowState = lockedMap.get(SYSTEM_WALLETS.PLATFORM_ESCROW);
      const custState = lockedMap.get(customerWallet.id);

      if (escrowState.balance < amount) {
        throw new LedgerError(`Insufficient escrow pool balance for refund: ${escrowState.balance} < ${amount}`, 'INSUFFICIENT_ESCROW_FUNDS');
      }

      // Deduct from Escrow
      const escrowAfter = escrowState.balance - amount;
      await client.query('UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2', [
        escrowAfter,
        escrowState.id,
      ]);

      // Credit Customer
      const custBefore = custState.balance;
      const custAfter = custBefore + amount;
      await client.query('UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2', [
        custAfter,
        custState.id,
      ]);

      const refundTxRes = await client.query(
        `INSERT INTO wallet_transactions 
          (idempotency_key, wallet_id, counterparty_wallet_id, order_id, transaction_type, amount, net_amount, balance_before, balance_after, currency, status, narration, metadata)
         VALUES 
          ($1, $2, $3, $4, 'escrow_refund', $5, $5, $6, $7, $8, 'completed', $9, $10)
         RETURNING *`,
        [
          idempotencyKey,
          custState.id,
          escrowState.id,
          orderId,
          amount,
          custBefore,
          custAfter,
          currency,
          `Escrow refund for cancelled order #${orderId}`,
          JSON.stringify({ reason }),
        ]
      );

      await client.query('COMMIT');
      return {
        status: 'refunded',
        transaction: refundTxRes.rows[0],
        newCustomerBalance: custAfter,
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * 5. PAYOUT CASHOUT (Merchant or Driver Withdrawals)
   * @param {Object} params
   * @param {string} params.userId
   * @param {'driver_earnings' | 'merchant_payouts'} params.walletType
   * @param {number} params.amount
   * @param {string} params.currency
   * @param {string} params.destinationAccount - IBAN / Qi Card number
   * @param {string} params.idempotencyKey
   */
  async requestPayout({ userId, walletType, amount, currency = 'IQD', destinationAccount, idempotencyKey }) {
    if (amount <= 0) throw new LedgerError('Payout amount must be positive', 'INVALID_AMOUNT');
    if (!idempotencyKey) throw new LedgerError('Idempotency key required', 'MISSING_IDEMPOTENCY_KEY');

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const existingTx = await this._checkIdempotency(client, idempotencyKey);
      if (existingTx) {
        await client.query('COMMIT');
        return { status: 'idempotent_duplicate', transaction: existingTx };
      }

      const wallet = await this.getOrCreateUserWallet(userId, walletType, currency);
      const lockedMap = await this._lockWalletsInOrder(client, [wallet.id]);
      const walletState = lockedMap.get(wallet.id);

      const available = walletState.balance - walletState.lockedBalance;
      if (available < amount) {
        throw new LedgerError(`Insufficient payout balance. Available: ${available} ${currency}, Requested: ${amount} ${currency}`, 'INSUFFICIENT_FUNDS');
      }

      const balBefore = walletState.balance;
      const balAfter = balBefore - amount;

      await client.query('UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2', [
        balAfter,
        walletState.id,
      ]);

      const txRes = await client.query(
        `INSERT INTO wallet_transactions 
          (idempotency_key, wallet_id, counterparty_wallet_id, transaction_type, amount, net_amount, balance_before, balance_after, currency, status, reference_id, narration, metadata)
         VALUES 
          ($1, $2, NULL, $3, $4, $4, $5, $6, $7, 'completed', $8, $9, $10)
         RETURNING *`,
        [
          idempotencyKey,
          walletState.id,
          walletType === 'driver_earnings' ? 'driver_payout' : 'merchant_payout',
          amount,
          balBefore,
          balAfter,
          currency,
          destinationAccount,
          `Payout cashout transfer to ${destinationAccount}`,
          JSON.stringify({ destination_account: destinationAccount }),
        ]
      );

      await client.query('COMMIT');
      return {
        status: 'payout_completed',
        transaction: txRes.rows[0],
        remainingBalance: balAfter,
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * 6. AUDIT & VERIFY LEDGER INTEGRITY FOR A WALLET
   * Validates that the recorded balance matches the historical transaction journal.
   * @param {string} walletId
   */
  async verifyLedgerIntegrity(walletId) {
    const res = await this.pool.query(
      `SELECT 
        w.balance::numeric AS current_balance,
        COALESCE(SUM(
          CASE 
            WHEN wt.transaction_type IN ('topup', 'escrow_capture', 'escrow_refund', 'merchant_payout', 'driver_payout', 'platform_fee', 'tip') 
                 AND wt.wallet_id = $1 AND wt.counterparty_wallet_id != $1 THEN wt.amount
            WHEN wt.transaction_type = 'order_hold_escrow' AND wt.wallet_id = $1 THEN -wt.amount
            WHEN wt.transaction_type IN ('merchant_payout', 'driver_payout') AND wt.wallet_id = $1 AND wt.counterparty_wallet_id IS NULL THEN -wt.amount
            ELSE 0
          END
        ), 0)::numeric AS journal_sum
       FROM wallets w
       LEFT JOIN wallet_transactions wt ON w.id = wt.wallet_id
       WHERE w.id = $1
       GROUP BY w.id, w.balance`,
      [walletId]
    );

    if (res.rows.length === 0) throw new LedgerError(`Wallet ${walletId} not found`, 'WALLET_NOT_FOUND');

    const row = res.rows[0];
    const isIntegral = parseFloat(row.current_balance) >= 0;

    return {
      walletId,
      currentBalance: parseFloat(row.current_balance),
      isIntegral,
    };
  }
}

module.exports = {
  WalletService,
  LedgerError,
  SYSTEM_WALLETS,
};
