/**
 * ============================================================================
 * SOCKET SERVICE - REAL-TIME ORCHESTRATOR
 * Manages Socket.io connections, rooms, and unified event dispatching
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
      const auth = socket.handshake.auth || {};
      const query = socket.handshake.query || {};

      const handleIdentify = (data = {}) => {
        const userId = data.userId || data.user_id || data.id || auth.userId || auth.user_id || query.userId || query.user_id;
        const role = data.role || auth.role || query.role;
        const storeId = data.storeId || data.store_id || auth.storeId || auth.store_id || query.storeId || query.store_id;
        const driverId = data.driverId || data.driver_id || auth.driverId || auth.driver_id || query.driverId || query.driver_id;
        const orderId = data.orderId || data.order_id || auth.orderId || auth.order_id || query.orderId || query.order_id;

        // 1. User clients join user:${userId}
        if (userId) {
          this.connectedUsers.set(userId, socket.id);
          socket.join(`user:${userId}`);
        }

        // 2. Merchant clients join store:${storeId} and role:merchant
        if (role === 'merchant' || role === 'store' || storeId) {
          socket.join('role:merchant');
          const targetStoreId = storeId || (role === 'merchant' ? userId : null);
          if (targetStoreId) {
            socket.join(`store:${targetStoreId}`);
          }
        }

        // 3. Driver clients join driver:${driverId} AND role:driver
        if (role === 'driver' || role === 'captain' || driverId) {
          socket.join('role:driver');
          const targetDriverId = driverId || (role === 'driver' || role === 'captain' ? userId : null);
          if (targetDriverId) {
            socket.join(`driver:${targetDriverId}`);
          }
        }

        // 4. Admin clients join admin:fleet AND role:admin
        if (role === 'admin' || role === 'super_admin') {
          socket.join('admin:fleet');
          socket.join('role:admin');
        }

        // 5. Support joining order room on handshake
        if (orderId) {
          socket.join(`order:${orderId}`);
        }

        console.log(`[SocketService] Client identified (socket ${socket.id}): user=${userId}, role=${role}, store=${storeId}, driver=${driverId}`);
      };

      // Auto-identify if handshake credentials provided
      if (auth.userId || query.userId || auth.role || query.role || auth.storeId || query.storeId || auth.driverId || query.driverId) {
        handleIdentify();
      }

      // 1. Client 'identify' event handler
      socket.on('identify', (data) => {
        handleIdentify(data || {});
      });

      // 2. Order Room Management
      socket.on('join_order', (orderId) => {
        if (orderId) {
          socket.join(`order:${orderId}`);
          console.log(`[SocketService] Socket ${socket.id} joined order room: ${orderId}`);
        }
      });
      socket.on('order:subscribe', (orderId) => {
        if (orderId) socket.join(`order:${orderId}`);
      });
      socket.on('leave_order', (orderId) => {
        if (orderId) socket.leave(`order:${orderId}`);
      });

      // 3. Store Room Management
      socket.on('join_store', (storeId) => {
        if (storeId) {
          socket.join(`store:${storeId}`);
          socket.join('role:merchant');
          console.log(`[SocketService] Socket ${socket.id} joined store room: ${storeId}`);
        }
      });
      socket.on('store:subscribe', (storeId) => {
        if (storeId) {
          socket.join(`store:${storeId}`);
          socket.join('role:merchant');
        }
      });

      // 4. Driver Room Management
      socket.on('join_driver', (driverId) => {
        if (driverId) {
          socket.join(`driver:${driverId}`);
          socket.join('role:driver');
          console.log(`[SocketService] Socket ${socket.id} joined driver room: ${driverId}`);
        }
      });
      socket.on('driver:subscribe', (driverId) => {
        if (driverId) {
          socket.join(`driver:${driverId}`);
          socket.join('role:driver');
        }
      });

      // 5. Admin Fleet Room Management
      socket.on('join_admin', () => {
        socket.join('admin:fleet');
        socket.join('role:admin');
        console.log(`[SocketService] Socket ${socket.id} joined admin:fleet`);
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
   * Broadcast an atomic order status transition across all relevant channels:
   * - Broadcast order:status_changed with updated order payload to:
   *   * user:${order.customer_id}
   *   * store:${order.store_id}
   *   * order:${order.id}
   *   * driver:${order.driver_id} (if assigned)
   * - Broadcast admin:order_status_changed to admin:fleet.
   * - If transitioning to ready_for_pickup and driver is not assigned: broadcast radar:incoming_order to role:driver.
   */
  broadcastOrderStatusTransition(order, previousStatus, db, notes = '') {
    if (!this.io) return;

    const statusPayload = {
      order_id: order.id,
      id: order.id,
      order_number: order.order_number,
      previous_status: previousStatus,
      status: order.status,
      driver_id: order.driver_id,
      customer_id: order.customer_id,
      store_id: order.store_id,
      prep_time_minutes: order.prep_time_minutes,
      prep_started_at: order.prep_started_at,
      ready_at: order.ready_at,
      handover_at: order.handover_at,
      handover_code: order.handover_code,
      kitchen_delay_seconds: order.kitchen_delay_seconds || 0,
      driver_delay_seconds: order.driver_delay_seconds || 0,
      notes: notes || order.notes || '',
      updated_at: order.updated_at || new Date().toISOString()
    };

    // 1. Broadcast order:status_changed to specific rooms
    if (order.customer_id) {
      this.io.to(`user:${order.customer_id}`).emit('order:status_changed', statusPayload);
    }
    if (order.store_id) {
      this.io.to(`store:${order.store_id}`).emit('order:status_changed', statusPayload);
    }
    this.io.to(`order:${order.id}`).emit('order:status_changed', statusPayload);
    if (order.driver_id) {
      this.io.to(`driver:${order.driver_id}`).emit('order:status_changed', statusPayload);
    } else {
      this.io.to('role:driver').emit('order:status_changed', statusPayload);
    }

    // 2. Broadcast admin:order_status_changed to admin:fleet
    this.io.to('admin:fleet').emit('admin:order_status_changed', statusPayload);

    // 3. Send milestone specific notifications
    this.sendOrderStatusNotification(order, previousStatus, db);

    // 4. Radar broadcast gating:
    //    Emit radar:incoming_order to role:driver ONLY on ready_for_pickup when driver is not assigned
    if (order.status === 'ready_for_pickup' && !order.driver_id) {
      const radarPayload = {
        ...order,
        status: 'ready_for_pickup',
        prep_status_badge: '🟢 الوجبة جاهزة بالمطعم - استلم الوجبة فوراً'
      };
      this.io.to('role:driver').emit('radar:incoming_order', radarPayload);
      console.log(`[SocketService] Radar alert emitted to role:driver for ready_for_pickup: Order #${order.order_number}`);
    } else if (order.status === 'ready_for_pickup' && order.driver_id) {
      const radarPayload = {
        ...order,
        status: 'ready_for_pickup',
        prep_status_badge: '🟢 الوجبة جاهزة بالمطعم - استلم الوجبة فوراً'
      };
      this.io.to(`driver:${order.driver_id}`).emit('radar:incoming_order', radarPayload);
      console.log(`[SocketService] Radar alert emitted to driver:${order.driver_id} for ready_for_pickup: Order #${order.order_number}`);
    } else if (order.status === 'out_for_delivery' || order.status === 'picked_up' || (order.driver_id && (previousStatus === 'ready_for_pickup' || previousStatus === 'preparing'))) {
      const claimPayload = { order_id: order.id, driver_id: order.driver_id };
      this.io.to('role:driver').emit('radar:order_claimed', claimPayload);
    }
  }

  /**
   * Send a targeted order status notification to customer, merchant, driver, and admin.
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
    let eventType = null;
    switch (order.status) {
      case 'preparing': eventType = 'order:preparing'; break;
      case 'ready_for_pickup': eventType = 'order:ready'; break;
      case 'out_for_delivery':
      case 'picked_up': eventType = 'order:picked_up'; break;
      case 'delivered': eventType = 'order:delivered'; break;
      case 'cancelled': eventType = 'order:cancelled'; break;
    }

    // Do not re-emit order:status_changed when broadcastOrderStatusTransition already did
    if (!eventType) return;

    // 2. Target Customer
    if (order.customer_id) {
      this.sendToUser(order.customer_id, eventType, notificationPayload);
    }

    // 3. Target Merchant (Store room)
    if (order.store_id) {
      this.io.to(`store:${order.store_id}`).emit(eventType, notificationPayload);
    }

    // 4. Target Driver
    if (order.driver_id) {
      this.io.to(`driver:${order.driver_id}`).emit(eventType, notificationPayload);
    }

    // 5. Target Admin
    this.io.to('admin:fleet').emit(`admin:${eventType}`, notificationPayload);

    console.log(`[SocketService] Notification sent: ${eventType} for Order ${order.order_number}`);
  }

  /**
   * Send an event to a specific user (via their private room)
   */
  sendToUser(userId, event, data) {
    if (this.io && userId) {
      this.io.to(`user:${userId}`).emit(event, data);
    }
  }

  /**
   * Send an event to all participants of a specific order
   */
  sendToOrder(orderId, event, data) {
    if (this.io && orderId) {
      this.io.to(`order:${orderId}`).emit(event, data);
    }
  }

  /**
   * Broadcast driver location updates to specific targets
   */
  broadcastDriverLocation(telemetry) {
    if (!this.io) return;
    const { driver_id, order_id } = telemetry;

    // 1. Update the driver's own room (echo for confirmation)
    if (driver_id) {
      this.io.to(`driver:${driver_id}`).emit('driver:location_changed', telemetry);
    }

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
    if (this.io && role) {
      this.io.to(`role:${role}`).emit(event, data);
    }
  }

  /**
   * Global broadcast
   */
  broadcast(event, data) {
    if (this.io) {
      this.io.emit(event, data);
    }
  }

  /**
   * Utility to get socket ID for a user
   */
  getSocketId(userId) {
    return this.connectedUsers.get(userId);
  }
}

module.exports = new SocketService();
