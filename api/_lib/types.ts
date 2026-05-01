// Server-side mirror of the frontend AnalysisResponse shape.
// Kept in sync with src/types.ts.

export type AnalysisResponse = {
  summary: string;
  observations: string[];
  recommendedNextSteps: string[];
  promptForClaudeOrLovable?: string;
  risksOrWarnings?: string[];
};

export type AnalyzeRequest = {
  imageBase64: string;
  question: string;
  projectContext?: string;
};
