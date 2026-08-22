import React from "react";
import { Link } from "react-router-dom";
import { useApp } from "../AppContext";
import Spinner from "../components/Spinner";

function StatCard({ label, value, hint }) {
  return (
    <div className="animate-in rounded-xl border border-ink-800 bg-ink-900/50 p-4">
      <p className="text-[11px] uppercase tracking-wider text-ink-500">{label}</p>
      <p className="mt-1 text-3xl font-semibold tabular-nums text-ink-50">
        {value?.toLocaleString("pt-BR") ?? "—"}
      </p>
      {hint && <p className="mt-1 text-xs text-ink-500">{hint}</p>}
    </div>
  );
}

function BarList({ title, rows, linkFor, formatLabel = (row) => row.value }) {
  if (!rows?.length) return null;
  const max = Math.max(...rows.map((row) => row.count));

  return (
    <section className="animate-in rounded-xl border border-ink-800 bg-ink-900/50 p-4">
      <h2 className="mb-3 text-sm font-semibold text-ink-200">{title}</h2>
      <ul className="space-y-2">
        {rows.map((row) => {
          const content = (
            <>
              <span className="relative z-10 truncate pr-3">{formatLabel(row)}</span>
              <span className="relative z-10 shrink-0 text-xs tabular-nums text-ink-400">{row.count}</span>
              <span
                aria-hidden
                className="absolute inset-y-0 left-0 rounded-md bg-wax-500/15"
                style={{ width: `${(row.count / max) * 100}%` }}
              />
            </>
          );

          const className =
            "relative flex items-center justify-between overflow-hidden rounded-md px-2 py-1.5 text-sm text-ink-200 transition hover:text-wax-300";

          return (
            <li key={String(row.value)}>
              {linkFor ? (
                <Link to={linkFor(row)} className={className}>
                  {content}
                </Link>
              ) : (
                <div className={className}>{content}</div>
              )}
            </li>
          );
        })}
      </ul>
    </section>
  );
}

export default function StatsPage() {
  const { profile, loading } = useApp();

  if (loading || !profile) {
    return (
      <div className="flex justify-center py-24">
        <Spinner size={28} />
      </div>
    );
  }

  const stats = profile.stats ?? {};

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-ink-50">Estatísticas</h1>
        <p className="mt-1 text-sm text-ink-400">Um retrato da sua prateleira no Discogs.</p>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Na coleção" value={stats.collection_count} hint="itens (inclui duplicatas)" />
        <StatCard label="Lista de desejos" value={stats.wantlist_count} hint="discos que você quer" />
        <StatCard label="Artistas" value={stats.artist_count} hint="distintos na coleção" />
        <StatCard label="Lançamentos" value={stats.release_count} hint="registros únicos no banco" />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <BarList
          title="Gêneros mais presentes"
          rows={stats.top_genres}
          linkFor={(row) => `/?genre=${encodeURIComponent(row.value)}`}
        />
        <BarList
          title="Artistas com mais discos"
          rows={stats.top_artists}
          linkFor={(row) => `/?q=${encodeURIComponent(row.value)}`}
        />
        <BarList
          title="Formatos"
          rows={stats.top_formats}
          linkFor={(row) => `/?media=${encodeURIComponent(row.value)}`}
        />
        <BarList
          title="Por década"
          rows={stats.decades}
          formatLabel={(row) => `Anos ${row.value}`}
          linkFor={(row) => `/?decade=${row.value}`}
        />
      </div>
    </div>
  );
}
