import React, { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { api } from "../api";
import Cover from "../components/Cover";
import StarRating from "../components/StarRating";
import Spinner from "../components/Spinner";
import EmptyState from "../components/EmptyState";
import { ArrowLeftIcon, ExternalIcon, DiscIcon, HeartIcon } from "../components/Icons";

const formatDate = (value) =>
  value ? new Date(value).toLocaleDateString("pt-BR", { day: "2-digit", month: "long", year: "numeric" }) : null;

function Meta({ label, children }) {
  if (!children) return null;
  return (
    <div>
      <dt className="text-[11px] uppercase tracking-wider text-ink-500">{label}</dt>
      <dd className="mt-0.5 text-sm text-ink-200">{children}</dd>
    </div>
  );
}

function Chip({ children, to }) {
  const className =
    "inline-flex rounded-full border border-ink-700 bg-ink-900/70 px-2.5 py-0.5 text-xs text-ink-300 transition hover:border-wax-500 hover:text-wax-300";
  return to ? (
    <Link to={to} className={className}>
      {children}
    </Link>
  ) : (
    <span className={className}>{children}</span>
  );
}

export default function ReleasePage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [release, setRelease] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setRelease(null);

    api
      .release(id, controller.signal)
      .then((payload) => {
        setRelease(payload);
        setError(null);
      })
      .catch((err) => {
        if (err.name !== "AbortError") setError(err);
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });

    return () => controller.abort();
  }, [id]);

  if (loading) {
    return (
      <div className="flex justify-center py-24">
        <Spinner size={28} />
      </div>
    );
  }

  if (error) {
    return (
      <EmptyState
        title="Disco não encontrado"
        description={
          error.status === 404
            ? "Este lançamento não está na sua coleção nem na sua lista de desejos. Sincronize e tente de novo."
            : error.message
        }
        action={
          <Link to="/" className="rounded-lg bg-wax-500 px-4 py-2 text-sm font-semibold text-ink-950 hover:bg-wax-400">
            Voltar para a coleção
          </Link>
        }
      />
    );
  }

  const owned = release.in_collection ? release.collection : null;
  const wanted = release.in_wantlist ? release.wantlist : null;

  return (
    <article className="animate-in space-y-8">
      <button
        type="button"
        onClick={() => navigate(-1)}
        className="inline-flex items-center gap-2 text-sm text-ink-400 transition hover:text-ink-100"
      >
        <ArrowLeftIcon size={16} /> Voltar
      </button>

      <header className="grid gap-6 md:grid-cols-[16rem_minmax(0,1fr)] lg:grid-cols-[20rem_minmax(0,1fr)]">
        <div className="space-y-3">
          <Cover
            src={release.cover_url || release.thumb_url}
            alt={`Capa de ${release.title}`}
            className="aspect-square w-full shadow-2xl shadow-black/50"
            rounded="rounded-xl"
          />

          <div className="flex flex-wrap gap-2">
            {owned && (
              <span className="inline-flex items-center gap-1.5 rounded-full bg-emerald-500/15 px-2.5 py-1 text-xs font-medium text-emerald-300">
                <DiscIcon size={13} /> Na coleção
              </span>
            )}
            {wanted && (
              <span className="inline-flex items-center gap-1.5 rounded-full bg-wax-500/15 px-2.5 py-1 text-xs font-medium text-wax-300">
                <HeartIcon size={13} /> Na lista de desejos
              </span>
            )}
          </div>

          <a
            href={release.discogs_url}
            target="_blank"
            rel="noreferrer"
            className="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-ink-700 py-2 text-sm text-ink-200 transition hover:border-wax-500 hover:text-wax-300"
          >
            Ver no Discogs <ExternalIcon size={14} />
          </a>
        </div>

        <div className="min-w-0 space-y-5">
          <div>
            <p className="text-base text-ink-300">{release.artist}</p>
            <h1 className="mt-1 text-3xl font-semibold leading-tight tracking-tight text-ink-50">
              {release.title}
            </h1>
            <p className="mt-2 text-sm text-ink-400">
              {[release.released || release.year, release.format_summary, release.country]
                .filter(Boolean)
                .join(" · ")}
            </p>
          </div>

          <div className="flex flex-wrap gap-1.5">
            {release.genres?.map((genre) => (
              <Chip key={genre} to={`/?genre=${encodeURIComponent(genre)}`}>
                {genre}
              </Chip>
            ))}
            {release.styles?.map((style) => (
              <Chip key={style} to={`/?style=${encodeURIComponent(style)}`}>
                {style}
              </Chip>
            ))}
          </div>

          <dl className="grid grid-cols-2 gap-x-6 gap-y-4 sm:grid-cols-3">
            <Meta label="Gravadora">
              {release.labels?.map((label) => label.name).filter(Boolean).join(", ")}
            </Meta>
            <Meta label="Catálogo">{release.catno}</Meta>
            <Meta label="País">{release.country}</Meta>
            <Meta label="Adicionado em">{formatDate(owned?.date_added ?? wanted?.date_added)}</Meta>
            <Meta label="Sua nota">
              {(owned?.rating || wanted?.rating) ? <StarRating value={owned?.rating || wanted?.rating} /> : null}
            </Meta>
            <Meta label="Comunidade">
              {release.community?.rating
                ? `${Number(release.community.rating).toFixed(2)} (${release.community.rating_count})`
                : null}
            </Meta>
            <Meta label="Têm / querem">
              {release.community?.have != null ? `${release.community.have} / ${release.community.want}` : null}
            </Meta>
            <Meta label="Menor preço">
              {release.lowest_price ? `$ ${Number(release.lowest_price).toFixed(2)}` : null}
            </Meta>
            <Meta label="À venda">{release.num_for_sale || null}</Meta>
          </dl>

          {(owned?.notes?.length > 0 || wanted?.notes) && (
            <div className="rounded-xl border border-ink-800 bg-ink-900/50 p-4">
              <p className="text-[11px] uppercase tracking-wider text-ink-500">Suas anotações</p>
              <p className="mt-1 whitespace-pre-line text-sm text-ink-200">
                {wanted?.notes ?? owned?.notes?.map((note) => note.value).join("\n")}
              </p>
            </div>
          )}
        </div>
      </header>

      {release.tracklist?.length > 0 && (
        <section>
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-ink-400">Faixas</h2>
          <ol className="divide-y divide-ink-800/70 overflow-hidden rounded-xl border border-ink-800">
            {release.tracklist.map((track, index) => (
              <li
                key={`${track.position}-${index}`}
                className={`flex items-baseline gap-4 px-4 py-2.5 text-sm ${
                  track.type === "heading" ? "bg-ink-900/70 font-medium text-ink-300" : "text-ink-100"
                }`}
              >
                <span className="w-10 shrink-0 text-xs tabular-nums text-ink-500">{track.position}</span>
                <span className="min-w-0 flex-1">
                  {track.title}
                  {track.artists?.length > 0 && (
                    <span className="text-ink-500"> — {track.artists.join(", ")}</span>
                  )}
                </span>
                <span className="shrink-0 text-xs tabular-nums text-ink-500">{track.duration}</span>
              </li>
            ))}
          </ol>
        </section>
      )}

      {release.videos?.length > 0 && (
        <section>
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-ink-400">Vídeos</h2>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {release.videos.map((video) => (
              <a
                key={video.uri}
                href={video.uri}
                target="_blank"
                rel="noreferrer"
                className="group flex gap-3 rounded-xl border border-ink-800 bg-ink-900/50 p-3 transition hover:border-ink-600"
              >
                {video.youtube_id && (
                  <img
                    src={`https://i.ytimg.com/vi/${video.youtube_id}/mqdefault.jpg`}
                    alt=""
                    loading="lazy"
                    referrerPolicy="no-referrer"
                    className="h-14 w-24 shrink-0 rounded-md bg-ink-800 object-cover"
                  />
                )}
                <span className="min-w-0">
                  <span className="line-clamp-2 text-sm text-ink-200 group-hover:text-wax-300">{video.title}</span>
                  <span className="mt-1 block text-[11px] text-ink-500">{video.duration}</span>
                </span>
              </a>
            ))}
          </div>
        </section>
      )}

      {release.notes && (
        <section>
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-ink-400">Notas do lançamento</h2>
          <p className="whitespace-pre-line rounded-xl border border-ink-800 bg-ink-900/50 p-4 text-sm leading-relaxed text-ink-300">
            {release.notes}
          </p>
        </section>
      )}

      {!release.details_available && (
        <p className="text-xs text-ink-600">
          Detalhes completos (faixas, vídeos) não puderam ser buscados no Discogs agora.
        </p>
      )}
    </article>
  );
}
