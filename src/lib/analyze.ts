import type { AnalysisResponse, AppSettings } from "../types";

export type AnalyzeInput = {
  imageBase64: string;
  question: string;
  /** Pre-rendered project overview (legacy field, still accepted). */
  projectContext?: string;
  /** Pre-rendered project brain block (overview + stack + brand + decisions). */
  projectBrain?: string;
  /** Pre-rendered recent-history block, never includes screenshots. */
  recentHistoryContext?: string;
};

export interface VisionProvider {
  analyze(input: AnalyzeInput): Promise<AnalysisResponse>;
}

const mockProvider: VisionProvider = {
  async analyze({ question, projectBrain, recentHistoryContext }) {
    await new Promise((r) => setTimeout(r, 900));
    const focus = question.trim() || "this screen";
    const brainNote = projectBrain
      ? `Project brain attached (${projectBrain.length} chars).`
      : "No project brain filled in yet.";
    const histNote = recentHistoryContext
      ? `Recent history attached.`
      : "No prior analyses for this project.";
    return {
      summary: `Mock analysis for: "${focus}". ${brainNote} ${histNote} Wire up a real vision provider to get a true read of the screenshot.`,
      observations: [
        "This is a mock response generated locally without sending the screenshot anywhere.",
        "The capture pipeline is working: screenshot decoded, question received, response shape matches AnalysisResponse.",
        projectBrain
          ? "Brain content would be passed to the model as ongoing project memory."
          : "Fill in the Project Brain to make real responses much sharper.",
      ],
      recommendedNextSteps: [
        "Add an OPENAI_API_KEY in your server env.",
        "Switch the provider in Settings → AI provider from 'mock' to 'openai'.",
        "Capture a real screen and try again.",
      ],
      promptForClaudeOrLovable:
        "Inspect api/_lib/openai.ts and confirm OPENAI_API_KEY is present in the server environment. If not, add it to .env (server-side only) and restart the dev server. Do not modify other files.",
      risksOrWarnings: [
        "Do not embed private API keys in the frontend bundle. Use a backend route.",
      ],
    };
  },
};

const remoteProvider: VisionProvider = {
  async analyze(input) {
    let res: Response;
    try {
      res = await fetch("/api/analyze", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(input),
      });
    } catch {
      throw new Error(
        "Could not reach /api/analyze. Is the backend running?",
      );
    }

    let body: unknown = null;
    try {
      body = await res.json();
    } catch {
      // Non-JSON body (e.g., HTML error page).
    }

    if (!res.ok) {
      const message =
        body && typeof body === "object" && "error" in body
          ? String((body as { error: unknown }).error)
          : `AI analysis failed (${res.status}). Check your API key or server logs.`;
      throw new Error(message);
    }
    return body as AnalysisResponse;
  },
};

export function getProvider(settings: AppSettings): VisionProvider {
  if (settings.provider === "mock") return mockProvider;
  return remoteProvider;
}

export function dataUrlToBase64(dataUrl: string): string {
  const idx = dataUrl.indexOf(",");
  return idx >= 0 ? dataUrl.slice(idx + 1) : dataUrl;
}

export async function analyzeScreenshot(args: {
  imageDataUrl: string;
  question: string;
  projectContext?: string;
  projectBrain?: string;
  recentHistoryContext?: string;
  settings: AppSettings;
}): Promise<AnalysisResponse> {
  const provider = getProvider(args.settings);
  return provider.analyze({
    imageBase64: dataUrlToBase64(args.imageDataUrl),
    question: args.question,
    projectContext: args.projectContext,
    projectBrain: args.projectBrain,
    recentHistoryContext: args.recentHistoryContext,
  });
}
