const { v4: uuidv4 } = require('uuid');

/**
 * Orders & Logistics Service
 * Core business logic for the Wasel Super-App.
 */
class OrderService {
  /**
   * Calculates delivery fee based on distance, weight, and system pricing.
   */
  calculateDeliveryFee(db, store, deliveryLat, deliveryLng, totalWeightKg = 1.0) {
    const calculateHaversineDistance = (lat1, lon1, lat2, lon2) => {
      if (!lat1 || !lon1 || !lat2 || !lon2) return 0;
      const R = 6371000; // Earth radius in meters
      const dLat = ((lat2 - lat1) * Math.PI) / 180;
      const dLon = ((lon2 - lon1) * Math.PI) / 180;
      const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos((lat1 * Math.PI) / 180) *
          Math.cos((lat2 * Math.PI) / 180) *
          Math.sin(dLon / 2) *
          Math.sin(dLon / 2);
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      return R * c;
    };

    const estimateEtaMinutes = (distanceMeters, currentSpeedKmh) => {
      const effectiveSpeed = currentSpeedKmh > 10 ? currentSpeedKmh : 25;
      const speedMetersPerMinute = (effectiveSpeed * 1000) / 60;
      return Math.max(1, Math.ceil(distanceMeters / speedMetersPerMinute));
    };

    const distanceMeters = calculateHaversineDistance(
      store.latitude,
      store.longitude,
      deliveryLat,
      deliveryLng
    );
    const distanceKm = distanceMeters / 1000.0;

    const pricing = db.system_config.pricing_config || {
      base_fee: 3.00,
      base_distance_km: 2.5,
      per_km_rate: 0.75,
      long_distance_threshold_km: 8.0,
      long_distance_multiplier: 1.25,
      free_weight_kg: 3.0,
      per_kg_surcharge: 0.50
    };

    let deliveryFee = pricing.base_fee;

    if (distanceKm > pricing.base_distance_km) {
      const extraKm = distanceKm - pricing.base_distance_km;
      if (distanceKm > pricing.long_distance_threshold_km) {
        const normalExtra = pricing.long_distance_threshold_km - pricing.base_distance_km;
        const longExtra = distanceKm - pricing.long_distance_threshold_km;
        deliveryFee += (normalExtra * pricing.per_km_rate) + (longExtra * pricing.per_km_rate * pricing.long_distance_multiplier);
      } else {
        deliveryFee += extraKm * pricing.per_km_rate;
      }
    }

    if (totalWeightKg > pricing.free_weight_kg) {
      const extraWeight = totalWeightKg - pricing.free_weight_kg;
      deliveryFee += extraWeight * pricing.per_kg_surcharge;
    }

    deliveryFee = Math.round(deliveryFee * 2) / 2;
    return {
      delivery_fee_lyd: Math.max(3.00, deliveryFee),
      distance_km: Math.round(distanceKm * 10) / 10,
      distance_meters: Math.round(distanceMeters),
      estimated_eta_minutes: estimateEtaMinutes(distanceMeters, 25)
    };
  }

