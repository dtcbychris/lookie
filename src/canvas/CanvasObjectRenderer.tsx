import type { CanvasObject } from "./canvasTypes";
import { NoteObject } from "./objects/NoteObject";
import { ImageObject } from "./objects/ImageObject";
import { FileObject } from "./objects/FileObject";
import { LinkObject } from "./objects/LinkObject";
import { ZoneObject } from "./objects/ZoneObject";
import { ScribbleObject } from "./objects/ScribbleObject";

interface Props {
  object: CanvasObject;
  selected: boolean;
  scale: number;
  onPointerDownMove: (e: React.PointerEvent) => void;
  onPointerDownResize: (e: React.PointerEvent) => void;
  onUpdate: (patch: Partial<CanvasObject>) => void;
  onSelect: () => void;
}

export function CanvasObjectRenderer({
  object,
  selected,
  scale,
  onPointerDownMove,
  onPointerDownResize,
  onUpdate,
  onSelect,
}: Props) {
  const wrapperStyle: React.CSSProperties = {
    position: "absolute",
    left: object.x,
    top: object.y,
    width: object.width,
    height: object.height,
    zIndex: object.zIndex,
    transform: object.rotation ? `rotate(${object.rotation}deg)` : undefined,
  };

  const showResize = !object.locked && selected;
  // Inverse-scale handles/outline so they appear constant on screen.
  const handleScale = 1 / scale;

  return (
    <div
      style={wrapperStyle}
      onPointerDown={(e) => {
        e.stopPropagation();
        onSelect();
      }}
    >
      {object.type === "note" && (
        <NoteObject
          object={object}
          onPointerDownMove={onPointerDownMove}
          onUpdate={onUpdate}
        />
      )}
      {object.type === "image" && (
        <ImageObject
          object={object}
          onPointerDownMove={onPointerDownMove}
          onUpdate={onUpdate}
        />
      )}
      {object.type === "file" && (
        <FileObject
          object={object}
          onPointerDownMove={onPointerDownMove}
          onUpdate={onUpdate}
        />
      )}
      {object.type === "link" && (
        <LinkObject
          object={object}
          onPointerDownMove={onPointerDownMove}
          onUpdate={onUpdate}
        />
      )}
      {object.type === "zone" && (
        <ZoneObject
          object={object}
          onPointerDownMove={onPointerDownMove}
          onUpdate={onUpdate}
        />
      )}
      {object.type === "scribble" && (
        <ScribbleObject
          object={object}
          onPointerDownMove={onPointerDownMove}
        />
      )}

      {selected && (
        <div
          className="pointer-events-none absolute -inset-px rounded-[10px] ring-2 ring-indigo-400/70"
          style={{
            boxShadow: "0 0 0 1px rgba(99,102,241,0.15)",
          }}
        />
      )}

      {showResize && (
        <div
          onPointerDown={(e) => onPointerDownResize(e)}
          className="absolute bottom-0 right-0 z-10 cursor-nwse-resize rounded-tl-md bg-indigo-500 shadow"
          style={{
            width: 14 * handleScale,
            height: 14 * handleScale,
            transform: `translate(${7 * handleScale}px, ${7 * handleScale}px)`,
          }}
          title="Resize"
        />
      )}
    </div>
  );
}
