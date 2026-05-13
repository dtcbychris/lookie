import { useEffect, useMemo, useRef, useState } from "react";
import type { CanvasObject, ScribbleStroke } from "./canvasTypes";
import { clampScale, screenToCanvas } from "./canvasUtils";
import { CanvasObjectRenderer } from "./CanvasObjectRenderer";
import type { CanvasStore } from "./useCanvasStore";

interface Props {
  store: CanvasStore;
  containerRef: React.RefObject<HTMLDivElement | null>;
}

interface DragState {
  kind: "pan" | "move" | "resize" | "scribble";
  objectId?: string;
  startClientX: number;
  startClientY: number;
  origin: { x: number; y: number; width?: number; height?: number };
  liveStroke?: ScribbleStroke;
  liveOrigin?: { x: number; y: number };
}

export function InfiniteCanvas({ store, containerRef }: Props) {
  const { state, setViewport, setSelected, updateObject, addObject } = store;
  const { viewport, objects, tool, selectedId } = state;

  const dragRef = useRef<DragState | null>(null);
  const [, forceRender] = useState(0);
  const [liveStroke, setLiveStroke] = useState<{
    stroke: ScribbleStroke;
    origin: { x: number; y: number };
  } | null>(null);

  // Wheel handler for zoom / two-finger pan
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      const rect = el.getBoundingClientRect();
      if (e.ctrlKey || e.metaKey) {
        // pinch-zoom / ctrl+wheel
        const delta = -e.deltaY * 0.01;
        const next = clampScale(viewport.scale * (1 + delta));
        const sx = e.clientX - rect.left;
        const sy = e.clientY - rect.top;
        const cx = (sx - viewport.x) / viewport.scale;
        const cy = (sy - viewport.y) / viewport.scale;
        setViewport({
          x: sx - cx * next,
          y: sy - cy * next,
          scale: next,
        });
      } else {
        setViewport((prev) => ({
          ...prev,
          x: prev.x - e.deltaX,
          y: prev.y - e.deltaY,
        }));
      }
    };
    el.addEventListener("wheel", onWheel, { passive: false });
    return () => el.removeEventListener("wheel", onWheel);
  }, [viewport, setViewport]);

  // Global pointer move/up while dragging
  useEffect(() => {
    function onMove(e: PointerEvent) {
      const drag = dragRef.current;
      if (!drag) return;
      const dx = e.clientX - drag.startClientX;
      const dy = e.clientY - drag.startClientY;

      if (drag.kind === "pan") {
        setViewport((prev) => ({
          ...prev,
          x: drag.origin.x + dx,
          y: drag.origin.y + dy,
        }));
      } else if (drag.kind === "move" && drag.objectId) {
        updateObject(drag.objectId, {
          x: drag.origin.x + dx / viewport.scale,
          y: drag.origin.y + dy / viewport.scale,
        });
      } else if (drag.kind === "resize" && drag.objectId) {
        updateObject(drag.objectId, {
          width: Math.max(80, (drag.origin.width ?? 200) + dx / viewport.scale),
          height: Math.max(60, (drag.origin.height ?? 120) + dy / viewport.scale),
        });
      } else if (drag.kind === "scribble" && drag.liveStroke && drag.liveOrigin) {
        const rect = containerRef.current?.getBoundingClientRect();
        if (!rect) return;
        const pt = screenToCanvas(e.clientX, e.clientY, rect, viewport);
        const local = {
          x: pt.x - drag.liveOrigin.x,
          y: pt.y - drag.liveOrigin.y,
        };
        drag.liveStroke.points.push(local);
        setLiveStroke({
          stroke: { ...drag.liveStroke, points: [...drag.liveStroke.points] },
          origin: drag.liveOrigin,
        });
      }
    }
    function onUp() {
      const drag = dragRef.current;
      if (!drag) return;
      if (drag.kind === "scribble" && drag.liveStroke && drag.liveOrigin) {
        const points = drag.liveStroke.points;
        if (points.length > 1) {
          let minX = Infinity;
          let minY = Infinity;
          let maxX = -Infinity;
          let maxY = -Infinity;
          for (const p of points) {
            if (p.x < minX) minX = p.x;
            if (p.y < minY) minY = p.y;
            if (p.x > maxX) maxX = p.x;
            if (p.y > maxY) maxY = p.y;
          }
          const pad = 8;
          const offsetX = minX - pad;
          const offsetY = minY - pad;
          const normalized = points.map((p) => ({
            x: p.x - offsetX,
            y: p.y - offsetY,
          }));
          addObject({
            type: "scribble",
            x: drag.liveOrigin.x + offsetX,
            y: drag.liveOrigin.y + offsetY,
            width: Math.max(24, maxX - minX + pad * 2),
            height: Math.max(24, maxY - minY + pad * 2),
            strokes: [{ ...drag.liveStroke, points: normalized }],
          });
        }
        setLiveStroke(null);
      }
      dragRef.current = null;
      forceRender((n) => n + 1);
    }
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
    window.addEventListener("pointercancel", onUp);
    return () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      window.removeEventListener("pointercancel", onUp);
    };
  }, [viewport, updateObject, setViewport, addObject]);

  function handleBackgroundPointerDown(e: React.PointerEvent<HTMLDivElement>) {
    if (e.button !== 0) return;
    const rect = containerRef.current?.getBoundingClientRect();
    if (!rect) return;

    if (tool === "scribble") {
      const pt = screenToCanvas(e.clientX, e.clientY, rect, viewport);
      const stroke: ScribbleStroke = {
        color: "#1f232b",
        width: 2,
        points: [{ x: 0, y: 0 }],
      };
      dragRef.current = {
        kind: "scribble",
        startClientX: e.clientX,
        startClientY: e.clientY,
        origin: { x: 0, y: 0 },
        liveStroke: stroke,
        liveOrigin: pt,
      };
      setLiveStroke({ stroke, origin: pt });
      return;
    }

    setSelected(null);
    dragRef.current = {
      kind: "pan",
      startClientX: e.clientX,
      startClientY: e.clientY,
      origin: { x: viewport.x, y: viewport.y },
    };
  }

  function beginMove(obj: CanvasObject, e: React.PointerEvent) {
    if (obj.locked) return;
    e.stopPropagation();
    setSelected(obj.id);
    dragRef.current = {
      kind: "move",
      objectId: obj.id,
      startClientX: e.clientX,
      startClientY: e.clientY,
      origin: { x: obj.x, y: obj.y },
    };
  }

  function beginResize(obj: CanvasObject, e: React.PointerEvent) {
    if (obj.locked) return;
    e.stopPropagation();
    setSelected(obj.id);
    dragRef.current = {
      kind: "resize",
      objectId: obj.id,
      startClientX: e.clientX,
      startClientY: e.clientY,
      origin: { x: obj.x, y: obj.y, width: obj.width, height: obj.height },
    };
  }

  const sortedObjects = useMemo(
    () => [...objects].sort((a, b) => a.zIndex - b.zIndex),
    [objects],
  );

  const cursor =
    tool === "scribble"
      ? "crosshair"
      : dragRef.current?.kind === "pan"
        ? "grabbing"
        : "grab";

  return (
    <div
      ref={(el) => {
        (containerRef as { current: HTMLDivElement | null }).current = el;
      }}
      onPointerDown={handleBackgroundPointerDown}
      className="absolute inset-0 select-none overflow-hidden"
      style={{
        backgroundColor: "#fafaf7",
        backgroundImage:
          "radial-gradient(circle at 1px 1px, rgba(31,35,43,0.08) 1px, transparent 0)",
        backgroundSize: `${24 * viewport.scale}px ${24 * viewport.scale}px`,
        backgroundPosition: `${viewport.x}px ${viewport.y}px`,
        cursor,
      }}
    >
      <div
        className="absolute left-0 top-0 origin-top-left"
        style={{
          transform: `translate(${viewport.x}px, ${viewport.y}px) scale(${viewport.scale})`,
        }}
      >
        {sortedObjects.map((obj) => (
          <CanvasObjectRenderer
            key={obj.id}
            object={obj}
            selected={obj.id === selectedId}
            scale={viewport.scale}
            onPointerDownMove={(e) => beginMove(obj, e)}
            onPointerDownResize={(e) => beginResize(obj, e)}
            onUpdate={(patch) => updateObject(obj.id, patch)}
            onSelect={() => setSelected(obj.id)}
          />
        ))}
        {liveStroke && (
          <svg
            className="pointer-events-none absolute"
            style={{
              left: liveStroke.origin.x,
              top: liveStroke.origin.y,
              overflow: "visible",
            }}
          >
            <polyline
              fill="none"
              stroke={liveStroke.stroke.color}
              strokeWidth={liveStroke.stroke.width}
              strokeLinecap="round"
              strokeLinejoin="round"
              points={liveStroke.stroke.points
                .map((p) => `${p.x},${p.y}`)
                .join(" ")}
            />
          </svg>
        )}
      </div>
    </div>
  );
}

