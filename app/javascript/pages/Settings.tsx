import { FormEvent } from "react"
import { Head, useForm, usePage } from "@inertiajs/react"
import { AppShell } from "@/components/AppShell"
import { PageHeader } from "@/components/PageHeader"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

import type { PageProps } from "@/types/inertia"

type Props = PageProps<{ settings: { revenue_threshold_millions: number } }>

export default function Settings() {
  const { props } = usePage<Props>()
  const errors = props.errors ?? {}

  const form = useForm({
    revenue_threshold_millions: String(props.settings.revenue_threshold_millions),
  })

  const submit = (e: FormEvent) => {
    e.preventDefault()
    form.patch("/settings", { preserveScroll: true })
  }

  return (
    <>
      <Head title="Settings">
        <meta name="description" content="Configure the Graham screener's checklist thresholds." />
        <meta property="og:title" content="Settings" />
        <meta
          property="og:description"
          content="Configure the Graham screener's checklist thresholds."
        />
      </Head>
      <AppShell>
        <PageHeader title="Settings" description="Screener configuration." />

        {props.flash?.notice && <p className="mt-6 text-sm text-accent">{props.flash.notice}</p>}

        <section className="mt-10 max-w-md">
          <form onSubmit={submit} className="space-y-4">
            <div className="space-y-2">
              <label htmlFor="revenue_threshold_millions">Revenue threshold ($ millions)</label>
              <Input
                id="revenue_threshold_millions"
                inputMode="decimal"
                required
                aria-invalid={!!errors.revenue_threshold_millions}
                value={form.data.revenue_threshold_millions}
                onChange={(e) => form.setData("revenue_threshold_millions", e.target.value)}
              />
              {errors.revenue_threshold_millions ? (
                <p className="text-xs text-danger-display">{errors.revenue_threshold_millions}</p>
              ) : (
                <p className="text-xs text-ink-muted">
                  Rule 1 — adequate size. Graham's $100M bar from 1973 is roughly $700M today.
                </p>
              )}
            </div>
            <Button type="submit" disabled={form.processing}>
              Save settings
            </Button>
          </form>
        </section>
      </AppShell>
    </>
  )
}
