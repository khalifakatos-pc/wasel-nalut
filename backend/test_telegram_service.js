const assert = require('assert');
const telegramService = require('./services/telegramService');

async function runTelegramServiceTests() {
  console.log('================================================================');
  console.log('✈️ TESTING WASEL NALUT TELEGRAM BOT API SERVICE (@WaselNalutbot)');
  console.log('================================================================');

  telegramService.enabled = true;
  telegramService.botToken = 'mock-bot-token-for-unit-test';
  telegramService.links.clear();
  telegramService.otpStore.clear();
  telegramService.authSessions.clear();
  telegramService.pendingChatSessions.clear();

  const sentTelegramMessages = [];
  const emittedEvents = [];
  const mockIo = {
    to: (room) => ({ emit: (event, data) => emittedEvents.push({ room, event, data }) }),
    emit: (event, data) => emittedEvents.push({ room: 'global', event, data }),
  };

  // Intercept _callTelegramApi for offline deterministic tests
  telegramService._callTelegramApi = async (method, payload) => {
    sentTelegramMessages.push({ method, payload });
    return { ok: true, result: { message_id: sentTelegramMessages.length } };
  };

  // 1. Phone normalization
  assert.strictEqual(telegramService.normalizePhone('0918207786'), '218918207786');
  assert.strictEqual(telegramService.normalizePhone('+218925550001'), '218925550001');
  assert.strictEqual(telegramService.normalizePhone('941122334'), '218941122334');
  console.log('✅ 1. Phone normalization passed.');

  // 2. Unlinked user requests OTP -> must require bot verification & NEVER leak OTP in response
  const unlinkedReq = await telegramService.requestOtp('0918207786', 'customer');
  assert.strictEqual(unlinkedReq.success, true);
  assert.strictEqual(unlinkedReq.mode, 'bot_verification_required');
  assert.strictEqual(unlinkedReq.otp, undefined, 'OTP must never be leaked before Telegram contact proof');
  assert.ok(unlinkedReq.deeplinkUrl.includes('WaselNalutbot?start=auth_'));

  // Trying to verify OTP before sharing contact on Telegram must fail
  const storedBeforeVerify = telegramService.otpStore.get('218918207786');
  const prematureVerify = telegramService.verifyOtp('0918207786', storedBeforeVerify.otp);
  assert.strictEqual(prematureVerify.success, false, 'Cannot verify OTP prior to bot contact share');
  console.log('✅ 2. Zero-leak unlinked OTP & pre-share lock verified.');

  // 3. Simulate /start auth_<sessionId> + Contact Share Ownership Check
  const db = {
    stores: [
      { id: 'store_nalut_ranchello', name: 'مطعم رانشيلو', phone: '0912345002', rating: 4.8, is_open: true, base_delivery_fee_lyd: 5 }
    ],
    drivers: [
      { id: 'driver_01', full_name: 'طارق الكابتن', phone: '0925550001', wallet_balance_lyd: 145, cash_in_hand_lyd: 60 }
    ],
    products: [
      { id: 'prod_1', store_id: 'store_nalut_ranchello', name: 'برغر', name_ar: 'برغر رانشيلو', in_stock: true, is_available: true }
    ],
    orders: [
      {
        id: 'ord_tg_101',
        order_number: '501',
        customer_id: 'cust_1',
        customer_phone: '0918207786',
        store_id: 'store_nalut_ranchello',
        driver_id: 'driver_01',
        status: 'placed',
        total_amount_lyd: 40,
        items: [{ name_ar: 'برغر رانشيلو', quantity: 2, price: 20 }],
        handover_code: '4499'
      }
    ],
    users: []
  };

  await telegramService.processWebhookUpdate({
    message: {
      chat: { id: 777001 },
      from: { id: 777001, first_name: 'خليفة' },
      text: `/start auth_${unlinkedReq.sessionId}`
    }
  }, db, mockIo);

  // Reject forwarded contact from another user_id
  const spoofAttempt = await telegramService.processWebhookUpdate({
    message: {
      chat: { id: 777001 },
      from: { id: 777001 },
      contact: { phone_number: '+218918207786', user_id: 999999 }
    }
  }, db, mockIo);
  assert.strictEqual(spoofAttempt.success, false);

  // Valid contact share by owner
  let linkSavedCount = 0;
  const verifyContactRes = await telegramService.processWebhookUpdate({
    message: {
      chat: { id: 777001 },
      from: { id: 777001, first_name: 'خليفة', username: 'khalifa' },
      contact: { phone_number: '+218918207786', user_id: 777001, first_name: 'خليفة' }
    }
  }, db, mockIo, {
    onSaveLink: async () => { linkSavedCount += 1; }
  });
  assert.strictEqual(verifyContactRes.success, true);
  assert.strictEqual(linkSavedCount, 1);
  assert.strictEqual(telegramService.getChatIdForPhone('0918207786'), '777001');

  // Polling session-status now shows verified=true!
  const sessionCheck = telegramService.getSessionStatus(unlinkedReq.sessionId);
  assert.strictEqual(sessionCheck.verified, true);
  const consumed = telegramService.consumeSession(unlinkedReq.sessionId);
  assert.ok(consumed && consumed.normalizedPhone === '218918207786');
  console.log('✅ 3. Telegram contact ownership verification & 1-tap auto-login passed.');

  // 4. Subsequent OTP request for linked user sends OTP directly to Telegram chat_id
  sentTelegramMessages.length = 0;
  const directOtpReq = await telegramService.requestOtp('0918207786', 'customer');
  assert.strictEqual(directOtpReq.mode, 'direct_delivery');
  assert.ok(sentTelegramMessages.some(m => m.method === 'sendMessage' && m.payload.chat_id === '777001'));
  const directStored = telegramService.otpStore.get('218918207786');
  const directVerify = telegramService.verifyOtp('0918207786', directStored.otp);
  assert.strictEqual(directVerify.success, true);
  console.log('✅ 4. Linked user direct Telegram OTP push & verification passed.');

  // 5. Merchant notification + inline callback button acceptance
  telegramService.links.set('218912345002', { phone: '218912345002', chat_id: '888002', role: 'merchant' });
  const merchPush = await telegramService.notifyMerchantNewOrder(db.orders[0], db.stores[0]);
  assert.strictEqual(merchPush.ok, true);

  let ordersSaved = 0;
  const cbRes = await telegramService.processWebhookUpdate({
    callback_query: {
      id: 'cb_1',
      data: 'merchant_accept:ord_tg_101:15',
      message: { chat: { id: 888002 }, message_id: 12 }
    }
  }, db, mockIo, {
    onOrderSave: async () => { ordersSaved += 1; }
  });
  assert.strictEqual(cbRes.success, true);
  assert.strictEqual(db.orders[0].status, 'preparing');
  assert.strictEqual(db.orders[0].prep_time_minutes, 15);
  assert.strictEqual(ordersSaved, 1);
  assert.ok(emittedEvents.some(e => e.event === 'kds:order_preparing'));
  console.log('✅ 5. Merchant inline order alert & accept callback passed.');

  // 6. Customer GPS location update & Captain COD escrow query
  await telegramService.processWebhookUpdate({
    message: {
      chat: { id: 777001 },
      from: { id: 777001 },
      location: { latitude: 31.8691, longitude: 10.9844 }
    }
  }, db, mockIo);
  assert.strictEqual(db.orders[0].delivery_lat, 31.8691);

  telegramService.links.set('218925550001', { phone: '218925550001', chat_id: '999003', role: 'captain' });
  sentTelegramMessages.length = 0;
  const capRes = await telegramService.processWebhookUpdate({
    message: { chat: { id: 999003 }, from: { id: 999003 }, text: 'كم عهدة اليوم' }
  }, db, mockIo);
  assert.strictEqual(capRes.action, 'captain_escrow_reported');
  assert.ok(sentTelegramMessages[0].payload.text.includes('60.00 د.ل'));
  console.log('✅ 6. Customer GPS sharing & Captain COD escrow inquiry passed.');

  console.log('\n🎉 ALL TELEGRAM BOT API SERVICE TESTS PASSED 100%!');
}

runTelegramServiceTests().catch(err => {
  console.error('❌ Telegram tests failed:', err);
  process.exit(1);
});
