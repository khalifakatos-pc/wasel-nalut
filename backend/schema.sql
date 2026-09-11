-- ============================================================================
-- PRESTO / MATAA SUPER-APP ENTERPRISE DATABASE SCHEMA
-- PostgreSQL 14+ / Supabase Compatible DDL with PostGIS & Row Level Security
-- ============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 2. CUSTOM ENUMS AND DOMAINS
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('customer', 'driver', 'merchant', 'admin', 'dispatcher', 'support');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE user_status AS ENUM ('active', 'suspended', 'pending_verification', 'banned');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE wallet_type AS ENUM ('customer_wallet', 'driver_earnings', 'merchant_payouts', 'platform_escrow', 'platform_revenue');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE wallet_status AS ENUM ('active', 'frozen', 'closed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE transaction_type AS ENUM (
        'topup', 
        'order_hold_escrow', 
        'escrow_capture', 
        'escrow_refund', 
        'merchant_payout', 
        'driver_payout', 
        'platform_fee', 
        'tip', 
        'cash_collection', 
        'adjustment'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE transaction_status AS ENUM ('pending', 'completed', 'failed', 'reversed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE store_status AS ENUM ('active', 'inactive', 'busy', 'closed', 'suspended');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE product_status AS ENUM ('available', 'out_of_stock', 'archived');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE order_status AS ENUM (
        'draft',
        'placed',
        'confirmed_by_store',
        'preparing',
        'ready_for_pickup',
        'driver_assigned',
        'driver_arrived_store',
        'picked_up',
        'out_for_delivery',
        'driver_arrived_dropoff',
        'delivered',
        'cancelled',
        'refunded'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE payment_method AS ENUM ('wallet', 'cash_on_delivery', 'card', 'mobile_money');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE payment_status AS ENUM ('pending', 'authorized', 'captured', 'refunded', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE driver_status AS ENUM ('offline', 'online_idle', 'busy_delivery', 'suspended');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE vehicle_type AS ENUM ('bicycle', 'motorcycle', 'car', 'van');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE zone_type AS ENUM ('delivery_zone', 'high_surge', 'restricted', 'hub');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 3. HELPER FUNCTIONS & TRIGGERS
CREATE OR REPLACE FUNCTION set_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CORE USERS AND ADDRESSES
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(255) UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    password_hash VARCHAR(255),
    role user_role NOT NULL DEFAULT 'customer',
    status user_status NOT NULL DEFAULT 'active',
    avatar_url TEXT,
    locale VARCHAR(10) DEFAULT 'ar-IQ',
    device_token TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

CREATE TABLE IF NOT EXISTS user_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label VARCHAR(50) NOT NULL DEFAULT 'Home', -- Home, Work, Other
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    building_name VARCHAR(100),
    floor_number VARCHAR(20),
    apartment_number VARCHAR(20),
    city VARCHAR(100) NOT NULL DEFAULT 'Baghdad',
    state VARCHAR(100) DEFAULT 'Baghdad',
    postal_code VARCHAR(20),
    location GEOMETRY(Point, 4326) NOT NULL,
    latitude NUMERIC(10, 7) GENERATED ALWAYS AS (ST_Y(location)) STORED,
    longitude NUMERIC(10, 7) GENERATED ALWAYS AS (ST_X(location)) STORED,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    delivery_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_user_addresses_updated_at
BEFORE UPDATE ON user_addresses
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

-- ============================================================================
-- 5. WALLETS & DOUBLE-ENTRY TRANSACTION LEDGER
-- ============================================================================

CREATE TABLE IF NOT EXISTS wallets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE RESTRICT,
    wallet_type wallet_type NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'IQD',
    balance NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    locked_balance NUMERIC(14, 2) NOT NULL DEFAULT 0.00, -- Amount reserved for active escrows
    status wallet_status NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_wallet_balance_non_negative CHECK (balance >= 0),
    CONSTRAINT chk_wallet_locked_balance_non_negative CHECK (locked_balance >= 0),
    CONSTRAINT chk_wallet_available_funds CHECK (balance >= locked_balance),
    CONSTRAINT uq_user_wallet_currency UNIQUE (user_id, wallet_type, currency)
);

CREATE TRIGGER trg_wallets_updated_at
BEFORE UPDATE ON wallets
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

-- System accounts (user_id is NULL for platform master escrow and platform revenue)
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
    counterparty_wallet_id UUID REFERENCES wallets(id) ON DELETE RESTRICT,
    order_id UUID, -- Foreign key added below after orders table creation
    transaction_type transaction_type NOT NULL,
    amount NUMERIC(14, 2) NOT NULL,
    fee_amount NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    net_amount NUMERIC(14, 2) NOT NULL,
    balance_before NUMERIC(14, 2) NOT NULL,
    balance_after NUMERIC(14, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'IQD',
    status transaction_status NOT NULL DEFAULT 'completed',
    reference_id VARCHAR(100),
    narration TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_tx_amount_positive CHECK (amount > 0)
);

-- ============================================================================
-- 6. GEOFENCE ZONES
-- ============================================================================

CREATE TABLE IF NOT EXISTS geofence_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    zone_type zone_type NOT NULL DEFAULT 'delivery_zone',
    boundary GEOMETRY(Polygon, 4326) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    base_delivery_fee NUMERIC(10, 2) NOT NULL DEFAULT 3000.00,
    surge_multiplier NUMERIC(3, 2) NOT NULL DEFAULT 1.00,
    min_order_amount NUMERIC(10, 2) NOT NULL DEFAULT 5000.00,
    max_delivery_radius_meters INT NOT NULL DEFAULT 15000,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_geofence_zones_updated_at
BEFORE UPDATE ON geofence_zones
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

-- ============================================================================
-- 7. STORES & PRODUCT CATALOG
-- ============================================================================

CREATE TABLE IF NOT EXISTS stores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    name VARCHAR(150) NOT NULL,
    slug VARCHAR(180) NOT NULL UNIQUE,
    description TEXT,
    logo_url TEXT,
    banner_url TEXT,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    rating NUMERIC(3, 2) NOT NULL DEFAULT 5.00,
    total_ratings INT NOT NULL DEFAULT 0,
    commission_rate NUMERIC(5, 2) NOT NULL DEFAULT 15.00, -- 15% platform commission
    status store_status NOT NULL DEFAULT 'active',
    address TEXT NOT NULL,
    location GEOMETRY(Point, 4326) NOT NULL,
    latitude NUMERIC(10, 7) GENERATED ALWAYS AS (ST_Y(location)) STORED,
    longitude NUMERIC(10, 7) GENERATED ALWAYS AS (ST_X(location)) STORED,
    geofence_zone_id UUID REFERENCES geofence_zones(id) ON DELETE SET NULL,
    opening_hours JSONB NOT NULL DEFAULT '{"monday":{"open":"08:00","close":"23:00"},"tuesday":{"open":"08:00","close":"23:00"},"wednesday":{"open":"08:00","close":"23:00"},"thursday":{"open":"08:00","close":"23:00"},"friday":{"open":"13:00","close":"23:00"},"saturday":{"open":"08:00","close":"23:00"},"sunday":{"open":"08:00","close":"23:00"}}'::jsonb,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    prep_time_minutes INT NOT NULL DEFAULT 25,
    min_order_value NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_stores_updated_at
BEFORE UPDATE ON stores
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

CREATE TABLE IF NOT EXISTS store_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    sort_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_store_category_name UNIQUE (store_id, name)
);

CREATE TRIGGER trg_store_categories_updated_at
BEFORE UPDATE ON store_categories
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    category_id UUID REFERENCES store_categories(id) ON DELETE SET NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    image_url TEXT,
    base_price NUMERIC(12, 2) NOT NULL,
    discounted_price NUMERIC(12, 2),
    sku VARCHAR(50),
    status product_status NOT NULL DEFAULT 'available',
    sort_order INT NOT NULL DEFAULT 0,
    is_taxable BOOLEAN NOT NULL DEFAULT FALSE,
    preparation_time_minutes INT NOT NULL DEFAULT 15,
    calories INT,
    allergens TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_product_price_positive CHECK (base_price >= 0),
    CONSTRAINT chk_product_discount_valid CHECK (discounted_price IS NULL OR discounted_price <= base_price)
);

CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

CREATE TABLE IF NOT EXISTS product_addons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    group_name VARCHAR(100) NOT NULL DEFAULT 'Options', -- e.g. "Size", "Extra Toppings", "Sauce"
    name VARCHAR(100) NOT NULL,
    price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    max_selectable INT NOT NULL DEFAULT 1,
    is_required BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_addon_price_positive CHECK (price >= 0)
);

-- ============================================================================
-- 8. DRIVERS AND FLEET MANAGEMENT
-- ============================================================================

CREATE TABLE IF NOT EXISTS drivers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    vehicle_type vehicle_type NOT NULL DEFAULT 'motorcycle',
    license_plate VARCHAR(30) NOT NULL,
    license_number VARCHAR(50) NOT NULL,
    national_id VARCHAR(50) NOT NULL,
    status driver_status NOT NULL DEFAULT 'offline',
    is_approved BOOLEAN NOT NULL DEFAULT FALSE,
    rating NUMERIC(3, 2) NOT NULL DEFAULT 5.00,
    total_deliveries INT NOT NULL DEFAULT 0,
    current_location GEOMETRY(Point, 4326),
    latitude NUMERIC(10, 7) GENERATED ALWAYS AS (CASE WHEN current_location IS NOT NULL THEN ST_Y(current_location) ELSE NULL END) STORED,
    longitude NUMERIC(10, 7) GENERATED ALWAYS AS (CASE WHEN current_location IS NOT NULL THEN ST_X(current_location) ELSE NULL END) STORED,
    heading NUMERIC(5, 2) DEFAULT 0.00,
    speed_kmh NUMERIC(5, 2) DEFAULT 0.00,
    last_location_update TIMESTAMPTZ,
    max_delivery_radius_meters INT NOT NULL DEFAULT 10000,
    battery_level INT,
    is_charging BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_drivers_updated_at
