import type { AnalysisItem } from "../types";

type Props = {
  items: AnalysisItem[];
  activeId: string | null;
  onSelect: (item: AnalysisItem) => void;
  onDelete: (id: string) => void;
};

export function HistoryList({ items, activeId, onSelect, onDelete }: Props) {
  if (items.length === 0) {
    return (
      <section className="card p-4 text-xs text-ink-500">
        No analyses yet for this project.
      </section>
    );
  }

  return (
    <section className="card divide-y divide-ink-800">
      {items.map((item) => {
        const isActive = item.id === activeId;
        return (
          <div
            key={item.id}
            className={
              "flex items-start gap-3 px-4 py-3 text-sm transition " +
              (isActive ? "bg-ink-800/60" : "hover:bg-ink-900")
            }
          >
            <button
              type="button"
              onClick={() => onSelect(item)}
              className="flex-1 text-left"
            >
              <div className="line-clamp-1 text-ink-100">
                {item.question || "(no question)"}
              </div>
              <div className="mt-0.5 line-clamp-1 text-xs text-ink-500">
                {item.response.summary}
              </div>
              <div className="mt-1 text-[11px] text-ink-600">
                {new Date(item.createdAt).toLocaleString()}
                {item.imageDataUrl ? " · screenshot saved" : ""}
              </div>
            </button>
            <button
              type="button"
              className="text-xs text-ink-500 hover:text-rose-300"
              onClick={() => onDelete(item.id)}
              aria-label="Delete analysis"
            >
              ✕
            </button>
          </div>
        );
      })}
    </section>
  );
}
