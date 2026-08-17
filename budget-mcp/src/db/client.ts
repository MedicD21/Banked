import { neon, type NeonQueryFunction } from "@neondatabase/serverless";

/**
 * Single shared SQL tag for the whole app. The Neon serverless driver is
 * HTTP-based, so it's safe to call from short-lived Vercel functions without
 * connection-pool exhaustion concerns.
 *
 * Requires DATABASE_URL to be set (Neon connection string, pooled endpoint).
 */
let cachedSql: NeonQueryFunction<false, false> | undefined;

export function getSql(): NeonQueryFunction<false, false> {
  if (cachedSql) return cachedSql;

  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error(
      "DATABASE_URL is not set. Add your Neon connection string to the environment."
    );
  }

  cachedSql = neon(connectionString);
  return cachedSql;
}

/** Convert a dollar amount (e.g. from user input) to integer cents. */
export function toCents(dollars: number): number {
  return Math.round(dollars * 100);
}

/** Convert integer cents back to a dollar amount for display. */
export function toDollars(cents: number): number {
  return Math.round(cents) / 100;
}