BEFORE UPDATE ON drivers
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

-- ============================================================================
-- 9. ORDERS, ORDER ITEMS, AND AUDIT STATUS LOGS
-- ============================================================================

CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number VARCHAR(30) NOT NULL UNIQUE,
    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE RESTRICT,
    driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
    status order_status NOT NULL DEFAULT 'placed',
    payment_method payment_method NOT NULL DEFAULT 'wallet',
    payment_status payment_status NOT NULL DEFAULT 'pending',
    currency VARCHAR(3) NOT NULL DEFAULT 'IQD',
    subtotal NUMERIC(12, 2) NOT NULL,
    tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    delivery_fee NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    platform_fee NUMERIC(12, 2) NOT NULL DEFAULT 500.00,
    store_commission_fee NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    tip_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_amount NUMERIC(12, 2) NOT NULL,
    delivery_address JSONB NOT NULL,
    delivery_location GEOMETRY(Point, 4326) NOT NULL,
    delivery_latitude NUMERIC(10, 7) GENERATED ALWAYS AS (ST_Y(delivery_location)) STORED,
    delivery_longitude NUMERIC(10, 7) GENERATED ALWAYS AS (ST_X(delivery_location)) STORED,
    special_instructions TEXT,
    estimated_delivery_time TIMESTAMPTZ,
    actual_delivery_time TIMESTAMPTZ,
    cancellation_reason TEXT,
    cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_order_total_positive CHECK (total_amount >= 0)
);

CREATE TRIGGER trg_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

-- Add foreign key constraint back to wallet_transactions for orders
ALTER TABLE wallet_transactions 
ADD CONSTRAINT fk_wallet_tx_orders FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    product_name VARCHAR(150) NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    total_price NUMERIC(12, 2) NOT NULL,
    selected_addons JSONB DEFAULT '[]'::jsonb, -- Array of {id, name, price}
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_status_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status order_status NOT NULL,
    changed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    notes TEXT,
    location GEOMETRY(Point, 4326),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 10. REAL-TIME DRIVER LOCATIONS TELEMETRY
-- ============================================================================

