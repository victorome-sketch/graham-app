import { FormEvent, ReactNode, useEffect, useRef, useState } from "react"
import { Head, Link, useForm, usePage } from "@inertiajs/react"
import { Check } from "lucide-react"
import { AppShell } from "@/components/AppShell"
import { PageHeader } from "@/components/PageHeader"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"
import { cn } from "@/lib/utils"

import type { PageProps } from "@/types/inertia"

type Prefill = Partial<Record<string, string | boolean>>

const EPS_FIELDS = [
  { key: "eps_1", label: "Latest year" },
  { key: "eps_2", label: "1 year ago" },
  { key: "eps_3", label: "2 years ago" },
  { key: "eps_4", label: "3 years ago" },
  { key: "eps_5", label: "4 years ago" },
  { key: "eps_6", label: "5 years ago" },
  { key: "eps_7", label: "6 years ago" },
  { key: "eps_8", label: "7 years ago" },
  { key: "eps_9", label: "8 years ago" },
  { key: "eps_10", label: "9 years ago" },
] as const

type EpsKey = (typeof EPS_FIELDS)[number]["key"]

type FieldKey =
  | "ticker"
  | "company_name"
  | "price"
  | "revenue"
  | "current_assets"
  | "current_liabilities"
  | EpsKey
  | "dividend_years"
  | "bvps"

const EPS_KEYS = EPS_FIELDS.map((f) => f.key) as EpsKey[]

// Only the two balance-sheet fields depend on the financial-company switch.
const BALANCE_KEYS: FieldKey[] = ["current_assets", "current_liabilities"]

// Sections double as the supporting column's orientation list, so the numbers
// on the form and the numbers in the sidebar can never drift apart.
const SECTIONS: { index: string; title: string; keys: FieldKey[] }[] = [
  { index: "01", title: "Company", keys: ["ticker"] },
  { index: "02", title: "Financials", keys: ["price", "revenue", ...BALANCE_KEYS] },
  { index: "03", title: "Earnings per share", keys: EPS_KEYS },
  { index: "04", title: "Dividends & book value", keys: ["dividend_years", "bvps"] },
]

// Short names for the error summary — the field's own label, without units.
const FIELD_LABELS: Record<FieldKey, string> = {
  ticker: "Ticker",
  company_name: "Company name",
  price: "Share price",
  revenue: "Annual revenue",
  current_assets: "Current assets",
  current_liabilities: "Current liabilities",
  ...(Object.fromEntries(
    EPS_FIELDS.map((f) => [f.key, `EPS — ${f.label.toLowerCase()}`]),
  ) as Record<EpsKey, string>),
  dividend_years: "Consecutive years of dividends",
  bvps: "Book value per share",
}

// Summary order follows the form, not the order Rails happened to validate in.
const FIELD_ORDER: FieldKey[] = [
  "ticker",
  "company_name",
  "price",
  "revenue",
  ...BALANCE_KEYS,
  ...EPS_KEYS,
  "dividend_years",
  "bvps",
]

// The unit lives in the affix, which is decorative; screen readers get it from
// a visually-hidden suffix on the label instead.
const AFFIX_SR: Record<string, string> = {
  $: "in dollars",
  $M: "in millions of dollars",
  years: "in years",
}

// The mobile action bar is fixed over the bottom of the viewport, so a
// control scrolled to by the browser (focus, scrollIntoView, an error-summary
// link) has to reserve room beneath itself. Form padding only creates
// end-of-page space; scroll-margin is what the scroll algorithms honour.
const SCROLL_CLEAR = "scroll-mb-28 lg:scroll-mb-0"

const str = (value: string | boolean | undefined) => (typeof value === "string" ? value : "")

const fmtMillions = (value: number) =>
  `$${new Intl.NumberFormat("en-US", { maximumFractionDigits: 1 }).format(value)}M`

