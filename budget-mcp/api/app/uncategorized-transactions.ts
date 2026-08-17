import type { VercelRequest, VercelResponse } from "@vercel/node";
import { isAppAuthorized, rejectUnauthorized } from "../../src/http/appAuth.js";
import { getUncategorizedTransactions } from "../../src/reconcile/reconcile.js";

/** Real transactions awaiting reconciliation — the iOS app's Reconcile screen. */
export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  if (!isAppAuthorized(req)) {
    rejectUnauthorized(res);
    return;
  }

  if (req.method !== "GET") {
    res.status(405).json({ error: "Method not allowed. Use GET." });
    return;
  }

  const limitParam = Array.isArray(req.query.limit) ? req.query.limit[0] : req.query.limit;
  const parsedLimit = limitParam ? parseInt(limitParam, 10) : 25;
  const limit = Number.isFinite(parsedLimit) ? Math.min(Math.max(parsedLimit, 1), 100) : 25;

  const transactions = await getUncategorizedTransactions(limit);
  res.status(200).json({ transactions });
}
