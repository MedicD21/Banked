import { createCategory } from "../src/budget/ledger.js";

/**
 * Creates a handful of sample budget categories for local testing before
 * any Plaid account is linked. Safe to re-run — createCategory rejects
 * duplicate names rather than creating a second copy.
 */
const SAMPLE_CATEGORIES: Array<{ name: string; allocatedDollars: number; period: "monthly" | "weekly" | "custom" }> = [
  { name: "Groceries", allocatedDollars: 500, period: "monthly" },
  { name: "Dining Out", allocatedDollars: 150, period: "monthly" },
  { name: "Entertainment", allocatedDollars: 75, period: "monthly" },
  { name: "Transportation", allocatedDollars: 120, period: "monthly" },
];

async function seed(): Promise<void> {
  if (!process.env.DATABASE_URL) {
    console.error("DATABASE_URL is not set. Export it before running this script.");
    process.exit(1);
  }

  for (const category of SAMPLE_CATEGORIES) {
    try {
      const created = await createCategory(category.name, category.allocatedDollars, category.period);
      console.log(`Created '${created.name}' — $${created.allocatedDollars} (${created.period})`);
    } catch (err) {
      console.log(`Skipped '${category.name}': ${err instanceof Error ? err.message : "unknown error"}`);
    }
  }

  console.log("Seed complete.");
}

seed().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
