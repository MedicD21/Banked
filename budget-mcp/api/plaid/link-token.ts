import type { VercelRequest, VercelResponse } from "@vercel/node";
import { createLinkToken } from "../../src/plaid/client.js";

/**
 * Called by the custom iOS app (not by Claude) to kick off Plaid Link.
 * Gated with the same app-level token used for the MCP endpoint's convenience,
 * but treat this as a separate credential in production if the app ships to
 * more than one device/user.
 */
export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  const expected = process.env.APP_API_TOKEN;
  const authHeader = req.headers["authorization"];
  if (!expected || authHeader !== `Bearer ${expected}`) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    const userId = process.env.SINGLE_USER_ID ?? "default-user";
    const linkToken = await createLinkToken(userId);
    res.status(200).json({ linkToken });
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : "Failed to create link token" });
  }
}
