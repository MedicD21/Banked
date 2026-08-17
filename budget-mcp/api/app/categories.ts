import type { VercelRequest, VercelResponse } from "@vercel/node";
import { isAppAuthorized, rejectUnauthorized } from "../../src/http/appAuth.js";
import { listCategories } from "../../src/budget/ledger.js";

/** Read-only category list for the iOS app's Budget Overview screen. */
export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  if (!isAppAuthorized(req)) {
    rejectUnauthorized(res);
    return;
  }

  if (req.method !== "GET") {
    res.status(405).json({ error: "Method not allowed. Use GET." });
    return;
  }

  const includeArchived = req.query.includeArchived === "true";
  const categories = await listCategories(includeArchived);
  res.status(200).json({ categories });
}
