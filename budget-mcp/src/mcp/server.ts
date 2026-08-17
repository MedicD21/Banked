import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { registerBudgetTools } from "./tools/budget-tools.js";
import { registerPlaidTools } from "./tools/plaid-tools.js";

export function createBudgetMcpServer(): McpServer {
  const server = new McpServer({
    name: "budget-mcp-server",
    version: "1.0.0",
  });

  registerBudgetTools(server);
  registerPlaidTools(server);

  return server;
}
