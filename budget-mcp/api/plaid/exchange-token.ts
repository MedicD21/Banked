import type { VercelRequest, VercelResponse } from "@vercel/node";
import { z } from "zod";
import { CountryCode } from "plaid";
import { exchangePublicToken, getPlaidClient } from "../../src/plaid/client.js";
import { getSql } from "../../src/db/client.js";
import { encryptSecret } from "../../src/security/crypto.js";
import { syncItem } from "../../src/plaid/sync.js";

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
    const institutionId = itemResponse.data.item.institution_id ?? null;

    let institutionName = institutionId;
    if (institutionId) {
      try {
        const institutionResponse = await client.institutionsGetById({
          institution_id: institutionId,
          country_codes: [CountryCode.Us],
        });
        institutionName = institutionResponse.data.institution.name;
      } catch {
        // Fall back to the raw institution_id if the lookup fails — still
        // usable, just less friendly.
      }
    }

    const encryptedAccessToken = encryptSecret(accessToken);

    const sql = getSql();
    const [item] = await sql`
      insert into plaid_items (item_id, access_token, institution_name, status)
      values (${itemId}, ${encryptedAccessToken}, ${institutionName}, 'active')
      on conflict (item_id) do update set access_token = excluded.access_token, status = 'active'
      returning id, item_id, access_token, institution_name
    `;

    // Pull balances + transaction history immediately rather than waiting for
    // the next daily cron run, so a freshly linked account isn't empty in the app.
    const syncResult = await syncItem({
      id: item.id as string,
      item_id: item.item_id as string,
      access_token: item.access_token as string,
      institution_name: item.institution_name as string | null,
    });

    res.status(200).json({ success: true, itemId, sync: syncResult });
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : "Failed to exchange token" });
  }
}
