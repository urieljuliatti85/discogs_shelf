import React from "react";
import { useApp } from "../AppContext";
import { SyncIcon } from "./Icons";
import Spinner from "./Spinner";

const STAGE_LABELS = { collection: "coleção", wantlist: "lista de desejos", done: "pronto" };

export default function SyncButton() {
  const { sync, profile } = useApp();
  const { status, isRunning, start } = sync;

  const disabled = isRunning || !profile?.configured;

  return (
    <div className="flex items-center gap-3">
      {isRunning && status?.total_count > 0 && (
        <div className="hidden items-center gap-2 sm:flex">
          <div className="h-1.5 w-28 overflow-hidden rounded-full bg-ink-800">
            <div
              className="h-full rounded-full bg-wax-500 transition-all duration-500"
              style={{ width: `${status.progress}%` }}
            />
          </div>
          <span className="text-xs tabular-nums text-ink-400">
            {status.synced_count}/{status.total_count} · {STAGE_LABELS[status.stage] ?? ""}
          </span>
        </div>
      )}

      <button
        type="button"
        onClick={start}
        disabled={disabled}
        title={profile?.configured ? "Buscar dados atualizados no Discogs" : "Configure DISCOGS_USERNAME primeiro"}
        className="inline-flex items-center gap-2 rounded-lg border border-ink-700 bg-ink-900 px-3 py-2 text-sm font-medium text-ink-200 transition hover:border-wax-500 hover:text-wax-300 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {isRunning ? <Spinner size={15} /> : <SyncIcon size={16} />}
        <span className="hidden sm:inline">{isRunning ? "Sincronizando…" : "Sincronizar"}</span>
      </button>
    </div>
  );
}
