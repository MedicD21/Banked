-- Budget MCP schema (Neon Postgres)
-- Run once via `npm run db:migrate` or paste into Neon SQL editor.

create extension if not exists "uuid-ossp";

-- ── Budget (the "fake money" side) ─────────────────────────────────────────

create table if not exists budget_categories (
  id            uuid primary key default uuid_generate_v4(),
  name          text not null unique,
  allocated_cents bigint not null default 0,   -- planned amount for the period
  spent_cents     bigint not null default 0,   -- running total spent (fake ledger)
  period          text not null default 'monthly', -- monthly | weekly | custom
  is_archived     boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Every fund movement or logged expense inside the fake budget, so nothing
-- is ever a silent balance mutation — it's always an auditable entry.
create table if not exists budget_ledger_entries (
  id              uuid primary key default uuid_generate_v4(),
  category_id     uuid references budget_categories(id) on delete cascade,
  -- 'allocation' | 'transfer_in' | 'transfer_out' | 'expense' | 'reconciliation'
  entry_type      text not null,
  amount_cents    bigint not null,             -- positive = added to category, negative = removed
  memo            text,
  related_entry_id uuid references budget_ledger_entries(id), -- links transfer pairs
  plaid_transaction_id text,                   -- set only for entry_type = 'reconciliation'
  created_at      timestamptz not null default now()
);

create index if not exists idx_ledger_category on budget_ledger_entries(category_id);
create index if not exists idx_ledger_plaid_txn on budget_ledger_entries(plaid_transaction_id);

-- ── Plaid (the real, read-only side) ────────────────────────────────────────

create table if not exists plaid_items (
  id              uuid primary key default uuid_generate_v4(),
  item_id         text not null unique,        -- Plaid item_id
  access_token    text not null,               -- AES-256-GCM ciphertext ("iv:authTag:ciphertext" hex),
                                                -- encrypted/decrypted by src/security/crypto.ts using
                                                -- ENCRYPTION_KEY. Never stored or logged in plaintext.
  institution_name text,
  status          text not null default 'active', -- active | error | revoked
  last_synced_at  timestamptz,
  created_at      timestamptz not null default now()
);

create table if not exists plaid_accounts (
  id              uuid primary key default uuid_generate_v4(),
  plaid_item_id   uuid references plaid_items(id) on delete cascade,
  account_id      text not null unique,         -- Plaid account_id
  name            text not null,
  official_name   text,
  type            text,
  subtype         text,
  mask            text,
  current_balance_cents   bigint,
  available_balance_cents bigint,
  currency        text default 'USD',
  updated_at      timestamptz not null default now()
);

create table if not exists plaid_transactions (
  id                uuid primary key default uuid_generate_v4(),
  plaid_account_id  uuid references plaid_accounts(id) on delete cascade,
  transaction_id    text not null unique,        -- Plaid transaction_id
  amount_cents      bigint not null,             -- Plaid convention: positive = money out
  merchant_name     text,
  name              text,
  category           text,                        -- Plaid personal_finance_category.primary
  pending           boolean not null default false,
  date              date not null,
  reconciled        boolean not null default false,
  reconciled_category_id uuid references budget_categories(id),
  created_at        timestamptz not null default now()
);

create index if not exists idx_plaid_txn_reconciled on plaid_transactions(reconciled);
create index if not exists idx_plaid_txn_date on plaid_transactions(date);

-- ── Sync bookkeeping ─────────────────────────────────────────────────────

create table if not exists plaid_sync_cursors (
  plaid_item_id   uuid primary key references plaid_items(id) on delete cascade,
  cursor          text,                          -- Plaid /transactions/sync cursor
  updated_at      timestamptz not null default now()
);
