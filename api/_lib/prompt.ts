import type { AnalysisResponse } from "./types";

export const SYSTEM_PROMPT = `You are a screen-aware product/build assistant helping a non-technical founder understand and improve what is visible in a screenshot.

Analyze the screenshot and answer the user's question directly.

Prioritize:
1. What the user should do next
2. Any visible UI, product, or implementation issues
3. Clear step-by-step guidance
4. A copy-ready prompt the user can paste into Lovable, Claude Code, or Cursor when useful

Be practical, specific, and concise. Do not invent details that are not visible. If you are uncertain, say what you can infer and what needs to be checked.

You MUST respond with a single JSON object matching exactly this TypeScript type, with no extra keys, no markdown fences, and no commentary outside the JSON:

{
  "summary": string,
  "observations": string[],
  "recommendedNextSteps": string[],
  "promptForClaudeOrLovable": string,
  "risksOrWarnings": string[]
}

The promptForClaudeOrLovable field should contain a self-contained, copy-pasteable instruction that another AI coding tool could act on without needing the screenshot. Reference what is visible explicitly so the receiving tool has enough context.`;

export function buildUserText(args: {
  question: string;
  projectContext?: string;
}): string {
  const ctx = args.projectContext?.trim()
    ? args.projectContext.trim()
    : "(none provided)";
  const q = args.question.trim() || "Describe what you see and what I should do next.";
  return `Project context:\n${ctx}\n\nUser question:\n${q}`;
}

// Defensive parser: handles model output that occasionally wraps JSON in
// markdown fences or includes leading/trailing prose.
export function parseAnalysisJson(raw: string): AnalysisResponse {
  const cleaned = stripCodeFences(raw).trim();
  let value: unknown;
  try {
    value = JSON.parse(cleaned);
  } catch {
    // Last-ditch: try to extract the first {...} block.
    const match = cleaned.match(/\{[\s\S]*\}/);
    if (!match) {
      throw new Error("Model did not return JSON.");
    }
    value = JSON.parse(match[0]);
  }
  return validateAnalysisResponse(value);
}

function stripCodeFences(s: string): string {
  const fence = /^```(?:json)?\s*([\s\S]*?)\s*```$/m;
  const m = s.match(fence);
  return m ? m[1] : s;
}

function validateAnalysisResponse(value: unknown): AnalysisResponse {
  if (!value || typeof value !== "object") {
    throw new Error("Model JSON was not an object.");
  }
  const v = value as Record<string, unknown>;

  const summary = expectString(v.summary, "summary");
  const observations = expectStringArray(v.observations, "observations");
  const recommendedNextSteps = expectStringArray(
    v.recommendedNextSteps,
    "recommendedNextSteps",
  );

  const out: AnalysisResponse = {
    summary,
    observations,
    recommendedNextSteps,
  };
  if (typeof v.promptForClaudeOrLovable === "string") {
    out.promptForClaudeOrLovable = v.promptForClaudeOrLovable;
  }
  if (Array.isArray(v.risksOrWarnings)) {
    out.risksOrWarnings = v.risksOrWarnings.filter(
      (x): x is string => typeof x === "string",
    );
  }
  return out;
}

function expectString(v: unknown, field: string): string {
  if (typeof v !== "string") {
    throw new Error(`Field "${field}" must be a string.`);
  }
  return v;
}

function expectStringArray(v: unknown, field: string): string[] {
  if (!Array.isArray(v)) {
    throw new Error(`Field "${field}" must be an array of strings.`);
  }
  return v.filter((x): x is string => typeof x === "string");
}
