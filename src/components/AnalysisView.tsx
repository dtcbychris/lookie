import { useMemo, useState } from "react";
import type { AnalysisResponse, AnalyzeState } from "../types";
import {
  PROMPT_TARGETS,
  type PromptTarget,
  wrapPrompt,
} from "../lib/promptTargets";

type Props = {
  state: AnalyzeState;
  response: AnalysisResponse | null;
  errorMessage: string | null;
  question: string;
  projectName: string;
  projectContext?: string;
};

function CopyButton({
  text,
  label,
  disabled,
}: {
  text: string;
  label?: string;
  disabled?: boolean;
}) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      type="button"
      className="btn-outline text-xs"
      disabled={disabled}
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(text);
          setCopied(true);
          setTimeout(() => setCopied(false), 1500);
        } catch {
          setCopied(false);
        }
      }}
    >
      {copied ? "Copied" : (label ?? "Copy")}
    </button>
  );
}

export function AnalysisView({
  state,
  response,
  errorMessage,
  question,
  projectName,
  projectContext,
}: Props) {
  const [target, setTarget] = useState<PromptTarget>("claude-code");

  const wrappedPrompt = useMemo(() => {
    if (!response?.promptForClaudeOrLovable) return "";
    return wrapPrompt({
      target,
      basePrompt: response.promptForClaudeOrLovable,
      question,
      projectName,
      projectContext,
    });
  }, [target, response, question, projectName, projectContext]);

  if (state === "idle" && !response) {
    return (
      <section className="card p-6 text-sm text-ink-400">
        Capture a screenshot, ask a question, then click{" "}
        <span className="text-ink-100">Analyze</span>. The response will appear
        here.
      </section>
    );
  }

  if (state === "analyzing") {
    return (
      <section className="card p-6">
        <div className="flex items-center gap-3 text-sm text-ink-300">
          <span className="h-2 w-2 animate-pulse rounded-full bg-amber-400" />
          Analyzing screenshot…
        </div>
      </section>
    );
  }

  if (state === "error") {
    return (
      <section className="card border-rose-900/50 p-6 text-sm text-rose-200">
        {errorMessage ?? "AI analysis failed."}
      </section>
    );
  }

  if (!response) return null;

  return (
    <section className="card divide-y divide-ink-800">
      <div className="p-5">
        <div className="label mb-1">Summary</div>
        <p className="text-sm leading-relaxed text-ink-100">
          {response.summary}
        </p>
      </div>

      {response.observations?.length ? (
        <div className="p-5">
          <div className="label mb-2">Observations</div>
          <ul className="list-disc space-y-1 pl-5 text-sm text-ink-200">
            {response.observations.map((o, i) => (
              <li key={i}>{o}</li>
            ))}
          </ul>
        </div>
      ) : null}

      {response.recommendedNextSteps?.length ? (
        <div className="p-5">
          <div className="label mb-2">Recommended next steps</div>
          <ul className="list-decimal space-y-1 pl-5 text-sm text-ink-200">
            {response.recommendedNextSteps.map((s, i) => (
              <li key={i}>{s}</li>
            ))}
          </ul>
        </div>
      ) : null}

      {response.promptForClaudeOrLovable ? (
        <div className="p-5">
          <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="label">Implementation prompt</div>
              <div className="mt-0.5 text-xs text-ink-500">
                Pick a target, copy, paste.
              </div>
            </div>
            <div className="flex items-center gap-2">
              <div
                role="tablist"
                aria-label="Prompt target"
                className="flex overflow-hidden rounded-md border border-ink-700"
              >
                {PROMPT_TARGETS.map((t) => {
                  const active = target === t.id;
                  return (
                    <button
                      key={t.id}
                      type="button"
                      role="tab"
                      aria-selected={active}
                      className={
                        "px-2.5 py-1 text-xs transition " +
                        (active
                          ? "bg-indigo-500/20 text-indigo-100"
                          : "text-ink-300 hover:bg-ink-800")
                      }
                      onClick={() => setTarget(t.id)}
                    >
                      {t.label}
                    </button>
                  );
                })}
              </div>
              <CopyButton
                text={wrappedPrompt}
                label={`Copy for ${PROMPT_TARGETS.find((t) => t.id === target)?.label}`}
                disabled={!wrappedPrompt}
              />
            </div>
          </div>
          <pre className="max-h-[360px] overflow-auto whitespace-pre-wrap rounded-md border border-ink-800 bg-ink-950 p-3 font-mono text-xs text-ink-200">
            {wrappedPrompt || response.promptForClaudeOrLovable}
          </pre>
        </div>
      ) : null}

      {response.risksOrWarnings?.length ? (
        <div className="p-5">
          <div className="label mb-2 text-amber-300">Risks & warnings</div>
          <ul className="list-disc space-y-1 pl-5 text-sm text-amber-200/90">
            {response.risksOrWarnings.map((w, i) => (
              <li key={i}>{w}</li>
            ))}
          </ul>
        </div>
      ) : null}
    </section>
  );
}
