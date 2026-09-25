/**
 * ============================================================================
 * DISPATCH SERVICE - SMART DRIVER MATCHING ENGINE
 * Handles the logic of finding and notifying the best available drivers
 * ============================================================================
 */

const { calculateHaversineDistance } = require('../utils/geo');
const SocketService = require('./socketService');

class DispatchService {
  constructor() {
    this.dispatchTimeouts = new Map(); // orderId -> timeout object
    this.DISPATCH_TIMEOUT_MINUTES = 5;
  }

  /**
   * Finds the best available drivers for an order and sends dispatch requests.
   * @param {Object} order The order that is ready for pickup
   * @param {Object} db The database state
   */
  async dispatchOrder(order, db) {
    console.log(`[DispatchService] Initiating smart dispatch for Order ${order.order_number}`);

    const store = db.stores.find(s => s.id === order.store_id);
    if (!store) {
      console.error(`[DispatchService] Store not found for order ${order.id}`);
      return { success: false, error: 'Store not found' };
    }

    // 1. Filter drivers who are 'online_idle' and 'is_approved'
    const availableDrivers = db.drivers.filter(d =>
      d.status === 'online_idle' &&
      d.is_approved === true
    );

    if (availableDrivers.length === 0) {
      console.log(`[DispatchService] No online_idle approved drivers available for Order ${order.order_number}`);
      this._startTimeout(order, db);
      return { success: false, error: 'No available drivers' };
    }

    // 2. Calculate distance from store to each available driver
    const rankedDrivers = availableDrivers.map(driver => ({
      ...driver,
      distance: calculateHaversineDistance(
        store.latitude,
        store.longitude,
        driver.latitude,
        driver.longitude
      )
    }));

    // 3. Rank the top 3 closest drivers
    rankedDrivers.sort((a, b) => a.distance - b.distance);
    const topDrivers = rankedDrivers.slice(0, 3);

    console.log(`[DispatchService] Top ${topDrivers.length} drivers found for Order ${order.order_number}`);

    // 4. Send 'dispatch:request' event via SocketService to these drivers
    topDrivers.forEach(driver => {
      SocketService.sendToUser(driver.id, 'dispatch:request', {
        order_id: order.id,
        order_number: order.order_number,
        store_name: store.name,
        pickup_location: {
          latitude: store.latitude,
          longitude: store.longitude,
          address: store.address
        },
        distance_meters: Math.round(driver.distance),
        estimated_earnings: order.delivery_fee_lyd * 0.80,
        items_count: order.items?.length || 0
      });
    });

    // Start timeout mechanism to notify admin if no one accepts
    this._startTimeout(order, db);

    return {
      success: true,
      driversNotified: topDrivers.map(d => d.id)
    };
  }

  /**
   * Starts a timeout to notify admin if order isn't picked up within X minutes.
   */
  _startTimeout(order, db) {
    // Clear existing timeout if any
    if (this.dispatchTimeouts.has(order.id)) {
      clearTimeout(this.dispatchTimeouts.get(order.id).timer);
    }

    const timer = setTimeout(() => {
      this._handleDispatchTimeout(order, db);
    }, this.DISPATCH_TIMEOUT_MINUTES * 60 * 1000);

    this.dispatchTimeouts.set(order.id, { timer });
  }

  /**
   * Notifies admin when an order remains unassigned after timeout.
   */
  _handleDispatchTimeout(order, db) {
    // Check if order is still waiting for pickup and has no driver assigned
    const currentOrder = db.orders.find(o => o.id === order.id);
    if (currentOrder && currentOrder.status === 'ready_for_pickup' && !currentOrder.driver_id) {
      console.log(`[DispatchService] TIMEOUT: Order ${order.order_number} not accepted by any driver within ${this.DISPATCH_TIMEOUT_MINUTES} mins.`);

      SocketService.io.to('admin:fleet').emit('admin:dispatch_timeout', {
        order_id: order.id,
        order_number: order.order_number,
        store_name: order.store_name,
        timeout_minutes: this.DISPATCH_TIMEOUT_MINUTES,
        message: 'No driver accepted the dispatch request within the allocated time.'
      });
    }
    this.dispatchTimeouts.delete(order.id);
  }

  /**
   * Call this when a driver accepts the order to cancel the admin notification timer.
   */
  cancelTimeout(orderId) {
    if (this.dispatchTimeouts.has(orderId)) {
      clearTimeout(this.dispatchTimeouts.get(orderId).timer);
      this.dispatchTimeouts.delete(orderId);
      console.log(`[DispatchService] Dispatch timeout cancelled for Order ${orderId}`);
    }
  }
}

module.exports = new DispatchService();
