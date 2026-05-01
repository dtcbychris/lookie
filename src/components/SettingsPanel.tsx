import type { AppSettings } from "../types";

type Props = {
  settings: AppSettings;
  onChange: (next: AppSettings) => void;
};

export function SettingsPanel({ settings, onChange }: Props) {
  function setPrivacy<K extends keyof AppSettings["privacy"]>(
    key: K,
    value: AppSettings["privacy"][K],
  ) {
    onChange({
      ...settings,
      privacy: { ...settings.privacy, [key]: value },
    });
  }

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6 px-8 py-10">
      <header>
        <h1 className="text-xl font-semibold text-ink-50">Settings & Privacy</h1>
        <p className="mt-1 text-sm text-ink-400">
          Builder Copilot is user-controlled. Capture only happens when you
          click <span className="text-ink-100">Capture screen</span>, and the
          screen-share stream stops the moment the screenshot is taken.
        </p>
      </header>

      <section className="card divide-y divide-ink-800">
        <Toggle
          label="Save screenshots"
          description="Store the captured image alongside each analysis. Off by default."
          checked={settings.privacy.saveScreenshots}
          onChange={(v) => setPrivacy("saveScreenshots", v)}
        />
        <Toggle
          label="Save chat history"
          description="Keep questions and responses in local history per project."
          checked={settings.privacy.saveChatHistory}
          onChange={(v) => setPrivacy("saveChatHistory", v)}
        />
        <Toggle
          label="Auto-redact sensitive text"
          description="Placeholder for MVP. Redaction is not yet active — do not rely on it."
          checked={settings.privacy.autoRedact}
          onChange={(v) => setPrivacy("autoRedact", v)}
          disabled
        />
        <LockedRow
          label="Never capture in the background"
          description="Locked on. Capture is always manual and stops immediately after one frame."
        />
        <LockedRow
          label="Capture mode"
          description="Manual only. There is no watch mode in the MVP."
        />
      </section>

      <section className="card p-5">
        <div className="label mb-2">AI provider</div>
        <p className="mb-3 text-sm text-ink-400">
          Choose <span className="text-ink-100">mock</span> for local-only
          testing. The other providers expect a backend at{" "}
          <code className="rounded bg-ink-950 px-1 text-xs">/api/analyze</code>{" "}
          that holds the API key.
        </p>
        <div className="flex flex-wrap gap-2">
          {(["mock", "openai", "anthropic"] as const).map((p) => (
            <button
              key={p}
              type="button"
              onClick={() => onChange({ ...settings, provider: p })}
              className={
                "rounded-md border px-3 py-1.5 text-xs transition " +
                (settings.provider === p
                  ? "border-indigo-400 bg-indigo-500/15 text-indigo-100"
                  : "border-ink-700 text-ink-300 hover:bg-ink-900")
              }
            >
              {p}
            </button>
          ))}
        </div>
      </section>

      <section className="card p-5 text-xs text-ink-500">
        <p>
          <span className="text-ink-300">How storage works:</span> projects,
          settings, and history are saved in your browser&apos;s localStorage.
          Nothing leaves your device unless you set the provider to a remote
          option.
        </p>
      </section>
    </div>
  );
}

function Toggle({
  label,
  description,
  checked,
  onChange,
  disabled,
}: {
  label: string;
  description: string;
  checked: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <label
      className={
        "flex cursor-pointer items-start gap-4 px-5 py-4 " +
        (disabled ? "opacity-60" : "")
      }
    >
      <input
        type="checkbox"
        className="mt-1 h-4 w-4 accent-indigo-500"
        checked={checked}
        disabled={disabled}
        onChange={(e) => onChange(e.target.checked)}
      />
      <div>
        <div className="text-sm font-medium text-ink-100">{label}</div>
        <div className="text-xs text-ink-400">{description}</div>
      </div>
    </label>
  );
}

function LockedRow({
  label,
  description,
}: {
  label: string;
  description: string;
}) {
  return (
    <div className="flex items-start gap-4 px-5 py-4">
      <div className="mt-1 rounded bg-emerald-500/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-emerald-300">
        Locked on
      </div>
      <div>
        <div className="text-sm font-medium text-ink-100">{label}</div>
        <div className="text-xs text-ink-400">{description}</div>
      </div>
    </div>
  );
}
