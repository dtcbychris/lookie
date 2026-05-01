import { useState } from "react";
import type { AnalysisResponse, AnalyzeState } from "../types";

type Props = {
  state: AnalyzeState;
  response: AnalysisResponse | null;
  errorMessage: string | null;
};

function CopyButton({ text, label }: { text: string; label?: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      type="button"
      className="btn-outline text-xs"
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

export function AnalysisView({ state, response, errorMessage }: Props) {
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
          <div className="mb-2 flex items-center justify-between">
            <div className="label">Prompt for Claude / Lovable / Cursor</div>
            <CopyButton
              text={response.promptForClaudeOrLovable}
              label="Copy prompt"
            />
          </div>
          <pre className="whitespace-pre-wrap rounded-md border border-ink-800 bg-ink-950 p-3 font-mono text-xs text-ink-200">
            {response.promptForClaudeOrLovable}
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
