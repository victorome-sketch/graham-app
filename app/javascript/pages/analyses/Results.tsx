import { useEffect, useRef } from "react"
import { Head, Link } from "@inertiajs/react"
import { Check, ChevronRight, Minus, X } from "lucide-react"
import { AppShell } from "@/components/AppShell"
import { PageHeader } from "@/components/PageHeader"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { DataRow, DataTable } from "@/components/ui/data-table"
import { cn } from "@/lib/utils"

type Verdict = "pass" | "fail" | "na"

type Rule =
  | { key: "adequate_size"; verdict: Verdict; reason: string | null; values: { revenue: number; threshold: number } }
  | {
      key: "financial_condition"
      verdict: Verdict
      reason: string | null
      values: { current_ratio: number | null; current_assets: number | null; current_liabilities: number | null }
    }
  | { key: "earnings_stability"; verdict: Verdict; reason: string | null; values: { positive_years: number } }
  | {
      key: "dividend_record"
      verdict: Verdict
      reason: string | null
      values: { dividend_years: number; required_years: number }
    }
  | {
      key: "earnings_growth"
      verdict: Verdict
      reason: string | null
      values: { recent_avg: number; old_avg: number; growth_pct: number | null }
    }
  | {
      key: "moderate_pe"
      verdict: Verdict
      reason: string | null
      values: { pe: number | null; avg_eps: number; price_limit: number | null }
    }
  | {
      key: "moderate_pb"
      verdict: Verdict
      reason: string | null
      values: { pb: number | null; pe: number | null; pe_times_pb: number | null }
    }

type Analysis = {
  ticker: string
  company_name: string | null
  financial_company: boolean
  price: number
  rules: Rule[]
  pass_count: number
  fail_count: number
  na_count: number
  met_count: number
  graham_number: {
    computable: boolean
    value: number | null
    margin_pct: number | null
    eps_used: number
    bvps_used: number
  }
  revenue_threshold: number
}

const RULE_TITLES: Record<Rule["key"], string> = {
  adequate_size: "1. Adequate size",
  financial_condition: "2. Strong financial condition",
  earnings_stability: "3. Earnings stability",
  dividend_record: "4. Dividend record",
  earnings_growth: "5. Earnings growth",
  moderate_pe: "6. Moderate P/E",
  moderate_pb: "7. Moderate P/B",
}

// Graham's numbering, keyed by rule so the summary line and the meter never
// have to parse the "1. " prefix out of RULE_TITLES.
const RULE_NUMBERS: Record<Rule["key"], number> = {
  adequate_size: 1,
  financial_condition: 2,
  earnings_stability: 3,
  dividend_record: 4,
  earnings_growth: 5,
  moderate_pe: 6,
  moderate_pb: 7,
}

const VERDICT_TONE = { pass: "affirm", fail: "danger", na: "muted" } as const
const VERDICT_LABEL = { pass: "Pass", fail: "Fail", na: "N/A" } as const

// Marks are decorative (glyph shape + hue); the Badge beside each title and
// the summary line carry the same information as text.
const VERDICT_MARK = {
  pass: { Icon: Check, className: "bg-affirm-faded text-affirm-display" },
  fail: { Icon: X, className: "bg-danger-faded text-danger-display" },
  na: { Icon: Minus, className: "bg-surface text-ink-muted" },
} as const

const VERDICT_TICK = { pass: "bg-affirm", fail: "bg-danger", na: "bg-hairline" } as const

// The form's own labels, so the recap reads exactly like what was typed.
const EPS_LABELS = [
  ["eps_1", "Latest year"],
  ["eps_2", "1 year ago"],
  ["eps_3", "2 years ago"],
  ["eps_4", "3 years ago"],
  ["eps_5", "4 years ago"],
  ["eps_6", "5 years ago"],
  ["eps_7", "6 years ago"],
  ["eps_8", "7 years ago"],
  ["eps_9", "8 years ago"],
  ["eps_10", "9 years ago"],
] as const

const moneyFmt = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" })
const millionsFmt = new Intl.NumberFormat("en-US", { maximumFractionDigits: 1 })
const pctFmt = new Intl.NumberFormat("en-US", {
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
  signDisplay: "exceptZero",
})

