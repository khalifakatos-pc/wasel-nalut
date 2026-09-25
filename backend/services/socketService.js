/**
 * ============================================================================
 * SOCKET SERVICE - REAL-TIME ORCHESTRATOR
 * Manages Socket.io connections, rooms, and event dispatching
 * ============================================================================
 */

class SocketService {
  constructor() {
    this.io = null;
    this.connectedUsers = new Map(); // userId -> socketId
  }

  /**
   * Initialize the service with the Socket.io instance from server.js
   */
  init(io) {
    this.io = io;
    this._setupListeners();
    console.log('[SocketService] Initialized and listening for events');
  }

  _setupListeners() {
    this.io.on('connection', (socket) => {
      // 1. User Identification
      socket.on('identify', ({ userId, role }) => {
        this.connectedUsers.set(userId, socket.id);
        socket.join(`user:${userId}`);

        if (role === 'driver') socket.join('role:driver');
        if (role === 'merchant') socket.join('role:merchant');
        if (role === 'admin') socket.join('role:admin');

        console.log(`[SocketService] User ${userId} (${role}) connected: ${socket.id}`);
      });

      // 2. Order Room Management
      socket.on('join_order', (orderId) => {
        socket.join(`order:${orderId}`);
        console.log(`[SocketService] Socket ${socket.id} joined order room: ${orderId}`);
      });

      socket.on('disconnect', () => {
        // Clean up connected users map
        for (let [userId, socketId] of this.connectedUsers.entries()) {
          if (socketId === socket.id) {
            this.connectedUsers.delete(userId);
            break;
          }
        }
      });
    });
  }

  /**
   * Send a targeted order status notification to customer, merchant, and driver.
   */
  sendOrderStatusNotification(order, previousStatus, db) {
    const store = db?.stores?.find(s => s.id === order.store_id) || {};
    const driver = db?.drivers?.find(d => d.id === order.driver_id);

    const notificationPayload = {
      order_id: order.id,
      order_number: order.order_number,
      status: order.status,
      previous_status: previousStatus,
      store_name: store.name || 'Unknown Store',
      customer_name: order.customer_name,
      driver_name: driver ? driver.full_name : 'Not assigned',
      updated_at: new Date().toISOString(),
    };

    // 1. Define specific event types based on milestones
    let eventType = 'order:status_changed';
    switch (order.status) {
      case 'preparing': eventType = 'order:preparing'; break;
      case 'ready_for_pickup': eventType = 'order:ready'; break;
      case 'out_for_delivery': eventType = 'order:picked_up'; break;
      case 'delivered': eventType = 'order:delivered'; break;
      case 'cancelled': eventType = 'order:cancelled'; break;
    }

    // 2. Target Customer
    this.sendToUser(order.customer_id, eventType, notificationPayload);

    // 3. Target Merchant (Store room)
    this.io.to(`store:${order.store_id}`).emit(eventType, notificationPayload);

    // 4. Target Driver
    if (order.driver_id) {
      this.sendToUser(order.driver_id, eventType, notificationPayload);
    }

    // 5. Target Admin
    this.io.to('admin:fleet').emit(`admin:${eventType}`, notificationPayload);

    console.log(`[SocketService] Notification sent: ${eventType} for Order ${order.order_number}`);
  }

  /**
   * Send an event to a specific user (via their private room)
   */
  sendToUser(userId, event, data) {
    this.io.to(`user:${userId}`).emit(event, data);
  }

  /**
   * Send an event to all participants of a specific order
   */
  sendToOrder(orderId, event, data) {
    this.io.to(`order:${orderId}`).emit(event, data);
  }

  /**
   * Broadcast driver location updates to specific targets
   */
  broadcastDriverLocation(telemetry) {
    const { driver_id, order_id } = telemetry;

    // 1. Update the driver's own room (echo for confirmation)
    this.io.to(`driver:${driver_id}`).emit('driver:location_changed', telemetry);

    // 2. Update admin fleet dashboard
    this.io.to('admin:fleet').emit('admin:driver_moved', telemetry);

    // 3. If associated with an order, update the order room (customer/merchant)
    if (order_id) {
      this.sendToOrder(order_id, 'order:driver_location', telemetry);
    }
  }

  /**
   * Broadcast an event to a specific role (e.g., all drivers)
   */
  broadcastToRole(role, event, data) {
    this.io.to(`role:${role}`).emit(event, data);
  }

  /**
   * Global broadcast
   */
  broadcast(event, data) {
    this.io.emit(event, data);
  }

  /**
   * Utility to get socket ID for a user
   */
  getSocketId(userId) {
    return this.connectedUsers.get(userId);
  }
}

module.exports = new SocketService();
