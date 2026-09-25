const express = require('express');
const router = express.Router();
const ReviewService = require('../services/reviewService');
const { authMiddleware } = require('../middleware/auth');

/**
 * @route   POST /api/reviews
 * @desc    Submit a review for an order
 * @access  Private (Customer)
 */
router.post('/', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const review = await ReviewService.submitReview(req.db, userId, req.body);
    res.status(201).json(review);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

/**
 * @route   GET /api/reviews/store/:storeId
 * @desc    Fetch reviews for a specific store
 * @access  Public
 */
router.get('/store/:storeId', async (req, res) => {
  try {
    const { storeId } = req.params;
    const reviews = await ReviewService.getStoreReviews(req.db, storeId);
    res.status(200).json(reviews);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * @route   GET /api/reviews/driver/:driverId
 * @desc    Fetch reviews for a specific driver
 * @access  Public
 */
router.get('/driver/:driverId', async (req, res) => {
  try {
    const { driverId } = req.params;
    const reviews = await ReviewService.getDriverReviews(req.db, driverId);
    res.status(200).json(reviews);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