const fmtMoney = (v: number) => moneyFmt.format(v)
const fmtMillions = (v: number) => `$${millionsFmt.format(v)}M`
const fmtRatio = (v: number) => v.toFixed(2)
const fmtPct = (v: number) => `${pctFmt.format(v)}%`

// One plain sentence per rule — what happened, without the figures. The
// figures live in ruleMath() so they line up in their own column.
function ruleOutcome(rule: Rule): string {
  switch (rule.key) {
    case "adequate_size":
      return rule.verdict === "pass" ? "Revenue meets the minimum." : "Revenue is below the minimum."
    case "financial_condition":
      if (rule.verdict === "na") {
        return "Not applied — Graham never fails banks and insurers on the current-ratio test."
      }
      return rule.verdict === "pass"
        ? "Current ratio is at least 2, as required."
        : "Current ratio is below the required 2."
    case "earnings_stability":
      return rule.verdict === "pass"
        ? "EPS was positive in every one of the last 10 years."
        : "EPS was not positive in every one of the last 10 years — every year must be positive."
    case "dividend_record":
      return rule.verdict === "pass"
        ? "Dividends have been paid for at least the required run of consecutive years."
        : "Dividends have not been paid for the required run of consecutive years."
    case "earnings_growth":
      if (rule.reason === "base_avg_not_positive") {
        return "Not computable — the average EPS of years 8–10 was not positive, so growth from that base is undefined."
      }
      return rule.verdict === "pass"
        ? "Growth in 3-year average EPS meets the required +33%."
        : "Growth in 3-year average EPS is below the required +33%."
    case "moderate_pe":
      if (rule.reason === "avg_eps_not_positive") {
        return "The 3-year average EPS is not positive, so no price can satisfy Graham's 15× ceiling."
      }
      return rule.verdict === "pass"
        ? "Price is within 15× the 3-year average EPS."
        : "Price is above 15× the 3-year average EPS."
    case "moderate_pb": {
      const { pb, pe_times_pb } = rule.values
      if (rule.reason === "bvps_not_positive") {
        return "Book value per share is not positive, so price-to-book cannot be computed."
      }
      if (pb! <= 1.5) {
        return "Price-to-book is within the 1.5 ceiling."
      }
      if (rule.verdict === "pass") {
        return "Price-to-book is over 1.5, but P/E × P/B is within the 22.5 allowance."
      }
      return pe_times_pb === null
        ? "Price-to-book is over the 1.5 ceiling, and the P/E × P/B fallback is not computable with non-positive average earnings."
        : "Price-to-book is over the 1.5 ceiling, and P/E × P/B exceeds the 22.5 allowance."
    }
  }
}

// The arithmetic behind each verdict, one line per entry, from the values the
// server already rounded for display. Null when a branch has nothing to show.
function ruleMath(rule: Rule, price: number): string[] | null {
  switch (rule.key) {
    case "adequate_size": {
      const { revenue, threshold } = rule.values
      return [`${fmtMillions(revenue)} ${rule.verdict === "pass" ? "≥" : "<"} ${fmtMillions(threshold)} minimum`]
    }
    case "financial_condition": {
      if (rule.verdict === "na") return null
      const { current_ratio, current_assets, current_liabilities } = rule.values
      return [
        `${fmtMillions(current_assets!)} ÷ ${fmtMillions(current_liabilities!)} = ${fmtRatio(current_ratio!)}`,
        "at least 2 required",
      ]
    }
    case "earnings_stability":
      return [`${rule.values.positive_years} of 10 years positive`]
    case "dividend_record": {
      const { dividend_years, required_years } = rule.values
      return [
        `${dividend_years} consecutive year${dividend_years === 1 ? "" : "s"}`,
        `at least ${required_years} required`,
      ]
    }
    case "earnings_growth": {
      const { recent_avg, old_avg, growth_pct } = rule.values
      if (rule.reason === "base_avg_not_positive") {
        return [`years 8–10 average EPS ${fmtMoney(old_avg)}`]
      }
      return [`${fmtMoney(old_avg)} → ${fmtMoney(recent_avg)} = ${fmtPct(growth_pct!)}`, "at least +33% required"]
    }
    case "moderate_pe": {
      const { pe, avg_eps, price_limit } = rule.values
      if (rule.reason === "avg_eps_not_positive") {
        return [`3-year average EPS ${fmtMoney(avg_eps)}`]
      }
      return [`${fmtMoney(price)} ÷ ${fmtMoney(avg_eps)} = ${fmtRatio(pe!)}×`, `ceiling 15× (${fmtMoney(price_limit!)})`]
    }
    case "moderate_pb": {
      const { pb, pe_times_pb } = rule.values
      if (rule.reason === "bvps_not_positive") return null
      const lines = [`P/B ${fmtRatio(pb!)} · ceiling 1.5`]
      if (pb! > 1.5 && pe_times_pb !== null) {
        lines.push(`P/E × P/B ${fmtRatio(pe_times_pb)}`, "allowance 22.5")
      }
      return lines
    }
  }
}

