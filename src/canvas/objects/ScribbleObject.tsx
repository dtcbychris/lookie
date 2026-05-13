import type { CanvasObject } from "../canvasTypes";

interface Props {
  object: CanvasObject;
  onPointerDownMove: (e: React.PointerEvent) => void;
}

export function ScribbleObject({ object, onPointerDownMove }: Props) {
  const strokes = object.strokes ?? [];
  const locked = !!object.locked;
  return (
    <div
      onPointerDown={onPointerDownMove}
      className={`relative h-full w-full ${
        locked ? "" : "cursor-grab active:cursor-grabbing"
      }`}
    >
      <svg
        viewBox={`0 0 ${object.width} ${object.height}`}
        className="h-full w-full"
        preserveAspectRatio="none"
      >
        {strokes.map((stroke, i) => (
          <polyline
            key={i}
            fill="none"
            stroke={stroke.color}
            strokeWidth={stroke.width}
            strokeLinecap="round"
            strokeLinejoin="round"
            points={stroke.points.map((p) => `${p.x},${p.y}`).join(" ")}
          />
        ))}
      </svg>
    </div>
  );
}
