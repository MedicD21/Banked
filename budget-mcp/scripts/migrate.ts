import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { neon } from "@neondatabase/serverless";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function migrate(): Promise<void> {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error("DATABASE_URL is not set. Export it or add it to your shell env before running this script.");
    process.exit(1);
  }

  const sql = neon(connectionString);
  const schemaPath = path.join(__dirname, "..", "db", "schema.sql");
  const schema = readFileSync(schemaPath, "utf-8");

  // Strip full-line comments first, so a comment block preceding a statement
  // (with no semicolon of its own) doesn't get glued onto that statement's
  // chunk and cause the whole thing to be mistaken for a comment-only chunk.
  const withoutCommentLines = schema
    .split("\n")
    .filter((line) => !line.trim().startsWith("--"))
    .join("\n");

  // Neon's HTTP driver executes one statement per call, so split on semicolons
  // that end a statement. Good enough for this schema file (no semicolons
  // inside string literals or function bodies).
  const statements = withoutCommentLines
    .split(";")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);

  for (const statement of statements) {
    console.log(`Running: ${statement.slice(0, 60).replace(/\s+/g, " ")}...`);
    await sql(statement);
  }

  console.log(`Applied ${statements.length} statements successfully.`);
}

migrate().catch((err) => {
  console.error("Migration failed:", err);
  process.exit(1);
});
