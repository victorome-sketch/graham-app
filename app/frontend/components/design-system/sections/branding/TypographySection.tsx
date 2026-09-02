import { SectionShell } from "@/components/design-system/SectionShell";
import { FONTS } from "@/components/design-system/palette";

const code = `// Set in design-system.css via @theme:
//   --font-display: 'Inter', ui-sans-serif, system-ui, sans-serif;
//   --font-sans: 'DM Sans', ui-sans-serif, system-ui, sans-serif;

<h1 className="font-display">Display headline</h1>
<p className="font-sans">Body paragraph.</p>

// Figures — tabular numerals for every currency, ratio and percentage.
// Type only: colour and layout stay at the call site.
<span className="figure">$47,061M · 1.13 · +46.9%</span>
<span className="figure-lg text-ink-display">$18.74</span>
<span className="figure-xl text-ink-display">4</span>

// Compact heading — keeps the outline level, renders at body size.
<h3 className="heading-compact">1. Adequate size</h3>`;

export function TypographySection() {
  return (
    <SectionShell
      id="typography"
      title="Typography"
      description={
        <>
          Two families. Headlines use <code>{FONTS.display}</code>, body copy
          uses <code>{FONTS.body}</code>. Both load from Google Fonts via{" "}
          <code>&lt;link&gt;</code> tags in the app's HTML <code>&lt;head&gt;</code>.
          Numbers get the <code>figure</code> treatment so digits line up.
        </>
      }
      whenToUse={
        <ul>
          <li>
            Use <code>font-display</code> for headings only. Headings already
            inherit it via base styles.
          </li>
          <li>
            Use <code>font-sans</code> for everything else — also already the
            default.
          </li>
          <li>
            Put <code>.figure</code> on every currency, ratio and percentage;{" "}
            <code>.figure-lg</code> / <code>.figure-xl</code> for headline
            numbers. Pair with a colour token at the call site.
          </li>
          <li>
            Use <code>.heading-compact</code> on a heading inside a dense list
            (one heading per row) to keep the outline level without the size.
          </li>
        </ul>
      }
      whenNotToUse={
        <ul>
          <li>
            Don't import additional font families — propose adding to the
            system instead.
          </li>
          <li>Don't override <code>font-family</code> inline.</li>
          <li>
            Don't reach for <code>&lt;code&gt;</code> to get monospace or
            tabular digits — arithmetic is not code. Use <code>.figure</code>{" "}
            (plus <code>font-mono</code> if you want a computed look).
          </li>
        </ul>
      }
      preview={
        <div className="space-y-6">
          <div>
            <div className="mb-1 text-xs font-mono text-ink-muted">
              Display — {FONTS.display}
            </div>
            <div className="font-display text-4xl font-semibold text-ink-display">
              The quick brown fox jumps over the lazy dog
            </div>
          </div>
          <div>
            <div className="mb-1 text-xs font-mono text-ink-muted">
              Body — {FONTS.body}
            </div>
            <div className="font-sans text-base text-ink-body">
              The quick brown fox jumps over the lazy dog. 0123456789. The
              five boxing wizards jump quickly.
            </div>
          </div>
          <div>
            <div className="mb-1 text-xs font-mono text-ink-muted">
              Figures — .figure-xl / .figure-lg / .figure
            </div>
            <div className="flex flex-wrap items-baseline gap-x-8 gap-y-3">
              <span className="figure-xl text-ink-display">4</span>
              <span className="figure-lg text-ink-display">$18.74</span>
              <span className="figure-lg text-danger-display">-265.1%</span>
              <span className="figure text-ink-body">$47,061M · 1.13 · +46.9%</span>
            </div>
          </div>
          <div>
            <div className="mb-1 text-xs font-mono text-ink-muted">
              Compact heading — h3.heading-compact
            </div>
            <h3 className="heading-compact">1. Adequate size</h3>
          </div>
        </div>
      }
      code={code}
    />
  );
}
