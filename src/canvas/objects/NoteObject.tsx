import { useState } from "react";
import type { CanvasObject } from "../canvasTypes";

interface Props {
  object: CanvasObject;
  onPointerDownMove: (e: React.PointerEvent) => void;
  onUpdate: (patch: Partial<CanvasObject>) => void;
}

export function NoteObject({ object, onPointerDownMove, onUpdate }: Props) {
  const [editingTitle, setEditingTitle] = useState(false);
  const [editingBody, setEditingBody] = useState(false);
  const locked = !!object.locked;
  const tint = object.color ?? "#fff8d1";

  return (
    <div
      className="flex h-full w-full flex-col overflow-hidden rounded-xl border border-black/5 shadow-md"
      style={{ backgroundColor: tint }}
    >
      <div
        onPointerDown={onPointerDownMove}
        onDoubleClick={() => !locked && setEditingTitle(true)}
        className={`px-3 pt-2 ${locked ? "" : "cursor-grab active:cursor-grabbing"}`}
      >
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
            className="w-full bg-transparent text-sm font-semibold text-ink-900 outline-none"
            placeholder="Title"
          />
        ) : (
          <div className="truncate text-sm font-semibold text-ink-900">
            {object.title || "Untitled note"}
          </div>
        )}
      </div>

      <div
        className="flex-1 overflow-auto px-3 pb-3 pt-1"
        onDoubleClick={() => !locked && setEditingBody(true)}
        onPointerDown={(e) => {
          if (!editingBody) onPointerDownMove(e);
        }}
      >
        {editingBody && !locked ? (
          <textarea
            autoFocus
            defaultValue={object.content ?? ""}
            onPointerDown={(e) => e.stopPropagation()}
            onBlur={(e) => {
              onUpdate({ content: e.currentTarget.value });
              setEditingBody(false);
            }}
            className="h-full w-full resize-none bg-transparent text-sm leading-snug text-ink-900 outline-none"
            placeholder="Write something..."
          />
        ) : (
          <div className="whitespace-pre-wrap text-sm leading-snug text-ink-900/85">
            {object.content || (
              <span className="text-ink-900/40">Double-click to edit</span>
            )}
          </div>
        )}
      </div>

      {locked && <LockBadge />}
    </div>
  );
}

function LockBadge() {
  return (
    <div className="absolute right-2 top-2 rounded-full bg-white/70 px-1.5 py-0.5 text-[10px] font-medium text-ink-700 backdrop-blur">
      Locked
    </div>
  );
}
