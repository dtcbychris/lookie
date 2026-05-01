import { useEffect, useMemo, useState } from "react";
import type {
  AnalysisItem,
  AnalysisResponse,
  AnalyzeState,
  AppSettings,
  CaptureState,
  Project,
} from "../types";
import { captureScreenOnce } from "../lib/capture";
import { analyzeScreenshot } from "../lib/analyze";
import { uid } from "../lib/storage";
import { CapturePanel } from "./CapturePanel";
import { AnalysisView } from "./AnalysisView";
import { HistoryList } from "./HistoryList";

type Props = {
  project: Project;
  settings: AppSettings;
  history: AnalysisItem[];
  onUpdateProject: (next: Project) => void;
  onDeleteProject: (id: string) => void;
  onAddAnalysis: (item: AnalysisItem) => void;
  onDeleteAnalysis: (id: string) => void;
};

export function ProjectWorkspace({
  project,
  settings,
  history,
  onUpdateProject,
  onDeleteProject,
  onAddAnalysis,
  onDeleteAnalysis,
}: Props) {
  const [editingContext, setEditingContext] = useState(false);
  const [contextDraft, setContextDraft] = useState(project.savedContext ?? "");
  const [question, setQuestion] = useState("");
  const [captureState, setCaptureState] = useState<CaptureState>("idle");
  const [captureError, setCaptureError] = useState<string | null>(null);
  const [imageDataUrl, setImageDataUrl] = useState<string | null>(null);
  const [analyzeState, setAnalyzeState] = useState<AnalyzeState>("idle");
  const [analysis, setAnalysis] = useState<AnalysisResponse | null>(null);
  const [analyzeError, setAnalyzeError] = useState<string | null>(null);
  const [activeHistoryId, setActiveHistoryId] = useState<string | null>(null);

  // Reset transient state when switching projects.
  useEffect(() => {
    setQuestion("");
    setCaptureState("idle");
    setCaptureError(null);
    setImageDataUrl(null);
    setAnalyzeState("idle");
    setAnalysis(null);
    setAnalyzeError(null);
    setActiveHistoryId(null);
    setEditingContext(false);
    setContextDraft(project.savedContext ?? "");
  }, [project.id, project.savedContext]);

  const projectHistory = useMemo(
    () => history.filter((h) => h.projectId === project.id),
    [history, project.id],
  );

  async function handleCapture() {
    setCaptureError(null);
    setCaptureState("requesting-permission");
    try {
      setCaptureState("capturing");
      const result = await captureScreenOnce();
      setImageDataUrl(result.dataUrl);
      setCaptureState("captured");
      setActiveHistoryId(null);
      setAnalysis(null);
      setAnalyzeState("idle");
      setAnalyzeError(null);
    } catch (err) {
      setCaptureState("error");
      setCaptureError(
        err instanceof Error ? err.message : "Could not capture screen.",
      );
    }
  }

  function handleClearScreenshot() {
    setImageDataUrl(null);
    setCaptureState("idle");
    setCaptureError(null);
  }

  async function handleAnalyze() {
    if (!imageDataUrl) {
      setAnalyzeError("No screenshot captured yet.");
      setAnalyzeState("error");
      return;
    }
    setAnalyzeState("analyzing");
    setAnalyzeError(null);
    try {
      const response = await analyzeScreenshot({
        imageDataUrl,
        question: question.trim(),
        projectContext: project.savedContext,
        settings,
      });
      setAnalysis(response);
      setAnalyzeState("success");

      if (settings.privacy.saveChatHistory) {
        const item: AnalysisItem = {
          id: uid(),
          projectId: project.id,
          question: question.trim(),
          imageDataUrl: settings.privacy.saveScreenshots
            ? imageDataUrl
            : undefined,
          response,
          createdAt: new Date().toISOString(),
        };
        onAddAnalysis(item);
        setActiveHistoryId(item.id);
      }
    } catch (err) {
      setAnalyzeState("error");
      setAnalyzeError(
        err instanceof Error ? err.message : "AI analysis failed.",
      );
    }
  }

  function handleSelectHistory(item: AnalysisItem) {
    setActiveHistoryId(item.id);
    setQuestion(item.question);
    setAnalysis(item.response);
    setAnalyzeState("success");
    setAnalyzeError(null);
    if (item.imageDataUrl) {
      setImageDataUrl(item.imageDataUrl);
      setCaptureState("captured");
    }
  }

  function saveContext() {
    onUpdateProject({
      ...project,
      savedContext: contextDraft,
      updatedAt: new Date().toISOString(),
    });
    setEditingContext(false);
  }

  return (
    <div className="flex h-full flex-col overflow-hidden">
      <header className="flex items-center justify-between border-b border-ink-800 px-8 py-4">
        <div className="min-w-0">
          <div className="label">Project</div>
          <h1 className="truncate text-lg font-semibold text-ink-50">
            {project.name}
          </h1>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            className="btn-outline"
            onClick={() => {
              setContextDraft(project.savedContext ?? "");
              setEditingContext((v) => !v);
            }}
          >
            {editingContext ? "Close context" : "Edit context"}
          </button>
          <button
            type="button"
            className="btn-outline text-rose-300 hover:text-rose-200"
            onClick={() => {
              const ok = window.confirm(
                `Delete project "${project.name}"? Its history will also be removed.`,
              );
              if (ok) onDeleteProject(project.id);
            }}
          >
            Delete project
          </button>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto px-8 py-6">
        <div className="mx-auto flex max-w-4xl flex-col gap-6">
          {editingContext ? (
            <section className="card p-4">
              <div className="label mb-2">Project context</div>
              <textarea
                className="input min-h-[120px] font-mono text-xs"
                value={contextDraft}
                onChange={(e) => setContextDraft(e.target.value)}
                placeholder="Describe what this project is about so the AI can give sharper answers."
              />
              <div className="mt-3 flex justify-end gap-2">
                <button
                  type="button"
                  className="btn-ghost"
                  onClick={() => setEditingContext(false)}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  className="btn-primary"
                  onClick={saveContext}
                >
                  Save context
                </button>
              </div>
            </section>
          ) : null}

          <CapturePanel
            state={captureState}
            imageDataUrl={imageDataUrl}
            errorMessage={captureError}
            onCapture={handleCapture}
            onClear={handleClearScreenshot}
          />

          <section className="card p-4">
            <div className="label mb-2">Your question</div>
            <textarea
              className="input min-h-[80px]"
              placeholder="What should I do next? What's wrong with this screen?"
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
            />
            <div className="mt-3 flex items-center justify-between">
              <p className="text-xs text-ink-500">
                {settings.provider === "mock"
                  ? "Provider: mock — responses are generated locally."
                  : `Provider: ${settings.provider} — sends to /api/analyze.`}
              </p>
              <button
                type="button"
                className="btn-primary"
                onClick={handleAnalyze}
                disabled={!imageDataUrl || analyzeState === "analyzing"}
              >
                {analyzeState === "analyzing" ? "Analyzing…" : "Analyze"}
              </button>
            </div>
          </section>

          <AnalysisView
            state={analyzeState}
            response={analysis}
            errorMessage={analyzeError}
            question={question}
            projectName={project.name}
            projectContext={project.savedContext}
          />

          <section>
            <div className="mb-2 flex items-center justify-between">
              <div className="label">History</div>
              <span className="text-xs text-ink-500">
                {projectHistory.length} item
                {projectHistory.length === 1 ? "" : "s"}
              </span>
            </div>
            <HistoryList
              items={projectHistory}
              activeId={activeHistoryId}
              onSelect={handleSelectHistory}
              onDelete={(id) => {
                onDeleteAnalysis(id);
                if (activeHistoryId === id) setActiveHistoryId(null);
              }}
            />
          </section>
        </div>
      </div>
    </div>
  );
}
