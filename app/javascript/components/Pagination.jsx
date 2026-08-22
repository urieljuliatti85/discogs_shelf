import React from "react";

function pageNumbers(current, total) {
  const pages = new Set([1, total, current, current - 1, current + 1]);
  if (current <= 3) [2, 3, 4].forEach((p) => pages.add(p));
  if (current >= total - 2) [total - 1, total - 2, total - 3].forEach((p) => pages.add(p));

  return [...pages]
    .filter((p) => p >= 1 && p <= total)
    .sort((a, b) => a - b)
    .reduce((acc, page, index, list) => {
      if (index > 0 && page - list[index - 1] > 1) acc.push("gap");
      acc.push(page);
      return acc;
    }, []);
}

export default function Pagination({ page, totalPages, onChange }) {
  if (totalPages <= 1) return null;

  const button =
    "min-w-9 rounded-lg border px-2.5 py-1.5 text-sm transition disabled:cursor-not-allowed disabled:opacity-40";

  return (
    <nav className="flex flex-wrap items-center justify-center gap-1.5 pt-8" aria-label="Paginação">
      <button
        type="button"
        className={`${button} border-ink-700 text-ink-300 hover:border-ink-500 hover:text-ink-100`}
        onClick={() => onChange(page - 1)}
        disabled={page <= 1}
      >
        Anterior
      </button>

      {pageNumbers(page, totalPages).map((entry, index) =>
        entry === "gap" ? (
          <span key={`gap-${index}`} className="px-1 text-ink-600">
            …
          </span>
        ) : (
          <button
            key={entry}
            type="button"
            aria-current={entry === page ? "page" : undefined}
            className={`${button} ${
              entry === page
                ? "border-wax-500 bg-wax-500/15 font-semibold text-wax-300"
                : "border-ink-700 text-ink-300 hover:border-ink-500 hover:text-ink-100"
            }`}
            onClick={() => onChange(entry)}
          >
            {entry}
          </button>
        )
      )}

      <button
        type="button"
        className={`${button} border-ink-700 text-ink-300 hover:border-ink-500 hover:text-ink-100`}
        onClick={() => onChange(page + 1)}
        disabled={page >= totalPages}
      >
        Próxima
      </button>
    </nav>
  );
}