// "2" · "2 and 6" · "2, 6 and 7"
function listNumbers(numbers: number[]): string {
  if (numbers.length <= 1) return numbers.join("")
  return `${numbers.slice(0, -1).join(", ")} and ${numbers[numbers.length - 1]}`
}

// Raw form value exactly as typed; "" when absent or not a string.
const str = (value: string | boolean | undefined) => (typeof value === "string" ? value : "")

function VerdictRow({ rule, price }: { rule: Rule; price: number }) {
  const { Icon, className } = VERDICT_MARK[rule.verdict]
  const math = ruleMath(rule, price)

  return (
    <li
      data-rule={rule.key}
      data-verdict={rule.verdict}
      className="grid grid-cols-[1.75rem_1fr] gap-x-4 gap-y-2 py-5 sm:grid-cols-[1.75rem_1fr_minmax(0,14rem)]"
    >
      <span
        aria-hidden="true"
        className={cn("mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full", className)}
      >
        <Icon className="h-3.5 w-3.5" strokeWidth={3} />
      </span>
      <div className="min-w-0">
        <div className="flex flex-wrap items-baseline gap-x-3">
          <h3 className="heading-compact">{RULE_TITLES[rule.key]}</h3>
          <Badge tone={VERDICT_TONE[rule.verdict]} className="sr-only">
            {VERDICT_LABEL[rule.verdict]}
          </Badge>
        </div>
        <p className="mt-1">{ruleOutcome(rule)}</p>
      </div>
      {math && (
        <div className="figure col-start-2 font-mono text-xs leading-relaxed text-ink-muted sm:col-start-auto sm:text-right">
          {math.map((line) => (
            <span key={line} className="block">
              {line}
            </span>
          ))}
        </div>
      )}
    </li>
  )
}

