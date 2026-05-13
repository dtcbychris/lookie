import { useRef, useState } from "react";
import type { CanvasStore } from "./useCanvasStore";
import { fileToDataUrl } from "./canvasUtils";

interface Props {
  store: CanvasStore;
  getSpawnPoint: () => { x: number; y: number };
}

export function CanvasToolbar({ store, getSpawnPoint }: Props) {
  const { state, setTool, addObject, clearAll, importState, exportState } =
    store;
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const importInputRef = useRef<HTMLInputElement | null>(null);
  const [confirmClear, setConfirmClear] = useState(false);

  function addNote() {
    const { x, y } = getSpawnPoint();
    addObject({
      type: "note",
      x: x - 110,
      y: y - 70,
      width: 220,
      height: 140,
      title: "",
      content: "",
    });
  }

  function addImage() {
    const url = window.prompt("Image URL:");
    if (!url) return;
    const { x, y } = getSpawnPoint();
    addObject({
      type: "image",
      x: x - 140,
      y: y - 110,
      width: 280,
      height: 220,
      url,
      title: "",
    });
  }

  function addLink() {
    const url = window.prompt("URL:");
    if (!url) return;
    const { x, y } = getSpawnPoint();
    addObject({
      type: "link",
      x: x - 130,
      y: y - 50,
      width: 260,
      height: 100,
      url,
      title: "",
    });
  }

  function addZone() {
    const name = window.prompt("Zone name:", "Research");
    if (name === null) return;
    const { x, y } = getSpawnPoint();
    addObject({
      type: "zone",
      x: x - 240,
      y: y - 160,
      width: 480,
      height: 320,
      title: name || "Zone",
    });
  }

  function triggerFile() {
    fileInputRef.current?.click();
  }

  async function onFileChosen(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    let dataUrl: string | undefined;
    if (file.size <= 4 * 1024 * 1024) {
      try {
        dataUrl = await fileToDataUrl(file);
      } catch {
        dataUrl = undefined;
      }
    }
    const { x, y } = getSpawnPoint();
    addObject({
      type: "file",
      x: x - 120,
      y: y - 60,
      width: 240,
      height: 120,
      title: file.name,
      file: {
        name: file.name,
        mimeType: file.type || "application/octet-stream",
        size: file.size,
        dataUrl,
      },
    });
  }

  function onExport() {
    const json = exportState();
    const blob = new Blob([json], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `canvasos-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }

  function triggerImport() {
    importInputRef.current?.click();
  }

  async function onImportChosen(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    const text = await file.text();
    const ok = importState(text);
    if (!ok) window.alert("Could not import that file.");
  }

  return (
    <div className="pointer-events-none fixed left-4 top-4 z-50 flex flex-col gap-2">
      <div className="pointer-events-auto flex items-center gap-1 rounded-xl border border-ink-200/70 bg-white/90 p-1 shadow-lg backdrop-blur">
        <ToolButton
          label="Select"
          active={state.tool === "select"}
          onClick={() => setTool("select")}
          icon={<CursorIcon />}
        />
        <ToolButton
          label="Scribble"
          active={state.tool === "scribble"}
          onClick={() =>
            setTool(state.tool === "scribble" ? "select" : "scribble")
          }
          icon={<PenIcon />}
        />
        <Divider />
        <ToolButton label="Note" onClick={addNote} icon={<NoteIcon />} />
        <ToolButton label="Image" onClick={addImage} icon={<ImageIcon />} />
        <ToolButton label="File" onClick={triggerFile} icon={<FileIcon />} />
        <ToolButton label="Link" onClick={addLink} icon={<LinkIcon />} />
        <ToolButton label="Zone" onClick={addZone} icon={<ZoneIcon />} />
        <Divider />
        <ToolButton
          label="Export"
          onClick={onExport}
          icon={<ExportIcon />}
        />
        <ToolButton
          label="Import"
          onClick={triggerImport}
          icon={<ImportIcon />}
        />
        <ToolButton
          label="Clear"
          onClick={() => setConfirmClear(true)}
          icon={<TrashIcon />}
          danger
        />
      </div>

      <input
        ref={fileInputRef}
        type="file"
        className="hidden"
        onChange={onFileChosen}
      />
      <input
        ref={importInputRef}
        type="file"
        accept="application/json"
        className="hidden"
        onChange={onImportChosen}
      />

      {confirmClear && (
        <div className="pointer-events-auto rounded-xl border border-ink-200/70 bg-white p-3 text-sm shadow-lg">
          <div className="mb-2 text-ink-700">Clear all objects?</div>
          <div className="flex justify-end gap-2">
            <button
              className="rounded px-2 py-1 text-ink-600 hover:bg-ink-100"
              onClick={() => setConfirmClear(false)}
            >
              Cancel
            </button>
            <button
              className="rounded bg-red-500 px-2 py-1 text-white hover:bg-red-400"
              onClick={() => {
                clearAll();
                setConfirmClear(false);
              }}
            >
              Clear
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function Divider() {
  return <div className="mx-0.5 h-6 w-px bg-ink-200" />;
}

function ToolButton({
  label,
  icon,
  active,
  onClick,
  danger,
}: {
  label: string;
  icon: React.ReactNode;
  active?: boolean;
  onClick: () => void;
  danger?: boolean;
}) {
  return (
    <button
      type="button"
      title={label}
      onClick={onClick}
      className={`flex items-center gap-1.5 rounded-md px-2 py-1.5 text-xs font-medium transition ${
        active
          ? "bg-indigo-500 text-white"
          : danger
            ? "text-red-500 hover:bg-red-50"
            : "text-ink-700 hover:bg-ink-100"
      }`}
    >
      <span className="h-4 w-4">{icon}</span>
      <span className="hidden sm:inline">{label}</span>
    </button>
  );
}

function CursorIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4">
      <path
        d="M5 3l6 16 2-7 7-2L5 3z"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinejoin="round"
      />
    </svg>
  );
}
function PenIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4">
      <path
        d="M4 20l4-1 11-11-3-3L5 16l-1 4z"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinejoin="round"
      />
    </svg>
  );
}
function NoteIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4">
      <rect
        x="4"
        y="4"
        width="16"
        height="16"
        rx="2"
        stroke="currentColor"
        strokeWidth="1.5"
      />
      <path d="M8 9h8M8 13h6" stroke="currentColor" strokeWidth="1.5" />
    </svg>
  );
}
function ImageIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4">
      <rect
        x="3"
        y="5"
        width="18"
        height="14"
        rx="2"
        stroke="currentColor"
        strokeWidth="1.5"
      />
      <circle cx="9" cy="10" r="1.5" fill="currentColor" />
      <path d="M21 17l-5-5-7 7" stroke="currentColor" strokeWidth="1.5" />
    </svg>
  );
}
function FileIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4">
      <path
        d="M7 3h7l5 5v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z"
        stroke="currentColor"
        strokeWidth="1.5"
      />
      <path d="M14 3v5h5" stroke="currentColor" strokeWidth="1.5" />
    </svg>
  );
}
function LinkIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4">
      <path
        d="M10 14a4 4 0 0 0 5.66 0l3-3a4 4 0 1 0-5.66-5.66l-1 1"
        stroke="currentColor"
        strokeWidth="1.5"
      />
      <path
        d="M14 10a4 4 0 0 0-5.66 0l-3 3a4 4 0 1 0 5.66 5.66l1-1"
        stroke="currentColor"
        strokeWidth="1.5"
      />
    </svg>
  );
}
function ZoneIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4">
      <rect
        x="3"
        y="3"
        width="18"
        height="18"
        rx="2"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeDasharray="3 3"
      />
    </svg>
  );
}
function ExportIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4">
      <path
        d="M12 4v12m0-12l-4 4m4-4l4 4M5 20h14"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  );
}
function ImportIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4">
      <path
        d="M12 20V8m0 12l-4-4m4 4l4-4M5 4h14"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  );
}
function TrashIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4">
      <path
        d="M4 7h16M9 7V4h6v3m-8 0v13a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1V7"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
