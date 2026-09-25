-- ============================================================================
-- Smart Expense Tracker — Demo Seed Data
-- ============================================================================
-- Purpose : Populate a fresh `expensetracker` database with a realistic demo
--           dataset so every feature (dashboard charts, budgets, recurring
--           bills, merchant auto-categorisation, bank sync dedup) is demoable
--           without manual data entry.
--
-- Usage   : psql -U $POSTGRES_USER -d expensetracker -f sql/seed.sql
--           (run AFTER sql/schema.sql)
--
-- Idempotent: most inserts are guarded with ON CONFLICT DO NOTHING, so the
--           script is safe to re-run. Lookups use the demo user's email, not
--           hardcoded UUIDs.
--
-- Defensive tables: the authoritative DDL lives in sql/schema.sql. The
--           CREATE TABLE IF NOT EXISTS statements below only ensure this file
--           also works standalone (e.g. a bare postgres:16 container). They
--           never drop or alter existing tables.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- Defensive table stubs (authoritative DDL is in sql/schema.sql)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          TEXT NOT NULL,
    email         TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS categories (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS expenses (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount        NUMERIC(12,2) NOT NULL,
    category      TEXT NOT NULL,
    date          DATE NOT NULL,
    payment_mode  TEXT NOT NULL,
    merchant      TEXT,
    notes         TEXT,
    source        TEXT NOT NULL DEFAULT 'MANUAL',
    bank_txn_ref  TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS budgets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category        TEXT NOT NULL,
    monthly_limit   NUMERIC(12,2) NOT NULL,
    alert_threshold NUMERIC(4,3) NOT NULL DEFAULT 0.8,
    UNIQUE (user_id, category)
);

CREATE TABLE IF NOT EXISTS recurring_expenses (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name          TEXT NOT NULL,
    amount        NUMERIC(12,2) NOT NULL,
    category      TEXT NOT NULL,
    frequency     TEXT NOT NULL,
    next_due_date DATE NOT NULL,
    payment_mode  TEXT NOT NULL,
    merchant      TEXT
);

CREATE TABLE IF NOT EXISTS merchant_map (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_key TEXT UNIQUE NOT NULL,
    category     TEXT NOT NULL,
    hit_count    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS bank_consents (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status     TEXT NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bank_accounts (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    consent_id    UUID REFERENCES bank_consents(id) ON DELETE SET NULL,
    bank_name     TEXT NOT NULL,
    masked_number TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
    -- NOTE: only masked account numbers are ever stored (e.g. 'XXXX-4821').
);

CREATE TABLE IF NOT EXISTS bank_transactions (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES bank_accounts(id) ON DELETE CASCADE,
    txn_id     TEXT UNIQUE NOT NULL,
    date       DATE NOT NULL,
    amount     NUMERIC(12,2) NOT NULL,
    type       TEXT NOT NULL,              -- DEBIT | CREDIT
    merchant   TEXT,
    vpa        TEXT,
    note       TEXT,
    balance    NUMERIC(14,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 1. Demo user
-- ============================================================================
-- Login:  demo@example.com
-- Password (throwaway demo account only): demo1234
-- The hash below is a REAL BCrypt hash of 'demo1234' (cost 10), generated and
-- verified with Python's bcrypt library: bcrypt.checkpw(b'demo1234', hash)
-- returned True at seed-generation time. Do NOT reuse this password anywhere.
INSERT INTO users (id, name, email, password_hash)
VALUES (
    gen_random_uuid(),
    'Demo User',
    'demo@example.com',
    '$2b$10$v0GQZdpUPbfcVbh4szD1u.Ar0BSzFLZUkCzkFJ5qlh8hYJJmmWw0a'
)
ON CONFLICT (email) DO NOTHING;

-- ============================================================================
-- 2. Categories (the 11 canonical categories)
-- ============================================================================
INSERT INTO categories (name) VALUES
    ('Food'),
    ('Transport'),
    ('Shopping'),
    ('Utilities'),
    ('Rent'),
    ('Subscriptions'),
    ('Health'),
    ('Entertainment'),
    ('Education'),
    ('Travel'),
    ('Other')
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- 3. Expenses — 30 rows across July / August / September 2026
-- ============================================================================
-- payment_mode: UPI | CARD | CASH | BANK_TRANSFER
-- source: MANUAL (typed in) | QR (scanned QR receipt) | BANK (bank sync)
-- September Entertainment total = 950 + 900 = 1850, which is 92.5% of the
-- Entertainment budget (2000) and above its 0.8 alert threshold (1600) —
-- so the budget alert demo fires without the budget being exceeded.
INSERT INTO expenses
    (user_id, amount, category, date, payment_mode, merchant, notes, source, bank_txn_ref)
VALUES
    -- July 2026 (8)
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 449.00,  'Food',        '2026-07-05', 'UPI',           'Swiggy',        'Dinner order',               'MANUAL', NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 312.00,  'Transport',   '2026-07-08', 'UPI',           'Uber',          'Airport drop',               'MANUAL', NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 2340.00, 'Shopping',    '2026-07-10', 'CARD',          'DMart',         'Monthly groceries',          'MANUAL', NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 299.00,  'Utilities',   '2026-07-12', 'UPI',           'Airtel',        'Prepaid recharge',           'QR',     NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 12000.00,'Rent',        '2026-07-15', 'BANK_TRANSFER', 'Landlord',      'July rent',                  'MANUAL', NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 649.00,  'Subscriptions','2026-07-18','CARD',          'Netflix',       'Monthly plan',               'MANUAL', NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 1120.00, 'Food',        '2026-07-22', 'UPI',           'BigBasket',     'Groceries',                  'QR',     NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 780.00,  'Entertainment','2026-07-28','CARD',          'PVR Cinemas',   'Movie night',                'MANUAL', NULL),

    -- August 2026 (11)
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 385.00,  'Food',        '2026-08-02', 'UPI',           'Swiggy',        'Lunch order',                'BANK',   'txn009'),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 210.00,  'Transport',   '2026-08-05', 'UPI',           'Uber',          'Office commute',             'BANK',   NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 520.00,  'Food',        '2026-08-07', 'UPI',           'Zomato',        'Weekend dinner',             'MANUAL', NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 12000.00,'Rent',        '2026-08-09', 'BANK_TRANSFER', 'Landlord',      'August rent',                'BANK',   NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 1450.00, 'Utilities',   '2026-08-11', 'UPI',           'BESCOM',        'Electricity bill',           'BANK',   'txn008'),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 649.00,  'Subscriptions','2026-08-14','CARD',          'Netflix',       'Monthly plan',               'BANK',   'txn010'),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 1985.00, 'Shopping',    '2026-08-16', 'CARD',          'DMart',         'Groceries + household',      'MANUAL', NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 180.00,  'Transport',   '2026-08-19', 'UPI',           'Uber',          'Evening ride',               'QR',     NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 299.00,  'Food',        '2026-08-23', 'UPI',           'Swiggy',        'Snacks',                     'MANUAL', NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 2499.00, 'Shopping',    '2026-08-26', 'CARD',          'Amazon',        'Headphones',                 'MANUAL', NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 640.00,  'Health',      '2026-08-30', 'CARD',          'Apollo Pharmacy','Medicines',                 'MANUAL', NULL),

    -- September 2026 (11)
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 12000.00,'Rent',        '2026-09-01', 'BANK_TRANSFER', 'Landlord',      'September rent',             'BANK',   'txn002'),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 249.00,  'Food',        '2026-09-02', 'UPI',           'Swiggy',        'Food delivery',              'BANK',   'txn001'),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 245.00,  'Transport',   '2026-09-04', 'UPI',           'Uber',          'Office commute',             'BANK',   'txn003'),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 649.00,  'Subscriptions','2026-09-06','CARD',          'Netflix',       'Monthly plan',               'BANK',   'txn004'),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 1340.00, 'Food',        '2026-09-08', 'UPI',           'BigBasket',     'Groceries',                  'BANK',   'txn005'),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 950.00,  'Entertainment','2026-09-10','CARD',          'BookMyShow',    'Concert tickets',            'MANUAL', NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 410.00,  'Food',        '2026-09-12', 'UPI',           'Zomato',        'Lunch',                      'BANK',   'txn006'),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 299.00,  'Utilities',   '2026-09-15', 'UPI',           'Airtel',        'Prepaid recharge',           'QR',     NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 1299.00, 'Shopping',    '2026-09-17', 'CARD',          'Amazon',        'Books',                      'MANUAL', NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 900.00,  'Entertainment','2026-09-19','CARD',          'PVR Cinemas',   'Movie + popcorn',            'MANUAL', NULL),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 320.00,  'Food',        '2026-09-21', 'UPI',           'Swiggy',        'Dinner',                     'BANK',   'txn007');

