import { useState } from "react";
import type { CanvasObject } from "../canvasTypes";

interface Props {
  object: CanvasObject;
  onPointerDownMove: (e: React.PointerEvent) => void;
  onUpdate: (patch: Partial<CanvasObject>) => void;
}

const ZONE_TINTS = [
  "rgba(99,102,241,0.10)",
  "rgba(16,185,129,0.10)",
  "rgba(244,114,182,0.10)",
  "rgba(245,158,11,0.10)",
  "rgba(14,165,233,0.10)",
];

export function ZoneObject({ object, onPointerDownMove, onUpdate }: Props) {
  const [editing, setEditing] = useState(false);
  const locked = !!object.locked;
  const tint = object.color ?? ZONE_TINTS[0];

  return (
    <div
      onPointerDown={onPointerDownMove}
      className={`relative flex h-full w-full flex-col rounded-2xl border-2 border-dashed ${
        locked ? "" : "cursor-grab active:cursor-grabbing"
      }`}
      style={{
        backgroundColor: tint,
        borderColor: "rgba(31,35,43,0.18)",
      }}
    >
      <div
        className="px-4 pt-3"
        onDoubleClick={(e) => {
          e.stopPropagation();
          if (!locked) setEditing(true);
        }}
      >
        {editing && !locked ? (
          <input
            autoFocus
            defaultValue={object.title ?? ""}
            onPointerDown={(e) => e.stopPropagation()}
            onBlur={(e) => {
              onUpdate({ title: e.currentTarget.value });
              setEditing(false);
            }}
            onKeyDown={(e) => {
              if (e.key === "Enter") (e.target as HTMLInputElement).blur();
              if (e.key === "Escape") setEditing(false);
            }}
            className="w-full bg-transparent text-base font-semibold uppercase tracking-wide text-ink-700 outline-none"
            placeholder="Zone name"
          />
        ) : (
          <div className="text-xs font-semibold uppercase tracking-wider text-ink-600/80">
            {object.title || "Zone"}
          </div>
        )}
      </div>
    </div>
  );
}
