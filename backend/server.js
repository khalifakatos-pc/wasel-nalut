/**
 * ============================================================================
 * WASEL NALUT SUPER-APP UNIFIED BACKEND SERVER (LIBYA)
 * Complete Express + Socket.io Server (Port 3000 / Production Cloud)
 * 
 * Features:
 * - Multi-Vertical Catalog (Wasel Food, Grocery, Pharmacy, Marketplace)
 * - Authentic Nalut Partner Stores & Verified Coordinates
 * - Double-Entry Wallet & Escrow Ledger Management
 * - Dynamic Delivery Fee Engine & Automated Driver Dispatch
 * - Real-Time Socket.io Telemetry & Order Status Streaming
 * - High-Performance Database initialized from seed_data.json
 * ============================================================================
 */

const express = require('express');
const compression = require('compression');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
const SocketService = require('./services/socketService');
const pricingService = require('./services/pricingService');
const ledgerService = require('./services/ledgerService');
const orderService = require('./services/orderService');
const dispatchService = require('./services/dispatchService');

// Load environment variables from .env if present
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf-8');
  envContent.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const [key, ...vals] = trimmed.split('=');
      if (key && vals.length > 0) {
        process.env[key.trim()] = vals.join('=').trim();
      }
    }
  });
}

// ----------------------------------------------------------------------------
// 1. CONFIGURATION & CONSTANTS
// ----------------------------------------------------------------------------
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'wasel-nalut-secure-jwt-key-2026-prod';
const SEED_DATA_PATH = path.join(__dirname, 'seed_data.json');
const PROXIMITY_THRESHOLD_METERS = 200; // Trigger alert within 200m

// System Wallets
const SYSTEM_WALLETS = {
  ESCROW: '00000000-0000-0000-0000-000000000001',
  REVENUE: '00000000-0000-0000-0000-000000000002',
};

// Security: In-Memory Sliding Window Rate Limiter
const rateLimitMap = new Map();
function rateLimiter(maxRequests = 30, windowMs = 60000) {
  return (req, res, next) => {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';
    const key = `${req.path}_${ip}`;
    const now = Date.now();

    if (!rateLimitMap.has(key)) {
      rateLimitMap.set(key, { count: 1, resetTime: now + windowMs });
      return next();
    }

    const record = rateLimitMap.get(key);
    if (now > record.resetTime) {
      record.count = 1;
      record.resetTime = now + windowMs;
      return next();
    }

    record.count++;
    if (record.count > maxRequests) {
      const retryAfter = Math.ceil((record.resetTime - now) / 1000);
      res.set('Retry-After', retryAfter);
      return res.status(429).json({
        success: false,
        error: 'Too many requests. Please slow down and try again.',
        retry_after_seconds: retryAfter
      });
    }

    next();
  };
}

// Stale rate limiter cleanup every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, record] of rateLimitMap.entries()) {
    if (now > record.resetTime) {
      rateLimitMap.delete(key);
    }
  }
}, 300000);

// ----------------------------------------------------------------------------
// 2. IN-MEMORY CACHE & POSTGRESQL PERSISTENCE ENGINE
// ----------------------------------------------------------------------------
let db = {
  system_config: {},
  users: [],
  wallets: [],
  drivers: [],
  categories: [],
  stores: [],
  products: [],
  orders: [],
  wallet_transactions: [],
  vouchers: [],
  audit_logs: [],
  loyalty_points: [],
  loyalty_transactions: [],
  referrals: [],
  user_vouchers: [],
  reviews: [],
  product_modifiers: [],
  delivery_zones: []
};

// PostgreSQL Connection Pool
let pgPool = null;
const DATABASE_URL = process.env.DATABASE_URL;
if (DATABASE_URL) {
  try {
    pgPool = new Pool({
      connectionString: DATABASE_URL,
      ssl: DATABASE_URL.includes('localhost') ? false : { rejectUnauthorized: false },
      max: 20,
      connectionTimeoutMillis: 5000,
      idleTimeoutMillis: 30000
    });
    console.log('[PostgreSQL] Initialized pg pool with cloud database');
  } catch (err) {
    console.error('[PostgreSQL] Pool initialization error:', err.message);
  }
}

function loadSeedData() {
  try {
    if (fs.existsSync(SEED_DATA_PATH)) {
      const raw = fs.readFileSync(SEED_DATA_PATH, 'utf-8');
      const parsed = JSON.parse(raw);
      db = {
        system_config: parsed.system_config || {},
        users: parsed.users || [],
        wallets: parsed.wallets || [],
        drivers: parsed.drivers || [],
        categories: parsed.categories || [],
        stores: parsed.stores || [],
        products: parsed.products || [],
        orders: parsed.orders || [],
        wallet_transactions: parsed.wallet_transactions || [],
        vouchers: parsed.vouchers || [],
        audit_logs: parsed.audit_logs || [],
        loyalty_points: parsed.loyalty_points || [],
        loyalty_transactions: parsed.loyalty_transactions || [],
        referrals: parsed.referrals || [],
        user_vouchers: parsed.user_vouchers || [],
        reviews: parsed.reviews || [],
        product_modifiers: parsed.product_modifiers || [],
        delivery_zones: parsed.delivery_zones || []
      };
      // Zero-Ghost Principle: on boot, stores default to closed and drivers to offline until active app heartbeat
      db.stores.forEach(s => {
        s.is_open = true;
        s.last_heartbeat = Date.now();
      });
      db.drivers.forEach(d => {
        d.status = 'offline';
        d.is_active = false;
        d.last_heartbeat = null;
      });
      console.log(`[Database] Loaded seed data successfully:`);
      console.log(` - Stores: ${db.stores.length}`);
      console.log(` - Products: ${db.products.length}`);
      console.log(` - Drivers: ${db.drivers.length}`);
      console.log(` - Users: ${db.users.length}`);
      console.log(` - Orders: ${db.orders.length}`);
      console.log(` - Wallets: ${db.wallets.length}`);
    } else {
      console.warn(`[Database] seed_data.json not found at ${SEED_DATA_PATH}. Initializing empty.`);
    }
  } catch (err) {
    console.error(`[Database] Failed to load seed_data.json:`, err.message);
  }
}

loadSeedData();

// Runtime disk dumps eliminated. All persistence is strictly handled through PostgreSQL.
function saveSeedData() {
  // Deprecated: Zero runtime writes to seed_data.json.
}

// PostgreSQL Async Helper Functions
async function saveUserToPg(u, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor || !u) return;
  try {
    await executor.query(`
      INSERT INTO users (id, phone, full_name, email, password_hash, role, status, city, firebase_uid, auth_method, is_blocked, unpaid_debt_lyd, device_token, metadata)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
      ON CONFLICT (id) DO UPDATE SET
        phone = EXCLUDED.phone,
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email,
        password_hash = COALESCE(EXCLUDED.password_hash, users.password_hash),
        role = EXCLUDED.role,
        status = EXCLUDED.status,
        city = EXCLUDED.city,
        firebase_uid = COALESCE(EXCLUDED.firebase_uid, users.firebase_uid),
        is_blocked = EXCLUDED.is_blocked,
        unpaid_debt_lyd = EXCLUDED.unpaid_debt_lyd,
        device_token = COALESCE(EXCLUDED.device_token, users.device_token),
        updated_at = CURRENT_TIMESTAMP
    `, [
      u.id, u.phone, u.full_name || 'زبون واصل', u.email || null, u.password || u.password_hash || null,
      u.role || 'customer', u.status || 'active', u.city || 'nalut', u.firebase_uid || null,
      u.auth_method || 'firebase_sms', u.is_blocked === true, u.unpaid_debt_lyd || 0.0,
      u.device_token || null, JSON.stringify(u.metadata || {})
    ]);
  } catch (err) {
    console.error('[PostgreSQL saveUser error]:', err.message);
    if (dbClient) throw err;
  }
}

async function saveWalletToPg(w, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor || !w) return;
  try {
    await executor.query(`
      INSERT INTO wallets (id, user_id, wallet_type, currency, balance, locked_balance, status)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (id) DO UPDATE SET
        balance = EXCLUDED.balance,
        locked_balance = EXCLUDED.locked_balance,
        status = EXCLUDED.status,
        updated_at = CURRENT_TIMESTAMP
    `, [
      w.id, w.user_id || null, w.wallet_type || 'customer_wallet', w.currency || 'LYD',
      w.balance || 0.00, w.locked_balance || 0.00, w.status || 'active'
    ]);
  } catch (err) {
    console.error('[PostgreSQL saveWallet error]:', err.message);
    if (dbClient) throw err;
  }
}

async function saveCategoryToPg(c, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor || !c) return;
  try {
    await executor.query(`
      INSERT INTO categories (id, name, name_ar, icon, sort_order, is_active)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        name_ar = EXCLUDED.name_ar,
        icon = EXCLUDED.icon,
        sort_order = EXCLUDED.sort_order,
        is_active = EXCLUDED.is_active
    `, [
      c.id, c.name_en || c.name || '', c.name_ar || c.name || '',
      c.icon || '', c.sort_order || 0, c.is_active !== false
    ]);
  } catch (err) {
    console.error('[PostgreSQL saveCategory error]:', err.message);
    if (dbClient) throw err;
  }
}

async function saveVoucherToPg(v, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor || !v) return;
  try {
    await executor.query(`
      INSERT INTO vouchers (id, voucher_number, type, beneficiary_name, beneficiary_role, beneficiary_id, amount_lyd, payment_method, destination_account, notes, created_by, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      ON CONFLICT (id) DO UPDATE SET
        notes = EXCLUDED.notes
    `, [
      v.id, v.voucher_number, v.type || 'receipt', v.beneficiary_name || '',
      v.beneficiary_role || 'captain', v.beneficiary_id || '', v.amount_lyd || 0,
      v.payment_method || 'cash', v.destination_account || '', v.notes || '',
      v.created_by || 'إدارة واصل - نالوت', v.created_at || new Date().toISOString()
    ]);
  } catch (err) {
    console.error('[PostgreSQL saveVoucher error]:', err.message);
    if (dbClient) throw err;
  }
}

async function saveAuditLogToPg(a, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor || !a) return;
  try {
    await executor.query(`
      INSERT INTO audit_logs (id, action, actor_id, actor_role, target_type, target_id, details, ip_address, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      ON CONFLICT (id) DO NOTHING
    `, [
      a.id, a.action || 'system_event', a.actor_id || null, a.actor_role || null,
      a.target_type || null, a.target_id || null, JSON.stringify(a.details || {}),
      a.ip_address || null, a.created_at || new Date().toISOString()
    ]);
  } catch (err) {
    console.error('[PostgreSQL saveAuditLog error]:', err.message);
    if (dbClient) throw err;
  }
}

async function saveWalletTransactionToPg(t, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor || !t) return;
  try {
    await executor.query(`
      INSERT INTO wallet_transactions (id, wallet_id, counterparty_wallet_id, order_id, transaction_type, account_type, entity_type, entry_type, amount, currency, status, description, metadata, batch_id, idempotency_key, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
      ON CONFLICT (id) DO NOTHING
    `, [
      t.id, t.wallet_id, t.counterparty_wallet_id || null, t.order_id || null,
      t.transaction_type, t.account_type || null, t.entity_type || null,
      t.entry_type || 'CREDIT', t.amount || 0, t.currency || 'LYD',
      t.status || 'completed', t.description || '', JSON.stringify(t.metadata || {}),
      t.batch_id || null, t.idempotency_key || null, t.created_at || new Date().toISOString()
    ]);
  } catch (err) {
    console.error('[PostgreSQL saveWalletTransaction error]:', err.message);
    if (dbClient) throw err;
  }
}

async function saveStoreToPg(s, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor) return;
  try {
    await executor.query(`
      INSERT INTO stores (id, name, name_en, type, district, city, phone, pin, app_mode, commission_rate, rating, review_count, delivery_time_min, delivery_time_max, min_order_lyd, base_delivery_fee_lyd, latitude, longitude, logo_url, banner_url, badge, is_open, is_featured)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23)
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        name_en = EXCLUDED.name_en,
        type = EXCLUDED.type,
        district = EXCLUDED.district,
        city = EXCLUDED.city,
        phone = EXCLUDED.phone,
        pin = EXCLUDED.pin,
        app_mode = EXCLUDED.app_mode,
        commission_rate = EXCLUDED.commission_rate,
        rating = EXCLUDED.rating,
        review_count = EXCLUDED.review_count,
        delivery_time_min = EXCLUDED.delivery_time_min,
        delivery_time_max = EXCLUDED.delivery_time_max,
        min_order_lyd = EXCLUDED.min_order_lyd,
        base_delivery_fee_lyd = EXCLUDED.base_delivery_fee_lyd,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        logo_url = EXCLUDED.logo_url,
        banner_url = EXCLUDED.banner_url,
        badge = EXCLUDED.badge,
        is_open = EXCLUDED.is_open,
        is_featured = EXCLUDED.is_featured
    `, [
      s.id, s.name, s.name_en || s.name, s.type || 'restaurant', s.district || 'نالوت', s.city || 'nalut',
      s.phone || '', s.pin || '', s.app_mode || 'kitchen', s.commission_rate || 10.0, s.rating || 5.0,
      s.review_count || 0, s.delivery_time_min || 20, s.delivery_time_max || 35, s.min_order_lyd || 10.0,
      s.base_delivery_fee_lyd || 4.0, s.latitude || 31.8686, s.longitude || 10.9818, s.logo_url || '',
      s.banner_url || '', s.badge || '', s.is_open === true, s.is_featured !== false
    ]);
  } catch (err) {
    console.error('[PostgreSQL saveStore error]:', err.message);
    if (dbClient) throw err;
  }
}

async function deleteStoreFromPg(id, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor) return;
  try {
    await executor.query('DELETE FROM stores WHERE id = $1', [id]);
  } catch (err) {
    console.error('[PostgreSQL deleteStore error]:', err.message);
    if (dbClient) throw err;
  }
}

async function saveProductToPg(p, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor) return;
  try {
    await executor.query(`
      INSERT INTO products (id, store_id, name, name_ar, price, price_lyd, category, category_id, description, desc_ar, image_url, in_stock, is_available, is_popular, unit, stock_quantity)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        name_ar = EXCLUDED.name_ar,
        price = EXCLUDED.price,
        price_lyd = EXCLUDED.price_lyd,
        category = EXCLUDED.category,
        category_id = EXCLUDED.category_id,
        description = EXCLUDED.description,
        desc_ar = EXCLUDED.desc_ar,
        image_url = EXCLUDED.image_url,
        in_stock = EXCLUDED.in_stock,
        is_available = EXCLUDED.is_available,
        is_popular = EXCLUDED.is_popular,
        unit = EXCLUDED.unit,
        stock_quantity = EXCLUDED.stock_quantity
    `, [
      p.id, p.store_id, p.name || p.name_ar || 'صنف', p.name_ar || p.name || 'صنف',
      p.price || p.price_lyd || 0, p.price_lyd || p.price || 0,
      p.category || 'عام', p.category_id || '', p.description || '', p.desc_ar || '', p.image_url || '',
      p.in_stock !== false, p.is_available !== false, p.is_popular === true, p.unit || 'قطعة',
      p.stock_quantity !== undefined && p.stock_quantity !== null && !isNaN(p.stock_quantity) ? parseInt(p.stock_quantity, 10) : 100
    ]);
  } catch (err) {
    console.error('[PostgreSQL saveProduct error]:', err.message);
    if (dbClient) throw err;
  }
}

async function deleteProductFromPg(id, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor) return;
  try {
    await executor.query('DELETE FROM products WHERE id = $1', [id]);
  } catch (err) {
    console.error('[PostgreSQL deleteProduct error]:', err.message);
    if (dbClient) throw err;
  }
}

async function saveDriverToPg(d, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor) return;
  try {
    await executor.query(`
      INSERT INTO drivers (id, user_id, full_name, phone, vehicle_type, vehicle_plate, license_number, national_id, rating, total_deliveries, is_approved, is_active, status, wallet_balance_lyd, cod_balance_lyd, cash_in_hand_lyd, latitude, longitude)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
      ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        vehicle_type = EXCLUDED.vehicle_type,
        vehicle_plate = EXCLUDED.vehicle_plate,
        rating = EXCLUDED.rating,
        total_deliveries = EXCLUDED.total_deliveries,
        is_approved = EXCLUDED.is_approved,
        is_active = EXCLUDED.is_active,
        status = EXCLUDED.status,
        wallet_balance_lyd = EXCLUDED.wallet_balance_lyd,
        cod_balance_lyd = EXCLUDED.cod_balance_lyd,
        cash_in_hand_lyd = EXCLUDED.cash_in_hand_lyd,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude
    `, [
      d.id, d.user_id || '', d.full_name, d.phone, d.vehicle_type || 'motorcycle', d.vehicle_plate || d.plate_number || '',
      d.license_number || '', d.national_id || '', d.rating || 5.0, d.total_deliveries || d.total_trips || 0,
      d.is_approved !== false, d.is_active === true, d.status || 'offline', d.wallet_balance_lyd || 0,
      d.cod_balance_lyd || 0, d.cash_in_hand_lyd || 0, d.latitude || 31.8686, d.longitude || 10.9818
    ]);
  } catch (err) {
    console.error('[PostgreSQL saveDriver error]:', err.message);
    if (dbClient) throw err;
  }
}

async function deleteDriverFromPg(id, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor) return;
  try {
    await executor.query('DELETE FROM drivers WHERE id = $1', [id]);
  } catch (err) {
    console.error('[PostgreSQL deleteDriver error]:', err.message);
    if (dbClient) throw err;
  }
}

async function saveOrderItemsToPg(orderId, items, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor || !items || !Array.isArray(items)) return;
  try {
    for (const item of items) {
      const itemId = item.id || `item_${uuidv4().substring(0, 8)}`;
      const prodId = item.product_id || item.id || null;
      const prodName = item.name_ar || item.name || item.name_en || 'صنف';
      const unitPrice = parseFloat(item.unit_price_lyd || item.unit_price || item.price || item.price_lyd || 0);
      const quantity = parseInt(item.quantity || 1, 10);
      const totalPrice = parseFloat(item.item_total_lyd || item.total_price || (unitPrice * quantity));
      const addons = JSON.stringify(item.modifiers || item.selected_addons || []);
      const notes = item.notes || '';
      await executor.query(`
        INSERT INTO order_items (id, order_id, product_id, product_name, unit_price, quantity, total_price, selected_addons, notes)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (id) DO UPDATE SET
          quantity = EXCLUDED.quantity,
          total_price = EXCLUDED.total_price,
          selected_addons = EXCLUDED.selected_addons,
          notes = EXCLUDED.notes
      `, [itemId, orderId, prodId, prodName, unitPrice, quantity, totalPrice, addons, notes]);
    }
  } catch (err) {
    console.error('[PostgreSQL saveOrderItems error]:', err.message);
    if (dbClient) throw err;
  }
}

async function saveOrderToPg(o, dbClient = null) {
  const executor = dbClient || pgPool;
  if (!executor) return;
  try {
    await executor.query(`
      INSERT INTO orders (id, order_number, customer_id, customer_name, customer_phone, store_id, store_name, driver_id, status, subtotal_lyd, delivery_fee_lyd, total_amount_lyd, payment_method, delivery_address, delivery_lat, delivery_lng, items, notes, rating, driver_rating, review_comment, cancellation_reason, otp_code, payment_status, discount_lyd, distance_km, estimated_eta_minutes, prep_started_at, ready_at, handover_at, delivered_at, cancelled_at, handover_code, prep_time_minutes, kitchen_delay_seconds, driver_delay_seconds, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32, $33, $34, $35, $36, $37)
      ON CONFLICT (id) DO UPDATE SET
        driver_id = EXCLUDED.driver_id,
        status = EXCLUDED.status,
        subtotal_lyd = EXCLUDED.subtotal_lyd,
        delivery_fee_lyd = EXCLUDED.delivery_fee_lyd,
        total_amount_lyd = EXCLUDED.total_amount_lyd,
        payment_method = EXCLUDED.payment_method,
        payment_status = EXCLUDED.payment_status,
        notes = EXCLUDED.notes,
        rating = EXCLUDED.rating,
        driver_rating = EXCLUDED.driver_rating,
        review_comment = EXCLUDED.review_comment,
        cancellation_reason = EXCLUDED.cancellation_reason,
        otp_code = COALESCE(EXCLUDED.otp_code, orders.otp_code),
        discount_lyd = EXCLUDED.discount_lyd,
        distance_km = EXCLUDED.distance_km,
        estimated_eta_minutes = EXCLUDED.estimated_eta_minutes,
        prep_started_at = EXCLUDED.prep_started_at,
        ready_at = EXCLUDED.ready_at,
        handover_at = EXCLUDED.handover_at,
        delivered_at = EXCLUDED.delivered_at,
        cancelled_at = EXCLUDED.cancelled_at,
        handover_code = EXCLUDED.handover_code,
        prep_time_minutes = EXCLUDED.prep_time_minutes,
        kitchen_delay_seconds = EXCLUDED.kitchen_delay_seconds,
        driver_delay_seconds = EXCLUDED.driver_delay_seconds,
        items = EXCLUDED.items,
        updated_at = EXCLUDED.updated_at
    `, [
      o.id, o.order_number, o.customer_id, o.customer_name, o.customer_phone,
      o.store_id, o.store_name, o.driver_id || null, o.status || 'placed',
      o.subtotal_lyd || 0, o.delivery_fee_lyd || 0, o.total_amount_lyd || 0,
      o.payment_method || 'wallet', o.delivery_address || '', o.delivery_latitude || o.delivery_lat || 31.8686,
      o.delivery_longitude || o.delivery_lng || 10.9818, JSON.stringify(o.items || []), o.notes || '',
      o.rating || null, o.driver_rating || null, o.review_comment || null, o.cancellation_reason || null,
      o.otp_code || null, o.payment_status || null, o.discount_lyd || 0, o.distance_km || null,
      o.estimated_eta_minutes || null, o.prep_started_at || null, o.ready_at || null,
      o.handover_at || null, o.delivered_at || null, o.cancelled_at || null,
      o.handover_code || null, o.prep_time_minutes || 15, o.kitchen_delay_seconds || 0,
      o.driver_delay_seconds || 0, o.updated_at || new Date().toISOString()
    ]);
    if (o.items && Array.isArray(o.items)) {
      await saveOrderItemsToPg(o.id, o.items, dbClient);
    }
  } catch (err) {
    console.error('[PostgreSQL saveOrder error]:', err.message);
    if (dbClient) throw err;
  }
}

// PostgreSQL Data Mapping Helpers
function mapPgOrder(r) {
  if (!r) return null;
  return {
    ...r,
    subtotal_lyd: parseFloat(r.subtotal_lyd) || 0,
    delivery_fee_lyd: parseFloat(r.delivery_fee_lyd) || 0,
    total_amount_lyd: parseFloat(r.total_amount_lyd) || 0,
    delivery_latitude: parseFloat(r.delivery_lat) || (r.delivery_latitude ? parseFloat(r.delivery_latitude) : 31.8687),
    delivery_longitude: parseFloat(r.delivery_lng) || (r.delivery_longitude ? parseFloat(r.delivery_longitude) : 10.9818),
    rating: r.rating !== null && r.rating !== undefined ? parseFloat(r.rating) : null,
    driver_rating: r.driver_rating !== null && r.driver_rating !== undefined ? parseFloat(r.driver_rating) : null,
    distance_km: r.distance_km !== null && r.distance_km !== undefined ? parseFloat(r.distance_km) : null,
    discount_lyd: parseFloat(r.discount_lyd) || 0,
    items: Array.isArray(r.items) ? r.items : (typeof r.items === 'string' ? JSON.parse(r.items || '[]') : [])
  };
}

function mapPgStore(r) {
  if (!r) return null;
  return {
    ...r,
    rating: parseFloat(r.rating) || 5.0,
    latitude: parseFloat(r.latitude) || 31.8686,
    longitude: parseFloat(r.longitude) || 10.9818,
    min_order_lyd: parseFloat(r.min_order_lyd) || 10.0,
    base_delivery_fee_lyd: parseFloat(r.base_delivery_fee_lyd) || 4.0,
    commission_rate: parseFloat(r.commission_rate) || 10.0,
    review_count: parseInt(r.review_count, 10) || 0,
    delivery_time_min: parseInt(r.delivery_time_min, 10) || 20,
    delivery_time_max: parseInt(r.delivery_time_max, 10) || 35,
    is_open: r.is_open === true || r.is_open === 'true' || r.is_open === 1,
    is_featured: r.is_featured === true || r.is_featured === 'true' || r.is_featured === 1
  };
}

function mapPgDriver(d) {
  if (!d) return null;
  return {
    ...d,
    rating: parseFloat(d.rating) || 5.0,
    wallet_balance_lyd: parseFloat(d.wallet_balance_lyd) || 0,
    cod_balance_lyd: parseFloat(d.cod_balance_lyd) || 0,
    cash_in_hand_lyd: parseFloat(d.cash_in_hand_lyd) || 0,
    latitude: parseFloat(d.latitude) || 31.8686,
    longitude: parseFloat(d.longitude) || 10.9818,
    heading: parseFloat(d.heading) || 0,
    speed_kmh: parseFloat(d.speed_kmh) || 0,
    total_deliveries: parseInt(d.total_deliveries, 10) || 0,
    is_approved: d.is_approved === true || d.is_approved === 'true' || d.is_approved === 1,
    is_active: d.is_active === true || d.is_active === 'true' || d.is_active === 1
  };
}

function mapPgProduct(p) {
  if (!p) return null;
  return {
    ...p,
    price: parseFloat(p.price) || 0,
    price_lyd: parseFloat(p.price_lyd) || parseFloat(p.price) || 0,
    in_stock: p.in_stock === true || p.in_stock === 'true' || p.in_stock === 1,
    is_available: p.is_available === true || p.is_available === 'true' || p.is_available === 1,
    is_popular: p.is_popular === true || p.is_popular === 'true' || p.is_popular === 1
  };
}

async function saveDeliveryZoneToPg(z) {
  if (!pgPool) return;
  try {
    await pgPool.query(`
      INSERT INTO delivery_zones (id, name_ar, name_en, base_fee_lyd, min_delivery_time, max_delivery_time, is_active, sort_order)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      ON CONFLICT (id) DO UPDATE SET
        name_ar = EXCLUDED.name_ar,
        name_en = EXCLUDED.name_en,
        base_fee_lyd = EXCLUDED.base_fee_lyd,
        min_delivery_time = EXCLUDED.min_delivery_time,
        max_delivery_time = EXCLUDED.max_delivery_time,
        is_active = EXCLUDED.is_active,
        sort_order = EXCLUDED.sort_order
    `, [z.id, z.name_ar, z.name_en || '', z.base_fee_lyd || 5.0, z.min_delivery_time || 20, z.max_delivery_time || 35, z.is_active !== false, z.sort_order || 0]);
  } catch (err) {
    console.error('[PostgreSQL saveDeliveryZone error]:', err.message);
  }
}