export default function AnalysesResults({
  analysis,
  inputs,
}: {
  analysis: Analysis
  inputs: Record<string, string | boolean>
}) {
  const {
    ticker,
    company_name,
    financial_company,
    price,
    rules,
    pass_count,
    fail_count,
    na_count,
    met_count,
    graham_number,
  } = analysis
  const pageTitle = `${ticker} — Graham checklist`

  const failing = rules.filter((rule) => rule.verdict === "fail").map((rule) => RULE_NUMBERS[rule.key])
  // Decorative only: how much of the price the Graham Number covers, clamped.
  const barFill = graham_number.computable ? Math.min(graham_number.value! / price, 1) * 100 : 0

  // Inputs recap: open by default on desktop only. The <details> stays
  // uncontrolled — React sets `open` once at mount and never touches it again,
  // so the user's own toggles stick.
  const recapRef = useRef<HTMLDetailsElement>(null)
  useEffect(() => {
    if (!window.matchMedia("(min-width: 64rem)").matches) {
      recapRef.current?.removeAttribute("open")
    }
  }, [])

  const editLink = (
    <Button variant="secondary" asChild>
      <Link href="/analyses/new" data={inputs}>
        Edit inputs &amp; re-run
      </Link>
    </Button>
  )

  // Recap values are the user's raw strings — never parsed or reformatted.
  const recapValue = (key: string, unused = false) => {
    const raw = str(inputs[key])
    if (raw === "") {
      return <span className="text-ink-muted">{unused ? "Not used — financial company" : "Not entered"}</span>
    }
    return (
      <>
        <span className="figure">{raw}</span>
        {unused && <span className="ml-2 text-sm text-ink-muted">(not used — financial company)</span>}
      </>
    )
  }

  return (
    <>
      <Head title={pageTitle}>
        <meta
          name="description"
          content="Pass/fail results against Benjamin Graham's seven defensive-investor criteria, with the Graham Number next to the current price."
        />
        <meta property="og:title" content={pageTitle} />
        <meta
          property="og:description"
          content="Pass/fail results against Benjamin Graham's seven defensive-investor criteria, with the Graham Number next to the current price."
        />
      </Head>
      <AppShell>
        <PageHeader
          title={
            <>
              <span className="figure">{ticker}</span>
              {company_name && (
                <span className="block break-words font-sans text-xl font-normal tracking-normal text-ink-muted sm:ml-3 sm:inline">
                  {company_name}
                </span>
              )}
            </>
          }
          description="Checked against Benjamin Graham's defensive-investor criteria (The Intelligent Investor, Ch. 14)."
          actions={editLink}
        />

        <section
          aria-labelledby="verdict-heading"
          className="callout mt-8 grid p-0 divide-y divide-hairline lg:grid-cols-[1fr_1.15fr] lg:divide-x lg:divide-y-0"
        >
          <h2 id="verdict-heading" className="sr-only">
            Verdict
          </h2>

          <div className="p-6 lg:p-8">
            <p className="font-mono text-xs uppercase tracking-widest text-ink-muted">Criteria met</p>
            <p className="mt-2 flex items-baseline gap-2">
              <span className="figure-xl text-ink-display">{met_count}</span>
              <span className="figure-lg font-medium text-ink-muted">of 7</span>
            </p>
            <div aria-hidden="true" className="mt-5 flex gap-1.5">
              {rules.map((rule) => (
                <div key={rule.key} className="flex flex-1 flex-col items-center gap-1.5">
                  <span className={cn("block h-1.5 w-full rounded-full", VERDICT_TICK[rule.verdict])} />
                  <span className="font-mono text-xs text-ink-muted">{RULE_NUMBERS[rule.key]}</span>
                </div>
              ))}
            </div>
            {failing.length > 0 && (
              <p className="mt-4">
                Fails rule{failing.length === 1 ? "" : "s"} {listNumbers(failing)}.
              </p>
            )}
            {na_count > 0 && (
              <p className="mt-2 text-sm text-ink-muted">
                Includes {na_count} not-applicable rule{na_count === 1 ? "" : "s"}, counted as met —
                Graham never fails a company on a rule that doesn't apply to it.
              </p>
            )}
          </div>

          <div className="p-6 lg:p-8">
            <div className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
              <p className="font-mono text-xs uppercase tracking-widest text-ink-muted">Graham Number vs. price</p>
              <span className="text-xs text-ink-muted">information only</span>
            </div>
            {graham_number.computable ? (
              <>
                <dl className="mt-3 flex flex-wrap gap-x-8 gap-y-3">
                  <div>
                    <dt className="text-sm text-ink-muted">Graham Number</dt>
                    <dd className="figure-lg text-ink-display">{fmtMoney(graham_number.value!)}</dd>
                  </div>
                  <div>
                    <dt className="text-sm text-ink-muted">Current price</dt>
                    <dd className="figure-lg text-ink-display">{fmtMoney(price)}</dd>
                  </div>
                  <div>
                    <dt className="text-sm text-ink-muted">Margin</dt>
                    <dd
                      className={cn(
                        "figure-lg",
                        graham_number.margin_pct! >= 0 ? "text-affirm-display" : "text-danger-display",
                      )}
                    >
                      {fmtPct(graham_number.margin_pct!)}
                    </dd>
                  </div>
                </dl>
                <div aria-hidden="true" className="mt-4">
                  <div className="relative h-2 overflow-hidden rounded-full bg-hairline">
                    <span className="absolute inset-y-0 left-0 rounded-full bg-affirm" style={{ width: `${barFill}%` }} />
                    <span
                      className="absolute inset-y-0 w-0.5 bg-ink-display"
                      style={{ left: `clamp(0px, calc(${barFill}% - 1px), calc(100% - 2px))` }}
                    />
                  </div>
                  <div className="figure mt-1.5 flex justify-between font-mono text-xs text-ink-muted">
                    <span>ceiling {fmtMoney(graham_number.value!)}</span>
                    <span>price {fmtMoney(price)}</span>
                  </div>
                </div>
                <p className="figure mt-3 font-mono text-xs text-ink-muted">
                  √(22.5 × EPS {fmtMoney(graham_number.eps_used)} × book value {fmtMoney(graham_number.bvps_used)}) ={" "}
                  {fmtMoney(graham_number.value!)}
                </p>
                <p className="mt-2 text-sm text-ink-muted">
                  A positive margin means the price is below Graham's fair-value ceiling — information only, never a
                  signal.
                </p>
              </>
            ) : (
              <>
                <p className="figure-lg mt-3 text-ink-muted">Not computable</p>
                <dl className="mt-3 flex flex-wrap gap-x-8 gap-y-3">
                  <div>
                    <dt className="text-sm text-ink-muted">Latest EPS</dt>
                    <dd className="figure-lg text-ink-display">{fmtMoney(graham_number.eps_used)}</dd>
                  </div>
                  <div>
                    <dt className="text-sm text-ink-muted">Book value per share</dt>
                    <dd className="figure-lg text-ink-display">{fmtMoney(graham_number.bvps_used)}</dd>
                  </div>
                </dl>
                <p className="mt-3 text-sm text-ink-muted">
                  The formula √(22.5 × EPS × book value) requires positive earnings and positive book value per share.
                </p>
              </>
            )}
          </div>
        </section>

        <section aria-labelledby="criteria-heading" className="mt-10">
          <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
            <h2 id="criteria-heading">The seven criteria</h2>
            <p className="figure font-mono text-sm text-ink-muted">
              {fail_count} fail · {pass_count} pass{na_count > 0 && ` · ${na_count} N/A`}
            </p>
          </div>
          <ul className="mt-4 divide-y divide-hairline border-t border-hairline">
            {rules.map((rule) => (
              <VerdictRow key={rule.key} rule={rule} price={price} />
            ))}
          </ul>
        </section>

        <section aria-labelledby="inputs-heading" className="mt-10">
          <h2 id="inputs-heading">Inputs used</h2>
          <details ref={recapRef} open className="group mt-3">
            <summary className="flex cursor-pointer list-none items-center gap-2 rounded-md text-sm text-ink-muted [&::-webkit-details-marker]:hidden focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 focus-visible:ring-offset-page">
              <ChevronRight aria-hidden="true" className="h-4 w-4 shrink-0 transition-transform group-open:rotate-90" />
              As entered — check your own typing
            </summary>
            <DataTable className="mt-3">
              <DataRow title="Share price ($)">{recapValue("price")}</DataRow>
              <DataRow title="Annual revenue ($ millions)">{recapValue("revenue")}</DataRow>
              <DataRow title="Financial company (bank or insurer)">{financial_company ? "Yes" : "No"}</DataRow>
              <DataRow title="Current assets ($ millions)">{recapValue("current_assets", financial_company)}</DataRow>
              <DataRow title="Current liabilities ($ millions)">
                {recapValue("current_liabilities", financial_company)}
              </DataRow>
              <DataRow title="Earnings per share ($), last 10 fiscal years">
                <dl className="grid grid-cols-2 gap-x-6 gap-y-2 sm:grid-cols-5">
                  {EPS_LABELS.map(([key, label]) => (
                    <div key={key}>
                      <dt className="text-xs text-ink-muted">{label}</dt>
                      <dd>{recapValue(key)}</dd>
                    </div>
                  ))}
                </dl>
              </DataRow>
              <DataRow title="Consecutive years of dividends paid">{recapValue("dividend_years")}</DataRow>
              <DataRow title="Book value per share ($)">{recapValue("bvps")}</DataRow>
            </DataTable>
          </details>
        </section>

        <section className="callout callout-signal mt-8">
          <h2>Limitations</h2>
          <ul className="mt-2 space-y-1 text-sm">
            <li>
              These thresholds are Graham's from the 1970s — a strict P/E ≤ 15 rejects nearly every
              modern growth company. A result here means "fails Graham's rules," never "bad stock."
            </li>
            <li>
              Financial companies (banks, insurers) are never failed on the current-ratio rule — it
              shows N/A instead.
            </li>
            <li>
              The revenue minimum (currently {fmtMillions(analysis.revenue_threshold)}) is
              configurable in <Link href="/settings">Settings</Link>.
            </li>
            <li>Nothing here is investment advice.</li>
          </ul>
        </section>
      </AppShell>
    </>
  )
}
