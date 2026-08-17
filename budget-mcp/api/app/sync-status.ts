import type { VercelRequest, VercelResponse } from "@vercel/node";
import { isAppAuthorized, rejectUnauthorized } from "../../src/http/appAuth.js";
import { getSyncStatus } from "../../src/plaid/status.js";

/** Last-sync status per linked institution — the iOS app's Settings screen. */
export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  if (!isAppAuthorized(req)) {
    rejectUnauthorized(res);
    return;
  }

  if (req.method !== "GET") {
    res.status(405).json({ error: "Method not allowed. Use GET." });
    return;
  }

  const items = await getSyncStatus();
  res.status(200).json({ items });
}
