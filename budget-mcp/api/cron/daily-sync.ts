import type { VercelRequest, VercelResponse } from "@vercel/node";
import { runDailySync } from "../../src/plaid/sync.js";

/**
 * Triggered once per day by Vercel Cron (see vercel.json). Vercel signs cron
 * requests with a bearer token matching CRON_SECRET when configured — verify
 * it here so this endpoint can't be hit by anyone else to burn Plaid API calls.
 */
export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  const expected = process.env.CRON_SECRET;
  const authHeader = req.headers["authorization"];

  if (!expected || authHeader !== `Bearer ${expected}`) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  try {
    const results = await runDailySync();
    const hadErrors = results.some((r) => r.error);
    res.status(hadErrors ? 207 : 200).json({ ranAt: new Date().toISOString(), results });
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : "Unknown error during sync" });
  }
}
