import { analyzeWithOpenAI, ProviderError } from "./_lib/openai";
import { readJsonBody, sendJson, type Req, type Res } from "./_lib/http";
import type { AnalyzeRequest } from "./_lib/types";

export default async function handler(req: Req, res: Res): Promise<void> {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    sendJson(res, 405, { error: "Method not allowed." });
    return;
  }

  let body: unknown;
  try {
    body = await readJsonBody(req);
  } catch (err) {
    sendJson(res, 400, {
      error: err instanceof Error ? err.message : "Invalid request body.",
    });
    return;
  }

  const parsed = parseAnalyzeRequest(body);
  if ("error" in parsed) {
    sendJson(res, 400, { error: parsed.error });
    return;
  }

  const provider = (process.env.AI_PROVIDER || "openai").toLowerCase();
  try {
    if (provider === "openai") {
      const result = await analyzeWithOpenAI(parsed.value);
      sendJson(res, 200, result);
      return;
    }
    sendJson(res, 400, {
      error: `Unsupported provider "${provider}". Set AI_PROVIDER=openai.`,
    });
  } catch (err) {
    if (err instanceof ProviderError) {
      sendJson(res, err.status, { error: err.message });
      return;
    }
    console.error("[/api/analyze] unexpected error", err);
    sendJson(res, 500, { error: "Internal server error." });
  }
}

type ParseResult =
  | { value: AnalyzeRequest }
  | { error: string };

function parseAnalyzeRequest(body: unknown): ParseResult {
  if (!body || typeof body !== "object") {
    return { error: "Request body must be a JSON object." };
  }
  const b = body as Record<string, unknown>;

  if (typeof b.imageBase64 !== "string" || b.imageBase64.length === 0) {
    return { error: "Missing or invalid 'imageBase64'." };
  }
  // Basic sanity: base64 chars only (allow padding). Strip data URL prefix if present.
  let imageBase64 = b.imageBase64;
  if (imageBase64.startsWith("data:")) {
    const idx = imageBase64.indexOf(",");
    if (idx >= 0) imageBase64 = imageBase64.slice(idx + 1);
  }
  if (!/^[A-Za-z0-9+/=\s]+$/.test(imageBase64)) {
    return { error: "'imageBase64' is not valid base64." };
  }

  const question = typeof b.question === "string" ? b.question : "";
  const projectContext =
    typeof b.projectContext === "string" ? b.projectContext : undefined;
  const projectBrain =
    typeof b.projectBrain === "string" ? b.projectBrain : undefined;
  const recentHistoryContext =
    typeof b.recentHistoryContext === "string"
      ? b.recentHistoryContext
      : undefined;

  return {
    value: {
      imageBase64,
      question,
      projectContext,
      projectBrain,
      recentHistoryContext,
    },
  };
}
