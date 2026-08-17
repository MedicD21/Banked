import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { listCategories, createCategory, moveFunds, logExpense } from "../../budget/ledger.js";

export function registerBudgetTools(server: McpServer): void {
  server.registerTool(
    "budget_list_categories",
    {
      title: "List Budget Categories",
      description: `Lists all active budget categories with allocated, spent, and remaining amounts.

This is a fake/planning budget — no real money moves. Use this before any transfer or expense
so you have current category IDs and balances.

Returns: array of { id, name, allocatedDollars, spentDollars, remainingDollars, period }`,
      inputSchema: {
        includeArchived: z.boolean().default(false).describe("Include archived categories"),
      },
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    },
    async ({ includeArchived }) => {
      const categories = await listCategories(includeArchived);
      return {
        content: [{ type: "text", text: JSON.stringify(categories, null, 2) }],
        structuredContent: { categories },
      };
    }
  );

  server.registerTool(
    "budget_create_category",
    {
      title: "Create Budget Category",
      description: `Creates a new budget category with an initial allocation.

Args:
  - name: category name (e.g. "Groceries")
  - allocatedDollars: planned amount for the period, in dollars (e.g. 400.00)
  - period: 'monthly' | 'weekly' | 'custom' (default: monthly)

Don't use this to log a one-off expense — use budget_log_expense for that instead.`,
      inputSchema: {
        name: z.string().min(1).max(100),
        allocatedDollars: z.number().nonnegative(),
        period: z.enum(["monthly", "weekly", "custom"]).default("monthly"),
      },
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false },
    },
    async ({ name, allocatedDollars, period }) => {
      const category = await createCategory(name, allocatedDollars, period);
      return {
        content: [{ type: "text", text: `Created category '${category.name}' with $${category.allocatedDollars} allocated.` }],
        structuredContent: { category },
      };
    }
  );

  server.registerTool(
    "budget_move_funds",
    {
      title: "Move Funds Between Categories",
      description: `Moves a "fake money" amount from one budget category's allocation to another.

This only edits your own budget ledger — it never touches a real bank account. Use this when
the user asks to reallocate budget, e.g. "move $50 from Entertainment to Groceries".

Args:
  - fromCategoryId: category id to take funds from (use budget_list_categories to find ids)
  - toCategoryId: category id to add funds to
  - amountDollars: amount to move, in dollars
  - memo: optional note about why the transfer happened

Fails if the source category doesn't have enough allocated to cover the move.`,
      inputSchema: {
        fromCategoryId: z.string().uuid(),
        toCategoryId: z.string().uuid(),
        amountDollars: z.number().positive(),
        memo: z.string().max(200).optional(),
      },
      annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false },
    },
    async ({ fromCategoryId, toCategoryId, amountDollars, memo }) => {
      const result = await moveFunds(fromCategoryId, toCategoryId, amountDollars, memo);
      return { content: [{ type: "text", text: result.message }], structuredContent: result };
    }
  );

  server.registerTool(
    "budget_log_expense",
    {
      title: "Log a Manual Expense",
      description: `Logs a manual expense against a budget category (for cash spending or anything
not covered by the automatic Plaid reconciliation). Increases the category's spent amount.

Args:
  - categoryId: category id to log against
  - amountDollars: expense amount in dollars
  - memo: optional description (e.g. "Farmers market cash")`,
      inputSchema: {
        categoryId: z.string().uuid(),
        amountDollars: z.number().positive(),
        memo: z.string().max(200).optional(),
      },
      annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false },
    },
    async ({ categoryId, amountDollars, memo }) => {
      const result = await logExpense(categoryId, amountDollars, memo);
      return { content: [{ type: "text", text: result.message }], structuredContent: result };
    }
  );
}
