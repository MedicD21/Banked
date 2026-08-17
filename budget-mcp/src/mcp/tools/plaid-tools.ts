import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { getSql, toDollars } from "../../db/client.js";
import {
  getUncategorizedTransactions,
  reconcileTransaction,
  getBudgetVsActual,
} from "../../reconcile/reconcile.js";

export function registerPlaidTools(server: McpServer): void {
  server.registerTool(
    "plaid_get_balances",
    {
      title: "Get Real Account Balances",
      description: `Returns current balances for all linked bank accounts, as of the last daily sync
(balances are NOT fetched live — see plaid_get_sync_status for when they were last updated).

This is read-only. Nothing about this tool can move money or change account settings.

Returns: array of { name, mask, type, subtype, currentBalanceDollars, availableBalanceDollars }`,
      inputSchema: {},
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    },
    async () => {
      const sql = getSql();
      const rows = await sql`
        select name, mask, type, subtype, current_balance_cents, available_balance_cents, updated_at
        from plaid_accounts
        order by name
      `;
      const accounts = rows.map((r) => ({
        name: r.name as string,
        mask: r.mask as string | null,
        type: r.type as string | null,
        subtype: r.subtype as string | null,
        currentBalanceDollars: toDollars(r.current_balance_cents as number),
        availableBalanceDollars:
          r.available_balance_cents !== null ? toDollars(r.available_balance_cents as number) : null,
        lastUpdated: r.updated_at as string,
      }));
      return {
        content: [{ type: "text", text: JSON.stringify(accounts, null, 2) }],
        structuredContent: { accounts },
      };
    }
  );

  server.registerTool(
    "plaid_get_sync_status",
    {
      title: "Get Last Sync Status",
      description: `Returns when each linked bank item last synced and whether it's healthy.
Sync runs once per day automatically — there is no manual/on-demand sync tool by design,
to stay well inside Plaid's API rate limits.`,
      inputSchema: {},
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    },
    async () => {
      const sql = getSql();
      const rows = await sql`
        select institution_name, status, last_synced_at from plaid_items order by institution_name
      `;
      const items = rows.map((r) => ({
        institutionName: r.institution_name as string | null,
        status: r.status as string,
        lastSyncedAt: r.last_synced_at as string | null,
      }));
      return { content: [{ type: "text", text: JSON.stringify(items, null, 2) }], structuredContent: { items } };
    }
  );

  server.registerTool(
    "plaid_get_uncategorized_transactions",
    {
      title: "Get Uncategorized Real Transactions",
      description: `Lists recent real bank transactions (from the last daily sync) that haven't
been reconciled against a budget category yet. Use this to find candidates for
plaid_reconcile_transaction.

Args:
  - limit: max transactions to return (default 25)

Returns: array of { transactionId, date, merchantName, name, plaidCategory, amountDollars }
amountDollars follows Plaid's convention: positive = money out (a purchase/expense).`,
      inputSchema: {
        limit: z.number().int().min(1).max(100).default(25),
      },
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    },
    async ({ limit }) => {
      const transactions = await getUncategorizedTransactions(limit);
      if (transactions.length === 0) {
        return { content: [{ type: "text", text: "No uncategorized transactions — everything is reconciled." }] };
      }
      return {
        content: [{ type: "text", text: JSON.stringify(transactions, null, 2) }],
        structuredContent: { transactions },
      };
    }
  );

  server.registerTool(
    "plaid_reconcile_transaction",
    {
      title: "Reconcile a Real Transaction to a Budget Category",
      description: `Matches one real bank transaction to a fake-budget category. This deducts the
transaction amount from that category's "spent" total and marks the transaction as reconciled
so it won't show up in plaid_get_uncategorized_transactions again.

This is the ONLY way real Plaid data affects the budget — it never touches the actual bank
account, it only updates your own ledger.

Args:
  - transactionId: the Plaid transaction id (from plaid_get_uncategorized_transactions)
  - categoryId: the budget category id to charge it against (from budget_list_categories)

Confirm the match with the user before calling this if the mapping isn't obvious from
the merchant name.`,
      inputSchema: {
        transactionId: z.string().min(1),
        categoryId: z.string().uuid(),
      },
      annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false },
    },
    async ({ transactionId, categoryId }) => {
      const result = await reconcileTransaction(transactionId, categoryId);
      return { content: [{ type: "text", text: result.message }], structuredContent: result };
    }
  );

  server.registerTool(
    "budget_get_vs_actual",
    {
      title: "Compare Budget vs Real Spending",
      description: `For each category, compares the planned allocation, the fake-ledger spent total
(manual expenses + reconciled transactions), and the real reconciled spend from Plaid.
Use this for "how am I doing on my budget this month" style questions.

Returns: array of { categoryName, allocatedDollars, budgetSpentDollars, realSpentDollars, remainingDollars }`,
      inputSchema: {},
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    },
    async () => {
      const rows = await getBudgetVsActual();
      return { content: [{ type: "text", text: JSON.stringify(rows, null, 2) }], structuredContent: { rows } };
    }
  );
}