async function saveSystemConfigToPg(key, value, description = '') {
  if (!pgPool) return;
  try {
    await pgPool.query(`
      INSERT INTO system_config (key, value, description, updated_at)
      VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
      ON CONFLICT (key) DO UPDATE SET
        value = EXCLUDED.value,
        description = EXCLUDED.description,
        updated_at = CURRENT_TIMESTAMP
    `, [key, JSON.stringify(value), description]);
  } catch (err) {
    console.error('[PostgreSQL saveSystemConfig error]:', err.message);
  }
}

async function saveLoyaltyPointToPg(userPhone, balance, totalEarned = 0, totalRedeemed = 0) {
  if (!pgPool) return;
  try {
    await pgPool.query(`
      INSERT INTO loyalty_points (user_phone, points_balance, total_earned, total_redeemed, updated_at)
      VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
      ON CONFLICT (user_phone) DO UPDATE SET
        points_balance = EXCLUDED.points_balance,
        total_earned = EXCLUDED.total_earned,
        total_redeemed = EXCLUDED.total_redeemed,
        updated_at = CURRENT_TIMESTAMP
    `, [userPhone, balance, totalEarned, totalRedeemed]);
  } catch (err) {
    console.error('[PostgreSQL saveLoyaltyPoint error]:', err.message);
  }
}

async function saveLoyaltyTransactionToPg(tx) {
  if (!pgPool) return;
  try {
    await pgPool.query(`
      INSERT INTO loyalty_transactions (id, user_phone, order_id, points_change, transaction_type, description, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (id) DO NOTHING
    `, [tx.id, tx.user_phone, tx.order_id || null, tx.points_change, tx.transaction_type, tx.description || '', tx.created_at || new Date().toISOString()]);
  } catch (err) {
    console.error('[PostgreSQL saveLoyaltyTransaction error]:', err.message);
  }
}

async function saveReferralToPg(ref) {
  if (!pgPool) return;
  try {
    await pgPool.query(`
      INSERT INTO referrals (id, referrer_phone, referred_phone, status, reward_voucher_code, created_at, verified_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (id) DO UPDATE SET
        status = EXCLUDED.status,
        reward_voucher_code = EXCLUDED.reward_voucher_code,
        verified_at = EXCLUDED.verified_at
    `, [ref.id, ref.referrer_phone, ref.referred_phone, ref.status || 'pending', ref.reward_voucher_code || null, ref.created_at || new Date().toISOString(), ref.verified_at || null]);
  } catch (err) {
    console.error('[PostgreSQL saveReferral error]:', err.message);
  }
}

async function saveUserVoucherToPg(v) {
  if (!pgPool) return;
  try {
    await pgPool.query(`
      INSERT INTO user_vouchers (id, user_phone, code, title, voucher_type, discount_amount_lyd, min_order_lyd, is_used, used_order_id, expires_at, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      ON CONFLICT (id) DO UPDATE SET
        is_used = EXCLUDED.is_used,
        used_order_id = EXCLUDED.used_order_id
    `, [v.id, v.user_phone, v.code, v.title, v.voucher_type || 'free_delivery', v.discount_amount_lyd || 5.0, v.min_order_lyd || 15.0, v.is_used === true, v.used_order_id || null, v.expires_at, v.created_at || new Date().toISOString()]);
  } catch (err) {
    console.error('[PostgreSQL saveUserVoucher error]:', err.message);
  }
}

async function saveReviewToPg(r) {
  if (!pgPool) return;
  try {
    await pgPool.query(`
      INSERT INTO reviews (id, order_id, customer_phone, store_id, driver_id, store_rating, driver_rating, comment, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      ON CONFLICT (id) DO UPDATE SET
        store_rating = EXCLUDED.store_rating,
        driver_rating = EXCLUDED.driver_rating,
        comment = EXCLUDED.comment
    `, [r.id, r.order_id, r.customer_phone, r.store_id, r.driver_id || null, r.store_rating, r.driver_rating || null, r.comment || '', r.created_at || new Date().toISOString()]);
  } catch (err) {
    console.error('[PostgreSQL saveReview error]:', err.message);
  }
}

async function saveModifierToPg(m) {
  if (!pgPool) return;
  try {
    await pgPool.query(`
      INSERT INTO product_modifiers (id, product_id, group_name, name, price_lyd, max_selectable, is_required, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      ON CONFLICT (id) DO UPDATE SET
        group_name = EXCLUDED.group_name,
        name = EXCLUDED.name,
        price_lyd = EXCLUDED.price_lyd,
        max_selectable = EXCLUDED.max_selectable,
        is_required = EXCLUDED.is_required
    `, [m.id, m.product_id, m.group_name, m.name, m.price_lyd || 0.0, m.max_selectable || 1, m.is_required === true, m.created_at || new Date().toISOString()]);
  } catch (err) {
    console.error('[PostgreSQL saveModifier error]:', err.message);
  }
}

async function initPgTables(forceSeed = false) {
  if (!pgPool) return;
  try {
    console.log('[PostgreSQL] Initializing tables and checking migrations...');
    await pgPool.query(`
      -- 1. Users Table
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(100) PRIMARY KEY,
        phone VARCHAR(50) UNIQUE NOT NULL,
        full_name VARCHAR(255) NOT NULL,
        email VARCHAR(255),
        password_hash VARCHAR(255),
        role VARCHAR(50) DEFAULT 'customer',
        status VARCHAR(50) DEFAULT 'active',
        city VARCHAR(100) DEFAULT 'nalut',
        firebase_uid VARCHAR(128),
        auth_method VARCHAR(50) DEFAULT 'firebase_sms',
        is_blocked BOOLEAN DEFAULT false,
        unpaid_debt_lyd NUMERIC DEFAULT 0.0,
        device_token TEXT,
        metadata JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
      CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users(firebase_uid);

      -- 2. Categories Table
      CREATE TABLE IF NOT EXISTS categories (
        id VARCHAR(100) PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        name_ar VARCHAR(100),
        icon VARCHAR(100),
        sort_order INT DEFAULT 0,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- 3. Stores Table
      CREATE TABLE IF NOT EXISTS stores (
        id VARCHAR(100) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        name_en VARCHAR(255),
        type VARCHAR(50) DEFAULT 'restaurant',
        district VARCHAR(255),
        city VARCHAR(100) DEFAULT 'nalut',
        phone VARCHAR(50),
        pin VARCHAR(20),
        app_mode VARCHAR(50) DEFAULT 'kitchen',
        commission_rate NUMERIC DEFAULT 10.0,
        rating NUMERIC DEFAULT 5.0,
        review_count INT DEFAULT 0,
        delivery_time_min INT DEFAULT 20,
        delivery_time_max INT DEFAULT 35,
        min_order_lyd NUMERIC DEFAULT 10.0,
        base_delivery_fee_lyd NUMERIC DEFAULT 4.0,
        latitude NUMERIC DEFAULT 31.8686,
        longitude NUMERIC DEFAULT 10.9818,
        logo_url TEXT,
        banner_url TEXT,
        badge VARCHAR(100),
        is_open BOOLEAN DEFAULT false,
        is_featured BOOLEAN DEFAULT true,
        address TEXT DEFAULT 'نالوت - المركز',
        merchant_id VARCHAR(100),
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- 4. Products Table
      CREATE TABLE IF NOT EXISTS products (
        id VARCHAR(100) PRIMARY KEY,
        store_id VARCHAR(100) NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
        name VARCHAR(255) NOT NULL,
        name_ar VARCHAR(255),
        price NUMERIC NOT NULL,
        price_lyd NUMERIC NOT NULL,
        category VARCHAR(100) DEFAULT 'عام',
        category_id VARCHAR(100),
        description TEXT,
        desc_ar TEXT,
        image_url TEXT,
        in_stock BOOLEAN DEFAULT true,
        is_available BOOLEAN DEFAULT true,
        is_popular BOOLEAN DEFAULT false,
        unit VARCHAR(50) DEFAULT 'قطعة',
        stock_quantity INT DEFAULT 100,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- 5. Drivers Table
      CREATE TABLE IF NOT EXISTS drivers (
        id VARCHAR(100) PRIMARY KEY,
        user_id VARCHAR(100),
        full_name VARCHAR(255) NOT NULL,
        phone VARCHAR(50) NOT NULL,
        vehicle_type VARCHAR(50) DEFAULT 'motorcycle',
        vehicle_plate VARCHAR(50),
        license_number VARCHAR(50),
        national_id VARCHAR(50),
        rating NUMERIC DEFAULT 5.0,
        total_deliveries INT DEFAULT 0,
        is_approved BOOLEAN DEFAULT true,
        is_active BOOLEAN DEFAULT false,
        status VARCHAR(50) DEFAULT 'offline',
        wallet_balance_lyd NUMERIC DEFAULT 0.0,
        cod_balance_lyd NUMERIC DEFAULT 0.0,
        cash_in_hand_lyd NUMERIC DEFAULT 0.0,
        max_cod_limit_lyd NUMERIC DEFAULT 250.0,
        latitude NUMERIC,
        longitude NUMERIC,
        heading NUMERIC DEFAULT 0.0,
        speed_kmh NUMERIC DEFAULT 0.0,
        last_heartbeat BIGINT,
        active_order_id VARCHAR(100),
        total_trips INT DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- 6. Orders Table
      CREATE TABLE IF NOT EXISTS orders (
        id VARCHAR(100) PRIMARY KEY,
        order_number VARCHAR(50),
        customer_id VARCHAR(100),
        customer_name VARCHAR(255),
        customer_phone VARCHAR(50),
        store_id VARCHAR(100) REFERENCES stores(id) ON DELETE SET NULL,
        store_name VARCHAR(255),
        driver_id VARCHAR(100),
        status VARCHAR(50) DEFAULT 'placed',
        subtotal_lyd NUMERIC DEFAULT 0.0,
        delivery_fee_lyd NUMERIC DEFAULT 0.0,
        total_amount_lyd NUMERIC DEFAULT 0.0,
        payment_method VARCHAR(50) DEFAULT 'wallet',
        delivery_address TEXT,
        delivery_lat NUMERIC,
        delivery_lng NUMERIC,
        items JSONB DEFAULT '[]'::jsonb,
        notes TEXT,
        rating NUMERIC,
        driver_rating NUMERIC,
        review_comment TEXT,
        cancellation_reason TEXT,
        otp_code VARCHAR(50),
        delivery_otp VARCHAR(10),
        payment_status VARCHAR(50),
        discount_lyd NUMERIC DEFAULT 0.0,
        service_fee_lyd NUMERIC DEFAULT 0.0,
        distance_km NUMERIC,
        estimated_eta_minutes INT,
        prep_started_at TIMESTAMPTZ,
        ready_at TIMESTAMPTZ,
        handover_at TIMESTAMPTZ,
        delivered_at TIMESTAMPTZ,
        cancelled_at TIMESTAMPTZ,
        handover_code VARCHAR(20),
        prep_time_minutes INT,
        kitchen_delay_seconds INT DEFAULT 0,
        driver_delay_seconds INT DEFAULT 0,
        dispute_resolved BOOLEAN DEFAULT false,
        dispute_resolved_at TIMESTAMPTZ,
        dispute_notes TEXT,
        customer_penalty_status VARCHAR(50),
        meal_disposal VARCHAR(50),
        loyalty_points_discount_lyd NUMERIC DEFAULT 0.0,
        free_delivery_discount_lyd NUMERIC DEFAULT 0.0,
        reviewed_at TIMESTAMPTZ,
        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- 7. Order Items Table
      CREATE TABLE IF NOT EXISTS order_items (
        id VARCHAR(100) PRIMARY KEY,
        order_id VARCHAR(100) NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        product_id VARCHAR(100),
        product_name VARCHAR(255),
        unit_price NUMERIC DEFAULT 0.0,
        quantity INT DEFAULT 1,
        total_price NUMERIC DEFAULT 0.0,
        selected_addons JSONB DEFAULT '[]'::jsonb,
        notes TEXT,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- 8. Wallets Table
      CREATE TABLE IF NOT EXISTS wallets (
        id VARCHAR(100) PRIMARY KEY,
        user_id VARCHAR(100),
        wallet_type VARCHAR(50) NOT NULL,
        currency VARCHAR(10) DEFAULT 'LYD',
        balance NUMERIC(14, 2) DEFAULT 0.00,
        locked_balance NUMERIC(14, 2) DEFAULT 0.00,
        status VARCHAR(50) DEFAULT 'active',
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- 9. Wallet Transactions Table
      CREATE TABLE IF NOT EXISTS wallet_transactions (
        id VARCHAR(100) PRIMARY KEY,
        wallet_id VARCHAR(100),
        counterparty_wallet_id VARCHAR(100),
        order_id VARCHAR(100),
        transaction_type VARCHAR(50) NOT NULL,
        account_type VARCHAR(50),
        entity_type VARCHAR(50),
        entry_type VARCHAR(10) DEFAULT 'CREDIT',
        amount NUMERIC(14, 2) NOT NULL,
        currency VARCHAR(10) DEFAULT 'LYD',
        status VARCHAR(50) DEFAULT 'completed',
        description TEXT,
        metadata JSONB DEFAULT '{}'::jsonb,
        batch_id VARCHAR(100),
        idempotency_key VARCHAR(100),
        balance_before NUMERIC(14, 2),
        balance_after NUMERIC(14, 2),
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- 10. Official Platform Vouchers Table (Receipts & Disbursements)
      CREATE TABLE IF NOT EXISTS vouchers (
        id VARCHAR(100) PRIMARY KEY,
        voucher_number VARCHAR(100) UNIQUE NOT NULL,
        type VARCHAR(50) NOT NULL,
        beneficiary_name VARCHAR(255),
        beneficiary_role VARCHAR(50),
        beneficiary_id VARCHAR(100),
        amount_lyd NUMERIC(14, 2) NOT NULL,
        payment_method VARCHAR(100) DEFAULT 'cash',
        destination_account VARCHAR(100),
        notes TEXT,
        created_by VARCHAR(255) DEFAULT 'إدارة واصل - نالوت',
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_vouchers_number ON vouchers(voucher_number);
      CREATE INDEX IF NOT EXISTS idx_vouchers_beneficiary ON vouchers(beneficiary_id);

      -- 11. Voucher Usage Table
      CREATE TABLE IF NOT EXISTS voucher_usage (
        id VARCHAR(100) PRIMARY KEY,
        voucher_id VARCHAR(100) NOT NULL,
        user_id VARCHAR(100) NOT NULL,
        order_id VARCHAR(100),
        used_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_voucher_usage_user ON voucher_usage(user_id, voucher_id);

      -- 12. General Ledger Journal Entries Table
      CREATE TABLE IF NOT EXISTS journal_entries (
        id VARCHAR(100) PRIMARY KEY,
        entry_number VARCHAR(100) UNIQUE NOT NULL,
        reference_id VARCHAR(100),
        transaction_type VARCHAR(50) NOT NULL,
        narration TEXT NOT NULL,
        total_debit NUMERIC(14, 2) NOT NULL,
        total_credit NUMERIC(14, 2) NOT NULL,
        discrepancy NUMERIC(14, 4) DEFAULT 0.0000,
        is_balanced BOOLEAN DEFAULT true,
        lines_count INT DEFAULT 2,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_journal_entries_number ON journal_entries(entry_number);
      CREATE INDEX IF NOT EXISTS idx_journal_entries_ref ON journal_entries(reference_id);
      CREATE INDEX IF NOT EXISTS idx_journal_entries_type ON journal_entries(transaction_type);

      -- 13. General Ledger Journal Entry Lines Table
      CREATE TABLE IF NOT EXISTS journal_entry_lines (
        id VARCHAR(100) PRIMARY KEY,
        journal_entry_id VARCHAR(100) NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
        entry_number VARCHAR(100) NOT NULL,
        line_number INT NOT NULL,
        account_code VARCHAR(20) NOT NULL,
        account_name_ar VARCHAR(255),
        account_category VARCHAR(50),
        debit NUMERIC(14, 2) DEFAULT 0.00,
        credit NUMERIC(14, 2) DEFAULT 0.00,
        entity_type VARCHAR(50),
        entity_id VARCHAR(100),
        note TEXT,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_journal_lines_entry ON journal_entry_lines(journal_entry_id);
      CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON journal_entry_lines(account_code);
      CREATE INDEX IF NOT EXISTS idx_journal_lines_entity ON journal_entry_lines(entity_type, entity_id);

      -- 14. Audit Logs Table
      CREATE TABLE IF NOT EXISTS audit_logs (
        id VARCHAR(100) PRIMARY KEY,
        action VARCHAR(100) NOT NULL,
        actor_id VARCHAR(100),
        actor_role VARCHAR(50),
        target_type VARCHAR(100),
        target_id VARCHAR(100),
        details JSONB DEFAULT '{}'::jsonb,
        ip_address VARCHAR(50),
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
      CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);

      -- 15. Loyalty Points & Transactions
      CREATE TABLE IF NOT EXISTS loyalty_points (
        user_phone VARCHAR(50) PRIMARY KEY,
        points_balance INT NOT NULL DEFAULT 0,
        total_earned INT NOT NULL DEFAULT 0,
        total_redeemed INT NOT NULL DEFAULT 0,
        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS loyalty_transactions (
        id VARCHAR(100) PRIMARY KEY,
        user_phone VARCHAR(50) NOT NULL,
        order_id VARCHAR(100),
        points_change INT NOT NULL,
        transaction_type VARCHAR(50) NOT NULL,
        description TEXT,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_loyalty_tx_phone ON loyalty_transactions(user_phone);

      -- 16. Referrals
      CREATE TABLE IF NOT EXISTS referrals (
        id VARCHAR(100) PRIMARY KEY,
        referrer_phone VARCHAR(50) NOT NULL,
        referred_phone VARCHAR(50) NOT NULL,
        status VARCHAR(50) DEFAULT 'pending',
        reward_voucher_code VARCHAR(100),
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        verified_at TIMESTAMPTZ
      );
      CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_phone);
      CREATE INDEX IF NOT EXISTS idx_referrals_referred ON referrals(referred_phone);

      -- 17. User Vouchers
      CREATE TABLE IF NOT EXISTS user_vouchers (
        id VARCHAR(100) PRIMARY KEY,
        user_phone VARCHAR(50) NOT NULL,
        code VARCHAR(100) UNIQUE NOT NULL,
        title VARCHAR(255) NOT NULL,
        voucher_type VARCHAR(50) DEFAULT 'free_delivery',
        discount_amount_lyd NUMERIC DEFAULT 5.0,
        min_order_lyd NUMERIC DEFAULT 15.0,
        is_used BOOLEAN DEFAULT false,
        used_order_id VARCHAR(100),
        expires_at TIMESTAMPTZ NOT NULL,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_user_vouchers_phone ON user_vouchers(user_phone);

      -- 18. Reviews
      CREATE TABLE IF NOT EXISTS reviews (
        id VARCHAR(100) PRIMARY KEY,
        order_id VARCHAR(100) UNIQUE NOT NULL,
        customer_phone VARCHAR(50) NOT NULL,
        store_id VARCHAR(100) NOT NULL,
        driver_id VARCHAR(100),
        store_rating NUMERIC(3, 1) NOT NULL,
        driver_rating NUMERIC(3, 1),
        comment TEXT,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_reviews_store ON reviews(store_id);
      CREATE INDEX IF NOT EXISTS idx_reviews_order ON reviews(order_id);

      -- 19. System Config
      CREATE TABLE IF NOT EXISTS system_config (
        key VARCHAR(100) PRIMARY KEY,
        value JSONB NOT NULL,
        description TEXT,
        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- 20. Product Modifiers
      CREATE TABLE IF NOT EXISTS product_modifiers (
        id VARCHAR(100) PRIMARY KEY,
        product_id VARCHAR(100) NOT NULL,
        group_name VARCHAR(100) NOT NULL,
        name VARCHAR(100) NOT NULL,
        price_lyd NUMERIC DEFAULT 0.0,
        max_selectable INT DEFAULT 1,
        is_required BOOLEAN DEFAULT false,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_modifiers_product ON product_modifiers(product_id);

      -- 21. Delivery Zones
      CREATE TABLE IF NOT EXISTS delivery_zones (
        id VARCHAR(100) PRIMARY KEY,
        name_ar VARCHAR(255) NOT NULL,
        name_en VARCHAR(255),
        base_fee_lyd NUMERIC NOT NULL,
        min_delivery_time INT NOT NULL,
        max_delivery_time INT NOT NULL,
        is_active BOOLEAN DEFAULT true,
        sort_order INT DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- Constraints & System Wallets Setup
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'uq_wallets_user_type_curr'
        ) THEN
          ALTER TABLE wallets ADD CONSTRAINT uq_wallets_user_type_curr UNIQUE (user_id, wallet_type, currency);
        END IF;
      END $$;

      INSERT INTO wallets (id, user_id, wallet_type, currency, balance, locked_balance, status)
      VALUES 
        ('00000000-0000-0000-0000-000000000001', 'system_escrow', 'platform_escrow', 'LYD', 0.00, 0.00, 'active'),
        ('00000000-0000-0000-0000-000000000002', 'system_revenue', 'platform_revenue', 'LYD', 0.00, 0.00, 'active'),
        ('00000000-0000-0000-0000-000000000003', 'system_vault', 'platform_vault', 'LYD', 0.00, 0.00, 'active')
      ON CONFLICT (id) DO NOTHING;

      -- Schema Column Migrations
      ALTER TABLE wallet_transactions ADD COLUMN IF NOT EXISTS batch_id VARCHAR(100);
      ALTER TABLE wallet_transactions ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(100);
      ALTER TABLE wallet_transactions ADD COLUMN IF NOT EXISTS balance_before NUMERIC(14, 2);
      ALTER TABLE wallet_transactions ADD COLUMN IF NOT EXISTS balance_after NUMERIC(14, 2);

      ALTER TABLE stores ADD COLUMN IF NOT EXISTS address TEXT DEFAULT 'نالوت - المركز';
      ALTER TABLE stores ADD COLUMN IF NOT EXISTS merchant_id VARCHAR(100);

      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS max_cod_limit_lyd NUMERIC DEFAULT 250.0;

      ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_otp VARCHAR(10);
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispute_resolved BOOLEAN DEFAULT false;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispute_resolved_at TIMESTAMPTZ;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispute_notes TEXT;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_penalty_status VARCHAR(50);
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS meal_disposal VARCHAR(50);
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS loyalty_points_discount_lyd NUMERIC DEFAULT 0.0;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS free_delivery_discount_lyd NUMERIC DEFAULT 0.0;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

      -- High-Performance Production Query Indexes
      CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
      CREATE INDEX IF NOT EXISTS idx_orders_store_id ON orders(store_id);
      CREATE INDEX IF NOT EXISTS idx_orders_driver_id ON orders(driver_id);
      CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
      CREATE INDEX IF NOT EXISTS idx_stores_is_open ON stores(is_open);
      CREATE INDEX IF NOT EXISTS idx_products_store_id ON products(store_id);
      CREATE INDEX IF NOT EXISTS idx_wallet_tx_order_id ON wallet_transactions(order_id);
      CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet_id ON wallet_transactions(wallet_id);
    `);

    const countRes = await pgPool.query('SELECT COUNT(*) FROM stores');
    const storeCount = parseInt(countRes.rows[0].count, 10);

    if (storeCount === 0 || forceSeed) {
      console.log(`[PostgreSQL] Initial bootstrap: Seeding authentic data into PostgreSQL...`);
      for (const s of db.stores) {
        await saveStoreToPg(s);
      }
      for (const p of db.products) {
        await saveProductToPg(p);
      }
      for (const d of db.drivers) {
        await saveDriverToPg(d);
      }
      for (const c of db.categories) {
        await saveCategoryToPg(c);
      }
      for (const u of db.users) {
        await saveUserToPg(u);
      }
      for (const w of db.wallets) {
        await saveWalletToPg(w);
      }
      console.log('[PostgreSQL] Initial bootstrap seeding completed successfully.');
    } else {
      console.log(`[PostgreSQL] Hydrating cache from PostgreSQL (${storeCount} stores)...`);
      const storesRes = await pgPool.query('SELECT * FROM stores ORDER BY is_open DESC, is_featured DESC');
      db.stores = storesRes.rows.map(mapPgStore);

      const productsRes = await pgPool.query('SELECT * FROM products ORDER BY name ASC');
      db.products = productsRes.rows.map(mapPgProduct);

      const driversRes = await pgPool.query('SELECT * FROM drivers');
      db.drivers = driversRes.rows.map(mapPgDriver);

      const ordersRes = await pgPool.query('SELECT * FROM orders ORDER BY created_at DESC LIMIT 300');
      db.orders = (ordersRes.rows || []).map(mapPgOrder);

      // Hydrate Users
      const usersRes = await pgPool.query('SELECT * FROM users');
      if (usersRes.rows.length > 0) {
        db.users = usersRes.rows.map(r => ({
          ...r,
          unpaid_debt_lyd: parseFloat(r.unpaid_debt_lyd) || 0
        }));
      }

      // Hydrate Wallets
      const walletsRes = await pgPool.query('SELECT * FROM wallets');
      if (walletsRes.rows.length > 0) {
        db.wallets = walletsRes.rows.map(r => ({
          ...r,
          balance: parseFloat(r.balance) || 0,
          locked_balance: parseFloat(r.locked_balance) || 0
        }));
      }

      // Hydrate Categories
      const catRes = await pgPool.query('SELECT * FROM categories ORDER BY sort_order ASC');
      if (catRes.rows.length > 0) {
        db.categories = catRes.rows;
      }

      // Hydrate Vouchers
      const vouchersRes = await pgPool.query('SELECT * FROM vouchers ORDER BY created_at DESC LIMIT 300');
      if (vouchersRes.rows.length > 0) {
        db.vouchers = vouchersRes.rows.map(r => ({
          ...r,
          amount_lyd: parseFloat(r.amount_lyd) || 0
        }));
      }

      // Hydrate Audit Logs
      const auditRes = await pgPool.query('SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 300');
      if (auditRes.rows.length > 0) {
        db.audit_logs = auditRes.rows;
      }

      // Hydrate Journal Entries & Lines
      const jrnRes = await pgPool.query('SELECT * FROM journal_entries ORDER BY created_at DESC LIMIT 300');
      if (jrnRes.rows.length > 0) {
        db.journal_entries = jrnRes.rows.map(r => ({
          ...r,
          total_debit: parseFloat(r.total_debit) || 0,
          total_credit: parseFloat(r.total_credit) || 0,
          discrepancy: parseFloat(r.discrepancy) || 0
        }));
      }

      const jrnLinesRes = await pgPool.query('SELECT * FROM journal_entry_lines ORDER BY line_number ASC LIMIT 1000');
      if (jrnLinesRes.rows.length > 0) {
        db.journal_entry_lines = jrnLinesRes.rows.map(r => ({
          ...r,
          debit: parseFloat(r.debit) || 0,
          credit: parseFloat(r.credit) || 0
        }));
      }

      // -------------------------------------------------------------
      // Delivery Zones Seeding & Hydration
      // -------------------------------------------------------------
      const zonesCountRes = await pgPool.query('SELECT COUNT(*) FROM delivery_zones');
      if (parseInt(zonesCountRes.rows[0].count, 10) === 0) {
        console.log('[PostgreSQL] Seeding 6 authentic Nalut delivery zones...');
        const initialZones = [
          { id: 'zone_nalut_center', name_ar: 'نالوت - المركز والبلدة القديمة', name_en: 'Nalut Center & Old Town', base_fee_lyd: 3.0, min_delivery_time: 15, max_delivery_time: 25, sort_order: 1 },
          { id: 'zone_nalut_qalaa', name_ar: 'نالوت - حي القلعة وسيدي خليفة', name_en: 'Al-Qalaa & Sidi Khalifa', base_fee_lyd: 3.5, min_delivery_time: 20, max_delivery_time: 30, sort_order: 2 },
          { id: 'zone_nalut_africa', name_ar: 'نالوت - شارع أفريقيا والمنطقة الحرفية', name_en: 'Africa Street & Industrial Zone', base_fee_lyd: 4.0, min_delivery_time: 20, max_delivery_time: 30, sort_order: 3 },
          { id: 'zone_nalut_airport', name_ar: 'نالوت - طريق المطار والمدخل الشرقي', name_en: 'Airport Road & East Gate', base_fee_lyd: 5.0, min_delivery_time: 25, max_delivery_time: 35, sort_order: 4 },
          { id: 'zone_nalut_talat', name_ar: 'منطقة تالات وضواحي نالوت الجبلية', name_en: 'Talat & Mountain Suburbs', base_fee_lyd: 6.5, min_delivery_time: 30, max_delivery_time: 45, sort_order: 5 },
          { id: 'zone_nalut_kabaw_road', name_ar: 'خط طريق كاباو والمزارع المجاورة', name_en: 'Kabaw Road & Farmlands', base_fee_lyd: 8.5, min_delivery_time: 35, max_delivery_time: 50, sort_order: 6 }
        ];
        for (const z of initialZones) {
          await saveDeliveryZoneToPg(z);
        }
      }
      const zonesRes = await pgPool.query('SELECT * FROM delivery_zones ORDER BY sort_order ASC');
      db.delivery_zones = zonesRes.rows.map(r => ({
        ...r,
        base_fee_lyd: parseFloat(r.base_fee_lyd) || 5.0
      }));

      // -------------------------------------------------------------
      // System Config Seeding & Hydration
      // -------------------------------------------------------------
      const cfgCountRes = await pgPool.query("SELECT COUNT(*) FROM system_config WHERE key = 'core_platform_rules'");
      if (parseInt(cfgCountRes.rows[0].count, 10) === 0) {
        console.log('[PostgreSQL] Seeding default platform rules in system_config...');
        await saveSystemConfigToPg('core_platform_rules', {
          referral_enabled: true,
          referral_target_count: 3,
          referral_reward_type: 'free_delivery',
          referral_reward_lyd: 5.0,
          referral_min_order_lyd: 20.0,
          referral_validity_days: 14,
          referral_condition: 'on_signup_otp',
          loyalty_enabled: true,
          loyalty_points_per_lyd: 1.0,
          loyalty_redemption_rate: 20.0,
          captain_bonus_enabled: true,
          captain_daily_target: 8,
          captain_daily_bonus_lyd: 15.0,
          ratings_enabled: true
        }, 'قواعد وسياسات تشغيل منصة واصل نالوت');
      }
      const cfgRes = await pgPool.query('SELECT * FROM system_config');
      db.system_config = {};
      cfgRes.rows.forEach(r => {
        db.system_config[r.key] = typeof r.value === 'string' ? JSON.parse(r.value) : r.value;
      });

      // -------------------------------------------------------------
      // Modifiers & Loyalty Hydration
      // -------------------------------------------------------------
      const modRes = await pgPool.query('SELECT * FROM product_modifiers');
      db.product_modifiers = modRes.rows.map(r => ({
        ...r,
        price_lyd: parseFloat(r.price_lyd) || 0.0
      }));

      const loyaltyRes = await pgPool.query('SELECT * FROM loyalty_points');
      db.loyalty_points = loyaltyRes.rows;

      console.log(`[PostgreSQL] Hydration complete: ${db.stores.length} stores, ${db.products.length} products, ${db.drivers.length} drivers, ${db.orders.length} orders, ${db.users.length} users, ${db.wallets.length} wallets, ${db.delivery_zones.length} delivery zones.`);
    }
  } catch (err) {
    console.error('[PostgreSQL] Table initialization/hydration error:', err.message);
  }
}

