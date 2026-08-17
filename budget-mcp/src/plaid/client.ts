import { Configuration, PlaidApi, PlaidEnvironments, Products, CountryCode } from "plaid";

/**
 * This app only ever calls Plaid's read endpoints:
 *   - /link/token/create + /item/public_token/exchange  (one-time linking)
 *   - /accounts/balance/get                              (balances)
 *   - /transactions/sync                                 (incremental transactions)
 *
 * No transfer, payment, or auth (ACH) products are requested or wired up.
 * Nothing in this codebase should ever call a Plaid write/transfer endpoint —
 * if you find yourself importing TransferCreateRequest or similar, stop.
 */

function getEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set in the environment.`);
  return value;
}

let cachedClient: PlaidApi | undefined;

export function getPlaidClient(): PlaidApi {
  if (cachedClient) return cachedClient;

  const plaidEnv = (process.env.PLAID_ENV ?? "sandbox") as keyof typeof PlaidEnvironments;

  const configuration = new Configuration({
    basePath: PlaidEnvironments[plaidEnv],
    baseOptions: {
      headers: {
        "PLAID-CLIENT-ID": getEnv("PLAID_CLIENT_ID"),
        "PLAID-SECRET": getEnv("PLAID_SECRET"),
      },
    },
  });

  cachedClient = new PlaidApi(configuration);
  return cachedClient;
}

/** Create a Link token for the one-time account-linking flow (used by your iOS app, not by Claude). */
export async function createLinkToken(userId: string): Promise<string> {
  const client = getPlaidClient();
  const response = await client.linkTokenCreate({
    user: { client_user_id: userId },
    client_name: "Budget MCP",
    products: [Products.Transactions],
    country_codes: [CountryCode.Us],
    language: "en",
  });
  return response.data.link_token;
}

/** Exchange a public_token (from Plaid Link) for a permanent access_token + item_id. */
export async function exchangePublicToken(
  publicToken: string
): Promise<{ accessToken: string; itemId: string }> {
  const client = getPlaidClient();
  const response = await client.itemPublicTokenExchange({ public_token: publicToken });
  return { accessToken: response.data.access_token, itemId: response.data.item_id };
}
