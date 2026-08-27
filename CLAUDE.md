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

`.github/workflows/ci.yml` runs on push to `main` and on every PR: `bin/rubocop -f github`,
the frontend build (`npm run build` + `build:css`, which nothing else verifies since
`app/assets/builds` is gitignored), and `bin/rails db:test:prepare` + `bin/rails test`.
The test job installs Node as well as Ruby on purpose — see the note on `db:test:prepare`
below. It deliberately does not repeat the scans in `security.yml`.

`.github/workflows/security.yml` runs the three vulnerability scans on push to `main`,
on every PR, and weekly (advisory databases move without the code moving): bundler-audit
against a freshly pulled ruby-advisory-db, brakeman, and `npm audit --audit-level=high`.
Suppressions live in `config/bundler-audit.yml` and `config/brakeman.ignore`.

`.githooks/pre-commit` runs `bin/rubocop -f github` over the whole project and then
`bin/rails db:test:prepare` + `bin/rails test`; `bin/setup` activates it with
`git config core.hooksPath .githooks`, since hooks don't come with a clone. Bypass a
single commit with `git commit --no-verify`. The test step passes trivially today —
`bin/rails test` still works with the railtie commented out, it just finds 0 tests.

`bin/rails db:test:prepare` shells out to esbuild and tailwindcss. With no `test:prepare`
task defined (that railtie again), jsbundling-rails and cssbundling-rails fall back to
enhancing `db:test:prepare` with `javascript:build` and `css:build` — so anything that
prepares the test database needs npm packages installed, not just gems.

`bin/dev` exports `PORT=3001`, so the app is at <http://localhost:3001>. Plain
`bin/rails server` falls back to Puma's 3000 — use `bin/dev` unless you mean 3000.

There is no test suite: `rails/test_unit/railtie` is commented out in `config/application.rb`, there is no `test/` directory, and `bin/ci` runs no test step (the pre-commit hook calls `bin/rails test`, but it has nothing to run). Don't claim a change is "tested" from a green `bin/ci`. Note also that `bin/ci` shells out to `yarn audit` even though dependencies are managed with npm.

Config lives in `.env` (loaded by dotenv in dev/test): `DISCOGS_USERNAME` required, `DISCOGS_TOKEN` optional.

## Architecture

Rails 8 API + a React 19 SPA served from a single ERB page. SQLite is the only datastore.

**The local DB is the source of truth for browsing.** Discogs is contacted only during an explicit sync, plus a lazy per-release detail fetch. Every search, filter, facet, sort and stat is a SQLite query. Don't add Discogs calls to list endpoints.

**Sync (`app/services/discogs/`)** — `Client` is a `Net::HTTP` wrapper that paginates via `each_page`, retries with backoff, and sleeps when the `X-Discogs-Ratelimit-Remaining` header nears zero (a big collection gets slower rather than failing). `ReleaseMapper` turns a Discogs `basic_information` blob into `Release` attributes. `Sync` is a **mirror**: it upserts everything it sees, then deletes collection/wantlist rows it did not see and orphaned `Release` rows. It reports progress by writing to a `SyncRun` row. The app never writes to Discogs.

`DiscogsSyncJob` runs `Sync` in the background (Active Job `:async` in development, Solid Queue in production). `POST /api/sync` refuses to start a second run while `SyncRun.running?`; that guard only looks at runs created in the last hour, so a run killed mid-flight stops blocking after an hour instead of wedging sync forever. The frontend `useSync` hook polls `GET /api/sync` every 1.5s only while a run is in flight, then bumps `dataVersion` in `AppContext` so every mounted list refetches.

**Release details are a cache, not sync output.** Tracklists, videos, images and community stats are not in the collection payload, so `Api::ReleasesController` fetches them per release and stores them in the `releases.details` JSON column with a 30-day TTL (`Release#details_stale?`). A failed fetch is logged and swallowed — the endpoint still renders whatever is cached, and `details_available` tells the UI which case it got.

**Facets and JSON columns** — `genres`, `styles`, `formats`, `labels`, `artists` are JSON array columns on `releases`. Filtering and faceting use SQLite's `json_each` / `json_extract` (see the scopes and `Release.facet` in `app/models/release.rb`) rather than substring matching. `Release::FACETS` is a whitelist: `facet` interpolates its `path`/`column` into raw SQL, so only add entries there, never pass caller input into that expression. Decades are *not* a `FACETS` entry — they are an integer-division group (`(releases.year / 10) * 10`) written out separately in `ItemsController#decades_for` and `ProfileController#stats`.

**Shared list pipeline** — collection and wantlist are the same code path. `ItemsController` (routed twice via `defaults: { list: ... }`) picks the join model, and `ItemsQuery` does filtering, sorting, and pagination for both. `ItemsQuery#filtered` is the unpaginated scope reused for facet counts, so facet counts reflect the other active filters. Sorting keys live in `ItemsQuery::SORTS`; a `nil` value there means the key is handled by a raw-SQL branch in `apply_sort` — the text sorts use `COLLATE NOCASE` and the year sorts push NULLs last, which a hash order can't express.

The two join models are not symmetrical: `collection_items` are keyed by Discogs `instance_id` (the same release can be in the collection twice) with `notes` as a JSON array, while `wantlist_items` are unique per `release_id` with `notes` as text.

**Serializers** — `app/serializers/` is the only definition of the JSON payload shape; controllers never build hashes by hand. `ReleaseSerializer.summary` is what lists return, `.detail` is the release page, and `ItemSerializer` wraps a summary with the per-item fields (`rating`, `date_added`, `notes`). Add a field there, not in a controller.

**Errors** — `Api::BaseController` maps `Discogs::*` exceptions to JSON status codes. `rescue_from` matches in reverse declaration order, so the `Discogs::Error` catch-all must stay declared *before* its subclasses. CSRF protection is skipped for GETs only; `api.js` sends `X-CSRF-Token` from the layout's meta tag on `POST /api/sync`.

**Frontend (`app/javascript/`)** — esbuild bundles `application.jsx` to `app/assets/builds/`, served by Propshaft; Tailwind v4 compiles `application.tailwind.css` to the same directory. There is no `tailwind.config.js` — the palette (`ink-*`, `wax-*`), fonts and template `@source` paths are declared in the `@theme` block of that CSS file. React Router owns all non-API paths, and a catch-all route in `config/routes.rb` re-serves the SPA shell for deep links (paths containing a dot are excluded so missing assets 404). All list state (`q`, `genre`, `style`, `media`, `decade`, `sort`, `page`) lives in the URL query string — keep new filters there, not in component state. `ItemsPage` is mounted twice with a `key` per list so switching lists remounts instead of reusing state. `app/javascript/api.js` is the only place that talks to the backend.

## Conventions

- User-facing strings — API error messages, rake task output, UI copy — are in **Brazilian Portuguese**. Code, identifiers, and comments are in English.
- Comments in this codebase explain non-obvious *why* (SQLite quirks, rate limits, ordering constraints). Match that; skip narration.
- Ruby style is rubocop-rails-omakase (note the `[ a, b ]` array spacing).
