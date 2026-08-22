import React from "react";
import { Link } from "react-router-dom";
import Cover from "./Cover";
import StarRating from "./StarRating";

export default function ReleaseCard({ release }) {
  return (
    <Link
      to={`/release/${release.discogs_id}`}
      className="group animate-in flex flex-col rounded-xl border border-ink-800 bg-ink-900/60 p-3 transition hover:-translate-y-0.5 hover:border-ink-600 hover:bg-ink-800/70 focus:outline-none focus-visible:ring-2 focus-visible:ring-wax-500"
    >
      <div className="relative aspect-square w-full overflow-hidden rounded-lg">
        <Cover
          src={release.cover_url || release.thumb_url}
          alt={`Capa de ${release.title}`}
          className="h-full w-full transition duration-300 group-hover:scale-[1.03]"
        />
        {release.year && (
          <span className="absolute bottom-2 left-2 rounded-md bg-ink-950/80 px-1.5 py-0.5 text-[11px] font-medium text-ink-200 backdrop-blur">
            {release.year}
          </span>
        )}
      </div>

      <div className="mt-3 flex min-w-0 flex-1 flex-col">
        <h3 className="truncate text-sm font-semibold text-ink-50" title={release.title}>
          {release.title}
        </h3>
        <p className="truncate text-xs text-ink-400" title={release.artist}>
          {release.artist}
        </p>

        <div className="mt-auto flex items-center justify-between gap-2 pt-2">
          <span className="truncate text-[11px] text-ink-500" title={release.format_summary}>
            {release.format_summary || "—"}
          </span>
          <StarRating value={release.rating} size="text-[11px]" />
        </div>
      </div>
    </Link>
  );
}