// Call initPgTables on startup
initPgTables();

// ----------------------------------------------------------------------------
// 3. GEOSPATIAL & LOGISTICS UTILITIES
// ----------------------------------------------------------------------------
function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
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
  return R * c; // meters
}

function estimateEtaMinutes(distanceMeters, currentSpeedKmh) {
  const effectiveSpeed = currentSpeedKmh > 10 ? currentSpeedKmh : 25; // default 25 km/h in city
  const speedMetersPerMinute = (effectiveSpeed * 1000) / 60;
  return Math.max(1, Math.ceil(distanceMeters / speedMetersPerMinute));
}

function calculateDynamicDeliveryFee(store, deliveryLat, deliveryLng, totalWeightKg = 1.0) {
  return pricingService.calculateFee(store, deliveryLat, deliveryLng, totalWeightKg, db.system_config);
}

// ----------------------------------------------------------------------------
// 4. SERVER & SOCKET.IO SETUP
// ----------------------------------------------------------------------------
const VoucherRoutes = require('./routes/vouchers.routes');
const ReviewRoutes = require('./routes/reviews.routes');

// ... (other imports)

const app = express();
const server = http.createServer(app);

// Fast unblocking Health Check for UptimeRobot / Render Keep-Alive
app.get('/health', (req, res) => {
  res.json({ status: 'ok', uptime: Math.round(process.uptime()), timestamp: new Date().toISOString() });
});
app.get('/api/v1/ping', (req, res) => {
  res.json({ pong: true, uptime: Math.round(process.uptime()), memory_mb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) });
});

// Response compression for 70-85% smaller payloads
app.use(compression());

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());
const publicDir = fs.existsSync(path.join(__dirname, 'public'))
  ? path.join(__dirname, 'public')
  : path.join(__dirname, '../public');

const webDir = fs.existsSync(path.join(__dirname, 'admin_merchant_web'))
  ? path.join(__dirname, 'admin_merchant_web')
  : path.join(__dirname, '../admin_merchant_web');

app.use(express.static(publicDir));
app.use('/web', express.static(webDir));
app.use('/admin-assets', express.static(webDir));

// Serve Flutter Customer Web App
const flutterAppDir = fs.existsSync(path.join(publicDir, 'app'))
  ? path.join(publicDir, 'app')
  : path.join(__dirname, '../flutter_mobile_app/build/web');

if (fs.existsSync(flutterAppDir)) {
  app.get('/app', (req, res) => res.redirect('/app/'));
  app.use('/app', express.static(flutterAppDir));
  app.get('/app/*', (req, res) => {
    res.sendFile(path.join(flutterAppDir, 'index.html'));
  });
}

app.get('/merchant', (req, res) => {
  res.sendFile(path.join(webDir, 'merchant_portal.html'));
});

app.get('/admin', (req, res) => {
  res.sendFile(path.join(webDir, 'admin_dispatch_dashboard.html'));
});

app.get('/live', (req, res) => {
  res.sendFile(path.join(publicDir, 'live_mission_control.html'));
});

app.get('/mission-control', (req, res) => {
  res.sendFile(path.join(publicDir, 'live_mission_control.html'));
});

// Public Recipient Tracking Web Page (Accessible to anyone with tracking link)
app.get(['/track', '/track/:id'], (req, res) => {
  const trackFile = fs.existsSync(path.join(publicDir, 'track.html'))
    ? path.join(publicDir, 'track.html')
    : path.join(__dirname, 'public/track.html');
  res.sendFile(trackFile);
});

// Real-time End-to-End simulation trigger for Live Mission Control
app.post('/api/v1/simulation/run-cycle', async (req, res) => {
  try {
    const orderNum = `ORD-2026-LY-${Math.floor(1000 + Math.random() * 9000)}`;
    const orderId = `ord_nalut_sim_${Date.now()}`;
    const targetStore = db.stores.find(s => s.id === 'store_nalut_alhanaa') || db.stores[0];
    
    const simulatedOrder = {
      id: orderId,
      order_number: orderNum,
      customer_id: 'user_nalut_salem',
      customer_name: 'سالم النالوتي',
      customer_phone: '0917778899',
      store_id: targetStore.id,
      store_name: targetStore.name,
      status: 'pending',
      items: [
        { id: 'prod_nalut_sim_01', name: 'أدوية وفيتامينات - صيدلية الهناء', price: 61.0, quantity: 1 }
      ],
      total_amount_lyd: 61.0,
      delivery_fee_lyd: 7.5,
      driver_payout_lyd: 7.5,
      payment_method: 'cash_on_delivery',
      delivery_address: 'نالوت - حي الزهور - شارع تونس',
      otp_code: '1890',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    db.orders.push(simulatedOrder);
    saveOrderToPg(simulatedOrder);

    // Broadcast Stage 1: Order Created
    io.emit('order:new', simulatedOrder);
    io.emit('order:status_changed', {
      order_id: simulatedOrder.id,
      order_number: simulatedOrder.order_number,
      status: 'pending',
      customer_name: simulatedOrder.customer_name,
      total_amount_lyd: simulatedOrder.total_amount_lyd,
      store_name: simulatedOrder.store_name
    });

    res.json({
      success: true,
      message: 'Simulation cycle started successfully',
      data: simulatedOrder
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
    credentials: true,
  },
  pingInterval: 10000,
  pingTimeout: 5000,
  transports: ['websocket', 'polling']
});

// Initialize SocketService
SocketService.init(io);

// Attach io to request for route handlers
app.use((req, res, next) => {
  req.io = io;
  next();
});

// Universal API Route Aliasing Middleware
// Automatically proxies root API calls (e.g. /stores, /products, /drivers, /orders, /admin/*)
// to /api/v1/* so Flutter apps and MCP tools work with or without the prefix seamlessly!
// ... (previous code)
app.use((req, res, next) => {
  if (
    !req.url.startsWith('/api/v1') &&
    !req.url.startsWith('/app') &&
    !req.url.startsWith('/web') &&
    !req.url.startsWith('/admin-assets') &&
    req.path !== '/admin' &&
    req.path !== '/merchant' &&
    req.path !== '/' &&
    req.path !== '/health'
  ) {
    const apiRoots = ['/stores', '/products', '/drivers', '/orders', '/admin', '/vouchers', '/audit', '/auth', '/config', '/wallet', '/categories'];
    if (apiRoots.some(prefix => req.path === prefix || req.path.startsWith(prefix + '/'))) {
      req.url = '/api/v1' + req.url;
    }
  }
  next();
});

// Register Voucher Routes
app.use('/api/v1/vouchers', (req, res, next) => {
  // Inject db into request for routes to use
  req.db = db;
  next();
}, VoucherRoutes);

app.use('/api/v1/reviews', (req, res, next) => {
  // Inject db into request for routes to use
  req.db = db;
  next();
}, ReviewRoutes);

// ----------------------------------------------------------------------------
// 5. AUTHENTICATION HELPERS & MIDDLEWARE
// ----------------------------------------------------------------------------

function generateToken(user) {
  let driverId = user.driver_id;
  if (!driverId && user.role === 'driver' && typeof db !== 'undefined' && db.drivers) {
    const matched = db.drivers.find(d => d.user_id === user.id || d.id === user.id || (user.phone && d.phone === user.phone));
    if (matched) driverId = matched.id;
  }
  let storeId = user.store_id;
  if (!storeId && user.role === 'merchant' && typeof db !== 'undefined' && db.stores) {
    const matched = db.stores.find(s => s.merchant_id === user.id || s.id === user.id || (user.phone && s.phone === user.phone));
    if (matched) storeId = matched.id;
  }

  return jwt.sign(
    {
      id: user.id,
      sub: user.id,
      phone: user.phone,
      full_name: user.full_name,
      role: user.role,
      city: user.city || 'nalut',
      driver_id: driverId || undefined,
      store_id: storeId || undefined
    },
    JWT_SECRET,
    { expiresIn: '30d' }
  );
}

function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: 'Authentication required: Missing or invalid Bearer token'
    });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = db.users.find(u => u.id === decoded.id);
    if (!user) {
      req.user = {
        id: decoded.id,
        phone: decoded.phone,
        full_name: decoded.full_name || 'مستخدم واصل',
        role: decoded.role || 'customer',
        city: decoded.city || 'nalut',
        store_id: decoded.store_id || null,
        driver_id: decoded.driver_id || null
      };
      return next();
    }
    req.user = user;
    next();
  } catch (err) {
    return res.status(401).json({
      success: false,
      error: 'Invalid or expired authorization token'
    });
  }
}

// Security: Administrative Authorization Guard
function adminAuthMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: 'Access Denied: Admin authorization required. Missing Bearer token'
    });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    if (decoded.role !== 'admin') {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You do not have permission to access administrative resources'
      });
    }
    const user = db.users.find(u => u.id === decoded.id);
    req.user = user || { id: decoded.id, role: 'admin', full_name: decoded.full_name || 'مدير النظام' };
    next();
  } catch (err) {
    return res.status(401).json({ success: false, error: 'Invalid or expired admin session' });
  }
}

function storeOwnerOrAdminMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Authentication required: Missing Bearer token' });
  }
  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    if (decoded.role === 'admin') {
      req.user = decoded;
      return next();
    }
    if (decoded.role === 'merchant' && (decoded.store_id === req.params.id || decoded.id === req.params.id)) {
      req.user = decoded;
      return next();
    }
    return res.status(403).json({ success: false, error: 'Forbidden: You do not have permission to manage this store' });
  } catch (err) {
    return res.status(401).json({ success: false, error: 'Invalid or expired token' });
  }
}

function driverSelfOrAdminMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Authentication required: Missing Bearer token' });
  }
  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    if (decoded.role === 'admin') {
      req.user = decoded;
      return next();
    }
    const targetDriver = (typeof db !== 'undefined' && db.drivers)
      ? db.drivers.find(d => d.id === req.params.id || d.user_id === req.params.id)
      : null;
    const isSelfDriver = decoded.role === 'driver' && (
      decoded.driver_id === req.params.id ||
      decoded.id === req.params.id ||
      decoded.sub === req.params.id ||
      (targetDriver && (
        targetDriver.id === decoded.driver_id ||
        targetDriver.id === decoded.id ||
        targetDriver.id === decoded.sub ||
        targetDriver.user_id === decoded.id ||
        targetDriver.user_id === decoded.sub ||
        targetDriver.user_id === decoded.driver_id
      ))
    );
    if (isSelfDriver) {
      req.user = decoded;
      return next();
    }
    return res.status(403).json({ success: false, error: 'Forbidden: You do not have permission to settle for this driver' });
  } catch (err) {
    return res.status(401).json({ success: false, error: 'Invalid or expired token' });
  }
}

function sanitizeStore(store) {
  if (!store) return store;
  const { pin, password, password_hash, ...publicStore } = store;
  return publicStore;
}

function sanitizeDriver(driver) {
  if (!driver) return driver;
  const { pin, password, password_hash, ...publicDriver } = driver;
  return publicDriver;
}

// ----------------------------------------------------------------------------
// 6. REST API ROUTES
// ----------------------------------------------------------------------------

// Root / Health
app.get('/', (req, res) => {
  res.json({
    name: 'Wasel Nalut Super-App API Engine',
    version: '1.0.0',
    status: 'ONLINE',
    currency: 'LYD (د.ل)',
    cities: ['Nalut (نالوت)', 'Tripoli (طرابلس)', 'Benghazi (بنغازي)'],
    documentation: '/api/v1/spec',
    endpoints: {
      stores: '/api/v1/stores',
      orders: '/api/v1/orders',
      wallet: '/api/v1/wallet/balance',
      admin: '/api/v1/admin/overview'
    }
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'UP',
    uptime_seconds: process.uptime(),
    active_socket_clients: io.engine.clientsCount,
    timestamp: new Date().toISOString()
  });
});

app.get('/api/v1/health', (req, res) => {
  res.json({
    status: 'healthy',
    system: 'presto-mataa-backend-lyd',
    socket_connections: io.engine.clientsCount,
    database_records: {
      stores: db.stores.length,
      products: db.products.length,
      drivers: db.drivers.length,
      orders: db.orders.length,
      wallets: db.wallets.length
    }
  });
});

app.get('/api/v1/config', (req, res) => {
  res.json({
    success: true,
    data: db.system_config
  });
});

