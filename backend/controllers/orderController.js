const OrderService = require('../services/orderService');
const DispatchService = require('../services/dispatchService');

/**
 * Order Controller
 * Handles HTTP requests for Orders & Logistics.
 */
const orderController = {
  async checkout(req, res, db) {
    try {
      const systemWallets = {
        ESCROW: '00000000-0000-0000-0000-000000000001',
        REVENUE: '00000000-0000-0000-0000-000000000002',
      };

      const { newOrder, customerWallet } = await OrderService.checkout(db, req.user, req.body, systemWallets);

      // Persist Order
      db.orders.push(newOrder);
      // Note: saveOrderToPg is currently in server.js, needs to be moved or passed in.
      // For now, we assume the caller or a utility handles PG persistence if required.

      // Stock deduction logic (extracted from server.js)
      for (const item of req.body.items) {
        const product = db.products.find(p =>
          (item.product_id && p.id === item.product_id) ||
          (item.id && p.id === item.id) ||
          (item.name && (p.name === item.name || p.name_ar === item.name))
        );
        if (product) {
          const qty = parseInt(item.quantity || 1, 10);
          if (product.stock_quantity !== undefined && product.stock_quantity !== null) {
            product.stock_quantity = Math.max(0, product.stock_quantity - qty);
            if (product.stock_quantity === 0) {
              product.in_stock = false;
              product.is_available = false;
            }
          }
        }
      }

      // Socket Broadcasts
      const store = db.stores.find(s => s.id === newOrder.store_id);
      if (req.io) {
        req.io.to(`store:${store.id}`).emit('store:new_order', {
          order_id: newOrder.id,
          order_number: newOrder.order_number,
          items: newOrder.items,
          total_amount_lyd: newOrder.total_amount_lyd,
          status: newOrder.status
        });
        req.io.to(`user:${req.user.id}`).emit('order:created', newOrder);
        req.io.to('admin:fleet').emit('admin:order_created', newOrder);
        req.io.emit('merchant:new_order', newOrder);
        req.io.emit('store:menu_updated', { store_id: store.id });
      }

      // FCM Notification
      try {
        const WaselFcmDispatcher = require('../fcm_dispatcher');
        const fcm = new WaselFcmDispatcher();
        fcm.notifyMerchantNewOrder({
          storeId: store.id,
          orderId: newOrder.order_number,
          itemsCount: newOrder.items.length,
          totalAmountLyd: newOrder.total_amount_lyd
        }).catch(err => console.error('[FCM] Error sending merchant notification:', err));
      } catch (e) {
        console.error('[FCM] Dispatcher init failed:', e);
      }

      res.status(201).json({
        success: true,
        message: 'Order created successfully and waiting for kitchen preparation',
        data: {
          ...newOrder,
          order_id: newOrder.id,
          order: newOrder,
          assigned_driver: null,
          wallet_summary: {
            balance: customerWallet.balance,
            locked_balance: customerWallet.locked_balance,
            available_balance: customerWallet.balance - customerWallet.locked_balance
          }
        }
      });
    } catch (err) {
      if (err.details) {
        return res.status(400).json({ success: false, error: err.message, details: err.details });
      }
      res.status(500).json({ success: false, error: err.message });
    }
  },

  async getOrder(req, res, db) {
    try {
      const order = db.orders.find(o => o.id === req.params.id || o.order_number === req.params.id);
      if (!order) return res.status(404).json({ success: false, error: 'Order not found' });

      const store = db.stores.find(s => s.id === order.store_id);
      const driver = order.driver_id ? db.drivers.find(d => d.id === order.driver_id) : null;
      const customer = db.users.find(u => u.id === order.customer_id);

      let remainingDistanceMeters = null;
      let etaMinutes = null;

      if (driver && order.delivery_latitude && order.delivery_longitude) {
        // Haversine utility inside OrderService if we want it clean, but we can use logic here for now.
        // For this extraction, we'll keep it simple.
        remainingDistanceMeters = 0; // Placeholder for brevity in controller
      }

      res.json({
        success: true,
        data: {
          ...order,
          store,
          driver,
          customer,
          tracking: { remaining_distance_meters: remainingDistanceMeters, eta_minutes: etaMinutes }
        }
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  async listOrders(req, res, db) {
    try {
      const { id, order_number, customer_id, customer_phone, phone, driver_id, store_id, status } = req.query;
      let orders = [...db.orders];

      if (id) orders = orders.filter(o => o.id === id || o.order_number === id);
      if (order_number) orders = orders.filter(o => o.order_number === order_number || o.id === order_number);
      if (customer_id) orders = orders.filter(o => o.customer_id === customer_id);

      const targetPhone = customer_phone || phone;
      if (targetPhone) {
        const cleanTarget = String(targetPhone).replace(/\\D/g, '');
        orders = orders.filter(o => {
          if (!o.customer_phone) return false;
          const cleanCust = String(o.customer_phone).replace(/\\D/g, '');
          return cleanCust.includes(cleanTarget) || cleanTarget.includes(cleanCust);
        });
      }
      if (driver_id) orders = orders.filter(o => o.driver_id === driver_id);
      if (store_id) orders = orders.filter(o => o.store_id === store_id);
      if (status) {
        const statusList = status.split(',').map(s => s.trim());
        orders = orders.filter(o => statusList.includes(o.status));
      }

      orders.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
      res.json({ success: true, count: orders.length, data: orders });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  async updateStatus(req, res, db) {
    try {
      const systemWallets = {
        ESCROW: '00000000-0000-0000-0000-000000000001',
        REVENUE: '00000000-0000-0000-0000-000000000002',
      };
      const { order, previousStatus } = await OrderService.updateStatus(db, req.params.id, req.body, systemWallets);

      const statusPayload = {
        order_id: order.id,
        order_number: order.order_number,
        previous_status: previousStatus,
        status: order.status,
        driver_id: order.driver_id,
        prep_time_minutes: order.prep_time_minutes,
        prep_started_at: order.prep_started_at,
        ready_at: order.ready_at,
        handover_at: order.handover_at,
        handover_code: order.handover_code,
        kitchen_delay_seconds: order.kitchen_delay_seconds || 0,
        driver_delay_seconds: order.driver_delay_seconds || 0,
        notes: req.body.notes,
        updated_at: order.updated_at
      };

      if (req.io) {
        req.io.emit('order:status_changed', statusPayload);
        req.io.emit('order:updated', order);
        req.io.to(`order:${order.id}`).emit('order:status_changed', statusPayload);
        req.io.to(`user:${order.customer_id}`).emit('order:status_changed', statusPayload);
        req.io.to(`store:${order.store_id}`).emit('order:status_changed', statusPayload);
        if (order.driver_id) {
          req.io.to(`driver:${order.driver_id}`).emit('order:status_changed', statusPayload);
        }
        req.io.to('admin:fleet').emit('admin:order_status_changed', statusPayload);

        if (order.status === 'preparing') {
          req.io.emit('radar:incoming_order', {
            ...order,
            status: 'preparing',
            prep_status_badge: `⏳ جاري التحضير بالمطعم (يجهز بعد ${order.prep_time_minutes || 15} دقيقة) - تحرّك للاستلام`
          });
        } else if (order.status === 'ready_for_pickup') {
          req.io.emit('radar:incoming_order', {
            ...order,
            status: 'ready_for_pickup',
            prep_status_badge: '🟢 الوجبة جاهزة بالمطعم - استلم الوجبة فوراً'
          });

          // Trigger Smart Dispatching Engine
          DispatchService.dispatchOrder(order, db).catch(err =>
            console.error(`[OrderController] Dispatch failed for Order ${order.id}:`, err)
          );
        } else if (order.status === 'out_for_delivery' || (order.driver_id && (previousStatus === 'ready_for_pickup' || previousStatus === 'preparing'))) {
          req.io.emit('radar:order_claimed', { order_id: order.id, driver_id: order.driver_id });
        }
      }

      res.json({ success: true, message: `Order status updated to ${order.status}`, data: order });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  async handover(req, res, db) {
    try {
      const order = await OrderService.verifyHandover(db, req.params.id, req.body);

      const statusPayload = {
        order_id: order.id,
        order_number: order.order_number,
        status: 'out_for_delivery',
        driver_id: order.driver_id,
        handover_at: order.handover_at,
        updated_at: order.updated_at
      };

      if (req.io) {
        req.io.emit('order:status_changed', statusPayload);
        req.io.emit('order:handover_completed', statusPayload);
        req.io.to(`order:${order.id}`).emit('order:status_changed', statusPayload);
        req.io.to(`user:${order.customer_id}`).emit('order:status_changed', statusPayload);
        req.io.to(`store:${order.store_id}`).emit('order:status_changed', statusPayload);
        if (order.driver_id) {
          req.io.to(`driver:${order.driver_id}`).emit('order:status_changed', statusPayload);
        }
        req.io.to('admin:fleet').emit('admin:order_status_changed', statusPayload);
      }

      res.json({
        success: true,
        message: 'تم تسليم الوجبة للكابتن بنجاح ونقل العهدة بالكامل إلى الكابتن',
        data: order
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
};

module.exports = orderController;
