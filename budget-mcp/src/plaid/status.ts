import { getSql } from "../db/client.js";

export interface PlaidItemStatus {
  institutionName: string | null;
  status: string;
  lastSyncedAt: string | null;
}

/** Last-sync status per linked Plaid item. Shared by the MCP tool and the iOS app's Settings screen. */
export async function getSyncStatus(): Promise<PlaidItemStatus[]> {
  const sql = getSql();
  const rows = await sql`
    select institution_name, status, last_synced_at from plaid_items order by institution_name
  `;
  return rows.map((r) => ({
    institutionName: r.institution_name as string | null,
    status: r.status as string,
    lastSyncedAt: r.last_synced_at as string | null,
  }));
}
