import { SectionShell } from "@/components/design-system/SectionShell";
import { Input } from "@/components/ui/input";

const code = `<fieldset className="min-w-0">
  <legend className="mb-4 w-full">
    <span className="form-section-head">
      <span className="form-section-index">01</span>
      <span className="form-section-title">Company</span>
      <span aria-hidden="true" className="form-section-rule" />
    </span>
  </legend>

  {/* fields… */}
</fieldset>`;

function Head({
  index,
  title,
  note,
}: {
  index: string;
  title: string;
  note?: string;
}) {
  return (
    <legend className="mb-4 w-full">
      <span className="form-section-head">
        <span className="form-section-index">{index}</span>
        <span className="form-section-title">{title}</span>
        <span aria-hidden="true" className="form-section-rule" />
        {note && <span className="form-section-note">{note}</span>}
      </span>
    </legend>
  );
}

export function FormSectionsSection() {
  return (
    <SectionShell
      id="form-sections"
      title="Form sections"
      description={
        <>
          A numbered header for a long form: a mono index, a display-face title,
          and a hairline rule that runs to the edge of the column. It gives a
          twenty-field form a handful of labelled stops without wrapping every
          group in a card. Lives inside <code>&lt;legend&gt;</code>, so the
          grouping is real to a screen reader as well as to the eye.
        </>
      }
      whenToUse={
        <ul>
          <li>Forms long enough to scroll — three or more distinct groups of fields.</li>
          <li>When a user needs to orient mid-form (“which part am I in?”).</li>
          <li>When the same numbering is echoed elsewhere — a progress list, a summary, a table of contents.</li>
        </ul>
      }
      whenNotToUse={
        <ul>
          <li>Short forms — a plain <code>&lt;legend&gt;</code> is enough below three groups.</li>
          <li>Steps in a wizard — numbering here labels parts of one page, not a sequence.</li>
          <li>Page-level headings — use <code>&lt;PageHeader&gt;</code> and <code>&lt;h2&gt;</code>.</li>
        </ul>
      }
      preview={
        <form className="max-w-xl space-y-8" onSubmit={(e) => e.preventDefault()}>
          <fieldset className="min-w-0">
            <Head index="01" title="Company" />
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-[9rem_minmax(0,1fr)]">
              <div className="space-y-2">
                <label htmlFor="ds-section-ticker">Ticker</label>
                <Input id="ds-section-ticker" className="uppercase" defaultValue="KO" />
              </div>
              <div className="space-y-2">
                <label htmlFor="ds-section-name">
                  Company name
                  <span className="ml-1 text-xs font-normal text-ink-muted">{" "}optional</span>
                </label>
                <Input id="ds-section-name" defaultValue="The Coca-Cola Company" />
              </div>
            </div>
          </fieldset>

          <fieldset className="min-w-0">
            <Head index="02" title="Earnings per share" note="last 10 years" />
            <p className="mb-1 text-xs text-ink-muted">
              A note under the header carries instructions for the whole group.
            </p>
            <div className="space-y-2">
              <label htmlFor="ds-section-eps">
                Latest year
                <span className="sr-only"> earnings per share in dollars</span>
              </label>
              <div className="field-affix">
                <span aria-hidden="true" className="field-affix-start">
                  $
                </span>
                <Input id="ds-section-eps" inputMode="decimal" defaultValue="2.47" />
              </div>
            </div>
          </fieldset>
        </form>
      }
      code={code}
      options={
        <ul className="list-disc pl-5">
          <li><code>.form-section-index</code> — the mono numeral. Two digits (<code>01</code>) reads as a set; drop it entirely if the sections aren't countable.</li>
          <li><code>.form-section-note</code> — an optional right-hand note after the rule (“last 10 years”, “optional”). It wraps below the title on narrow columns.</li>
          <li>Put <code>min-w-0</code> on the <code>&lt;fieldset&gt;</code>: its default <code>min-inline-size: min-content</code> otherwise stops it shrinking inside a grid or flex column.</li>
          <li>Spacing: <code>space-y-8</code> between sections, the design system's <code>space-y-4</code> / <code>space-y-2</code> within them.</li>
          <li>Don't restyle the <code>&lt;legend&gt;</code> itself — the classes go on spans inside it, so the base label/legend typography stays intact for every other form.</li>
        </ul>
      }
    />
  );
}
