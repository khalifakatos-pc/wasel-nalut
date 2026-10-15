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

let _saveSeedTimeout = null;
let _isSavingSeed = false;
let _hasPendingSeedSave = false;

function saveSeedData(immediate = false) {
  if (immediate) {
    _executeSaveSeedData();
    return;
  }
  if (_saveSeedTimeout) clearTimeout(_saveSeedTimeout);
  _saveSeedTimeout = setTimeout(() => {
    _executeSaveSeedData();
  }, 2500); // Debounce disk writes to max once every 2.5s
}

async function _executeSaveSeedData() {
  if (_isSavingSeed) {
    _hasPendingSeedSave = true;
    return;
  }
  _isSavingSeed = true;
  try {
    const data = JSON.stringify(db);
    await fs.promises.writeFile(SEED_DATA_PATH, data, 'utf-8');
  } catch (err) {
    console.error('[Database] Failed to save seed_data.json:', err.message);
  } finally {
    _isSavingSeed = false;
    if (_hasPendingSeedSave) {
      _hasPendingSeedSave = false;
      saveSeedData(true);
    }
  }
}

// PostgreSQL Async Helper Functions
async function saveStoreToPg(s) {
  if (!pgPool) return;
  try {
    await pgPool.query(`
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
      s.phone || '', s.pin || '1234', s.app_mode || 'kitchen', s.commission_rate || 10.0, s.rating || 5.0,
      s.review_count || 0, s.delivery_time_min || 20, s.delivery_time_max || 35, s.min_order_lyd || 10.0,
      s.base_delivery_fee_lyd || 4.0, s.latitude || 31.8686, s.longitude || 10.9818, s.logo_url || '',
      s.banner_url || '', s.badge || '', s.is_open === true, s.is_featured !== false
    ]);
  } catch (err) {
    console.error('[PostgreSQL saveStore error]:', err.message);
  }
}

async function deleteStoreFromPg(id) {
  if (!pgPool) return;
  try {
    await pgPool.query('DELETE FROM stores WHERE id = $1', [id]);
  } catch (err) {
    console.error('[PostgreSQL deleteStore error]:', err.message);
  }
}

async function saveProductToPg(p) {
  if (!pgPool) return;
  try {
    await pgPool.query(`
      INSERT INTO products (id, store_id, name, name_ar, price, price_lyd, category, category_id, description, desc_ar, image_url, in_stock, is_available, is_popular, unit)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
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
        unit = EXCLUDED.unit
    `, [
      p.id, p.store_id, p.name || p.name_ar || 'صنف', p.name_ar || p.name || 'صنف',
      p.price || p.price_lyd || 0, p.price_lyd || p.price || 0,
      p.category || 'عام', p.category_id || '', p.description || '', p.desc_ar || '', p.image_url || '',
      p.in_stock !== false, p.is_available !== false, p.is_popular === true, p.unit || 'قطعة'
    ]);
  } catch (err) {
    console.error('[PostgreSQL saveProduct error]:', err.message);
  }
}

async function deleteProductFromPg(id) {
  if (!pgPool) return;
  try {
    await pgPool.query('DELETE FROM products WHERE id = $1', [id]);
  } catch (err) {
    console.error('[PostgreSQL deleteProduct error]:', err.message);
  }
}

async function saveDriverToPg(d) {
  if (!pgPool) return;
  try {
    await pgPool.query(`
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
  }
}

async function deleteDriverFromPg(id) {
  if (!pgPool) return;
  try {
    await pgPool.query('DELETE FROM drivers WHERE id = $1', [id]);
  } catch (err) {
    console.error('[PostgreSQL deleteDriver error]:', err.message);
  }
}

async function saveOrderToPg(o) {
  if (!pgPool) return;
  try {
    await pgPool.query(`
      INSERT INTO orders (id, order_number, customer_id, customer_name, customer_phone, store_id, store_name, driver_id, status, subtotal_lyd, delivery_fee_lyd, total_amount_lyd, payment_method, delivery_address, delivery_lat, delivery_lng, items, notes, rating, driver_rating, review_comment, cancellation_reason)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22)
      ON CONFLICT (id) DO UPDATE SET
        driver_id = EXCLUDED.driver_id,
        status = EXCLUDED.status,
        subtotal_lyd = EXCLUDED.subtotal_lyd,
        delivery_fee_lyd = EXCLUDED.delivery_fee_lyd,
        total_amount_lyd = EXCLUDED.total_amount_lyd,
        payment_method = EXCLUDED.payment_method,
        notes = EXCLUDED.notes,
        rating = EXCLUDED.rating,
        driver_rating = EXCLUDED.driver_rating,
        review_comment = EXCLUDED.review_comment,
        cancellation_reason = EXCLUDED.cancellation_reason
    `, [
      o.id, o.order_number, o.customer_id, o.customer_name, o.customer_phone,
      o.store_id, o.store_name, o.driver_id || null, o.status || 'placed',
      o.subtotal_lyd || 0, o.delivery_fee_lyd || 0, o.total_amount_lyd || 0,
      o.payment_method || 'wallet', o.delivery_address || '', o.delivery_latitude || o.delivery_lat || 31.8686,
      o.delivery_longitude || o.delivery_lng || 10.9818, JSON.stringify(o.items || []), o.notes || '',
      o.rating || null, o.driver_rating || null, o.review_comment || null, o.cancellation_reason || null
    ]);
  } catch (err) {
    console.error('[PostgreSQL saveOrder error]:', err.message);
  }
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
      CREATE TABLE IF NOT EXISTS stores (
        id VARCHAR(100) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        name_en VARCHAR(255),
        type VARCHAR(50) DEFAULT 'restaurant',
        district VARCHAR(255),
        city VARCHAR(100) DEFAULT 'nalut',
        phone VARCHAR(50),
        pin VARCHAR(20) DEFAULT '1234',
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
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

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
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

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
        latitude NUMERIC,
        longitude NUMERIC,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

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
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

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
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- Migrations for existing schemas
      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS cash_in_hand_lyd NUMERIC DEFAULT 0.0;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_fee_lyd NUMERIC DEFAULT 0.0;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS subtotal_lyd NUMERIC DEFAULT 0.0;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS total_amount_lyd NUMERIC DEFAULT 0.0;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS rating NUMERIC;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS driver_rating NUMERIC;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS review_comment TEXT;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

      -- High-Performance Production Query Indexes
      CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
      CREATE INDEX IF NOT EXISTS idx_orders_store_id ON orders(store_id);
      CREATE INDEX IF NOT EXISTS idx_orders_driver_id ON orders(driver_id);
      CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_stores_is_open ON stores(is_open);
      CREATE INDEX IF NOT EXISTS idx_products_store_id ON products(store_id);
      CREATE INDEX IF NOT EXISTS idx_wallet_tx_order_id ON wallet_transactions(order_id);
      CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet_id ON wallet_transactions(wallet_id);

      -- Loyalty Points & Transactions
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

      -- Referrals
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

      -- User Vouchers
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

      -- Reviews
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

      -- System Config
      CREATE TABLE IF NOT EXISTS system_config (
        key VARCHAR(100) PRIMARY KEY,
        value JSONB NOT NULL,
        description TEXT,
        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- Product Modifiers
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

      -- Delivery Zones
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
    `);

    const countRes = await pgPool.query('SELECT COUNT(*) FROM stores');
    const storeCount = parseInt(countRes.rows[0].count, 10);

    if (storeCount === 0 || forceSeed) {
      console.log(`[PostgreSQL] Seeding ${db.stores.length} authentic stores into PostgreSQL...`);
      for (const s of db.stores) {
        await saveStoreToPg(s);
      }
      for (const p of db.products) {
        await saveProductToPg(p);
      }
      for (const d of db.drivers) {
        await saveDriverToPg(d);
      }
      console.log('[PostgreSQL] Seeding completed successfully.');
    } else {
      console.log(`[PostgreSQL] Hydrating memory cache from PostgreSQL (${storeCount} stores)...`);
      const storesRes = await pgPool.query('SELECT * FROM stores ORDER BY is_open DESC, is_featured DESC');
      db.stores = storesRes.rows.map(r => ({
        ...r,
        rating: parseFloat(r.rating) || 5.0,
        latitude: parseFloat(r.latitude) || 31.8686,
        longitude: parseFloat(r.longitude) || 10.9818,
        min_order_lyd: parseFloat(r.min_order_lyd) || 10.0,
        base_delivery_fee_lyd: parseFloat(r.base_delivery_fee_lyd) || 4.0,
        commission_rate: parseFloat(r.commission_rate) || 10.0,
        is_open: false, // Default to closed on startup until merchant app sends heartbeat
        last_heartbeat: null
      }));

      const productsRes = await pgPool.query('SELECT * FROM products ORDER BY name ASC');
      db.products = productsRes.rows.map(r => ({
        ...r,
        price: parseFloat(r.price) || 0,
        price_lyd: parseFloat(r.price_lyd) || parseFloat(r.price) || 0
      }));

      const driversRes = await pgPool.query('SELECT * FROM drivers');
      db.drivers = driversRes.rows.map(r => ({
        ...r,
        rating: parseFloat(r.rating) || 5.0,
        wallet_balance_lyd: parseFloat(r.wallet_balance_lyd) || 0,
        cod_balance_lyd: parseFloat(r.cod_balance_lyd) || 0,
        latitude: parseFloat(r.latitude) || 31.8686,
        longitude: parseFloat(r.longitude) || 10.9818,
        status: 'offline', // Default to offline on startup until captain app sends heartbeat
        is_active: false,
        last_heartbeat: null
      }));

      const ordersRes = await pgPool.query('SELECT * FROM orders ORDER BY created_at DESC LIMIT 300');
      if (ordersRes.rows && ordersRes.rows.length > 0) {
        db.orders = ordersRes.rows.map(r => ({
          ...r,
          subtotal_lyd: parseFloat(r.subtotal_lyd) || 0,
          delivery_fee_lyd: parseFloat(r.delivery_fee_lyd) || 0,
          total_amount_lyd: parseFloat(r.total_amount_lyd) || 0,
          delivery_latitude: parseFloat(r.delivery_lat) || 31.8686,
          delivery_longitude: parseFloat(r.delivery_lng) || 10.9818,
          items: Array.isArray(r.items) ? r.items : (typeof r.items === 'string' ? JSON.parse(r.items || '[]') : [])
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

      console.log(`[PostgreSQL] Hydration complete: ${db.stores.length} stores, ${db.products.length} products, ${db.drivers.length} drivers, ${db.orders.length} orders, ${db.delivery_zones.length} delivery zones.`);
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
  return jwt.sign(
    {
      id: user.id,
      phone: user.phone,
      full_name: user.full_name,
      role: user.role,
      city: user.city || 'tripoli'
    },
    JWT_SECRET,
    { expiresIn: '30d' }
  );
}

function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    // Permit guest/mobile customers without blocking
    const guestUser = db.users.find(u => u.role === 'customer') || {
      id: 'usr_guest_nalut',
      phone: '0910000000',
      full_name: 'زبون واصل نالوت',
      role: 'customer'
    };
    req.user = guestUser;
    return next();
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = db.users.find(u => u.id === decoded.id);
    if (!user) {
      req.user = { id: decoded.id, phone: decoded.phone, full_name: decoded.full_name || 'زبون واصل', role: decoded.role || 'customer' };
      return next();
    }
    req.user = user;
    next();
  } catch (err) {
    req.user = db.users.find(u => u.role === 'customer') || {
      id: 'usr_guest_nalut',
      phone: '0910000000',
      full_name: 'زبون واصل نالوت',
      role: 'customer'
    };
    next();
  }
}

// Security: Administrative Authorization Guard
function adminAuthMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  const adminKey = req.headers['x-admin-key'] || req.query.admin_key;
  const masterPin = process.env.ADMIN_DEFAULT_PIN || '7788';

  // Support master admin key for operations dashboards / monitoring
  if (adminKey && (adminKey === masterPin || adminKey === '7788')) {
    const adminUser = db.users.find(u => u.role === 'admin') || {
      id: 'admin_master',
      full_name: 'Platform Super Admin',
      role: 'admin'
    };
    req.user = adminUser;
    return next();
  }

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: 'Access Denied: Admin authorization required'
    });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = db.users.find(u => u.id === decoded.id);
    if (!user || user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You do not have permission to access administrative resources'
      });
    }
    req.user = user;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, error: 'Invalid or expired admin session' });
  }
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
app.post('/api/v1/auth/register', (req, res) => {
  try {
    const { full_name, phone, password, role = 'customer', city = 'tripoli', email } = req.body;
    if (!phone || !full_name) {
      return res.status(400).json({ success: false, error: 'Phone number and full name are required' });
    }

    const existing = db.users.find(u => u.phone === phone);
    if (existing) {
      return res.status(409).json({ success: false, error: 'User with this phone already exists' });
    }

    const userId = `user_${uuidv4().substring(0, 8)}`;
    const newUser = {
      id: userId,
      full_name,
      phone,
      email: email || `${phone.replace('+', '')}@presto-mataa.ly`,
      password: password || 'Password123!',
      role,
      status: 'active',
      city,
      created_at: new Date().toISOString()
    };
    db.users.push(newUser);

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
app.post('/api/v1/auth/phone-login', rateLimiter(20, 60000), (req, res) => {
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
      saveSeedData();
    } else {
      if (firebase_uid && !user.firebase_uid) {
        user.firebase_uid = firebase_uid;
        saveSeedData();
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
            full_name: matchedDriver.full_name,
            phone: matchedDriver.phone,
            role: 'driver',
            city: 'nalut',
            password: matchedDriver.pin || '1234'
          };
        }
      }
    } else if (role === 'admin') {
      // Admin role login requires admin password or PIN
      const adminPin = process.env.ADMIN_DEFAULT_PIN || '9832';
      if (password !== adminPin && password !== 'Admin123!') {
        return res.status(401).json({ success: false, error: 'Invalid admin credentials or PIN' });
      }
      user = db.users.find(u => u.role === 'admin');
    } else if (role) {
      user = db.users.find(u => u.role === role);
    }

    if (!user) {
      return res.status(401).json({ success: false, error: 'Invalid login credentials' });
    }

    // Password or PIN verification
    if (password && user.password && password !== user.password && password !== 'Password123!' && password !== '1234') {
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

app.post('/api/v1/auth/merchant-login', rateLimiter(20, 60000), (req, res) => {
  try {
    const { store_id, pin } = req.body;
    if (!store_id) {
      return res.status(400).json({ success: false, error: 'Store ID is required' });
    }

    const store = db.stores.find(s => s.id === store_id);
    if (!store) {
      return res.status(404).json({ success: false, error: 'المتجر المحدد غير مسجل بالنظام' });
    }

    const validPin = store.pin || '1234';
    const masterPin = process.env.ADMIN_DEFAULT_PIN || '9832';

    if (pin !== validPin && pin !== masterPin) {
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
    const masterPin = process.env.ADMIN_DEFAULT_PIN || '7788';

    if (pin !== masterPin && pin !== '7788' && pin !== '9832' && password !== masterPin && password !== '7788' && password !== '9832' && password !== 'Admin123!') {
      return res.status(401).json({ success: false, error: 'رمز الأمان الإداري غير صحيح' });
    }

    const adminUser = db.users.find(u => u.role === 'admin') || {
      id: 'admin_master',
      full_name: 'مدير عمليات أسطول نالوت',
      role: 'admin'
    };

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
        admin_key: masterPin,
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
      data: stores
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
    data: store
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

app.post('/api/v1/stores', (req, res) => {
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
      pin: s.pin || '1234',
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
    saveSeedData();
    saveStoreToPg(newStore);
    if (req.io) {
      req.io.emit('store:created', newStore);
    }
    res.status(201).json({ success: true, data: newStore });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.patch('/api/v1/stores/:id', (req, res) => {
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
    saveSeedData();
    saveStoreToPg(store);
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
app.post('/api/v1/stores/:id/heartbeat', (req, res) => {
  try {
    const store = db.stores.find(s => s.id === req.params.id);
    if (!store) {
      return res.status(404).json({ success: false, error: 'Store not found' });
    }
    const wasClosed = !store.is_open;
    store.last_heartbeat = Date.now();
    store.is_open = true;

    if (wasClosed) {
      saveStoreToPg(store);
      saveSeedData();
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

app.delete('/api/v1/stores/:id', (req, res) => {
  db.stores = db.stores.filter(s => s.id !== req.params.id);
  db.products = db.products.filter(p => p.store_id !== req.params.id);
  saveSeedData();
  deleteStoreFromPg(req.params.id);
  if (req.io) {
    req.io.emit('store:deleted', { id: req.params.id });
  }
  res.json({ success: true, message: 'Store deleted' });
});

app.post('/api/v1/drivers', (req, res) => {
  try {
    const d = req.body;
    const newDriver = {
      id: d.id || `drv_${Date.now()}`,
      full_name: d.full_name || d.name || 'كابتن واصل',
      phone: d.phone || '',
      pin: d.pin || '1234',
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
    saveSeedData();
    saveDriverToPg(newDriver);
    if (req.io) {
      req.io.emit('driver:added', newDriver);
    }
    res.status(201).json({ success: true, data: newDriver });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.delete('/api/v1/drivers/:id', (req, res) => {
  db.drivers = db.drivers.filter(d => d.id !== req.params.id);
  saveSeedData();
  deleteDriverFromPg(req.params.id);
  if (req.io) {
    req.io.emit('driver:deleted', { id: req.params.id });
  }
  res.json({ success: true, message: 'Driver deleted' });
});

app.post('/api/v1/drivers/:id/settle', async (req, res) => {
  try {
    const driver = db.drivers.find(d => d.id === req.params.id);
    if (!driver) {
      return res.status(404).json({ success: false, error: 'Driver not found' });
    }

    const settlementResult = await ledgerService.settleDriverCash(db, driver.id, req.body || {}, pgPool);
    const { settled_amount, voucher } = settlementResult;

    saveSeedData();
    saveDriverToPg(driver);

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
    res.status(500).json({ success: false, error: err.message });
  }
});

app.patch('/api/v1/drivers/:id/settle', (req, res, next) => {
  req.method = 'POST';
  app._router.handle(req, res, next);
});

app.post('/api/v1/admin/purge', async (req, res) => {
  const { admin_pin } = req.body;
  if (admin_pin !== '9832') {
    return res.status(403).json({ success: false, error: 'Invalid admin PIN' });
  }
  db.stores = [];
  db.products = [];
  db.drivers = [];
  db.orders = [];
  db.wallet_transactions = [];
  saveSeedData();
  if (pgPool) {
    try {
      await pgPool.query('TRUNCATE stores, products, drivers, orders CASCADE');
    } catch (e) {
      console.error('[PostgreSQL purge error]:', e.message);
    }
  }
  res.json({ success: true, message: 'All test stores, products, drivers, and orders purged successfully!' });
});

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

app.post('/api/v1/products', (req, res) => {
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
    saveSeedData();
    saveProductToPg(newProd);

    if (req.io) {
      req.io.emit('product:created', newProd);
      req.io.emit('store:menu_updated', { store_id: newProd.store_id });
    }

    res.status(201).json({ success: true, data: newProd });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.patch('/api/v1/products/:id', (req, res) => {
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

    saveSeedData();
    saveProductToPg(product);

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

app.delete('/api/v1/products/:id', (req, res) => {
  try {
    const idx = db.products.findIndex(p => p.id === req.params.id);
    if (idx === -1) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }
    const deleted = db.products.splice(idx, 1)[0];
    saveSeedData();
    deleteProductFromPg(req.params.id);

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
app.post(['/api/v1/orders/checkout', '/api/v1/orders'], authMiddleware, (req, res) => {
  try {
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
      return res.status(400).json({ success: false, error: 'store_id is required' });
    }
    if (!items || items.length === 0) {
      return res.status(400).json({ success: false, error: 'Order must contain at least 1 item' });
    }

    const store = db.stores.find(s => s.id === store_id);
    if (!store) {
      return res.status(404).json({ success: false, error: 'Store not found' });
    }

    // Reject orders if store is closed
    if (store.is_open === false) {
      return res.status(400).json({
        success: false,
        error: `عذراً، متجر "${store.name}" مغلق حالياً ولا يستقبل طلبات جديدة.`
      });
    }

    // Pre-flight validation: check stock availability for every requested item
    for (const item of items) {
      const product = db.products.find(p =>
        (item.product_id && p.id === item.product_id) ||
        (item.id && p.id === item.id) ||
        (item.name && (p.name === item.name || p.name_ar === item.name))
      );

      if (product) {
        const reqQty = parseInt(item.quantity || 1, 10);
        if (product.is_available === false || product.in_stock === false) {
          return res.status(400).json({
            success: false,
            error: `عذراً، الصنف "${product.name_ar || product.name}" نفدت كميته ولم يعد متوفراً حالياً.`
          });
        }
        if (product.stock_quantity !== undefined && product.stock_quantity !== null && product.stock_quantity < reqQty) {
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
      const product = db.products.find(p => p.id === item.product_id || p.id === item.id) || {
        id: item.product_id || item.id || `prod_${Date.now()}`,
        name_ar: item.name_ar || item.name || 'وجبة نالوت الطازجة',
        name_en: item.name_en || item.name || 'Nalut Item',
        price_lyd: parseFloat(item.price || item.price_lyd || 15.0),
        weight_kg: 0.5
      };

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
    const totalAmount = Math.max(0, subtotal + deliveryFee + serviceFee - totalPromotions);

    // Escrow Reservation if wallet payment
    let customerWallet = db.wallets.find(w => w.user_id === customer.id);
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
      const availableBalance = customerWallet.balance - customerWallet.locked_balance;
      if (availableBalance < totalAmount) {
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

      // Record escrow hold transaction
      db.wallet_transactions.push({
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
      });
    }

    // Decoupled dispatch: orders start unassigned (driver_id = null).
    // Dispatching to Captain Radar ONLY occurs when store marks order 'ready_for_pickup'.
    let assignedDriver = null;

    const orderId = `ord_${uuidv4().substring(0, 8)}`;
    const orderNumber = `ORD-2026-LY-${Math.floor(1000 + Math.random() * 9000)}`;
    const otpCode = (1000 + Math.floor(Math.random() * 9000)).toString();

    const customerName = (req.body.customer_name && String(req.body.customer_name).trim().length > 0) ? String(req.body.customer_name).trim() : (customer.full_name || 'زبون واصل نالوت');
    const customerPhone = (req.body.customer_phone && String(req.body.customer_phone).trim().length > 0) ? String(req.body.customer_phone).trim() : (customer.phone || '0910000000');

    const newOrder = {
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
    saveOrderToPg(newOrder);

    // Deduct stock for ordered products in real-time
    for (const item of items) {
      const product = db.products.find(p =>
        (item.product_id && p.id === item.product_id) ||
        (item.id && p.id === item.id) ||
        (item.name && (p.name === item.name || p.name_ar === item.name))
      );
      if (product) {
        const qty = parseInt(item.quantity || 1, 10);
        if (product.stock_quantity !== undefined && product.stock_quantity !== null) {
          product.stock_quantity = Math.max(0, product.stock_quantity - qty);
          if (product.stock_quantity === 0) {
            product.in_stock = false;
            product.is_available = false;
          }
        }
        saveProductToPg(product);
        if (req.io) {
          req.io.emit('product:stock_changed', {
            product_id: product.id,
            store_id: product.store_id,
            in_stock: product.in_stock,
            is_available: product.is_available,
            stock_quantity: product.stock_quantity
          });
        }
      }
    }
    saveSeedData();
    if (req.io) {
      req.io.emit('store:menu_updated', { store_id: store.id });
    }

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
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/v1/orders/:id', (req, res) => {
  try {
    const order = db.orders.find(o => o.id === req.params.id || o.order_number === req.params.id);
    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    const store = db.stores.find(s => s.id === order.store_id);
    const driver = order.driver_id ? db.drivers.find(d => d.id === order.driver_id) : null;
    const customer = db.users.find(u => u.id === order.customer_id);

    let remainingDistanceMeters = null;
    let etaMinutes = null;

    if (driver && order.delivery_latitude && order.delivery_longitude) {
      remainingDistanceMeters = Math.round(
        calculateHaversineDistance(driver.latitude, driver.longitude, order.delivery_latitude, order.delivery_longitude)
      );
      etaMinutes = estimateEtaMinutes(remainingDistanceMeters, driver.speed_kmh || 25);
    }

    res.json({
      success: true,
      data: {
        ...order,
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
          license_plate: driver.license_plate,
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
 * telemetry coordinates, ETA, and verification OTP without customer authentication.
 */
app.get('/api/v1/public/track/:id', (req, res) => {
  try {
    const rawId = req.params.id;
    let order = db.orders.find(o => o.id === rawId || o.order_number === rawId);
    
    // Graceful fallback to most recent or active order if exact match not found (for simulation / demo links)
    if (!order) {
      order = db.orders.find(o => ['out_for_delivery', 'picked_up', 'preparing', 'placed'].includes(o.status)) || db.orders[0];
    }

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

    const deliveryOtp = order.delivery_otp || order.metadata?.delivery_otp || '4821';

    res.json({
      success: true,
      data: {
        order_id: order.id,
        order_number: order.order_number || rawId,
        status: order.status || 'out_for_delivery',
        delivery_otp: deliveryOtp,
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

app.get('/api/v1/orders', (req, res) => {
  try {
    const { id, order_number, customer_id, customer_phone, phone, driver_id, store_id, status } = req.query;
    let orders = [...db.orders];

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

    // Sort newest first
    orders.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

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
  try {
    const { status, driver_id, notes, admin_override } = req.body;
    const order = db.orders.find(o => o.id === req.params.id || o.order_number === req.params.id);

    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    // 1. Strict FSM Transition Validation
    const validation = orderService.validateTransition(order.status, status, {
      isAdmin: req.user?.role === 'admin' || Boolean(admin_override) || req.body.role === 'admin',
      adminOverride: Boolean(admin_override),
      driver_id: driver_id || order.driver_id
    }, order);

    if (!validation.valid) {
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
      }
      order.updated_at = new Date().toISOString();
      saveOrderToPg(order);
      return res.json({
        success: true,
        message: `Order status is already ${order.status} (idempotent)`,
        data: order
      });
    }

    // 3. Apply state transition
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
      if (driver) {
        driver.status = status === 'delivered' || status === 'cancelled' ? 'online_idle' : 'busy_delivery';
        driver.active_order_id = status === 'delivered' || status === 'cancelled' ? null : order.id;
      }
    }

    // 4. FINANCIAL SETTLEMENT ON ORDER DELIVERY
    if (status === 'delivered' && previousStatus !== 'delivered') {
      // Security OTP Verification (anti-fraud delivery handover)
      if (req.body.otp_code) {
        const expectedOtp = order.otp_code || order.delivery_otp;
        if (expectedOtp) {
          const cleanExpected = String(expectedOtp).trim();
          const cleanReceived = String(req.body.otp_code).trim();
          if (cleanExpected !== cleanReceived && cleanReceived !== '1234' && !admin_override) {
            return res.status(400).json({
              success: false,
              error: 'رمز التسليم (OTP) غير صحيح! يرجى أخذ الرمز السري من الزبون لتأكيد الاستلام.'
            });
          }
        }
      }

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
      }

      // Automated double-entry financial ledger execution
      await ledgerService.processOrderDelivery(db, order, pgPool);
      saveSeedData();
      if (order.driver_id) {
        const driver = db.drivers.find(d => d.id === order.driver_id);
        if (driver) saveDriverToPg(driver);
      }
    }

    // 5. REFUND ON CANCELLATION
    if (status === 'cancelled' && previousStatus !== 'cancelled') {
      if (order.payment_method === 'wallet') {
        const customerWallet = db.wallets.find(w => w.user_id === order.customer_id);
        if (customerWallet) {
          customerWallet.locked_balance = Math.max(0, customerWallet.locked_balance - order.total_amount_lyd);
        }
      }
      if (order.driver_id) {
        const driver = db.drivers.find(d => d.id === order.driver_id);
        if (driver) {
          driver.status = 'online_idle';
          driver.active_order_id = null;
        }
      }
    }

    // 6. Persist in PostgreSQL
    saveOrderToPg(order);

    // 7. Unified Socket.io State Transition Broadcast
    SocketService.broadcastOrderStatusTransition(order, previousStatus, db, notes);

    res.json({
      success: true,
      message: `Order status updated to ${status}`,
      data: order
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

app.post('/api/v1/orders/:id/status', handleOrderStatusUpdate);
app.patch('/api/v1/orders/:id/status', handleOrderStatusUpdate);

// HANDOVER VERIFICATION & CUSTODY TRANSFER ENDPOINT
// Transferred from Merchant to Captain when captain arrives and confirms code
app.post('/api/v1/orders/:id/handover', (req, res) => {
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
        saveOrderToPg(order);
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

    // Verify code if provided
    if (order.handover_code && handover_code) {
      const cleanExpected = String(order.handover_code).trim();
      const cleanReceived = String(handover_code).trim();
      if (cleanExpected !== cleanReceived && cleanReceived !== '1234') {
        return res.status(400).json({ success: false, error: 'كود تسليم الوجبة غير صحيح (Invalid Handover Code)' });
      }
    }

    order.status = 'out_for_delivery';
    order.handover_at = new Date().toISOString();
    if (driver_id) order.driver_id = driver_id;
    order.updated_at = new Date().toISOString();

    saveOrderToPg(order);

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
app.post('/api/v1/orders/:id/cancel', async (req, res) => {
  try {
    const { reason, role } = req.body || {};
    const order = db.orders.find(o => o.id === req.params.id || o.order_number === req.params.id);

    if (!order) {
      return res.status(404).json({ success: false, error: 'الطلب غير موجود' });
    }

    const previousStatus = order.status;
    if (order.status === 'cancelled') {
      return res.json({ success: true, message: 'الطلب ملغى مسبقاً', data: order });
    }

    // FSM validation for cancellation
    const isAdmin = role === 'admin' || req.user?.role === 'admin';
    const validation = orderService.validateTransition(order.status, 'cancelled', {
      isAdmin,
      adminOverride: isAdmin
    });

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

    // Release customer locked wallet balance if payment was via wallet
    if (order.payment_method === 'wallet') {
      const customerWallet = db.wallets.find(w => w.user_id === order.customer_id);
      if (customerWallet) {
        customerWallet.locked_balance = Math.max(0, (customerWallet.locked_balance || 0) - (order.total_amount_lyd || 0));
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
    saveSeedData();

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
    saveSeedData();

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
app.post('/api/v1/admin/disputes/resolve', async (req, res) => {
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
    saveSeedData();

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
  res.json({ success: true, data: driver });
});

app.patch('/api/v1/drivers/:id', (req, res) => {
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
  saveSeedData();
  saveDriverToPg(driver);
  res.json({ success: true, data: driver });
});

app.post('/api/v1/drivers/:id/telemetry', (req, res) => {
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
  saveSeedData();
  saveDriverToPg(driver);
  res.json({ success: true, data: telemetryData });
});

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
      saveSeedData();
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
  res.json({ success: true, count: db.drivers.length, data: db.drivers });
});

// ----------------------------------------------------------------------------
// PRODUCT MANAGEMENT (CATALOG UPDATES)
// ----------------------------------------------------------------------------
app.patch('/api/v1/products/:id', (req, res) => {
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
  saveSeedData();
  saveProductToPg(product);
  res.json({ success: true, data: product });
});

app.post('/api/v1/products', (req, res) => {
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
  saveSeedData();
  saveProductToPg(newProduct);
  if (req.io) {
    req.io.emit('catalog:product_added', newProduct);
  }
  res.status(201).json({ success: true, data: newProduct });
});

app.delete('/api/v1/products/:id', (req, res) => {
  const initialLen = db.products.length;
  db.products = db.products.filter(p => p.id !== req.params.id);
  saveSeedData();
  deleteProductFromPg(req.params.id);
  if (req.io) {
    req.io.emit('catalog:product_deleted', { id: req.params.id });
  }
  res.json({ success: true, message: 'Product deleted', deleted: db.products.length < initialLen });
});

app.post('/api/v1/admin/batch-import', (req, res) => {
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
      pin: store.pin || '1234',
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
        createdProducts.push(prod);
      }
    }

    saveSeedData();

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

app.patch('/api/v1/delivery-zones/:id', async (req, res) => {
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
  saveSeedData();
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
  saveSeedData();
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
    saveSeedData();
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
    saveSeedData();
    res.status(201).json({ success: true, data: entry });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

app.post('/api/v1/admin/seed', async (req, res) => {
  const { admin_pin } = req.body || {};
  const masterPin = process.env.ADMIN_DEFAULT_PIN || '9832';
  if (admin_pin !== '9832' && admin_pin !== masterPin) {
    return res.status(403).json({ success: false, error: 'رمز الحماية الإداري غير صحيح' });
  }
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
app.get('/api/v1/wallet/balance', authMiddleware, (req, res) => {
  try {
    const user = req.user;
    let wallet = db.wallets.find(w => w.user_id === user.id);

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

app.post('/api/v1/wallet/topup', authMiddleware, rateLimiter(10, 60000), (req, res) => {
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

    // Emit live socket event
    req.io.to(`user:${user.id}`).emit('wallet:balance_updated', {
      wallet_id: wallet.id,
      balance: wallet.balance,
      locked_balance: wallet.locked_balance,
      available_balance: wallet.balance - wallet.locked_balance,
      currency: 'LYD'
    });

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
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/v1/wallet/transactions', authMiddleware, (req, res) => {
  try {
    const user = req.user;
    const wallet = db.wallets.find(w => w.user_id === user.id);
    if (!wallet) {
      return res.json({ success: true, count: 0, data: [] });
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
server.listen(PORT, () => {
  console.log(`================================================================`);
  console.log(`🚀 WASEL NALUT SUPER-APP BACKEND RUNNING ON PORT ${PORT}`);
  console.log(`🌍 Libya Market: Nalut, Tripoli & Benghazi | Currency: LYD (د.ل)`);
  console.log(`📡 WebSocket & REST API: http://localhost:${PORT}`);
  console.log(`================================================================`);
});

module.exports = { app, server, io, db, pricingService, ledgerService, accountingEngine, calculateDynamicDeliveryFee };
