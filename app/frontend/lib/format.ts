// Number formatters shared by the analysis pages, so a figure reads the same
// wherever it appears (the History margin must match the Results margin).
const moneyFmt = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" })
const millionsFmt = new Intl.NumberFormat("en-US", { maximumFractionDigits: 1 })
const pctFmt = new Intl.NumberFormat("en-US", {
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
  signDisplay: "exceptZero",
})

export const fmtMoney = (v: number) => moneyFmt.format(v)
export const fmtMillions = (v: number) => `$${millionsFmt.format(v)}M`
export const fmtRatio = (v: number) => v.toFixed(2)
export const fmtPct = (v: number) => `${pctFmt.format(v)}%`
