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
let cachedClientEnv: string | undefined;

export function getPlaidClient(): PlaidApi {
  const plaidEnv = (process.env.PLAID_ENV ?? "sandbox") as keyof typeof PlaidEnvironments;

  // Rebuild if PLAID_ENV changed since the last call (e.g. between test runs) —
  // otherwise a cached sandbox client would silently keep serving production code paths.
  if (cachedClient && cachedClientEnv === plaidEnv) return cachedClient;

  // Plaid issues a distinct secret per environment; PLAID_SECRET is the
  // sandbox/development secret, PLAID_PROD_SECRET is the production one.
  const secret = plaidEnv === "production" ? getEnv("PLAID_PROD_SECRET") : getEnv("PLAID_SECRET");

  const configuration = new Configuration({
    basePath: PlaidEnvironments[plaidEnv],
    baseOptions: {
      headers: {
        "PLAID-CLIENT-ID": getEnv("PLAID_CLIENT_ID"),
        "PLAID-SECRET": secret,
      },
    },
  });

  cachedClient = new PlaidApi(configuration);
  cachedClientEnv = plaidEnv;
  return cachedClient;
}

/** Create a Link token for the one-time account-linking flow (used by your iOS app, not by Claude). */
export async function createLinkToken(userId: string): Promise<string> {
  const client = getPlaidClient();
  // Many real institutions (Chase, Bank of America, Wells Fargo, etc.) require
  // the OAuth flow, which needs a redirect_uri that exactly matches one
  // registered in the Plaid Dashboard under Team Settings > API > Allowed
  // redirect URIs. Sandbox test institutions don't need this.
  const redirectUri = process.env.PLAID_REDIRECT_URI;
  const response = await client.linkTokenCreate({
    user: { client_user_id: userId },
    client_name: "Budget MCP",
    products: [Products.Transactions],
    country_codes: [CountryCode.Us],
    language: "en",
    ...(redirectUri ? { redirect_uri: redirectUri } : {}),
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
