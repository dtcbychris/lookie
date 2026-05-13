import type { CanvasObject, Viewport } from "./canvasTypes";

export function uid(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
}

export function nowIso(): string {
  return new Date().toISOString();
}

export function screenToCanvas(
  clientX: number,
  clientY: number,
  containerRect: DOMRect,
  viewport: Viewport,
): { x: number; y: number } {
  const sx = clientX - containerRect.left;
  const sy = clientY - containerRect.top;
  return {
    x: (sx - viewport.x) / viewport.scale,
    y: (sy - viewport.y) / viewport.scale,
  };
}

export function clampScale(scale: number): number {
  return Math.min(4, Math.max(0.1, scale));
}

export function maxZIndex(objects: CanvasObject[]): number {
  return objects.reduce((max, o) => (o.zIndex > max ? o.zIndex : max), 0);
}

export function minZIndex(objects: CanvasObject[]): number {
  if (objects.length === 0) return 0;
  return objects.reduce((min, o) => (o.zIndex < min ? o.zIndex : min), Infinity);
}

export function computeBoundingBox(objects: CanvasObject[]): {
  x: number;
  y: number;
  width: number;
  height: number;
} | null {
  if (objects.length === 0) return null;
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const o of objects) {
    if (o.x < minX) minX = o.x;
    if (o.y < minY) minY = o.y;
    if (o.x + o.width > maxX) maxX = o.x + o.width;
    if (o.y + o.height > maxY) maxY = o.y + o.height;
  }
  return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
}

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024)
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

export function fileToDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}
