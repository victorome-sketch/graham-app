# Milestone 1 log — Rules engine, manual entry only

## What's new in the app

- **Run a Graham checklist on any stock by typing in its financials.** Logging in now lands you straight on a "New analysis" form — enter ticker, price, revenue, current assets/liabilities, 10 years of EPS, dividend years, and book value, then hit "Run checklist."
- **A full results screen with a verdict for every rule.** Each of Graham's 7 defensive-investor criteria shows Pass / Fail / N/A with the actual numbers behind it in plain language (e.g. "Current ratio is 2.50; at least 2 is required"), plus an "X of 7 criteria met" summary.
- **The Graham Number next to the current price**, with the margin % and the formula shown — presented as information only, never a buy/sell signal.
- **Financial companies handled the Graham way.** Tick "This is a financial company" and the current-ratio rule shows N/A (never failed), the assets/liabilities fields switch off, and the company can still reach 7 of 7.
- **A configurable revenue threshold.** The Settings page now has the rule-1 revenue minimum (default $700M); change it and the next checklist run uses the new bar.
- **"Edit inputs & re-run"** on the results screen takes you back to the form with everything pre-filled.
- **A limitations note on every result** — 1970s thresholds, the financial-company N/A rule, the configurable threshold, and "not investment advice."

## What was built

**Backend**
- `app/models/graham/analysis_input.rb` — parses/validates the raw form params into typed BigDecimals; error keys match the form field names exactly (they surface via Inertia's shared `errors` prop).
- `app/models/graham/checklist.rb` — the rules engine: 7 `RuleResult`s (`Data.define`, verdict `:pass/:fail/:na` + values + machine `reason` key), counts, Graham Number, and `to_props` (JSON-safe, display-rounded floats). All copy lives in the frontend; the engine emits numbers/verdicts/reason keys only.
- `app/models/setting.rb` + `db/migrate/20260423000006_create_settings.rb` — single-row `settings` table, `revenue_threshold_millions` decimal(12,2) default 700, `Setting.instance` accessor (`first_or_create!`).
- `app/controllers/analyses_controller.rb` — `new` (renders form with `prefill` + `revenue_threshold` props), `create` (valid → `render inertia: "analyses/Results"` with the computed checklist, invalid → redirect back with the error hash). Nothing is persisted.
- `SettingsController` — `show` now passes the threshold; new `update` follows the profiles mutation idiom.
- Routes: `resources :analyses, only: %i[ new create ]`, `get "analyses" → redirect("/analyses/new")` (hard-refresh guard for the transient results page), `patch "settings"`. The `dashboard` route/controller/page were **removed** — the analysis form is the post-login home (`after_authentication_url`, `pages#home`, and signup redirect all point at `new_analysis_path`).

**Frontend**
- `app/javascript/pages/analyses/New.tsx` — the form: fieldset groups, 10-field EPS grid (2-col mobile / 5-col desktop), "— required until filled" label markers, financial-company checkbox that disables CA/CL, threshold helper linking Settings, `inputMode="decimal"` text inputs.
- `app/javascript/pages/analyses/Results.tsx` — summary callout, Graham Number callout (neutral, no color-coding), the 7 rules as a listings-style list with verdict Badges, limitations callout, "Edit inputs & re-run" links carrying the raw inputs as query params.
- `app/javascript/pages/Settings.tsx` — replaced the placeholder with the threshold form.
- `MainNav.tsx` — nav item is now "New analysis" (ListChecks icon); brand link points at `/analyses/new`.
- **Design-system addition:** `danger` Badge tone (`.badge-danger` in `design-system.css`, cva tone in `ui/badge.tsx`, showcased in the Badges section). Verdict mapping: pass=accent, fail=danger, na=muted.

**Tests** (all green: 68 unit/integration runs + 2 system runs)
- `test/models/graham/checklist_test.rb` — worked examples A ("STL", 7/7, GN $30.00, margin +20.0%), B (financial N/A, 7/7 met), C ("JUNK", 1/7, margin −200.0%), every boundary inclusive-pass (ratio 2, growth 33%, P/E 15, P/B 1.5, product 22.5), and all non-computable edges.
- `test/models/graham/analysis_input_test.rb`, `test/models/setting_test.rb`, `test/controllers/analyses_controller_test.rb` (POST success is an intentional 200 Inertia render), `test/controllers/settings_controller_test.rb`.
- `test/system/analysis_flow_test.rb` — end-to-end browser flow incl. financial-company variant and threshold flip; saves verification screenshots to `tmp/screenshots/`. (`Capybara.default_max_wait_time` raised to 5s in `application_system_test_case.rb` — the 2s default flaked on first-load warmup.)
- `public/robots.txt`: `Disallow: /dashboard` → `Disallow: /analyses`. Not in sitemap/llms.txt (auth-gated).

## Decisions made during implementation (not pre-specified in the PRD)

- **Units:** aggregate money fields (revenue, current assets/liabilities, threshold) are entered and stored in **$ millions**; per-share fields (price, EPS, BVPS) in dollars.
- **Dividend record input** is a single integer "consecutive years of dividends paid" (0–99); rule 4 passes at ≥ 20. (User-confirmed choice over a yes/no toggle or 20 checkboxes.)
- **"X of 7 met" counts N/A as met** (`met_count = rules not failed`), so a financial company can reach 7 of 7; the summary appends "(includes N not-applicable, counted as met)". The policy is isolated in one engine method.
- **Growth threshold is exactly 33%** (`GROWTH_MIN = BigDecimal("0.33")`) per the PRD, not Graham's one-third. One constant to change.
- **Edge-case semantics:** rule 5 is `:na` (reason `base_avg_not_positive`) when the years-8–10 average EPS ≤ 0 — growth from a non-positive base is undefined, and such a company always fails rule 3 anyway. Rule 6 is a hard `fail` when the 3-year average EPS ≤ 0. Rule 7 gates on BVPS > 0 before either branch (a negative P/B would absurdly pass "P/B ≤ 1.5"). Graham Number requires latest EPS > 0 AND BVPS > 0 (a negative×negative product does not sneak through the square root).
- **Verdicts compare unrounded BigDecimals; displays round** (ratios 2dp, percentages 1dp, money 2dp) in `Checklist#to_props`, which also converts everything to JSON-safe floats (BigDecimal would serialize as a string and break the frontend formatters).
- **Graham Number margin is plain neutral text** — no green/red — per the "information, never a signal" rule.

## What milestone 2 needs to know

- **The API-prefill hook already exists:** `AnalysesController#new` accepts any subset of the form fields as query params and passes them to the page as the `prefill` prop ("Edit inputs & re-run" uses this today). M2's ticker lookup can reuse the same prop or replace it with a fetch flow.
- **The field contract** is `AnalysesController::PERMITTED_FIELDS` (ticker, company_name, financial_company, price, revenue, current_assets, current_liabilities, eps_1..eps_10 newest-first, dividend_years, bvps). `Graham::AnalysisInput` is the single validation/typing layer — extend it rather than adding a parallel path.
- **Provenance tags (api/manual) intentionally don't exist yet** — everything is manual in M1. The engine takes plain values, so tags will be a form/UI + input-layer concern.
- **`get "analyses" → redirect` is a placeholder** for M3's real index. `#create` renders Results transiently; M3 turns this into persist + redirect to a show page (the Results page's props shape in `Checklist#to_props` is the natural snapshot format).
- **Threshold access:** `Setting.instance.revenue_threshold_millions` (BigDecimal, $ millions). Room for more columns on the singleton row.
- `financial_company` arrives as a real boolean from Inertia JSON posts but as the string `"true"` from prefill query params — `AnalysisInput` casts with `ActiveModel::Type::Boolean`; keep that in mind for API-sourced params.

