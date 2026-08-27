import React from "react";
import { NavLink, Outlet, Link } from "react-router-dom";
import { useApp } from "../AppContext";
import { DiscIcon, HeartIcon, ChartIcon } from "./Icons";
import SyncButton from "./SyncButton";

const NAV = [
  { to: "/", label: "Coleção", Icon: DiscIcon, end: true },
  { to: "/wantlist", label: "Lista de desejos", Icon: HeartIcon },
  { to: "/stats", label: "Estatísticas", Icon: ChartIcon },
];

export default function Layout() {
  const { profile, sync } = useApp();

  return (
    <div className="mx-auto flex min-h-full w-full max-w-7xl flex-col px-4 pb-16 sm:px-6">
      <header className="sticky top-0 z-20 -mx-4 mb-6 border-b border-ink-800/80 bg-ink-950/85 px-4 py-3 backdrop-blur-md sm:-mx-6 sm:px-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Link to="/" className="group flex items-center gap-2.5">
            <img
              src="/images/dekslayer.png"
              alt="DeksLayer"
              className="h-12 w-auto max-w-[12rem] object-contain transition-opacity group-hover:opacity-80"
            />
            <span className="leading-tight">
              <span className="block text-sm font-semibold tracking-tight text-ink-50">Discogs Shelf</span>
              <span className="block text-[11px] text-ink-500">
                {profile?.username ? `@${profile.username}` : "sem usuário configurado"}
              </span>
            </span>
          </Link>

          <nav className="order-3 flex w-full gap-1 sm:order-2 sm:w-auto">
            {NAV.map(({ to, label, Icon, end }) => (
              <NavLink
                key={to}
                to={to}
                end={end}
                className={({ isActive }) =>
                  `inline-flex flex-1 items-center justify-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition sm:flex-none ${
                    isActive
                      ? "bg-ink-800 text-ink-50"
                      : "text-ink-400 hover:bg-ink-900 hover:text-ink-200"
                  }`
                }
              >
                <Icon size={16} />
                <span className="hidden sm:inline">{label}</span>
                <span className="sm:hidden">{label.split(" ")[0]}</span>
              </NavLink>
            ))}
          </nav>

          <div className="order-2 sm:order-3">
            <SyncButton />
          </div>
        </div>
      </header>

      {sync.status?.status === "failed" && (
        <div className="mb-5 rounded-xl border border-red-900/60 bg-red-950/40 px-4 py-3 text-sm text-red-200">
          <strong className="font-semibold">A última sincronização falhou.</strong>{" "}
          {sync.status.error_message}
        </div>
      )}

      <main className="flex-1">
        <Outlet />
      </main>

      <footer className="mt-12 border-t border-ink-800/70 pt-5 text-xs text-ink-600">
        Dados de{" "}
        <a href="https://www.discogs.com" target="_blank" rel="noreferrer" className="text-ink-400 hover:text-wax-400">
          Discogs
        </a>
        {profile?.last_sync && (
          <> · última sincronização em {new Date(profile.last_sync).toLocaleString("pt-BR")}</>
        )}
      </footer>
    </div>
  );
}