// The mobile action bar is fixed to the bottom of the viewport, which iOS and
// Android both park the software keyboard over. When the visual viewport
// shrinks by more than a nav bar's worth, the keyboard is up — slide the bar
// out rather than let it sit on top of the keyboard or the field being typed
// into. No visualViewport (older browsers, SSR) means the bar simply stays.
function useKeyboardOpen() {
  const [open, setOpen] = useState(false)
  useEffect(() => {
    const viewport = window.visualViewport
    if (!viewport) return
    const sync = () => setOpen(window.innerHeight - viewport.height > 120)
    viewport.addEventListener("resize", sync)
    sync()
    return () => viewport.removeEventListener("resize", sync)
  }, [])
  return open
}

type FieldOptions = {
  helper?: ReactNode
  required?: boolean
  disabled?: boolean
  inputMode?: "decimal" | "numeric" | "text"
  affix?: string
  affixSide?: "start" | "end"
  className?: string
  placeholder?: string
  optional?: boolean
}

export default function AnalysesNew({
  prefill,
  revenue_threshold,
}: {
  prefill: Prefill
  revenue_threshold: number
}) {
  const { props } = usePage<PageProps>()
  const errors = props.errors ?? {}
  // Arriving via "Edit inputs & re-run": say so, since the prefilled form
  // otherwise looks identical to a blank one.
  const rerunTicker = str(prefill.ticker).trim().toUpperCase()
  const keyboardOpen = useKeyboardOpen()

  const form = useForm({
    ticker: str(prefill.ticker),
    company_name: str(prefill.company_name),
    financial_company: prefill.financial_company === true || prefill.financial_company === "true",
    price: str(prefill.price),
    revenue: str(prefill.revenue),
    current_assets: str(prefill.current_assets),
    current_liabilities: str(prefill.current_liabilities),
    ...(Object.fromEntries(EPS_FIELDS.map((f) => [f.key, str(prefill[f.key])])) as Record<EpsKey, string>),
    dividend_years: str(prefill.dividend_years),
    bvps: str(prefill.bvps),
  })

  const financial = form.data.financial_company

  const submit = (e: FormEvent) => {
    e.preventDefault()
    form.post("/analyses")
  }

  // ---- Completion, per section --------------------------------------------
  // A financial company doesn't owe the two balance-sheet values, so they drop
  // out of the denominator as well as out of the form.
  const sectionStatus = SECTIONS.map((section) => {
    const keys = section.keys.filter((key) => !(financial && BALANCE_KEYS.includes(key)))
    return {
      ...section,
      done: keys.filter((key) => form.data[key].trim() !== "").length,
      total: keys.length,
    }
  })
  const filledCount = sectionStatus.reduce((n, s) => n + s.done, 0)
  const totalCount = sectionStatus.reduce((n, s) => n + s.total, 0)

  // ---- Error summary -------------------------------------------------------
  const errorEntries = FIELD_ORDER.filter((key) => errors[key]).map((key) => ({
    key,
    label: FIELD_LABELS[key],
    message: errors[key] as string,
  }))
  const errorSignature = errorEntries.map((e) => e.key).join(",")
  const summaryRef = useRef<HTMLDivElement>(null)
  useEffect(() => {
    if (errorSignature) summaryRef.current?.focus()
  }, [errorSignature])

  // "Ready to run" is a claim, so only make it when it's true: everything
  // required is present and no validation error is outstanding.
  const ready = filledCount === totalCount && errorEntries.length === 0

  // ---- Field renderers -----------------------------------------------------
  const field = (key: FieldKey, label: string, options: FieldOptions = {}) => {
    const {
      helper,
      required = true,
      disabled = false,
      inputMode = "decimal",
      affix,
      affixSide = "start",
      className,
      placeholder,
      optional = false,
    } = options
    const value = form.data[key]
    const error = errors[key]
    const describedBy = error ? `${key}-error` : helper ? `${key}-helper` : undefined

    const control = (
      <Input
        id={key}
        inputMode={inputMode === "text" ? undefined : inputMode}
        required={required && !disabled}
        disabled={disabled}
        aria-invalid={!!error}
        aria-describedby={describedBy}
        placeholder={placeholder}
        className={cn(SCROLL_CLEAR, className)}
        value={value}
        onChange={(e) => form.setData(key, e.target.value)}
      />
    )

    return (
      <div className="space-y-2">
        {/* Nothing in this label depends on the field's value — labels must not
            move or change while the user is typing into them. */}
        <label htmlFor={key}>
          {label}
          {affix && AFFIX_SR[affix] && <span className="sr-only"> {AFFIX_SR[affix]}</span>}
          {optional && <span className="ml-1 text-xs font-normal text-ink-muted">{" "}optional</span>}
        </label>
        {affix ? (
          <div className="field-affix">
            {affixSide === "start" && (
              <span aria-hidden="true" className="field-affix-start">
                {affix}
              </span>
            )}
            {control}
            {affixSide === "end" && (
              <span aria-hidden="true" className="field-affix-end">
                {affix}
              </span>
            )}
          </div>
        ) : (
          control
        )}
        {error && (
          <p id={`${key}-error`} className="text-xs text-danger-display">
            {error}
          </p>
        )}
        {helper && !error && (
          <p id={`${key}-helper`} className="text-xs text-ink-muted">
            {helper}
          </p>
        )}
      </div>
    )
  }

  // One ledger line per fiscal year: label left, right-aligned tabular value
  // right, hairline between rows. Two columns wherever the content column is
  // wide enough for a year label beside a 7.5rem field — which the sidebar
  // takes away at `lg` and gives back at `xl`.
  const epsRow = (f: (typeof EPS_FIELDS)[number]) => {
    const error = errors[f.key]
    return (
      <div
        key={f.key}
        className="grid grid-cols-[minmax(0,1fr)_7.5rem] items-center gap-x-3 gap-y-1 border-t border-hairline py-2"
      >
        <label htmlFor={f.key}>
          {f.label}
          <span className="sr-only"> earnings per share in dollars</span>
        </label>
        <div className="field-affix">
          <span aria-hidden="true" className="field-affix-start">
            $
          </span>
          <Input
            id={f.key}
            className={SCROLL_CLEAR}
            inputMode="decimal"
            required
            aria-invalid={!!error}
            aria-describedby={error ? `${f.key}-error` : undefined}
            value={form.data[f.key]}
            onChange={(e) => form.setData(f.key, e.target.value)}
          />
        </div>
        {error && (
          <p id={`${f.key}-error`} className="col-start-2 text-right text-xs text-danger-display">
            {error}
          </p>
        )}
      </div>
    )
  }

  const sectionHead = (index: string, title: string) => (
    <legend className="mb-4 w-full">
      <span className="form-section-head">
        <span className="form-section-index">{index}</span>
        <span className="form-section-title">{title}</span>
        <span aria-hidden="true" className="form-section-rule" />
      </span>
    </legend>
  )

  return (
    <>
      <Head title="New analysis">
        <meta
          name="description"
          content="Enter a stock's financials by hand and check them against Benjamin Graham's seven defensive-investor criteria."
        />
        <meta property="og:title" content="New analysis" />
        <meta
          property="og:description"
          content="Enter a stock's financials by hand and check them against Benjamin Graham's seven defensive-investor criteria."
        />
      </Head>
      <AppShell>
        <PageHeader
          title="New analysis"
          description={
            rerunTicker
              ? `Re-running ${rerunTicker} — update any figures that changed, then run. This creates a new saved analysis.`
              : "Enter a stock's financials to check Graham's seven defensive-investor criteria."
          }
        />

        <form
          onSubmit={submit}
          className="mt-8 grid grid-cols-1 gap-10 pb-24 lg:grid-cols-[minmax(0,1fr)_15rem] lg:items-start lg:gap-8 lg:pb-0 xl:gap-12"
        >
          <div className="min-w-0 space-y-8">
            {/* One statement, once — instead of a "required" flag that appears
                and disappears from ten labels as the user types. */}
            <p className="text-xs text-ink-muted">
              Every field is required unless marked optional.
            </p>

            {/* 01 — Company ------------------------------------------------ */}
            <fieldset className="min-w-0">
              {sectionHead("01", "Company")}
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-[9rem_minmax(0,1fr)]">
                {field("ticker", "Ticker", {
                  inputMode: "text",
                  className: "uppercase",
                  placeholder: "KO",
                })}
                {field("company_name", "Company name", {
                  inputMode: "text",
                  required: false,
                  optional: true,
                })}
              </div>

              <div
                className={cn(
                  "mt-4 flex gap-3 rounded-lg border p-4 transition-colors",
                  financial ? "border-accent/40 bg-accent-faded" : "border-hairline bg-surface",
                )}
              >
                <Checkbox
                  id="financial_company"
                  className={cn("mt-1", SCROLL_CLEAR)}
                  checked={financial}
                  onChange={(e) => form.setData("financial_company", e.target.checked)}
                  aria-describedby="financial_company-helper"
                />
                <div className="min-w-0">
                  <label htmlFor="financial_company">
                    This is a financial company (bank or insurer)
                  </label>
                  <p id="financial_company-helper" className="mt-1 text-xs text-ink-muted">
                    Graham never fails banks and insurers on the current-ratio test — rule 2 reports
                    N/A and the two balance-sheet fields below are skipped.
                  </p>
                </div>
              </div>
            </fieldset>

            {/* 02 — Financials --------------------------------------------- */}
            <fieldset className="min-w-0">
              {sectionHead("02", "Financials")}
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 sm:gap-x-5">
                {field("price", "Share price", { affix: "$" })}
                {field("revenue", "Annual revenue", {
                  affix: "$M",
                  helper: (
                    <>
                      Rule 1 currently requires at least {fmtMillions(revenue_threshold)} — change it
                      in <Link href="/settings">Settings</Link>.
                    </>
                  ),
                })}
              </div>
              <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 sm:gap-x-5">
                {field("current_assets", "Current assets", { affix: "$M", disabled: financial })}
                {field("current_liabilities", "Current liabilities", {
                  affix: "$M",
                  disabled: financial,
                })}
              </div>
              <p className="mt-3 text-xs text-ink-muted">
                {financial
                  ? "Skipped — you marked this as a financial company, so rule 2 reports N/A."
                  : "Rule 2 needs current assets ÷ current liabilities to be at least 2."}
              </p>
            </fieldset>

            {/* 03 — Earnings per share -------------------------------------- */}
            <fieldset className="min-w-0">
              {sectionHead("03", "Earnings per share")}
              <p className="mb-1 text-xs text-ink-muted">
                Diluted EPS for each of the last 10 fiscal years, newest first. Negative values are
                allowed.
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 sm:gap-x-8 lg:grid-cols-1 xl:grid-cols-2">
                {EPS_FIELDS.map(epsRow)}
              </div>
            </fieldset>

            {/* 04 — Dividends & book value ---------------------------------- */}
            <fieldset className="min-w-0">
              {sectionHead("04", "Dividends & book value")}
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 sm:gap-x-5">
                {field("dividend_years", "Consecutive years of dividends", {
                  inputMode: "numeric",
                  affix: "years",
                  affixSide: "end",
                  helper: "Rule 4 requires at least 20.",
                })}
                {field("bvps", "Book value per share", {
                  affix: "$",
                  helper: "Negative values are allowed.",
                })}
              </div>
            </fieldset>
          </div>

          {/* Supporting column — completion, errors, and (from `lg`) the
              primary action. Sticky on large screens; folds into the end of
              the flow below it, where the fixed bar carries the action. */}
          <aside className="space-y-4 lg:sticky lg:top-8 lg:self-start">
            <div data-testid="progress-card" className="callout">
              <p className="font-mono text-xs uppercase tracking-widest text-ink-muted">
                {ready ? "Ready to run" : "Input progress"}
              </p>
              <p className="mt-2 flex items-baseline gap-2">
                <span className="figure-lg text-ink-display">{filledCount}</span>
                <span className="figure font-display text-lg font-medium text-ink-muted">
                  of {totalCount}
                </span>
              </p>
              <p className="text-sm text-ink-muted">required values entered</p>
              <div aria-hidden="true" className="mt-3 h-1 overflow-hidden rounded-full bg-hairline">
                <span
                  className="block h-full rounded-full bg-accent transition-[width] duration-200"
                  style={{ width: `${totalCount ? (filledCount / totalCount) * 100 : 0}%` }}
                />
              </div>
              <ul className="mt-4 space-y-2 border-t border-hairline pt-4">
                {sectionStatus.map((s) => (
                  <li
                    key={s.index}
                    className="grid grid-cols-[minmax(0,1fr)_auto] items-baseline gap-3 text-sm"
                  >
                    <span className="text-ink-muted">
                      <span className="figure font-mono text-xs">{s.index}</span> {s.title}
                    </span>
                    {s.done === s.total ? (
                      <span className="inline-flex items-center gap-1 text-xs text-affirm-display">
                        <Check aria-hidden="true" className="h-3 w-3" strokeWidth={3} />
                        done
                      </span>
                    ) : (
                      <span className="figure font-mono text-xs text-ink-muted">
                        {s.done}/{s.total}
                      </span>
                    )}
                  </li>
                ))}
              </ul>
            </div>

            {errorEntries.length > 0 && (
              <div
                ref={summaryRef}
                tabIndex={-1}
                role="alert"
                aria-labelledby="error-summary-heading"
                className="callout callout-danger border-danger/30 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-danger focus-visible:ring-offset-2 focus-visible:ring-offset-page"
              >
                <p id="error-summary-heading" className="text-sm font-medium text-danger-display">
                  {errorEntries.length === 1
                    ? "1 field needs attention"
                    : `${errorEntries.length} fields need attention`}
                </p>
                <ul className="mt-2 space-y-1.5 text-sm">
                  {errorEntries.map((entry) => (
                    <li key={entry.key}>
                      <a
                        href={`#${entry.key}`}
                        className="underline underline-offset-2"
                        onClick={(e) => {
                          e.preventDefault()
                          document.getElementById(entry.key)?.focus()
                        }}
                      >
                        {entry.label}
                      </a>{" "}
                      <span className="text-ink-muted">{entry.message}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}

            <div className="hidden lg:block">
              <Button type="submit" size="lg" className="w-full" disabled={form.processing}>
                {form.processing ? "Running checklist…" : "Run checklist"}
              </Button>
              <p className="mt-2 text-xs text-ink-muted">
                Every checklist you run is saved to History — reopen or delete it there later.
              </p>
            </div>
            <p className="text-xs text-ink-muted lg:hidden">
              Every checklist you run is saved to History — reopen or delete it there later.
            </p>
          </aside>

          {/* Mobile action bar. Last in the DOM, so it is also last in the tab
              order; the form reserves `pb-24` beneath its content for it. */}
          <div
            data-testid="mobile-action-bar"
            className={cn(
              "fixed inset-x-0 bottom-0 z-30 border-t border-hairline bg-page px-4 pt-3 transition-transform duration-150 lg:hidden",
              keyboardOpen && "translate-y-full",
            )}
            style={{ paddingBottom: "max(0.75rem, env(safe-area-inset-bottom))" }}
          >
            <div className="flex items-center gap-4">
              <p className="min-w-0 flex-1 truncate text-xs text-ink-muted">
                <span className="figure font-mono text-ink-display">
                  {filledCount} of {totalCount}
                </span>{" "}
                entered
              </p>
              <Button type="submit" disabled={form.processing}>
                {form.processing ? "Running…" : "Run checklist"}
              </Button>
            </div>
          </div>
        </form>
      </AppShell>
    </>
  )
}
