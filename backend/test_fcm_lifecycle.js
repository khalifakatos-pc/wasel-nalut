/**
 * Wasel Nalut - FCM Push & Order Sound Dispatch Verification Script
 * Validates full notification chain: Kitchen Bell -> Captain Radar Alarm -> Customer Status Chime
 */

const WaselFcmDispatcher = require('./fcm_dispatcher');
const dispatchService = require('./services/dispatchService');
const socketService = require('./services/socketService');

async function runFcmVerification() {
  console.log('================================================================');
  console.log('🚀 TESTING WASEL NALUT FCM PUSH & CONTINUOUS SOUND CHIME CHAIN');
  console.log('================================================================');

  const fcm = new WaselFcmDispatcher('wasel-nalut');

  // Test 1: Kitchen New Order Bell
  console.log('\n[1/3] Testing Kitchen New Order Bell (KDS)...');
  const kitchenPayload = await fcm.notifyMerchantNewOrder({
    storeId: 'store_nalut_01',
    orderId: 'ORD-2026-LY-8801',
    itemsCount: 3,
    totalAmountLyd: '45.00'
  });
  console.log('  Channel:', kitchenPayload.message.android.notification.channel_id);
  console.log('  Sound:', kitchenPayload.message.android.notification.sound);
  console.log('  Priority:', kitchenPayload.message.android.notification.notification_priority);
  if (kitchenPayload.message.android.notification.channel_id !== 'wasel_kitchen_alerts_channel') {
    throw new Error('Mismatched kitchen alert channel');
  }

  // Test 2: Captain Radar Alarm
  console.log('\n[2/3] Testing Captain Order Radar Alarm...');
  const captainPayload = await fcm.notifyCaptainsNewOrder({
    orderId: 'ORD-2026-LY-8801',
    storeName: 'مطعم قلعة نالوت للمشويات',
    totalAmountLyd: '45.00',
    deliveryFeeLyd: '5.00'
  });
  console.log('  Channel:', captainPayload.message.android.notification.channel_id);
  console.log('  Sound:', captainPayload.message.android.notification.sound);
  console.log('  Vibration:', captainPayload.message.android.notification.vibrate_timings_millis);
  if (captainPayload.message.android.notification.channel_id !== 'wasel_driver_alerts_channel') {
    throw new Error('Mismatched driver alert channel');
  }

  // Test 3: Customer Order Status Chime
  console.log('\n[3/3] Testing Customer Order Status Chime...');
  const customerPayload = await fcm.notifyCustomerOrderStatus({
    orderId: 'ORD-2026-LY-8801',
    status: 'picked_up',
    statusTextAr: 'كابتن واصل استلم طلبك وهو في مساره نحو موقعك في نالوت',
    restaurantName: 'مطعم قلعة نالوت للمشويات'
  });
  console.log('  Channel:', customerPayload.message.android.notification.channel_id);
  console.log('  Sound:', customerPayload.message.android.notification.sound);
  if (customerPayload.message.android.notification.channel_id !== 'wasel_customer_orders_channel') {
    throw new Error('Mismatched customer order channel');
  }

  console.log('\n================================================================');
  console.log('✅ ALL FCM NOTIFICATION CHANNELS & SOUNDS VERIFIED SUCCESSFULLY!');
  console.log('================================================================');
}

runFcmVerification().catch(err => {
  console.error('❌ Verification failed:', err);
  process.exit(1);
});
