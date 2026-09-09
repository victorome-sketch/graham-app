// One saved analysis as the History list and a saved result's header see it.
// The date arrives pre-formatted from the server (`ran_at_label`) so the SSR
// render and the browser hydrate identically; `ran_at` is the ISO timestamp
// for <time dateTime>.
export type AnalysisSummary = {
  id: number
  url: string
  ticker: string
  company_name: string | null
  met_count: number
  margin_pct: number | null
  ran_at: string
  ran_at_label: string
}
