const { config } = require('../config');

/**
 * Wallet Service handles the core business logic for financial operations,
 * including balance updates, escrow management, and double-entry ledger recording.
 */
class WalletService {
  /**
   * Updates a wallet balance and records the transaction in the ledger.
   * @param {Object} db - The database instance.
   * @param {string} walletId - ID of the wallet to update.
   * @param {number} amount - Amount to add (positive) or subtract (negative).
   * @param {string} counterpartyWalletId - ID of the other party in the transaction.
   * @param {string} transactionType - Type of transaction (e.g., 'topup', 'merchant_payout').
   * @param {string} description - Human-readable description.
   * @param {string} orderId - Optional associated order ID.
   * @returns {Object} The updated wallet and the created transaction.
   */
  async updateBalance(db, walletId, amount, counterpartyWalletId, transactionType, description, orderId = null) {
    const wallet = db.wallets.find(w => w.id === walletId);
    if (!wallet) {
      throw new Error(`Wallet not found: ${walletId}`);
    }

    wallet.balance += amount;

    const txn = {
      id: `txn_${transactionType.substring(0, 4)}_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      wallet_id: walletId,
      counterparty_wallet_id: counterpartyWalletId,
      order_id: orderId,
      transaction_type: transactionType,
      amount: amount,
      currency: wallet.currency || 'LYD',
      status: 'completed',
      description: description,
      created_at: new Date().toISOString()
    };

    db.wallet_transactions.push(txn);

    return { wallet, transaction: txn };
  }

  /**
   * Handles the specific logic for locking funds in escrow during checkout.
   */
  async holdEscrow(db, walletId, amount, orderId) {
    const wallet = db.wallets.find(w => w.id === walletId);
    if (!wallet) throw new Error(`Wallet not found: ${walletId}`);

    const availableBalance = wallet.balance - wallet.locked_balance;
    if (availableBalance < amount) {
      throw new Error(`Insufficient wallet balance. Available: ${availableBalance.toFixed(2)} LYD, Required: ${amount.toFixed(2)} LYD`);
    }

    wallet.locked_balance += amount;

    const txn = {
      id: `txn_hold_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      wallet_id: walletId,
      counterparty_wallet_id: config.SYSTEM_WALLETS.ESCROW,
      order_id: orderId,
      transaction_type: 'order_hold_escrow',
      amount: amount,
      currency: 'LYD',
      status: 'completed',
      description: `حجز ضمان مالي للطلب`,
      created_at: new Date().toISOString()
    };

    db.wallet_transactions.push(txn);
    return { wallet, transaction: txn };
  }

  /**
   * Settles the escrow: deducts the balance and clears the lock.
   */
  async settleEscrow(db, walletId, amount) {
    const wallet = db.wallets.find(w => w.id === walletId);
    if (!wallet) throw new Error(`Wallet not found: ${walletId}`);

    wallet.locked_balance = Math.max(0, wallet.locked_balance - amount);
    wallet.balance = Math.max(0, wallet.balance - amount);

    return wallet;
  }

  /**
   * Refunds the escrow: clears the lock without deducting balance.
   */
  async refundEscrow(db, walletId, amount) {
    const wallet = db.wallets.find(w => w.id === walletId);
    if (!wallet) throw new Error(`Wallet not found: ${walletId}`);

    wallet.locked_balance = Math.max(0, wallet.locked_balance - amount);
    return wallet;
  }

  /**
   * Ensures a wallet exists for a user, creating one if necessary.
   */
  async ensureWallet(db, user) {
    let wallet = db.wallets.find(w => w.user_id === user.id);
    if (!wallet) {
      wallet = {
        id: `wallet_${user.id}`,
        user_id: user.id,
        wallet_type: user.role === 'driver' ? 'driver_earnings' : user.role === 'merchant' ? 'merchant_payouts' : 'customer_wallet',
        currency: 'LYD',
        balance: user.role === 'customer' ? 50.00 : 0.00, // Initial welcome balance for customers
        locked_balance: 0.00,
        status: 'active'
      };
      db.wallets.push(wallet);
    }
    return wallet;
  }
}

module.exports = new WalletService();
