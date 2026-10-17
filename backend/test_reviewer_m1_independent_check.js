/**
 * Independent Adversarial Recheck Suite by reviewer_m1_recheck
 * Tests all 5 fixes under aggressive edge cases and attack vectors.
 */

const assert = require('assert');
const http = require('http');
const jwt = require('jsonwebtoken');

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'wasel-nalut-secure-jwt-key-2026-prod';

function makeRequest(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const payload = body !== null ? JSON.stringify(body) : null;
    const headers = { 'Content-Type': 'application/json' };
    if (payload) headers['Content-Length'] = Buffer.byteLength(payload);
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const req = http.request({
      hostname: '127.0.0.1',
      port: PORT,
      path,
      method: method.toUpperCase(),
      headers
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        let parsed = null;
        try { parsed = JSON.parse(data); } catch (_) { parsed = data; }
        resolve({ statusCode: res.statusCode, body: parsed });
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function runReviewerAdversarialCheck() {
  console.log('--- Reviewer Independent Adversarial Verification Suite ---');

  const serverModule = require('./server.js');
  const db = serverModule.db;
  const JWT_SECRET = process.env.JWT_SECRET || 'wasel-nalut-secure-jwt-key-2026-prod';

  await new Promise(r => setTimeout(r, 600));

  const adminToken = jwt.sign({ id: 'adm_1', role: 'admin' }, JWT_SECRET, { expiresIn: '1h' });
  const customerToken = jwt.sign({ id: 'cust_1', role: 'customer' }, JWT_SECRET, { expiresIn: '1h' });

  // 1. Attack on adminOverride with various payloads by customer
  console.log('\n[1] Stress-testing non-admin adminOverride forging permutations...');
  const testOrder1 = {
    id: 'ord_adv_1',
    order_number: 'ORD-ADV-1',
    customer_id: 'cust_1',
    status: 'placed',
    total_amount_lyd: 50.0,
    created_at: new Date().toISOString()
  };
  db.orders.push(testOrder1);

  const overridePayloads = [
    { adminOverride: true },
    { admin_override: true },
    { adminOverride: 'true' },
    { admin_override: 1 },
    { adminOverride: {} },
    { adminOverride: [true] }
  ];

  for (const p of overridePayloads) {
    const res = await makeRequest('POST', `/api/v1/orders/${testOrder1.id}/status`, { status: 'delivered', ...p }, customerToken);
    if (res.statusCode !== 400) {
      console.log('Unexpected response:', res.statusCode, res.body);
    }
    assert.strictEqual(res.statusCode, 400, `Expected 400 for payload ${JSON.stringify(p)}, got ${res.statusCode}`);
    assert.strictEqual(testOrder1.status, 'placed', 'Order status must not have transitioned');
  }
  console.log('✅ Non-admin adminOverride payloads strictly rejected without state change.');

  // 2. Terminal state driver reassignment check
  console.log('\n[2] Stress-testing terminal state driver reassignment...');
  const deliveredOrder = {
    id: 'ord_term_del',
    order_number: 'ORD-TERM-DEL',
    status: 'delivered',
    driver_id: 'driver_nalut_01'
  };
  const cancelledOrder = {
    id: 'ord_term_can',
    order_number: 'ORD-TERM-CAN',
    status: 'cancelled',
    driver_id: 'driver_nalut_01'
  };
  db.orders.push(deliveredOrder, cancelledOrder);

  const reassignDelRes = await makeRequest('POST', `/api/v1/orders/${deliveredOrder.id}/reassign`, { driver_id: 'driver_nalut_02' }, adminToken);
  assert.strictEqual(reassignDelRes.statusCode, 400, 'Reassigning delivered order must return 400');
  assert(reassignDelRes.body?.error.includes('لا يمكن إعادة إسناد'), 'Must return Arabic terminal guard error');

  const reassignCanRes = await makeRequest('POST', `/api/v1/orders/${cancelledOrder.id}/reassign`, { driver_id: 'driver_nalut_02' }, adminToken);
  assert.strictEqual(reassignCanRes.statusCode, 400, 'Reassigning cancelled order must return 400');
  assert(reassignCanRes.body?.error.includes('لا يمكن إعادة إسناد'), 'Must return Arabic terminal guard error');
  console.log('✅ Terminal state reassignment blocked for delivered & cancelled.');

  // 3. Driver reassignment status check: verify prevDriver status is 'online_idle'
  console.log('\n[3] Verifying previous driver reset to online_idle on valid reassignment...');
  const d1 = { id: 'drv_test_reassign_1', status: 'busy_delivery', active_order_id: 'ord_active_reassign' };
  const d2 = { id: 'drv_test_reassign_2', status: 'online_idle', active_order_id: null };
  const activeOrder = {
    id: 'ord_active_reassign',
    order_number: 'ORD-REASSIGN-ACTIVE',
    status: 'ready_for_pickup',
    driver_id: d1.id
  };
  db.drivers.push(d1, d2);
  db.orders.push(activeOrder);

  const reassignValidRes = await makeRequest('POST', `/api/v1/orders/${activeOrder.id}/reassign`, { driver_id: d2.id }, adminToken);
  assert.strictEqual(reassignValidRes.statusCode, 200, 'Valid reassignment must succeed');
  assert.strictEqual(d1.status, 'online_idle', 'Previous driver status must be online_idle');
  assert.strictEqual(d1.active_order_id, null, 'Previous driver active_order_id must be null');
  assert.strictEqual(d2.status, 'busy_delivery', 'New driver status must be busy_delivery');
  assert.strictEqual(d2.active_order_id, activeOrder.id, 'New driver active_order_id must match order id');
  assert.strictEqual(activeOrder.driver_id, d2.id, 'Order driver_id must be updated');
  console.log('✅ Driver reassignment correctly updates previous driver to online_idle.');

  // 4. Purge PIN permutations
  console.log('\n[4] Stress-testing selective purge PIN requirements...');
  const invalidPins = [
    {},
    { pin: '' },
    { pin: '1234' },
    { pin: '9832' },
    { pin: null },
    { pin: 0 },
    { pin: false }
  ];

  for (const inv of invalidPins) {
    const res = await makeRequest('POST', '/api/v1/admin/orders/purge', inv, adminToken);
    assert.strictEqual(res.statusCode, 401, `Expected 401 for purge with ${JSON.stringify(inv)}, got ${res.statusCode}`);
  }

  // Valid PIN 7788
  const validPurgeRes = await makeRequest('POST', '/api/v1/admin/orders/purge', { pin: '7788' }, adminToken);
  assert.strictEqual(validPurgeRes.statusCode, 200, 'Valid PIN must allow purge');
  assert.strictEqual(db.orders.length, 0, 'Orders array must be cleared to 0');
  console.log('✅ Selective purge strictly requires valid PIN (401 on invalid/missing).');

  // 5. Cache Eviction by UUID and order_number
  console.log('\n[5] Verifying cache eviction by both UUID and human order_number...');
  const orderA = { id: 'ord_del_uuid_1', order_number: 'WS-DEL-1', status: 'placed' };
  const orderB = { id: 'ord_del_uuid_2', order_number: 'WS-DEL-2', status: 'placed' };
  db.orders.push(orderA, orderB);

  // Delete by UUID
  const delUuidRes = await makeRequest('DELETE', `/api/v1/admin/orders/${orderA.id}`, null, adminToken);
  assert.strictEqual(delUuidRes.statusCode, 200);
  assert.strictEqual(db.orders.some(o => o.id === orderA.id), false, 'Order A must be evicted from db.orders');

  // Delete by order_number
  const delNumRes = await makeRequest('DELETE', `/api/v1/admin/orders/${orderB.order_number}`, null, adminToken);
  assert.strictEqual(delNumRes.statusCode, 200);
  assert.strictEqual(db.orders.some(o => o.order_number === orderB.order_number), false, 'Order B must be evicted from db.orders');
  console.log('✅ Cache eviction successfully evicts orders by both UUID and order_number.');

  console.log('\n🎉 ALL 5 INDEPENDENT ADVERSARIAL STRESS TESTS PASSED WITH 100% SUCCESS!');
  process.exit(0);
}

runReviewerAdversarialCheck().catch(err => {
  console.error('Adversarial check failed:', err);
  process.exit(1);
});
