import type { VercelRequest, VercelResponse } from "@vercel/node";

/** Shared bearer-token gate for every `api/app/*` route the iOS app calls. */
export function isAppAuthorized(req: VercelRequest): boolean {
  const expected = process.env.APP_API_TOKEN;
  if (!expected) return false; // fail closed if misconfigured
  const header = req.headers["authorization"];
  return header === `Bearer ${expected}`;
}

export function rejectUnauthorized(res: VercelResponse): void {
  res.status(401).json({ error: "Unauthorized" });
}
