// Wraps the model's `promptForClaudeOrLovable` with target-appropriate framing
// so the user can paste it straight into Claude Code, Lovable, Cursor, etc.

export type PromptTarget = "claude-code" | "lovable" | "cursor" | "raw";

export const PROMPT_TARGETS: { id: PromptTarget; label: string }[] = [
  { id: "claude-code", label: "Claude Code" },
  { id: "lovable", label: "Lovable" },
  { id: "cursor", label: "Cursor" },
  { id: "raw", label: "Raw" },
];

export type WrapArgs = {
  target: PromptTarget;
  basePrompt: string;
  question?: string;
  projectName?: string;
  projectContext?: string;
};

export function wrapPrompt(args: WrapArgs): string {
  const { target, basePrompt } = args;
  const trimmedBase = basePrompt.trim();
  if (target === "raw") return trimmedBase;

  const contextBlock = buildContextBlock(args);
  switch (target) {
    case "claude-code":
      return [
        "You are Claude Code working inside the user's repository.",
        "",
        contextBlock,
        "Task:",
        trimmedBase,
        "",
        "Before editing, briefly state the plan and the files you intend to change. Make the changes, run any relevant typecheck/build/test commands, and report what was done.",
      ]
        .filter(Boolean)
        .join("\n");

    case "lovable":
      return [
        "Lovable, please make the following change to this project:",
        "",
        contextBlock,
        "Change request:",
        trimmedBase,
        "",
        "Preserve existing data bindings, routes, and component structure unless the change explicitly requires otherwise. Keep styling consistent with the current design.",
      ]
        .filter(Boolean)
        .join("\n");

    case "cursor":
      return [
        "Implement the following in the current workspace.",
        "",
        contextBlock,
        "Implementation:",
        trimmedBase,
        "",
        "Edit only the files needed for this change. Match existing code conventions in the repo.",
      ]
        .filter(Boolean)
        .join("\n");
  }
}

function buildContextBlock(args: WrapArgs): string {
  const lines: string[] = [];
  if (args.projectName) {
    lines.push(`Project: ${args.projectName}`);
  }
  if (args.projectContext?.trim()) {
    lines.push("Project context:");
    lines.push(args.projectContext.trim());
  }
  if (args.question?.trim()) {
    lines.push("Original question from the user:");
    lines.push(args.question.trim());
  }
  if (lines.length === 0) return "";
  return lines.join("\n") + "\n";
}
