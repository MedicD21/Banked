import type { VercelRequest, VercelResponse } from "@vercel/node";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { createBudgetMcpServer } from "../src/mcp/server.js";

/**
 * This endpoint is publicly reachable (required for Claude's cloud infrastructure
 * to call it per Anthropic's remote-MCP architecture), so it's gated with a
 * static bearer token configured as the connector's auth header in Claude.
 * Rotate MCP_SERVER_TOKEN if it's ever exposed.
 */
function isAuthorized(req: VercelRequest): boolean {
  const expected = process.env.MCP_SERVER_TOKEN;
  if (!expected) return false; // fail closed if misconfigured
  const header = req.headers["authorization"];
  return header === `Bearer ${expected}`;
}

export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  if (!isAuthorized(req)) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed. Use POST for MCP requests." });
    return;
  }

  const server = createBudgetMcpServer();

  // Stateless transport: a new instance per request avoids request-id collisions
  // across concurrent invocations of this serverless function.
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
    enableJsonResponse: true,
  });

  res.on("close", () => {
    transport.close();
    server.close();
  });

  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
}
