/**
 * ============================================================================
 * PRESTO / MATAA SUPER-APP REAL-TIME FLEET & ORDER TRACKING SOCKET SERVER
 * High-concurrency WebSocket & Socket.io server with geospatial telemetry,
 * dynamic room routing, geofence proximity triggers, and resilient reconnection.
 * ============================================================================
 */

const http = require('http');
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');

// Environment Configurations
const PORT = process.env.PORT || 4001;
const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-presto-jwt-key-change-in-prod';
const PG_CONNECTION_STRING = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/presto_mataa_db';
const LOCATION_THROTTLE_MS = parseInt(process.env.LOCATION_THROTTLE_MS || '1500', 10);
const PROXIMITY_THRESHOLD_METERS = 200; // Trigger alert when driver is within 200m

// PostgreSQL Connection Pool for Telemetry Persistence
const pgPool = new Pool({
  connectionString: PG_CONNECTION_STRING,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

// In-memory runtime state caches
const driverLastUpdateMap = new Map(); // driverId -> timestamp
const driverDisconnectTimers = new Map(); // driverId -> NodeJS.Timeout
const orderActiveDrivers = new Map(); // orderId -> driverId
const latestDriverTelemetry = new Map(); // driverId -> TelemetryPayload

// Haversine Distance Calculation Formula (in meters)
function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
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
}

// Estimate ETA in minutes based on distance and average city delivery speed (25 km/h)
function estimateEtaMinutes(distanceMeters, currentSpeedKmh) {
  const effectiveSpeed = currentSpeedKmh > 10 ? currentSpeedKmh : 25; // fallback to 25 km/h
  const speedMetersPerMinute = (effectiveSpeed * 1000) / 60;
  return Math.max(1, Math.ceil(distanceMeters / speedMetersPerMinute));
}

// HTTP Server setup
const server = http.createServer((req, res) => {
  if (req.url === '/health' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        status: 'UP',
        uptime: process.uptime(),
        activeConnections: io.engine.clientsCount,
        timestamp: new Date().toISOString(),
      })
    );
    return;
  }
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not Found' }));
});

// Socket.io Server Initialization
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
    credentials: true,
  },
  pingInterval: 10000,
  pingTimeout: 5000,
  transports: ['websocket', 'polling'],
});

/**
 * Socket Authentication Middleware
 * Validates JWT token from handshake auth or query params
 */
