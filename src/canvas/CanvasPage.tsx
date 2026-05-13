import { useCallback, useEffect, useRef } from "react";
import { InfiniteCanvas } from "./InfiniteCanvas";
import { CanvasToolbar } from "./CanvasToolbar";
import { ObjectControls } from "./ObjectControls";
import { CanvasControls } from "./CanvasControls";
import { useCanvasStore } from "./useCanvasStore";

export function CanvasPage() {
  const store = useCanvasStore();
  const containerRef = useRef<HTMLDivElement | null>(null);

  const getSpawnPoint = useCallback((): { x: number; y: number } => {
    const rect = containerRef.current?.getBoundingClientRect();
    const v = store.state.viewport;
    if (!rect) return { x: 0, y: 0 };
    return {
      x: (rect.width / 2 - v.x) / v.scale,
      y: (rect.height / 2 - v.y) / v.scale,
    };
  }, [store.state.viewport]);

  // Keyboard shortcuts
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      const target = e.target as HTMLElement | null;
      const tag = target?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA") return;

      if ((e.key === "Delete" || e.key === "Backspace") && store.state.selectedId) {
        store.deleteObject(store.state.selectedId);
        e.preventDefault();
      }
      if (e.key === "Escape") {
        store.setSelected(null);
        store.setTool("select");
      }
      if (e.key === "v") store.setTool("select");
      if (e.key === "p") store.setTool("scribble");
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [store]);

  return (
    <div className="fixed inset-0 bg-[#fafaf7] text-ink-900">
      <div className="relative h-full w-full">
        <InfiniteCanvas store={store} containerRef={containerRef} />
      </div>
      <CanvasToolbar store={store} getSpawnPoint={getSpawnPoint} />
      <ObjectControls store={store} />
      <CanvasControls store={store} containerRef={containerRef} />
      <BrandMark />
    </div>
  );
}

function BrandMark() {
  return (
    <div className="pointer-events-none fixed bottom-4 left-4 z-40 text-[11px] font-medium uppercase tracking-[0.18em] text-ink-400">
      CanvasOS
    </div>
  );
}
