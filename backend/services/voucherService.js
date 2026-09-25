/**
 * Voucher Service
 * Manages creation, validation, and application of promotional vouchers.
 */
class VoucherService {
  /**
   * Validates a voucher for a given user and order.
   * @returns {Object} { isValid: boolean, discountAmount: number, deliveryDiscount: number, error: string }
   */
  async validateVoucher(db, voucherCode, userId, orderSubtotal, orderDeliveryFee) {
    const voucher = db.vouchers ? db.vouchers.find(v => v.code === voucherCode) : null;

    if (!voucher) {
      return { isValid: false, error: 'رمز القسيمة غير صحيح (Invalid voucher code)' };
    }

    // 1. Expiry Date Check
    if (voucher.expiry_date && new Date(voucher.expiry_date) < new Date()) {
      return { isValid: false, error: 'هذه القسيمة منتهية الصلاحية (Voucher expired)' };
    }

    // 2. Total Usage Limit Check
    if (voucher.usage_limit && voucher.used_count >= voucher.usage_limit) {
      return { isValid: false, error: 'تم استنفاد جميع استخدامات هذه القسيمة (Usage limit reached)' };
    }

    // 3. Per-User Usage Limit Check
    const userUsageCount = db.voucher_usage
      ? db.voucher_usage.filter(u => u.voucher_id === voucher.id && u.user_id === userId).length
      : 0;
    if (voucher.user_usage_limit && userUsageCount >= voucher.user_usage_limit) {
      return { isValid: false, error: 'لقد استخدمت هذه القسيمة الحد الأقصى المسموح به (User usage limit reached)' };
    }

    // 4. Minimum Order Value Check
    if (voucher.min_order_value && orderSubtotal < voucher.min_order_value) {
      return {
        isValid: false,
        error: `هذه القسيمة صالحة للطلبات التي تزيد قيمتها عن ${voucher.min_order_value} د.ل (Minimum order value not met)`
      };
    }

    // Calculate Discounts
    let discountAmount = 0;
    let deliveryDiscount = 0;

    switch (voucher.type) {
      case 'PERCENTAGE':
        discountAmount = orderSubtotal * (voucher.value / 100);
        // Cap discount if there is a max discount amount
        if (voucher.max_discount_amount) {
          discountAmount = Math.min(discountAmount, voucher.max_discount_amount);
        }
        break;
      case 'FIXED':
        discountAmount = voucher.value;
        break;
      case 'FREE_DELIVERY':
        deliveryDiscount = orderDeliveryFee;
        break;
      default:
        return { isValid: false, error: 'نوع القسيمة غير معروف (Unknown voucher type)' };
    }

    // Discount cannot exceed subtotal
    discountAmount = Math.min(discountAmount, orderSubtotal);

    return {
      isValid: true,
      discountAmount: Math.round(discountAmount * 100) / 100,
      deliveryDiscount: Math.round(deliveryDiscount * 100) / 100,
      voucherId: voucher.id
    };
  }

  /**
   * Marks a voucher as used.
   */
  async applyVoucher(db, voucherId, userId, orderId) {
    const voucher = db.vouchers ? db.vouchers.find(v => v.id === voucherId) : null;
    if (!voucher) throw new Error('Voucher not found');

    // Increment total used count
    voucher.used_count = (voucher.used_count || 0) + 1;

    // Track usage for fraud prevention and per-user limits
    if (!db.voucher_usage) {
      db.voucher_usage = [];
    }

    db.voucher_usage.push({
      id: `vuse_${Date.now()}`,
      voucher_id: voucherId,
      user_id: userId,
      order_id: orderId,
      used_at: new Date().toISOString()
    });
  }

  /**
   * Admin: Create a new voucher
   */
  async createVoucher(db, voucherData) {
    const newVoucher = {
      id: `vouch_${Date.now()}`,
      code: voucherData.code.toUpperCase(),
      type: voucherData.type, // 'PERCENTAGE', 'FIXED', 'FREE_DELIVERY'
      value: parseFloat(voucherData.value || 0),
      min_order_value: parseFloat(voucherData.min_order_value || 0),
      max_discount_amount: parseFloat(voucherData.max_discount_amount || 0),
      expiry_date: voucherData.expiry_date,
      usage_limit: parseInt(voucherData.usage_limit, 10) || null,
      user_usage_limit: parseInt(voucherData.user_usage_limit, 10) || null,
      used_count: 0,
      created_at: new Date().toISOString()
    };

    if (!db.vouchers) {
      db.vouchers = [];
    }
    db.vouchers.push(newVoucher);
    return newVoucher;
  }

  /**
   * User: Get available vouchers
   */
  async getUserVouchers(db, userId) {
    if (!db.vouchers) return [];

    const now = new Date();
    return db.vouchers.filter(v => {
      const isExpired = v.expiry_date && new Date(v.expiry_date) < now;
      const totalLimitReached = v.usage_limit && v.used_count >= v.usage_limit;

      const userUsageCount = db.voucher_usage
        ? db.voucher_usage.filter(u => u.voucher_id === v.id && u.user_id === userId).length
        : 0;
      const userLimitReached = v.user_usage_limit && userUsageCount >= v.user_usage_limit;

      return !isExpired && !totalLimitReached && !userLimitReached;
    });
  }
}

module.exports = new VoucherService();
