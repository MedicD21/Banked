import type { VercelRequest, VercelResponse } from "@vercel/node";
import { z } from "zod";
import { exchangePublicToken, getPlaidClient } from "../../src/plaid/client.js";
import { getSql } from "../../src/db/client.js";
import { encryptSecret } from "../../src/security/crypto.js";

const BodySchema = z.object({
  publicToken: z.string().min(1),
});

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

  const parsed = BodySchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Missing or invalid publicToken", details: parsed.error.flatten() });
    return;
  }

  try {
    const { accessToken, itemId } = await exchangePublicToken(parsed.data.publicToken);

    const client = getPlaidClient();
    const itemResponse = await client.itemGet({ access_token: accessToken });
    const institutionName = itemResponse.data.item.institution_id ?? null;

    const encryptedAccessToken = encryptSecret(accessToken);

    const sql = getSql();
    await sql`
      insert into plaid_items (item_id, access_token, institution_name, status)
      values (${itemId}, ${encryptedAccessToken}, ${institutionName}, 'active')
      on conflict (item_id) do update set access_token = excluded.access_token, status = 'active'
    `;

    res.status(200).json({ success: true, itemId });
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : "Failed to exchange token" });
  }
}
