import { useEffect, useState } from "react";
import type { Project } from "../types";
import { BRAIN_FIELDS } from "../lib/projectContext";

type Props = {
  project: Project;
  onSave: (next: Project) => void;
  onClose: () => void;
  onRemoveDecision: (index: number) => void;
};

const HELP: Record<string, string> = {
  savedContext:
    "What is this project? Who is it for? What's the current focus?",
  stack:
    "Frameworks, libraries, hosting, key services. e.g. 'Next.js + Tailwind, Supabase, Stripe Connect, Vercel'.",
  brandRules:
    "Voice, tone, color palette, type, components. e.g. 'single-color icons, 8pt grid, rounded-md only'.",
  productGoals:
    "What you're trying to achieve. e.g. 'launch creator dashboard MVP by Friday'.",
  userPreferences:
    "How you want Brixley to respond. e.g. 'be direct, no hedging, prefer code over prose'.",
};

const PLACEHOLDER: Record<string, string> = {
  savedContext: "Vibal is a marketplace for IRL marketing activations…",
  stack: "Next.js, TypeScript, Tailwind, Supabase, Stripe…",
  brandRules: "Single-color icons, max two font weights, 8pt spacing…",
  productGoals: "Ship the creator dashboard MVP this week…",
  userPreferences: "Be opinionated. Skip preamble. Prefer code blocks…",
};

export function ProjectBrainPanel({
  project,
  onSave,
  onClose,
  onRemoveDecision,
}: Props) {
  const [draft, setDraft] = useState<Project>(project);

  // Reset draft if the underlying project changes (e.g., decision removed).
  useEffect(() => {
    setDraft(project);
  }, [project]);

  function update<K extends keyof Project>(key: K, value: Project[K]) {
    setDraft((prev) => ({ ...prev, [key]: value }));
  }

  function handleSave() {
    onSave({ ...draft, updatedAt: new Date().toISOString() });
  }

  const dirty = JSON.stringify(draft) !== JSON.stringify(project);
  const decisions = project.decisions ?? [];

  return (
    <section className="card">
      <header className="flex items-center justify-between border-b border-ink-800 px-5 py-3">
        <div>
          <div className="label">Project brain</div>
          <p className="mt-0.5 text-xs text-ink-500">
            Persistent memory for this project. Sent with every analysis so
            Brixley keeps continuity instead of starting over each time.
          </p>
        </div>
        <button type="button" className="btn-ghost" onClick={onClose}>
          Close
        </button>
      </header>

      <div className="grid grid-cols-1 gap-4 p-5 md:grid-cols-2">
        {BRAIN_FIELDS.map(({ key, label }) => (
          <label key={key} className="flex flex-col gap-1.5">
            <span className="label">{label}</span>
            <textarea
              className="input min-h-[88px] font-mono text-xs"
              value={(draft[key] as string | undefined) ?? ""}
              placeholder={PLACEHOLDER[key]}
              onChange={(e) => update(key, e.target.value)}
            />
            <span className="text-[11px] text-ink-500">{HELP[key]}</span>
          </label>
        ))}
      </div>

      <div className="border-t border-ink-800 p-5">
        <div className="mb-2 flex items-center justify-between">
          <div className="label">Decisions</div>
          <span className="text-xs text-ink-500">
            {decisions.length} item{decisions.length === 1 ? "" : "s"}
          </span>
        </div>
        {decisions.length === 0 ? (
          <p className="text-xs text-ink-500">
            No decisions yet. Use{" "}
            <span className="text-ink-300">Save as project decision</span> on
            any analysis response to add one.
          </p>
        ) : (
          <ul className="space-y-1.5">
            {decisions.map((d, i) => (
              <li
                key={i}
                className="flex items-start gap-2 rounded-md border border-ink-800 bg-ink-950 px-3 py-2 text-sm text-ink-200"
              >
                <span className="flex-1">{d}</span>
                <button
                  type="button"
                  onClick={() => onRemoveDecision(i)}
                  className="text-xs text-ink-500 hover:text-rose-300"
                  aria-label="Remove decision"
                >
                  ✕
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      <footer className="flex items-center justify-end gap-2 border-t border-ink-800 px-5 py-3">
        <button type="button" className="btn-ghost" onClick={onClose}>
          Cancel
        </button>
        <button
          type="button"
          className="btn-primary"
          onClick={handleSave}
          disabled={!dirty}
        >
          {dirty ? "Save brain" : "Saved"}
        </button>
      </footer>
    </section>
  );
}