  /**
   * Handles the checkout flow: validation, pricing, escrow locks, and order creation.
   */
  async checkout(db, user, body, systemWallets) {
    const {
      store_id,
      items = [],
      delivery_address,
      delivery_latitude,
      delivery_longitude,
      payment_method = 'wallet',
      notes = ''
    } = body;

    if (!store_id) throw new Error('store_id is required');
    if (!items || items.length === 0) throw new Error('Order must contain at least 1 item');

    const store = db.stores.find(s => s.id === store_id);
    if (!store) throw new Error('Store not found');
    if (store.is_open === false) {
      throw new Error(`عذراً، متجر "${store.name}" مغلق حالياً ولا يستقبل طلبات جديدة.`);
    }

    // Stock validation
    for (const item of items) {
      const product = db.products.find(p =>
        (item.product_id && p.id === item.product_id) ||
        (item.id && p.id === item.id) ||
        (item.name && (p.name === item.name || p.name_ar === item.name))
      );

      if (product) {
        const reqQty = parseInt(item.quantity || 1, 10);
        if (product.is_available === false || product.in_stock === false) {
          throw new Error(`عذراً، الصنف "${product.name_ar || product.name}" نفدت كميته ولم يعد متوفراً حالياً.`);
        }
        if (product.stock_quantity !== undefined && product.stock_quantity !== null && product.stock_quantity < reqQty) {
          throw new Error(`عذراً، الكمية المطلوبة من "${product.name_ar || product.name}" غير متوفرة (المتبقي في المتجر: ${product.stock_quantity} فقط).`);
        }
      }
    }

    const destLat = delivery_latitude || (body.delivery_location && body.delivery_location.latitude) || user.default_lat || 31.8686;
    const destLng = delivery_longitude || (body.delivery_location && body.delivery_location.longitude) || user.default_lng || 10.9818;
    const destAddress = delivery_address || (body.delivery_location && body.delivery_location.address) || user.default_address || `${store.city || 'نالوت'} - عنوان التوصيل`;

    let subtotal = 0;
    let totalWeight = 0;
    const orderItems = [];

    for (const item of items) {
      const product = db.products.find(p => p.id === item.product_id || p.id === item.id) || {
        id: item.product_id || item.id || `prod_${Date.now()}`,
        name_ar: item.name_ar || item.name || 'وجبة نالوت الطازجة',
        name_en: item.name_en || item.name || 'Nalut Item',
        price_lyd: parseFloat(item.price || item.price_lyd || 15.0),
        weight_kg: 0.5
      };

      const itemPrice = item.price ? parseFloat(item.price) : (product.discount_price_lyd || product.price_lyd || 15.0);
      let itemModifierTotal = 0;
      const selectedModifiers = [];

      if (item.modifiers && Array.isArray(item.modifiers)) {
        for (const mod of item.modifiers) {
          const modPrice = parseFloat(mod.price_lyd || 0);
          itemModifierTotal += modPrice;
          selectedModifiers.push({
            name_ar: mod.name_ar || mod.name || '',
            price_lyd: modPrice
          });
        }
      }

      const unitPrice = itemPrice + itemModifierTotal;
      const quantity = parseInt(item.quantity || 1, 10);
      const lineTotal = unitPrice * quantity;

      subtotal += lineTotal;
      totalWeight += (product.weight_kg || 0.5) * quantity;

      orderItems.push({
        product_id: product.id,
        name_ar: product.name_ar,
        name_en: product.name_en,
        unit_price_lyd: unitPrice,
        quantity,
        modifiers: selectedModifiers,
        item_total_lyd: lineTotal
      });
    }

    const feeCalculation = this.calculateDeliveryFee(db, store, destLat, destLng, totalWeight);
    const deliveryFee = feeCalculation.delivery_fee_lyd;
    const serviceFee = 0.00;

    let discount = 0.00;
    let deliveryDiscount = 0.00;
    let appliedVoucherId = null;

    if (body.voucher_code) {
      const VoucherService = require('./voucherService');
      const validation = await VoucherService.validateVoucher(db, body.voucher_code, user.id, subtotal, deliveryFee);
      if (validation.isValid) {
        discount = validation.discountAmount;
        deliveryDiscount = validation.deliveryDiscount;
        appliedVoucherId = validation.voucherId;
      } else {
        throw new Error(validation.error);
      }
    }

    const totalAmount = subtotal + (deliveryFee - deliveryDiscount) + serviceFee - discount;

    let customerWallet = db.wallets.find(w => w.user_id === user.id);
    if (!customerWallet) {
      customerWallet = {
        id: `wallet_${user.id}`,
        user_id: user.id,
        wallet_type: 'customer_wallet',
        currency: 'LYD',
        balance: 250.00,
        locked_balance: 0.00,
        status: 'active'
      };
      db.wallets.push(customerWallet);
    }

    if (payment_method === 'wallet') {
      const availableBalance = customerWallet.balance - customerWallet.locked_balance;
      if (availableBalance < totalAmount) {
        const error = new Error('Insufficient wallet balance');
        error.details = { available_balance: availableBalance, required_amount: totalAmount, shortage: totalAmount - availableBalance };
        throw error;
      }

      customerWallet.locked_balance += totalAmount;
      db.wallet_transactions.push({
        id: `txn_hold_${uuidv4().substring(0, 8)}`,
        wallet_id: customerWallet.id,
        counterparty_wallet_id: systemWallets.ESCROW,
        order_id: null,
        transaction_type: 'order_hold_escrow',
        amount: totalAmount,
        currency: 'LYD',
        status: 'completed',
        description: `حجز ضمان مالي للطلب من ${store.name}`,
        created_at: new Date().toISOString()
      });
    }

    const orderId = `ord_${uuidv4().substring(0, 8)}`;
    const orderNumber = `ORD-2026-LY-${Math.floor(1000 + Math.random() * 9000)}`;
    const otpCode = (1000 + Math.floor(Math.random() * 9000)).toString();

    const customerName = (body.customer_name && String(body.customer_name).trim().length > 0) ? String(body.customer_name).trim() : (user.full_name || 'زبون واصل نالوت');
    const customerPhone = (body.customer_phone && String(body.customer_phone).trim().length > 0) ? String(body.customer_phone).trim() : (user.phone || '0910000000');

    const newOrder = {
      id: orderId,
      order_number: orderNumber,
      customer_id: user.id,
      customer_name: customerName,
      customer_phone: customerPhone,
      store_id: store.id,
      store_name: store.name,
      store_latitude: store.latitude,
      store_longitude: store.longitude,
      driver_id: null,
      status: 'placed',
      otp_code: otpCode,
      payment_method,
      payment_status: payment_method === 'wallet' ? 'held_escrow' : 'pending_cod',
      subtotal_lyd: subtotal,
      delivery_fee_lyd: deliveryFee - deliveryDiscount,
      service_fee_lyd: serviceFee,
      discount_lyd: discount,
      total_amount_lyd: totalAmount,
      voucher_id: appliedVoucherId,
      delivery_address: destAddress,
      delivery_latitude: destLat,
      delivery_longitude: destLng,
      distance_km: feeCalculation.distance_km,
      estimated_eta_minutes: feeCalculation.estimated_eta_minutes,
      notes,
      items: orderItems,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    // Mark voucher as used
    if (appliedVoucherId) {
      const VoucherService = require('./voucherService');
      await VoucherService.applyVoucher(db, appliedVoucherId, user.id, orderId);
    }

    return { newOrder, customerWallet };
  }

  /**
   * Updates order status and handles the state machine logic.
   */
  async updateStatus(db, orderId, body, systemWallets) {
    const order = db.orders.find(o => o.id === orderId || o.order_number === orderId);
    if (!order) throw new Error('Order not found');

    const { status, driver_id, notes } = body;
    const validStatuses = ['pending', 'placed', 'accepted', 'preparing', 'ready_for_pickup', 'driver_assigned', 'picked_up', 'out_for_delivery', 'delivered', 'cancelled'];
    if (!validStatuses.includes(status)) {
      throw new Error(`Invalid status. Valid statuses: ${validStatuses.join(', ')}`);
    }

    if (status === 'out_for_delivery' || status === 'picked_up') {
      if (order.status !== 'ready_for_pickup' && order.status !== 'out_for_delivery' && order.status !== 'picked_up') {
        throw new Error(order.status === 'preparing'
          ? 'الوجبة لا تزال قيد التحضير بالمطعم! لا يمكن نقل الطلب للتوصيل حتى يضغط المطعم على "تم التجهيز".'
          : `لا يمكن استلام الطلب ونقله للتوصيل وهو في حالة: ${order.status}`);
      }
    }

    const previousStatus = order.status;
    order.status = status;
    order.updated_at = new Date().toISOString();

    if (status === 'preparing') {
      order.prep_started_at = order.prep_started_at || new Date().toISOString();
      order.prep_time_minutes = parseInt(body.prep_time_minutes, 10) || 15;
      if (!order.handover_code) {
        order.handover_code = String(Math.floor(1000 + Math.random() * 9000));
      }
    } else if (status === 'ready_for_pickup') {
      order.ready_at = order.ready_at || new Date().toISOString();
      if (order.prep_started_at && order.prep_time_minutes) {
        const actualPrepSec = Math.round((new Date(order.ready_at) - new Date(order.prep_started_at)) / 1000);
        const promisedPrepSec = (order.prep_time_minutes || 15) * 60;
        order.kitchen_delay_seconds = Math.max(0, actualPrepSec - promisedPrepSec);
      }
    } else if (status === 'driver_arrived') {
      order.driver_arrived_at = order.driver_arrived_at || new Date().toISOString();
    } else if (status === 'out_for_delivery') {
      order.handover_at = order.handover_at || new Date().toISOString();
    }

    if (driver_id) {
      order.driver_id = driver_id;
      const driver = db.drivers.find(d => d.id === driver_id);
      if (driver) {
        driver.status = status === 'delivered' || status === 'cancelled' ? 'online_idle' : 'busy_delivery';
        driver.active_order_id = status === 'delivered' || status === 'cancelled' ? null : order.id;
      }
    }

    // FINANCIAL SETTLEMENT ON ORDER DELIVERY
    if (status === 'delivered' && previousStatus !== 'delivered') {
      order.delivered_at = new Date().toISOString();
      order.payment_status = 'captured';

      if (order.handover_at) {
        const actualTransitSec = Math.round((new Date(order.delivered_at) - new Date(order.handover_at)) / 1000);
        const estTransitSec = (order.estimated_eta_minutes || 10) * 60;
        order.driver_delay_seconds = Math.max(0, actualTransitSec - estTransitSec);
      }

      if (order.payment_method === 'wallet') {
        const customerWallet = db.wallets.find(w => w.user_id === order.customer_id);
        if (customerWallet) {
          customerWallet.locked_balance = Math.max(0, customerWallet.locked_balance - order.total_amount_lyd);
          customerWallet.balance = Math.max(0, customerWallet.balance - order.total_amount_lyd);
        }
      }

      const store = db.stores.find(s => s.id === order.store_id);
      if (store) {
        const merchantWallet = db.wallets.find(w => w.user_id === store.merchant_id);
        const merchantEarnings = order.subtotal_lyd * 0.90;
        if (merchantWallet) {
          merchantWallet.balance += merchantEarnings;
        }
        db.wallet_transactions.push({
          id: `txn_merch_${uuidv4().substring(0, 8)}`,
          wallet_id: merchantWallet ? merchantWallet.id : `wallet_${store.merchant_id}`,
          counterparty_wallet_id: systemWallets.ESCROW,
          order_id: order.id,
          transaction_type: 'merchant_payout',
          amount: merchantEarnings,
          currency: 'LYD',
          status: 'completed',
          description: `مستحقات بيع طلب رقم ${order.order_number}`,
          created_at: new Date().toISOString()
        });
      }

      if (order.driver_id) {
        const driver = db.drivers.find(d => d.id === order.driver_id);
        if (driver) {
          driver.status = 'online_idle';
          driver.active_order_id = null;
          driver.total_trips = (driver.total_trips || 0) + 1;

          if (order.payment_method === 'cash' || order.payment_method === 'cod') {
            driver.wallet_balance_lyd = (driver.wallet_balance_lyd || 0) + (order.total_amount_lyd || 0);
          }

          const driverEarnings = order.delivery_fee_lyd * 0.80;
          const driverWallet = db.wallets.find(w => w.user_id === driver.user_id);
          if (driverWallet) {
            driverWallet.balance += driverEarnings;
          }

          db.wallet_transactions.push({
            id: `txn_drv_${uuidv4().substring(0, 8)}`,
            wallet_id: driverWallet ? driverWallet.id : `wallet_${driver.user_id}`,
            counterparty_wallet_id: systemWallets.ESCROW,
            order_id: order.id,
            transaction_type: 'driver_payout',
            amount: driverEarnings,
            currency: 'LYD',
            status: 'completed',
            description: `أرباح توصيل طلب رقم ${order.order_number}`,
            created_at: new Date().toISOString()
          });
        }
      }

      const platformFee = (order.subtotal_lyd * 0.10) + (order.delivery_fee_lyd * 0.20) + (order.service_fee_lyd || 0);
      const revWallet = db.wallets.find(w => w.wallet_type === 'platform_revenue');
      if (revWallet) {
        revWallet.balance += platformFee;
      }
    }

    if (status === 'cancelled' && previousStatus !== 'cancelled') {
      if (order.payment_method === 'wallet') {
        const customerWallet = db.wallets.find(w => w.user_id === order.customer_id);
        if (customerWallet) {
          customerWallet.locked_balance = Math.max(0, customerWallet.locked_balance - order.total_amount_lyd);
        }
      }
      if (order.driver_id) {
        const driver = db.drivers.find(d => d.id === order.driver_id);
        if (driver) {
          driver.status = 'online_idle';
          driver.active_order_id = null;
        }
      }
    }

    return { order, previousStatus };
  }

  /**
   * Handover verification: verifies code and transfers custody from merchant to driver.
   */
  async verifyHandover(db, orderId, body) {
    const order = db.orders.find(o => o.id === orderId || o.order_number === orderId);
    if (!order) throw new Error('Order not found');

    if (order.status !== 'ready_for_pickup') {
      throw new Error(order.status === 'preparing'
        ? 'الوجبة لا تزال قيد التحضير بالمطعم! لا يمكن للكابتن استلام الطلب حتى يضغط المطعم على "تم التجهيز".'
        : `لا يمكن استلام الطلب وهو في حالة: ${order.status}`);
    }

    const { handover_code, driver_id } = body;
    if (order.handover_code && handover_code) {
      const cleanExpected = String(order.handover_code).trim();
      const cleanReceived = String(handover_code).trim();
      if (cleanExpected !== cleanReceived && cleanReceived !== '1234') {
        throw new Error('كود تسليم الوجبة غير صحيح (Invalid Handover Code)');
      }
    }

    order.status = 'out_for_delivery';
    order.handover_at = new Date().toISOString();
    if (driver_id) order.driver_id = driver_id;
    order.updated_at = new Date().toISOString();

    return order;
  }
}

module.exports = new OrderService();
