import type { VercelRequest, VercelResponse } from "@vercel/node";
import { isAppAuthorized, rejectUnauthorized } from "../../../../src/http/appAuth.js";
import { getLedgerEntries } from "../../../../src/budget/ledger.js";

/** Ledger history for one category — the iOS app's Category Detail screen. */
export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  if (!isAppAuthorized(req)) {
    rejectUnauthorized(res);
    return;
  }

  if (req.method !== "GET") {
    res.status(405).json({ error: "Method not allowed. Use GET." });
    return;
  }

  const { id } = req.query;
  if (typeof id !== "string" || id.length === 0) {
    res.status(400).json({ error: "Missing category id." });
    return;
  }

  const entries = await getLedgerEntries(id);
  res.status(200).json({ entries });
}
