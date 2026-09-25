const { v4: uuidv4 } = require('uuid');

/**
 * Trust & Quality Review Service
 * Handles the logic for submitting and retrieving reviews for stores and drivers.
 */
class ReviewService {
  /**
   * Submits a review for a specific order.
   * Ensures the order is 'delivered' and the user is the customer of that order.
   */
  async submitReview(db, userId, body) {
    const { order_id, rating, comment, image_url } = body;

    if (!order_id || !rating) {
      throw new Error('order_id and rating are required');
    }

    if (rating < 1 || rating > 5) {
      throw new Error('Rating must be between 1 and 5');
    }

    // 1. Find the order
    const order = await db.query('SELECT * FROM orders WHERE id = $1', [order_id]);
    if (!order || order.rows.length === 0) {
      throw new Error('Order not found');
    }
    const orderData = order.rows[0];

    // 2. Validate ownership and status
    if (orderData.customer_id !== userId) {
      throw new Error('You are not authorized to review this order');
    }

    if (orderData.status !== 'delivered') {
      throw new Error('You can only review orders that have been delivered');
    }

    // 3. Check if a review already exists for this order
    const existingReview = await db.query('SELECT id FROM reviews WHERE order_id = $1', [order_id]);
    if (existingReview.rows.length > 0) {
      throw new Error('This order has already been reviewed');
    }

    // 4. Insert the review
    const reviewResult = await db.query(
      'INSERT INTO reviews (id, order_id, customer_id, store_id, driver_id, rating, comment, image_url) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *',
      [
        uuidv4(),
        order_id,
        userId,
        orderData.store_id,
        orderData.driver_id,
        rating,
        comment || null,
        image_url || null
      ]
    );

    return reviewResult.rows[0];
  }

  /**
   * Retrieves reviews for a specific store.
   */
  async getStoreReviews(db, storeId) {
    const result = await db.query(
      'SELECT r.*, u.full_name as customer_name FROM reviews r JOIN users u ON r.customer_id = u.id WHERE r.store_id = $1 ORDER BY r.created_at DESC',
      [storeId]
    );
    return result.rows;
  }

  /**
   * Retrieves reviews for a specific driver.
   */
  async getDriverReviews(db, driverId) {
    const result = await db.query(
      'SELECT r.*, u.full_name as customer_name FROM reviews r JOIN users u ON r.customer_id = u.id WHERE r.driver_id = $1 ORDER BY r.created_at DESC',
      [driverId]
    );
    return result.rows;
  }
}

module.exports = new ReviewService();
