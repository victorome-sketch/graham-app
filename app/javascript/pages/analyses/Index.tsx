import { Head, Link, usePage } from "@inertiajs/react"
import { ChevronRight, ListChecks } from "lucide-react"
import { AppShell } from "@/components/AppShell"
import { PageHeader } from "@/components/PageHeader"
import { Button } from "@/components/ui/button"
import { fmtPct } from "@/lib/format"
import { cn } from "@/lib/utils"
import type { AnalysisSummary } from "@/types/analysis"
import type { PageProps } from "@/types/inertia"

const DESCRIPTION =
  "Every Graham checklist you have run, newest first — reopen any past analysis exactly as it was."

export default function AnalysesIndex({ analyses }: { analyses: AnalysisSummary[] }) {
  const { props } = usePage<PageProps>()
  const count = analyses.length

  const newLink = (
    <Button asChild>
      <Link href="/analyses/new">New analysis</Link>
    </Button>
  )

  return (
    <>
      <Head title="History">
        <meta name="description" content={DESCRIPTION} />
        <meta property="og:title" content="History" />
        <meta property="og:description" content={DESCRIPTION} />
      </Head>
      <AppShell>
        <PageHeader
          title="History"
          description={`${count} saved ${count === 1 ? "analysis" : "analyses"}.`}
          actions={newLink}
        />

        {props.flash?.notice && (
          <p role="status" className="mt-6 text-sm text-accent">
            {props.flash.notice}
          </p>
        )}

        {count === 0 ? (
          <section className="callout mt-8">
            <h2>No analyses yet</h2>
            <p className="mt-2">Run a checklist and it is saved here exactly as it came out.</p>
            <div className="mt-4">{newLink}</div>
          </section>
        ) : (
          <ul
            data-testid="history-list"
            className="mt-6 divide-y divide-hairline overflow-hidden rounded-md border border-hairline bg-page"
          >
            {analyses.map((row) => (
              <li key={row.id}>
                <Link
                  href={row.url}
                  className="flex items-center gap-3 px-4 py-3 no-underline hover:bg-surface"
                >
                  <ListChecks className="h-4 w-4 shrink-0 text-ink-muted" aria-hidden="true" />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-medium text-ink-display">
                      <span className="figure">{row.ticker}</span>
                      {row.company_name && (
                        <span className="ml-2 font-normal text-ink-muted">{row.company_name}</span>
                      )}
                    </div>
                    <div className="truncate text-xs text-ink-muted">
                      <time dateTime={row.ran_at}>{row.ran_at_label}</time>
                    </div>
                  </div>
                  {/* Stacked on phones so the ticker and date keep their room; side by side from sm up. */}
                  <div className="flex shrink-0 flex-col items-end gap-0.5 sm:flex-row sm:items-center sm:gap-3">
                    <span className="figure text-sm text-ink-display">
                      {row.met_count} <span className="text-ink-muted">of 7</span>
                    </span>
                    <span className={cn("figure text-sm sm:w-20 sm:text-right", marginTone(row.margin_pct))}>
                      <span className="sr-only">Margin </span>
                      {row.margin_pct === null ? "—" : fmtPct(row.margin_pct)}
                    </span>
                  </div>
                  <ChevronRight className="h-4 w-4 shrink-0 text-ink-muted" aria-hidden="true" />
                </Link>
              </li>
            ))}
          </ul>
        )}
      </AppShell>
    </>
  )
}

// The same sign colouring as the Results page's margin figure; muted when the
// Graham Number was not computable for that run.
function marginTone(margin: number | null) {
  if (margin === null) return "text-ink-muted"
  return margin >= 0 ? "text-affirm-display" : "text-danger-display"
}
