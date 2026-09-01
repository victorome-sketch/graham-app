import { Head, Link } from "@inertiajs/react"
import { AppShell } from "@/components/AppShell"
import { PageHeader } from "@/components/PageHeader"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"

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

const VERDICT_TONE = { pass: "accent", fail: "danger", na: "muted" } as const
const VERDICT_LABEL = { pass: "Pass", fail: "Fail", na: "N/A" } as const

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

function ruleDetail(rule: Rule, price: number): string {
  switch (rule.key) {
    case "adequate_size": {
      const { revenue, threshold } = rule.values
      return rule.verdict === "pass"
        ? `Revenue of ${fmtMillions(revenue)} meets the ${fmtMillions(threshold)} minimum.`
        : `Revenue of ${fmtMillions(revenue)} is below the ${fmtMillions(threshold)} minimum.`
    }
    case "financial_condition": {
      if (rule.verdict === "na") {
        return "Not applied — Graham never fails banks and insurers on the current-ratio test."
      }
      const { current_ratio, current_assets, current_liabilities } = rule.values
      return `Current ratio is ${fmtRatio(current_ratio!)} (${fmtMillions(current_assets!)} current assets ÷ ${fmtMillions(current_liabilities!)} current liabilities); at least 2 is required.`
    }
    case "earnings_stability": {
      const { positive_years } = rule.values
      return rule.verdict === "pass"
        ? "EPS was positive in every one of the last 10 years."
        : `EPS was positive in ${positive_years} of the last 10 years — every year must be positive.`
    }
    case "dividend_record": {
      const { dividend_years, required_years } = rule.values
      return `Dividends paid for ${dividend_years} consecutive year${dividend_years === 1 ? "" : "s"}; at least ${required_years} are required.`
    }
    case "earnings_growth": {
      const { recent_avg, old_avg, growth_pct } = rule.values
      if (rule.reason === "base_avg_not_positive") {
        return `Not computable — the average EPS of years 8–10 (${fmtMoney(old_avg)}) was not positive, so growth from that base is undefined.`
      }
      return `3-year average EPS went from ${fmtMoney(old_avg)} to ${fmtMoney(recent_avg)} (${fmtPct(growth_pct!)}); at least +33% is required.`
    }
    case "moderate_pe": {
      const { pe, avg_eps, price_limit } = rule.values
      if (rule.reason === "avg_eps_not_positive") {
        return `The 3-year average EPS (${fmtMoney(avg_eps)}) is not positive, so no price can satisfy Graham's 15× ceiling.`
      }
      return `Price ${fmtMoney(price)} is ${fmtRatio(pe!)}× the 3-year average EPS of ${fmtMoney(avg_eps)}; the ceiling is 15× (${fmtMoney(price_limit!)}).`
    }
    case "moderate_pb": {
      const { pb, pe_times_pb } = rule.values
      if (rule.reason === "bvps_not_positive") {
        return "Book value per share is not positive, so price-to-book cannot be computed."
      }
      if (pb! <= 1.5) {
        return `Price-to-book is ${fmtRatio(pb!)}, within the 1.5 ceiling.`
      }
      if (rule.verdict === "pass") {
        return `Price-to-book is ${fmtRatio(pb!)} (over 1.5), but P/E × P/B of ${fmtRatio(pe_times_pb!)} is within the 22.5 allowance.`
      }
      return pe_times_pb === null
        ? `Price-to-book is ${fmtRatio(pb!)}, over the 1.5 ceiling, and the P/E × P/B fallback is not computable with non-positive average earnings.`
        : `Price-to-book is ${fmtRatio(pb!)}, over the 1.5 ceiling, and P/E × P/B of ${fmtRatio(pe_times_pb!)} exceeds the 22.5 allowance.`
    }
  }
}

export default function AnalysesResults({
  analysis,
  inputs,
}: {
  analysis: Analysis
  inputs: Record<string, string | boolean>
}) {
  const { ticker, company_name, price, rules, na_count, met_count, graham_number } = analysis
  const pageTitle = `${ticker} — Graham checklist`

  const editLink = (
    <Button variant="secondary" asChild>
      <Link href="/analyses/new" data={inputs}>
        Edit inputs &amp; re-run
      </Link>
    </Button>
  )

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
          title={company_name ? `${ticker} — ${company_name}` : ticker}
          description="Checked against Benjamin Graham's defensive-investor criteria (The Intelligent Investor, Ch. 14)."
          actions={editLink}
        />

        <section className="callout mt-8">
          <h2>{met_count} of 7 criteria met</h2>
          {na_count > 0 && (
            <p className="mt-1 text-sm text-ink-muted">
              Includes {na_count} not-applicable rule{na_count === 1 ? "" : "s"}, counted as met —
              Graham never fails a company on a rule that doesn't apply to it.
            </p>
          )}
        </section>

        <section className="callout mt-4">
          {graham_number.computable ? (
            <>
              <p>
                <strong>Graham Number {fmtMoney(graham_number.value!)}</strong> vs. price{" "}
                {fmtMoney(price)} — margin {fmtPct(graham_number.margin_pct!)}
              </p>
              <p className="mt-1 text-sm text-ink-muted">
                √(22.5 × EPS {fmtMoney(graham_number.eps_used)} × book value{" "}
                {fmtMoney(graham_number.bvps_used)}). A positive margin means the price is below
                Graham's fair-value ceiling — information only, never a signal.
              </p>
            </>
          ) : (
            <>
              <p>
                <strong>Graham Number not computable</strong>
              </p>
              <p className="mt-1 text-sm text-ink-muted">
                The formula √(22.5 × EPS × book value) requires positive earnings and positive book
                value per share (latest EPS {fmtMoney(graham_number.eps_used)}, book value{" "}
                {fmtMoney(graham_number.bvps_used)}).
              </p>
            </>
          )}
        </section>

        <ul className="mt-8 divide-y divide-hairline overflow-hidden rounded-md border border-hairline bg-page">
          {rules.map((rule) => (
            <li key={rule.key} className="flex items-start justify-between gap-4 px-4 py-3">
              <div className="min-w-0">
                <strong>{RULE_TITLES[rule.key]}</strong>
                <p className="mt-0.5 text-sm text-ink-muted">{ruleDetail(rule, price)}</p>
              </div>
              <Badge tone={VERDICT_TONE[rule.verdict]} className="mt-0.5 shrink-0">
                {VERDICT_LABEL[rule.verdict]}
              </Badge>
            </li>
          ))}
        </ul>

        <section className="callout callout-signal mt-8">
          <h3>Limitations</h3>
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

        <div className="mt-8">{editLink}</div>
      </AppShell>
    </>
  )
}
