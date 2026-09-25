-- ==============================================================================
-- Smart Expense Tracker — demo seed data
--
-- Matches the JPA entities (BIGINT identity keys, enum names as VARCHAR).
-- Idempotent: safe to run more than once (ON CONFLICT DO NOTHING guards).
--
-- Demo login: demo@example.com / demo1234
-- ==============================================================================

-- ============================================================================
-- 1. Demo user
-- ============================================================================
-- Password (throwaway demo account only): demo1234
-- The hash below is a REAL BCrypt hash of 'demo1234' (cost 10), verified with
-- Python's bcrypt library: bcrypt.checkpw(b'demo1234', hash) == True.
-- Do NOT reuse this password anywhere.
INSERT INTO users (name, email, password_hash, created_at)
VALUES (
    'Demo User',
    'demo@example.com',
    '$2b$10$v0GQZdpUPbfcVbh4szD1u.Ar0BSzFLZUkCzkFJ5qlh8hYJJmmWw0a',
    now()
)
ON CONFLICT (email) DO NOTHING;

-- ============================================================================
-- 2. Expenses — 30 rows across July / August / September 2026
-- ============================================================================
-- payment_mode: UPI | CARD | CASH | BANK_TRANSFER
-- source: MANUAL (typed in) | QR (scanned QR receipt) | BANK (bank sync)
-- September Entertainment total = 950 + 900 = 1850, which is 92.5% of the
-- Entertainment budget (2000) and above its 0.8 alert threshold (1600) —
-- so the budget alert demo fires without the budget being exceeded.
-- Idempotent: skipped entirely if the demo user already has expenses.
INSERT INTO expenses
    (user_id, amount, category, date, payment_mode, merchant, notes, source, bank_txn_ref, created_at, updated_at)
SELECT v.user_id::bigint, v.amount::numeric(12,2), v.category, v.date::date, v.payment_mode, v.merchant, v.notes, v.source, v.bank_txn_ref, v.created_at::timestamptz, v.updated_at::timestamptz
FROM (VALUES
    -- July 2026 (8)
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 449.00,  'Food',        '2026-07-05', 'UPI',           'Swiggy',        'Dinner order',               'MANUAL', NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 312.00,  'Transport',   '2026-07-08', 'UPI',           'Uber',          'Airport drop',               'MANUAL', NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 2340.00, 'Shopping',    '2026-07-10', 'CARD',          'DMart',         'Monthly groceries',          'MANUAL', NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 299.00,  'Utilities',   '2026-07-12', 'UPI',           'Airtel',        'Prepaid recharge',           'QR',     NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 12000.00,'Rent',        '2026-07-15', 'BANK_TRANSFER', 'Landlord',      'July rent',                  'MANUAL', NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 649.00,  'Subscriptions','2026-07-18','CARD',          'Netflix',       'Monthly plan',               'MANUAL', NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 1120.00, 'Food',        '2026-07-22', 'UPI',           'BigBasket',     'Groceries',                  'QR',     NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 780.00,  'Entertainment','2026-07-28','CARD',          'PVR Cinemas',   'Movie night',                'MANUAL', NULL, now(), now()),

    -- August 2026 (11)
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 385.00,  'Food',        '2026-08-02', 'UPI',           'Swiggy',        'Lunch order',                'BANK',   'txn009', now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 210.00,  'Transport',   '2026-08-05', 'UPI',           'Uber',          'Office commute',             'BANK',   NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 520.00,  'Food',        '2026-08-07', 'UPI',           'Zomato',        'Weekend dinner',             'MANUAL', NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 12000.00,'Rent',        '2026-08-09', 'BANK_TRANSFER', 'Landlord',      'August rent',                'BANK',   NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 1450.00, 'Utilities',   '2026-08-11', 'UPI',           'BESCOM',        'Electricity bill',           'BANK',   'txn008', now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 649.00,  'Subscriptions','2026-08-14','CARD',          'Netflix',       'Monthly plan',               'BANK',   'txn010', now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 1985.00, 'Shopping',    '2026-08-16', 'CARD',          'DMart',         'Groceries + household',      'MANUAL', NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 180.00,  'Transport',   '2026-08-19', 'UPI',           'Uber',          'Evening ride',               'QR',     NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 299.00,  'Food',        '2026-08-23', 'UPI',           'Swiggy',        'Snacks',                     'MANUAL', NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 2499.00, 'Shopping',    '2026-08-26', 'CARD',          'Amazon',        'Headphones',                 'MANUAL', NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 640.00,  'Health',      '2026-08-30', 'CARD',          'Apollo Pharmacy','Medicines',                 'MANUAL', NULL, now(), now()),

    -- September 2026 (11)
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 12000.00,'Rent',        '2026-09-01', 'BANK_TRANSFER', 'Landlord',      'September rent',             'BANK',   'txn002', now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 249.00,  'Food',        '2026-09-02', 'UPI',           'Swiggy',        'Food delivery',              'BANK',   'txn001', now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 245.00,  'Transport',   '2026-09-04', 'UPI',           'Uber',          'Office commute',             'BANK',   'txn003', now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 649.00,  'Subscriptions','2026-09-06','CARD',          'Netflix',       'Monthly plan',               'BANK',   'txn004', now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 1340.00, 'Food',        '2026-09-08', 'UPI',           'BigBasket',     'Groceries',                  'BANK',   'txn005', now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 950.00,  'Entertainment','2026-09-10','CARD',          'BookMyShow',    'Concert tickets',            'MANUAL', NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 410.00,  'Food',        '2026-09-12', 'UPI',           'Zomato',        'Lunch',                      'BANK',   'txn006', now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 299.00,  'Utilities',   '2026-09-15', 'UPI',           'Airtel',        'Prepaid recharge',           'QR',     NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 1299.00, 'Shopping',    '2026-09-17', 'CARD',          'Amazon',        'Books',                      'MANUAL', NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 900.00,  'Entertainment','2026-09-19','CARD',          'PVR Cinemas',   'Movie + popcorn',            'MANUAL', NULL, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 320.00,  'Food',        '2026-09-21', 'UPI',           'Swiggy',        'Dinner',                     'BANK',   'txn007', now(), now())
) AS v(user_id, amount, category, date, payment_mode, merchant, notes, source, bank_txn_ref, created_at, updated_at)
WHERE NOT EXISTS (SELECT 1 FROM expenses e WHERE e.user_id = v.user_id);

