import { useCallback, useEffect, useRef, useState } from "react";
import type {
  CanvasObject,
  CanvasState,
  ToolMode,
  Viewport,
} from "./canvasTypes";
import { maxZIndex, minZIndex, nowIso, uid } from "./canvasUtils";

const STORAGE_KEY = "canvasos.state.v1";

const DEFAULT_VIEWPORT: Viewport = { x: 0, y: 0, scale: 1 };

const DEFAULT_STATE: CanvasState = {
  objects: [],
  viewport: DEFAULT_VIEWPORT,
  selectedId: null,
  tool: "select",
  lastSavedAt: null,
};

function loadFromStorage(): CanvasState {
  if (typeof window === "undefined") return DEFAULT_STATE;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return DEFAULT_STATE;
    const parsed = JSON.parse(raw) as Partial<CanvasState>;
    return {
      objects: Array.isArray(parsed.objects) ? parsed.objects : [],
      viewport: parsed.viewport ?? DEFAULT_VIEWPORT,
      selectedId: null,
      tool: "select",
      lastSavedAt: parsed.lastSavedAt ?? null,
    };
  } catch {
    return DEFAULT_STATE;
  }
}

function saveToStorage(state: CanvasState): string {
  const stamped = nowIso();
  const toSave = {
    objects: state.objects,
    viewport: state.viewport,
    lastSavedAt: stamped,
  };
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(toSave));
  } catch {
    // ignore quota errors silently for MVP
  }
  return stamped;
}

export interface CanvasStore {
  state: CanvasState;
  setViewport: (next: Viewport | ((prev: Viewport) => Viewport)) => void;
  setTool: (tool: ToolMode) => void;
  setSelected: (id: string | null) => void;
  addObject: (partial: Omit<CanvasObject, "id" | "zIndex" | "createdAt" | "updatedAt">) => CanvasObject;
  updateObject: (id: string, patch: Partial<CanvasObject>) => void;
  deleteObject: (id: string) => void;
  duplicateObject: (id: string) => void;
  toggleLock: (id: string) => void;
  bringForward: (id: string) => void;
  sendBackward: (id: string) => void;
  clearAll: () => void;
  importState: (raw: string) => boolean;
  exportState: () => string;
}

export function useCanvasStore(): CanvasStore {
  const [state, setState] = useState<CanvasState>(() => loadFromStorage());

  // Debounced autosave
  const saveTimer = useRef<number | null>(null);
  useEffect(() => {
    if (saveTimer.current) window.clearTimeout(saveTimer.current);
    saveTimer.current = window.setTimeout(() => {
      const stamped = saveToStorage(state);
      setState((prev) =>
        prev.lastSavedAt === stamped ? prev : { ...prev, lastSavedAt: stamped },
      );
    }, 400);
    return () => {
      if (saveTimer.current) window.clearTimeout(saveTimer.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state.objects, state.viewport]);

  const setViewport = useCallback(
    (next: Viewport | ((prev: Viewport) => Viewport)) => {
      setState((prev) => ({
        ...prev,
        viewport: typeof next === "function" ? next(prev.viewport) : next,
      }));
    },
    [],
  );

  const setTool = useCallback((tool: ToolMode) => {
    setState((prev) => ({ ...prev, tool }));
  }, []);

  const setSelected = useCallback((id: string | null) => {
    setState((prev) =>
      prev.selectedId === id ? prev : { ...prev, selectedId: id },
    );
  }, []);

  const addObject = useCallback<CanvasStore["addObject"]>((partial) => {
    const now = nowIso();
    let created: CanvasObject;
    setState((prev) => {
      const z = maxZIndex(prev.objects) + 1;
      created = {
        ...partial,
        id: uid(),
        zIndex: partial.type === "zone" ? minZIndex(prev.objects) - 1 : z,
        createdAt: now,
        updatedAt: now,
      } as CanvasObject;
      return {
        ...prev,
        objects: [...prev.objects, created],
        selectedId: created.id,
      };
    });
    // @ts-expect-error created is assigned inside setState callback
    return created;
  }, []);

  const updateObject = useCallback((id: string, patch: Partial<CanvasObject>) => {
    setState((prev) => ({
      ...prev,
      objects: prev.objects.map((o) =>
        o.id === id ? { ...o, ...patch, updatedAt: nowIso() } : o,
      ),
    }));
  }, []);

  const deleteObject = useCallback((id: string) => {
    setState((prev) => ({
      ...prev,
      objects: prev.objects.filter((o) => o.id !== id),
      selectedId: prev.selectedId === id ? null : prev.selectedId,
    }));
  }, []);

  const duplicateObject = useCallback((id: string) => {
    setState((prev) => {
      const src = prev.objects.find((o) => o.id === id);
      if (!src) return prev;
      const now = nowIso();
      const copy: CanvasObject = {
        ...src,
        id: uid(),
        x: src.x + 24,
        y: src.y + 24,
        zIndex: maxZIndex(prev.objects) + 1,
        createdAt: now,
        updatedAt: now,
      };
      return {
        ...prev,
        objects: [...prev.objects, copy],
        selectedId: copy.id,
      };
    });
  }, []);

  const toggleLock = useCallback((id: string) => {
    setState((prev) => ({
      ...prev,
      objects: prev.objects.map((o) =>
        o.id === id ? { ...o, locked: !o.locked, updatedAt: nowIso() } : o,
      ),
    }));
  }, []);

  const bringForward = useCallback((id: string) => {
    setState((prev) => ({
      ...prev,
      objects: prev.objects.map((o) =>
        o.id === id
          ? { ...o, zIndex: maxZIndex(prev.objects) + 1, updatedAt: nowIso() }
          : o,
      ),
    }));
  }, []);

  const sendBackward = useCallback((id: string) => {
    setState((prev) => ({
      ...prev,
      objects: prev.objects.map((o) =>
        o.id === id
          ? { ...o, zIndex: minZIndex(prev.objects) - 1, updatedAt: nowIso() }
          : o,
      ),
    }));
  }, []);

  const clearAll = useCallback(() => {
    setState((prev) => ({ ...prev, objects: [], selectedId: null }));
  }, []);

  const importState = useCallback((raw: string): boolean => {
    try {
      const parsed = JSON.parse(raw) as Partial<CanvasState>;
      if (!Array.isArray(parsed.objects)) return false;
      setState({
        objects: parsed.objects as CanvasObject[],
        viewport: parsed.viewport ?? DEFAULT_VIEWPORT,
        selectedId: null,
        tool: "select",
        lastSavedAt: nowIso(),
      });
      return true;
    } catch {
      return false;
    }
  }, []);

  const exportState = useCallback((): string => {
    return JSON.stringify(
      { objects: state.objects, viewport: state.viewport },
      null,
      2,
    );
  }, [state.objects, state.viewport]);

  return {
    state,
    setViewport,
    setTool,
    setSelected,
    addObject,
    updateObject,
    deleteObject,
    duplicateObject,
    toggleLock,
    bringForward,
    sendBackward,
    clearAll,
    importState,
    exportState,
  };
}
