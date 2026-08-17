# Budget MCP Server

A personal budgeting MCP server: Claude (web, iOS, Desktop, Code) and a custom
iOS app both talk to the same Vercel-hosted backend. The budget itself is
"fake money" — pure bookkeeping, no real transfers. Real bank balances and
transactions come in read-only via Plaid, once a day, purely to reconcile
against the fake budget.

```
                 Vercel (this repo)
                 ┌─────────────────────────────┐
Plaid ──(daily)─▶│ /api/cron/daily-sync         │
   (read-only)   │        │                      │
                 │        ▼                      │
                 │  Neon Postgres                │
                 │   - budget_categories         │
                 │   - budget_ledger_entries      │
                 │   - plaid_accounts/transactions│
                 │        ▲            ▲          │
                 │        │            │          │
                 │ /api/mcp      /api/plaid/*     │
                 └────┬──────────────┬────────────┘
                      │              │
                Claude (connector)   Custom iOS app
                (chat, all reads/    (Plaid Link flow,
                 writes to budget)    visual budget UI)
```

## What lives where

- **`db/schema.sql`** — Postgres schema. Two clearly separated halves:
  the fake budget ledger, and the read-only Plaid mirror.
- **`src/budget/ledger.ts`** — category CRUD, fake fund transfers, manual
  expense logging. Every mutation writes an auditable ledger row.
- **`src/plaid/`** — Plaid client + the daily sync job (balances +
  `/transactions/sync`). No write/transfer Plaid products are used.
- **`src/reconcile/`** — matches real Plaid transactions to budget
  categories, and computes budget-vs-actual.
- **`src/mcp/`** — the MCP server and tool definitions Claude calls.
- **`api/mcp.ts`** — the public endpoint Claude's connector hits.
- **`api/cron/daily-sync.ts`** — invoked once a day by Vercel Cron. This is
  the _only_ sync path — there's no manual/on-demand sync tool, by design,
  to stay well within Plaid's rate limits.
- **`api/plaid/link-token.ts` / `exchange-token.ts`** — used only by your
  custom iOS app to run Plaid Link once per account and store the resulting
  access token.

## MCP tools exposed to Claude

| Tool                                   | Read/Write | Purpose                                            |
| -------------------------------------- | ---------- | -------------------------------------------------- |
| `budget_list_categories`               | read       | Category balances                                  |
| `budget_create_category`               | write      | New category + allocation                          |
| `budget_move_funds`                    | write      | Reallocate fake money between categories           |
| `budget_log_expense`                   | write      | Log a manual (non-Plaid) expense                   |
| `plaid_get_balances`                   | read       | Real balances as of last sync                      |
| `plaid_get_sync_status`                | read       | When each linked item last synced                  |
| `plaid_get_uncategorized_transactions` | read       | Real spend awaiting reconciliation                 |
| `plaid_reconcile_transaction`          | write      | Match one real transaction to a category           |
| `budget_get_vs_actual`                 | read       | Planned vs. fake-spent vs. real-spent per category |

## Setup

1. **Copy `.env.example` to `.env`** and fill it in as you go through the
   steps below. Scripts load it via Node's `--env-file=.env` — don't `export`
   `DATABASE_URL` in your shell directly, since Neon connection strings
   contain `&` characters that most shells will mangle.
2. **Neon**: create a database, copy the pooled connection string into
   `DATABASE_URL` in `.env`.
3. **Apply schema**:
   ```bash
   npm install
   npm run db:migrate
   ```
   Optionally seed a few sample categories for local testing before Plaid is linked:
   ```bash
   npm run db:seed
   ```
4. **Plaid**: get sandbox keys from the Plaid dashboard, set
   `PLAID_CLIENT_ID` / `PLAID_SECRET` / `PLAID_ENV=sandbox` in `.env`.
5. **Generate tokens**:
   ```bash
   openssl rand -hex 32   # MCP_SERVER_TOKEN
   openssl rand -hex 32   # APP_API_TOKEN
   openssl rand -hex 32   # CRON_SECRET
   openssl rand -hex 32   # ENCRYPTION_KEY (encrypts plaid_items.access_token at rest)
   ```
6. **Deploy to Vercel**, adding all variables from `.env.example` under
   Project Settings → Environment Variables. `vercel.json` already declares
   the daily cron schedule (07:00 UTC — adjust as you like).
7. **Link an account** from your iOS app: call `POST /api/plaid/link-token`
   to get a Plaid Link token, run Plaid Link natively, then
   `POST /api/plaid/exchange-token` with the resulting `publicToken`.
8. **Connect Claude**: in claude.ai → Settings → Connectors → Add custom
   connector, use `https://<your-vercel-app>.vercel.app/api/mcp` as the URL,
   with header `Authorization: Bearer <MCP_SERVER_TOKEN>`. This syncs to
   Claude's iOS/Android apps and Desktop automatically.

## Design notes / guardrails worth keeping if you extend this

- **No manual sync tool.** Daily cron only. If you add a "refresh now" button
  in the iOS app later, have it just re-read from Postgres, not call Plaid.
- **No Plaid write/transfer endpoints anywhere.** If a future feature needs
  one, treat that as a deliberate, separate decision — not an extension of
  this codebase's trust boundary.
- **`plaid_reconcile_transaction` is the only bridge** between real and fake
  data. Keep it that way so the fake budget's integrity is easy to reason
  about.
- `plaid_items.access_token` is encrypted at rest (AES-256-GCM via
  `src/security/crypto.ts`, key from `ENCRYPTION_KEY`). If you ever rotate
  `ENCRYPTION_KEY`, existing stored tokens become undecryptable — you'd need
  to re-link those accounts via Plaid Link.
- Category mutations (`budget_move_funds`, `budget_log_expense`,
  `plaid_reconcile_transaction`, `budget_create_category`) all validate
  against archived categories and duplicate names, and bundle their ledger +
  balance writes into a single Neon `sql.transaction()` call so a mid-write
  failure can't leave the ledger and category balance out of sync.
- `plaid_reconcile_transaction` atomically claims the transaction (`update
... where reconciled = false`) before writing ledger/category side effects,
  so two concurrent reconcile calls on the same transaction can't double-count.
