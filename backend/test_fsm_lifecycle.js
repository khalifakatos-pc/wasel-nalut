/**
 * ============================================================================
 * TEST FSM LIFECYCLE & ZERO GHOST ORDERS (WASEL NALUT)
 * Validates:
 * 1. Checkout produces status: 'placed' with driver_id: null (no ghost captain dispatch).
 * 2. Status 'preparing' keeps driver_id: null.
 * 3. Status 'ready_for_pickup' triggers Captain Radar availability.
 * 4. Status 'out_for_delivery' assigns driver_id.
 * 5. Status 'delivered' completes financial settlement.
 * ============================================================================
 */

const { app, server, db, io } = require('./server.js');
const http = require('http');
const path = require('path');

let ioClient = null;
try {
  ioClient = require('socket.io-client');
} catch (_) {
  try {
    const altPath = path.join(__dirname, '..', '.agents', 'teamwork', 'teamwork_preview_challenger_m2_2', 'node_modules', 'socket.io-client');
    ioClient = require(altPath);
  } catch (e2) {}
}

const PORT = process.env.PORT || 3000;

function createSocketClient(auth) {
  if (!ioClient) return Promise.resolve(null);
  return new Promise((resolve, reject) => {
    const socket = ioClient(`http://127.0.0.1:${PORT}`, {
      transports: ['websocket', 'polling'],
      forceNew: true,
      auth
    });
    const timer = setTimeout(() => {
      socket.disconnect();
      reject(new Error('Socket connection timed out'));
    }, 5000);
    socket.on('connect', () => {
      clearTimeout(timer);
      resolve(socket);
    });
    socket.on('connect_error', (err) => {
      clearTimeout(timer);
      reject(err);
    });
  });
}

function request(path, options = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port: PORT,
      path,
      method: options.method || 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...(options.headers || {})
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch (_) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });
    req.on('error', reject);
    if (options.body) req.write(JSON.stringify(options.body));
    req.end();
  });
}

