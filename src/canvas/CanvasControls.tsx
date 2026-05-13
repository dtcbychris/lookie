import type { CanvasStore } from "./useCanvasStore";
import { clampScale, computeBoundingBox } from "./canvasUtils";

interface Props {
  store: CanvasStore;
  containerRef: React.RefObject<HTMLDivElement | null>;
}

export function CanvasControls({ store, containerRef }: Props) {
  const { state, setViewport } = store;
  const { viewport, objects, lastSavedAt } = state;

  function zoom(delta: number) {
    const rect = containerRef.current?.getBoundingClientRect();
    if (!rect) return;
    const next = clampScale(viewport.scale * (1 + delta));
    const cx = rect.width / 2;
    const cy = rect.height / 2;
    const wx = (cx - viewport.x) / viewport.scale;
    const wy = (cy - viewport.y) / viewport.scale;
    setViewport({ x: cx - wx * next, y: cy - wy * next, scale: next });
  }

  function reset() {
    setViewport({ x: 0, y: 0, scale: 1 });
  }

  function fit() {
    const rect = containerRef.current?.getBoundingClientRect();
    if (!rect || objects.length === 0) return reset();
    const bb = computeBoundingBox(objects);
    if (!bb) return reset();
    const margin = 80;
    const sx = (rect.width - margin * 2) / bb.width;
    const sy = (rect.height - margin * 2) / bb.height;
    const scale = clampScale(Math.min(sx, sy, 1.5));
    const cx = bb.x + bb.width / 2;
    const cy = bb.y + bb.height / 2;
    setViewport({
      x: rect.width / 2 - cx * scale,
      y: rect.height / 2 - cy * scale,
      scale,
    });
  }

  return (
    <div className="pointer-events-none fixed bottom-4 right-4 z-50 flex flex-col items-end gap-2">
      <div className="pointer-events-auto flex items-center gap-1 rounded-xl border border-ink-200/70 bg-white/90 p-1 shadow-lg backdrop-blur">
        <SmallBtn onClick={() => zoom(-0.15)} label="−" />
        <div className="min-w-[3rem] text-center text-xs text-ink-600">
          {Math.round(viewport.scale * 100)}%
        </div>
        <SmallBtn onClick={() => zoom(0.15)} label="+" />
        <div className="mx-1 h-5 w-px bg-ink-200" />
        <TextBtn onClick={reset} label="Reset" />
        <TextBtn onClick={fit} label="Fit" />
      </div>
      <div className="pointer-events-none rounded-md bg-white/70 px-2 py-0.5 text-[11px] text-ink-500 backdrop-blur">
        {objects.length} object{objects.length === 1 ? "" : "s"}
        {lastSavedAt && (
          <span className="ml-2 text-ink-400">
            saved {timeAgo(lastSavedAt)}
          </span>
        )}
      </div>
    </div>
  );
}

function SmallBtn({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="h-7 w-7 rounded-md text-sm text-ink-700 hover:bg-ink-100"
    >
      {label}
    </button>
  );
}

function TextBtn({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="rounded-md px-2 py-1 text-xs text-ink-700 hover:bg-ink-100"
    >
      {label}
    </button>
  );
}

function timeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  if (diff < 5_000) return "just now";
  if (diff < 60_000) return `${Math.floor(diff / 1000)}s ago`;
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
  return new Date(iso).toLocaleDateString();
}
