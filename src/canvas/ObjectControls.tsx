import type { CanvasStore } from "./useCanvasStore";

interface Props {
  store: CanvasStore;
}

export function ObjectControls({ store }: Props) {
  const { state, toggleLock, duplicateObject, deleteObject, bringForward, sendBackward } =
    store;
  const selected = state.objects.find((o) => o.id === state.selectedId);
  if (!selected) return null;

  return (
    <div className="pointer-events-auto fixed left-1/2 top-4 z-50 flex -translate-x-1/2 items-center gap-1 rounded-xl border border-ink-200/70 bg-white/95 p-1 shadow-lg backdrop-blur">
      <span className="px-2 text-xs font-medium uppercase tracking-wider text-ink-400">
        {selected.type}
      </span>
      <Divider />
      <Btn
        label={selected.locked ? "Unlock" : "Lock"}
        onClick={() => toggleLock(selected.id)}
        active={selected.locked}
      />
      <Btn label="Duplicate" onClick={() => duplicateObject(selected.id)} />
      <Btn label="Forward" onClick={() => bringForward(selected.id)} />
      <Btn label="Backward" onClick={() => sendBackward(selected.id)} />
      <Btn
        label="Delete"
        danger
        onClick={() => deleteObject(selected.id)}
      />
    </div>
  );
}

function Divider() {
  return <div className="mx-0.5 h-5 w-px bg-ink-200" />;
}

function Btn({
  label,
  onClick,
  active,
  danger,
}: {
  label: string;
  onClick: () => void;
  active?: boolean;
  danger?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`rounded-md px-2 py-1 text-xs font-medium transition ${
        active
          ? "bg-amber-500 text-white"
          : danger
            ? "text-red-500 hover:bg-red-50"
            : "text-ink-700 hover:bg-ink-100"
      }`}
    >
      {label}
    </button>
  );
}
