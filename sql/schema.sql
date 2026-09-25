-- ============================================================================
-- Smart Expense Tracker — PostgreSQL schema
-- Database: expensetracker
-- Run:  psql -d expensetracker -f schema.sql
-- ============================================================================

-- UUID generation (Postgres 13+ ships pgcrypto by default)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- users: registered users. Passwords are stored only as BCrypt hashes.
-- ----------------------------------------------------------------------------
CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- categories: the 11 fixed expense categories (reference / validation table)
-- ----------------------------------------------------------------------------
CREATE TABLE categories (
    id   SMALLSERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

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
    ('Other');

-- ----------------------------------------------------------------------------
-- expenses: the core fact table, one row per expense.
-- source: QR | MANUAL | BANK | RECURRING
-- ----------------------------------------------------------------------------
CREATE TABLE expenses (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    category    VARCHAR(50) NOT NULL,
    date        DATE NOT NULL,
    payment_mode VARCHAR(30),
    merchant    VARCHAR(255),
    notes       TEXT,
    source      VARCHAR(20) NOT NULL DEFAULT 'MANUAL'
                CHECK (source IN ('QR','MANUAL','BANK','RECURRING')),
    bank_txn_ref VARCHAR(100),          -- provider txn id; dedup key for BANK source
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Hot path for monthly summaries / budget alerts: filter by user + date range
CREATE INDEX idx_expenses_user_date ON expenses (user_id, date);
-- Dedup lookups during bank sync
CREATE INDEX idx_expenses_bank_ref ON expenses (bank_txn_ref);

-- ----------------------------------------------------------------------------
-- budgets: monthly spending limit per user per category.
-- alert_threshold 0.8 means "warn when 80% of the limit is used".
-- ----------------------------------------------------------------------------
CREATE TABLE budgets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    category        VARCHAR(50) NOT NULL,
    monthly_limit   NUMERIC(12,2) NOT NULL CHECK (monthly_limit > 0),
    alert_threshold NUMERIC(3,2) NOT NULL DEFAULT 0.8
                    CHECK (alert_threshold > 0 AND alert_threshold <= 1),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_budgets_user_category UNIQUE (user_id, category)
);

-- ----------------------------------------------------------------------------
-- recurring_expenses: rules materialized into expenses by the @Scheduled job.
-- frequency: DAILY | WEEKLY | MONTHLY | YEARLY
-- ----------------------------------------------------------------------------
CREATE TABLE recurring_expenses (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    amount        NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    category      VARCHAR(50) NOT NULL,
    frequency     VARCHAR(20) NOT NULL
                  CHECK (frequency IN ('DAILY','WEEKLY','MONTHLY','YEARLY')),
    next_due_date DATE NOT NULL,
    payment_mode  VARCHAR(30),
    merchant      VARCHAR(255),
    active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_recurring_due ON recurring_expenses (active, next_due_date);

-- ----------------------------------------------------------------------------
-- bank_consents: a user's consent for a bank data source (mock or real AA).
-- ----------------------------------------------------------------------------
CREATE TABLE bank_consents (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    bank_name  VARCHAR(100) NOT NULL,
    status     VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
               CHECK (status IN ('ACTIVE','REVOKED','EXPIRED')),
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ
);

-- ----------------------------------------------------------------------------
-- bank_accounts: accounts under a consent.
-- SECURITY: only MASKED account numbers are stored. Never credentials/PINs.
-- ----------------------------------------------------------------------------
CREATE TABLE bank_accounts (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consent_id           UUID NOT NULL REFERENCES bank_consents (id) ON DELETE CASCADE,
    masked_account_number VARCHAR(50) NOT NULL,   -- e.g. 'XXXX-XXXX-1234'
    account_type         VARCHAR(30),             -- SAVINGS | CURRENT
    bank_name            VARCHAR(100)
);

-- ----------------------------------------------------------------------------
-- bank_transactions: raw provider transactions before they become expenses.
-- txn_ref is the provider's unique reference and drives dedup.
-- ----------------------------------------------------------------------------
CREATE TABLE bank_transactions (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consent_id    UUID NOT NULL REFERENCES bank_consents (id) ON DELETE CASCADE,
    txn_ref       VARCHAR(100) NOT NULL UNIQUE,
    amount        NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    merchant      VARCHAR(255),
    date          DATE NOT NULL,
    raw_narration TEXT,
    imported      BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_bank_txn_consent ON bank_transactions (consent_id, date);

-- ----------------------------------------------------------------------------
-- merchant_map: per-user merchant -> category learning from corrections.
-- Checked before the ML model during categorization; hit_count grows with
-- each correction for the same merchant.
-- ----------------------------------------------------------------------------
CREATE TABLE merchant_map (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    merchant_key VARCHAR(255) NOT NULL,   -- normalized: lowercased, trimmed
    category     VARCHAR(50) NOT NULL,
    hit_count    INTEGER NOT NULL DEFAULT 1 CHECK (hit_count >= 1),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_merchant_map_user_key UNIQUE (user_id, merchant_key)
);

CREATE INDEX idx_merchant_map_lookup ON merchant_map (user_id, merchant_key);

-- ----------------------------------------------------------------------------
-- sync_runs: audit log of each bank sync (manual POST /api/bank/sync or the
-- daily @Scheduled job).
-- ----------------------------------------------------------------------------
CREATE TABLE sync_runs (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consent_id        UUID NOT NULL REFERENCES bank_consents (id) ON DELETE CASCADE,
    started_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at       TIMESTAMPTZ,
    new_transactions  INTEGER NOT NULL DEFAULT 0,
    duplicates_skipped INTEGER NOT NULL DEFAULT 0,
    status            VARCHAR(20) NOT NULL DEFAULT 'RUNNING'
                      CHECK (status IN ('RUNNING','SUCCESS','FAILED'))
);
