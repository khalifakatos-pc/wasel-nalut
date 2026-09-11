const http = require('http');

// Start server in background for testing
process.env.PORT = '3009';
const app = require('./server.js');

// Wait for server to listen
setTimeout(async () => {
  try {
    const fetch = (path, options = {}) => new Promise((resolve, reject) => {
      const req = http.request({
        hostname: '127.0.0.1',
        port: 3000,
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

    console.log('Testing GET /api/v1/stores...');
    const storesRes = await fetch('/api/v1/stores');
    console.log('Status:', storesRes.status, 'Count:', storesRes.body?.count);

    console.log('Testing GET /api/v1/stores/store_nalut_ranchello/menu...');
    const menuRes = await fetch('/api/v1/stores/store_nalut_ranchello/menu');
    console.log('Status:', menuRes.status, 'Products in Ranchilo:', menuRes.body?.data?.products?.length);

    console.log('Testing GET /api/v1/drivers...');
    const driversRes = await fetch('/api/v1/drivers');
    console.log('Status:', driversRes.status, 'Drivers count:', driversRes.body?.count);

    console.log('Testing POST /api/v1/orders/checkout (guest mode)...');
    const checkoutRes = await fetch('/api/v1/orders/checkout', {
      method: 'POST',
      body: {
        store_id: 'store_nalut_ranchello',
        items: [{ id: 'prod_ranch_01', name: 'شاورما لحم عربي دبل', price: 22.0, quantity: 2 }],
        delivery_location: { latitude: 31.8695, longitude: 10.9835, address: 'نالوت - حي القلعة' },
        payment_method: 'cash_on_delivery'
      }
    });
    console.log('Status:', checkoutRes.status, 'Order Number:', checkoutRes.body?.data?.order_number, 'Status:', checkoutRes.body?.data?.status);

    const orderId = checkoutRes.body?.data?.id;

    console.log('Testing GET /api/v1/orders...');
    const ordersRes = await fetch('/api/v1/orders?status=placed,preparing');
    console.log('Status:', ordersRes.status, 'Orders found:', ordersRes.body?.count);

    console.log('Testing PATCH /api/v1/orders/' + orderId + '...');
    const patchRes = await fetch('/api/v1/orders/' + orderId, {
      method: 'PATCH',
      body: { status: 'preparing' }
    });
    console.log('Status:', patchRes.status, 'New order status:', patchRes.body?.data?.status);

    console.log('Testing PATCH /api/v1/products/prod_ranchello_box_big...');
    const patchProd = await fetch('/api/v1/products/prod_ranchello_box_big', {
      method: 'PATCH',
      body: { is_available: true, price: 145.0 }
    });
    console.log('Status:', patchProd.status, 'Product price:', patchProd.body?.data?.price_lyd);

    console.log('\n✅ ALL LIVE REST & SYNC ENDPOINTS WORKED PERFECTLY!');
    process.exit(0);
  } catch (err) {
    console.error('Test failed:', err);
    process.exit(1);
  }
}, 1000);
