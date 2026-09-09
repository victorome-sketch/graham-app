# Milestone 3 log — Saved history

## What's new in the app

- **Every checklist you run is saved automatically.** Running a checklist now lands on that run's own page (`/analyses/:id`), which you can bookmark, refresh, or come back to later — the results no longer vanish on reload.
- **A History page**, one click away in the main navigation, lists every past run newest-first: ticker and company, when it ran, the "X of 7" score, and the Graham Number margin (green above the ceiling, red below, "—" when it could not be computed).
- **Past analyses reopen exactly as they were.** A saved run is a frozen snapshot: changing the revenue threshold in Settings afterwards changes future runs only, and the reopened page says which threshold that run used.
- **Re-running creates a new record beside the old one.** "Edit inputs & re-run" opens the form pre-filled from the saved run (the form says "Re-running KO — update any figures that changed, then run"); submitting saves a second analysis without touching the first.
- **Analyses can be deleted**, with a confirmation dialog, from the saved analysis page. History shows a "No analyses yet" state when the list is empty.
- The form's "Nothing is saved" note is gone; it now says every checklist is saved to History.

## What was built

**Backend**
- `db/migrate/20260908000001_create_analyses.rb` — `analyses` table: `user_id` (FK), `ticker`, `company_name`, `financial_company`, and two `jsonb` columns — `inputs` (the raw form values exactly as typed) and `result` (the computed checklist in the shape the Results page renders). Composite index on `[user_id, created_at]`.
- `app/models/analysis.rb` — `belongs_to :user`, presence validations (an empty snapshot is rejected), `newest_first` scope, `Analysis.snapshot!(user:, input:, checklist:, raw_params:)` which freezes one run, and `met_count` / `margin_pct` readers over the stored `result`.
- `app/models/user.rb` — `has_many :analyses, dependent: :destroy`; `User#time_zone` (the nullable IANA `timezone` column, falling back to the app zone).
- `app/controllers/analyses_controller.rb` — `index` (history rows), `create` (persist, then `redirect_to analysis_path`), `show` (renders `analyses/Results` from the stored `result`/`inputs` plus a `record` prop — never recomputed), `destroy` (redirect to History with a notice). All lookups go through `Current.user.analyses`, so another user's id is a 404. `analysis_summary` formats the run date server-side (`RAN_AT_FORMAT`) in the user's time zone.
- Routes: `resources :analyses, only: %i[ index new create show destroy ]`; the M1 `get "analyses" → redirect` placeholder is gone.

**Frontend**
- `app/javascript/pages/analyses/Index.tsx` — the History page: `PageHeader` with a "New analysis" action, the design system's Listings pattern (`<ul>` of row links), a `.callout` empty state, and the flash notice line.
- `app/javascript/pages/analyses/Results.tsx` — optional `record` prop; "Run on <date>" in the header; "Edit inputs & re-run" promoted to the primary action; a Delete control when the page is a saved record; the Limitations note now names the threshold "used for this run".
- `app/frontend/components/DeleteAnalysisDialog.tsx` — the first real consumer of the design-system `Dialog`: "Delete" trigger, "Delete analysis" danger confirm, `router.delete`.
- `app/javascript/pages/analyses/New.tsx` — "Nothing is saved" copy replaced; a "Re-running {TICKER} — …" description when the form arrives pre-filled with a ticker.
- `app/frontend/components/MainNav.tsx` — new "History" item (`/analyses`, lucide `History`); "New analysis" now matches only `/analyses/new`.
- `app/frontend/components/PageHeader.tsx` — action buttons wrap on narrow screens.
- `app/frontend/lib/format.ts` (the money / millions / ratio / percent formatters, moved out of Results.tsx so History and Results format the margin identically) and `app/frontend/types/analysis.ts` (`AnalysisSummary`).

