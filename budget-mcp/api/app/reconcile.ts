import type { VercelRequest, VercelResponse } from "@vercel/node";
import { z } from "zod";
import { isAppAuthorized, rejectUnauthorized } from "../../src/http/appAuth.js";
import { reconcileTransaction } from "../../src/reconcile/reconcile.js";

const BodySchema = z.object({
  transactionId: z.string().min(1),
  categoryId: z.string().uuid(),
});

/**
 * The iOS app's Reconcile screen hits this — same underlying logic the
 * `plaid_reconcile_transaction` MCP tool uses. This stays the only bridge
 * between real Plaid data and the fake budget ledger, per the backend guardrail.
 */
export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  if (!isAppAuthorized(req)) {
    rejectUnauthorized(res);
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed. Use POST." });
    return;
  }

  const parsed = BodySchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Missing or invalid transactionId/categoryId", details: parsed.error.flatten() });
    return;
  }

  const result = await reconcileTransaction(parsed.data.transactionId, parsed.data.categoryId);
  res.status(result.success ? 200 : 400).json(result);
}
