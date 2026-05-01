import type { AnalysisResponse, AppSettings } from "../types";

export interface VisionProvider {
  analyze(input: {
    imageBase64: string;
    question: string;
    projectContext?: string;
  }): Promise<AnalysisResponse>;
}

const mockProvider: VisionProvider = {
  async analyze({ question, projectContext }) {
    await new Promise((r) => setTimeout(r, 900));
    const focus = question.trim() || "this screen";
    return {
      summary: `Mock analysis for: "${focus}". Wire up a real vision provider to get a true read of the screenshot.`,
      observations: [
        "This is a mock response generated locally without sending the screenshot anywhere.",
        projectContext
          ? `Project context received (${projectContext.length} chars) — it would be passed to the model.`
          : "No project context provided. Add some in the project header for sharper answers.",
        "The capture pipeline is working: screenshot decoded, question received, response shape matches AnalysisResponse.",
      ],
      recommendedNextSteps: [
        "Add an OPENAI_API_KEY or ANTHROPIC_API_KEY in your backend env.",
        "Implement /api/analyze to call the provider with the image and question.",
        "Switch the provider in Settings → AI provider from 'mock' to your chosen vendor.",
      ],
      promptForClaudeOrLovable: `Implement a serverless route /api/analyze that accepts { imageBase64, question, projectContext } and returns JSON matching AnalysisResponse {summary, observations[], recommendedNextSteps[], promptForClaudeOrLovable?, risksOrWarnings?}. Use ${"the configured provider"} and parse the model's output to that shape.`,
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
  settings: AppSettings;
}): Promise<AnalysisResponse> {
  const provider = getProvider(args.settings);
  return provider.analyze({
    imageBase64: dataUrlToBase64(args.imageDataUrl),
    question: args.question,
    projectContext: args.projectContext,
  });
}
