import { getSql, toDollars } from "../db/client.js";

export interface UncategorizedTransaction {
  transactionId: string;
  date: string;
  merchantName: string | null;
  name: string;
  plaidCategory: string | null;
  amountDollars: number;
}

export interface BudgetVsActualRow {
  categoryId: string;
  categoryName: string;
  allocatedDollars: number;
  budgetSpentDollars: number;   // from the fake ledger (manual logs + reconciliations)
  realSpentDollars: number;     // from reconciled Plaid transactions only
  remainingDollars: number;
}

/** Real bank transactions not yet matched to a budget category. Plaid convention: positive amount = money out. */
export async function getUncategorizedTransactions(limit = 25): Promise<UncategorizedTransaction[]> {
  const sql = getSql();
  const rows = await sql`
    select transaction_id, date, merchant_name, name, category, amount_cents
    from plaid_transactions
    where reconciled = false and pending = false and amount_cents > 0
    order by date desc
    limit ${limit}
  `;

  return rows.map((r) => ({
    transactionId: r.transaction_id as string,
    date: r.date as string,
    merchantName: r.merchant_name as string | null,
    name: r.name as string,
    plaidCategory: r.category as string | null,
    amountDollars: toDollars(r.amount_cents as number),
  }));
}

/**
 * Matches one real transaction to a budget category: marks it reconciled and
 * writes a 'reconciliation' ledger entry that deducts from that category's
 * fake budget. This is the only place real Plaid data touches the fake ledger,
 * and it never touches the real account — read-only in, ledger-only out.
 */
export async function reconcileTransaction(
  transactionId: string,
  categoryId: string
): Promise<{ success: boolean; message: string }> {
  const sql = getSql();

  const txnRows = await sql`
    select id, amount_cents, reconciled, name from plaid_transactions where transaction_id = ${transactionId}
  `;
  const txn = txnRows[0];
  if (!txn) {
    return { success: false, message: `No transaction found with id '${transactionId}'.` };
  }
  if (txn.reconciled) {
    return { success: false, message: `Transaction '${transactionId}' is already reconciled.` };
  }

  const categoryRows = await sql`select id, name, is_archived from budget_categories where id = ${categoryId}`;
  if (!categoryRows[0]) {
    return { success: false, message: `No budget category found with id '${categoryId}'.` };
  }
  if (categoryRows[0].is_archived) {
    return { success: false, message: `${categoryRows[0].name} is archived — unarchive it before reconciling against it.` };
  }

  const amountCents = txn.amount_cents as number; // positive = money out

  // Atomically claim the transaction first (guards against a concurrent
  // reconcile of the same transaction landing twice) before writing the
  // ledger/category side effects.
  const claimed = await sql`
    update plaid_transactions
    set reconciled = true, reconciled_category_id = ${categoryId}
    where transaction_id = ${transactionId} and reconciled = false
    returning id
  `;
  if (!claimed[0]) {
    return { success: false, message: `Transaction '${transactionId}' is already reconciled.` };
  }

  await sql.transaction((tx) => [
    tx`
      insert into budget_ledger_entries (category_id, entry_type, amount_cents, memo, plaid_transaction_id)
      values (${categoryId}, 'reconciliation', ${-amountCents}, ${`Reconciled: ${txn.name}`}, ${transactionId})
    `,
    tx`
      update budget_categories
      set spent_cents = spent_cents + ${amountCents}, updated_at = now()
      where id = ${categoryId}
    `,
  ]);

  return {
    success: true,
    message: `Reconciled '${txn.name}' (${toDollars(amountCents)}) against ${categoryRows[0].name}.`,
  };
}

/** Compares planned budget vs. fake-ledger spend vs. real reconciled spend, per category. */
export async function getBudgetVsActual(): Promise<BudgetVsActualRow[]> {
  const sql = getSql();

  const rows = await sql`
    select
      bc.id as category_id,
      bc.name as category_name,
      bc.allocated_cents,
      bc.spent_cents,
      coalesce(sum(case when pt.reconciled then pt.amount_cents else 0 end), 0) as real_spent_cents
    from budget_categories bc
    left join plaid_transactions pt on pt.reconciled_category_id = bc.id
    where bc.is_archived = false
    group by bc.id, bc.name, bc.allocated_cents, bc.spent_cents
    order by bc.name
  `;

  return rows.map((r) => {
    const allocated = toDollars(r.allocated_cents as number);
    const spent = toDollars(r.spent_cents as number);
    return {
      categoryId: r.category_id as string,
      categoryName: r.category_name as string,
      allocatedDollars: allocated,
      budgetSpentDollars: spent,
      realSpentDollars: toDollars(r.real_spent_cents as number),
      remainingDollars: Math.round((allocated - spent) * 100) / 100,
    };
  });
}