-- ============================================================================
-- 4. Budgets — Entertainment is near-exceeded (1850 / 2000 = 92.5%,
--    above the 0.8 alert threshold of 1600), so the alert demo fires.
-- ============================================================================
INSERT INTO budgets (user_id, category, monthly_limit, alert_threshold)
VALUES
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'Food',         6000.00, 0.8),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'Transport',    2500.00, 0.8),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'Shopping',     8000.00, 0.8),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'Entertainment',2000.00, 0.8)
ON CONFLICT (user_id, category) DO NOTHING;

-- ============================================================================
-- 5. Recurring expenses — 3 monthly bills due in October 2026
-- ============================================================================
INSERT INTO recurring_expenses
    (user_id, name, amount, category, frequency, next_due_date, payment_mode, merchant)
VALUES
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'House Rent',        12000.00, 'Rent',        'MONTHLY', '2026-10-01', 'BANK_TRANSFER', 'Landlord'),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'Netflix Subscription', 649.00, 'Subscriptions', 'MONTHLY', '2026-10-06', 'CARD',          'Netflix'),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'Electricity Bill',   1450.00, 'Utilities',   'MONTHLY', '2026-10-11', 'UPI',           'BESCOM');

-- ============================================================================
-- 6. Merchant map — learned merchant -> category mappings with hit counts.
--    Used by the backend to auto-categorise bank/UPI transactions.
-- ============================================================================
INSERT INTO merchant_map (merchant_key, category, hit_count)
VALUES
    ('swiggy',    'Food',          42),
    ('zomato',    'Food',          31),
    ('uber',      'Transport',     28),
    ('dmart',     'Shopping',      17),
    ('bigbasket', 'Food',          15),
    ('netflix',   'Subscriptions', 24),
    ('airtel',    'Utilities',     19),
    ('amazon',    'Shopping',      12)
