export type CanvasObjectType =
  | "note"
  | "image"
  | "file"
  | "link"
  | "scribble"
  | "zone";

export interface ScribbleStroke {
  points: { x: number; y: number }[];
  color: string;
  width: number;
}

export interface FileMeta {
  name: string;
  mimeType: string;
  size: number;
  dataUrl?: string;
}

export interface CanvasObject {
  id: string;
  type: CanvasObjectType;
  x: number;
  y: number;
  width: number;
  height: number;
  rotation?: number;
  locked?: boolean;
  title?: string;
  content?: string;
  url?: string;
  color?: string;
  category?: string;
  zIndex: number;
  createdAt: string;
  updatedAt: string;

  // type-specific
  strokes?: ScribbleStroke[];
  file?: FileMeta;
}

export interface Viewport {
  x: number;
  y: number;
  scale: number;
}

export type ToolMode = "select" | "scribble";

export interface CanvasState {
  objects: CanvasObject[];
  viewport: Viewport;
  selectedId: string | null;
  tool: ToolMode;
  lastSavedAt: string | null;
}
