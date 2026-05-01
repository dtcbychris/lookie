// Tiny request/response helpers usable from both Vercel handlers and a
// vanilla Node http server (which is what Vite middleware gives us).

import type { IncomingMessage, ServerResponse } from "node:http";

export type Req = IncomingMessage & { body?: unknown };
export type Res = ServerResponse;

export async function readJsonBody(req: Req): Promise<unknown> {
  if (req.body && typeof req.body === "object") {
    // Vercel auto-parses JSON when Content-Type is application/json.
    return req.body;
  }
  return new Promise((resolve, reject) => {
    let data = "";
    req.setEncoding("utf8");
    req.on("data", (chunk: string) => {
      data += chunk;
      // Cap at ~25 MB to avoid abuse; screenshots are usually <10 MB base64.
      if (data.length > 25 * 1024 * 1024) {
        req.destroy();
        reject(new Error("Request body too large."));
      }
    });
    req.on("end", () => {
      if (!data) return resolve({});
      try {
        resolve(JSON.parse(data));
      } catch {
        reject(new Error("Request body was not valid JSON."));
      }
    });
    req.on("error", reject);
  });
}

export function sendJson(res: Res, status: number, body: unknown): void {
  if (res.headersSent) return;
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.end(JSON.stringify(body));
}