-- ============================================================================
-- 3. Budgets — Entertainment is near-exceeded (1850 / 2000 = 92.5%,
--    above the 0.8 alert threshold of 1600), so the alert demo fires.
-- ============================================================================
INSERT INTO budgets (user_id, category, monthly_limit, alert_threshold, created_at)
VALUES
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'Food',         6000.00, 0.8, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'Transport',    2500.00, 0.8, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'Shopping',     8000.00, 0.8, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'Entertainment',2000.00, 0.8, now())
ON CONFLICT (user_id, category) DO NOTHING;

-- ============================================================================
-- 4. Recurring expenses — 3 monthly bills due in October 2026
-- ============================================================================
INSERT INTO recurring_expenses
    (user_id, name, amount, category, frequency, next_due_date, payment_mode, merchant, active, created_at)
SELECT v.user_id::bigint, v.name, v.amount::numeric(12,2), v.category, v.frequency, v.next_due_date::date, v.payment_mode, v.merchant, v.active::boolean, v.created_at::timestamptz
FROM (VALUES
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'House Rent',           12000.00, 'Rent',          'MONTHLY', '2026-10-01', 'BANK_TRANSFER', 'Landlord', TRUE, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'Netflix Subscription',   649.00, 'Subscriptions', 'MONTHLY', '2026-10-06', 'CARD',          'Netflix',  TRUE, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'Electricity Bill',      1450.00, 'Utilities',     'MONTHLY', '2026-10-11', 'UPI',           'BESCOM',   TRUE, now())
) AS v(user_id, name, amount, category, frequency, next_due_date, payment_mode, merchant, active, created_at)
WHERE NOT EXISTS (SELECT 1 FROM recurring_expenses r WHERE r.user_id = v.user_id);

