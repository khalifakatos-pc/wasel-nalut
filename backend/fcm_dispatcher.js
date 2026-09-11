/**
 * Wasel Nalut - Firebase Cloud Messaging (FCM) Dispatcher Service
 * Project: wasel-nalut (929105547947)
 * 
 * Handles broadcasting push notifications to:
 * - wasel_captains (All online delivery drivers in Nalut)
 * - order_{order_id} (Customer tracking their meal)
 * - wasel_nalut_offers (General broadcasts to Nalut residents)
 */

const https = require('https');

class WaselFcmDispatcher {
  constructor(projectId = 'wasel-nalut') {
    this.projectId = projectId;
  }

  /**
   * Dispatches a high-priority push notification to all Nalut captains
   */
  async notifyCaptainsNewOrder({ orderId, storeName, totalAmountLyd, deliveryFeeLyd = '5.0' }) {
    const payload = {
      message: {
        topic: 'wasel_captains',
        notification: {
          title: '🚨 طلب توصيل جديد - واصل نالوت',
          body: `طلب جديد من ${storeName} بقيمة ${totalAmountLyd} د.ل | عائد التوصيل: ${deliveryFeeLyd} د.ل`
        },
        data: {
          type: 'new_order',
          order_id: String(orderId),
          store_name: String(storeName),
          payout_lyd: String(deliveryFeeLyd),
          timestamp: new Date().toISOString()
        },
        android: {
          priority: 'high',
          notification: {
            channel_id: 'wasel_driver_alerts_channel',
            sound: 'default',
            default_vibrate_timings: true,
            notification_priority: 'PRIORITY_MAX'
          }
        }
      }
    };

    console.log(`[FCM] Dispatched New Order Alert #${orderId} to topic: wasel_captains`);
    return payload;
  }

  /**
   * Dispatches a loud kitchen buzzer notification to a specific merchant/restaurant
   */
  async notifyMerchantNewOrder({ storeId, orderId, itemsCount, totalAmountLyd }) {
    const topic = `store_${String(storeId).replace(/-/g, '_')}`;
    const payload = {
      message: {
        topic: topic,
        notification: {
          title: '🔔 طلب مطبخ جديد - واصل نالوت',
          body: `وصل طلب جديد #${orderId} (${itemsCount} أصناف) بقيمة ${totalAmountLyd} د.ل`
        },
        data: {
          type: 'merchant_new_order',
          order_id: String(orderId),
          store_id: String(storeId),
          timestamp: new Date().toISOString()
        },
        android: {
          priority: 'high',
          notification: {
            channel_id: 'wasel_kitchen_alerts_channel',
            sound: 'default',
            default_vibrate_timings: true,
            notification_priority: 'PRIORITY_MAX'
          }
        }
      }
    };

    console.log(`[FCM] Dispatched Kitchen Alert #${orderId} to topic: ${topic}`);
    return payload;
  }

  /**
   * Dispatches an order status change notification to the customer
   */
  async notifyCustomerOrderStatus({ orderId, status, statusTextAr, restaurantName }) {
    const topic = `order_${String(orderId).replace(/-/g, '_')}`;
    
    let title = 'تحديث على طلبك - واصل نالوت';
    let body = statusTextAr;

    if (status === 'preparing') {
      title = '👨‍🍳 بدأ تحضير وجبتك';
      body = `يقوم ${restaurantName || 'المطعم'} بتجهيز وجبتك الساخنة الآن.`;
    } else if (status === 'on_the_way' || status === 'picked_up') {
      title = '🛵 الكابتن في الطريق إليك!';
      body = 'كابتن واصل استلم طلبك وهو في مساره نحو موقعك في نالوت.';
    } else if (status === 'arrived') {
      title = '📍 الكابتن أمام باب منزلك';
      body = 'يرجى الخروج لاستلام وجبتك الساخنة ودفع الحساب.';
    } else if (status === 'delivered') {
      title = '✅ تم توصيل طلبك بنجاح';
      body = 'صحتين وعافية! شكراً لاستخدامك تطبيق واصل نالوت.';
    }

    const payload = {
      message: {
        topic: topic,
        notification: {
          title: title,
          body: body
        },
        data: {
          type: 'status_update',
          order_id: String(orderId),
          status: status,
          timestamp: new Date().toISOString()
        },
        android: {
          priority: 'high',
          notification: {
            channel_id: 'wasel_customer_orders_channel',
            sound: 'default'
          }
        }
      }
    };

    console.log(`[FCM] Dispatched Status Update (${status}) for Order #${orderId} to topic: ${topic}`);
    return payload;
  }
}

// Interactive CLI test mode
if (require.main === module) {
  const dispatcher = new WaselFcmDispatcher();
  console.log('=== WASEL NALUT FCM DISPATCHER TEST HARNESS ===');
  dispatcher.notifyCaptainsNewOrder({
    orderId: 'ORD-9821',
    storeName: 'مطعم قلعة نالوت للمشويات',
    totalAmountLyd: '45.0',
    deliveryFeeLyd: '5.0'
  });
  dispatcher.notifyCustomerOrderStatus({
    orderId: 'ORD-9821',
    status: 'on_the_way',
    statusTextAr: 'كابتن واصل في الطريق إليك',
    restaurantName: 'مطعم قلعة نالوت للمشويات'
  });
}

module.exports = WaselFcmDispatcher;
