export type AnalysisResponse = {
  summary: string;
  observations: string[];
  recommendedNextSteps: string[];
  promptForClaudeOrLovable?: string;
  risksOrWarnings?: string[];
};

export type Project = {
  id: string;
  name: string;
  description?: string;
  savedContext?: string;
  createdAt: string;
  updatedAt: string;
};

export type AnalysisItem = {
  id: string;
  projectId: string;
  question: string;
  imageDataUrl?: string;
  response: AnalysisResponse;
  createdAt: string;
};

export type PrivacySettings = {
  saveScreenshots: boolean;
  saveChatHistory: boolean;
  autoRedact: boolean;
};

export type AppSettings = {
  privacy: PrivacySettings;
  provider: "mock" | "openai" | "anthropic";
};

export type CaptureState =
  | "idle"
  | "requesting-permission"
  | "capturing"
  | "captured"
  | "error";

export type AnalyzeState = "idle" | "analyzing" | "success" | "error";
