import React, { useCallback, useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { useApp } from "../AppContext";
import { useItems, useDebounced } from "../hooks/useItems";
import Filters from "../components/Filters";
import ReleaseCard from "../components/ReleaseCard";
import ReleaseRow from "../components/ReleaseRow";
import Pagination from "../components/Pagination";
import EmptyState from "../components/EmptyState";
import Spinner from "../components/Spinner";

const VIEW_STORAGE_KEY = "discogs-shelf:view";

const readStoredView = () => {
  try {
    return localStorage.getItem(VIEW_STORAGE_KEY) === "list" ? "list" : "grid";
  } catch {
    return "grid";
  }
};

export default function ItemsPage({ list, title, subtitle }) {
  const { dataVersion, sync, profile } = useApp();
  const [searchParams, setSearchParams] = useSearchParams();
  const [search, setSearch] = useState(searchParams.get("q") ?? "");
  const [view, setView] = useState(readStoredView);

  const debouncedSearch = useDebounced(search, 350);

  const filters = {
    genre: searchParams.get("genre") ?? "",
    style: searchParams.get("style") ?? "",
    media: searchParams.get("media") ?? "",
    decade: searchParams.get("decade") ?? "",
    sort: searchParams.get("sort") ?? "added_desc",
  };
  const page = Number(searchParams.get("page") ?? 1);

  // Keep ?q= in sync with the debounced input so the URL stays shareable
  // without pushing a history entry per keystroke.
  useEffect(() => {
    const current = searchParams.get("q") ?? "";
    if (current === debouncedSearch) return;

    const next = new URLSearchParams(searchParams);
    debouncedSearch ? next.set("q", debouncedSearch) : next.delete("q");
    next.delete("page");
    setSearchParams(next, { replace: true });
  }, [debouncedSearch]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    setSearch(searchParams.get("q") ?? "");
  }, [list]); // eslint-disable-line react-hooks/exhaustive-deps

  const { data, loading, error } = useItems(
    list,
    { ...filters, q: searchParams.get("q") ?? "", page },
    dataVersion
  );

  const updateParam = useCallback(
    (key, value) => {
      const next = new URLSearchParams(searchParams);
      value ? next.set(key, value) : next.delete(key);
      if (key !== "page") next.delete("page");
      setSearchParams(next);
    },
    [searchParams, setSearchParams]
  );

  const reset = useCallback(() => {
    setSearch("");
    setSearchParams(new URLSearchParams());
  }, [setSearchParams]);

  const changeView = useCallback((mode) => {
    setView(mode);
    try {
      localStorage.setItem(VIEW_STORAGE_KEY, mode);
    } catch {
      /* storage may be unavailable — the view still works for this session */
    }
  }, []);

  const goToPage = useCallback(
    (nextPage) => {
      updateParam("page", nextPage > 1 ? String(nextPage) : "");
      window.scrollTo({ top: 0, behavior: "smooth" });
    },
    [updateParam]
  );

  const items = data?.items ?? [];
  const isEmptyLibrary = !loading && !data?.pagination?.total && !searchParams.toString();

  if (error) {
    return (
      <EmptyState
        title="Não foi possível carregar os discos"
        description={error.message}
      />
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight text-ink-50">{title}</h1>
          <p className="mt-1 text-sm text-ink-400">{subtitle}</p>
        </div>
        {loading && <Spinner size={18} className="mb-1" />}
      </div>

      <Filters
        search={search}
        onSearchChange={setSearch}
        filters={filters}
        onFilterChange={updateParam}
        onReset={reset}
        facets={data?.facets}
        view={view}
        onViewChange={changeView}
        total={data?.pagination?.total ?? null}
      />

      {isEmptyLibrary ? (
        <EmptyState
          title={profile?.configured ? "Nada por aqui ainda" : "Configure seu usuário do Discogs"}
          description={
            profile?.configured
              ? "Sincronize para trazer seus discos do Discogs para o banco local."
              : "Defina DISCOGS_USERNAME no arquivo .env e reinicie o servidor."
          }
          action={
            profile?.configured && (
              <button
                type="button"
                onClick={sync.start}
                disabled={sync.isRunning}
                className="rounded-lg bg-wax-500 px-4 py-2 text-sm font-semibold text-ink-950 transition hover:bg-wax-400 disabled:opacity-50"
              >
                {sync.isRunning ? "Sincronizando…" : "Sincronizar agora"}
              </button>
            )
          }
        />
      ) : items.length === 0 && !loading ? (
        <EmptyState title="Nenhum disco corresponde aos filtros" description="Tente afrouxar a busca ou limpar os filtros." />
      ) : view === "grid" ? (
        <div
          className={`grid grid-cols-2 gap-3 transition-opacity sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 ${
            loading ? "opacity-50" : ""
          }`}
        >
          {items.map((release) => (
            <ReleaseCard key={release.item_id} release={release} />
          ))}
        </div>
      ) : (
        <div className={`divide-y divide-ink-800/70 transition-opacity ${loading ? "opacity-50" : ""}`}>
          {items.map((release) => (
            <ReleaseRow key={release.item_id} release={release} />
          ))}
        </div>
      )}

      <Pagination
        page={data?.pagination?.page ?? 1}
        totalPages={data?.pagination?.total_pages ?? 1}
        onChange={goToPage}
      />
    </div>
  );
}
