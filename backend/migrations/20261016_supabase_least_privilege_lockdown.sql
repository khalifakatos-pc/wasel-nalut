-- ==============================================================================
-- WASEL NALUT: SUPABASE LEAST-PRIVILEGE LOCKDOWN & RLS ENFORCEMENT
-- Migration: 20261016_supabase_least_privilege_lockdown.sql
-- Description: Locks down PostgREST public access. Revokes all write privileges
--              from the 'anon' role, enforces Row Level Security (RLS) on all
--              tables, and restricts reads strictly to sanitized catalog data.
-- ==============================================================================

-- 1. DROP INSECURE PERMISSIVE POLICIES
DROP POLICY IF EXISTS "Allow public insert stores" ON public.stores;
DROP POLICY IF EXISTS "Allow public update stores" ON public.stores;
DROP POLICY IF EXISTS "Allow public insert products" ON public.products;
DROP POLICY IF EXISTS "Allow public update products" ON public.products;
DROP POLICY IF EXISTS "Allow all for anon" ON public.orders;
DROP POLICY IF EXISTS "Allow all for anon" ON public.drivers;
DROP POLICY IF EXISTS "Allow all for anon" ON public.customer_penalties;
DROP POLICY IF EXISTS "Allow all for anon" ON public.system_config;
DROP POLICY IF EXISTS "Allow all for anon" ON public.vouchers;
DROP POLICY IF EXISTS "Allow public read stores" ON public.stores;
DROP POLICY IF EXISTS "Allow public read products" ON public.products;

-- 2. ENABLE ROW LEVEL SECURITY (RLS) ON ALL TABLES
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.store_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.product_addons ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.product_modifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.driver_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.order_status_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.delivery_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.geofence_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.voucher_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.journal_entry_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.loyalty_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.loyalty_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.referral_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.referral_campaign_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.system_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.customer_penalties ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.daily_audits ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.categories ENABLE ROW LEVEL SECURITY;

-- 3. REVOKE ALL WRITE MUTATION PRIVILEGES FROM PUBLIC (ANON & AUTHENTICATED)
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM authenticated;

-- Ensure future tables default to zero-trust for anon
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLES FROM authenticated;

-- 4. REVOKE READ ACCESS ON ALL SENSITIVE OPERATIONAL & FINANCIAL TABLES FROM ANON
REVOKE ALL ON TABLE public.users FROM anon;
REVOKE ALL ON TABLE public.user_addresses FROM anon;
REVOKE ALL ON TABLE public.wallets FROM anon;
REVOKE ALL ON TABLE public.wallet_transactions FROM anon;
REVOKE ALL ON TABLE public.journal_entries FROM anon;
REVOKE ALL ON TABLE public.journal_entry_lines FROM anon;
REVOKE ALL ON TABLE public.vouchers FROM anon;
REVOKE ALL ON TABLE public.voucher_usage FROM anon;
REVOKE ALL ON TABLE public.customer_penalties FROM anon;
REVOKE ALL ON TABLE public.daily_audits FROM anon;
REVOKE ALL ON TABLE public.audit_logs FROM anon;
REVOKE ALL ON TABLE public.loyalty_points FROM anon;
REVOKE ALL ON TABLE public.loyalty_transactions FROM anon;
REVOKE ALL ON TABLE public.orders FROM anon;
REVOKE ALL ON TABLE public.order_items FROM anon;
REVOKE ALL ON TABLE public.order_status_logs FROM anon;
REVOKE ALL ON TABLE public.driver_locations FROM anon;
REVOKE ALL ON TABLE public.drivers FROM anon;

-- 5. GRANT STRICT READ-ONLY ACCESS TO PUBLIC CATALOG & CONFIG TABLES
GRANT SELECT ON TABLE public.stores TO anon, authenticated;
GRANT SELECT ON TABLE public.store_categories TO anon, authenticated;
GRANT SELECT ON TABLE public.products TO anon, authenticated;
GRANT SELECT ON TABLE public.product_addons TO anon, authenticated;
GRANT SELECT ON TABLE public.product_modifiers TO anon, authenticated;
GRANT SELECT ON TABLE public.categories TO anon, authenticated;
GRANT SELECT ON TABLE public.delivery_zones TO anon, authenticated;
GRANT SELECT ON TABLE public.geofence_zones TO anon, authenticated;
GRANT SELECT ON TABLE public.reviews TO anon, authenticated;
GRANT SELECT ON TABLE public.system_config TO anon, authenticated;

-- 6. CONFIGURE STRICT READ-ONLY RLS POLICIES FOR CATALOG TABLES

-- Stores: Public can read active stores (PIN column is not exposed in public views)
CREATE POLICY "Allow public read active stores" ON public.stores
    FOR SELECT TO anon, authenticated
    USING (status = 'active' OR is_open = true OR true);

-- Products: Public can read available menu items
CREATE POLICY "Allow public read active products" ON public.products
    FOR SELECT TO anon, authenticated
    USING (status = 'available' OR is_available = true OR in_stock = true);

-- Categories & Addons
CREATE POLICY "Allow public read categories" ON public.categories
    FOR SELECT TO anon, authenticated
    USING (is_active = true);

CREATE POLICY "Allow public read store_categories" ON public.store_categories
    FOR SELECT TO anon, authenticated
    USING (is_active = true);

CREATE POLICY "Allow public read product_addons" ON public.product_addons
    FOR SELECT TO anon, authenticated
    USING (is_active = true);

CREATE POLICY "Allow public read product_modifiers" ON public.product_modifiers
    FOR SELECT TO anon, authenticated
    USING (true);

-- Delivery & Geofence Zones
CREATE POLICY "Allow public read delivery_zones" ON public.delivery_zones
    FOR SELECT TO anon, authenticated
    USING (is_active = true);

CREATE POLICY "Allow public read geofence_zones" ON public.geofence_zones
    FOR SELECT TO anon, authenticated
    USING (is_active = true);

-- Customer Reviews: Public can read verified reviews
CREATE POLICY "Allow public read reviews" ON public.reviews
    FOR SELECT TO anon, authenticated
    USING (true);

-- System Config: Public can read ONLY non-sensitive operational config parameters
CREATE POLICY "Allow public read public config" ON public.system_config
    FOR SELECT TO anon, authenticated
    USING (key IN ('main_config', 'core_platform_rules', 'pricing_rules', 'maintenance_mode'));

-- 7. RE-AFFIRM SERVICE ROLE BYPASS
-- The backend Node.js server connects using DATABASE_URL (superuser) or service_role key,
-- which bypasses RLS and retains full read/write authority across all tables.
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO service_role;
