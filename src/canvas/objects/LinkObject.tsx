import { useState } from "react";
import type { CanvasObject } from "../canvasTypes";

interface Props {
  object: CanvasObject;
  onPointerDownMove: (e: React.PointerEvent) => void;
  onUpdate: (patch: Partial<CanvasObject>) => void;
}

export function LinkObject({ object, onPointerDownMove, onUpdate }: Props) {
  const [editingTitle, setEditingTitle] = useState(false);
  const locked = !!object.locked;

  function display(): string {
    try {
      if (!object.url) return "";
      const u = new URL(
        object.url.startsWith("http") ? object.url : `https://${object.url}`,
      );
      return u.hostname.replace(/^www\./, "") + (u.pathname === "/" ? "" : u.pathname);
    } catch {
      return object.url ?? "";
    }
  }

  function open() {
    if (!object.url) return;
    const href = object.url.startsWith("http")
      ? object.url
      : `https://${object.url}`;
    window.open(href, "_blank", "noopener,noreferrer");
  }

  return (
    <div
      onPointerDown={onPointerDownMove}
      className={`flex h-full w-full flex-col justify-between rounded-xl border border-ink-100 bg-white p-3 shadow-md ${
        locked ? "" : "cursor-grab active:cursor-grabbing"
      }`}
    >
      <div className="flex items-start gap-2">
        <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-emerald-50 text-emerald-600">
          <LinkIcon />
        </div>
        <div className="min-w-0 flex-1">
          {editingTitle && !locked ? (
            <input
              autoFocus
              defaultValue={object.title ?? ""}
              onPointerDown={(e) => e.stopPropagation()}
              onBlur={(e) => {
                onUpdate({ title: e.currentTarget.value });
                setEditingTitle(false);
              }}
              onKeyDown={(e) => {
                if (e.key === "Enter") (e.target as HTMLInputElement).blur();
                if (e.key === "Escape") setEditingTitle(false);
              }}
              className="w-full bg-transparent text-sm font-medium text-ink-900 outline-none"
              placeholder="Title"
            />
          ) : (
            <div
              className="truncate text-sm font-medium text-ink-900"
              onDoubleClick={(e) => {
                e.stopPropagation();
                if (!locked) setEditingTitle(true);
              }}
            >
              {object.title || display() || "Link"}
            </div>
          )}
          <div className="truncate text-[11px] text-ink-500">{display()}</div>
        </div>
      </div>
      <div className="flex justify-end">
        <button
          type="button"
          onPointerDown={(e) => e.stopPropagation()}
          onClick={open}
          className="rounded px-1.5 py-0.5 text-[11px] text-emerald-600 hover:bg-emerald-50"
        >
          Open ↗
        </button>
      </div>
    </div>
  );
}

function LinkIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4">
      <path
        d="M10 14a4 4 0 0 0 5.66 0l3-3a4 4 0 1 0-5.66-5.66l-1 1"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
      <path
        d="M14 10a4 4 0 0 0-5.66 0l-3 3a4 4 0 1 0 5.66 5.66l1-1"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  );
}
