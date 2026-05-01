import { useEffect, useState } from "react";
import type { AnalysisItem, AppSettings, Project } from "./types";
import {
  loadActiveProjectId,
  loadHistory,
  loadProjects,
  loadSettings,
  saveActiveProjectId,
  saveHistory,
  saveProjects,
  saveSettings,
  uid,
} from "./lib/storage";
import { Sidebar } from "./components/Sidebar";
import { ProjectWorkspace } from "./components/ProjectWorkspace";
import { SettingsPanel } from "./components/SettingsPanel";

type View = "workspace" | "settings";

export function App() {
  const [projects, setProjects] = useState<Project[]>(() => loadProjects());
  const [activeProjectId, setActiveProjectId] = useState<string | null>(() => {
    const stored = loadActiveProjectId();
    if (stored) return stored;
    const fallback = loadProjects()[0]?.id ?? null;
    return fallback;
  });
  const [view, setView] = useState<View>("workspace");
  const [history, setHistory] = useState<AnalysisItem[]>(() => loadHistory());
  const [settings, setSettings] = useState<AppSettings>(() => loadSettings());

  useEffect(() => {
    saveProjects(projects);
  }, [projects]);

  useEffect(() => {
    saveActiveProjectId(activeProjectId);
  }, [activeProjectId]);

  useEffect(() => {
    saveHistory(history);
  }, [history]);

  useEffect(() => {
    saveSettings(settings);
  }, [settings]);

  const activeProject =
    projects.find((p) => p.id === activeProjectId) ?? projects[0] ?? null;

  function handleSelectProject(id: string) {
    setActiveProjectId(id);
    setView("workspace");
  }

  function handleNewProject() {
    const name = window.prompt("Project name?");
    if (!name?.trim()) return;
    const now = new Date().toISOString();
    const project: Project = {
      id: uid(),
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    };
    setProjects((prev) => [...prev, project]);
    setActiveProjectId(project.id);
    setView("workspace");
  }

  function handleUpdateProject(next: Project) {
    setProjects((prev) => prev.map((p) => (p.id === next.id ? next : p)));
  }

  function handleDeleteProject(id: string) {
    setProjects((prev) => prev.filter((p) => p.id !== id));
    setHistory((prev) => prev.filter((h) => h.projectId !== id));
    if (activeProjectId === id) {
      const next = projects.find((p) => p.id !== id);
      setActiveProjectId(next?.id ?? null);
    }
  }

  function handleAddAnalysis(item: AnalysisItem) {
    setHistory((prev) => [item, ...prev]);
  }

  function handleDeleteAnalysis(id: string) {
    setHistory((prev) => prev.filter((h) => h.id !== id));
  }

  return (
    <div className="flex h-full w-full">
      <Sidebar
        projects={projects}
        activeProjectId={activeProject?.id ?? null}
        view={view}
        onSelectProject={handleSelectProject}
        onNewProject={handleNewProject}
        onOpenSettings={() => setView("settings")}
      />

      <main className="flex min-w-0 flex-1 flex-col">
        {view === "settings" ? (
          <SettingsPanel settings={settings} onChange={setSettings} />
        ) : activeProject ? (
          <ProjectWorkspace
            key={activeProject.id}
            project={activeProject}
            settings={settings}
            history={history}
            onUpdateProject={handleUpdateProject}
            onDeleteProject={handleDeleteProject}
            onAddAnalysis={handleAddAnalysis}
            onDeleteAnalysis={handleDeleteAnalysis}
          />
        ) : (
          <EmptyState onNewProject={handleNewProject} />
        )}
      </main>
    </div>
  );
}

function EmptyState({ onNewProject }: { onNewProject: () => void }) {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-3 p-10 text-center">
      <h2 className="text-lg font-semibold text-ink-100">No project selected</h2>
      <p className="max-w-md text-sm text-ink-400">
        Create a project to capture screenshots and ask questions about what
        you&apos;re building.
      </p>
      <button type="button" className="btn-primary" onClick={onNewProject}>
        New project
      </button>
    </div>
  );
}