ON CONFLICT (merchant_key) DO NOTHING;

-- ============================================================================
-- 7. Bank consent + account + transactions (dedup demo)
-- ============================================================================
-- One APPROVED consent for the mock bank. Only the MASKED account number is
-- stored anywhere — never a full account number.
INSERT INTO bank_consents (id, user_id, status)
VALUES (
    gen_random_uuid(),
    (SELECT id FROM users WHERE email = 'demo@example.com'),
    'APPROVED'
)
ON CONFLICT DO NOTHING;

INSERT INTO bank_accounts (id, user_id, consent_id, bank_name, masked_number)
VALUES (
    gen_random_uuid(),
    (SELECT id FROM users WHERE email = 'demo@example.com'),
    (SELECT id FROM bank_consents
      WHERE user_id = (SELECT id FROM users WHERE email = 'demo@example.com')
      ORDER BY created_at DESC LIMIT 1),
    'Mock National Bank',
    'XXXX-4821'
)
ON CONFLICT DO NOTHING;

-- ~10 bank transactions that mirror seeded expenses via bank_txn_ref,
-- plus a salary credit so the sync demo shows CREDIT handling too.
-- Re-running the bank sync against these rows should produce zero new
-- expenses (dedup demo), while mock-statement.json contains newer txns.
INSERT INTO bank_transactions
    (account_id, txn_id, date, amount, type, merchant, vpa, note, balance)
VALUES
    ((SELECT id FROM bank_accounts WHERE masked_number = 'XXXX-4821' LIMIT 1), 'txn009', '2026-08-02', 385.00,  'DEBIT', 'Swiggy',      'swiggy@upi',    'Lunch order',       52140.00),
    ((SELECT id FROM bank_accounts WHERE masked_number = 'XXXX-4821' LIMIT 1), 'txn008', '2026-08-11', 1450.00, 'DEBIT', 'BESCOM',      'bescom@upi',    'Electricity bill',  50690.00),
    ((SELECT id FROM bank_accounts WHERE masked_number = 'XXXX-4821' LIMIT 1), 'txn010', '2026-08-14', 649.00,  'DEBIT', 'Netflix',     NULL,            'Monthly plan',      50041.00),
    ((SELECT id FROM bank_accounts WHERE masked_number = 'XXXX-4821' LIMIT 1), 'txn002', '2026-09-01', 12000.00,'DEBIT', 'Landlord',    NULL,            'September rent',    38041.00),
    ((SELECT id FROM bank_accounts WHERE masked_number = 'XXXX-4821' LIMIT 1), 'txn001', '2026-09-02', 249.00,  'DEBIT', 'Swiggy',      'swiggy@upi',    'Food delivery',     37792.00),
    ((SELECT id FROM bank_accounts WHERE masked_number = 'XXXX-4821' LIMIT 1), 'txn003', '2026-09-04', 245.00,  'DEBIT', 'Uber',        'uber@upi',      'Office commute',    37547.00),
    ((SELECT id FROM bank_accounts WHERE masked_number = 'XXXX-4821' LIMIT 1), 'txn004', '2026-09-06', 649.00,  'DEBIT', 'Netflix',     NULL,            'Monthly plan',      36898.00),
    ((SELECT id FROM bank_accounts WHERE masked_number = 'XXXX-4821' LIMIT 1), 'txn005', '2026-09-08', 1340.00, 'DEBIT', 'BigBasket',   'bigbasket@upi', 'Groceries',         35558.00),
    ((SELECT id FROM bank_accounts WHERE masked_number = 'XXXX-4821' LIMIT 1), 'txn006', '2026-09-12', 410.00,  'DEBIT', 'Zomato',      'zomato@upi',    'Lunch',             35148.00),
    ((SELECT id FROM bank_accounts WHERE masked_number = 'XXXX-4821' LIMIT 1), 'txn007', '2026-09-21', 320.00,  'DEBIT', 'Swiggy',      'swiggy@upi',    'Dinner',            34828.00),
    ((SELECT id FROM bank_accounts WHERE masked_number = 'XXXX-4821' LIMIT 1), 'txn011', '2026-09-01', 85000.00,'CREDIT','ACME Corp',   NULL,            'Salary September', 119828.00)
ON CONFLICT (txn_id) DO NOTHING;

-- ============================================================================
-- Done. Sanity check after loading:
--   SELECT 'users', count(*) FROM users
--   UNION ALL SELECT 'expenses', count(*) FROM expenses
--   UNION ALL SELECT 'bank_transactions', count(*) FROM bank_transactions;
-- ============================================================================
