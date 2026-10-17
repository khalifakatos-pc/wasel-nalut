-- Wasel Nalut Production Data Zeroing Script
-- Resets all orders, transactions, and liabilities while strictly preserving stores, products, categories, delivery zones, and registered drivers.

TRUNCATE orders, order_items CASCADE;
TRUNCATE reviews CASCADE;
UPDATE drivers SET active_order_id = NULL, cod_balance_lyd = 0.00, cash_in_hand_lyd = 0.00, status = 'offline', is_active = false;
UPDATE wallets SET locked_balance = 0.00;
TRUNCATE wallet_transactions CASCADE;
TRUNCATE journal_entries, journal_entry_lines CASCADE;
TRUNCATE voucher_usage CASCADE;
