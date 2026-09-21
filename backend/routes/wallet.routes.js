const express = require('express');
const router = express.Router();
const walletController = require('../controllers/walletController');

// wrap pattern: (fn) => (req, res, next) => fn(req, res, req.app.get('db'), next)
const wrap = (fn) => (req, res, next) => fn(req, res, req.app.get('db'), next);

/**
 * @route   GET /api/v1/wallet/balance
 * @desc    Get current wallet balance and available funds
 * @access  Private
 */
router.get('/balance', wrap(walletController.getBalance));

/**
 * @route   POST /api/v1/wallet/topup
 * @desc    Top up wallet via external payment channel
 * @access  Private
 */
router.post('/topup', wrap(walletController.topup));

/**
 * @route   GET /api/v1/wallet/transactions
 * @desc    Get wallet transaction history
 * @access  Private
 */
router.get('/transactions', wrap(walletController.getTransactions));

module.exports = router;
