const express = require('express');
const router = express.Router();
const VoucherService = require('../services/voucherService');
const { authMiddleware } = require('../middleware/auth');

/**
 * @route   GET /api/vouchers
 * @desc    Get available vouchers for the current user
 * @access  Private
 */
router.get('/', authMiddleware, async (req, res) => {
  try {
    const vouchers = await VoucherService.getUserVouchers(req.db, req.user?.id);
    res.json({ success: true, data: vouchers });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * @route   POST /api/vouchers
 * @desc    Create a new voucher (Admin only)
 * @access  Private (Admin)
 */
router.post('/', authMiddleware, async (req, res) => {
  try {
    if (req.user?.role !== 'admin') {
      return res.status(403).json({ success: false, error: 'Unauthorized: Admin access required' });
    }

    const voucher = await VoucherService.createVoucher(req.db, req.body);
    res.status(201).json({ success: true, message: 'Voucher created successfully', data: voucher });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
