import type * as React from "react";
import { SectionShell } from "@/components/design-system/SectionShell";
import { Input } from "@/components/ui/input";

const code = `import { Input } from "@/components/ui/input";

{/* Leading unit */}
<div className="space-y-2">
  <label htmlFor="price">
    Share price
    <span className="sr-only"> in dollars</span>
  </label>
  <div className="field-affix">
    <span aria-hidden="true" className="field-affix-start">$</span>
    <Input id="price" inputMode="decimal" />
  </div>
</div>

{/* Trailing unit */}
<div className="space-y-2">
  <label htmlFor="years">
    Consecutive years of dividends
    <span className="sr-only"> in years</span>
  </label>
  <div className="field-affix">
    <Input id="years" inputMode="numeric" />
    <span aria-hidden="true" className="field-affix-end">years</span>
  </div>
</div>`;

function Demo({
  id,
  label,
  affix,
  unit,
  side = "start",
  ...inputProps
}: {
  id: string;
  label: string;
  affix: string;
  /* The affix is aria-hidden, so the unit reaches the accessible name here. */
  unit: string;
  side?: "start" | "end";
} & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <div className="space-y-2">
      <label htmlFor={id}>
        {label}
        <span className="sr-only"> {unit}</span>
      </label>
      <div className="field-affix">
        {side === "start" && (
          <span aria-hidden="true" className="field-affix-start">
            {affix}
          </span>
        )}
        <Input id={id} inputMode="decimal" {...inputProps} />
        {side === "end" && (
          <span aria-hidden="true" className="field-affix-end">
            {affix}
          </span>
        )}
      </div>
    </div>
  );
}

export function FieldAffixSection() {
  return (
    <SectionShell
      id="field-affix"
      title="Field affix"
      description={
        <>
          A unit rendered inside the control's frame, so labels stay short and
          numeric values keep a single alignment down a column. The wrapper owns
          the border and the focus ring; the inner <code>&lt;Input&gt;</code>{" "}
          gives up both and picks up tabular numerals and right alignment.
        </>
      }
      whenToUse={
        <ul>
          <li>Currency, magnitude, or duration fields — <code>$</code>, <code>$M</code>, <code>years</code>, <code>%</code>.</li>
          <li>Columns of numbers that should read as a ledger.</li>
          <li>Anywhere the unit would otherwise bloat the label — “Share price ($ millions)”.</li>
        </ul>
      }
      whenNotToUse={
        <ul>
          <li>Text fields — a unit implies a number.</li>
          <li>Units the user can change: that's a <code>&lt;Select&gt;</code> beside the field, not an affix.</li>
          <li>Icons or buttons inside the field — this pattern is a static, non-interactive label.</li>
        </ul>
      }
      preview={
        <div className="grid max-w-2xl gap-4 sm:grid-cols-2">
          <Demo
            id="ds-affix-price"
            label="Share price"
            affix="$"
            unit="in dollars"
            defaultValue="62.40"
          />
          <Demo
            id="ds-affix-revenue"
            label="Annual revenue"
            affix="$M"
            unit="in millions of dollars"
            defaultValue="45754"
          />
          <Demo
            id="ds-affix-years"
            label="Consecutive years of dividends"
            affix="years"
            unit="in years"
            side="end"
            inputMode="numeric"
            defaultValue="62"
          />
          <Demo
            id="ds-affix-invalid"
            label="Current liabilities"
            affix="$M"
            unit="in millions of dollars"
            aria-invalid
            defaultValue="0"
          />
          <Demo
            id="ds-affix-disabled"
            label="Current assets"
            affix="$M"
            unit="in millions of dollars"
            disabled
            defaultValue="26732"
          />
        </div>
      }
      code={code}
      options={
        <ul className="list-disc pl-5">
          <li><code>.field-affix-start</code> for a leading unit, <code>.field-affix-end</code> for a trailing one. Both are <code>aria-hidden</code>.</li>
          <li>
            Accessibility: the affix is decorative, so put the unit in the label
            as a <code>sr-only</code> suffix — <code>&lt;label&gt;Share price&lt;span className="sr-only"&gt; in dollars&lt;/span&gt;&lt;/label&gt;</code>.
          </li>
          <li>Invalid: set <code>aria-invalid</code> on the inner input — the wrapper picks up the danger border via <code>:has()</code>.</li>
          <li>
            Disabled: set <code>disabled</code> on the inner input. The group dims
            <em> once</em> — a filled surface plus muted text, not stacked
            <code>opacity-50</code> on wrapper and control. Labels and helper text
            outside the wrapper keep full contrast.
          </li>
          <li>Errors and helper text sit in the usual slot beneath the wrapper, unchanged from Forms.</li>
        </ul>
      }
    />
  );
}
