import { getPlaidClient } from "./client.js";
import { getSql } from "../db/client.js";
import { decryptSecret } from "../security/crypto.js";

export interface SyncResult {
  itemId: string;
  institutionName: string | null;
  accountsUpdated: number;
  transactionsAdded: number;
  transactionsModified: number;
  transactionsRemoved: number;
  error?: string;
}

/**
 * Syncs balances + transactions for every active Plaid item.
 * Intended to be called once per day from the Vercel cron function —
 * there is deliberately no manually-triggerable "sync now" path exposed
 * to Claude, to stay well inside Plaid's rate limits.
 */
export async function runDailySync(): Promise<SyncResult[]> {
  const sql = getSql();
  const client = getPlaidClient();

  const items = await sql`
    select id, item_id, access_token, institution_name
    from plaid_items
    where status = 'active'
  `;

  const results: SyncResult[] = [];

  for (const item of items) {
    const result: SyncResult = {
      itemId: item.item_id as string,
      institutionName: item.institution_name as string | null,
      accountsUpdated: 0,
      transactionsAdded: 0,
      transactionsModified: 0,
      transactionsRemoved: 0,
    };

    try {
      const accessToken = decryptSecret(item.access_token as string);

      // 1. Balances
      const balanceResponse = await client.accountsBalanceGet({
        access_token: accessToken,
      });

      for (const account of balanceResponse.data.accounts) {
        await sql`
          insert into plaid_accounts (
            plaid_item_id, account_id, name, official_name, type, subtype,
            mask, current_balance_cents, available_balance_cents, currency, updated_at
          ) values (
            ${item.id}, ${account.account_id}, ${account.name}, ${account.official_name ?? null},
            ${account.type}, ${account.subtype ?? null}, ${account.mask ?? null},
            ${Math.round((account.balances.current ?? 0) * 100)},
            ${account.balances.available !== null && account.balances.available !== undefined
              ? Math.round(account.balances.available * 100)
              : null},
            ${account.balances.iso_currency_code ?? "USD"}, now()
          )
          on conflict (account_id) do update set
            current_balance_cents = excluded.current_balance_cents,
            available_balance_cents = excluded.available_balance_cents,
            updated_at = now()
        `;
        result.accountsUpdated += 1;
      }

      // 2. Incremental transactions via /transactions/sync
      const cursorRow = await sql`
        select cursor from plaid_sync_cursors where plaid_item_id = ${item.id}
      `;
      let cursor: string | undefined = cursorRow[0]?.cursor ?? undefined;
      let hasMore = true;

      while (hasMore) {
        const syncResponse = await client.transactionsSync({
          access_token: accessToken,
          cursor,
        });

        for (const txn of syncResponse.data.added) {
          const accountRow = await sql`
            select id from plaid_accounts where account_id = ${txn.account_id}
          `;
          if (!accountRow[0]) continue;

          await sql`
            insert into plaid_transactions (
              plaid_account_id, transaction_id, amount_cents, merchant_name,
              name, category, pending, date
            ) values (
              ${accountRow[0].id}, ${txn.transaction_id}, ${Math.round(txn.amount * 100)},
              ${txn.merchant_name ?? null}, ${txn.name}, ${txn.personal_finance_category?.primary ?? null},
              ${txn.pending}, ${txn.date}
            )
            on conflict (transaction_id) do nothing
          `;
          result.transactionsAdded += 1;
        }

        for (const txn of syncResponse.data.modified) {
          await sql`
            update plaid_transactions set
              amount_cents = ${Math.round(txn.amount * 100)},
              merchant_name = ${txn.merchant_name ?? null},
              name = ${txn.name},
              pending = ${txn.pending}
            where transaction_id = ${txn.transaction_id}
          `;
          result.transactionsModified += 1;
        }

        for (const removed of syncResponse.data.removed) {
          if (!removed.transaction_id) continue;
          await sql`delete from plaid_transactions where transaction_id = ${removed.transaction_id}`;
          result.transactionsRemoved += 1;
        }

        cursor = syncResponse.data.next_cursor;
        hasMore = syncResponse.data.has_more;
      }

      await sql`
        insert into plaid_sync_cursors (plaid_item_id, cursor, updated_at)
        values (${item.id}, ${cursor}, now())
        on conflict (plaid_item_id) do update set cursor = excluded.cursor, updated_at = now()
      `;

      await sql`update plaid_items set last_synced_at = now(), status = 'active' where id = ${item.id}`;
    } catch (err) {
      result.error = err instanceof Error ? err.message : "Unknown sync error";
      await sql`update plaid_items set status = 'error' where id = ${item.id}`;
    }

    results.push(result);
  }

  return results;
}
