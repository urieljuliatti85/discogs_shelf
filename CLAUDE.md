# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bin/setup              # bundle + npm install + db:prepare, then execs bin/dev
bin/setup --skip-server
bin/dev                # Foreman: rails server + esbuild --watch + tailwind --watch
bin/rails discogs:check # verify DISCOGS_USERNAME/DISCOGS_TOKEN against the API
bin/rails discogs:sync  # run a full sync synchronously in the terminal
bin/rubocop            # rubocop-rails-omakase
bin/brakeman
bin/ci                 # setup + rubocop + bundler-audit + yarn audit + brakeman
npm run build          # esbuild once (bundles app/javascript/application.jsx)
npm run build:css      # tailwind once
```

There is no test suite: `rails/test_unit/railtie` is commented out in `config/application.rb`, there is no `test/` directory, and `bin/ci` runs no test step. Don't claim a change is "tested" from a green `bin/ci`. Note also that `bin/ci` shells out to `yarn audit` even though dependencies are managed with npm.

Config lives in `.env` (loaded by dotenv in dev/test): `DISCOGS_USERNAME` required, `DISCOGS_TOKEN` optional.

## Architecture

Rails 8 API + a React 19 SPA served from a single ERB page. SQLite is the only datastore.

**The local DB is the source of truth for browsing.** Discogs is contacted only during an explicit sync, plus a lazy per-release detail fetch. Every search, filter, facet, sort and stat is a SQLite query. Don't add Discogs calls to list endpoints.

**Sync (`app/services/discogs/`)** — `Client` is a `Net::HTTP` wrapper that paginates via `each_page`, retries with backoff, and sleeps when the `X-Discogs-Ratelimit-Remaining` header nears zero (a big collection gets slower rather than failing). `ReleaseMapper` turns a Discogs `basic_information` blob into `Release` attributes. `Sync` is a **mirror**: it upserts everything it sees, then deletes collection/wantlist rows it did not see and orphaned `Release` rows. It reports progress by writing to a `SyncRun` row. The app never writes to Discogs.

`DiscogsSyncJob` runs `Sync` in the background (Active Job `:async` in development, Solid Queue in production). `POST /api/sync` refuses to start a second run while `SyncRun.running?`; the frontend `useSync` hook polls `GET /api/sync` every 1.5s only while a run is in flight, then bumps `dataVersion` in `AppContext` so every mounted list refetches.

**Facets and JSON columns** — `genres`, `styles`, `formats`, `labels`, `artists` are JSON array columns on `releases`. Filtering and faceting use SQLite's `json_each` / `json_extract` (see the scopes and `Release.facet` in `app/models/release.rb`) rather than substring matching. `Release::FACETS` is a whitelist: `facet` interpolates its `path`/`column` into raw SQL, so only add entries there, never pass caller input into that expression.

**Shared list pipeline** — collection and wantlist are the same code path. `ItemsController` (routed twice via `defaults: { list: ... }`) picks the join model, and `ItemsQuery` does filtering, sorting, and pagination for both. `ItemsQuery#filtered` is the unpaginated scope reused for facet counts, so facet counts reflect the other active filters. Sorting keys live in `ItemsQuery::SORTS`; the text sorts use `COLLATE NOCASE` and year sorts push NULLs last, so they are raw-SQL branches rather than hash orders.

**Errors** — `Api::BaseController` maps `Discogs::*` exceptions to JSON status codes. `rescue_from` matches in reverse declaration order, so the `Discogs::Error` catch-all must stay declared *before* its subclasses.

**Frontend (`app/javascript/`)** — esbuild bundles `application.jsx` to `app/assets/builds/`, served by Propshaft; Tailwind v4 compiles `application.tailwind.css` to the same directory. React Router owns all non-API paths, and a catch-all route in `config/routes.rb` re-serves the SPA shell for deep links (paths containing a dot are excluded so missing assets 404). All list state (`q`, `genre`, `style`, `media`, `decade`, `sort`, `page`) lives in the URL query string — keep new filters there, not in component state. `app/javascript/api.js` is the only place that talks to the backend.

## Conventions

- User-facing strings — API error messages, rake task output, UI copy — are in **Brazilian Portuguese**. Code, identifiers, and comments are in English.
- Comments in this codebase explain non-obvious *why* (SQLite quirks, rate limits, ordering constraints). Match that; skip narration.
- Ruby style is rubocop-rails-omakase (note the `[ a, b ]` array spacing).
