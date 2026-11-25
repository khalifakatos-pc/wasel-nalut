const assert = require('assert');
const kapsoService = require('./services/kapsoService');

async function runKapsoAiWorkflowTests() {
  console.log('================================================================');
  console.log('🚀 WASEL NALUT: TESTING KAPSO WHATSAPP AI AGENT & WORKFLOW');
  console.log('================================================================');

  // Mock socket.io instance
  const emittedEvents = [];
  const mockIo = {
    to: (room) => ({
      emit: (event, data) => emittedEvents.push({ room, event, data })
    }),
    emit: (event, data) => emittedEvents.push({ room: 'global', event, data })
  };

  // Verify paused kill-switch before enabling for test simulation
  const pausedWebhookRes = await kapsoService.processWebhookMessage({ from: '0918207786', type: 'text', text: { body: 'مرحبا' } }, {}, mockIo);
  assert.strictEqual(pausedWebhookRes.ignored, true, 'Paused Kapso should ignore webhook messages');
  kapsoService.enabled = true;

  // Intercept _postToKapso so tests run 100% offline and deterministic
  const dispatchedMessages = [];
  kapsoService._postToKapso = async (endpoint, payload) => {
    dispatchedMessages.push({ endpoint, payload });
    return {
      statusCode: 200,
      data: {
        messaging_product: 'whatsapp',
        messages: [{ id: `wamid.mock_${Date.now()}` }]
      }
    };
  };

  // Mock database
  const db = {
    users: [
      { id: 'user_cust_01', phone: '0918207786', full_name: 'علي التاورغي', role: 'customer' }
    ],
    stores: [
      { id: 'store_nalut_pizza', name: 'بيتزا الجبل نالوت', name_ar: 'بيتزا الجبل', phone: '0912345001', rating: 4.8, delivery_time_min: 15, delivery_time_max: 25 }
    ],
    drivers: [
      { id: 'driver_01', name: 'طارق الكابتن', phone: '0925550001', settled_cash_lyd: 50.00 }
    ],
    products: [
      { id: 'prod_pizza_01', store_id: 'store_nalut_pizza', name: 'بيتزا مارجريتا', name_ar: 'بيتزا مارجريتا', price: 18.00, in_stock: true, is_available: true }
    ],
    orders: [
      {
        id: 'ord_101',
        order_number: '101',
        customer_id: 'user_cust_01',
        customer_phone: '0918207786',
        store_id: 'store_nalut_pizza',
        driver_id: 'driver_01',
        status: 'pending',
        total_amount_lyd: 36.00,
        payment_method: 'cod',
        handover_code: '7788',
        items: [{ id: 'prod_pizza_01', name: 'بيتزا مارجريتا', quantity: 2, price: 18.00 }]
      },
      {
        id: 'ord_102',
        order_number: '102',
        customer_id: 'user_cust_01',
        customer_phone: '0918207786',
        store_id: 'store_nalut_pizza',
        status: 'pending',
        total_amount_lyd: 22.00,
        payment_method: 'cod',
        items: [{ id: 'prod_pizza_01', name: 'بيتزا مارجريتا', quantity: 1, price: 18.00 }]
      },
      {
        id: 'ord_completed_past',
        order_number: '99',
        customer_id: 'user_cust_01',
        customer_phone: '0918207786',
        store_id: 'store_nalut_pizza',
        driver_id: 'driver_01',
        status: 'delivered',
        total_amount_lyd: 150.00,
        payment_method: 'cod'
      }
    ]
  };

  // --------------------------------------------------------------------------
  // TEST 1: Dispatch New Order Notification to Merchant with Interactive Buttons
  // --------------------------------------------------------------------------
  console.log('\n--- 1. Testing notifyMerchantNewOrder ---');
  dispatchedMessages.length = 0;
  const dispatchRes = await kapsoService.notifyMerchantNewOrder(db.orders[0], db.stores[0]);
  assert.strictEqual(dispatchRes.success, true);
  assert.strictEqual(dispatchedMessages.length, 1);
  const sentInteractive = dispatchedMessages[0].payload;
  assert.strictEqual(sentInteractive.type, 'interactive');
  assert.strictEqual(sentInteractive.interactive.action.buttons.length, 3);
  assert.strictEqual(sentInteractive.interactive.action.buttons[0].reply.id, 'merchant_accept:ord_101:15');
  console.log('✅ Merchant order notification sent with 15m/25m/reject buttons.');

  // --------------------------------------------------------------------------
  // TEST 2: Process Webhook - Merchant Accepts Order (15 minutes)
  // --------------------------------------------------------------------------
  console.log('\n--- 2. Testing Merchant Accepts Order via Webhook ---');
  emittedEvents.length = 0;
  dispatchedMessages.length = 0;

  const acceptWebhook = {
    from: '0912345001', // Merchant phone
    type: 'interactive',
    interactive: {
      type: 'button_reply',
      button_reply: {
        id: 'merchant_accept:ord_101:15',
        title: 'قبول (15 دقيقة) ⏱️'
      }
    }
  };

  const acceptRes = await kapsoService.processWebhookMessage(acceptWebhook, db, mockIo);
  assert.strictEqual(acceptRes.success, true);
  assert.strictEqual(acceptRes.action, 'order_accepted');
  assert.strictEqual(db.orders[0].status, 'preparing');
  assert.strictEqual(db.orders[0].estimated_prep_time_minutes, 15);
  assert.ok(emittedEvents.some(e => e.event === 'order:status_changed' && e.room === 'store:store_nalut_pizza'));
  assert.ok(emittedEvents.some(e => e.event === 'kds:order_preparing'));
  console.log('✅ Order successfully transitioned to preparing with 15min prep time & sockets emitted.');

  // --------------------------------------------------------------------------
  // TEST 3: Process Webhook - Merchant Rejects Order
  // --------------------------------------------------------------------------
  console.log('\n--- 3. Testing Merchant Rejects Order via Webhook ---');
  const rejectWebhook = {
    from: '0912345001',
    type: 'interactive',
    interactive: {
      type: 'button_reply',
      button_reply: {
        id: 'merchant_reject:ord_102',
        title: 'اعتذار / رفض ❌'
      }
    }
  };

  const rejectRes = await kapsoService.processWebhookMessage(rejectWebhook, db, mockIo);
  assert.strictEqual(rejectRes.success, true);
  assert.strictEqual(rejectRes.action, 'order_rejected');
  assert.strictEqual(db.orders[1].status, 'cancelled');
  console.log('✅ Order ord_102 cancelled successfully via WhatsApp button.');

  // --------------------------------------------------------------------------
  // TEST 4: Customer Order Status Text Inquiry ("وين طلبي")
  // --------------------------------------------------------------------------
  console.log('\n--- 4. Testing Customer Order Status Inquiry ---');
  dispatchedMessages.length = 0;
  const custInquiryWebhook = {
    from: '0918207786',
    type: 'text',
    text: { body: 'السلام عليكم، وين طلبي؟' }
  };

  const statusInquiryRes = await kapsoService.processWebhookMessage(custInquiryWebhook, db, mockIo);
  assert.strictEqual(statusInquiryRes.success, true);
  assert.strictEqual(statusInquiryRes.action, 'order_status_reported');
  assert.strictEqual(dispatchedMessages.length, 1);
  const statusReply = dispatchedMessages[0].payload.text.body;
  assert.ok(statusReply.includes('#101'));
  assert.ok(statusReply.includes('بيتزا الجبل'));
  assert.ok(statusReply.includes('36 د.ل'));
  assert.ok(statusReply.includes('طارق الكابتن'));
  console.log('✅ Customer received accurate live status card with driver & restaurant info.');

  // --------------------------------------------------------------------------
  // TEST 5: Customer Location Pin Sharing
  // --------------------------------------------------------------------------
  console.log('\n--- 5. Testing Customer GPS Location Sharing ---');
  emittedEvents.length = 0;
  const locationWebhook = {
    from: '0918207786',
    type: 'location',
    location: {
      latitude: 31.8686,
      longitude: 10.9818
    }
  };

  const locationRes = await kapsoService.processWebhookMessage(locationWebhook, db, mockIo);
  assert.strictEqual(locationRes.success, true);
  assert.strictEqual(locationRes.action, 'location_updated');
  assert.strictEqual(db.orders[0].delivery_latitude, 31.8686);
  assert.strictEqual(db.orders[0].delivery_longitude, 10.9818);
  assert.ok(emittedEvents.some(e => e.event === 'driver:destination_updated'));
  console.log('✅ Customer GPS location updated active order delivery coordinates.');

  // --------------------------------------------------------------------------
  // TEST 6: Driver COD Escrow Query ("عهدة")
  // --------------------------------------------------------------------------
  console.log('\n--- 6. Testing Driver COD Escrow Query ---');
  dispatchedMessages.length = 0;
  const driverInquiryWebhook = {
    from: '0925550001',
    type: 'text',
    text: { body: 'كم رصيد عهدتي اليوم؟' }
  };

  const driverRes = await kapsoService.processWebhookMessage(driverInquiryWebhook, db, mockIo);
  assert.strictEqual(driverRes.success, true);
  assert.strictEqual(driverRes.action, 'captain_escrow_reported');
  const escrowReply = dispatchedMessages[0].payload.text.body;
  assert.ok(escrowReply.includes('150.00 د.ل'));
  assert.ok(escrowReply.includes('50.00 د.ل'));
  assert.ok(escrowReply.includes('100.00 د.ل')); // 150 - 50 = 100 due
  console.log('✅ Driver received exact COD escrow calculation in LYD (100.00 د.ل due).');

  // --------------------------------------------------------------------------
  // TEST 7: Merchant Disabling Menu Item via Text ("أوقف صنف بيتزا مارجريتا")
  // --------------------------------------------------------------------------
  console.log('\n--- 7. Testing Merchant Disabling Item via WhatsApp ---');
  emittedEvents.length = 0;
  const stopItemWebhook = {
    from: '0912345001',
    type: 'text',
    text: { body: 'أوقف صنف بيتزا مارجريتا' }
  };

  const stopItemRes = await kapsoService.processWebhookMessage(stopItemWebhook, db, mockIo);
  assert.strictEqual(stopItemRes.success, true);
  assert.strictEqual(stopItemRes.action, 'product_disabled');
  assert.strictEqual(db.products[0].is_available, false);
  assert.strictEqual(db.products[0].in_stock, false);
  assert.ok(emittedEvents.some(e => e.event === 'product:stock_changed'));
  console.log('✅ Product بيتزا مارجريتا disabled instantly in catalog and socket emitted.');

  // --------------------------------------------------------------------------
  // TEST 8: Captain Arrival Alert to Kitchen
  // --------------------------------------------------------------------------
  console.log('\n--- 8. Testing sendCaptainArrivalAlert ---');
  dispatchedMessages.length = 0;
  const arrivalAlertRes = await kapsoService.sendCaptainArrivalAlert(db.stores[0].phone, db.orders[0], db.drivers[0]);
  assert.strictEqual(arrivalAlertRes.success, true);
  const arrivalAlertText = dispatchedMessages[0].payload.text.body;
  assert.ok(arrivalAlertText.includes('7788')); // OTP
  assert.ok(arrivalAlertText.includes('طارق الكابتن'));
  console.log('✅ Merchant received captain arrival alert with handover code 7788.');

  // --------------------------------------------------------------------------
  // TEST 9: Kapso v2 Webhook Format + PG Hooks + Silent Agent Mode
  // --------------------------------------------------------------------------
  console.log('\n--- 9. Testing Kapso v2 Webhook Format & Silent Mode Hooks ---');
  dispatchedMessages.length = 0;
  let savedOrdersCount = 0;
  const kapsoV2Payload = {
    phone_number_id: '1100582179808362',
    message: {
      id: 'wamid.test_v2_loc',
      from: '218918207786',
      type: 'location',
      location: { latitude: 31.8712, longitude: 10.9855 }
    }
  };
  const v2LocRes = await kapsoService.processWebhookMessage(kapsoV2Payload, db, mockIo, {
    onOrderSave: async () => { savedOrdersCount += 1; },
    silentReplyToSender: true
  });
  assert.strictEqual(v2LocRes.success, true);
  assert.strictEqual(v2LocRes.action, 'location_updated');
  assert.strictEqual(savedOrdersCount, 1);
  assert.strictEqual(db.orders[0].delivery_lat, 31.8712);
  assert.strictEqual(dispatchedMessages.length, 0, 'Silent agent mode should not duplicate replies to sender');

  const textSilentRes = await kapsoService.processWebhookMessage(
    { message: { from: '218918207786', type: 'text', text: { body: 'مرحبا' } } },
    db,
    mockIo,
    { silentReplyToSender: true }
  );
  assert.strictEqual(textSilentRes.ignored, true);
  assert.strictEqual(dispatchedMessages.length, 0);
  console.log('✅ Kapso v2 payload parsing, PG persistence hook, and silent agent handoff verified.');

  console.log('\n================================================================');
  console.log('🎉 ALL KAPSO AI AGENT WORKFLOW & INTEGRATION TESTS PASSED 100%!');
  console.log('================================================================');
}

runKapsoAiWorkflowTests().catch(err => {
  console.error('❌ Test failed with exception:', err);
  process.exit(1);
});
