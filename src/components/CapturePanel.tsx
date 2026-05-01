import type { CaptureState } from "../types";

type Props = {
  state: CaptureState;
  imageDataUrl: string | null;
  errorMessage: string | null;
  onCapture: () => void;
  onClear: () => void;
};

const STATE_LABEL: Record<CaptureState, string> = {
  idle: "Ready to capture",
  "requesting-permission": "Choose a window…",
  capturing: "Capturing…",
  captured: "Screenshot captured",
  error: "Capture error",
};

export function CapturePanel({
  state,
  imageDataUrl,
  errorMessage,
  onCapture,
  onClear,
}: Props) {
  const busy = state === "requesting-permission" || state === "capturing";
  return (
    <section className="card flex flex-col">
      <header className="flex items-center justify-between border-b border-ink-800 px-4 py-3">
        <div className="flex items-center gap-3">
          <span
            className={
              "h-2 w-2 rounded-full " +
              (state === "captured"
                ? "bg-emerald-400"
                : state === "error"
                  ? "bg-rose-400"
                  : busy
                    ? "bg-amber-400 animate-pulse"
                    : "bg-ink-500")
            }
          />
          <span className="text-sm font-medium text-ink-100">
            {STATE_LABEL[state]}
          </span>
        </div>
        <div className="flex gap-2">
          {imageDataUrl ? (
            <button type="button" className="btn-outline" onClick={onClear}>
              Clear
            </button>
          ) : null}
          <button
            type="button"
            className="btn-primary"
            onClick={onCapture}
            disabled={busy}
          >
            {imageDataUrl ? "Capture again" : "Capture screen"}
          </button>
        </div>
      </header>

      <div className="p-4">
        {imageDataUrl ? (
          <div className="overflow-hidden rounded-md border border-ink-800 bg-ink-950">
            <img
              src={imageDataUrl}
              alt="Captured screenshot preview"
              className="block max-h-[420px] w-full object-contain"
            />
          </div>
        ) : (
          <div className="flex h-48 flex-col items-center justify-center rounded-md border border-dashed border-ink-800 bg-ink-950 text-center">
            <p className="text-sm text-ink-300">
              Click <span className="text-ink-100">Capture screen</span> to grab
              a single frame.
            </p>
            <p className="mt-1 text-xs text-ink-500">
              Capture stops the moment the screenshot is taken. Nothing runs in
              the background.
            </p>
          </div>
        )}
        {state === "error" && errorMessage ? (
          <p className="mt-3 text-sm text-rose-300">{errorMessage}</p>
        ) : null}
      </div>
    </section>
  );
}