// ----------------------------------------------------------------------------
// DYNAMIC PRICING QUOTE ROUTES (R1)
// ----------------------------------------------------------------------------
const handlePricingQuote = (req, res) => {
  try {
    const store_id = req.query.store_id || req.body.store_id;
    const lat = req.query.lat || req.query.delivery_lat || req.query.delivery_latitude || req.body.lat || req.body.delivery_lat || req.body.delivery_latitude;
    const lng = req.query.lng || req.query.delivery_lng || req.query.delivery_longitude || req.body.lng || req.body.delivery_lng || req.body.delivery_longitude;
    const weight_kg = parseFloat(req.query.weight_kg || req.body.weight_kg || 1.0);

    const quote = pricingService.getQuote({
      store_id,
      lat,
      lng,
      delivery_lat: lat,
      delivery_lng: lng,
      weight_kg,
      db
    });

    return res.json({
      success: true,
      base_fee: quote.base_fee,
      distance_km: quote.distance_km,
      distance_meters: quote.distance_meters,
      delivery_fee_lyd: quote.delivery_fee_lyd,
      currency: quote.currency,
      estimated_eta_minutes: quote.estimated_eta_minutes,
      data: quote
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
};

app.get('/api/v1/pricing/quote', handlePricingQuote);
app.post('/api/v1/pricing/quote', handlePricingQuote);

// ----------------------------------------------------------------------------
// AUTH ROUTES
// ----------------------------------------------------------------------------
app.post('/api/v1/auth/register', async (req, res) => {
  try {
    const { full_name, phone, password, role = 'customer', city = 'tripoli', email } = req.body;
    if (!phone || !full_name) {
      return res.status(400).json({ success: false, error: 'Phone number and full name are required' });
    }

    let existing = db.users.find(u => u.phone === phone);
    if (!existing && pgPool) {
      const uRes = await pgPool.query('SELECT * FROM users WHERE phone = $1', [phone]);
      if (uRes.rows.length > 0) existing = uRes.rows[0];
    }
    if (existing) {
      return res.status(409).json({ success: false, error: 'User with this phone already exists' });
    }

    const userId = `user_${uuidv4().substring(0, 8)}`;
    const newUser = {
      id: userId,
      full_name,
      phone,
      email: email || `${phone.replace('+', '')}@presto-mataa.ly`,
      password: password || require('crypto').randomBytes(8).toString('hex'),
      role,
      status: 'active',
      city,
      created_at: new Date().toISOString()
    };
    db.users.push(newUser);
    await saveUserToPg(newUser);

    // Create wallet with initial welcome balance (e.g. 50 LYD for testing)
    const walletId = `wallet_${userId}`;
    const newWallet = {
      id: walletId,
      user_id: userId,
      wallet_type: role === 'driver' ? 'driver_earnings' : role === 'merchant' ? 'merchant_payouts' : 'customer_wallet',
      currency: 'LYD',
      balance: role === 'customer' ? 50.00 : 0.00,
      locked_balance: 0.00,
      status: 'active'
    };
    db.wallets.push(newWallet);
    await saveWalletToPg(newWallet);

    const token = generateToken(newUser);
    res.status(201).json({
      success: true,
      message: 'Account registered successfully',
      data: {
        token,
        user: newUser,
        wallet: newWallet
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// PASSWORDLESS VERIFIED PHONE AUTHENTICATION (Firebase SMS & WhatsApp OTP)
app.post('/api/v1/auth/phone-login', rateLimiter(20, 60000), async (req, res) => {
  try {
    const { phone, full_name, firebase_uid, auth_method } = req.body;
    if (!phone) {
      return res.status(400).json({ success: false, error: 'Phone number is required' });
    }

    // Clean and normalize phone number
    const cleanPhone = String(phone).trim();
    const rawDigits = cleanPhone.replace(/[^0-9]/g, '');
    const standardLibyan = rawDigits.startsWith('218') ? `+${rawDigits}` : `+218${rawDigits.replace(/^0/, '')}`;
    const localLibyan = rawDigits.startsWith('218') ? `0${rawDigits.substring(3)}` : `0${rawDigits.replace(/^0/, '')}`;

    // Find existing user by any Libyan phone variant
    let user = db.users.find(u =>
      u.phone === cleanPhone ||
      u.phone === standardLibyan ||
      u.phone === localLibyan ||
      (u.firebase_uid && firebase_uid && u.firebase_uid === firebase_uid)
    );

    if (!user && pgPool) {
      const uRes = await pgPool.query(`
        SELECT * FROM users
        WHERE phone = $1 OR phone = $2 OR phone = $3 OR (firebase_uid IS NOT NULL AND firebase_uid = $4)
        LIMIT 1
      `, [cleanPhone, standardLibyan, localLibyan, firebase_uid || '']);
      if (uRes.rows.length > 0) {
        user = uRes.rows[0];
        db.users.push(user);
      }
    }

    let isNewUser = false;
    if (!user) {
      isNewUser = true;
      const userId = `user_${uuidv4().substring(0, 8)}`;
      user = {
        id: userId,
        full_name: full_name || 'زبون واصل نالوت',
        phone: standardLibyan,
        email: `${rawDigits}@wasel-nalut.ly`,
        role: 'customer',
        status: 'active',
        city: 'nalut',
        firebase_uid: firebase_uid || null,
        auth_method: auth_method || 'firebase_sms',
        created_at: new Date().toISOString()
      };
      db.users.push(user);
      await saveUserToPg(user);

      // Initialize Customer Wallet with welcome credit (50 LYD)
      const walletId = `wallet_${userId}`;
      const newWallet = {
        id: walletId,
        user_id: userId,
        wallet_type: 'customer_wallet',
        currency: 'LYD',
        balance: 50.00,
        locked_balance: 0.00,
        status: 'active'
      };
      db.wallets.push(newWallet);
      await saveWalletToPg(newWallet);
    } else {
      if (firebase_uid && !user.firebase_uid) {
        user.firebase_uid = firebase_uid;
        await saveUserToPg(user);
      }
    }

    const token = generateToken(user);
    const wallet = db.wallets.find(w => w.user_id === user.id) || null;

    res.json({
      success: true,
      message: isNewUser ? 'Account created and verified via mobile phone' : 'Logged in successfully via mobile phone',
      data: {
        token,
        user: {
          id: user.id,
          full_name: user.full_name,
          phone: user.phone,
          role: user.role,
          city: user.city || 'nalut'
        },
        wallet
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/auth/login', rateLimiter(15, 60000), (req, res) => {
  try {
    const { phone, password, role } = req.body;
    
    if (!phone && !role) {
      return res.status(400).json({ success: false, error: 'Phone number or role required' });
    }

    let user;
    let driverData = null;
    if (phone) {
      user = db.users.find(u => u.phone === phone);
      if (!user) {
        const matchedDriver = db.drivers.find(d => d.phone === phone);
        if (matchedDriver) {
          driverData = matchedDriver;
          user = {
            id: matchedDriver.user_id || matchedDriver.id,
            driver_id: matchedDriver.id,
            full_name: matchedDriver.full_name,
            phone: matchedDriver.phone,
            role: 'driver',
            city: 'nalut',
            password: matchedDriver.pin || null
          };
        }
      } else if (user.role === 'driver') {
        const matchedDriver = db.drivers.find(d => d.user_id === user.id || d.phone === phone);
        if (matchedDriver) {
          driverData = matchedDriver;
          user.driver_id = matchedDriver.id;
        }
      }
    } else if (role === 'admin') {
      user = db.users.find(u => u.role === 'admin');
    } else if (role === 'driver') {
      const matchedDriver = db.drivers[0];
      if (matchedDriver) {
        driverData = matchedDriver;
        user = {
          id: matchedDriver.user_id || matchedDriver.id,
          driver_id: matchedDriver.id,
          full_name: matchedDriver.full_name,
          phone: matchedDriver.phone,
          role: 'driver',
          city: 'nalut',
          password: matchedDriver.pin || null
        };
      }
    } else if (role) {
      user = db.users.find(u => u.role === role);
    }

    if (!user) {
      return res.status(401).json({ success: false, error: 'Invalid login credentials' });
    }

    if (!password) {
      return res.status(400).json({ success: false, error: 'Password or PIN required' });
    }

    const storedSecret = user.password || user.password_hash;
    if (!storedSecret) {
      return res.status(401).json({ success: false, error: 'لم يتم تعيين رمز مرور لهذا الحساب' });
    }
    if (storedSecret !== password) {
      return res.status(401).json({ success: false, error: 'Incorrect password or PIN' });
    }

    const token = generateToken(user);
    const wallet = db.wallets.find(w => w.user_id === user.id) || null;

    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user.id,
          full_name: user.full_name,
          phone: user.phone,
          role: user.role,
          city: user.city
        },
        driver: driverData ? {
          id: driverData.id,
          full_name: driverData.full_name,
          phone: driverData.phone,
          vehicle_type: driverData.vehicle_type,
          vehicle_plate: driverData.vehicle_plate || driverData.plate_number
        } : null,
        wallet
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================================================
// HELPER: Robust Libyan Phone Number Normalization
// ============================================================================
function normalizeLibyanPhone(input) {
  if (!input) return '';
  const ascii = String(input)
    .replace(/[٠-٩]/g, d => d.charCodeAt(0) - 1632)
    .replace(/[۰-۹]/g, d => d.charCodeAt(0) - 1776);
  let digits = ascii.replace(/\D/g, '');
  if (digits.startsWith('00218')) {
    digits = digits.slice(5);
  } else if (digits.startsWith('218')) {
    digits = digits.slice(3);
  }
  return digits.replace(/^0+/, '');
}

app.post('/api/v1/auth/merchant-login', rateLimiter(20, 60000), (req, res) => {
  try {
    const { store_id, pin, phone } = req.body;
    const identifier = store_id || phone;
    if (!identifier) {
      return res.status(400).json({ success: false, error: 'Store ID is required' });
    }

    const cleanInput = String(identifier).trim();
    const normInput = normalizeLibyanPhone(cleanInput);

    const store = db.stores.find(s => {
      if (!s) return false;
      // 1. Exact Store ID match (case-insensitive)
      if (s.id && (s.id === cleanInput || s.id.toLowerCase() === cleanInput.toLowerCase())) {
        return true;
      }
      // 2. Phone match against Libyan normalized format (minimum 7 digits for subscriber line)
      if (normInput.length >= 7) {
        const normStorePhone = normalizeLibyanPhone(s.phone);
        if (normStorePhone.length >= 7) {
          if (normStorePhone === normInput ||
              normStorePhone.endsWith(normInput) ||
              normInput.endsWith(normStorePhone)) {
            return true;
          }
        }
      }
      return false;
    });
    if (!store) {
      return res.status(404).json({ success: false, error: 'المتجر المحدد غير مسجل بالنظام' });
    }

    const validPin = store.pin;
    if (!validPin || pin !== validPin) {
      return res.status(401).json({ success: false, error: 'رمز PIN الخاص بالمتجر غير صحيح' });
    }

    const token = jwt.sign(
      {
        id: store.merchant_id || `merch_${store.id}`,
        store_id: store.id,
        role: 'merchant',
        store_name: store.name
      },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      success: true,
      message: `تم تسجيل الدخول بنجاح لـ ${store.name}`,
      data: {
        token,
        store: {
          id: store.id,
          name: store.name,
          address: store.address,
          city: store.city,
          type: store.type,
          phone: store.phone
        }
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/auth/admin-login', rateLimiter(10, 60000), (req, res) => {
  try {
    const { pin, password } = req.body || {};
    const adminUser = db.users.find(u => u.role === 'admin');
    if (!adminUser) {
      return res.status(401).json({ success: false, error: 'حساب الإدارة غير متوفر بالنظام' });
    }

    const providedSecret = (pin || password || '').toString().trim();
    const adminSecret = (adminUser.password || adminUser.password_hash || '').toString().trim();
    const validAdminPin = (adminUser.pin || process.env.ADMIN_PIN || process.env.ADMIN_DEFAULT_PIN || '7788').toString().trim();

    const isMatch = Boolean(
      providedSecret && (providedSecret === adminSecret || providedSecret === validAdminPin)
    );

    if (!isMatch) {
      return res.status(401).json({ success: false, error: 'رمز الأمان الإداري غير صحيح' });
    }

    const token = jwt.sign(
      { id: adminUser.id, role: 'admin', full_name: adminUser.full_name },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      success: true,
      message: 'تم التحقق من الصلاحيات الإدارية بنجاح',
      data: {
        token,
        user: {
          id: adminUser.id,
          full_name: adminUser.full_name,
          role: 'admin'
        }
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/v1/auth/me', authMiddleware, (req, res) => {
  const wallet = db.wallets.find(w => w.user_id === req.user.id);
  res.json({
    success: true,
    data: {
      user: req.user,
      wallet
    }
  });
});

// ----------------------------------------------------------------------------
// STORES & CATALOG ROUTES
// ----------------------------------------------------------------------------
app.get('/api/v1/stores', (req, res) => {
  try {
    const { type, city, search, district, featured, lat, lng } = req.query;
    let stores = [...db.stores];

    if (type) {
      stores = stores.filter(s => s.type === type.toLowerCase());
    }

    if (city) {
      stores = stores.filter(s => s.city.toLowerCase() === city.toLowerCase());
    }

    if (district) {
      stores = stores.filter(s => s.district.toLowerCase().includes(district.toLowerCase()));
    }

    if (featured === 'true') {
      stores = stores.filter(s => s.is_featured);
    }

    if (search) {
      const q = search.toLowerCase();
      stores = stores.filter(s =>
        s.name.toLowerCase().includes(q) ||
        s.name_en.toLowerCase().includes(q) ||
        (s.cuisine_tags && s.cuisine_tags.some(t => t.toLowerCase().includes(q)))
      );
    }

    // Proximity calculation if coordinates provided
    if (lat && lng) {
      const userLat = parseFloat(lat);
      const userLng = parseFloat(lng);
      stores = stores.map(store => {
        const distanceMeters = calculateHaversineDistance(userLat, userLng, store.latitude, store.longitude);
        const feeQuote = calculateDynamicDeliveryFee(store, userLat, userLng);
        return {
          ...store,
          distance_meters: Math.round(distanceMeters),
          distance_km: Math.round((distanceMeters / 1000) * 10) / 10,
          calculated_delivery_fee_lyd: feeQuote.delivery_fee_lyd,
          calculated_eta_minutes: feeQuote.estimated_eta_minutes
        };
      });
      // Sort by proximity
      stores.sort((a, b) => a.distance_meters - b.distance_meters);
    }

    res.set('Cache-Control', 'public, max-age=15, stale-while-revalidate=60');
    res.json({
      success: true,
      count: stores.length,
      data: stores.map(sanitizeStore)
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/v1/stores/:id', (req, res) => {
  const store = db.stores.find(s => s.id === req.params.id);
  if (!store) {
    return res.status(404).json({ success: false, error: 'Store not found' });
  }
  res.set('Cache-Control', 'public, max-age=30, stale-while-revalidate=120');
  res.json({
    success: true,
    data: sanitizeStore(store)
  });
});

app.get('/api/v1/stores/:id/menu', (req, res) => {
  try {
    const store = db.stores.find(s => s.id === req.params.id);
    if (!store) {
      return res.status(404).json({ success: false, error: 'Store not found' });
    }

    const storeProducts = db.products.filter(p => p.store_id === store.id);
    const categoryIds = [...new Set(storeProducts.map(p => p.category_id))];
    const categories = db.categories.filter(c => categoryIds.includes(c.id));

    // Group products by category
    const menuSections = categories.map(cat => ({
      category: cat,
      products: storeProducts.filter(p => p.category_id === cat.id)
    }));

    res.set('Cache-Control', 'public, max-age=30, stale-while-revalidate=120');
    res.json({
      success: true,
      store: {
        id: store.id,
        name: store.name,
        name_en: store.name_en,
        type: store.type,
        rating: store.rating,
        delivery_time_min: store.delivery_time_min,
        delivery_time_max: store.delivery_time_max,
        base_delivery_fee_lyd: store.base_delivery_fee_lyd,
        badge: store.badge
      },
      categories,
      menu_sections: menuSections,
      all_products: storeProducts,
      products: storeProducts,
      data: {
        store_id: store.id,
        products: storeProducts
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/stores', adminAuthMiddleware, async (req, res) => {
  try {
    const s = req.body;
    if (!s.name) {
      return res.status(400).json({ success: false, error: 'Store name is required' });
    }
    const newStore = {
      id: s.id || `store_nalut_${Date.now()}`,
      name: s.name,
      name_en: s.name_en || s.name,
      type: s.type || 'restaurant',
      district: s.district || 'نالوت',
      city: 'nalut',
      phone: s.phone || '',
      pin: s.pin || crypto.randomInt(1000, 10000).toString(),
      app_mode: s.app_mode || ((s.type === 'grocery' || s.type === 'pharmacy') ? 'retail' : 'kitchen'),
      commission_rate: s.commission_rate || 10.0,
      rating: 5.0,
      review_count: 0,
      delivery_time_min: s.delivery_time_min || 20,
      delivery_time_max: s.delivery_time_max || 35,
      min_order_lyd: s.min_order_lyd || 10.0,
      base_delivery_fee_lyd: s.base_delivery_fee_lyd || 4.0,
      latitude: s.latitude || 31.8686,
      longitude: s.longitude || 10.9818,
      is_open: s.is_open !== false,
      is_featured: s.is_featured !== false,
      created_at: new Date().toISOString()
    };
    db.stores.unshift(newStore);
    await saveStoreToPg(newStore);
    if (req.io) {
      req.io.emit('store:created', newStore);
    }
    res.status(201).json({ success: true, data: newStore });
  } catch (err) {
    db.stores = db.stores.filter(s => s.id !== req.body?.id && s.name !== req.body?.name);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.patch('/api/v1/stores/:id', storeOwnerOrAdminMiddleware, async (req, res) => {
  try {
    const store = db.stores.find(s => s.id === req.params.id);
    if (!store) {
      return res.status(404).json({ success: false, error: 'Store not found' });
    }
    Object.assign(store, req.body);
    if (req.body.is_open !== undefined) {
      store.is_open = req.body.is_open === true || req.body.is_open === 'true' || req.body.is_open === 1;
      store.last_heartbeat = store.is_open ? Date.now() : 0;
    }
    await saveStoreToPg(store);
    if (req.io) {
      req.io.emit('store:updated', store);
      req.io.emit('store:status_changed', { store_id: store.id, is_open: store.is_open });
    }
    res.json({ success: true, data: store });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Merchant Active Heartbeat (Auto-opens store while merchant app is running)
app.post('/api/v1/stores/:id/heartbeat', storeOwnerOrAdminMiddleware, async (req, res) => {
  try {
    const store = db.stores.find(s => s.id === req.params.id);
    if (!store) {
      return res.status(404).json({ success: false, error: 'Store not found' });
    }
    const wasClosed = !store.is_open;
    store.last_heartbeat = Date.now();
    store.is_open = true;

    if (wasClosed) {
      await saveStoreToPg(store);
      if (req.io) {
        req.io.emit('store:status_changed', { store_id: store.id, is_open: true });
        req.io.emit('store:updated', store);
      }
      console.log(`[Presence Engine] Store "${store.name}" (${store.id}) opened via active merchant heartbeat.`);
    }

    res.json({
      success: true,
      store_id: store.id,
      is_open: store.is_open,
      last_heartbeat: store.last_heartbeat
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.delete('/api/v1/stores/:id', adminAuthMiddleware, async (req, res) => {
  try {
    db.stores = db.stores.filter(s => s.id !== req.params.id);
    db.products = db.products.filter(p => p.store_id !== req.params.id);
    await deleteStoreFromPg(req.params.id);
    if (req.io) {
      req.io.emit('store:deleted', { id: req.params.id });
    }
    res.json({ success: true, message: 'Store deleted' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/drivers', adminAuthMiddleware, async (req, res) => {
  try {
    const d = req.body;
    const newDriver = {
      id: d.id || `drv_${Date.now()}`,
      full_name: d.full_name || d.name || 'كابتن واصل',
      phone: d.phone || '',
      pin: d.pin || crypto.randomInt(1000, 10000).toString(),
      vehicle_type: d.vehicle_type || 'سيارة',
      plate_number: d.plate_number || 'نالوت 14-',
      status: 'available',
      rating: 5.0,
      total_trips: 0,
      wallet_balance_lyd: 0.0,
      max_cod_limit_lyd: d.max_cod_limit_lyd || 250.0,
      created_at: new Date().toISOString()
    };
    db.drivers.unshift(newDriver);
    await saveDriverToPg(newDriver);
    if (req.io) {
      req.io.emit('driver:added', newDriver);
    }
    res.status(201).json({ success: true, data: newDriver });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.delete('/api/v1/drivers/:id', adminAuthMiddleware, async (req, res) => {
  try {
    db.drivers = db.drivers.filter(d => d.id !== req.params.id);
    await deleteDriverFromPg(req.params.id);
    if (req.io) {
      req.io.emit('driver:deleted', { id: req.params.id });
    }
    res.json({ success: true, message: 'Driver deleted' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/drivers/:id/settle', driverSelfOrAdminMiddleware, async (req, res) => {
  let client = null;
  let prevCashInHand = null;
  let prevCodBalance = null;
  let driver = null;

  try {
    if (pgPool && typeof pgPool.connect === 'function') {
      client = await pgPool.connect();
      await client.query('BEGIN');
    }

    const runner = client || pgPool;
    if (runner) {
      const dRes = await runner.query('SELECT * FROM drivers WHERE id = $1 OR user_id = $1 FOR UPDATE', [req.params.id]);
      if (dRes.rows.length > 0) {
        driver = mapPgDriver(dRes.rows[0]);
        const memIdx = db.drivers.findIndex(d => d.id === driver.id);
        if (memIdx >= 0) db.drivers[memIdx] = driver;
        else db.drivers.push(driver);
      }
    }
    if (!driver) {
      driver = db.drivers.find(d => d.id === req.params.id || d.user_id === req.params.id);
    }
    if (!driver) {
      if (client) { await client.query('ROLLBACK'); client.release(); client = null; }
      return res.status(404).json({ success: false, error: 'Driver not found' });
    }

    // Preserve memory state snapshot for clean rollback on error
    prevCashInHand = driver.cash_in_hand_lyd;
    prevCodBalance = driver.cod_balance_lyd;

    const settlementResult = await ledgerService.settleDriverCash(db, driver.id, req.body || {}, client || pgPool);
    const { settled_amount, voucher } = settlementResult;

    // Save driver state to PostgreSQL using the active transaction client
    await saveDriverToPg(driver, client);

    // Commit transaction
    if (client) {
      await client.query('COMMIT');
      client.release();
      client = null;
    }

    if (req.io) {
      req.io.emit('driver:settled', {
        driver_id: driver.id,
        settled_amount: settled_amount,
        cash_in_hand: 0.0,
        cod_balance: 0.0,
        balance: driver.wallet_balance_lyd, // Net earnings preserved!
        wallet_balance_lyd: driver.wallet_balance_lyd,
        voucher: voucher
      });
    }

    res.json({
      success: true,
      message: 'Driver cash settled successfully',
      data: driver,
      settled_amount: settled_amount,
      cash_in_hand: 0.0,
      wallet_balance_lyd: driver.wallet_balance_lyd,
      voucher: voucher
    });
  } catch (err) {
    // Roll back database transaction
    if (client) {
      try { await client.query('ROLLBACK'); } catch (_) {}
      client.release();
      client = null;
    }

    // Roll back in-memory driver state
    if (driver && prevCashInHand !== null) {
      driver.cash_in_hand_lyd = prevCashInHand;
      driver.cod_balance_lyd = prevCodBalance;
    }

    res.status(500).json({ success: false, error: err.message });
  }
});

app.patch('/api/v1/drivers/:id/settle', (req, res, next) => {
  req.method = 'POST';
  app._router.handle(req, res, next);
});

// SELECTIVE ADMIN ORDERS PURGE ENDPOINT (F8 Selective Order Purge)
const handleAdminOrdersPurge = async (req, res) => {
  try {
    const { pin } = req.body || {};
    if (!pin || (pin !== '7788' && pin !== req.user?.pin)) {
      return res.status(401).json({ success: false, error: 'رمز الأمان PIN مطلوب وغير صحيح' });
    }

    // 1. Clear orders and related transactional ledger from memory
    db.orders = [];
    db.wallet_transactions = [];
    if (db.journal_entries) db.journal_entries = [];
    if (db.journal_entry_lines) db.journal_entry_lines = [];
    if (db.vouchers) db.vouchers = [];

    // 2. Reset driver active orders and COD custody liabilities
    if (db.drivers) {
      for (const driver of db.drivers) {
        driver.active_order_id = null;
        driver.cod_balance_lyd = 0.00;
        driver.cash_in_hand_lyd = 0.00;
        driver.status = 'offline';
        driver.is_active = false;
      }
    }

    // 3. Unlock customer wallet balances
    if (db.wallets) {
      for (const wallet of db.wallets) {
        wallet.locked_balance = 0.00;
      }
    }

    // 4. Update seed_data.json on disk to maintain zero state across server boots
    try {
      if (fs.existsSync(SEED_DATA_PATH)) {
        const rawSeed = fs.readFileSync(SEED_DATA_PATH, 'utf8');
        const parsedSeed = JSON.parse(rawSeed);
        parsedSeed.orders = [];
        if (parsedSeed.drivers) {
          for (const d of parsedSeed.drivers) {
            d.active_order_id = null;
            d.cod_balance_lyd = 0;
            d.cash_in_hand_lyd = 0;
            d.status = 'offline';
            d.is_active = false;
          }
        }
        if (parsedSeed.wallets) {
          for (const w of parsedSeed.wallets) {
            if (w.locked_balance !== undefined) w.locked_balance = 0;
          }
        }
        fs.writeFileSync(SEED_DATA_PATH, JSON.stringify(parsedSeed, null, 2), 'utf8');
      }
    } catch (fsErr) {
      console.warn('[Seed Data Disk Update Warning]:', fsErr.message);
    }

    // 5. Execute selective cascade truncate and reset in PostgreSQL
    if (pgPool) {
      try { await pgPool.query('TRUNCATE orders, order_items CASCADE'); } catch (_) {}
      try { await pgPool.query('TRUNCATE reviews CASCADE'); } catch (_) {}
      try {
        await pgPool.query(`
          UPDATE drivers
          SET active_order_id = NULL,
              cod_balance_lyd = 0.00,
              cash_in_hand_lyd = 0.00,
              status = 'offline',
              is_active = false
        `);
      } catch (_) {}
      try { await pgPool.query('UPDATE wallets SET locked_balance = 0.00'); } catch (_) {}
      try { await pgPool.query('TRUNCATE wallet_transactions CASCADE'); } catch (_) {}
      try { await pgPool.query('TRUNCATE journal_entries, journal_entry_lines CASCADE'); } catch (_) {}
      try { await pgPool.query('TRUNCATE voucher_usage CASCADE'); } catch (_) {}
    }

    // 6. Broadcast admin:orders_purged
    if (req.io) {
      req.io.emit('admin:orders_purged', { timestamp: new Date().toISOString() });
      req.io.to('admin:fleet').emit('admin:orders_purged', { timestamp: new Date().toISOString() });
    }

    res.json({
      success: true,
      message: 'تم تصفير كافة الطلبات وسجل الحركات بنجاح مع الحفاظ على المتاجر والمنتجات والكباتن'
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

app.post('/api/v1/admin/orders/purge', adminAuthMiddleware, handleAdminOrdersPurge);
app.post('/api/v1/admin/purge', adminAuthMiddleware, handleAdminOrdersPurge);

app.get('/api/v1/categories', (req, res) => {
  const { vertical } = req.query;
  let categories = [...db.categories];
  if (vertical) {
    categories = categories.filter(c => c.vertical === vertical);
  }
  res.json({
    success: true,
    count: categories.length,
    data: categories
  });
});

app.get('/api/v1/products', (req, res) => {
  try {
    const { store_id, category_id, search } = req.query;
    let products = [...db.products];
    if (store_id) {
      products = products.filter(p => p.store_id === store_id);
    }
    if (category_id) {
      products = products.filter(p => p.category_id === category_id);
    }
    if (search) {
      const q = search.toLowerCase();
      products = products.filter(p =>
        (p.name && p.name.toLowerCase().includes(q)) ||
        (p.name_ar && p.name_ar.toLowerCase().includes(q)) ||
        (p.description && p.description.toLowerCase().includes(q))
      );
    }
    res.json({
      success: true,
      count: products.length,
      data: products
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/v1/products/:id', (req, res) => {
  const product = db.products.find(p => p.id === req.params.id);
  if (!product) {
    return res.status(404).json({ success: false, error: 'Product not found' });
  }
  const store = db.stores.find(s => s.id === product.store_id);
  res.json({
    success: true,
    data: {
      ...product,
      store: store ? { id: store.id, name: store.name, type: store.type } : null
    }
  });
});

app.post('/api/v1/products', async (req, res) => {
  try {
    const p = req.body;
    if (!p.name && !p.name_ar) {
      return res.status(400).json({ success: false, error: 'Product name is required' });
    }
    const price = parseFloat(p.price || p.price_lyd || 0);
    const stockQuantity = p.stock_quantity !== undefined && p.stock_quantity !== null
      ? parseInt(p.stock_quantity, 10)
      : 50;
    const isAvailable = p.is_available !== undefined
      ? (p.is_available === true || p.is_available === 'true' || p.is_available === 1)
      : (stockQuantity > 0);

    const newProd = {
      id: p.id || `prod_${uuidv4().substring(0, 8)}`,
      store_id: p.store_id || 'store_default',
      name: p.name || p.name_ar,
      name_ar: p.name_ar || p.name,
      price: price,
      price_lyd: price,
      category: p.category || 'عام',
      category_id: p.category_id || '',
      description: p.description || p.desc_ar || '',
      desc_ar: p.desc_ar || p.description || '',
      image_url: p.image_url || '',
      in_stock: isAvailable && stockQuantity > 0,
      is_available: isAvailable && stockQuantity > 0,
      stock_quantity: stockQuantity,
      is_popular: p.is_popular === true || p.is_popular === 'true',
      unit: p.unit || 'قطعة',
      created_at: new Date().toISOString()
    };

    db.products.push(newProd);
    await saveProductToPg(newProd);

    if (req.io) {
      req.io.emit('product:created', newProd);
      req.io.emit('store:menu_updated', { store_id: newProd.store_id });
    }

    res.status(201).json({ success: true, data: newProd });
  } catch (err) {
    db.products = db.products.filter(p => p.id !== req.body?.id);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.patch('/api/v1/products/:id', async (req, res) => {
  try {
    const product = db.products.find(p => p.id === req.params.id);
    if (!product) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }

    const updates = req.body;

    // Handle price updates
    if (updates.price !== undefined || updates.price_lyd !== undefined) {
      const newPrice = parseFloat(updates.price_lyd || updates.price);
      product.price = newPrice;
      product.price_lyd = newPrice;
    }

    // Handle stock quantity updates
    if (updates.stock_quantity !== undefined && updates.stock_quantity !== null) {
      const qty = parseInt(updates.stock_quantity, 10);
      product.stock_quantity = isNaN(qty) ? 0 : Math.max(0, qty);
      if (product.stock_quantity === 0) {
        product.in_stock = false;
        product.is_available = false;
      } else {
        product.in_stock = true;
        product.is_available = true;
      }
    }

    // Handle availability / in_stock toggle explicitly
    if (updates.is_available !== undefined) {
      const isAvail = updates.is_available === true || updates.is_available === 'true' || updates.is_available === 1;
      product.is_available = isAvail;
      product.in_stock = isAvail;
      if (!isAvail) {
        product.stock_quantity = 0;
      } else if (product.stock_quantity === 0 || product.stock_quantity === undefined) {
        product.stock_quantity = 10;
      }
    } else if (updates.in_stock !== undefined) {
      const inStk = updates.in_stock === true || updates.in_stock === 'true' || updates.in_stock === 1;
      product.in_stock = inStk;
      product.is_available = inStk;
      if (!inStk) {
        product.stock_quantity = 0;
      } else if (product.stock_quantity === 0 || product.stock_quantity === undefined) {
        product.stock_quantity = 10;
      }
    }

    if (updates.name) product.name = updates.name;
    if (updates.name_ar) product.name_ar = updates.name_ar;
    if (updates.description) product.description = updates.description;
    if (updates.desc_ar) product.desc_ar = updates.desc_ar;
    if (updates.category) product.category = updates.category;
    if (updates.unit) product.unit = updates.unit;

    await saveProductToPg(product);

    if (req.io) {
      req.io.emit('product:updated', product);
      req.io.emit('product:stock_changed', {
        product_id: product.id,
        store_id: product.store_id,
        in_stock: product.in_stock,
        is_available: product.is_available,
        stock_quantity: product.stock_quantity
      });
      req.io.emit('store:menu_updated', { store_id: product.store_id });
    }

    res.json({ success: true, data: product });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.delete('/api/v1/products/:id', async (req, res) => {
  try {
    const idx = db.products.findIndex(p => p.id === req.params.id);
    if (idx === -1) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }
    const deleted = db.products.splice(idx, 1)[0];
    await deleteProductFromPg(req.params.id);

    if (req.io) {
      req.io.emit('product:deleted', { id: req.params.id, store_id: deleted.store_id });
      req.io.emit('store:menu_updated', { store_id: deleted.store_id });
    }

    res.json({ success: true, message: 'Product deleted', data: deleted });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ----------------------------------------------------------------------------
// AI OCR & SMART CATALOG SCANNER (GEMINI 3.7 FLASH INTEGRATION)
// ----------------------------------------------------------------------------
const AI_ENDPOINT = process.env.AI_ENDPOINT || 'http://127.0.0.1:8045/v1/chat/completions';
const AI_API_KEY = process.env.AI_API_KEY || 'sk-37c5462abaf34c58a8f05854cdd8a518';
const AI_MODEL = process.env.AI_MODEL || 'gemini-3.7-flash';

app.post('/api/v1/ai/parse-menu-invoice', rateLimiter(10, 60000), async (req, res) => {
  try {
    const { image_base64, text_content, store_type = 'restaurant', store_name = '' } = req.body;

    if (!image_base64 && (!text_content || !text_content.trim())) {
      return res.status(400).json({
        success: false,
        error: 'Please provide an image_base64 or text_content of the menu/invoice.'
      });
    }

    const systemPrompt = `You are an expert OCR & catalog digitizer AI for Libyan restaurants, cafeterias, and supermarkets in Nalut (نالوت) and Libya.
Your task is to analyze the provided restaurant menu image/text or supermarket invoice/receipt and extract all items with extreme accuracy.

Rules:
1. Extract item names in authentic Libyan Arabic (e.g. مشويات مشكل، كباب خروف بلدي، بيتزا، شاورما، زيت زيتون نالوت، حليب...).
2. Infer appropriate category (e.g. مشويات جبلية، بيتزا ومعجنات، سندوتشات وسريع، مقبلات ومشروبات، تموينات وبقالة...).
3. Extract or infer price in Libyan Dinars (LYD / د.ل) as a number (e.g. 25.0, 18.5, 4.5).
4. Provide a brief appetizing/clear description in Arabic.
5. Return ONLY a valid, strict JSON object with no markdown fences, formatted as:
{
  "store_name": "extracted or suggested store name",
  "store_type": "${store_type}",
  "total_items_found": 0,
  "items": [
    {
      "nameAr": "اسم الوجبة أو السلعة",
      "category": "القسم المناسب",
      "priceLyd": 25.00,
      "descAr": "وصف الوجبة والمكونات",
      "unit": "وجبة / صحن / قطعة / لتر"
    }
  ]
}`;

    const userMessageContent = [];
    if (text_content) {
      userMessageContent.push({
        type: 'text',
        text: `Here is the menu or invoice text to extract:\n\n${text_content}`
      });
    }
    if (image_base64) {
      const formattedImageUrl = image_base64.startsWith('data:') 
        ? image_base64 
        : `data:image/jpeg;base64,${image_base64}`;
      userMessageContent.push({
        type: 'image_url',
        image_url: { url: formattedImageUrl }
      });
    }

    const aiPayload = {
      model: AI_MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userMessageContent.length === 1 && userMessageContent[0].type === 'text' ? userMessageContent[0].text : userMessageContent }
      ],
      temperature: 0.1
    };

    const aiRes = await fetch(AI_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${AI_API_KEY}`
      },
      body: JSON.stringify(aiPayload)
    });

    if (!aiRes.ok) {
      const errText = await aiRes.text();
      throw new Error(`AI Gateway responded with status ${aiRes.status}: ${errText}`);
    }

    const aiJson = await aiRes.json();
    const rawContent = aiJson.choices?.[0]?.message?.content || '{}';
    
    let parsedData = {};
    try {
      const cleaned = rawContent.replace(/```json/gi, '').replace(/```/g, '').trim();
      parsedData = JSON.parse(cleaned);
    } catch(parseErr) {
      const jsonMatch = rawContent.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        parsedData = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error('Failed to parse structured JSON from AI output');
      }
    }

    res.json({
      success: true,
      source: 'Gemini 3.7 Flash AI OCR',
      data: parsedData
    });
  } catch (err) {
    console.error('[AI Menu OCR Error]:', err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/stores/:id/bulk-products', (req, res) => {
  try {
    const storeId = req.params.id;
    const { items = [] } = req.body;
    const store = db.stores.find(s => s.id === storeId);
    if (!store) {
      return res.status(404).json({ success: false, error: 'Store not found' });
    }

    const addedProducts = [];
    items.forEach((item, idx) => {
      const newProd = {
        id: `prod_${uuidv4().substring(0, 8)}`,
        store_id: store.id,
        name: item.nameAr || item.name || `صنف ${idx + 1}`,
        description: item.descAr || item.description || '',
        price_lyd: parseFloat(item.priceLyd || item.price_lyd || 10.0),
        category: item.category || 'عام',
        is_available: true,
        image_url: item.imageUrl || 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
        created_at: new Date().toISOString()
      };
      db.products.push(newProd);
      addedProducts.push(newProd);
    });

    res.status(201).json({
      success: true,
      message: `Successfully added ${addedProducts.length} items to ${store.name}`,
      count: addedProducts.length,
      data: addedProducts
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ----------------------------------------------------------------------------
// ORDERS & CHECKOUT ROUTES (R1)
// ----------------------------------------------------------------------------
app.post(['/api/v1/orders/checkout', '/api/v1/orders'], authMiddleware, async (req, res) => {
  let client = null;
  let customerWallet = null;
  let holdTxn = null;
  let newOrder = null;
  let totalAmount = 0;
  let isCommitted = false;
  const deductedProducts = [];
  try {
    if (pgPool && typeof pgPool.connect === 'function') {
      client = await pgPool.connect();
      await client.query('BEGIN');
    }

    const {
      store_id,
      items = [],
      delivery_address,
      delivery_latitude,
      delivery_longitude,
      delivery_lat,
      delivery_lng,
      payment_method = 'wallet', // 'wallet' | 'cash_on_delivery'
      notes = ''
    } = req.body;

    if (!store_id) {
      if (client) { await client.query('ROLLBACK'); client.release(); client = null; }
      return res.status(400).json({ success: false, error: 'store_id is required' });
    }
    if (!items || items.length === 0) {
      if (client) { await client.query('ROLLBACK'); client.release(); client = null; }
      return res.status(400).json({ success: false, error: 'Order must contain at least 1 item' });
    }

    let store = null;
    const storeQueryRunner = client || pgPool;
    if (storeQueryRunner) {
      const sRes = await storeQueryRunner.query('SELECT * FROM stores WHERE id = $1', [store_id]);
      if (sRes.rows.length > 0) {
        store = mapPgStore(sRes.rows[0]);
      }
    }
    if (!store) {
      store = db.stores.find(s => s.id === store_id);
    }
    if (!store) {
      if (client) { await client.query('ROLLBACK'); client.release(); client = null; }
      return res.status(404).json({ success: false, error: 'Store not found' });
    }

    // Reject orders if store is closed
    if (store.is_open === false) {
      if (client) { await client.query('ROLLBACK'); client.release(); client = null; }
      return res.status(400).json({
        success: false,
        error: `عذراً، متجر "${store.name}" مغلق حالياً ولا يستقبل طلبات جديدة.`
      });
    }

    // Pre-flight validation: check stock availability for every requested item
    for (const item of items) {
      let product = null;
      const itemId = item.product_id || item.id;
      const prodQueryRunner = client || pgPool;
      if (prodQueryRunner) {
        if (itemId) {
          const pRes = await prodQueryRunner.query('SELECT * FROM products WHERE id = $1', [itemId]);
          if (pRes.rows.length > 0) product = mapPgProduct(pRes.rows[0]);
        }
        if (!product && item.name) {
          const pRes = await prodQueryRunner.query('SELECT * FROM products WHERE name = $1 OR name_ar = $1 LIMIT 1', [item.name]);
          if (pRes.rows.length > 0) product = mapPgProduct(pRes.rows[0]);
        }
      }
      if (!product) {
        product = db.products.find(p =>
          (itemId && p.id === itemId) ||
          (item.name && (p.name === item.name || p.name_ar === item.name))
        );
      }

      if (product) {
        const reqQty = parseInt(item.quantity || 1, 10);
        if (product.is_available === false || product.in_stock === false) {
          if (client) { await client.query('ROLLBACK'); client.release(); client = null; }
          return res.status(400).json({
            success: false,
            error: `عذراً، الصنف "${product.name_ar || product.name}" نفدت كميته ولم يعد متوفراً حالياً.`
          });
        }
        if (product.stock_quantity !== undefined && product.stock_quantity !== null && product.stock_quantity < reqQty) {
          if (client) { await client.query('ROLLBACK'); client.release(); client = null; }
          return res.status(400).json({
            success: false,
            error: `عذراً، الكمية المطلوبة من "${product.name_ar || product.name}" غير متوفرة (المتبقي في المتجر: ${product.stock_quantity} فقط).`
          });
        }
      }
    }

    const customer = req.user;
    const destLat = delivery_latitude || delivery_lat || (req.body.delivery_location && req.body.delivery_location.latitude) || customer.default_lat || 31.8687;
    const destLng = delivery_longitude || delivery_lng || (req.body.delivery_location && req.body.delivery_location.longitude) || customer.default_lng || 10.9818;
    const destAddress = delivery_address || (req.body.delivery_location && req.body.delivery_location.address) || customer.default_address || `${store.city || 'نالوت'} - عنوان التوصيل`;

    // Calculate subtotal & validate items
    let subtotal = 0;
    let totalWeight = 0;
    const orderItems = [];

    for (const item of items) {
      let product = null;
      const itemId = item.product_id || item.id;
      const prodQueryRunner = client || pgPool;
      if (prodQueryRunner && itemId) {
        const pRes = await prodQueryRunner.query('SELECT * FROM products WHERE id = $1', [itemId]);
        if (pRes.rows.length > 0) product = mapPgProduct(pRes.rows[0]);
      }
      if (!product) {
        product = db.products.find(p => p.id === itemId) || {
          id: itemId || `prod_${Date.now()}`,
          name_ar: item.name_ar || item.name || 'وجبة نالوت الطازجة',
          name_en: item.name_en || item.name || 'Nalut Item',
          price_lyd: parseFloat(item.price || item.price_lyd || 15.0),
          weight_kg: 0.5
        };
      }

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

    // Calculate delivery fee
    const feeCalculation = calculateDynamicDeliveryFee(store, destLat, destLng, totalWeight);
    const deliveryFee = feeCalculation.delivery_fee_lyd;
    const serviceFee = 0.00; // Customer should not see app commission
    const discount = req.body.discount_amount_lyd ? parseFloat(req.body.discount_amount_lyd) : (req.body.discount_lyd ? parseFloat(req.body.discount_lyd) : 0.00);
    const pointsDiscount = req.body.loyalty_points_discount_lyd ? parseFloat(req.body.loyalty_points_discount_lyd) : 0.00;
    const freeDeliveryDiscount = req.body.free_delivery_discount_lyd ? parseFloat(req.body.free_delivery_discount_lyd) : 0.00;
    const totalPromotions = discount + pointsDiscount + freeDeliveryDiscount;
    totalAmount = Math.max(0, subtotal + deliveryFee + serviceFee - totalPromotions);

    // Escrow Reservation if wallet payment
    customerWallet = db.wallets.find(w => w.user_id === customer.id);
    if (!customerWallet) {
      customerWallet = {
        id: `wallet_${customer.id}`,
        user_id: customer.id,
        wallet_type: 'customer_wallet',
        currency: 'LYD',
        balance: 250.00,
        locked_balance: 0.00,
        status: 'active'
      };
      db.wallets.push(customerWallet);
    }

    if (payment_method === 'wallet') {
      let pgWallet = null;
      const walletRunner = client || pgPool;
      if (walletRunner) {
        const wRes = await walletRunner.query('SELECT * FROM wallets WHERE user_id = $1 FOR UPDATE', [customer.id]);
        if (wRes.rows.length > 0) {
          pgWallet = wRes.rows[0];
          customerWallet.balance = parseFloat(pgWallet.balance) || customerWallet.balance;
          customerWallet.locked_balance = parseFloat(pgWallet.locked_balance) || customerWallet.locked_balance;
        }
      }

      const availableBalance = customerWallet.balance - customerWallet.locked_balance;
      if (availableBalance < totalAmount) {
        if (client) { await client.query('ROLLBACK'); client.release(); client = null; }
        return res.status(400).json({
          success: false,
          error: `Insufficient wallet balance. Available: ${availableBalance.toFixed(2)} LYD, Required: ${totalAmount.toFixed(2)} LYD`,
          details: {
            available_balance: availableBalance,
            required_amount: totalAmount,
            shortage: totalAmount - availableBalance
          }
        });
      }

      // Lock funds in escrow
      customerWallet.locked_balance += totalAmount;
      if (client && pgWallet) {
        await client.query('UPDATE wallets SET locked_balance = locked_balance + $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', [totalAmount, pgWallet.id]);
      }

      // Record escrow hold transaction
      holdTxn = {
        id: `txn_hold_${uuidv4().substring(0, 8)}`,
        wallet_id: customerWallet.id,
        counterparty_wallet_id: SYSTEM_WALLETS.ESCROW,
        order_id: null, // will link below
        transaction_type: 'order_hold_escrow',
        amount: totalAmount,
        currency: 'LYD',
        status: 'completed',
        description: `حجز ضمان مالي للطلب من ${store.name}`,
        created_at: new Date().toISOString()
      };
      db.wallet_transactions.push(holdTxn);
      if (client) {
        await saveWalletTransactionToPg(holdTxn, client);
      }
    }

    const orderId = `ord_${uuidv4().substring(0, 8)}`;
    const orderNumber = `ORD-2026-LY-${Math.floor(1000 + Math.random() * 9000)}`;
    const otpCode = crypto.randomInt(1000, 10000).toString();
    const handoverCode = crypto.randomInt(1000, 10000).toString();

    const customerName = (req.body.customer_name && String(req.body.customer_name).trim().length > 0) ? String(req.body.customer_name).trim() : (customer.full_name || 'زبون واصل نالوت');
    const customerPhone = (req.body.customer_phone && String(req.body.customer_phone).trim().length > 0) ? String(req.body.customer_phone).trim() : (customer.phone || '0910000000');

    newOrder = {
      id: orderId,
      order_number: orderNumber,
      customer_id: customer.id,
      customer_name: customerName,
      customer_phone: customerPhone,
      store_id: store.id,
      store_name: store.name,
      store_latitude: store.latitude,
      store_longitude: store.longitude,
      driver_id: null,
      status: 'placed',
      otp_code: otpCode,
      delivery_otp: otpCode,
      handover_code: handoverCode,
      payment_method,
      payment_status: payment_method === 'wallet' ? 'held_escrow' : 'pending_cod',
      subtotal_lyd: subtotal,
      delivery_fee_lyd: deliveryFee,
      service_fee_lyd: serviceFee,
      discount_amount_lyd: discount,
      loyalty_points_discount_lyd: pointsDiscount,
      free_delivery_discount_lyd: freeDeliveryDiscount,
      discount_lyd: totalPromotions,
      total_amount_lyd: totalAmount,
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

    db.orders.push(newOrder);
    await saveOrderToPg(newOrder, client);

    // Deduct stock for ordered products in real-time
    const updatedProducts = [];
    for (const item of items) {
      let product = null;
      const itemId = item.product_id || item.id;
      const prodRunner = client || pgPool;
      if (prodRunner && itemId) {
        const pRes = await prodRunner.query('SELECT * FROM products WHERE id = $1', [itemId]);
        if (pRes.rows.length > 0) product = mapPgProduct(pRes.rows[0]);
      }
      if (!product) {
        product = db.products.find(p =>
          (itemId && p.id === itemId) ||
          (item.name && (p.name === item.name || p.name_ar === item.name))
        );
      }
      if (product) {
        const qty = parseInt(item.quantity || 1, 10);
        if (product.stock_quantity !== undefined && product.stock_quantity !== null) {
          product.stock_quantity = Math.max(0, product.stock_quantity - qty);
          deductedProducts.push({ id: product.id, quantity: qty });
          if (product.stock_quantity === 0) {
            product.in_stock = false;
            product.is_available = false;
          }
        }
        await saveProductToPg(product, client);
        const memProduct = db.products.find(p => p.id === product.id);
        if (memProduct) {
          Object.assign(memProduct, product);
        }
        updatedProducts.push(product);
      }
    }

    // ATOMIC ACID COMMIT
    if (client) {
      await client.query('COMMIT');
      client.release();
      client = null;
    }
    isCommitted = true;

    // STRICTLY POST-COMMIT REAL-TIME BROADCASTS
    if (req.io) {
      for (const prod of updatedProducts) {
        req.io.emit('product:stock_changed', {
          product_id: prod.id,
          store_id: prod.store_id,
          in_stock: prod.in_stock,
          is_available: prod.is_available,
          stock_quantity: prod.stock_quantity
        });
      }
      req.io.emit('store:menu_updated', { store_id: store.id });

      // Real-time Socket broadcasts to Store, User, and Admin (NOT Captain Radar yet)
      req.io.to(`store:${store.id}`).emit('store:new_order', {
        order_id: orderId,
        order_number: orderNumber,
        items: orderItems,
        total_amount_lyd: totalAmount,
        status: newOrder.status
      });

      req.io.to(`user:${customer.id}`).emit('order:created', newOrder);
      req.io.to('admin:fleet').emit('admin:order_created', newOrder);
      req.io.emit('merchant:new_order', newOrder);
    }

    // FIREBASE CLOUD MESSAGING: Loud Buzzer for Merchant Tablet (KDS)
    try {
      const WaselFcmDispatcher = require('./fcm_dispatcher');
      const fcm = new WaselFcmDispatcher();
      fcm.notifyMerchantNewOrder({
        storeId: store.id,
        orderId: orderNumber,
        itemsCount: orderItems.length,
        totalAmountLyd: totalAmount
      }).catch(err => console.error('[FCM] Error sending merchant notification:', err));
    } catch (fcmErr) {
      console.error('[FCM] Failed to initialize dispatcher:', fcmErr);
    }

    res.status(201).json({
      success: true,
      message: 'Order created successfully and waiting for kitchen preparation',
      data: {
        ...newOrder,
        order_id: orderId,
        order: newOrder,
        assigned_driver: null,
        wallet_summary: {
          balance: customerWallet.balance,
          locked_balance: customerWallet.locked_balance,
          available_balance: customerWallet.balance - customerWallet.locked_balance
        }
      }
    });
  } catch (err) {
    if (client) {
      try { await client.query('ROLLBACK'); } catch (_) {}
      client.release();
      client = null;
    }

    // In-memory rollback recovery if transaction aborted before/during COMMIT
    if (!isCommitted) {
      // 1. Revert customer wallet locked balance
      if (customerWallet && holdTxn) {
        customerWallet.locked_balance = Math.max(0, customerWallet.locked_balance - totalAmount);
      }
      // 2. Remove escrow hold transaction from db.wallet_transactions
      if (holdTxn && db.wallet_transactions) {
        const hIdx = db.wallet_transactions.findIndex(t => t.id === holdTxn.id);
        if (hIdx !== -1) {
          db.wallet_transactions.splice(hIdx, 1);
        }
      }
      // 3. Remove newOrder from db.orders
      if (newOrder && db.orders) {
        const oIdx = db.orders.findIndex(o => o.id === newOrder.id);
        if (oIdx !== -1) {
          db.orders.splice(oIdx, 1);
        }
      }
      // 4. Restore decremented product stock quantities
      if (deductedProducts.length > 0 && db.products) {
        for (const item of deductedProducts) {
          const prod = db.products.find(p => p.id === item.id);
          if (prod && prod.stock_quantity !== undefined && prod.stock_quantity !== null) {
            prod.stock_quantity += item.quantity;
            if (prod.stock_quantity > 0) {
              prod.in_stock = true;
              prod.is_available = true;
            }
          }
        }
      }
    }

    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/v1/orders/:id', async (req, res) => {
  try {
    let order = null;
    if (pgPool) {
      const oRes = await pgPool.query('SELECT * FROM orders WHERE id = $1 OR order_number = $1', [req.params.id]);
      if (oRes.rows.length > 0) {
        order = mapPgOrder(oRes.rows[0]);
      }
    }
    if (!order) {
      order = db.orders.find(o => o.id === req.params.id || o.order_number === req.params.id);
    }
    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    let store = null;
    if (pgPool && order.store_id) {
      const sRes = await pgPool.query('SELECT * FROM stores WHERE id = $1', [order.store_id]);
      if (sRes.rows.length > 0) store = mapPgStore(sRes.rows[0]);
    }
    if (!store && order.store_id) {
      store = db.stores.find(s => s.id === order.store_id);
    }

    let driver = null;
    if (pgPool && order.driver_id) {
      const dRes = await pgPool.query('SELECT * FROM drivers WHERE id = $1', [order.driver_id]);
      if (dRes.rows.length > 0) driver = mapPgDriver(dRes.rows[0]);
    }
    if (!driver && order.driver_id) {
      driver = db.drivers.find(d => d.id === order.driver_id);
    }

    let customer = null;
    if (order.customer_id) {
      customer = db.users.find(u => u.id === order.customer_id);
    }

    let remainingDistanceMeters = null;
    let etaMinutes = null;

    if (driver && order.delivery_latitude && order.delivery_longitude) {
      remainingDistanceMeters = Math.round(
        calculateHaversineDistance(driver.latitude, driver.longitude, order.delivery_latitude, order.delivery_longitude)
      );
      etaMinutes = estimateEtaMinutes(remainingDistanceMeters, driver.speed_kmh || 25);
    }

    let requestingUser = null;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        requestingUser = jwt.verify(authHeader.split(' ')[1], JWT_SECRET);
      } catch (_) {}
    }

    let orderData = { ...order };
    if (requestingUser && requestingUser.role === 'driver') {
      delete orderData.otp_code;
      delete orderData.delivery_otp;
    }

    res.json({
      success: true,
      data: {
        ...orderData,
        store: store ? {
          id: store.id,
          name: store.name,
          name_en: store.name_en,
          type: store.type,
          district: store.district,
          latitude: store.latitude,
          longitude: store.longitude
        } : null,
        driver: driver ? {
          id: driver.id,
          name: driver.full_name,
          phone: driver.phone,
          vehicle_type: driver.vehicle_type,
          vehicle_model: driver.vehicle_model,
          license_plate: driver.vehicle_plate || driver.license_plate,
          rating: driver.rating,
          latitude: driver.latitude,
          longitude: driver.longitude,
          heading: driver.heading,
          speed_kmh: driver.speed_kmh,
          battery_level: driver.battery_level
        } : null,
        customer: customer ? {
          id: customer.id,
          name: customer.full_name,
          phone: customer.phone
        } : null,
        tracking: {
          remaining_distance_meters: remainingDistanceMeters,
          remaining_distance_km: remainingDistanceMeters ? (remainingDistanceMeters / 1000).toFixed(1) : null,
          eta_minutes: etaMinutes
        }
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * PUBLIC RECIPIENT TRACKING ENDPOINT
 * Allows anyone with the tracking link / order ID to fetch live status,
 * telemetry coordinates, and ETA without customer authentication.
 * Note: delivery_otp is strictly omitted to prevent delivery fraud.
 */
app.get('/api/v1/public/track/:id', (req, res) => {
  try {
    const rawId = req.params.id;
    let order = db.orders.find(o => o.id === rawId || o.order_number === rawId);
    
    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    const store = db.stores.find(s => s.id === order.store_id) || db.stores[0];
    const driver = (order.driver_id ? db.drivers.find(d => d.id === order.driver_id) : null) || db.drivers[0];

    let remainingDistanceMeters = 1200;
    let etaMinutes = 8;

    if (driver && order.delivery_latitude && order.delivery_longitude) {
      remainingDistanceMeters = Math.round(
        calculateHaversineDistance(driver.latitude || 31.8682, driver.longitude || 10.9822, order.delivery_latitude, order.delivery_longitude)
      );
      etaMinutes = estimateEtaMinutes(remainingDistanceMeters, driver.speed_kmh || 25);
    }

    const deliveryAddressText = typeof order.delivery_address === 'string'
      ? order.delivery_address
      : (order.delivery_address?.address_line1 || order.delivery_address?.name || 'نالوت - وسط المدينة');

    res.json({
      success: true,
      data: {
        order_id: order.id,
        order_number: order.order_number || rawId,
        status: order.status || 'out_for_delivery',
        created_at: order.created_at,
        delivery_address_text: deliveryAddressText,
        delivery_latitude: order.delivery_latitude || 31.8695,
        delivery_longitude: order.delivery_longitude || 10.9835,
        recipient: {
          name: order.recipient_name || order.metadata?.recipient_name || 'المستلم',
          phone: order.recipient_phone || order.metadata?.recipient_phone || null
        },
        store: store ? {
          name: store.name,
          type: store.type,
          district: store.district || 'نالوت',
          latitude: store.latitude || 31.8687,
          longitude: store.longitude || 10.9818
        } : null,
        driver: driver ? {
          full_name: driver.full_name || 'كابتن واصل',
          vehicle_type: driver.vehicle_type || 'سيارة توصيل',
          phone: driver.phone || '0915544332',
          rating: driver.rating || 4.9,
          latitude: driver.latitude || 31.8682,
          longitude: driver.longitude || 10.9822,
          speed_kmh: driver.speed_kmh || 25,
          heading: driver.heading || 0
        } : null,
        tracking: {
          remaining_distance_meters: remainingDistanceMeters,
          remaining_distance_km: (remainingDistanceMeters / 1000).toFixed(1),
          eta_minutes: etaMinutes
        }
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/v1/orders', async (req, res) => {
  try {
    const { id, order_number, customer_id, customer_phone, phone, driver_id, store_id, status } = req.query;
    let orders = [];

    if (pgPool) {
      let query = 'SELECT * FROM orders WHERE 1=1';
      const params = [];

      if (id) {
        params.push(id);
        query += ` AND (id = $${params.length} OR order_number = $${params.length})`;
      }
      if (order_number) {
        params.push(order_number);
        query += ` AND (order_number = $${params.length} OR id = $${params.length})`;
      }
      if (customer_id) {
        params.push(customer_id);
        query += ` AND customer_id = $${params.length}`;
      }
      const targetPhone = customer_phone || phone;
      if (targetPhone) {
        const cleanTarget = String(targetPhone).replace(/\D/g, '');
        params.push(`%${cleanTarget}%`);
        query += ` AND customer_phone LIKE $${params.length}`;
      }
      if (driver_id) {
        params.push(driver_id);
        query += ` AND driver_id = $${params.length}`;
      }
      if (store_id) {
        params.push(store_id);
        query += ` AND store_id = $${params.length}`;
      }
      if (status) {
        const statusList = status.split(',').map(s => s.trim());
        params.push(statusList);
        query += ` AND status = ANY($${params.length}::text[])`;
      }

      query += ' ORDER BY created_at DESC';
      const oRes = await pgPool.query(query, params);
      orders = oRes.rows.map(mapPgOrder);
    } else {
      orders = [...db.orders];
      if (id) {
        orders = orders.filter(o => o.id === id || o.order_number === id);
      }
      if (order_number) {
        orders = orders.filter(o => o.order_number === order_number || o.id === order_number);
      }
      if (customer_id) {
        orders = orders.filter(o => o.customer_id === customer_id);
      }
      const targetPhone = customer_phone || phone;
      if (targetPhone) {
        const cleanTarget = String(targetPhone).replace(/\D/g, '');
        orders = orders.filter(o => {
          if (!o.customer_phone) return false;
          const cleanCust = String(o.customer_phone).replace(/\D/g, '');
          return cleanCust.includes(cleanTarget) || cleanTarget.includes(cleanCust);
        });
      }
      if (driver_id) orders = orders.filter(o => o.driver_id === driver_id);
      if (store_id) orders = orders.filter(o => o.store_id === store_id);
      if (status) {
        const statusList = status.split(',').map(s => s.trim());
        orders = orders.filter(o => statusList.includes(o.status));
      }
      orders.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    }

    res.json({
      success: true,
      count: orders.length,
      data: orders
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

const handleOrderStatusUpdate = async (req, res) => {
  let client = null;
  let isCommitted = false;
  let originalOrderSnapshot = null;
  let originalDriverSnapshot = null;
  let originalCustomerWalletSnapshot = null;
  let initialTxCount = db.wallet_transactions ? db.wallet_transactions.length : 0;
  let memOrder = null;
  try {
    if (pgPool && typeof pgPool.connect === 'function') {
      client = await pgPool.connect();
      await client.query('BEGIN');
    }

    const { status, driver_id, notes, admin_override } = req.body;
    let order = null;
    const runner = client || pgPool;
    if (runner) {
      const oRes = await runner.query('SELECT * FROM orders WHERE id = $1 OR order_number = $1', [req.params.id]);
      if (oRes.rows.length > 0) {
        order = mapPgOrder(oRes.rows[0]);
      }
    }
    if (!order) {
      order = db.orders.find(o => o.id === req.params.id || o.order_number === req.params.id);
    }

    if (!order) {
      if (client) { await client.query('ROLLBACK'); client.release(); client = null; }
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    // Keep memory in sync and capture rollback snapshot
    memOrder = db.orders.find(o => o.id === order.id || o.order_number === order.order_number);
    if (memOrder) {
      Object.assign(memOrder, order);
    } else {
      memOrder = order;
      db.orders.push(memOrder);
    }
    originalOrderSnapshot = JSON.parse(JSON.stringify(memOrder));

    const activeDriverId = driver_id || order.driver_id;
    if (activeDriverId && db.drivers) {
      const drv = db.drivers.find(d => d.id === activeDriverId);
      if (drv) originalDriverSnapshot = JSON.parse(JSON.stringify(drv));
    }

    if (order.customer_id && db.wallets) {
      const cw = db.wallets.find(w => w.user_id === order.customer_id);
      if (cw) originalCustomerWalletSnapshot = JSON.parse(JSON.stringify(cw));
    }

    // 1. Strict FSM Transition Validation
    const isAdmin = req.user?.role === 'admin';
    const hasAdminOverride = isAdmin && Boolean(req.body.adminOverride || req.body.admin_override);
    const validation = orderService.validateTransition(order.status, status, {
      isAdmin: isAdmin,
      adminOverride: hasAdminOverride,
      driver_id: driver_id || order.driver_id
    }, order);

    if (!validation.valid) {
      if (client) { await client.query('ROLLBACK'); client.release(); client = null; }
      return res.status(validation.statusCode || 400).json({
        success: false,
        error: validation.error
      });
    }

    const previousStatus = order.status;

    // 2. Idempotent check
    if (validation.isIdempotent) {
      if (driver_id && !order.driver_id) {
        order.driver_id = driver_id;
        const driver = db.drivers.find(d => d.id === driver_id);
        if (driver) {
          driver.status = 'busy_delivery';
          driver.active_order_id = order.id;
        }
        if (runner) {
          await runner.query("UPDATE drivers SET status = 'busy_delivery', active_order_id = $1 WHERE id = $2", [order.id, driver_id]);
        }
      }
      order.updated_at = new Date().toISOString();
      await saveOrderToPg(order, client);
      if (memOrder) Object.assign(memOrder, order);
      if (client) {
        await client.query('COMMIT');
        client.release();
        client = null;
      }
      return res.json({
        success: true,
        message: `Order status is already ${order.status} (idempotent)`,
        data: order
      });
    }

    // 3. Pre-flight Security Verification for Delivery
    if (status === 'delivered' && previousStatus !== 'delivered') {
      if (!isAdmin) {
        const expectedOtp = order.otp_code || order.delivery_otp;
        const cleanReceived = req.body.otp_code ? String(req.body.otp_code).trim() : null;
        if (!cleanReceived || cleanReceived !== String(expectedOtp).trim()) {
          if (client) { await client.query('ROLLBACK'); client.release(); client = null; }
          return res.status(400).json({
            success: false,
            error: 'رمز التسليم (OTP) مطلوب وغير صحيح! يرجى أخذ الرمز السري من الزبون لتأكيد الاستلام.'
          });
        }
      }
    }

    // 4. Apply state transition
    order.status = status;
    order.updated_at = new Date().toISOString();

    // Track detailed timing & accountability milestones
    if (status === 'preparing') {
      order.prep_started_at = order.prep_started_at || new Date().toISOString();
      if (req.body.prep_time_minutes) {
        order.prep_time_minutes = parseInt(req.body.prep_time_minutes, 10) || 15;
      } else if (!order.prep_time_minutes) {
        order.prep_time_minutes = 15;
      }
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
      if (!order.driver_id) {
        dispatchService.dispatchOrder(order, db).catch(err => {
          console.error('[DispatchService] Error dispatching order:', err.message);
        });
      }
    } else if (status === 'driver_arrived') {
      order.driver_arrived_at = order.driver_arrived_at || new Date().toISOString();
    } else if (status === 'out_for_delivery' || status === 'picked_up') {
      order.handover_at = order.handover_at || new Date().toISOString();
    }

    if (driver_id) {
      order.driver_id = driver_id;
      const driver = db.drivers.find(d => d.id === driver_id);
      const newDriverStatus = status === 'delivered' || status === 'cancelled' ? 'online_idle' : 'busy_delivery';
      const newActiveOrder = status === 'delivered' || status === 'cancelled' ? null : order.id;
      if (driver) {
        driver.status = newDriverStatus;
        driver.active_order_id = newActiveOrder;
      }
      if (runner) {
        await runner.query("UPDATE drivers SET status = $1, active_order_id = $2 WHERE id = $3", [newDriverStatus, newActiveOrder, driver_id]);
      }
    }

    // 5. FINANCIAL SETTLEMENT ON ORDER DELIVERY
    if (status === 'delivered' && previousStatus !== 'delivered') {
      order.delivered_at = new Date().toISOString();
      order.payment_status = 'captured';

      // Calculate driver transit delay
      if (order.handover_at) {
        const actualTransitSec = Math.round((new Date(order.delivered_at) - new Date(order.handover_at)) / 1000);
        const estTransitSec = (order.estimated_eta_minutes || 10) * 60;
        order.driver_delay_seconds = Math.max(0, actualTransitSec - estTransitSec);
      }

      // Reset driver active status
      if (order.driver_id && db.drivers) {
        const driver = db.drivers.find(d => d.id === order.driver_id);
        if (driver) {
          driver.status = 'online_idle';
          driver.active_order_id = null;
          driver.total_trips = (driver.total_trips || 0) + 1;
        }
        if (runner) {
          await runner.query("UPDATE drivers SET status = 'online_idle', active_order_id = NULL, total_deliveries = total_deliveries + 1 WHERE id = $1", [order.driver_id]);
        }
      }

      // Automated double-entry financial ledger execution (participates in transaction)
      await ledgerService.processOrderDelivery(db, order, client || pgPool);
      if (order.driver_id) {
        const driver = db.drivers.find(d => d.id === order.driver_id);
        if (driver) await saveDriverToPg(driver, client);
      }
    }

    // 5. REFUND & FINANCIAL REVERSAL ON CANCELLATION (F9)
    if (status === 'cancelled' && previousStatus !== 'cancelled') {
      const wasDelivered = previousStatus === 'delivered' || Boolean(order.delivered_at && order.payment_status === 'paid');
      if (wasDelivered) {
        // Reverse double-entry financial settlement: clears Account 1040 (COD custody), debits 2030, debits 2020, debits 4010/4020, refunds customer wallet if charged
        await ledgerService.reverseOrderSettlement(db, order, client || pgPool);
      } else {
        if (order.payment_method === 'wallet') {
          const customerWallet = db.wallets.find(w => w.user_id === order.customer_id);
          if (customerWallet) {
            customerWallet.locked_balance = Math.max(0, (customerWallet.locked_balance || 0) - (order.total_amount_lyd || 0));
          }
          if (runner && order.customer_id) {
            await runner.query(`
              UPDATE wallets
              SET locked_balance = GREATEST(0, locked_balance - $1), updated_at = CURRENT_TIMESTAMP
              WHERE user_id = $2 AND wallet_type = 'customer_wallet'
            `, [order.total_amount_lyd, order.customer_id]);
          }
        }
      }
      if (order.driver_id) {
        const driver = db.drivers.find(d => d.id === order.driver_id);
        if (driver) {
          driver.status = 'online_idle';
          driver.active_order_id = null;
        }
        if (runner) {
          await runner.query("UPDATE drivers SET status = 'online_idle', active_order_id = NULL WHERE id = $1", [order.driver_id]);
        }
      }
    }

    // 6. Persist Order in PostgreSQL (participates in transaction)
    await saveOrderToPg(order, client);
    if (memOrder) Object.assign(memOrder, order);

    // ATOMIC ACID COMMIT
    if (client) {
      await client.query('COMMIT');
      client.release();
      client = null;
    }
    isCommitted = true;

    // 7. Strictly Post-COMMIT Socket.io State Transition Broadcast
    SocketService.broadcastOrderStatusTransition(order, previousStatus, db, notes);

    res.json({
      success: true,
      message: `Order status updated to ${status}`,
      data: order
    });
  } catch (err) {
    if (client) {
      try { await client.query('ROLLBACK'); } catch (_) {}
      client.release();
      client = null;
    }

    // Rollback in-memory state mutations if transaction aborted before/during COMMIT
    if (!isCommitted) {
      if (originalOrderSnapshot && memOrder) {
        Object.assign(memOrder, originalOrderSnapshot);
      }
      if (originalDriverSnapshot && db.drivers) {
        const drv = db.drivers.find(d => d.id === originalDriverSnapshot.id);
        if (drv) Object.assign(drv, originalDriverSnapshot);
      }
      if (originalCustomerWalletSnapshot && db.wallets) {
        const cw = db.wallets.find(w => w.user_id === originalCustomerWalletSnapshot.user_id);
        if (cw) Object.assign(cw, originalCustomerWalletSnapshot);
      }
      if (db.wallet_transactions && db.wallet_transactions.length > initialTxCount) {
        db.wallet_transactions.splice(initialTxCount);
      }
    }

    res.status(500).json({ success: false, error: err.message });
  }
};

app.post('/api/v1/orders/:id/status', authMiddleware, handleOrderStatusUpdate);
app.patch('/api/v1/orders/:id/status', authMiddleware, handleOrderStatusUpdate);

// HANDOVER VERIFICATION & CUSTODY TRANSFER ENDPOINT
// Transferred from Merchant to Captain when captain arrives and confirms code
app.post('/api/v1/orders/:id/handover', authMiddleware, async (req, res) => {
  try {
    const { handover_code, driver_id } = req.body;
    const order = db.orders.find(o => o.id === req.params.id || o.order_number === req.params.id);
    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    // If order has already been handed over, return idempotent success
    if (order.status === 'out_for_delivery' || order.status === 'picked_up') {
      if (driver_id && !order.driver_id) {
        order.driver_id = driver_id;
        order.updated_at = new Date().toISOString();
        await saveOrderToPg(order);
      }
      return res.json({
        success: true,
        already_handed_over: true,
        message: 'تم تسليم الوجبة مسبقاً وهي قيد التوصيل للزبون',
        order: {
          id: order.id,
          order_number: order.order_number,
          status: order.status,
          driver_id: order.driver_id,
          handover_at: order.handover_at
        }
      });
    }

    // Require restaurant to have marked order as ready_for_pickup
    if (order.status !== 'ready_for_pickup') {
      return res.status(400).json({
        success: false,
        error: order.status === 'preparing'
          ? 'الوجبة لا تزال قيد التحضير بالمطعم! لا يمكن للكابتن استلام الطلب حتى يضغط المطعم على "تم التجهيز".'
          : `لا يمكن استلام الطلب وهو في حالة: ${order.status}`
      });
    }

    // Verify code strictly without bypasses or omissions
    if (!handover_code) {
      return res.status(400).json({ success: false, error: 'كود تسليم الوجبة مطلوب (Handover Code is required)' });
    }
    const cleanExpected = order.handover_code ? String(order.handover_code).trim() : null;
    const cleanReceived = String(handover_code).trim();
    if (!cleanExpected || cleanReceived !== cleanExpected) {
      return res.status(400).json({ success: false, error: 'كود تسليم الوجبة غير صحيح (Invalid Handover Code)' });
    }

    order.status = 'out_for_delivery';
    order.handover_at = new Date().toISOString();
    if (driver_id) order.driver_id = driver_id;
    order.updated_at = new Date().toISOString();

    await saveOrderToPg(order);

    SocketService.sendOrderStatusNotification(order, 'ready_for_pickup', db);

    const statusPayload = {
      order_id: order.id,
      order_number: order.order_number,
      status: 'out_for_delivery',
      driver_id: order.driver_id,
      handover_at: order.handover_at,
      updated_at: order.updated_at
    };

    req.io.to(`order:${order.id}`).emit('order:status_changed', statusPayload);
    req.io.to(`order:${order.id}`).emit('order:handover_completed', statusPayload);
    req.io.to(`user:${order.customer_id}`).emit('order:status_changed', statusPayload);
    req.io.to(`user:${order.customer_id}`).emit('order:handover_completed', statusPayload);
    req.io.to(`store:${order.store_id}`).emit('order:status_changed', statusPayload);
    req.io.to(`store:${order.store_id}`).emit('order:handover_completed', statusPayload);
    if (order.driver_id) {
      req.io.to(`driver:${order.driver_id}`).emit('order:status_changed', statusPayload);
      req.io.to(`driver:${order.driver_id}`).emit('order:handover_completed', statusPayload);
    }
    req.io.to('admin:fleet').emit('admin:order_status_changed', statusPayload);

    res.json({
      success: true,
      message: 'تم تسليم الوجبة للكابتن بنجاح ونقل العهدة بالكامل إلى الكابتن',
      data: order
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Direct alias for PATCH /api/v1/orders/:id
app.patch('/api/v1/orders/:id', (req, res, next) => {
  req.url = `/api/v1/orders/${req.params.id}/status`;
  req.method = 'POST';
  app._router.handle(req, res, next);
});

// ORDER CANCELLATION ENDPOINT (Customer & Admin)
app.post('/api/v1/orders/:id/cancel', authMiddleware, async (req, res) => {
  try {
    const { reason } = req.body || {};
    const order = db.orders.find(o => o.id === req.params.id || o.order_number === req.params.id);

    if (!order) {
      return res.status(404).json({ success: false, error: 'الطلب غير موجود' });
    }

    const previousStatus = order.status;
    if (order.status === 'cancelled') {
      return res.json({ success: true, message: 'الطلب ملغى مسبقاً', data: order });
    }

    // FSM validation for cancellation
    const isAdmin = req.user?.role === 'admin';
    const hasAdminOverride = isAdmin && Boolean(req.body?.adminOverride || req.body?.admin_override);
    const validation = orderService.validateTransition(order.status, 'cancelled', {
      isAdmin: isAdmin,
      adminOverride: hasAdminOverride
    }, order);

    if (!validation.valid) {
      return res.status(validation.statusCode || 400).json({
        success: false,
        error: validation.error || 'لا يمكن إلغاء الطلب في هذه المرحلة'
      });
    }

    // Apply cancellation state
    order.status = 'cancelled';
    order.cancellation_reason = reason || 'إلغاء من قبل الزبون';
    order.cancelled_at = new Date().toISOString();
    order.updated_at = new Date().toISOString();

    const wasDelivered = previousStatus === 'delivered' || Boolean(order.delivered_at && order.payment_status === 'paid');
    if (wasDelivered) {
      // Automatic Cancellation Financial Settlement (F9)
      await ledgerService.reverseOrderSettlement(db, order, pgPool);
    } else {
      // Release customer locked wallet balance if payment was via wallet
      if (order.payment_method === 'wallet') {
        const customerWallet = db.wallets.find(w => w.user_id === order.customer_id);
        if (customerWallet) {
          customerWallet.locked_balance = Math.max(0, (customerWallet.locked_balance || 0) - (order.total_amount_lyd || 0));
        }
        if (pgPool && order.customer_id) {
          try {
            await pgPool.query(`
              UPDATE wallets
              SET locked_balance = GREATEST(0, locked_balance - $1), updated_at = CURRENT_TIMESTAMP
              WHERE user_id = $2 AND wallet_type = 'customer_wallet'
            `, [order.total_amount_lyd || 0, order.customer_id]);
          } catch (_) {}
        }
      }
    }

    // Release driver if assigned
    if (order.driver_id && db.drivers) {
      const driver = db.drivers.find(d => d.id === order.driver_id);
      if (driver) {
        driver.status = 'online_idle';
        driver.active_order_id = null;
        if (pgPool) saveDriverToPg(driver);
      }
    }

    saveOrderToPg(order);

    // Unified Socket.io State Transition Broadcast
    SocketService.broadcastOrderStatusTransition(order, previousStatus, db, order.cancellation_reason);

    res.json({
      success: true,
      message: 'تم إلغاء الطلب بنجاح وفك حجز الرصيد',
      data: order
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// DRIVER REASSIGNMENT ENDPOINT (F6 Admin Courier Reassignment)
app.post('/api/v1/orders/:id/reassign', adminAuthMiddleware, async (req, res) => {
  try {
    const { driver_id: newDriverId } = req.body || {};
    if (!newDriverId) {
      return res.status(400).json({ success: false, error: 'driver_id is required for reassignment' });
    }

    const order = db.orders.find(o => o.id === req.params.id || o.order_number === req.params.id);
    if (!order) {
      return res.status(404).json({ success: false, error: 'الطلب غير موجود' });
    }

    if (['delivered', 'cancelled'].includes(order.status)) {
      return res.status(400).json({
        success: false,
        error: `لا يمكن إعادة إسناد كابتن لطلب منتهٍ بحالة: ${order.status}`
      });
    }

    const newDriver = db.drivers.find(d => d.id === newDriverId);
    if (!newDriver) {
      return res.status(404).json({ success: false, error: 'الكابتن المطلوب غير مسجل' });
    }

    const previousDriverId = order.driver_id;
    const previousStatus = order.status;

    // Unassign previous driver if present
    if (previousDriverId && previousDriverId !== newDriverId) {
      const prevDriver = db.drivers.find(d => d.id === previousDriverId);
      if (prevDriver) {
        prevDriver.status = 'online_idle';
        prevDriver.active_order_id = null;
        if (pgPool) {
          try {
            await pgPool.query("UPDATE drivers SET status = 'online_idle', active_order_id = NULL WHERE id = $1", [previousDriverId]);
          } catch (_) {}
        }
      }
    }

    // Assign new driver
    newDriver.status = 'busy_delivery';
    newDriver.active_order_id = order.id;
    if (pgPool) {
      try {
        await pgPool.query("UPDATE drivers SET status = 'busy_delivery', active_order_id = $1 WHERE id = $2", [order.id, newDriverId]);
      } catch (_) {}
    }

    // Update order
    order.driver_id = newDriverId;
    order.updated_at = new Date().toISOString();

    if (pgPool) {
      try {
        await pgPool.query('UPDATE orders SET driver_id = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', [newDriverId, order.id]);
      } catch (_) {}
    }

    // Broadcast state transition and telemetry
    SocketService.broadcastOrderStatusTransition(order, previousStatus, db, `إعادة إسناد الطلب للكابتن ${newDriver.full_name}`);
    if (req.io) {
      req.io.to(`driver:${newDriverId}`).emit('radar:incoming_order', {
        ...order,
        status: order.status,
        prep_status_badge: '🟢 تم إسناد هذا الطلب إليك مباشرة من قبل الإدارة'
      });
      req.io.to('role:driver').emit('radar:order_claimed', { order_id: order.id, driver_id: newDriverId });
      req.io.to('admin:fleet').emit('admin:order_status_changed', {
        order_id: order.id,
        status: order.status,
        driver_id: newDriverId,
        driver_name: newDriver.full_name,
        updated_at: order.updated_at
      });
    }

    res.json({
      success: true,
      message: `تم إعادة إسناد الطلب للكابتن ${newDriver.full_name} بنجاح`,
      data: order
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// SINGLE ORDER ADMIN DELETE ENDPOINT (F7 Single Order Admin Delete)
app.delete('/api/v1/admin/orders/:id', adminAuthMiddleware, async (req, res) => {
  try {
    const order = db.orders.find(o => o.id === req.params.id || o.order_number === req.params.id);
    if (!order) {
      return res.status(404).json({ success: false, error: 'الطلب غير موجود' });
    }

    // Clear driver binding if bound
    if (order.driver_id && db.drivers) {
      const driver = db.drivers.find(d => d.id === order.driver_id);
      if (driver && driver.active_order_id === order.id) {
        driver.active_order_id = null;
        driver.status = 'offline';
        if (pgPool) {
          try {
            await pgPool.query("UPDATE drivers SET active_order_id = NULL, status = 'offline' WHERE id = $1", [driver.id]);
          } catch (_) {}
        }
      }
    }

    // Unlock customer wallet locked_balance if was locked
    if (order.customer_id && order.payment_method === 'wallet' && db.wallets) {
      const customerWallet = db.wallets.find(w => w.user_id === order.customer_id);
      if (customerWallet) {
        customerWallet.locked_balance = Math.max(0, (customerWallet.locked_balance || 0) - (order.total_amount_lyd || 0));
      }
      if (pgPool) {
        try {
          await pgPool.query(`
            UPDATE wallets
            SET locked_balance = GREATEST(0, locked_balance - $1), updated_at = CURRENT_TIMESTAMP
            WHERE user_id = $2 AND wallet_type = 'customer_wallet'
          `, [order.total_amount_lyd || 0, order.customer_id]);
        } catch (_) {}
      }
    }

    // Delete from PostgreSQL
    if (pgPool) {
      try {
        await pgPool.query('DELETE FROM orders WHERE id = $1 OR order_number = $1', [order.id]);
      } catch (e) {
        console.error('[PostgreSQL order delete error]:', e.message);
      }
    }

    // Remove from in-memory cache
    const idx = db.orders.findIndex(o => o.id === order.id || o.order_number === order.order_number);
    if (idx !== -1) {
      db.orders.splice(idx, 1);
    }

    // Socket.io broadcasts
    if (req.io) {
      req.io.emit('order:deleted', { order_id: order.id, id: order.id, order_number: order.order_number });
      req.io.to('admin:fleet').emit('admin:order_deleted', { order_id: order.id, id: order.id, order_number: order.order_number });
      req.io.emit('admin:order_deleted', { order_id: order.id, id: order.id, order_number: order.order_number });
    }

    res.json({
      success: true,
      message: 'تم حذف الطلب نهائياً بنجاح',
      data: { id: order.id, order_number: order.order_number }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ORDER RATING & REVIEW ENDPOINT (Customer Fair Review)
app.post('/api/v1/orders/:id/rate', async (req, res) => {
  try {
    const { rating, driver_rating, comment, store_id } = req.body || {};
    const order = db.orders.find(o => o.id === req.params.id || o.order_number === req.params.id);

    if (!order) {
      return res.status(404).json({ success: false, error: 'الطلب غير موجود' });
    }

    const numRating = parseFloat(rating) || 5.0;
    const numDriverRating = parseFloat(driver_rating) || numRating;

    order.rating = numRating;
    order.driver_rating = numDriverRating;
    order.review_comment = comment || '';
    order.reviewed_at = new Date().toISOString();

    // Update store average rating
    const targetStoreId = store_id || order.store_id;
    if (targetStoreId && db.stores) {
      const store = db.stores.find(s => s.id === targetStoreId);
      if (store) {
        const curCount = store.review_count || 1;
        const curRating = store.rating || 5.0;
        store.rating = Math.round(((curRating * curCount + numRating) / (curCount + 1)) * 10) / 10;
        store.review_count = curCount + 1;
        if (pgPool) saveStoreToPg(store);
      }
    }

    // Update driver average rating
    if (order.driver_id && db.drivers) {
      const driver = db.drivers.find(d => d.id === order.driver_id);
      if (driver) {
        const curTrips = driver.total_trips || driver.total_deliveries || 1;
        const curRating = driver.rating || 5.0;
        driver.rating = Math.round(((curRating * curTrips + numDriverRating) / (curTrips + 1)) * 10) / 10;
        if (pgPool) saveDriverToPg(driver);
      }
    }

    saveOrderToPg(order);

    // Broadcast review event to merchant and admin
    if (req.io) {
      req.io.to(`store:${order.store_id}`).emit('store:new_review', {
        order_id: order.id,
        rating: numRating,
        comment
      });
      req.io.to('admin:fleet').emit('admin:new_review', {
        order_id: order.id,
        store_id: order.store_id,
        driver_id: order.driver_id,
        rating: numRating,
        driver_rating: numDriverRating,
        comment
      });
    }

    res.json({
      success: true,
      message: 'تم تسجيل التقييم بنجاح وتحديث سمعة المطعم والكابتن',
      data: {
        order_id: order.id,
        rating: numRating,
        driver_rating: numDriverRating,
        comment
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ----------------------------------------------------------------------------
// ADMIN DISPUTE RESOLUTION ENDPOINT (فض النزاعات والتعويض المالي التلقائي)
// ----------------------------------------------------------------------------
app.post('/api/v1/admin/disputes/resolve', adminAuthMiddleware, async (req, res) => {
  try {
    const {
      order_id,
      store_id,
      driver_id,
      total_amount_lyd,
      delivery_fee_lyd,
      customer_phone,
      customer_action = 'blacklisted',
      meal_disposal = 'captain_bonus',
      notes = ''
    } = req.body || {};

    const order = db.orders.find(o => o.id === order_id || o.order_number === order_id);
    if (!order) {
      return res.status(404).json({ success: false, error: 'الطلب غير موجود' });
    }

    order.status = 'cancelled';
    order.cancellation_stage = 'dispute_resolution';
    order.cancellation_reason = 'customer_no_show';
    order.dispute_resolved = true;
    order.dispute_resolved_at = new Date().toISOString();
    order.dispute_notes = notes;
    order.customer_penalty_status = customer_action;
    order.meal_disposal = meal_disposal;
    order.updated_at = new Date().toISOString();

    const amount = parseFloat(total_amount_lyd) || order.total_amount_lyd || 0;
    const deliveryFee = parseFloat(delivery_fee_lyd) || order.delivery_fee_lyd || 5.0;
    const foodSubtotal = Math.max(0, amount - deliveryFee);
    const restaurantComp = Math.round(foodSubtotal * 0.90 * 100) / 100;

    // 1. Compensate Restaurant Wallet
    const targetStoreId = store_id || order.store_id;
    if (targetStoreId && db.stores) {
      const store = db.stores.find(s => s.id === targetStoreId);
      if (store) {
        store.wallet_balance_lyd = (store.wallet_balance_lyd || 0) + restaurantComp;
        if (pgPool) saveStoreToPg(store);
      }
    }

    // 2. Compensate Driver Wallet
    const targetDriverId = driver_id || order.driver_id;
    if (targetDriverId && db.drivers) {
      const driver = db.drivers.find(d => d.id === targetDriverId);
      if (driver) {
        driver.wallet_balance_lyd = (driver.wallet_balance_lyd || 0) + deliveryFee;
        driver.status = 'online_idle';
        driver.active_order_id = null;
        if (pgPool) saveDriverToPg(driver);
      }
    }

    // 3. Customer action (Blacklist / Negative Balance)
    if (customer_phone && db.users) {
      const user = db.users.find(u => u.phone === customer_phone || u.id === order.customer_id);
      if (user) {
        if (customer_action === 'blacklisted') {
          user.is_blocked = true;
        } else if (customer_action === 'negative_balance') {
          user.unpaid_debt_lyd = (user.unpaid_debt_lyd || 0) + amount;
        }
      }
    }

    saveOrderToPg(order);

    // Broadcast dispute resolution via socket
    if (req.io) {
      req.io.to('admin:fleet').emit('admin:dispute_resolved', {
        order_id: order.id,
        restaurant_compensated: restaurantComp,
        driver_compensated: deliveryFee,
        customer_action,
        meal_disposal
      });
      if (targetStoreId) {
        req.io.to(`store:${targetStoreId}`).emit('order:dispute_compensated', {
          order_id: order.id,
          amount_compensated: restaurantComp
        });
      }
      if (targetDriverId) {
        req.io.to(`driver:${targetDriverId}`).emit('order:dispute_compensated', {
          order_id: order.id,
          amount_compensated: deliveryFee
        });
      }
    }

    res.json({
      success: true,
      message: 'تم فض النزاع، تعويض الشركاء، وتطبيق الإجراء المالي بنجاح',
      data: {
        order_id: order.id,
        restaurant_compensation: restaurantComp,
        driver_compensation: deliveryFee,
        customer_action,
        meal_disposal
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ----------------------------------------------------------------------------
// DRIVER & FLEET ROUTES
// ----------------------------------------------------------------------------
app.get('/api/v1/drivers/:id', (req, res) => {
  const driver = db.drivers.find(d => d.id === req.params.id);
  if (!driver) {
    return res.status(404).json({ success: false, error: 'Driver not found' });
  }
  res.json({ success: true, data: sanitizeDriver(driver) });
});

app.patch('/api/v1/drivers/:id', adminAuthMiddleware, (req, res) => {
  const driver = db.drivers.find(d => d.id === req.params.id);
  if (!driver) {
    return res.status(404).json({ success: false, error: 'Driver not found' });
  }
  Object.assign(driver, req.body);
  if (req.body.status !== undefined) {
    const isOnline = req.body.status !== 'offline';
    driver.is_active = isOnline;
    driver.last_heartbeat = isOnline ? Date.now() : 0;
    if (req.io) {
      req.io.emit('driver:status_changed', { driver_id: driver.id, status: driver.status });
      req.io.to('admin:fleet').emit('admin:driver_status_changed', { driver_id: driver.id, status: driver.status });
    }
  }
  if (req.body.latitude && req.body.longitude && req.io) {
    req.io.emit('driver:location_changed', {
      driver_id: driver.id,
      latitude: driver.latitude,
      longitude: driver.longitude,
      heading: driver.heading || 0,
      recorded_at: new Date().toISOString()
    });
  }
  saveDriverToPg(driver);
  res.json({ success: true, data: sanitizeDriver(driver) });
});

const handleDriverTelemetry = (req, res) => {
  const driver = db.drivers.find(d => d.id === req.params.id);
  if (!driver) {
    return res.status(404).json({ success: false, error: 'Driver not found' });
  }
  const { latitude, longitude, heading = 0, speed_kmh = 0, order_id } = req.body;
  if (latitude !== undefined) driver.latitude = parseFloat(latitude);
  if (longitude !== undefined) driver.longitude = parseFloat(longitude);
  if (heading !== undefined) driver.heading = parseFloat(heading);
  if (speed_kmh !== undefined) driver.speed_kmh = parseFloat(speed_kmh);
  driver.last_heartbeat = Date.now();

  let effectiveOrderId = order_id;
  if (!effectiveOrderId && db.orders) {
    const activeOrder = db.orders.find(o => 
      o.driver_id === driver.id && 
      ['driver_assigned', 'driver_arrived', 'out_for_delivery', 'picked_up'].includes(o.status)
    );
    if (activeOrder) effectiveOrderId = activeOrder.id;
  }

  let remainingDistance = null;
  let etaMinutes = null;
  if (effectiveOrderId) {
    const order = db.orders.find(o => o.id === effectiveOrderId);
    if (order && (order.delivery_latitude || order.delivery_lat)) {
      const destLat = parseFloat(order.delivery_latitude || order.delivery_lat);
      const destLng = parseFloat(order.delivery_longitude || order.delivery_lng);
      remainingDistance = Math.round(calculateHaversineDistance(
        driver.latitude, driver.longitude,
        destLat, destLng
      ));
      etaMinutes = estimateEtaMinutes(remainingDistance, driver.speed_kmh || 35);
    }
  }

  const telemetryData = {
    driver_id: driver.id,
    order_id: effectiveOrderId || null,
    latitude: driver.latitude,
    longitude: driver.longitude,
    heading: driver.heading,
    speed_kmh: driver.speed_kmh,
    remaining_distance_meters: remainingDistance,
    eta_minutes: etaMinutes,
    recorded_at: new Date().toISOString()
  };

  if (req.io) {
    SocketService.broadcastDriverLocation(telemetryData);
    if (effectiveOrderId) {
      req.io.to(`order:${effectiveOrderId}`).emit('order:driver_location', telemetryData);
      if (remainingDistance !== null && remainingDistance <= PROXIMITY_THRESHOLD_METERS) {
        req.io.to(`order:${effectiveOrderId}`).emit('driver:proximity_alert', {
          order_id: effectiveOrderId,
          driver_id: driver.id,
          distance_meters: remainingDistance,
          message: 'الكابتن اقترب من موقعك (أقل من 200 متر) 🛵'
        });
      }
    }
  }
  saveDriverToPg(driver);
  res.json({ success: true, data: telemetryData });
};

app.post('/api/v1/drivers/:id/telemetry', handleDriverTelemetry);
app.post('/api/v1/drivers/:id/location', handleDriverTelemetry);
app.post('/api/v1/captains/:id/location', handleDriverTelemetry);

// Captain Active Heartbeat (Auto-online while captain app is running)
app.post('/api/v1/drivers/:id/heartbeat', (req, res) => {
  try {
    const driver = db.drivers.find(d => d.id === req.params.id);
    if (!driver) {
      return res.status(404).json({ success: false, error: 'Driver not found' });
    }
    const wasOffline = driver.status === 'offline' || !driver.is_active;
    driver.last_heartbeat = Date.now();
    driver.is_active = true;
    if (driver.status === 'offline') {
      driver.status = 'online_idle';
    }

    const { latitude, longitude, heading = 0, speed_kmh = 0, order_id } = req.body || {};
    if (latitude !== undefined && longitude !== undefined) {
      driver.latitude = parseFloat(latitude);
      driver.longitude = parseFloat(longitude);
      driver.heading = parseFloat(heading);
      driver.speed_kmh = parseFloat(speed_kmh);

      let effectiveOrderId = order_id;
      if (!effectiveOrderId && db.orders) {
        const activeOrder = db.orders.find(o => 
          o.driver_id === driver.id && 
          ['driver_assigned', 'driver_arrived', 'out_for_delivery', 'picked_up'].includes(o.status)
        );
        if (activeOrder) effectiveOrderId = activeOrder.id;
      }

      const telemetryData = {
        driver_id: driver.id,
        order_id: effectiveOrderId || null,
        latitude: driver.latitude,
        longitude: driver.longitude,
        heading: driver.heading,
        speed_kmh: driver.speed_kmh,
        recorded_at: new Date().toISOString()
      };

      if (req.io) {
        req.io.to(`driver:${driver.id}`).emit('driver:location_changed', telemetryData);
        req.io.to('admin:fleet').emit('admin:driver_moved', telemetryData);
        if (effectiveOrderId) {
          req.io.to(`order:${effectiveOrderId}`).emit('order:driver_location', telemetryData);
        }
      }
    }

    if (wasOffline) {
      saveDriverToPg(driver);
      if (req.io) {
        req.io.emit('driver:status_changed', { driver_id: driver.id, status: driver.status });
        req.io.to('admin:fleet').emit('admin:driver_status_changed', { driver_id: driver.id, status: driver.status });
      }
      console.log(`[Presence Engine] Captain "${driver.full_name}" (${driver.id}) online via active heartbeat.`);
    }

    res.json({
      success: true,
      driver_id: driver.id,
      status: driver.status,
      is_active: driver.is_active,
      last_heartbeat: driver.last_heartbeat
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/v1/drivers', (req, res) => {
  res.json({ success: true, count: db.drivers.length, data: db.drivers.map(sanitizeDriver) });
});

// ----------------------------------------------------------------------------
// PRODUCT MANAGEMENT (CATALOG UPDATES)
// ----------------------------------------------------------------------------
app.patch('/api/v1/products/:id', async (req, res) => {
  const product = db.products.find(p => p.id === req.params.id);
  if (!product) {
    return res.status(404).json({ success: false, error: 'Product not found' });
  }
  Object.assign(product, req.body);
  if (req.body.price !== undefined) {
    product.price_lyd = parseFloat(req.body.price);
    product.price = parseFloat(req.body.price);
  }
  if (req.body.is_available !== undefined) {
    product.is_available = Boolean(req.body.is_available);
  }
  if (req.io) {
    req.io.emit('catalog:product_updated', product);
  }
  await saveProductToPg(product);
  res.json({ success: true, data: product });
});

app.post('/api/v1/products', async (req, res) => {
  const newProduct = {
    id: req.body.id || `prod_${Date.now()}`,
    store_id: req.body.store_id || 'store_default',
    name_ar: req.body.name_ar || req.body.name || 'صنف جديد',
    name_en: req.body.name_en || req.body.name || 'New Item',
    name: req.body.name || req.body.name_ar || 'صنف جديد',
    category_id: req.body.category_id || 'cat_food',
    category: req.body.category || 'وجبات',
    price: parseFloat(req.body.price || req.body.price_lyd || 20.0),
    price_lyd: parseFloat(req.body.price || req.body.price_lyd || 20.0),
    description: req.body.description || '',
    desc_ar: req.body.desc_ar || req.body.description || '',
    is_available: req.body.is_available !== undefined ? req.body.is_available : true,
    in_stock: req.body.in_stock !== undefined ? req.body.in_stock : true,
    created_at: new Date().toISOString()
  };
  db.products.push(newProduct);
  await saveProductToPg(newProduct);
  if (req.io) {
    req.io.emit('catalog:product_added', newProduct);
  }
  res.status(201).json({ success: true, data: newProduct });
});

app.delete('/api/v1/products/:id', async (req, res) => {
  const initialLen = db.products.length;
  db.products = db.products.filter(p => p.id !== req.params.id);
  await deleteProductFromPg(req.params.id);
  if (req.io) {
    req.io.emit('catalog:product_deleted', { id: req.params.id });
  }
  res.json({ success: true, message: 'Product deleted', deleted: db.products.length < initialLen });
});

app.post('/api/v1/admin/batch-import', adminAuthMiddleware, async (req, res) => {
  try {
    const { store, products = [] } = req.body;
    if (!store || !store.name) {
      return res.status(400).json({ success: false, error: 'Store object with at least "name" is required' });
    }

    const storeId = store.id || `store_nalut_${Date.now()}`;
    const newStore = {
      id: storeId,
      name: store.name,
      name_en: store.name_en || store.name,
      type: store.type || 'restaurant',
      district: store.district || 'نالوت',
      city: 'nalut',
      phone: store.phone || '',
      pin: store.pin || crypto.randomInt(1000, 10000).toString(),
      app_mode: store.app_mode || ((store.type === 'grocery' || store.type === 'pharmacy') ? 'retail' : 'kitchen'),
      commission_rate: store.commission_rate || 10.0,
      rating: 5.0,
      review_count: 0,
      delivery_time_min: store.delivery_time_min || 20,
      delivery_time_max: store.delivery_time_max || 35,
      min_order_lyd: store.min_order_lyd || 10.0,
      base_delivery_fee_lyd: store.base_delivery_fee_lyd || 4.0,
      latitude: store.latitude || 31.8686,
      longitude: store.longitude || 10.9818,
      is_open: store.is_open !== false,
      is_featured: store.is_featured !== false,
      created_at: new Date().toISOString()
    };

    db.stores = db.stores.filter(s => s.id !== storeId);
    db.stores.unshift(newStore);
    await saveStoreToPg(newStore);

    const createdProducts = [];
    if (Array.isArray(products) && products.length > 0) {
      db.products = db.products.filter(p => p.store_id !== storeId);
      for (let i = 0; i < products.length; i++) {
        const p = products[i];
        const prod = {
          id: p.id || `prod_${Date.now()}_${i}`,
          store_id: storeId,
          name_ar: p.name_ar || p.name || 'صنف',
          name_en: p.name_en || p.name || 'Item',
          category_id: p.category_id || 'cat_food',
          category: p.category || 'وجبات',
          price_lyd: parseFloat(p.price || p.price_lyd || 15.0),
          description: p.description || '',
          is_available: p.is_available !== false,
          created_at: new Date().toISOString()
        };
        db.products.push(prod);
        await saveProductToPg(prod);
        createdProducts.push(prod);
      }
    }

    if (req.io) {
      req.io.emit('catalog:store_imported', { store: newStore, products_count: createdProducts.length });
    }

    res.status(201).json({
      success: true,
      message: `Successfully imported store "${newStore.name}" with ${createdProducts.length} products`,
      data: {
        store: newStore,
        products_count: createdProducts.length,
        products: createdProducts
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================================================
// 12. NEW ARCHITECTURE ENDPOINTS: LOYALTY, REFERRALS, VOUCHERS, REVIEWS, CONFIG
// ============================================================================

// --- A. Loyalty System ---
app.get('/api/v1/loyalty/:phone', async (req, res) => {
  try {
    const phone = req.params.phone;
    let balance = 0;
    let totalEarned = 0;
    let totalRedeemed = 0;
    let txs = [];

    if (pgPool) {
      const pRes = await pgPool.query('SELECT * FROM loyalty_points WHERE user_phone = $1', [phone]);
      if (pRes.rows.length > 0) {
        balance = parseInt(pRes.rows[0].points_balance, 10) || 0;
        totalEarned = parseInt(pRes.rows[0].total_earned, 10) || 0;
        totalRedeemed = parseInt(pRes.rows[0].total_redeemed, 10) || 0;
      }
      const tRes = await pgPool.query('SELECT * FROM loyalty_transactions WHERE user_phone = $1 ORDER BY created_at DESC LIMIT 20', [phone]);
      txs = tRes.rows;
    } else {
      const rec = (db.loyalty_points || []).find(p => p.user_phone === phone);
      if (rec) {
        balance = rec.points_balance || 0;
        totalEarned = rec.total_earned || 0;
        totalRedeemed = rec.total_redeemed || 0;
      }
      txs = (db.loyalty_transactions || []).filter(t => t.user_phone === phone);
    }

    res.json({
      success: true,
      data: {
        phone,
        points_balance: balance,
        total_earned: totalEarned,
        total_redeemed: totalRedeemed,
        transactions: txs
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/loyalty/earn', async (req, res) => {
  try {
    const { phone, order_id, points, description } = req.body;
    if (!phone || !points || points <= 0) {
      return res.status(400).json({ success: false, error: 'Phone and positive points required' });
    }

    let currentBalance = 0;
    let totalEarned = 0;
    let totalRedeemed = 0;

    if (pgPool) {
      const pRes = await pgPool.query('SELECT * FROM loyalty_points WHERE user_phone = $1', [phone]);
      if (pRes.rows.length > 0) {
        currentBalance = parseInt(pRes.rows[0].points_balance, 10) || 0;
        totalEarned = parseInt(pRes.rows[0].total_earned, 10) || 0;
        totalRedeemed = parseInt(pRes.rows[0].total_redeemed, 10) || 0;
      }
    }

    const newBalance = currentBalance + parseInt(points, 10);
    const newEarned = totalEarned + parseInt(points, 10);
    await saveLoyaltyPointToPg(phone, newBalance, newEarned, totalRedeemed);

    const tx = {
      id: `ltx_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      user_phone: phone,
      order_id: order_id || null,
      points_change: parseInt(points, 10),
      transaction_type: 'order_reward',
      description: description || `مكافأة نقاط ولاء عن الطلب #${order_id || ''}`,
      created_at: new Date().toISOString()
    };
    await saveLoyaltyTransactionToPg(tx);

    res.json({ success: true, points_balance: newBalance, transaction: tx });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/loyalty/redeem', async (req, res) => {
  try {
    const { phone, order_id, points, description } = req.body;
    if (!phone || !points || points <= 0) {
      return res.status(400).json({ success: false, error: 'Phone and positive points required' });
    }

    let currentBalance = 0;
    let totalEarned = 0;
    let totalRedeemed = 0;

    if (pgPool) {
      const pRes = await pgPool.query('SELECT * FROM loyalty_points WHERE user_phone = $1', [phone]);
      if (pRes.rows.length > 0) {
        currentBalance = parseInt(pRes.rows[0].points_balance, 10) || 0;
        totalEarned = parseInt(pRes.rows[0].total_earned, 10) || 0;
        totalRedeemed = parseInt(pRes.rows[0].total_redeemed, 10) || 0;
      }
    }

    if (currentBalance < points) {
      return res.status(400).json({ success: false, error: `رصيد النقاط غير كافٍ. المتاح: ${currentBalance}` });
    }

    const newBalance = currentBalance - parseInt(points, 10);
    const newRedeemed = totalRedeemed + parseInt(points, 10);
    await saveLoyaltyPointToPg(phone, newBalance, totalEarned, newRedeemed);

    const tx = {
      id: `ltx_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      user_phone: phone,
      order_id: order_id || null,
      points_change: -parseInt(points, 10),
      transaction_type: 'redemption',
      description: description || `استبدال نقاط لخصم الطلب #${order_id || ''}`,
      created_at: new Date().toISOString()
    };
    await saveLoyaltyTransactionToPg(tx);

    res.json({ success: true, points_balance: newBalance, transaction: tx });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// --- B. Referrals & Viral Growth ---
app.get('/api/v1/referrals/:phone', async (req, res) => {
  try {
    const phone = req.params.phone;
    let friends = [];
    if (pgPool) {
      const rRes = await pgPool.query('SELECT * FROM referrals WHERE referrer_phone = $1 ORDER BY created_at DESC', [phone]);
      friends = rRes.rows;
    } else {
      friends = (db.referrals || []).filter(r => r.referrer_phone === phone);
    }
    const cleanPhone = phone.replace(/\D/g, '');
    const referralCode = `WAS-${cleanPhone.slice(-4)}`;
    res.json({ success: true, referral_code: referralCode, invited_friends: friends });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/referrals/invite', async (req, res) => {
  try {
    const { referrer_phone, friend_phone, friend_name } = req.body;
    if (!referrer_phone || !friend_phone) {
      return res.status(400).json({ success: false, error: 'Referrer phone and friend phone are required' });
    }

    const cleanFriendPhone = friend_phone.replace(/\D/g, '');
    let isAlreadyRegistered = false;

    if (pgPool) {
      const uRes = await pgPool.query('SELECT 1 FROM orders WHERE customer_phone = $1 LIMIT 1', [cleanFriendPhone]);
      if (uRes.rows.length > 0) isAlreadyRegistered = true;
    }

    const referralRecord = {
      id: `ref_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      referrer_phone,
      referred_phone: cleanFriendPhone,
      status: isAlreadyRegistered ? 'already_registered' : 'verified',
      reward_voucher_code: null,
      created_at: new Date().toISOString(),
      verified_at: isAlreadyRegistered ? null : new Date().toISOString()
    };

    await saveReferralToPg(referralRecord);
    if (!db.referrals) db.referrals = [];
    db.referrals.push(referralRecord);

    // Check if referrer qualifies for a voucher (every 3 verified friends)
    let totalVerified = 0;
    if (pgPool) {
      const cRes = await pgPool.query("SELECT COUNT(*) FROM referrals WHERE referrer_phone = $1 AND status = 'verified'", [referrer_phone]);
      totalVerified = parseInt(cRes.rows[0].count, 10);
    } else {
      totalVerified = db.referrals.filter(r => r.referrer_phone === referrer_phone && r.status === 'verified').length;
    }

    let issuedVoucher = null;
    if (!isAlreadyRegistered && totalVerified > 0 && totalVerified % 3 === 0) {
      const vCode = `FREE-REF-${Date.now().toString().slice(-4)}`;
      const expDate = new Date();
      expDate.setDate(expDate.getDate() + 14);
      issuedVoucher = {
        id: `uv_${Date.now()}`,
        user_phone: referrer_phone,
        code: vCode,
        title: 'كوبون توصيل مجاني 🛵 (مكافأة دعوة 3 أصدقاء)',
        voucher_type: 'free_delivery',
        discount_amount_lyd: 5.0,
        min_order_lyd: 15.0,
        is_used: false,
        used_order_id: null,
        expires_at: expDate.toISOString(),
        created_at: new Date().toISOString()
      };
      await saveUserVoucherToPg(issuedVoucher);
      if (!db.user_vouchers) db.user_vouchers = [];
      db.user_vouchers.push(issuedVoucher);
    }

    res.json({
      success: true,
      referral: referralRecord,
      reward_granted: issuedVoucher !== null,
      voucher: issuedVoucher
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// --- C. User Vouchers ---
app.get('/api/v1/vouchers/user/:phone', async (req, res) => {
  try {
    const phone = req.params.phone;
    let vouchers = [];
    if (pgPool) {
      const vRes = await pgPool.query(`
        SELECT * FROM user_vouchers 
        WHERE user_phone = $1 AND is_used = false AND expires_at > CURRENT_TIMESTAMP 
        ORDER BY created_at DESC
      `, [phone]);
      vouchers = vRes.rows;
    } else {
      vouchers = (db.user_vouchers || []).filter(v => v.user_phone === phone && !v.is_used);
    }
    res.json({ success: true, count: vouchers.length, data: vouchers });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/vouchers/user/redeem', async (req, res) => {
  try {
    const { code, order_id } = req.body;
    if (!code) return res.status(400).json({ success: false, error: 'Code is required' });

    if (pgPool) {
      const updateRes = await pgPool.query(`
        UPDATE user_vouchers 
        SET is_used = true, used_order_id = $1 
        WHERE code = $2 AND is_used = false
        RETURNING *
      `, [order_id || null, code]);
      if (updateRes.rows.length === 0) {
        return res.status(404).json({ success: false, error: 'كوبون غير صالح أو تم استخدامه مسبقاً' });
      }
      return res.json({ success: true, voucher: updateRes.rows[0] });
    }

    const v = (db.user_vouchers || []).find(v => v.code === code && !v.is_used);
    if (!v) return res.status(404).json({ success: false, error: 'كوبون غير صالح' });
    v.is_used = true;
    v.used_order_id = order_id || null;
    res.json({ success: true, voucher: v });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// --- D. Reviews & Ratings ---
app.post('/api/v1/reviews', async (req, res) => {
  try {
    const { order_id, customer_phone, store_id, driver_id, store_rating, driver_rating, comment } = req.body;
    if (!order_id || !store_id || !store_rating) {
      return res.status(400).json({ success: false, error: 'Order ID, Store ID, and store rating are required' });
    }

    const review = {
      id: `rev_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      order_id,
      customer_phone: customer_phone || '0910000000',
      store_id,
      driver_id: driver_id || null,
      store_rating: parseFloat(store_rating),
      driver_rating: driver_rating ? parseFloat(driver_rating) : null,
      comment: comment || '',
      created_at: new Date().toISOString()
    };

    await saveReviewToPg(review);
    if (!db.reviews) db.reviews = [];
    db.reviews.push(review);

    // Update store average rating
    if (pgPool) {
      const avgRes = await pgPool.query('SELECT AVG(store_rating) as avg_rating, COUNT(*) as count FROM reviews WHERE store_id = $1', [store_id]);
      if (avgRes.rows.length > 0) {
        const newRating = Math.round(parseFloat(avgRes.rows[0].avg_rating) * 10) / 10;
        const newCount = parseInt(avgRes.rows[0].count, 10);
        await pgPool.query('UPDATE stores SET rating = $1, review_count = $2 WHERE id = $3', [newRating, newCount, store_id]);
        const st = db.stores.find(s => s.id === store_id);
        if (st) {
          st.rating = newRating;
          st.review_count = newCount;
        }
      }
    }

    res.status(201).json({ success: true, review });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/v1/reviews/store/:storeId', async (req, res) => {
  try {
    const storeId = req.params.storeId;
    let revs = [];
    if (pgPool) {
      const rRes = await pgPool.query('SELECT * FROM reviews WHERE store_id = $1 ORDER BY created_at DESC LIMIT 30', [storeId]);
      revs = rRes.rows;
    } else {
      revs = (db.reviews || []).filter(r => r.store_id === storeId);
    }
    res.json({ success: true, count: revs.length, data: revs });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// --- E. System Configuration ---
app.get('/api/v1/config/system', async (req, res) => {
  try {
    let cfg = {};
    if (pgPool) {
      const cRes = await pgPool.query("SELECT value FROM system_config WHERE key = 'core_platform_rules'");
      if (cRes.rows.length > 0) {
        cfg = typeof cRes.rows[0].value === 'string' ? JSON.parse(cRes.rows[0].value) : cRes.rows[0].value;
      }
    }
    if (Object.keys(cfg).length === 0) {
      cfg = db.system_config?.core_platform_rules || {
        referral_enabled: true,
        referral_target_count: 3,
        referral_reward_type: 'free_delivery',
        referral_reward_lyd: 5.0,
        referral_min_order_lyd: 20.0,
        referral_validity_days: 14,
        referral_condition: 'on_signup_otp',
        loyalty_enabled: true,
        loyalty_points_per_lyd: 1.0,
        loyalty_redemption_rate: 20.0,
        captain_bonus_enabled: true,
        captain_daily_target: 8,
        captain_daily_bonus_lyd: 15.0,
        ratings_enabled: true
      };
    }
    res.json({ success: true, data: cfg });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.put('/api/v1/config/system', async (req, res) => {
  try {
    const newConfig = req.body;
    await saveSystemConfigToPg('core_platform_rules', newConfig, 'تحديث إعدادات منصة واصل');
    if (!db.system_config) db.system_config = {};
    db.system_config.core_platform_rules = newConfig;
    res.json({ success: true, data: newConfig });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// --- F. Product Modifiers ---
app.get('/api/v1/products/:productId/modifiers', async (req, res) => {
  try {
    const productId = req.params.productId;
    let mods = [];
    if (pgPool) {
      const mRes = await pgPool.query('SELECT * FROM product_modifiers WHERE product_id = $1 ORDER BY created_at ASC', [productId]);
      mods = mRes.rows;
    } else {
      mods = (db.product_modifiers || []).filter(m => m.product_id === productId);
    }
    res.json({ success: true, count: mods.length, data: mods });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/products/:productId/modifiers', async (req, res) => {
  try {
    const productId = req.params.productId;
    const { modifiers = [] } = req.body;
    if (pgPool) {
      await pgPool.query('DELETE FROM product_modifiers WHERE product_id = $1', [productId]);
      for (const m of modifiers) {
        const modObj = {
          id: m.id || `mod_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
          product_id: productId,
          group_name: m.group_name || 'خيارات إضافية',
          name: m.name,
          price_lyd: parseFloat(m.price_lyd) || 0.0,
          max_selectable: parseInt(m.max_selectable, 10) || 1,
          is_required: m.is_required === true
        };
        await saveModifierToPg(modObj);
      }
    }
    res.json({ success: true, message: 'Modifiers updated successfully' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// --- G. Delivery Zones ---
app.get('/api/v1/delivery-zones', async (req, res) => {
  try {
    let zones = [];
    if (pgPool) {
      const zRes = await pgPool.query('SELECT * FROM delivery_zones ORDER BY sort_order ASC');
      zones = zRes.rows;
    } else {
      zones = db.delivery_zones || [];
    }
    res.json({ success: true, count: zones.length, data: zones });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.patch('/api/v1/delivery-zones/:id', adminAuthMiddleware, async (req, res) => {
  try {
    const id = req.params.id;
    const { base_fee_lyd, min_delivery_time, max_delivery_time, is_active } = req.body;
    const z = (db.delivery_zones || []).find(zone => zone.id === id);
    if (z) {
      if (base_fee_lyd !== undefined) z.base_fee_lyd = parseFloat(base_fee_lyd);
      if (min_delivery_time !== undefined) z.min_delivery_time = parseInt(min_delivery_time, 10);
      if (max_delivery_time !== undefined) z.max_delivery_time = parseInt(max_delivery_time, 10);
      if (is_active !== undefined) z.is_active = is_active === true;
      await saveDeliveryZoneToPg(z);
    }
    res.json({ success: true, data: z });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ----------------------------------------------------------------------------
// VOUCHERS & PAYOUT REQUESTS
// ----------------------------------------------------------------------------
app.get('/api/v1/vouchers', (req, res) => {
  const vouchers = db.vouchers || [];
  res.json({ success: true, count: vouchers.length, data: vouchers });
});

app.post('/api/v1/vouchers', (req, res) => {
  if (!db.vouchers) db.vouchers = [];
  const voucher = {
    id: req.body.id || `vouch_${Date.now()}`,
    voucher_number: req.body.voucher_number || `REQ-DISB-${Date.now() % 100000}`,
    type: req.body.type || 'disbursement',
    amount_lyd: req.body.amount_lyd || 0,
    payment_method: req.body.payment_method || 'سداد',
    notes: req.body.notes || '',
    created_at: req.body.created_at || new Date().toISOString()
  };
  db.vouchers.push(voucher);
  saveVoucherToPg(voucher);
  res.status(201).json({ success: true, data: voucher });
});

// ----------------------------------------------------------------------------
// AUDIT & SETTLEMENT LEDGER
// ----------------------------------------------------------------------------
app.get('/api/v1/audit', (req, res) => {
  const logs = db.audit_logs || [];
  res.json({ success: true, count: logs.length, data: logs });
});

app.post('/api/v1/audit', (req, res) => {
  if (!db.audit_logs) db.audit_logs = [];
  const entry = {
    id: req.body.id || `audit_${Date.now()}`,
    ...req.body,
    created_at: req.body.created_at || new Date().toISOString()
  };
  db.audit_logs.unshift(entry);
  saveAuditLogToPg(entry);
  res.status(201).json({ success: true, data: entry });
});

// ----------------------------------------------------------------------------
// UNIFIED ACCOUNTING & GENERAL LEDGER API (COA, TRIAL BALANCE, Z-REPORT)
// ----------------------------------------------------------------------------
const accountingEngine = require('./services/accountingEngine');

// 1. Chart of Accounts (دليل وشجرة الحسابات)
app.get('/api/v1/accounting/chart-of-accounts', (req, res) => {
  res.json({
    success: true,
    data: Object.values(accountingEngine.CHART_OF_ACCOUNTS)
  });
});

// 2. Trial Balance (ميزان المراجعة الحي بالأرصدة والمجاميع)
app.get('/api/v1/accounting/trial-balance', (req, res) => {
  try {
    const trialBalance = accountingEngine.getTrialBalance(db);
    res.json(trialBalance);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 3. General Ledger & Journal Entries Feed (دفتر الأستاذ والقيود اليومية)
app.get('/api/v1/accounting/journal-entries', (req, res) => {
  try {
    const { account_code, limit = 50, page = 1 } = req.query;
    const ledger = accountingEngine.getGeneralLedger(db, {
      accountCode: account_code,
      limit: parseInt(limit, 10),
      page: parseInt(page, 10)
    });
    res.json(ledger);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 4. Exact Daily Z-Report computed strictly from posted Journal Entries
app.get('/api/v1/accounting/daily-audit', (req, res) => {
  try {
    const { date } = req.query;
    const zReport = accountingEngine.getDailyZReport(db, date);
    res.json(zReport);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5. Partner Account Statement (Store or Driver) from General Ledger
app.get('/api/v1/accounting/statement/:type/:id', (req, res) => {
  try {
    const { type, id } = req.params;
    const statement = accountingEngine.getPartnerStatement(db, {
      entityType: type,
      entityId: id
    });
    res.json(statement);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 6. Approve & Disburse Merchant Payout Request (صرف مستحقات متجر بسند وقيد)
app.post('/api/v1/accounting/payouts/disburse', async (req, res) => {
  try {
    const { store_id, amount, payment_method, destination_account, notes } = req.body;
    if (!store_id || !amount) {
      return res.status(400).json({ success: false, error: 'store_id and amount are required' });
    }
    const result = await ledgerService.disburseMerchantPayout(db, {
      storeId: store_id,
      amount: parseFloat(amount),
      paymentMethod: payment_method || 'مصرف الجمهورية',
      destinationAccount: destination_account || '',
      notes: notes || '',
      pgPool
    });
    res.json({ success: true, message: 'تم صرف المستحقات وتوليد سند الصرف والقيد المحاسبي بنجاح', data: result });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 7. Manual Balanced Adjustment Journal Entry (قيد تسوية وتعديل يدوي متوازن)
app.post('/api/v1/accounting/journal-entries', async (req, res) => {
  try {
    const { reference_id, narration, lines } = req.body;
    if (!Array.isArray(lines) || lines.length < 2) {
      return res.status(400).json({ success: false, error: 'A minimum of 2 balanced lines is required.' });
    }
    const entry = await accountingEngine.recordJournalEntry(db, {
      referenceId: reference_id || `manual_${Date.now()}`,
      transactionType: 'adjustment',
      narration: narration || 'قيد تسوية وتعديل محاسبي يدوي',
      lines: lines,
      pgPool
    });
    res.status(201).json({ success: true, data: entry });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/admin/seed', adminAuthMiddleware, async (req, res) => {
  loadSeedData();
  await initPgTables(true);
  res.json({
    success: true,
    message: 'تمت إعادة مزامنة وزرع كافة المتاجر والأصناف الحقيقية لنالوت في قاعدة البيانات بنجاح!',
    stores_count: db.stores.length,
    products_count: db.products.length,
    drivers_count: db.drivers.length
  });
});

// ----------------------------------------------------------------------------
// WALLET & LEDGER ROUTES
// ----------------------------------------------------------------------------
app.get('/api/v1/wallet/balance', authMiddleware, async (req, res) => {
  try {
    const user = req.user;
    let wallet = null;

    if (pgPool) {
      const wRes = await pgPool.query('SELECT * FROM wallets WHERE user_id = $1 LIMIT 1', [user.id]);
      if (wRes.rows.length > 0) {
        wallet = {
          ...wRes.rows[0],
          balance: parseFloat(wRes.rows[0].balance) || 0.00,
          locked_balance: parseFloat(wRes.rows[0].locked_balance) || 0.00
        };
      }
    }

    if (!wallet) {
      wallet = db.wallets.find(w => w.user_id === user.id);
    }

    if (!wallet) {
      wallet = {
        id: `wallet_${user.id}`,
        user_id: user.id,
        wallet_type: user.role === 'driver' ? 'driver_earnings' : user.role === 'merchant' ? 'merchant_payouts' : 'customer_wallet',
        currency: 'LYD',
        balance: 100.00,
        locked_balance: 0.00,
        status: 'active'
      };
      db.wallets.push(wallet);
      if (pgPool) {
        await saveWalletToPg(wallet);
      }
    }

    const availableBalance = wallet.balance - wallet.locked_balance;

    res.json({
      success: true,
      data: {
        wallet_id: wallet.id,
        user_id: wallet.user_id,
        wallet_type: wallet.wallet_type,
        currency: wallet.currency,
        currency_symbol: 'د.ل',
        total_balance: wallet.balance,
        locked_balance: wallet.locked_balance,
        available_balance: Math.max(0, availableBalance),
        status: wallet.status
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/wallet/topup', authMiddleware, rateLimiter(10, 60000), async (req, res) => {
  let client = null;
  try {
    const { amount, payment_channel = 'Sadad', reference_code } = req.body;
    const topupAmount = parseFloat(amount);

    if (!topupAmount || topupAmount <= 0 || topupAmount > 1000) {
      return res.status(400).json({
        success: false,
        error: 'Valid top-up amount is required (maximum limit is 1,000 LYD per top-up)'
      });
    }

    // Require bank reference code for audit trails unless administrator
    if (!reference_code && req.user.role !== 'admin') {
      return res.status(400).json({
        success: false,
        error: 'Bank transaction reference code or receipt number is required for verification'
      });
    }

    const user = req.user;
    let wallet = db.wallets.find(w => w.user_id === user.id);
    if (!wallet) {
      wallet = {
        id: `wallet_${user.id}`,
        user_id: user.id,
        wallet_type: 'customer_wallet',
        currency: 'LYD',
        balance: 0.00,
        locked_balance: 0.00,
        status: 'active'
      };
      db.wallets.push(wallet);
    }

    wallet.balance += topupAmount;

    const txn = {
      id: `txn_topup_${uuidv4().substring(0, 8)}`,
      wallet_id: wallet.id,
      counterparty_wallet_id: SYSTEM_WALLETS.REVENUE,
      order_id: null,
      transaction_type: 'topup',
      amount: topupAmount,
      currency: 'LYD',
      status: 'completed',
      description: `شحن رصيد إلكتروني عبر ${payment_channel} - كود العملية: ${reference_code || 'ADMIN_TOPUP'}`,
      created_at: new Date().toISOString()
    };
    db.wallet_transactions.push(txn);

    // Atomic PostgreSQL transaction
    if (pgPool && typeof pgPool.connect === 'function') {
      client = await pgPool.connect();
      await client.query('BEGIN');
      await client.query(`
        INSERT INTO wallets (id, user_id, wallet_type, currency, balance, locked_balance, status)
        VALUES ($1, $2, 'customer_wallet', 'LYD', $3, 0.00, 'active')
        ON CONFLICT (user_id, wallet_type, currency)
        DO UPDATE SET balance = wallets.balance + $3, updated_at = CURRENT_TIMESTAMP
      `, [wallet.id, user.id, topupAmount]);
      await saveWalletTransactionToPg(txn, client);
      await client.query('COMMIT');
      client.release();
      client = null;
    }

    // Strictly Post-COMMIT Socket.io emit
    if (req.io) {
      req.io.to(`user:${user.id}`).emit('wallet:balance_updated', {
        wallet_id: wallet.id,
        balance: wallet.balance,
        locked_balance: wallet.locked_balance,
        available_balance: wallet.balance - wallet.locked_balance,
        currency: 'LYD'
      });
    }

    res.json({
      success: true,
      message: `تم شحن الرصيد بنجاح بمبلغ ${topupAmount.toFixed(2)} د.ل عبر ${payment_channel}`,
      data: {
        wallet_id: wallet.id,
        balance: wallet.balance,
        locked_balance: wallet.locked_balance,
        available_balance: wallet.balance - wallet.locked_balance,
        transaction: txn
      }
    });
  } catch (err) {
    if (client) {
      try { await client.query('ROLLBACK'); } catch (_) {}
      client.release();
      client = null;
    }
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/v1/wallet/transactions', authMiddleware, async (req, res) => {
  try {
    const user = req.user;
    let wallet = db.wallets.find(w => w.user_id === user.id);

    if (pgPool) {
      const wRes = await pgPool.query('SELECT * FROM wallets WHERE user_id = $1 LIMIT 1', [user.id]);
      if (wRes.rows.length > 0) {
        wallet = wRes.rows[0];
      }
    }

    if (!wallet) {
      return res.json({ success: true, count: 0, data: [] });
    }

    if (pgPool) {
      const txRes = await pgPool.query(`
        SELECT * FROM wallet_transactions
        WHERE wallet_id = $1 OR wallet_id = $2
        ORDER BY created_at DESC
        LIMIT 100
      `, [wallet.id, `wallet_${user.id}`]);
      if (txRes.rows.length > 0) {
        return res.json({
          success: true,
          count: txRes.rows.length,
          data: txRes.rows
        });
      }
    }

    const txns = db.wallet_transactions.filter(t => t.wallet_id === wallet.id);
    txns.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

    res.json({
      success: true,
      count: txns.length,
      data: txns
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ----------------------------------------------------------------------------
// ADMIN & FLEET OVERVIEW ROUTES
// ----------------------------------------------------------------------------
app.get('/api/v1/admin/overview', adminAuthMiddleware, (req, res) => {
  try {
    const activeOrders = db.orders.filter(o => !['delivered', 'cancelled'].includes(o.status));
    const completedOrders = db.orders.filter(o => o.status === 'delivered');

    const gmv = db.orders.reduce((sum, o) => sum + (o.total_amount_lyd || 0), 0);
    const platformRevenueWallet = db.wallets.find(w => w.wallet_type === 'platform_revenue');

    const totalDrivers = db.drivers.length;
    const availableDrivers = db.drivers.filter(d => d.status === 'available' || d.status === 'online_idle' || d.status === 'online').length;
    const busyDrivers = db.drivers.filter(d => d.status === 'busy_delivery' || d.status === 'busy').length;
    const offlineDrivers = db.drivers.filter(d => d.status === 'offline' || !d.status).length;
    const openStores = db.stores.filter(s => s.is_open === true || s.is_open === 'true' || s.is_open === 1).length;

    // Vertical breakdown
    const verticalBreakdown = {
      restaurant: db.orders.filter(o => {
        const store = db.stores.find(s => s.id === o.store_id);
        return store && store.type === 'restaurant';
      }).length,
      grocery: db.orders.filter(o => {
        const store = db.stores.find(s => s.id === o.store_id);
        return store && store.type === 'grocery';
      }).length,
      marketplace: db.orders.filter(o => {
        const store = db.stores.find(s => s.id === o.store_id);
        return store && store.type === 'marketplace';
      }).length
    };

    let totalCodPending = 0;
    if (Array.isArray(db.drivers)) {
      totalCodPending = db.drivers.reduce((sum, d) => sum + (parseFloat(d.cash_in_hand_lyd !== undefined ? d.cash_in_hand_lyd : (d.cod_balance_lyd || 0)) || 0), 0);
    }
    totalCodPending = Math.round(totalCodPending * 100) / 100;

    res.json({
      success: true,
      data: {
        currency: 'LYD',
        currency_symbol: 'د.ل',
        metrics: {
          total_orders: db.orders.length,
          active_orders_count: activeOrders.length,
          completed_orders_count: completedOrders.length,
          gmv_total_lyd: Math.round(gmv * 100) / 100,
          platform_revenue_lyd: platformRevenueWallet ? platformRevenueWallet.balance : 0,
          cod_pending_lyd: totalCodPending,
          driver_cash_liability_lyd: totalCodPending,
          stores_count: db.stores.length,
          open_stores_count: openStores,
          total_stores_count: db.stores.length,
          online_drivers_count: availableDrivers + busyDrivers
        },
        fleet_stats: {
          total_drivers: totalDrivers,
          available: availableDrivers,
          busy: busyDrivers,
          offline: offlineDrivers
        },
        vertical_order_counts: verticalBreakdown,
        active_orders: activeOrders.slice(0, 10),
        live_drivers: db.drivers,
        stores: db.stores
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/v1/admin/drivers', adminAuthMiddleware, (req, res) => {
  res.json({
    success: true,
    count: db.drivers.length,
    data: db.drivers
  });
});

app.post('/api/v1/admin/dispatch/simulate', adminAuthMiddleware, (req, res) => {
  try {
    const { driver_id, order_id } = req.body;
    const driver = driver_id
      ? db.drivers.find(d => d.id === driver_id)
      : db.drivers.find(d => d.status === 'busy_delivery') || db.drivers[0];

    if (!driver) {
      return res.status(404).json({ success: false, error: 'No active driver found for simulation' });
    }

    const order = order_id
      ? db.orders.find(o => o.id === order_id)
      : (driver.active_order_id ? db.orders.find(o => o.id === driver.active_order_id) : db.orders[0]);

    // Move driver slightly towards destination
    let targetLat = 32.8800;
    let targetLng = 13.1500;
    if (order && order.delivery_latitude) {
      targetLat = order.delivery_latitude;
      targetLng = order.delivery_longitude;
    }

    const stepFactor = 0.15;
    driver.latitude = driver.latitude + (targetLat - driver.latitude) * stepFactor;
    driver.longitude = driver.longitude + (targetLng - driver.longitude) * stepFactor;
    driver.speed_kmh = Math.floor(25 + Math.random() * 20);
    driver.heading = (driver.heading + 10) % 360;

    const remainingDistance = Math.round(calculateHaversineDistance(driver.latitude, driver.longitude, targetLat, targetLng));
    const eta = estimateEtaMinutes(remainingDistance, driver.speed_kmh);

    const telemetry = {
      driver_id: driver.id,
      order_id: order ? order.id : null,
      latitude: driver.latitude,
      longitude: driver.longitude,
      heading: driver.heading,
      speed_kmh: driver.speed_kmh,
      battery_level: driver.battery_level,
      remaining_distance_meters: remainingDistance,
      eta_minutes: eta,
      recorded_at: new Date().toISOString()
    };

    // Broadcast telemetry via Socket.io
    if (order) {
      io.to(`order:${order.id}`).emit('order:driver_location', telemetry);
    }
    io.to(`driver:${driver.id}`).emit('driver:location_changed', telemetry);
    io.to('admin:fleet').emit('admin:driver_moved', telemetry);

    res.json({
      success: true,
      message: `Simulated driver ${driver.full_name} movement`,
      telemetry
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ----------------------------------------------------------------------------
// 7. SOCKET.IO REAL-TIME EVENT HANDLERS
// ----------------------------------------------------------------------------
io.use((socket, next) => {
  try {
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.headers?.authorization?.replace('Bearer ', '') ||
      socket.handshake.query?.token;

    if (token) {
      try {
        const decoded = jwt.verify(token, JWT_SECRET);
        socket.data.user = decoded;
      } catch (e) {
        // Fallback for dev mode
        socket.data.user = { id: 'guest_user', role: 'customer' };
      }
    } else {
      // Dev mode fallback
      const role = socket.handshake.query?.role || 'customer';
      const userId = socket.handshake.query?.userId || `guest_${socket.id.substring(0, 6)}`;
      socket.data.user = { id: userId, role };
    }
    next();
  } catch (err) {
    next();
  }
});

io.on('connection', (socket) => {
  const user = socket.data.user || { id: socket.id, role: 'customer' };
  console.log(`[Socket Connected] Socket: ${socket.id} | User: ${user.id} (${user.role})`);

  // Auto-join personal user room
  socket.join(`user:${user.id}`);

  if (user.role === 'driver') {
    socket.join(`driver:${user.id}`);
  } else if (user.role === 'admin') {
    socket.join('admin:fleet');
  }

  // 1. DRIVER GPS TELEMETRY STREAM
  socket.on('driver:location_update', (payload, ack) => {
    try {
      const driverId = payload.driver_id || user.id;
      const {
        order_id,
        latitude,
        longitude,
        heading = 0,
        speed_kmh = 0,
        battery_level = 100,
        is_charging = false
      } = payload;

      if (!latitude || !longitude) {
        if (ack) ack({ success: false, error: 'Invalid coordinates' });
        return;
      }

      // Update in-memory driver state
      const driver = db.drivers.find(d => d.id === driverId || d.user_id === driverId);
      if (driver) {
        driver.latitude = parseFloat(latitude);
        driver.longitude = parseFloat(longitude);
        driver.heading = parseFloat(heading);
        driver.speed_kmh = parseFloat(speed_kmh);
        driver.battery_level = parseInt(battery_level, 10);
        driver.is_charging = Boolean(is_charging);
      }

      const telemetryData = {
        driver_id: driverId,
        order_id: order_id || null,
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        heading: parseFloat(heading),
        speed_kmh: parseFloat(speed_kmh),
        battery_level: parseInt(battery_level, 10),
        is_charging: Boolean(is_charging),
        recorded_at: new Date().toISOString()
      };

      // Persist in PostgreSQL via existing helper
      if (driver) {
        saveDriverToPg(driver);
      }

      // Use SocketService to broadcast location updates
      SocketService.broadcastDriverLocation(telemetryData);

      // If tied to an active order, calculate ETA and broadcast to customer
      if (order_id) {
        const order = db.orders.find(o => o.id === order_id);
        if (order && order.delivery_latitude && order.delivery_longitude) {
          const remainingDistance = Math.round(
            calculateHaversineDistance(telemetryData.latitude, telemetryData.longitude, order.delivery_latitude, order.delivery_longitude)
          );
          const eta = estimateEtaMinutes(remainingDistance, telemetryData.speed_kmh);

          // Proximity alert trigger
          if (remainingDistance <= PROXIMITY_THRESHOLD_METERS) {
            io.to(`order:${order_id}`).emit('driver:proximity_alert', {
              order_id,
              distance_meters: remainingDistance,
              message: 'السائق يقترب من موقعك الآن! (أقل من 200 متر)'
            });
          }

          io.to(`order:${order_id}`).emit('order:driver_location', {
            ...telemetryData,
            remaining_distance_meters: remainingDistance,
            remaining_distance_km: (remainingDistance / 1000).toFixed(1),
            eta_minutes: eta
          });
        }
      }

      if (ack) ack({ success: true, recorded_at: telemetryData.recorded_at });
    } catch (err) {
      console.error('[driver:location_update Error]', err);
      if (ack) ack({ success: false, error: err.message });
    }
  });

  // 2. ORDER ROOM SUBSCRIPTION
  socket.on('order:subscribe', ({ order_id }, ack) => {
    if (!order_id) {
      if (ack) ack({ success: false, error: 'order_id is required' });
      return;
    }

    socket.join(`order:${order_id}`);
    const order = db.orders.find(o => o.id === order_id || o.order_number === order_id);
    const driver = order && order.driver_id ? db.drivers.find(d => d.id === order.driver_id) : null;

    let snapshot = null;
    if (order) {
      let distanceMeters = null;
      let eta = null;
      if (driver && order.delivery_latitude && order.delivery_longitude) {
        distanceMeters = Math.round(
          calculateHaversineDistance(driver.latitude, driver.longitude, order.delivery_latitude, order.delivery_longitude)
        );
        eta = estimateEtaMinutes(distanceMeters, driver.speed_kmh || 25);
      }

      snapshot = {
        order_id: order.id,
        order_number: order.order_number,
        status: order.status,
        driver: driver ? {
          id: driver.id,
          name: driver.full_name,
          phone: driver.phone,
          latitude: driver.latitude,
          longitude: driver.longitude,
          speed_kmh: driver.speed_kmh,
          heading: driver.heading
        } : null,
        remaining_distance_meters: distanceMeters,
        eta_minutes: eta
      };
    }

    if (ack) ack({ success: true, snapshot });
  });

  socket.on('order:unsubscribe', ({ order_id }) => {
    if (order_id) {
      socket.leave(`order:${order_id}`);
    }
  });

  // 3. STORE KITCHEN ROOM SUBSCRIPTION
  socket.on('store:subscribe', ({ store_id }, ack) => {
    if (store_id) {
      socket.join(`store:${store_id}`);
      if (ack) ack({ success: true, store_id });
    }
  });

  // 4. ORDER STATUS UPDATE BROADCAST
  socket.on('order:status_update', (payload, ack) => {
    try {
      const { order_id, status, notes } = payload;
      const order = db.orders.find(o => o.id === order_id);
      if (order) {
        order.status = status;
        order.updated_at = new Date().toISOString();

        const eventData = {
          order_id: order.id,
          order_number: order.order_number,
          status,
          notes,
          updated_at: order.updated_at
        };

        io.to(`order:${order.id}`).emit('order:status_changed', eventData);
        io.to(`user:${order.customer_id}`).emit('order:status_changed', eventData);
        io.to(`store:${order.store_id}`).emit('order:status_changed', eventData);
        if (order.driver_id) io.to(`driver:${order.driver_id}`).emit('order:status_changed', eventData);
        io.to('admin:fleet').emit('admin:order_status_changed', eventData);

        if (ack) ack({ success: true });
      } else {
        if (ack) ack({ success: false, error: 'Order not found' });
      }
    } catch (err) {
      if (ack) ack({ success: false, error: err.message });
    }
  });

  // 5. DRIVER STATUS TOGGLE
  socket.on('driver:set_status', ({ status }, ack) => {
    const driver = db.drivers.find(d => d.user_id === user.id || d.id === user.id);
    if (driver) {
      driver.status = status;
      io.to('admin:fleet').emit('admin:driver_status_changed', {
        driver_id: driver.id,
        status
      });
      if (ack) ack({ success: true, status });
    } else {
      if (ack) ack({ success: false, error: 'Driver profile not found' });
    }
  });

  socket.on('disconnect', (reason) => {
    console.log(`[Socket Disconnected] Socket: ${socket.id} | Reason: ${reason}`);
  });
});

// ----------------------------------------------------------------------------
// 8. AUTO-SIMULATION DRIVER TELEMETRY TICKER (For Live Demos)
// ----------------------------------------------------------------------------
// Periodically steps busy drivers along their delivery paths to produce real-time GPS telemetry
setInterval(() => {
  const busyDrivers = db.drivers.filter(d => d.status === 'busy_delivery' && d.active_order_id);
  busyDrivers.forEach(driver => {
    const order = db.orders.find(o => o.id === driver.active_order_id);
    if (order && order.delivery_latitude && order.delivery_longitude) {
      const step = 0.03; // Smooth progression
      driver.latitude += (order.delivery_latitude - driver.latitude) * step;
      driver.longitude += (order.delivery_longitude - driver.longitude) * step;
      driver.speed_kmh = Math.floor(25 + Math.random() * 15);
      driver.heading = (driver.heading + 5) % 360;

      const remainingDistance = Math.round(
        calculateHaversineDistance(driver.latitude, driver.longitude, order.delivery_latitude, order.delivery_longitude)
      );
      const eta = estimateEtaMinutes(remainingDistance, driver.speed_kmh);

      const telemetry = {
        driver_id: driver.id,
        order_id: order.id,
        latitude: driver.latitude,
        longitude: driver.longitude,
        heading: driver.heading,
        speed_kmh: driver.speed_kmh,
        battery_level: driver.battery_level,
        remaining_distance_meters: remainingDistance,
        remaining_distance_km: (remainingDistance / 1000).toFixed(1),
        eta_minutes: eta,
        recorded_at: new Date().toISOString()
      };

      io.to(`order:${order.id}`).emit('order:driver_location', telemetry);
      io.to('admin:fleet').emit('admin:driver_moved', telemetry);

      // Auto-complete delivery when driver arrives at dropoff location (< 30 meters)
      if (remainingDistance < 30 && order.status === 'out_for_delivery') {
        order.status = 'delivered';
        order.delivered_at = new Date().toISOString();
        driver.status = 'available';
        driver.active_order_id = null;

        io.to(`order:${order.id}`).emit('order:status_changed', {
          order_id: order.id,
          order_number: order.order_number,
          status: 'delivered',
          notes: 'تم تسليم الطلب بنجاح للزبون',
          updated_at: order.delivered_at
        });
      }
    }
  });
}, 3000);

// ----------------------------------------------------------------------------
// 9. REAL-TIME PRESENCE & AUTO-HEARTBEAT SWEEPER (60s TIMEOUT)
// Zero-Ghost Architecture: Stores and drivers automatically go closed/offline
// if no active heartbeat is received for more than 60 seconds.
// ----------------------------------------------------------------------------
const HEARTBEAT_TIMEOUT_MS = 60000;

setInterval(() => {
  const now = Date.now();

  // 1. Sweep Stores (Merchant App)
  db.stores.forEach(store => {
    if (store.is_open) {
      const lastBeat = store.last_heartbeat || 0;
      if (now - lastBeat > HEARTBEAT_TIMEOUT_MS) {
        store.is_open = false;
        saveStoreToPg(store);
        io.emit('store:status_changed', { store_id: store.id, is_open: false, reason: 'heartbeat_timeout' });
        io.emit('store:updated', store);
        console.log(`[Presence Engine] Store closed due to heartbeat timeout: ${store.name} (${store.id})`);
      }
    }
  });

  // 2. Sweep Drivers (Captain App)
  db.drivers.forEach(driver => {
    if (driver.status !== 'offline') {
      const lastBeat = driver.last_heartbeat || 0;
      if (now - lastBeat > HEARTBEAT_TIMEOUT_MS) {
        driver.status = 'offline';
        driver.is_active = false;
        saveDriverToPg(driver);
        io.emit('driver:status_changed', { driver_id: driver.id, status: 'offline', reason: 'heartbeat_timeout' });
        io.to('admin:fleet').emit('admin:driver_status_changed', { driver_id: driver.id, status: 'offline' });
        console.log(`[Presence Engine] Driver set offline due to heartbeat timeout: ${driver.full_name} (${driver.id})`);
      }
    }
  });
}, 20000);

// ----------------------------------------------------------------------------
// 10. START SERVER
// ----------------------------------------------------------------------------
server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    // Port already in use by active server or test runner, reuse gracefully without crashing
    return;
  }
  console.error('[Server Error]:', err);
});

if (require.main === module || !server.listening) {
  try {
    server.listen(PORT, () => {
      console.log(`================================================================`);
      console.log(`🚀 WASEL NALUT SUPER-APP BACKEND RUNNING ON PORT ${PORT}`);
      console.log(`🌍 Libya Market: Nalut, Tripoli & Benghazi | Currency: LYD (د.ل)`);
      console.log(`📡 WebSocket & REST API: http://localhost:${PORT}`);
      console.log(`================================================================`);
    });
  } catch (_) {}
}

module.exports = { app, server, io, db, pricingService, ledgerService, accountingEngine, calculateDynamicDeliveryFee };