CREATE TABLE IF NOT EXISTS driver_locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    location GEOMETRY(Point, 4326) NOT NULL,
    latitude NUMERIC(10, 7) GENERATED ALWAYS AS (ST_Y(location)) STORED,
    longitude NUMERIC(10, 7) GENERATED ALWAYS AS (ST_X(location)) STORED,
    heading NUMERIC(5, 2) DEFAULT 0.00,
    speed_kmh NUMERIC(5, 2) DEFAULT 0.00,
    accuracy_meters NUMERIC(6, 2),
    battery_level INT,
    is_charging BOOLEAN DEFAULT FALSE,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 11. INDEXES FOR HIGH-CONCURRENCY PERFORMANCE
-- ============================================================================

-- Spatial Indexes (GIST)
CREATE INDEX IF NOT EXISTS idx_user_addresses_location ON user_addresses USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_geofence_zones_boundary ON geofence_zones USING GIST (boundary);
CREATE INDEX IF NOT EXISTS idx_stores_location ON stores USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_drivers_current_location ON drivers USING GIST (current_location);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_location ON orders USING GIST (delivery_location);
CREATE INDEX IF NOT EXISTS idx_driver_locations_location ON driver_locations USING GIST (location);

-- Users & Auth Indexes
CREATE INDEX IF NOT EXISTS idx_users_phone ON users (phone);
CREATE INDEX IF NOT EXISTS idx_users_role_status ON users (role, status);

-- Store & Product Indexes
CREATE INDEX IF NOT EXISTS idx_stores_status ON stores (status);
CREATE INDEX IF NOT EXISTS idx_products_store_category ON products (store_id, category_id, status);
CREATE INDEX IF NOT EXISTS idx_product_addons_product ON product_addons (product_id, is_active);