-- ============================================================================
-- 5. Merchant mappings — learned merchant -> category mappings with hit
--    counts. Used by the backend to auto-categorise bank/UPI transactions.
-- ============================================================================
INSERT INTO merchant_mappings (user_id, merchant_key, category, hit_count, created_at, updated_at)
VALUES
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'swiggy',    'Food',          42, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'zomato',    'Food',          31, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'uber',      'Transport',     28, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'dmart',     'Shopping',      17, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'bigbasket', 'Food',          15, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'netflix',   'Subscriptions', 24, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'airtel',    'Utilities',     19, now(), now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'amazon',    'Shopping',      12, now(), now())
ON CONFLICT (user_id, merchant_key) DO NOTHING;

-- ============================================================================
-- 6. Bank consent + account + transactions (dedup demo)
-- ============================================================================
-- One APPROVED consent for the mock bank. Only the MASKED account number is
-- stored anywhere — never a full account number.
INSERT INTO bank_consents (user_id, bank_name, consent_id, status, created_at)
VALUES (
    (SELECT id FROM users WHERE email = 'demo@example.com'),
    'Mock National Bank',
    'mock-consent-001',
    'APPROVED',
    now()
)
ON CONFLICT (consent_id) DO NOTHING;

INSERT INTO bank_accounts (user_id, consent_id, bank_name, masked_number, created_at)
SELECT
    (SELECT id FROM users WHERE email = 'demo@example.com'),
    (SELECT id FROM bank_consents WHERE consent_id = 'mock-consent-001'),
    'Mock National Bank',
    'XXXX-4821',
    now()
WHERE NOT EXISTS (
    SELECT 1 FROM bank_accounts
    WHERE user_id = (SELECT id FROM users WHERE email = 'demo@example.com')
      AND masked_number = 'XXXX-4821'
);

-- ~10 bank transactions that mirror seeded expenses via txn_id,
-- plus a salary credit so the sync demo shows CREDIT handling too.
-- Re-running the bank sync against these rows should produce zero new
-- expenses (dedup demo), while mock-statement.json contains newer txns.
INSERT INTO bank_transactions
    (user_id, txn_id, date, amount, type, merchant, vpa, note, balance, processed, created_at)
VALUES
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'txn009', '2026-08-02', 385.00,  'DEBIT', 'Swiggy',      'swiggy@upi',    'Lunch order',       52140.00,  FALSE, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'txn008', '2026-08-11', 1450.00, 'DEBIT', 'BESCOM',      'bescom@upi',    'Electricity bill',  50690.00,  FALSE, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'txn010', '2026-08-14', 649.00,  'DEBIT', 'Netflix',     NULL,            'Monthly plan',      50041.00,  FALSE, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'txn002', '2026-09-01', 12000.00,'DEBIT', 'Landlord',    NULL,            'September rent',    38041.00,  FALSE, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'txn001', '2026-09-02', 249.00,  'DEBIT', 'Swiggy',      'swiggy@upi',    'Food delivery',     37792.00,  FALSE, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'txn003', '2026-09-04', 245.00,  'DEBIT', 'Uber',        'uber@upi',      'Office commute',    37577.00,  FALSE, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'txn004', '2026-09-06', 649.00,  'DEBIT', 'Netflix',     NULL,            'Monthly plan',      36928.00,  FALSE, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'txn005', '2026-09-08', 1340.00, 'DEBIT', 'BigBasket',   'bigbasket@upi', 'Groceries',         35588.00,  FALSE, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'txn006', '2026-09-12', 410.00,  'DEBIT', 'Zomato',      'zomato@upi',    'Lunch',             35178.00,  FALSE, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'txn007', '2026-09-21', 320.00,  'DEBIT', 'Swiggy',      'swiggy@upi',    'Dinner',            34858.00,  FALSE, now()),
    ((SELECT id FROM users WHERE email = 'demo@example.com'), 'txn011', '2026-09-01', 85000.00,'CREDIT','ACME Corp',   NULL,            'Salary September', 119828.00, FALSE, now())
ON CONFLICT (user_id, txn_id) DO NOTHING;

-- ============================================================================
-- Done. Sanity check after loading:
--   SELECT 'users', count(*) FROM users
--   UNION ALL SELECT 'expenses', count(*) FROM expenses
--   UNION ALL SELECT 'bank_transactions', count(*) FROM bank_transactions;
-- ============================================================================
