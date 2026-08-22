import React from "react";
import { SearchIcon, GridIcon, ListIcon, CloseIcon } from "./Icons";

const SORT_OPTIONS = [
  { value: "added_desc", label: "Adicionados recentemente" },
  { value: "added_asc", label: "Adicionados primeiro" },
  { value: "artist_asc", label: "Artista (A–Z)" },
  { value: "artist_desc", label: "Artista (Z–A)" },
  { value: "title_asc", label: "Título (A–Z)" },
  { value: "year_desc", label: "Ano (mais novo)" },
  { value: "year_asc", label: "Ano (mais antigo)" },
  { value: "rating_desc", label: "Melhor avaliados" },
];

const selectClass =
  "min-w-0 rounded-lg border border-ink-700 bg-ink-900 px-2.5 py-2 text-sm text-ink-200 transition hover:border-ink-500 focus:border-wax-500 focus:outline-none";

function FacetSelect({ label, value, options, onChange, formatLabel = (o) => o.value }) {
  if (!options?.length) return null;

  return (
    <label className="flex min-w-0 items-center">
      <span className="sr-only">{label}</span>
      <select className={selectClass} value={value} onChange={(event) => onChange(event.target.value)}>
        <option value="">{label}</option>
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {formatLabel(option)} ({option.count})
          </option>
        ))}
      </select>
    </label>
  );
}

export default function Filters({ search, onSearchChange, filters, onFilterChange, onReset, facets, view, onViewChange, total }) {
  const activeFilters = [
    filters.genre && { key: "genre", label: filters.genre },
    filters.style && { key: "style", label: filters.style },
    filters.media && { key: "media", label: filters.media },
    filters.decade && { key: "decade", label: `Anos ${filters.decade}` },
  ].filter(Boolean);

  return (
    <div className="space-y-3">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
        <div className="relative flex-1">
          <SearchIcon
            size={16}
            className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-500"
          />
          <input
            type="search"
            value={search}
            onChange={(event) => onSearchChange(event.target.value)}
            placeholder="Buscar por título, artista, gravadora ou catálogo…"
            className="w-full rounded-lg border border-ink-700 bg-ink-900 py-2 pl-9 pr-3 text-sm text-ink-100 placeholder:text-ink-500 transition focus:border-wax-500 focus:outline-none"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <FacetSelect label="Gênero" value={filters.genre} options={facets?.genres} onChange={(v) => onFilterChange("genre", v)} />
          <FacetSelect label="Estilo" value={filters.style} options={facets?.styles} onChange={(v) => onFilterChange("style", v)} />
          <FacetSelect label="Formato" value={filters.media} options={facets?.formats} onChange={(v) => onFilterChange("media", v)} />
          <FacetSelect
            label="Década"
            value={filters.decade}
            options={facets?.decades}
            onChange={(v) => onFilterChange("decade", v)}
            formatLabel={(option) => `${option.value}s`}
          />

          <select
            className={selectClass}
            value={filters.sort}
            onChange={(event) => onFilterChange("sort", event.target.value)}
          >
            {SORT_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>

          <div className="flex overflow-hidden rounded-lg border border-ink-700">
            {[
              { mode: "grid", Icon: GridIcon, label: "Grade" },
              { mode: "list", Icon: ListIcon, label: "Lista" },
            ].map(({ mode, Icon, label }) => (
              <button
                key={mode}
                type="button"
                title={label}
                aria-pressed={view === mode}
                onClick={() => onViewChange(mode)}
                className={`px-2.5 py-2 transition ${
                  view === mode ? "bg-wax-500/20 text-wax-300" : "text-ink-400 hover:bg-ink-800 hover:text-ink-200"
                }`}
              >
                <Icon size={16} />
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2 text-xs text-ink-400">
        <span className="tabular-nums">
          {total === null || total === undefined ? "…" : `${total.toLocaleString("pt-BR")} disco${total === 1 ? "" : "s"}`}
        </span>

        {activeFilters.map((filter) => (
          <button
            key={filter.key}
            type="button"
            onClick={() => onFilterChange(filter.key, "")}
            className="inline-flex items-center gap-1 rounded-full border border-ink-700 bg-ink-800/70 py-0.5 pl-2.5 pr-1.5 text-ink-200 transition hover:border-ink-500"
          >
            {filter.label}
            <CloseIcon size={12} />
          </button>
        ))}

        {(activeFilters.length > 0 || search) && (
          <button type="button" onClick={onReset} className="text-wax-400 underline-offset-2 hover:underline">
            limpar tudo
          </button>
        )}
      </div>
    </div>
  );
}
