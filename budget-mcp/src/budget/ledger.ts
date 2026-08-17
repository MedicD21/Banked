import { randomUUID } from "node:crypto";
import { getSql, toCents, toDollars } from "../db/client.js";

export interface BudgetCategory {
  id: string;
  name: string;
  allocatedDollars: number;
  spentDollars: number;
  remainingDollars: number;
  period: string;
}

export async function listCategories(includeArchived = false): Promise<BudgetCategory[]> {
  const sql = getSql();
  const rows = includeArchived
    ? await sql`select * from budget_categories order by name`
    : await sql`select * from budget_categories where is_archived = false order by name`;

  return rows.map((r) => ({
    id: r.id as string,
    name: r.name as string,
    allocatedDollars: toDollars(r.allocated_cents as number),
    spentDollars: toDollars(r.spent_cents as number),
    remainingDollars: toDollars((r.allocated_cents as number) - (r.spent_cents as number)),
    period: r.period as string,
  }));
}

export async function createCategory(
  name: string,
  allocatedDollars: number,
  period: "monthly" | "weekly" | "custom" = "monthly"
): Promise<BudgetCategory> {
  const sql = getSql();
  const cents = toCents(allocatedDollars);

  const existing = await sql`select id from budget_categories where name = ${name}`;
  if (existing[0]) {
    throw new Error(`A category named '${name}' already exists.`);
  }

  const [rows, _ledgerRows] = await sql.transaction((tx) => [
    tx`
      insert into budget_categories (name, allocated_cents, period)
      values (${name}, ${cents}, ${period})
      returning *
    `,
    tx`
      insert into budget_ledger_entries (category_id, entry_type, amount_cents, memo)
      select id, 'allocation', ${cents}, ${`Initial allocation for ${name}`}
      from budget_categories where name = ${name}
    `,
  ]);

  const r = rows[0];
  return {
    id: r.id as string,
    name: r.name as string,
    allocatedDollars: toDollars(r.allocated_cents as number),
    spentDollars: toDollars(r.spent_cents as number),
    remainingDollars: toDollars((r.allocated_cents as number) - (r.spent_cents as number)),
    period: r.period as string,
  };
}

/**
 * Moves "fake money" between two categories' allocations. Purely a bookkeeping
 * operation on your own ledger — nothing here touches a real account.
 */
export async function moveFunds(
  fromCategoryId: string,
  toCategoryId: string,
  amountDollars: number,
  memo?: string
): Promise<{ success: boolean; message: string }> {
  const sql = getSql();
  const cents = toCents(amountDollars);

  if (cents <= 0) {
    return { success: false, message: "Transfer amount must be greater than zero." };
  }
  if (fromCategoryId === toCategoryId) {
    return { success: false, message: "Source and destination categories must be different." };
  }

  const fromRows = await sql`select id, name, allocated_cents, is_archived from budget_categories where id = ${fromCategoryId}`;
  const toRows = await sql`select id, name, is_archived from budget_categories where id = ${toCategoryId}`;

  if (!fromRows[0]) return { success: false, message: `No category found with id '${fromCategoryId}'.` };
  if (!toRows[0]) return { success: false, message: `No category found with id '${toCategoryId}'.` };

  if (fromRows[0].is_archived) {
    return { success: false, message: `${fromRows[0].name} is archived — unarchive it before moving funds.` };
  }
  if (toRows[0].is_archived) {
    return { success: false, message: `${toRows[0].name} is archived — unarchive it before moving funds.` };
  }

  if ((fromRows[0].allocated_cents as number) < cents) {
    return {
      success: false,
      message: `${fromRows[0].name} only has ${toDollars(fromRows[0].allocated_cents as number)} allocated — can't move ${amountDollars}.`,
    };
  }

  const outEntryId = randomUUID();

  await sql.transaction((tx) => [
    tx`
      insert into budget_ledger_entries (id, category_id, entry_type, amount_cents, memo)
      values (${outEntryId}, ${fromCategoryId}, 'transfer_out', ${-cents}, ${memo ?? `Transfer to ${toRows[0].name}`})
    `,
    tx`
      insert into budget_ledger_entries (category_id, entry_type, amount_cents, memo, related_entry_id)
      values (${toCategoryId}, 'transfer_in', ${cents}, ${memo ?? `Transfer from ${fromRows[0].name}`}, ${outEntryId})
    `,
    tx`update budget_categories set allocated_cents = allocated_cents - ${cents}, updated_at = now() where id = ${fromCategoryId}`,
    tx`update budget_categories set allocated_cents = allocated_cents + ${cents}, updated_at = now() where id = ${toCategoryId}`,
  ]);

  return {
    success: true,
    message: `Moved $${amountDollars.toFixed(2)} from ${fromRows[0].name} to ${toRows[0].name}.`,
  };
}

/** Logs a manual (non-Plaid) expense against a category — for cash spending etc. */
export async function logExpense(
  categoryId: string,
  amountDollars: number,
  memo?: string
): Promise<{ success: boolean; message: string }> {
  const sql = getSql();
  const cents = toCents(amountDollars);

  if (cents <= 0) {
    return { success: false, message: "Expense amount must be greater than zero." };
  }

  const categoryRows = await sql`select id, name, is_archived from budget_categories where id = ${categoryId}`;
  if (!categoryRows[0]) {
    return { success: false, message: `No category found with id '${categoryId}'.` };
  }
  if (categoryRows[0].is_archived) {
    return { success: false, message: `${categoryRows[0].name} is archived — unarchive it before logging expenses.` };
  }

  await sql.transaction((tx) => [
    tx`
      insert into budget_ledger_entries (category_id, entry_type, amount_cents, memo)
      values (${categoryId}, 'expense', ${-cents}, ${memo ?? "Manual expense"})
    `,
    tx`update budget_categories set spent_cents = spent_cents + ${cents}, updated_at = now() where id = ${categoryId}`,
  ]);

  return { success: true, message: `Logged $${amountDollars.toFixed(2)} expense against ${categoryRows[0].name}.` };
}
