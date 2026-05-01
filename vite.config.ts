import { defineConfig, loadEnv, type Plugin } from "vite";
import react from "@vitejs/plugin-react";
import type { IncomingMessage, ServerResponse } from "node:http";

// Mounts api/*.ts files as serverless-style handlers during `vite dev`,
// matching how Vercel will host them in production. We only wire the
// routes we actually have.
function devApiPlugin(): Plugin {
  const routes = [{ url: "/api/analyze", module: "/api/analyze.ts" }];
  return {
    name: "dev-api-routes",
    apply: "serve",
    configureServer(server) {
      for (const { url, module } of routes) {
        server.middlewares.use(
          url,
          async (req: IncomingMessage, res: ServerResponse) => {
            try {
              const mod = await server.ssrLoadModule(module);
              const handler = mod.default as (
                req: IncomingMessage,
                res: ServerResponse,
              ) => Promise<void> | void;
              await handler(req, res);
            } catch (err) {
              server.config.logger.error(
                `[dev-api-routes] ${url} crashed: ${
                  err instanceof Error ? err.stack : String(err)
                }`,
              );
              if (!res.headersSent) {
                res.statusCode = 500;
                res.setHeader("Content-Type", "application/json");
                res.end(
                  JSON.stringify({ error: "Internal server error (dev)." }),
                );
              }
            }
          },
        );
      }
    },
  };
}

export default defineConfig(({ mode }) => {
  // Make non-VITE_ env vars (OPENAI_API_KEY, AI_PROVIDER, OPENAI_MODEL) visible
  // to the dev API handlers via process.env, mirroring Vercel's runtime.
  const env = loadEnv(mode, process.cwd(), "");
  for (const [key, value] of Object.entries(env)) {
    if (process.env[key] === undefined) process.env[key] = value;
  }
  return {
    plugins: [react(), devApiPlugin()],
    server: { port: 5173 },
  };
});
