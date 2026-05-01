import type { AnalysisItem, Project } from "../types";

export const BRAIN_FIELDS = [
  { key: "savedContext", label: "Project overview" },
  { key: "stack", label: "Tech stack" },
  { key: "brandRules", label: "Brand / design rules" },
  { key: "productGoals", label: "Product goals" },
  { key: "userPreferences", label: "User preferences" },
] as const satisfies readonly {
  key: keyof Project;
  label: string;
}[];

export type BrainFieldKey = (typeof BRAIN_FIELDS)[number]["key"];

const HISTORY_LIMIT = 5;

/**
 * Renders the project's "brain" (overview, stack, brand, goals, preferences,
 * decisions) into a single text block that can be pasted into a model prompt.
 */
export function formatProjectBrain(project: Project): string {
  const lines: string[] = [];
  for (const { key, label } of BRAIN_FIELDS) {
    const value = (project[key] as string | undefined)?.trim();
    if (value) lines.push(`${label}:\n${value}`);
  }
  const decisions = (project.decisions ?? [])
    .map((d) => d.trim())
    .filter(Boolean);
  if (decisions.length > 0) {
    lines.push(
      "Decisions already made:\n" + decisions.map((d) => `- ${d}`).join("\n"),
    );
  }
  return lines.join("\n\n");
}

/**
 * Returns a concise text block summarizing the most recent analyses for a
 * project, intentionally excluding screenshot data.
 */
export function getRecentProjectContext(
  projectId: string,
  history: AnalysisItem[],
  limit: number = HISTORY_LIMIT,
): string {
  const recent = history
    .filter((h) => h.projectId === projectId)
    .slice(0, limit);
  if (recent.length === 0) return "";

  const blocks = recent.map((item, i) => {
    const lines: string[] = [];
    lines.push(`#${i + 1} — ${new Date(item.createdAt).toLocaleString()}`);
    if (item.question.trim()) lines.push(`Question: ${item.question.trim()}`);
    if (item.response.summary)
      lines.push(`Summary: ${item.response.summary.trim()}`);
    const steps = item.response.recommendedNextSteps?.slice(0, 3) ?? [];
    if (steps.length) {
      lines.push(
        "Recommended next steps:\n" + steps.map((s) => `  - ${s}`).join("\n"),
      );
    }
    if (item.response.promptForClaudeOrLovable) {
      const p = item.response.promptForClaudeOrLovable.trim();
      lines.push(
        "Prior implementation prompt: " +
          (p.length > 220 ? p.slice(0, 220) + "…" : p),
      );
    }
    return lines.join("\n");
  });

  return (
    "Recent project history (most recent first):\n\n" + blocks.join("\n\n")
  );
}

export type BrainSummary = {
  filledFields: number;
  totalFields: number;
  decisionsCount: number;
  hasAny: boolean;
};

export function projectBrainSummary(project: Project): BrainSummary {
  const filledFields = BRAIN_FIELDS.reduce((acc, { key }) => {
    const v = project[key] as string | undefined;
    return acc + (v && v.trim().length > 0 ? 1 : 0);
  }, 0);
  const decisionsCount = (project.decisions ?? []).filter((d) => d.trim())
    .length;
  return {
    filledFields,
    totalFields: BRAIN_FIELDS.length,
    decisionsCount,
    hasAny: filledFields > 0 || decisionsCount > 0,
  };
}

export function recentHistoryCount(
  projectId: string,
  history: AnalysisItem[],
  limit: number = HISTORY_LIMIT,
): number {
  return Math.min(
    history.filter((h) => h.projectId === projectId).length,
    limit,
  );
}
