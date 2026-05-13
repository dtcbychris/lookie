import { useState } from "react";
import type { CanvasObject } from "../canvasTypes";
import { formatBytes } from "../canvasUtils";

interface Props {
  object: CanvasObject;
  onPointerDownMove: (e: React.PointerEvent) => void;
  onUpdate: (patch: Partial<CanvasObject>) => void;
}

export function FileObject({ object, onPointerDownMove, onUpdate }: Props) {
  const [showDetail, setShowDetail] = useState(false);
  const [editingTitle, setEditingTitle] = useState(false);
  const file = object.file;
  const locked = !!object.locked;

  return (
    <>
      <div
        onPointerDown={onPointerDownMove}
        onDoubleClick={() => setShowDetail(true)}
        className={`flex h-full w-full flex-col justify-between gap-2 rounded-xl border border-ink-100 bg-white p-3 shadow-md ${
          locked ? "" : "cursor-grab active:cursor-grabbing"
        }`}
      >
        <div className="flex items-start gap-2">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-indigo-50 text-indigo-500">
            <FileIcon />
          </div>
          <div className="min-w-0 flex-1">
            {editingTitle && !locked ? (
              <input
                autoFocus
                defaultValue={object.title ?? file?.name ?? ""}
                onPointerDown={(e) => e.stopPropagation()}
                onBlur={(e) => {
                  onUpdate({ title: e.currentTarget.value });
                  setEditingTitle(false);
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter")
                    (e.target as HTMLInputElement).blur();
                  if (e.key === "Escape") setEditingTitle(false);
                }}
                className="w-full bg-transparent text-sm font-medium text-ink-900 outline-none"
              />
            ) : (
              <div
                className="truncate text-sm font-medium text-ink-900"
                onDoubleClick={(e) => {
                  e.stopPropagation();
                  if (!locked) setEditingTitle(true);
                }}
              >
                {object.title || file?.name || "Untitled file"}
              </div>
            )}
            <div className="truncate text-[11px] text-ink-500">
              {file?.mimeType || "—"}
            </div>
          </div>
        </div>
        <div className="flex items-center justify-between text-[11px] text-ink-500">
          <span>{file ? formatBytes(file.size) : ""}</span>
          <button
            type="button"
            onPointerDown={(e) => e.stopPropagation()}
            onClick={() => setShowDetail(true)}
            className="rounded px-1.5 py-0.5 text-indigo-500 hover:bg-indigo-50"
          >
            Open
          </button>
        </div>
      </div>

      {showDetail && (
        <FileDetailModal
          object={object}
          onClose={() => setShowDetail(false)}
        />
      )}
    </>
  );
}

function FileDetailModal({
  object,
  onClose,
}: {
  object: CanvasObject;
  onClose: () => void;
}) {
  const file = object.file;
  return (
    <div
      className="fixed inset-0 z-[1000] flex items-center justify-center bg-black/40"
      onPointerDown={(e) => {
        e.stopPropagation();
        onClose();
      }}
    >
      <div
        className="w-full max-w-md rounded-xl bg-white p-5 shadow-2xl"
        onPointerDown={(e) => e.stopPropagation()}
      >
        <div className="mb-3 flex items-center justify-between">
          <h3 className="text-base font-semibold text-ink-900">
            {object.title || file?.name || "File"}
          </h3>
          <button
            onClick={onClose}
            className="rounded px-2 py-1 text-sm text-ink-500 hover:bg-ink-100"
          >
            Close
          </button>
        </div>
        <dl className="space-y-1 text-sm text-ink-700">
          <Row label="Name" value={file?.name ?? "—"} />
          <Row label="Type" value={file?.mimeType || "—"} />
          <Row label="Size" value={file ? formatBytes(file.size) : "—"} />
        </dl>
        {file?.dataUrl && file.mimeType.startsWith("image/") && (
          <img
            src={file.dataUrl}
            alt={file.name}
            className="mt-3 max-h-64 w-full rounded-md object-contain"
          />
        )}
        {file?.dataUrl && (
          <a
            href={file.dataUrl}
            download={file.name}
            className="mt-3 inline-block rounded-md bg-indigo-500 px-3 py-1.5 text-sm font-medium text-white hover:bg-indigo-400"
          >
            Download
          </a>
        )}
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-2">
      <dt className="text-ink-400">{label}</dt>
      <dd className="max-w-[60%] truncate text-right">{value}</dd>
    </div>
  );
}

function FileIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-5 w-5">
      <path
        d="M7 3h7l5 5v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinejoin="round"
      />
      <path d="M14 3v5h5" stroke="currentColor" strokeWidth="1.5" />
    </svg>
  );
}