## Deviations from the PRD

- **None in scope.** One addition beyond the letter of the PRD: the Dashboard stub was removed and the analysis form made the post-login home (user-approved), which also touched `robots.txt` and two existing test files.
- Rule 5's `:na`-on-undefined-base is a refinement of the PRD's pass/fail framing for one degenerate input combination (see decisions above); it can never inflate a score past what rule 3 already caps.

## Post-milestone changes (2026-09-08)

Everything below landed after this log was written. `_build_plan/prd.html` was reconciled to the shipped app on 2026-09-08 and is the source of truth wherever this log disagrees with it.

- **Results page rebuilt to the design handoff (Phase 1, `c205772`).** The Graham Number margin is now **colored by sign** — affirm below the ceiling, danger above — beside a ceiling-vs-price bar, with the caption "information only, never a signal"; the "plain neutral text, no green/red" decision recorded above no longer holds. The summary shows "X of 7 criteria met" with a seven-tick verdict strip, a "Fails rules 2, 6 and 7" line and the N/A-counted-as-met note; each rule renders as a plain-language outcome with its arithmetic alongside; the inputs recap is a collapsible "Inputs used" section (open by default on desktop); the limitations callout gained "Nothing here is investment advice."
- **New analysis form rebuilt to the design handoff (Phase 2, `a3b76a5`).** Four numbered sections (Company · Financials · Earnings per share · Dividends & book value) with unit affixes ($, $M, years). The per-label "— required until filled" markers are gone: one statement ("Every field is required unless marked optional"; company name is the only optional field) plus a live progress panel — "N of M required values entered", a done mark per section, "Ready to run" only when complete and error-free. Server-side errors come back as a summary whose links focus the failing field. Below `lg` a fixed bottom bar carries the count and the submit button and hides while the on-screen keyboard is open. The field contract, `AnalysisInput`, routes and controller are unchanged; the design system gained the "Field affix" and "Form sections" entries.
- **PRD reconciled (`b6382bf`).** Status pills (Shipped / Planned / Not started) on every feature, model and milestone; the rules table now states the engine's units, inclusive thresholds and edge cases; two M2 notes were added — the provider's annual EPS series fills the ten newest-first fields, and its dividend history collapses to the form's single "consecutive years of dividends paid" number.
- **CI and test infrastructure (`8e33bba`, `debb4f2`).** CI prebuilds the Vite test bundle (`RAILS_ENV=test bin/vite build --clear`) before both test jobs so parallel workers don't race on the manifest; Brakeman is pinned current and ignores the Rails 8.0 end-of-life warning via `config/brakeman.ignore` pending a Rails upgrade (due before 2026-11-07); the headless Chrome test profile disables the password manager, whose breach dialog for the fixture password "password" was silently swallowing keyboard and mouse input mid-test.