io.use(async (socket, next) => {
  try {
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.headers?.authorization?.replace('Bearer ', '') ||
      socket.handshake.query?.token;

    if (!token) {
      return next(new Error('AUTHENTICATION_ERROR: Token missing from handshake'));
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    socket.data.user = decoded; // { id, role, phone, full_name, etc. }
    next();
  } catch (err) {
    console.error(`[Socket Auth Error] Socket ${socket.id}: ${err.message}`);
    next(new Error(`AUTHENTICATION_ERROR: Invalid or expired token: ${err.message}`));
  }
});

/**
 * Socket Connection Event Handler
 */
io.on('connection', (socket) => {
  const user = socket.data.user;
  const socketId = socket.id;

  console.log(`[Socket Connected] Socket: ${socketId} | User: ${user.id} (${user.role})`);

  // Auto-join personal notification room
  socket.join(`user:${user.id}`);

  // If user is a driver, clear any pending disconnect timers and mark online
  if (user.role === 'driver') {
    socket.join(`driver:${user.id}`);
    if (driverDisconnectTimers.has(user.id)) {
      clearTimeout(driverDisconnectTimers.get(user.id));
      driverDisconnectTimers.delete(user.id);
      console.log(`[Driver Reconnected] Cleared disconnect timer for driver ${user.id}`);
    }
  }

  // --------------------------------------------------------------------------
  // 1. DRIVER GPS TELEMETRY STREAM
  // --------------------------------------------------------------------------
  socket.on('driver:location_update', async (payload, ack) => {
    try {
      if (user.role !== 'driver' && user.role !== 'admin') {
        if (ack) ack({ success: false, error: 'Unauthorized: Driver role required' });
        return;
      }

      const driverId = payload.driver_id || user.id;
      const {
        order_id,
        latitude,
        longitude,
        heading = 0,
        speed_kmh = 0,
        accuracy_meters = 5.0,
        battery_level = 100,
        is_charging = false,
      } = payload;

      if (!latitude || !longitude) {
        if (ack) ack({ success: false, error: 'Invalid coordinates' });
        return;
      }

      // Telemetry rate-limiting check
      const now = Date.now();
      const lastUpdate = driverLastUpdateMap.get(driverId) || 0;
      if (now - lastUpdate < LOCATION_THROTTLE_MS) {
        if (ack) ack({ success: true, throttled: true });
        return;
      }
      driverLastUpdateMap.set(driverId, now);

      const telemetryData = {
        driver_id: driverId,
        order_id: order_id || null,
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        heading: parseFloat(heading),
        speed_kmh: parseFloat(speed_kmh),
        accuracy_meters: parseFloat(accuracy_meters),
        battery_level: parseInt(battery_level, 10),
        is_charging: Boolean(is_charging),
        recorded_at: new Date().toISOString(),
      };

      // Cache latest known telemetry
      latestDriverTelemetry.set(driverId, telemetryData);

      // Async DB write (Fire & Forget to maintain ultra-low latency)
      persistDriverLocation(telemetryData).catch((err) =>
        console.error(`[DB Error] Failed to persist telemetry for driver ${driverId}:`, err.message)
      );

      // Broadcast to driver's personal tracking room
      io.to(`driver:${driverId}`).emit('driver:location_changed', telemetryData);

      // If active on an order, handle order broadcasting and geofence proximity checks
      if (order_id) {
        orderActiveDrivers.set(order_id, driverId);

        // Fetch destination & store coordinates for proximity calculation
        checkOrderProximityAndBroadcast(order_id, telemetryData);
      }

      if (ack) ack({ success: true, recorded_at: telemetryData.recorded_at });
    } catch (err) {
      console.error('[driver:location_update Error]', err);
      if (ack) ack({ success: false, error: err.message });
    }
  });

  // --------------------------------------------------------------------------
  // 2. ORDER ROOM SUBSCRIPTIONS & SYNCHRONIZATION
  // --------------------------------------------------------------------------
  socket.on('order:subscribe', async ({ order_id }, ack) => {
    try {
      if (!order_id) {
        if (ack) ack({ success: false, error: 'order_id is required' });
        return;
      }

      // Join the isolated order room
      socket.join(`order:${order_id}`);
      console.log(`[Order Room] User ${user.id} (${user.role}) subscribed to order:${order_id}`);

      // Return current order snapshot & driver telemetry if available
      const snapshot = await getOrderLiveSnapshot(order_id);

      if (ack) ack({ success: true, snapshot });
    } catch (err) {
      console.error('[order:subscribe Error]', err);
      if (ack) ack({ success: false, error: err.message });
    }
  });

  socket.on('order:unsubscribe', ({ order_id }) => {
    if (order_id) {
      socket.leave(`order:${order_id}`);
      console.log(`[Order Room] User ${user.id} unsubscribed from order:${order_id}`);
    }
  });

  // --------------------------------------------------------------------------
  // 3. STORE KITCHEN ROOM SUBSCRIPTION
  // --------------------------------------------------------------------------
  socket.on('store:subscribe', ({ store_id }, ack) => {
    if (!store_id) {
      if (ack) ack({ success: false, error: 'store_id is required' });
      return;
    }

    socket.join(`store:${store_id}`);
    console.log(`[Store Room] User ${user.id} joined store:${store_id}`);
    if (ack) ack({ success: true, store_id });
  });

  // --------------------------------------------------------------------------
  // 4. ORDER STATUS TRANSITION BROADCAST (Called by APIs/Workers)
  // --------------------------------------------------------------------------
  socket.on('order:status_update', async (payload, ack) => {
    try {
      const { order_id, status, notes, driver_id, store_id, customer_id } = payload;

      const eventPayload = {
        order_id,
        status,
        notes,
        driver_id,
        updated_at: new Date().toISOString(),
      };

      // Broadcast to Order Room
      io.to(`order:${order_id}`).emit('order:status_changed', eventPayload);

      // Notify customer and store directly
      if (customer_id) io.to(`user:${customer_id}`).emit('order:status_changed', eventPayload);
      if (store_id) io.to(`store:${store_id}`).emit('order:status_changed', eventPayload);
      if (driver_id) io.to(`driver:${driver_id}`).emit('order:status_changed', eventPayload);

      console.log(`[Order Status Event] Order ${order_id} -> ${status}`);
      if (ack) ack({ success: true });
    } catch (err) {
      console.error('[order:status_update Error]', err);
      if (ack) ack({ success: false, error: err.message });
    }
  });

  // --------------------------------------------------------------------------
  // 5. DRIVER AVAILABILITY TOGGLE
  // --------------------------------------------------------------------------
  socket.on('driver:set_status', async ({ status }, ack) => {
    try {
      if (user.role !== 'driver') {
        if (ack) ack({ success: false, error: 'Unauthorized: Driver only' });
        return;
      }

      await pgPool.query('UPDATE drivers SET status = $1, updated_at = NOW() WHERE user_id = $2', [
        status,
        user.id,
      ]);

      console.log(`[Driver Status Change] Driver ${user.id} status -> ${status}`);
      if (ack) ack({ success: true, status });
    } catch (err) {
      console.error('[driver:set_status Error]', err);
      if (ack) ack({ success: false, error: err.message });
    }
  });

  // --------------------------------------------------------------------------
  // 6. DISCONNECTION & GRACE PERIOD
  // --------------------------------------------------------------------------
  socket.on('disconnect', (reason) => {
    console.log(`[Socket Disconnected] Socket: ${socketId} | User: ${user.id} | Reason: ${reason}`);

    if (user.role === 'driver') {
      // Allow 30 seconds reconnect grace period before setting driver offline in DB
      const timer = setTimeout(async () => {
        try {
          console.log(`[Driver Grace Period Expired] Marking driver ${user.id} as offline`);
          await pgPool.query(
            "UPDATE drivers SET status = 'offline', updated_at = NOW() WHERE user_id = $1 AND status != 'busy_delivery'",
            [user.id]
          );
          driverDisconnectTimers.delete(user.id);
        } catch (err) {
          console.error(`[DB Error on Driver Offline] ${err.message}`);
        }
      }, 30000);

      driverDisconnectTimers.set(user.id, timer);
    }
  });
});

/**
 * Persist GPS Telemetry into PostgreSQL PostGIS tables
 */
async function persistDriverLocation(data) {
  const pointWkt = `POINT(${data.longitude} ${data.latitude})`;

  // 1. Insert into time-series driver_locations log
  await pgPool.query(
    `INSERT INTO driver_locations 
      (driver_id, order_id, location, heading, speed_kmh, accuracy_meters, battery_level, is_charging, recorded_at)
     VALUES 
      ($1, $2, ST_SetSRID(ST_GeomFromText($3), 4326), $4, $5, $6, $7, $8, $9)`,
    [
      data.driver_id,
      data.order_id,
      pointWkt,
      data.heading,
      data.speed_kmh,
      data.accuracy_meters,
      data.battery_level,
      data.is_charging,
      data.recorded_at,
    ]
  );

  // 2. Update current snapshot in drivers table
  await pgPool.query(
    `UPDATE drivers 
     SET current_location = ST_SetSRID(ST_GeomFromText($1), 4326),
         heading = $2,
         speed_kmh = $3,
         battery_level = $4,
         is_charging = $5,
         last_location_update = $6,
         updated_at = NOW()
     WHERE id = $7 OR user_id = $7`,
    [
      pointWkt,
      data.heading,
      data.speed_kmh,
      data.battery_level,
      data.is_charging,
      data.recorded_at,
      data.driver_id,
    ]
  );
}

/**
 * Check proximity to Store or Delivery Point & Broadcast to Order Room
 */
async function checkOrderProximityAndBroadcast(orderId, telemetry) {
  try {
    const res = await pgPool.query(
      `SELECT 
        o.id, o.status,
        s.name AS store_name,
        ST_Y(s.location) AS store_lat, ST_X(s.location) AS store_lon,
        o.delivery_latitude, o.delivery_longitude,
        o.customer_id
       FROM orders o
       JOIN stores s ON o.store_id = s.id
       WHERE o.id = $1`,
      [orderId]
    );

    if (res.rows.length === 0) return;
    const order = res.rows[0];

    let targetLat, targetLon, targetLabel;

    if (order.status === 'driver_assigned' || order.status === 'driver_arrived_store') {
      targetLat = order.store_lat;
      targetLon = order.store_lon;
      targetLabel = 'store';
    } else if (order.status === 'picked_up' || order.status === 'out_for_delivery') {
      targetLat = order.delivery_latitude;
      targetLon = order.delivery_longitude;
      targetLabel = 'customer_dropoff';
    }

    let remainingDistanceMeters = null;
    let etaMinutes = null;

    if (targetLat && targetLon) {
      remainingDistanceMeters = Math.round(
        calculateHaversineDistance(telemetry.latitude, telemetry.longitude, targetLat, targetLon)
      );
      etaMinutes = estimateEtaMinutes(remainingDistanceMeters, telemetry.speed_kmh);

      // Proximity Trigger Alert (< 200m)
      if (remainingDistanceMeters <= PROXIMITY_THRESHOLD_METERS) {
        io.to(`order:${orderId}`).emit('driver:proximity_alert', {
          order_id: orderId,
          target: targetLabel,
          distance_meters: remainingDistanceMeters,
          message:
            targetLabel === 'store'
              ? 'Driver is arriving at the store for pickup'
              : 'Driver is arriving at your delivery location',
        });
      }
    }

    // Broadcast enriched telemetry to order room
    io.to(`order:${orderId}`).emit('order:driver_location', {
      order_id: orderId,
      telemetry,
      remaining_distance_meters: remainingDistanceMeters,
      eta_minutes: etaMinutes,
    });
  } catch (err) {
    console.error(`[checkOrderProximity Error] Order ${orderId}:`, err.message);
  }
}

/**
 * Retrieve current order tracking snapshot for initial room connection or sync
 */
async function getOrderLiveSnapshot(orderId) {
  const res = await pgPool.query(
    `SELECT 
      o.id AS order_id,
      o.order_number,
      o.status,
      o.delivery_address,
      o.delivery_latitude,
      o.delivery_longitude,
      s.name AS store_name,
      ST_Y(s.location) AS store_latitude,
      ST_X(s.location) AS store_longitude,
      d.id AS driver_id,
      u.full_name AS driver_name,
      u.phone AS driver_phone,
      d.vehicle_type,
      d.license_plate,
      d.rating AS driver_rating,
      d.latitude AS driver_latitude,
      d.longitude AS driver_longitude,
      d.heading AS driver_heading,
      d.speed_kmh AS driver_speed_kmh
     FROM orders o
     JOIN stores s ON o.store_id = s.id
     LEFT JOIN drivers d ON o.driver_id = d.id
     LEFT JOIN users u ON d.user_id = u.id
     WHERE o.id = $1`,
    [orderId]
  );

  if (res.rows.length === 0) return null;
  const row = res.rows[0];

  let remainingDistanceMeters = null;
  let etaMinutes = null;

  if (row.driver_latitude && row.driver_longitude && row.delivery_latitude && row.delivery_longitude) {
    remainingDistanceMeters = Math.round(
      calculateHaversineDistance(
        row.driver_latitude,
        row.driver_longitude,
        row.delivery_latitude,
        row.delivery_longitude
      )
    );
    etaMinutes = estimateEtaMinutes(remainingDistanceMeters, row.driver_speed_kmh || 20);
  }

  return {
    order_id: row.order_id,
    order_number: row.order_number,
    status: row.status,
    store: {
      name: row.store_name,
      latitude: row.store_latitude,
      longitude: row.store_longitude,
    },
    destination: {
      address: row.delivery_address,
      latitude: row.delivery_latitude,
      longitude: row.delivery_longitude,
    },
    driver: row.driver_id
      ? {
          id: row.driver_id,
          name: row.driver_name,
          phone: row.driver_phone,
          vehicle_type: row.vehicle_type,
          license_plate: row.license_plate,
          rating: row.driver_rating,
          latitude: row.driver_latitude,
          longitude: row.driver_longitude,
          heading: row.driver_heading,
          speed_kmh: row.driver_speed_kmh,
        }
      : null,
    remaining_distance_meters: remainingDistanceMeters,
    eta_minutes: etaMinutes,
  };
}

// Graceful process termination
const gracefulShutdown = async () => {
  console.log('[Socket Server] Initiating graceful shutdown...');
  io.close(() => {
    console.log('[Socket Server] Closed all active socket connections.');
  });
  await pgPool.end();
  console.log('[Socket Server] Closed database pool.');
  process.exit(0);
};

process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

// Start Server
server.listen(PORT, () => {
  console.log(`========================================================`);
  console.log(`🚀 Presto/Mataa Tracking Socket Server running on port ${PORT}`);
  console.log(`📡 Transport: WebSocket & Polling | Rate-limit: ${LOCATION_THROTTLE_MS}ms`);
  console.log(`========================================================`);
});

module.exports = { server, io, calculateHaversineDistance, estimateEtaMinutes };
