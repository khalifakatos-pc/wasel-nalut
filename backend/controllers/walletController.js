const walletService = require('../services/walletService');
const { config } = require('../config');

/**
 * Wallet Controller handles HTTP requests for wallet operations.
 * The 'db' parameter is passed via the wrap middleware in the routes.
 */
const walletController = {
  /**
   * Get current wallet balance.
   */
  async getBalance(req, res, db) {
    try {
      const user = req.user;
      const wallet = await walletService.ensureWallet(db, user);

      const availableBalance = wallet.balance - wallet.locked_balance;

      res.json({
        success: true,
        data: {
          wallet_id: wallet.id,
          user_id: wallet.user_id,
          wallet_type: wallet.wallet_type,
          currency: wallet.currency,
          currency_symbol: 'د.ل',
          total_balance: wallet.balance,
          locked_balance: wallet.locked_balance,
          available_balance: Math.max(0, availableBalance),
          status: wallet.status
        }
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * Top up wallet funds.
   */
  async topup(req, res, db) {
    try {
      const { amount, payment_channel = 'Sadad', reference_code } = req.body;
      const topupAmount = parseFloat(amount);

      if (!topupAmount || topupAmount <= 0 || topupAmount > 1000) {
        return res.status(400).json({
          success: false,
          error: 'Valid top-up amount is required (maximum limit is 1,000 LYD per top-up)'
        });
      }

      if (!reference_code && req.user.role !== 'admin') {
        return res.status(400).json({
          success: false,
          error: 'Bank transaction reference code or receipt number is required for verification'
        });
      }

      const user = req.user;
      const wallet = await walletService.ensureWallet(db, user);

      const { wallet: updatedWallet, transaction: txn } = await walletService.updateBalance(
        db,
        wallet.id,
        topupAmount,
        config.SYSTEM_WALLETS.REVENUE,
        'topup',
        `شحن رصيد إلكتروني عبر ${payment_channel} - كود العملية: ${reference_code || 'ADMIN_TOPUP'}`
      );

      // Emit live socket event if io is available
      if (req.io) {
        req.io.to(`user:${user.id}`).emit('wallet:balance_updated', {
          wallet_id: updatedWallet.id,
          balance: updatedWallet.balance,
          locked_balance: updatedWallet.locked_balance,
          available_balance: updatedWallet.balance - updatedWallet.locked_balance,
          currency: 'LYD'
        });
      }

      res.json({
        success: true,
        message: `تم شحن الرصيد بنجاح بمبلغ ${topupAmount.toFixed(2)} د.ل عبر ${payment_channel}`,
        data: {
          wallet_id: updatedWallet.id,
          balance: updatedWallet.balance,
          locked_balance: updatedWallet.locked_balance,
          available_balance: updatedWallet.balance - updatedWallet.locked_balance,
          transaction: txn
        }
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * Get transaction history.
   */
  async getTransactions(req, res, db) {
    try {
      const user = req.user;
      const wallet = await walletService.ensureWallet(db, user);

      const txns = db.wallet_transactions.filter(t => t.wallet_id === wallet.id);
      txns.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

      res.json({
        success: true,
        count: txns.length,
        data: txns
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
};

module.exports = walletController;