**Tests** (all green: 82 unit/integration runs, 12 system runs)
- `test/models/analysis_test.rb` — snapshot columns from worked example A, exact jsonb round-trip of the Results props, nil margin when the Graham Number is not computable, financial-company N/A, `newest_first`, cascade delete, empty-snapshot validation.
- `test/controllers/analyses_controller_test.rb` — auth gate on every action; index newest-first and scoped to the current user (Inertia JSON payload); create persists + redirects (and saves nothing on invalid input); show renders the stored snapshot with the `record` prop; **show is frozen** after a Settings change; other users' records are 404 on show and delete; delete redirects with the notice (303 for Inertia requests).
- `test/system/saved_history_test.rb` — the PRD's "done when" as one browser flow: two tickers → History newest-first with scores and margins → threshold change → the old run reopens intact → re-run pre-filled → a new record computed against the new threshold beside the old → delete with the dialog (and cancel) → empty state. Screenshots in `tmp/screenshots/` (`history-*`, `results-saved-*`, `delete-dialog`, `analyses-new-rerun`, `history-empty-*`).
- `test/integration/ssr_smoke_test.rb` — also renders the saved-result header and the History page (empty and with a row) through the Node SSR server.
- `public/robots.txt` unchanged: `Disallow: /analyses` is a prefix rule and already covers the index and `/analyses/:id`. Not in sitemap/llms.txt (auth-gated).

## Decisions made during implementation (not pre-specified in the PRD)

- **Milestone 3 was built before Milestone 2.** There is no API yet, so "fresh data" can only be what the user types. Re-run is therefore the existing pre-filled "Edit inputs & re-run", which now saves a new record on submit; the form explains that it is re-running the ticker. The API-backed Re-run belongs to M2 (see below). No blank-figures button was added — it would force re-typing 17 numbers for no gain.
- **Snapshot format = the Results page's props.** `result` is exactly `{ ticker, company_name, financial_company, price, **Checklist#to_props }` (display-rounded, JSON-safe floats) and `inputs` is the raw permitted params hash. The show action renders both verbatim; nothing is recomputed on read, so Settings and engine changes never alter a saved run. Corollary: future changes to `to_props` must be additive or migrate stored rows.
- **No decimal columns for price / margin / threshold.** They would duplicate `result`, and a `BigDecimal` serialises to a JSON *string* (`"20.0"`), which breaks the frontend number formatters. `met_count` and `margin_pct` are read from `result` (floats and integers straight from jsonb).
- **`Analysis belongs_to :user`, not `Stock`.** The PRD's `Stock` model is an M2 concept; the identity fields (`ticker`, `company_name`, `financial_company`) are denormalised onto `analyses` so M2 can add `stock_id` and backfill. User scoping is cheap insurance because the starter's signup page is still open.
- **Dates are formatted on the server** (`ran_at_label`, e.g. "Sep 8, 2026, 3:42 PM", in the user's time zone with a UTC fallback) plus an ISO `ran_at` for `<time dateTime>`. A browser-locale format would render differently in the Node SSR pass and on hydration.
- **History uses the Listings pattern, not a table** (the design system has no table primitive). "X of 7" is plain figure text rather than a Badge, so no colour implies a judgement; the margin is sign-coloured exactly as on the Results page.
- **The saved-result page highlights "History" in the nav** (it lives under `/analyses/:id`); the form highlights "New analysis".
- **No pagination** — a single-user tool; add a limit or Pagy if history grows.
- **Tests build records through `Analysis.snapshot!`**, not a fixture file: `fixtures :all` would seed every test (breaking the empty state) and a hand-written jsonb fixture would drift from `to_props`.

## What milestone 2 needs to know

- **The Re-run hook is the prefill URL.** `GET /analyses/new?ticker=KO&company_name=…&financial_company=true` renders the form pre-filled (the `prefill` prop) and shows the "Re-running KO" description. M2's API lookup can intercept that request (fetch by ticker, fill the numbers, tag provenance) without touching History.
- **`Analysis.snapshot!(user:, input:, checklist:, raw_params:)`** is the single write path. Provenance tags can ride along in `inputs` (or a new jsonb column) — keep `result` additive so old rows still render.
- `analyses.ticker` / `company_name` / `financial_company` are ready to be replaced by (or paired with) a `stock_id` once `Stock` exists.

## Deviations from the PRD

- **"Re-run any ticker with fresh data"** — there is no fresh-data source until M2. Re-running is pre-filled from the saved snapshot; every submit creates a new record, which satisfies the "re-running creates a second record beside it" acceptance criterion.
- **Provenance tags are not stored** — they do not exist yet (M2). The snapshot stores the raw inputs, so tags can be added alongside them later.
- **`Analysis` belongs to a `User`, not a `Stock`** — see decisions above.

## About `_build_plan/`

This folder (the PRD and the per-milestone prompts and logs) is a temporary artifact of the initial build-out. Milestone 3 is the last planned milestone, but Milestone 2 (API fetch & caching) is still outstanding as of 2026-09-08; once it ships, the whole `_build_plan/` folder can be deleted. Nothing in the codebase references it.
