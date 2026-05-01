import type { Project } from "../types";

type Props = {
  projects: Project[];
  activeProjectId: string | null;
  view: "workspace" | "settings";
  onSelectProject: (id: string) => void;
  onNewProject: () => void;
  onOpenSettings: () => void;
};

export function Sidebar({
  projects,
  activeProjectId,
  view,
  onSelectProject,
  onNewProject,
  onOpenSettings,
}: Props) {
  return (
    <aside className="flex w-64 shrink-0 flex-col border-r border-ink-800 bg-ink-950">
      <div className="px-4 py-5">
        <div className="flex items-center gap-2">
          <div className="h-7 w-7 rounded-md bg-gradient-to-br from-indigo-400 to-fuchsia-500" />
          <div>
            <div className="text-sm font-semibold text-ink-100">
              Builder Copilot
            </div>
            <div className="text-[11px] text-ink-500">
              Screen-aware, user-controlled
            </div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between px-4 pb-2">
        <span className="label">Projects</span>
        <button
          type="button"
          className="text-xs text-indigo-300 hover:text-indigo-200"
          onClick={onNewProject}
        >
          + New
        </button>
      </div>

      <nav className="flex-1 overflow-y-auto px-2">
        {projects.map((p) => {
          const isActive = view === "workspace" && p.id === activeProjectId;
          return (
            <button
              key={p.id}
              type="button"
              onClick={() => onSelectProject(p.id)}
              className={
                "mb-1 flex w-full items-center justify-between rounded-md px-3 py-2 text-left text-sm transition " +
                (isActive
                  ? "bg-ink-800 text-ink-50"
                  : "text-ink-300 hover:bg-ink-900 hover:text-ink-100")
              }
            >
              <span className="truncate">{p.name}</span>
              {isActive ? (
                <span className="h-1.5 w-1.5 rounded-full bg-indigo-400" />
              ) : null}
            </button>
          );
        })}
      </nav>

      <div className="border-t border-ink-800 p-2">
        <button
          type="button"
          onClick={onOpenSettings}
          className={
            "flex w-full items-center justify-between rounded-md px-3 py-2 text-left text-sm transition " +
            (view === "settings"
              ? "bg-ink-800 text-ink-50"
              : "text-ink-300 hover:bg-ink-900 hover:text-ink-100")
          }
        >
          <span>Settings & Privacy</span>
          <span className="text-ink-500">›</span>
        </button>
      </div>
    </aside>
  );
}