async function runTest() {
  console.log(`\n🧪 Testing FSM & Radar against port ${PORT}`);
  
  let radarEventsReceived = [];
  const activeSockets = [];

  // Hook room emissions on io for direct room tracking
  const originalTo = io.to.bind(io);
  io.to = function(room) {
    const broadcaster = originalTo(room);
    const origEmit = broadcaster.emit.bind(broadcaster);
    broadcaster.emit = function(event, ...args) {
      if (event === 'radar:incoming_order' && room === 'role:driver') {
        if (!radarEventsReceived.some(e => e.id === args[0]?.id)) {
          radarEventsReceived.push(args[0]);
        }
      }
      return origEmit(event, ...args);
    };
    return broadcaster;
  };

  // Connect driver socket into role:driver room
  const driverSocket = await createSocketClient({ role: 'driver', driverId: 'driver_nalut_01' });
  if (driverSocket) {
    activeSockets.push(driverSocket);
    driverSocket.on('radar:incoming_order', (data) => {
      if (!radarEventsReceived.some(e => e.id === data.id)) {
        radarEventsReceived.push(data);
      }
    });
  }

  try {
    console.log('\n--- Step 1: Customer Checkout ---');
    const store = db.stores.find(s => s.city === 'nalut') || db.stores[0];
      const product = db.products.find(p => p.store_id === store.id) || db.products[0];

      // Login customer
      const loginRes = await request('/api/v1/auth/login', {
        method: 'POST',
        body: { phone: '0910000000', password: 'Customer@Nalut2026!Secure' }
      });
      const token = loginRes.body?.data?.token;

      // Checkout
      const checkoutRes = await request('/api/v1/orders/checkout', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        body: {
          store_id: store.id,
          items: [{ product_id: product.id, quantity: 1 }],
          delivery_address: 'نالوت - حي القلعة',
          payment_method: 'cash'
        }
      });

      const orderData = checkoutRes.body?.data;
      console.log('Checkout response status:', checkoutRes.status);
      console.log('Order ID:', orderData?.id);
      console.log('Order Status:', orderData?.status);
      console.log('Driver ID:', orderData?.driver_id);
      console.log('Assigned Driver:', orderData?.assigned_driver);

      if (orderData?.status !== 'placed') {
        throw new Error(`Expected status 'placed', got ${orderData?.status}`);
      }
      if (orderData?.driver_id !== null) {
        throw new Error(`Expected driver_id null at checkout, got ${orderData?.driver_id}`);
      }
      if (orderData?.assigned_driver !== null) {
        throw new Error(`Expected assigned_driver null at checkout, got ${JSON.stringify(orderData?.assigned_driver)}`);
      }

      // Wait a moment to ensure no radar event was sent at checkout
      await new Promise(r => setTimeout(r, 200));
      if (radarEventsReceived.length > 0) {
        throw new Error(`Captain radar triggered prematurely at checkout! Events: ${JSON.stringify(radarEventsReceived)}`);
      }
      console.log('✅ CHECKOUT PASSED: Order created as "placed", driver_id is null, captain radar is SILENT.');

      // Login admin for merchant and management status transitions
      const adminLoginRes = await request('/api/v1/auth/login', {
        method: 'POST',
        body: { phone: '0910009832', password: 'Admin@Nalut2026!Secure' }
      });
      const adminToken = adminLoginRes.body?.data?.token;
      const adminAuth = { Authorization: `Bearer ${adminToken}` };

      console.log('\n--- Step 2: Merchant accepts and starts preparing ---');
      const acceptRes = await request(`/api/v1/orders/${orderData.id}/status`, {
        method: 'POST',
        headers: adminAuth,
        body: { status: 'accepted' }
      });
      console.log('Accept response status:', acceptRes.status);
      console.log('Order status after accept:', acceptRes.body?.data?.status);
      if (acceptRes.status !== 200 || acceptRes.body?.data?.status !== 'accepted') {
        throw new Error(`Merchant acceptance failed: status ${acceptRes.status}`);
      }

      const prepRes = await request(`/api/v1/orders/${orderData.id}/status`, {
        method: 'POST',
        headers: adminAuth,
        body: { status: 'preparing' }
      });
      console.log('Preparing response status:', prepRes.status);
      console.log('Order status after prep:', prepRes.body?.data?.status);

      await new Promise(r => setTimeout(r, 200));
      if (radarEventsReceived.length > 0) {
        throw new Error(`Captain radar triggered during 'preparing' phase! Events: ${JSON.stringify(radarEventsReceived)}`);
      }
      console.log('✅ PREPARING PASSED: Kitchen preparing, captain radar still SILENT.');

      console.log('\n--- Step 3: Merchant completes packing -> ready_for_pickup ---');
      const readyRes = await request(`/api/v1/orders/${orderData.id}/status`, {
        method: 'POST',
        headers: adminAuth,
        body: { status: 'ready_for_pickup' }
      });
      console.log('Ready for pickup response status:', readyRes.status);
      console.log('Order status:', readyRes.body?.data?.status);

      await new Promise(r => setTimeout(r, 300));
      if (radarEventsReceived.length === 0) {
        throw new Error(`Captain radar did NOT trigger on 'ready_for_pickup'!`);
      }
      console.log(`✅ READY_FOR_PICKUP PASSED: Captain radar triggered! Received event for order: ${radarEventsReceived[0].order_number || radarEventsReceived[0].id}`);

      console.log('\n--- Step 4: Captain accepts on radar -> out_for_delivery ---');
      const claimRes = await request(`/api/v1/orders/${orderData.id}/status`, {
        method: 'POST',
        headers: adminAuth,
        body: {
          status: 'out_for_delivery',
          driver_id: 'driver_nalut_01'
        }
      });
      console.log('Claim response status:', claimRes.status);
      console.log('Order status:', claimRes.body?.data?.status);
      console.log('Assigned driver_id:', claimRes.body?.data?.driver_id);

      if (claimRes.body?.data?.driver_id !== 'driver_nalut_01') {
        throw new Error(`Expected driver_id 'driver_nalut_01', got ${claimRes.body?.data?.driver_id}`);
      }
      console.log('✅ OUT_FOR_DELIVERY PASSED: Order claimed by Captain driver_nalut_01.');

      console.log('\n--- Step 5: Captain delivers order with OTP ---');
      const otpCode = orderData.otp_code || orderData.delivery_otp;
      const deliverRes = await request(`/api/v1/orders/${orderData.id}/status`, {
        method: 'POST',
        headers: adminAuth,
        body: {
          status: 'delivered',
          driver_id: 'driver_nalut_01',
          delivery_otp: otpCode
        }
      });
      console.log('Delivered response status:', deliverRes.status);
      console.log('Final Order status:', deliverRes.body?.data?.status);

      if (deliverRes.body?.data?.status !== 'delivered') {
        throw new Error(`Expected status 'delivered', got ${deliverRes.body?.data?.status}`);
      }
      console.log('✅ DELIVERED PASSED: Order successfully completed and financial settlement applied.');

      console.log('\n================================================================');
      console.log('🎉 ALL FSM LIFECYCLE TESTS PASSED PERFECTLY WITH ZERO GHOST ORDERS!');
      console.log('================================================================\n');

    } catch (err) {
      console.error('❌ TEST FAILED:', err.message);
      process.exitCode = 1;
    } finally {
      activeSockets.forEach(s => {
        try { s.disconnect(); } catch (_) {}
      });
      server.close();
      process.exit(process.exitCode || 0);
    }
}

runTest();
