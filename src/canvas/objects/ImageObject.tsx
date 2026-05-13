import { useState } from "react";
import type { CanvasObject } from "../canvasTypes";

interface Props {
  object: CanvasObject;
  onPointerDownMove: (e: React.PointerEvent) => void;
  onUpdate: (patch: Partial<CanvasObject>) => void;
}

export function ImageObject({ object, onPointerDownMove, onUpdate }: Props) {
  const [editingCaption, setEditingCaption] = useState(false);
  const locked = !!object.locked;

  return (
    <div className="flex h-full w-full flex-col overflow-hidden rounded-xl border border-black/5 bg-white shadow-md">
      <div
        onPointerDown={onPointerDownMove}
        className={`relative flex-1 overflow-hidden bg-ink-100 ${
          locked ? "" : "cursor-grab active:cursor-grabbing"
        }`}
      >
        {object.url ? (
          <img
            src={object.url}
            alt={object.title ?? "image"}
            draggable={false}
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center text-xs text-ink-500">
            No image URL
          </div>
        )}
      </div>
      <div
        className="border-t border-ink-100 px-3 py-2"
        onDoubleClick={() => !locked && setEditingCaption(true)}
      >
        {editingCaption && !locked ? (
          <input
            autoFocus
            defaultValue={object.title ?? ""}
            onPointerDown={(e) => e.stopPropagation()}
            onBlur={(e) => {
              onUpdate({ title: e.currentTarget.value });
              setEditingCaption(false);
            }}
            onKeyDown={(e) => {
              if (e.key === "Enter") (e.target as HTMLInputElement).blur();
              if (e.key === "Escape") setEditingCaption(false);
            }}
            className="w-full bg-transparent text-xs text-ink-700 outline-none"
            placeholder="Caption"
          />
        ) : (
          <div className="truncate text-xs text-ink-600">
            {object.title || (
              <span className="text-ink-400">Double-click for caption</span>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
