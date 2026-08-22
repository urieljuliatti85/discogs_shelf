import React from "react";
import { Link } from "react-router-dom";
import Cover from "./Cover";
import StarRating from "./StarRating";

const formatDate = (value) =>
  value ? new Date(value).toLocaleDateString("pt-BR", { day: "2-digit", month: "short", year: "numeric" }) : "—";

export default function ReleaseRow({ release }) {
  return (
    <Link
      to={`/release/${release.discogs_id}`}
      className="animate-in grid grid-cols-[3rem_minmax(0,2.2fr)_minmax(0,1.1fr)_4rem_minmax(0,1fr)] items-center gap-3 rounded-lg border border-transparent px-2 py-2 transition hover:border-ink-700 hover:bg-ink-800/60 focus:outline-none focus-visible:ring-2 focus-visible:ring-wax-500 sm:gap-4"
    >
      <Cover
        src={release.thumb_url || release.cover_url}
        alt={`Capa de ${release.title}`}
        className="h-12 w-12"
        rounded="rounded-md"
      />

      <div className="min-w-0">
        <p className="truncate text-sm font-medium text-ink-50">{release.title}</p>
        <p className="truncate text-xs text-ink-400">{release.artist}</p>
      </div>

      <div className="hidden min-w-0 sm:block">
        <p className="truncate text-xs text-ink-300">{release.label || "—"}</p>
        <p className="truncate text-[11px] text-ink-500">{release.catno}</p>
      </div>

      <span className="text-xs tabular-nums text-ink-300">{release.year || "—"}</span>

      <div className="flex min-w-0 items-center justify-end gap-3">
        <StarRating value={release.rating} size="text-[11px]" />
        <span className="hidden truncate text-[11px] text-ink-500 md:inline">
          {formatDate(release.date_added)}
        </span>
      </div>
    </Link>
  );
}
