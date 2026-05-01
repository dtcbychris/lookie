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
  /** Legacy / overview text. Falls back to projectBrain when absent. */
  projectContext?: string;
  /** Pre-rendered project brain block (overview + stack + brand + decisions). */
  projectBrain?: string;
  /** Pre-rendered recent-history block, never includes screenshots. */
  recentHistoryContext?: string;
};
