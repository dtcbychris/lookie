import type {
  AnalysisItem,
  AppSettings,
  Project,
} from "../types";

const KEYS = {
  projects: "bc.projects",
  history: "bc.history",
  settings: "bc.settings",
  activeProject: "bc.activeProject",
} as const;

const DEFAULT_SETTINGS: AppSettings = {
  privacy: {
    saveScreenshots: false,
    saveChatHistory: true,
    autoRedact: false,
  },
  provider: "mock",
};

const DEFAULT_PROJECT_NAMES = ["Vibal", "PixelGP", "Driig", "General"];

export function uid(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
}

function read<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

function write<T>(key: string, value: T): void {
  localStorage.setItem(key, JSON.stringify(value));
}

export function loadSettings(): AppSettings {
  const stored = read<Partial<AppSettings> | null>(KEYS.settings, null);
  if (!stored) return DEFAULT_SETTINGS;
  return {
    ...DEFAULT_SETTINGS,
    ...stored,
    privacy: { ...DEFAULT_SETTINGS.privacy, ...(stored.privacy ?? {}) },
  };
}

export function saveSettings(settings: AppSettings): void {
  write(KEYS.settings, settings);
}

export function loadProjects(): Project[] {
  const existing = read<Project[]>(KEYS.projects, []);
  if (existing.length > 0) return existing;
  const now = new Date().toISOString();
  const seeded: Project[] = DEFAULT_PROJECT_NAMES.map((name) => ({
    id: uid(),
    name,
    createdAt: now,
    updatedAt: now,
  }));
  write(KEYS.projects, seeded);
  return seeded;
}

export function saveProjects(projects: Project[]): void {
  write(KEYS.projects, projects);
}

export function loadActiveProjectId(): string | null {
  return read<string | null>(KEYS.activeProject, null);
}

export function saveActiveProjectId(id: string | null): void {
  write(KEYS.activeProject, id);
}

export function loadHistory(): AnalysisItem[] {
  return read<AnalysisItem[]>(KEYS.history, []);
}

export function saveHistory(items: AnalysisItem[]): void {
  write(KEYS.history, items);
}
