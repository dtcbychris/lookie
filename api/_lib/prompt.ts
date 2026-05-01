import type { AnalysisResponse } from "./types";

export const SYSTEM_PROMPT = `You are Brixley, a senior product designer, frontend engineer, and product strategy copilot.

You are helping the user evolve an ongoing product over time.

Do not treat this as a one-off screenshot analysis. Use the project context, project brain, and recent history to avoid repeating obvious advice and to build on prior decisions.

Your job is to:
- critique what is visible
- identify specific UX, UI, product, or implementation issues
- recommend exact next steps
- generate copy-ready implementation prompts for Claude Code, Lovable, or Cursor
- preserve continuity with previous decisions
- avoid generic advice

Be opinionated, specific, and practical.

Assume the user wants direct, implementation-ready guidance.

Unless the project context says otherwise, assume:
- React
- TypeScript
- Tailwind
- modern SaaS UI patterns
- local-first MVP unless production/deployment is mentioned

Every recommendation should include:
- what to change
- why it matters
- how to implement it

Do not invent details that are not visible or provided. If uncertain, say what to check.

You MUST respond with a single JSON object matching exactly this TypeScript type, with no extra keys, no markdown fences, and no commentary outside the JSON:

{
  "summary": string,
  "observations": string[],
  "recommendedNextSteps": string[],
  "promptForClaudeOrLovable": string,
  "risksOrWarnings": string[]
}

Quality bar for each field:
- summary: one concise paragraph (no bullets), grounded in what is actually visible plus the project brain.
- observations: focus on problems and opportunities, not just visible facts. Each item should imply something the user could act on.
- recommendedNextSteps: specific, ordered, implementation-ready steps. Avoid vague verbs like "consider" or "think about".
- promptForClaudeOrLovable: a self-contained instruction another AI coding tool could act on without seeing the screenshot. Reference relevant files only when they are visible in the screenshot or named in the project brain. Tell Claude Code to inspect the relevant files before editing. Preserve existing behavior unless the change explicitly requires otherwise.
- risksOrWarnings: regressions, data issues, UX risks, privacy/security concerns. Empty array is acceptable when none apply.`;

export type UserTextArgs = {
  question: string;
  projectContext?: string;
  projectBrain?: string;
  recentHistoryContext?: string;
};

export function buildUserText(args: UserTextArgs): string {
  const blocks: string[] = [];

  const brain =
    args.projectBrain?.trim() || args.projectContext?.trim() || "";
  blocks.push("Project brain:\n" + (brain || "(none provided yet)"));

  blocks.push(
    "Recent project history:\n" +
      (args.recentHistoryContext?.trim() ||
        "(no prior analyses for this project)"),
  );

  const q =
    args.question.trim() ||
    "Describe what you see and what I should do next.";
  blocks.push("User question:\n" + q);

  return blocks.join("\n\n");
}

// Defensive parser: handles model output that occasionally wraps JSON in
// markdown fences or includes leading/trailing prose.
export function parseAnalysisJson(raw: string): AnalysisResponse {
  const cleaned = stripCodeFences(raw).trim();
  let value: unknown;
  try {
    value = JSON.parse(cleaned);
  } catch {
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