-- Orders Indexes
CREATE INDEX IF NOT EXISTS idx_orders_customer_status ON orders (customer_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_store_status ON orders (store_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_driver_status ON orders (driver_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_order_status_logs_order ON order_status_logs (order_id, created_at ASC);

-- Wallet Ledger Indexes
CREATE INDEX IF NOT EXISTS idx_wallets_user ON wallets (user_id, wallet_type);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet_created ON wallet_transactions (wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_counterparty ON wallet_transactions (counterparty_wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_order ON wallet_transactions (order_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_idempotency ON wallet_transactions (idempotency_key);

-- Telemetry Indexes
CREATE INDEX IF NOT EXISTS idx_driver_locations_driver_time ON driver_locations (driver_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_driver_locations_order_time ON driver_locations (order_id, recorded_at DESC) WHERE order_id IS NOT NULL;

-- ============================================================================
-- 12. STORED PROCEDURES & LEDGER FUNCTIONS
-- ============================================================================

-- Function to safely find nearest available drivers within a radius (in meters)
CREATE OR REPLACE FUNCTION find_nearby_drivers(
    origin_point GEOMETRY,
    radius_meters INT DEFAULT 5000,
    vehicle_filter vehicle_type DEFAULT NULL
)
RETURNS TABLE (
    driver_id UUID,
    user_id UUID,
    full_name VARCHAR,
    phone VARCHAR,
    vehicle_type vehicle_type,
    rating NUMERIC,
    latitude NUMERIC,
    longitude NUMERIC,
    distance_meters DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id AS driver_id,
        u.id AS user_id,
        u.full_name,
        u.phone,
        d.vehicle_type,
        d.rating,
        d.latitude,
        d.longitude,
        ST_Distance(d.current_location::geography, origin_point::geography) AS distance_meters
    FROM drivers d
    JOIN users u ON d.user_id = u.id
    WHERE d.status = 'online_idle'
      AND d.is_approved = TRUE
      AND d.current_location IS NOT NULL
      AND (vehicle_filter IS NULL OR d.vehicle_type = vehicle_filter)
      AND ST_DWithin(d.current_location::geography, origin_point::geography, LEAST(radius_meters, d.max_delivery_radius_meters))
    ORDER BY distance_meters ASC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql STABLE;

-- Trigger to record status transitions automatically
CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO order_status_logs (order_id, status, changed_by_user_id, notes)
        VALUES (NEW.id, NEW.status, NEW.cancelled_by, 'Status changed to ' || NEW.status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION log_order_status_change();

-- ============================================================================
-- 13. ROW LEVEL SECURITY (RLS) POLICIES FOR SUPABASE
-- ============================================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;

-- Customers can view their own profile
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid() = id);

-- Users can view their own addresses
CREATE POLICY "Users can manage own addresses" ON user_addresses
    FOR ALL USING (auth.uid() = user_id);

-- Wallets access policy
CREATE POLICY "Users can view own wallet" ON wallets
    FOR SELECT USING (auth.uid() = user_id);

-- Orders access policy
CREATE POLICY "Users can view orders they are involved in" ON orders
    FOR SELECT USING (
        auth.uid() = customer_id 
        OR auth.uid() IN (SELECT owner_user_id FROM stores WHERE id = orders.store_id)
        OR auth.uid() IN (SELECT user_id FROM drivers WHERE id = orders.driver_id)
    );

-- System seed initialization for Master Accounts
DO $$
DECLARE
    v_platform_escrow_wallet_id UUID;
    v_platform_revenue_wallet_id UUID;
BEGIN
    -- Check if platform escrow wallet exists
    IF NOT EXISTS (SELECT 1 FROM wallets WHERE wallet_type = 'platform_escrow' AND user_id IS NULL) THEN
        INSERT INTO wallets (id, user_id, wallet_type, currency, balance, locked_balance, status)
        VALUES ('00000000-0000-0000-0000-000000000001', NULL, 'platform_escrow', 'IQD', 0.00, 0.00, 'active');
    END IF;

    -- Check if platform revenue wallet exists
    IF NOT EXISTS (SELECT 1 FROM wallets WHERE wallet_type = 'platform_revenue' AND user_id IS NULL) THEN
        INSERT INTO wallets (id, user_id, wallet_type, currency, balance, locked_balance, status)
        VALUES ('00000000-0000-0000-0000-000000000002', NULL, 'platform_revenue', 'IQD', 0.00, 0.00, 'active');
    END IF;
END $$;

-- ============================================================================
-- 14. REFERRAL, VIRAL GROWTH & FREE DELIVERY VOUCHERS
-- ============================================================================

CREATE TABLE IF NOT EXISTS referral_campaign_rules (
    id VARCHAR(64) PRIMARY KEY DEFAULT 'current_campaign',
    is_active BOOLEAN NOT NULL DEFAULT true,
    target_referrals_count INT NOT NULL DEFAULT 3,
    reward_type VARCHAR(32) NOT NULL DEFAULT 'free_delivery', -- free_delivery, wallet_lyd, percent_discount
    reward_value NUMERIC(10, 2) NOT NULL DEFAULT 100.00, -- 100% off delivery or LYD amount
    min_order_for_voucher_lyd NUMERIC(10, 2) NOT NULL DEFAULT 15.00,
    voucher_validity_days INT NOT NULL DEFAULT 14,
    qualify_condition VARCHAR(32) NOT NULL DEFAULT 'on_signup_otp', -- on_signup_otp, on_first_order
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS referral_records (
    id VARCHAR(64) PRIMARY KEY,
    referrer_user_id VARCHAR(64) NOT NULL,
    referred_phone VARCHAR(32) NOT NULL,
    referred_name VARCHAR(128),
    referred_user_id VARCHAR(64),
    status VARCHAR(32) NOT NULL DEFAULT 'pending', -- already_registered, verified, first_order_completed
    device_uuid VARCHAR(128),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_referral_records_referrer ON referral_records(referrer_user_id);
CREATE INDEX IF NOT EXISTS idx_referral_records_phone ON referral_records(referred_phone);

CREATE TABLE IF NOT EXISTS user_vouchers (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    code VARCHAR(64) UNIQUE NOT NULL,
    voucher_type VARCHAR(32) NOT NULL DEFAULT 'free_delivery',
    title VARCHAR(128) NOT NULL,
    discount_amount_lyd NUMERIC(10, 2) DEFAULT 0.00,
    is_percentage BOOLEAN DEFAULT false,
    is_free_delivery BOOLEAN DEFAULT true,
    is_used BOOLEAN DEFAULT false,
    used_at TIMESTAMP WITH TIME ZONE,
    used_order_id VARCHAR(64),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_vouchers_user ON user_vouchers(user_id);

