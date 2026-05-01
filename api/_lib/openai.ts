import { SYSTEM_PROMPT, buildUserText, parseAnalysisJson } from "./prompt";
import type { AnalysisResponse, AnalyzeRequest } from "./types";

export class ProviderError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

const OPENAI_URL = "https://api.openai.com/v1/chat/completions";

export async function analyzeWithOpenAI(
  input: AnalyzeRequest,
): Promise<AnalysisResponse> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new ProviderError(
      "OPENAI_API_KEY is not set on the server.",
      500,
    );
  }

  const model = process.env.OPENAI_MODEL || "gpt-4o";

  const dataUrl = `data:image/png;base64,${input.imageBase64}`;
  const userText = buildUserText({
    question: input.question,
    projectContext: input.projectContext,
    projectBrain: input.projectBrain,
    recentHistoryContext: input.recentHistoryContext,
  });

  let res: Response;
  try {
    res = await fetch(OPENAI_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          {
            role: "user",
            content: [
              { type: "text", text: userText },
              { type: "image_url", image_url: { url: dataUrl, detail: "high" } },
            ],
          },
        ],
      }),
    });
  } catch (err) {
    throw new ProviderError(
      `Failed to reach OpenAI: ${err instanceof Error ? err.message : "network error"}`,
      502,
    );
  }

  if (!res.ok) {
    let detail = "";
    try {
      const errBody = await res.json();
      detail =
        (errBody?.error?.message as string | undefined) ??
        JSON.stringify(errBody);
    } catch {
      detail = await res.text().catch(() => "");
    }
    throw new ProviderError(
      `OpenAI API error (${res.status}): ${detail || "unknown error"}`,
      res.status === 401 || res.status === 403 ? 500 : 502,
    );
  }

  let body: any;
  try {
    body = await res.json();
  } catch {
    throw new ProviderError("OpenAI returned a non-JSON response.", 502);
  }

  const content: unknown = body?.choices?.[0]?.message?.content;
  if (typeof content !== "string" || content.length === 0) {
    throw new ProviderError("OpenAI response was empty.", 502);
  }

  try {
    return parseAnalysisJson(content);
  } catch (err) {
    throw new ProviderError(
      `Could not parse model output as AnalysisResponse: ${err instanceof Error ? err.message : "unknown"}`,
      502,
    );
  }
}
