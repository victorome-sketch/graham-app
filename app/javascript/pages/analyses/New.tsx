import { FormEvent, ReactNode } from "react"
import { Head, Link, useForm, usePage } from "@inertiajs/react"
import { AppShell } from "@/components/AppShell"
import { PageHeader } from "@/components/PageHeader"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"

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

const str = (value: string | boolean | undefined) => (typeof value === "string" ? value : "")

const fmtMillions = (value: number) =>
  `$${new Intl.NumberFormat("en-US", { maximumFractionDigits: 1 }).format(value)}M`

export default function AnalysesNew({
  prefill,
  revenue_threshold,
}: {
  prefill: Prefill
  revenue_threshold: number
}) {
  const { props } = usePage<PageProps>()
  const errors = props.errors ?? {}

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

  const field = (
    key: Exclude<keyof typeof form.data, "financial_company">,
    label: string,
    options: {
      helper?: ReactNode
      required?: boolean
      disabled?: boolean
      inputMode?: "decimal" | "numeric" | "text"
      className?: string
      placeholder?: string
    } = {},
  ) => {
    const { helper, required = true, disabled, inputMode = "decimal", className, placeholder } = options
    const value = form.data[key]
    return (
      <div className="space-y-2">
        <label htmlFor={key}>
          {label}
          {required && !disabled && value.trim() === "" && (
            <span className="ml-1.5 text-xs font-normal text-ink-muted">— required</span>
          )}
        </label>
        <Input
          id={key}
          inputMode={inputMode === "text" ? undefined : inputMode}
          required={required && !disabled}
          disabled={disabled}
          aria-invalid={!!errors[key]}
          placeholder={placeholder}
          className={className}
          value={value}
          onChange={(e) => form.setData(key, e.target.value)}
        />
        {errors[key] && <p className="text-xs text-danger-display">{errors[key]}</p>}
        {helper && !errors[key] && <p className="text-xs text-ink-muted">{helper}</p>}
      </div>
    )
  }

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
          description="Enter a stock's financials to check Graham's seven defensive-investor criteria."
        />

        <section className="mt-10 max-w-2xl">
          <form onSubmit={submit} className="space-y-10">
            <fieldset className="space-y-4">
              <legend>Company</legend>
              {field("ticker", "Ticker", {
                inputMode: "text",
                className: "uppercase",
                placeholder: "KO",
              })}
              {field("company_name", "Company name", {
                inputMode: "text",
                required: false,
                placeholder: "Optional",
              })}
              <label className="flex items-start gap-2 font-normal text-ink-body">
                <Checkbox
                  className="mt-0.5"
                  checked={financial}
                  onChange={(e) => form.setData("financial_company", e.target.checked)}
                />
                This is a financial company (bank or insurer)
              </label>
              <p className="text-xs text-ink-muted">
                Graham never fails banks and insurers on the current-ratio test — rule 2 shows N/A
                instead, and the current assets and liabilities below aren't needed.
              </p>
            </fieldset>

            <fieldset className="space-y-4">
              <legend>Financials</legend>
              {field("price", "Share price ($)")}
              {field("revenue", "Annual revenue ($ millions)", {
                helper: (
                  <>
                    Rule 1 currently requires at least {fmtMillions(revenue_threshold)} — change it
                    in <Link href="/settings">Settings</Link>.
                  </>
                ),
              })}
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                {field("current_assets", "Current assets ($ millions)", {
                  disabled: financial,
                  helper: financial ? "Not needed for financial companies." : undefined,
                })}
                {field("current_liabilities", "Current liabilities ($ millions)", {
                  disabled: financial,
                  helper: financial ? "Not needed for financial companies." : undefined,
                })}
              </div>
            </fieldset>

            <fieldset className="space-y-4">
              <legend>Earnings per share — last 10 fiscal years</legend>
              <p className="text-xs text-ink-muted">
                Diluted EPS in dollars for each of the last 10 fiscal years. Negative values are
                allowed.
              </p>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
                {EPS_FIELDS.map((f) => (
                  <div key={f.key}>{field(f.key, f.label)}</div>
                ))}
              </div>
            </fieldset>

            <fieldset className="space-y-4">
              <legend>Dividends &amp; book value</legend>
              {field("dividend_years", "Consecutive years of dividends paid", {
                inputMode: "numeric",
                helper: "Rule 4 requires at least 20.",
              })}
              {field("bvps", "Book value per share ($)", {
                helper: "Negative values are allowed.",
              })}
            </fieldset>

            <div className="space-y-2">
              <Button type="submit" disabled={form.processing}>
                Run checklist
              </Button>
              <p className="text-xs text-ink-muted">
                Nothing is saved — the checklist is computed from exactly what you enter here.
              </p>
            </div>
          </form>
        </section>
      </AppShell>
    </>
  )
}
