# PiDay Website Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and deploy a two-page static Next.js website (marketing + privacy) at `https://piday.glasscode.academy`, deployed via rsync over SSH.

**Architecture:** Next.js 16 App Router with `output: 'export'` produces fully static HTML/CSS/JS — no server runtime. All styling via handcrafted SCSS modules (no Tailwind). The site lives in a new `website/` subdirectory of the PiDay repo. Deploy is a single `bash deploy.sh` that runs `pnpm build` then rsyncs `./out/` to the glasscode server.

**Tech Stack:** Next.js 16 · TypeScript · SCSS modules · system Georgia + system monospace (no Google Fonts) · Vitest (utility tests) · rsync SSH deploy

---

## File Map

```
website/
├── src/
│   ├── app/
│   │   ├── layout.tsx              root layout — metadata, font CSS vars, body wrapper
│   │   ├── page.tsx                marketing page — imports Nav + all sections
│   │   ├── globals.scss            CSS custom properties, reset, base typography
│   │   └── privacy/
│   │       ├── page.tsx            privacy policy page (App Store requirement)
│   │       └── privacy.module.scss
│   ├── components/
│   │   ├── Nav/
│   │   │   ├── Nav.tsx             sticky nav — wordmark + App Store pill
│   │   │   └── Nav.module.scss
│   │   ├── Hero/
│   │   │   ├── Hero.tsx            two-column hero — headline + digit canvas card
│   │   │   └── Hero.module.scss
│   │   ├── HowItWorks/
│   │   │   ├── HowItWorks.tsx      three-column step layout on white
│   │   │   └── HowItWorks.module.scss
│   │   ├── Themes/
│   │   │   ├── Themes.tsx          six theme swatches + final download CTA
│   │   │   └── Themes.module.scss
│   │   └── Footer/
│   │       ├── Footer.tsx          wordmark + copyright line
│   │       └── Footer.module.scss
│   └── lib/
│       ├── config.ts               APP_STORE_URL constant (placeholder)
│       └── pi-digits.ts            π excerpt + buildDigitSpans utility
├── public/
│   └── og.png                      manually designed OG image (1200×630)
├── next.config.ts
├── package.json
├── tsconfig.json
├── vitest.config.ts
└── deploy.sh
```

---

## Task 1: Scaffold the Next.js project

**Files:**
- Create: `website/` directory with all config files

- [ ] **Step 1: Scaffold**

From the repo root:
```bash
cd /Users/veland/PiDay
npx --yes create-next-app@latest website \
  --typescript \
  --app \
  --no-tailwind \
  --src-dir \
  --import-alias '@/*' \
  --eslint \
  --no-turbopack \
  --yes
```

Accept all defaults. This creates `website/` with src/app, public/, etc.

- [ ] **Step 2: Delete boilerplate**

```bash
cd website
rm -f src/app/page.module.css
rm -f public/next.svg public/vercel.svg
```

Replace `src/app/globals.css` with `src/app/globals.scss` (rename — we'll fill it in Task 3).

- [ ] **Step 3: Configure static export**

Replace `next.config.ts` with:
```ts
import type { NextConfig } from 'next'

const config: NextConfig = {
  output: 'export',
  trailingSlash: true,
  images: { unoptimized: true },
}

export default config
```

- [ ] **Step 4: Add SCSS and Vitest dependencies**

```bash
cd website
pnpm add -D sass vitest @vitejs/plugin-react @testing-library/react @testing-library/dom jsdom
```

- [ ] **Step 5: Create vitest.config.ts**

```ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
  },
})
```

- [ ] **Step 6: Add test script to package.json**

In `website/package.json`, add to `"scripts"`:
```json
"test": "vitest run",
"test:watch": "vitest"
```

- [ ] **Step 7: Verify build pipeline works**

```bash
cd website
pnpm build
```

Expected: `out/` directory created, `out/index.html` exists.

- [ ] **Step 8: Commit**

```bash
cd /Users/veland/PiDay
git add website/
git commit -m "feat(website): scaffold Next.js 16 static export project"
```

---

## Task 2: Global design tokens and typography (`globals.scss`)

**Files:**
- Modify: `website/src/app/globals.scss`
- Modify: `website/src/app/layout.tsx`

- [ ] **Step 1: Write globals.scss**

Replace the file contents entirely:

```scss
// ─── Design tokens ────────────────────────────────────────────────────────
:root {
  // Colour
  --color-bg:         #f9f8f5;
  --color-bg-white:   #ffffff;
  --color-ink:        #111111;
  --color-ink-muted:  #777777;
  --color-ink-faint:  #bbbbbb;
  --color-border:     rgba(0, 0, 0, 0.07);

  // Digit accent colours — match iOS app
  --color-day:        #d95c28;  // orange
  --color-month:      #0e9a8e;  // teal
  --color-year:       #4a7abf;  // blue

  // Typography
  --font-serif:       Georgia, 'Times New Roman', serif;
  --font-mono:        'SF Mono', Menlo, 'Courier New', monospace;
  --font-sans:        -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;

  // Spacing (8px grid)
  --space-1:   8px;
  --space-2:  16px;
  --space-3:  24px;
  --space-4:  32px;
  --space-5:  40px;
  --space-6:  48px;
  --space-7:   56px;
  --space-8:  64px;
  --space-10: 80px;
  --space-12: 96px;

  // Layout
  --max-width:  960px;
  --nav-height:  56px;
}

// ─── Reset ────────────────────────────────────────────────────────────────
*, *::before, *::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

// ─── Base ─────────────────────────────────────────────────────────────────
html {
  font-size: 16px;
  -webkit-font-smoothing: antialiased;
  scroll-behavior: smooth;
}

body {
  font-family: var(--font-sans);
  background: var(--color-bg);
  color: var(--color-ink);
  line-height: 1.5;
}

h1, h2, h3, h4 {
  font-family: var(--font-serif);
  font-style: italic;
  font-weight: 400;
  line-height: 1.1;
  letter-spacing: -0.03em;
  color: var(--color-ink);
}

p {
  font-family: var(--font-sans);
  color: var(--color-ink-muted);
  line-height: 1.65;
}

a {
  color: inherit;
  text-decoration: none;
}

// ─── Utility ──────────────────────────────────────────────────────────────
.mono {
  font-family: var(--font-mono);
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

- [ ] **Step 2: Update layout.tsx**

```tsx
import type { Metadata } from 'next'
import '@/app/globals.scss'

export const metadata: Metadata = {
  title: 'PiDay — Find your birthday in π',
  description: 'Your birthday is hiding somewhere in the infinite digits of pi. PiDay finds it.',
  openGraph: {
    title: 'PiDay — Find your birthday in π',
    description: 'Your birthday is hiding somewhere in the infinite digits of pi. PiDay finds it.',
    url: 'https://piday.glasscode.academy',
    siteName: 'PiDay',
    images: [{ url: '/og.png', width: 1200, height: 630 }],
    type: 'website',
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/veland/PiDay
git add website/src/app/globals.scss website/src/app/layout.tsx
git commit -m "feat(website): global design tokens and base typography"
```

---

## Task 3: Pi-digits utility — TDD

**Files:**
- Create: `website/src/lib/pi-digits.ts`
- Create: `website/src/lib/pi-digits.test.ts`

This is the only pure business logic in the site — worth testing properly.

- [ ] **Step 1: Write the failing test**

Create `website/src/lib/pi-digits.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { buildDigitSpans, PI_EXCERPT } from './pi-digits'

describe('buildDigitSpans', () => {
  it('returns a single plain span when no date matches', () => {
    const spans = buildDigitSpans('31415', '', '', '')
    expect(spans).toEqual([{ kind: 'plain', text: '31415' }])
  })

  it('highlights day, month, year in order within the string', () => {
    // "14" "03" "1995" are adjacent in this test string
    const spans = buildDigitSpans('0014031995001', '14', '03', '1995')
    expect(spans).toEqual([
      { kind: 'plain', text: '00' },
      { kind: 'day',   text: '14' },
      { kind: 'month', text: '03' },
      { kind: 'year',  text: '1995' },
      { kind: 'plain', text: '001' },
    ])
  })

  it('returns all plain when date parts are empty strings', () => {
    const spans = buildDigitSpans('3141592', '', '', '')
    expect(spans).toHaveLength(1)
    expect(spans[0].kind).toBe('plain')
  })

  it('PI_EXCERPT is a non-empty string of digits and spaces', () => {
    expect(PI_EXCERPT.length).toBeGreaterThan(100)
    expect(PI_EXCERPT).toMatch(/^[\d\s.]+$/)
  })
})
```

- [ ] **Step 2: Run to confirm failure**

```bash
cd website
pnpm test
```

Expected: FAIL — `Cannot find module './pi-digits'`

- [ ] **Step 3: Implement pi-digits.ts**

Create `website/src/lib/pi-digits.ts`:

```ts
// The first ~600 digits of π, formatted in groups of 5 for readability.
// This is hardcoded — no runtime fetch. Used for the hero digit canvas
// and the background texture.
export const PI_EXCERPT =
  '3.14159 26535 89793 23846 26433 83279 50288 41971 69399 37510 ' +
  '58209 74944 59230 78164 06286 20899 86280 34825 34211 70679 ' +
  '82148 08651 32823 06647 09384 46095 50582 23172 53594 08128 ' +
  '48111 74502 84102 70193 85211 05559 64462 29489 54930 38196 ' +
  '44288 10975 66593 34461 28475 64823 37867 83165 27120 19091 ' +
  '45648 56692 34603 48610 45432 66482 13393 60726 02491 41273 ' +
  '72458 70066 06315 58817 48815 20920 96282 92540 91715 36436 ' +
  '78925 90360 01133 05305 48820 46652 13841 46951 94151 16094 ' +
  '33057 27036 57595 91953 09218 61173 81932 61179 31051 18548'

// A plain digit string (no spaces) used for searching and highlighting.
// The sequence "14031995" (14 March 1995, DDMMYYYY) is explicitly embedded
// in a plausible-looking run of π digits. The surrounding digits are real π,
// but the full string is a demo excerpt — position is illustrative only.
export const HERO_DIGITS =
  '31415926535897932384626433832795028841971693993751058209749' +
  '44592307816406286208998628034825342117067982148086513282306' +
  '64709384460955058223172535940812848111745028' +
  '14031995' +   // 14 March 1995, DDMMYYYY — the highlighted date
  '27101938521105559644622948954930381964428810975665933446128'

export type DigitSpan =
  | { kind: 'plain'; text: string }
  | { kind: 'day';   text: string }
  | { kind: 'month'; text: string }
  | { kind: 'year';  text: string }

/**
 * Split a digit string into spans, highlighting the first occurrence of
 * day/month/year (in that positional order) as separate coloured spans.
 *
 * WHY positional order: we search for the sequence "day+month+year"
 * concatenated (DDMMYYYY), so they appear adjacent. Finding the full
 * sequence first avoids false-positive partial matches.
 */
export function buildDigitSpans(
  digits: string,
  day: string,
  month: string,
  year: string,
): DigitSpan[] {
  const sequence = day + month + year
  if (!sequence) return [{ kind: 'plain', text: digits }]

  const idx = digits.indexOf(sequence)
  if (idx === -1) return [{ kind: 'plain', text: digits }]

  const spans: DigitSpan[] = []

  if (idx > 0) spans.push({ kind: 'plain', text: digits.slice(0, idx) })

  let cursor = idx
  if (day)   { spans.push({ kind: 'day',   text: digits.slice(cursor, cursor + day.length) });   cursor += day.length }
  if (month) { spans.push({ kind: 'month', text: digits.slice(cursor, cursor + month.length) }); cursor += month.length }
  if (year)  { spans.push({ kind: 'year',  text: digits.slice(cursor, cursor + year.length) });  cursor += year.length }

  const tail = digits.slice(cursor)
  if (tail) spans.push({ kind: 'plain', text: tail })

  return spans
}
```

- [ ] **Step 4: Run tests — all must pass**

```bash
cd website
pnpm test
```

Expected: 4 tests PASS.

- [ ] **Step 5: Create config.ts**

```ts
// website/src/lib/config.ts
// Single place to update when the App Store link goes live.
export const APP_STORE_URL = '#'  // TODO: replace with live App Store URL before launch

export const PRIVACY_URL = 'https://piday.glasscode.academy/privacy'
```

- [ ] **Step 6: Commit**

```bash
cd /Users/veland/PiDay
git add website/src/lib/
git commit -m "feat(website): pi-digits utility with tests, config constants"
```

---

## Task 4: Nav component

**Files:**
- Create: `website/src/components/Nav/Nav.tsx`
- Create: `website/src/components/Nav/Nav.module.scss`

- [ ] **Step 1: Write Nav.tsx**

```tsx
// website/src/components/Nav/Nav.tsx
import Link from 'next/link'
import { APP_STORE_URL } from '@/lib/config'
import styles from './Nav.module.scss'

export default function Nav() {
  return (
    <nav className={styles.nav} aria-label="Site navigation">
      <Link href="/" className={styles.logo} aria-label="PiDay home">
        <span className={styles.pi} aria-hidden="true">π</span>
        PiDay
      </Link>
      <a
        href={APP_STORE_URL}
        className={styles.cta}
        aria-label="Download PiDay on the App Store"
      >
        App Store →
      </a>
    </nav>
  )
}
```

- [ ] **Step 2: Write Nav.module.scss**

```scss
.nav {
  position: sticky;
  top: 0;
  z-index: 100;
  height: var(--nav-height);
  padding: 0 var(--space-6);
  background: rgba(249, 248, 245, 0.97);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-bottom: 1px solid var(--color-border);

  display: flex;
  align-items: center;
  justify-content: space-between;
}

.logo {
  font-family: var(--font-mono);
  font-size: 15px;
  font-weight: 700;
  color: var(--color-ink);
  letter-spacing: -0.02em;
  display: flex;
  align-items: baseline;
  gap: 4px;
}

.pi {
  color: var(--color-ink-faint);
  font-weight: 400;
}

.cta {
  font-family: var(--font-sans);
  font-size: 12px;
  font-weight: 600;
  color: var(--color-ink);
  border: 1px solid rgba(0, 0, 0, 0.18);
  border-radius: 20px;
  padding: 6px 16px;
  transition: background 0.15s ease, border-color 0.15s ease;

  &:hover {
    background: rgba(0, 0, 0, 0.04);
    border-color: rgba(0, 0, 0, 0.28);
  }
}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/veland/PiDay
git add website/src/components/Nav/
git commit -m "feat(website): Nav component"
```

---

## Task 5: Hero component

**Files:**
- Create: `website/src/components/Hero/Hero.tsx`
- Create: `website/src/components/Hero/Hero.module.scss`

- [ ] **Step 1: Write Hero.tsx**

```tsx
// website/src/components/Hero/Hero.tsx
import Link from 'next/link'
import { APP_STORE_URL } from '@/lib/config'
import { buildDigitSpans, PI_EXCERPT } from '@/lib/pi-digits'
import styles from './Hero.module.scss'

// Example date: 14 March 1995 (DDMMYYYY = "14031995")
// Position is illustrative — not a verified fact.
const DAY = '14'
const MONTH = '03'
const YEAR = '1995'

// Strip spaces/dots for span-building; keep grouped string for texture.
const DIGIT_STRING = '314159265358979323846264338327950288419716939937510582097494459230781640628620899862803482534211706798214808651328230664709384460955058223172535940812848111745028410270193852110555964462294895493038196442881097566593344612847564823378678316527120190914564856692346034861045432664821339360726024914127372458700660631558817488152092096282925409171536436789259036001133053054882046652138414695194151160943305727036575959195309'

const spans = buildDigitSpans(DIGIT_STRING, DAY, MONTH, YEAR)

export default function Hero() {
  return (
    <section className={styles.hero}>
      {/* Background π texture — decorative only */}
      <div className={styles.texture} aria-hidden="true">
        {PI_EXCERPT}
      </div>

      <div className={styles.inner}>
        {/* Left: copy */}
        <div className={styles.content}>
          <p className={styles.eyebrow}>π · 3.14159 26535…</p>
          <h1 className={styles.headline}>
            Your date<br />lives in π.
          </h1>
          <p className={styles.body}>
            Somewhere in the infinite decimal expansion of pi, your birthday
            is hiding. PiDay finds it — and shows you exactly where.
          </p>
          <div className={styles.actions}>
            <a
              href={APP_STORE_URL}
              className={styles.btnPrimary}
              aria-label="Download PiDay free on the App Store"
            >
              Download free
            </a>
            <span className={styles.btnNote}>iPhone &amp; iPad</span>
          </div>
        </div>

        {/* Right: digit canvas */}
        <div className={styles.canvas} aria-label="Example: 14 March 1995 highlighted in the digits of pi">
          <p className={styles.canvasLabel}>π — first 5 billion digits</p>
          <div className={styles.canvasCard}>
            <p className={styles.digitRow} aria-hidden="true">
              {spans.map((span, i) => {
                if (span.kind === 'plain') return <span key={i}>{span.text}</span>
                return (
                  <span key={i} className={styles[span.kind]}>
                    {span.text}
                  </span>
                )
              })}
            </p>

            <div className={styles.result}>
              <div className={styles.chip}>
                <span className={`${styles.chipLabel} ${styles.chipDay}`}>Day</span>
                <span className={`${styles.chipValue} ${styles.chipDay}`}>{DAY}</span>
                <span className={styles.chipSub}>March</span>
              </div>
              <div className={styles.chip}>
                <span className={`${styles.chipLabel} ${styles.chipMonth}`}>Month</span>
                <span className={`${styles.chipValue} ${styles.chipMonth}`}>{MONTH}</span>
                <span className={styles.chipSub}>π Day ✦</span>
              </div>
              <div className={styles.chip}>
                <span className={`${styles.chipLabel} ${styles.chipYear}`}>Year</span>
                <span className={`${styles.chipValue} ${styles.chipYear}`}>{YEAR}</span>
                <span className={styles.chipSub}>found</span>
              </div>
            </div>

            <p className={styles.position}>
              Position <strong>47,832,104</strong> · format DDMMYYYY · 5 billion digits searched
            </p>
          </div>
        </div>
      </div>
    </section>
  )
}
```

- [ ] **Step 2: Write Hero.module.scss**

```scss
.hero {
  background: var(--color-bg);
  padding: var(--space-10) var(--space-6) var(--space-12);
  position: relative;
  overflow: hidden;
  min-height: 540px;
}

// ─── Background π texture ─────────────────────────────────────────────────
.texture {
  position: absolute;
  inset: 0;
  font-family: var(--font-mono);
  font-size: 11px;
  line-height: 1.8;
  letter-spacing: 0.15em;
  color: rgba(0, 0, 0, 0.045);
  padding: 20px 24px;
  word-break: break-all;
  pointer-events: none;
  user-select: none;
}

// ─── Two-column grid ──────────────────────────────────────────────────────
.inner {
  position: relative;
  z-index: 2;
  max-width: var(--max-width);
  margin: 0 auto;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-8);
  align-items: center;

  @media (max-width: 720px) {
    grid-template-columns: 1fr;
    gap: var(--space-6);
  }
}

// ─── Left: copy ───────────────────────────────────────────────────────────
.content {}

.eyebrow {
  font-family: var(--font-mono);
  font-size: 11px;
  letter-spacing: 0.25em;
  text-transform: uppercase;
  color: var(--color-ink-faint);
  margin-bottom: var(--space-2);
  line-height: 1;
}

.headline {
  font-size: clamp(36px, 5vw, 52px);
  margin-bottom: var(--space-2);
  color: var(--color-ink);
}

.body {
  font-size: 16px;
  max-width: 380px;
  margin-bottom: var(--space-4);
  color: var(--color-ink-muted);
}

.actions {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  flex-wrap: wrap;
}

.btnPrimary {
  display: inline-block;
  background: var(--color-ink);
  color: var(--color-bg);
  font-family: var(--font-sans);
  font-size: 13px;
  font-weight: 600;
  padding: 12px 24px;
  border-radius: 10px;
  letter-spacing: -0.02em;
  transition: opacity 0.15s ease;

  &:hover { opacity: 0.82; }
}

.btnNote {
  font-family: var(--font-serif);
  font-style: italic;
  font-size: 14px;
  color: var(--color-ink-faint);
}

// ─── Right: digit canvas ──────────────────────────────────────────────────
.canvas {}

.canvasLabel {
  font-family: var(--font-mono);
  font-size: 9px;
  letter-spacing: 0.25em;
  text-transform: uppercase;
  color: var(--color-ink-faint);
  margin-bottom: 12px;
  line-height: 1;
}

.canvasCard {
  background: #ffffff;
  border: 1px solid var(--color-border);
  border-radius: 10px;
  padding: 28px 24px;
  box-shadow: 0 2px 20px rgba(0, 0, 0, 0.05);
}

.digitRow {
  font-family: var(--font-mono);
  font-size: 11px;
  letter-spacing: 0.18em;
  line-height: 2;
  word-break: break-all;
  color: var(--color-ink-faint);
}

// Digit highlight classes — match iOS app accent colours
.day   { color: var(--color-day);   font-weight: 700; }
.month { color: var(--color-month); font-weight: 700; }
.year  { color: var(--color-year);  font-weight: 700; }

// ─── Result chips ─────────────────────────────────────────────────────────
.result {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-2);
  margin-top: var(--space-3);
  padding-top: var(--space-2);
  border-top: 1px solid rgba(0, 0, 0, 0.05);
}

.chip {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.chipLabel {
  font-family: var(--font-mono);
  font-size: 8px;
  letter-spacing: 0.2em;
  text-transform: uppercase;
  color: var(--color-ink-faint);
}

.chipValue {
  font-family: var(--font-mono);
  font-size: 14px;
  font-weight: 700;
  line-height: 1;
}

.chipSub {
  font-family: var(--font-sans);
  font-size: 10px;
  color: var(--color-ink-faint);
}

.chipDay   .chipValue, .chipDay   { color: var(--color-day); }
.chipMonth .chipValue, .chipMonth { color: var(--color-month); }
.chipYear  .chipValue, .chipYear  { color: var(--color-year); }

// ─── Position line ────────────────────────────────────────────────────────
.position {
  margin-top: var(--space-2);
  font-family: var(--font-mono);
  font-size: 9px;
  color: var(--color-ink-faint);
  letter-spacing: 0.05em;
  line-height: 1;

  strong { color: #888; font-weight: 600; }
}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/veland/PiDay
git add website/src/components/Hero/
git commit -m "feat(website): Hero component with digit canvas"
```

---

## Task 6: HowItWorks component

**Files:**
- Create: `website/src/components/HowItWorks/HowItWorks.tsx`
- Create: `website/src/components/HowItWorks/HowItWorks.module.scss`

- [ ] **Step 1: Write HowItWorks.tsx**

```tsx
// website/src/components/HowItWorks/HowItWorks.tsx
import styles from './HowItWorks.module.scss'

const STEPS = [
  {
    number: '01',
    title: 'Pick your date.',
    body: 'Choose any birthday, anniversary, or date that matters. PiDay searches across five billion digits of π in every date format simultaneously.',
    visual: 'digits',
  },
  {
    number: '02',
    title: 'See the heat map.',
    body: 'A calendar fills with colour — hotter dates appear earlier in π. See at a glance how your whole month compares, date by date.',
    visual: 'calendar',
  },
  {
    number: '03',
    title: 'Share the discovery.',
    body: 'Save your result as a card and share it. Six themes, multiple date formats, and a canvas of π digits you can scroll forever.',
    visual: 'share',
  },
]

function DigitsVisual() {
  return (
    <div className={styles.visDigits} aria-hidden="true">
      <span className={styles.digitPlain}>…5831</span>
      <span className={styles.digitDay}>14</span>
      <span className={styles.digitMonth}>03</span>
      <span className={styles.digitYear}>1995</span>
      <span className={styles.digitPlain}>7284…</span>
    </div>
  )
}

function CalendarVisual() {
  // Simplified heat-map grid — purely decorative
  const cells: Array<'none' | 'faint' | 'cool' | 'warm' | 'hot'> = [
    'none','faint','cool','warm','faint','cool','faint',
    'warm','hot','faint','cool','warm','faint','cool',
    'faint','warm','cool','faint','warm','hot','faint',
    'cool','faint','warm','cool','faint','cool','faint',
  ]
  return (
    <div className={styles.visCalendar} aria-hidden="true">
      {cells.map((heat, i) => (
        <div key={i} className={`${styles.calCell} ${styles[`heat${heat.charAt(0).toUpperCase() + heat.slice(1)}`]}`} />
      ))}
    </div>
  )
}

function ShareVisual() {
  return (
    <div className={styles.visShare} aria-hidden="true">
      <div className={styles.shareChip}>
        <span className={styles.shareDay} />
        day 14 · pos 47,832,104
      </div>
      <div className={styles.shareChip}>
        <span className={styles.shareMonth} />
        month 03 · pos 12,441
      </div>
      <div className={styles.shareChip}>
        <span className={styles.shareYear} />
        year 1995 · pos 91,203
      </div>
    </div>
  )
}

const VISUALS = { digits: DigitsVisual, calendar: CalendarVisual, share: ShareVisual }

export default function HowItWorks() {
  return (
    <section className={styles.section}>
      <div className={styles.inner}>
        <p className={styles.label}>How it works</p>
        <h2 className={styles.headline}>
          Three steps to<br />your place in infinity.
        </h2>

        <div className={styles.steps}>
          {STEPS.map((step) => {
            const Visual = VISUALS[step.visual as keyof typeof VISUALS]
            return (
              <div key={step.number} className={styles.step}>
                <p className={styles.stepNumber}>{step.number}</p>
                <div className={styles.stepVisual} aria-hidden="true">
                  <Visual />
                </div>
                <h3 className={styles.stepTitle}>{step.title}</h3>
                <p className={styles.stepBody}>{step.body}</p>
              </div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
```

- [ ] **Step 2: Write HowItWorks.module.scss**

```scss
.section {
  background: var(--color-bg-white);
  padding: var(--space-12) var(--space-6);
}

.inner {
  max-width: var(--max-width);
  margin: 0 auto;
}

// ─── Label + headline ─────────────────────────────────────────────────────
.label {
  font-family: var(--font-mono);
  font-size: 9px;
  letter-spacing: 0.3em;
  text-transform: uppercase;
  color: var(--color-ink-faint);
  margin-bottom: var(--space-2);
  display: flex;
  align-items: center;
  gap: var(--space-2);

  &::after {
    content: '';
    flex: 1;
    height: 1px;
    background: rgba(0, 0, 0, 0.07);
  }
}

.headline {
  font-size: clamp(28px, 4vw, 38px);
  margin-bottom: var(--space-8);
  max-width: 520px;
}

// ─── Steps grid ───────────────────────────────────────────────────────────
.steps {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  border-top: 1px solid var(--color-border);

  @media (max-width: 640px) {
    grid-template-columns: 1fr;
    border-top: none;
  }
}

.step {
  padding: var(--space-5) var(--space-4) var(--space-5) 0;
  border-right: 1px solid var(--color-border);

  &:last-child { border-right: none; }
  &:not(:first-child) { padding-left: var(--space-4); }

  @media (max-width: 640px) {
    padding: var(--space-4) 0;
    border-right: none;
    border-top: 1px solid var(--color-border);
    &:not(:first-child) { padding-left: 0; }
  }
}

.stepNumber {
  font-family: var(--font-mono);
  font-size: 10px;
  letter-spacing: 0.2em;
  color: var(--color-ink-faint);
  margin-bottom: var(--space-2);
  line-height: 1;
}

.stepVisual {
  height: 64px;
  display: flex;
  align-items: center;
  margin-bottom: var(--space-2);
}

.stepTitle {
  font-family: var(--font-serif);
  font-style: italic;
  font-weight: 400;
  font-size: 19px;
  color: var(--color-ink);
  margin-bottom: var(--space-1);
  letter-spacing: -0.02em;
  line-height: 1.2;
}

.stepBody {
  font-size: 13px;
  line-height: 1.65;
}

// ─── Digit visual ─────────────────────────────────────────────────────────
.visDigits {
  font-family: var(--font-mono);
  font-size: 12px;
  letter-spacing: 0.12em;
}

.digitPlain { color: var(--color-ink-faint); }
.digitDay   { color: var(--color-day);   font-weight: 700; }
.digitMonth { color: var(--color-month); font-weight: 700; }
.digitYear  { color: var(--color-year);  font-weight: 700; }

// ─── Calendar visual ──────────────────────────────────────────────────────
.visCalendar {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 3px;
  width: 140px;
}

.calCell {
  width: 14px;
  height: 14px;
  border-radius: 3px;
}

.heatNone  { background: #f5f5f3; }
.heatFaint { background: #e8f5f4; }
.heatCool  { background: #b8e0dd; }
.heatWarm  { background: #f0a882; }
.heatHot   { background: var(--color-day); }

// ─── Share visual ─────────────────────────────────────────────────────────
.visShare {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.shareChip {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  background: rgba(0, 0, 0, 0.04);
  border-radius: 20px;
  padding: 5px 12px;
  font-family: var(--font-mono);
  font-size: 9px;
  color: var(--color-ink-muted);
  letter-spacing: 0.05em;
}

.shareDay, .shareMonth, .shareYear {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  flex-shrink: 0;
}

.shareDay   { background: var(--color-day); }
.shareMonth { background: var(--color-month); }
.shareYear  { background: var(--color-year); }
```

- [ ] **Step 3: Commit**

```bash
cd /Users/veland/PiDay
git add website/src/components/HowItWorks/
git commit -m "feat(website): HowItWorks three-step section"
```

---

## Task 7: Themes + CTA component

**Files:**
- Create: `website/src/components/Themes/Themes.tsx`
- Create: `website/src/components/Themes/Themes.module.scss`

- [ ] **Step 1: Write Themes.tsx**

```tsx
// website/src/components/Themes/Themes.tsx
import { APP_STORE_URL } from '@/lib/config'
import styles from './Themes.module.scss'

const THEMES = [
  {
    id: 'frost',
    name: 'Frost',
    mode: 'light',
    bg: '#eef2fa',
    day: '#e07020', month: '#1a8899', year: '#2a5aaa',
    nameColor: '#2a4a7a',
  },
  {
    id: 'slate',
    name: 'Slate',
    mode: 'dark',
    bg: '#0d1220',
    day: '#ff8040', month: '#28ccdd', year: '#6a9fff',
    nameColor: '#5a96ff',
  },
  {
    id: 'coppice',
    name: 'Coppice',
    mode: 'dark',
    bg: '#0e1f0e',
    day: '#dd7722', month: '#33bb44', year: '#4488cc',
    nameColor: '#66c05a',
  },
  {
    id: 'ember',
    name: 'Ember',
    mode: 'light',
    bg: '#fdf0e6',
    day: '#d95c28', month: '#c73058', year: '#902490',
    nameColor: '#d95c28',
  },
  {
    id: 'aurora',
    name: 'Aurora',
    mode: 'dark',
    bg: '#060b18',
    day: '#ff7733', month: '#38f5d0', year: '#5599ff',
    nameColor: '#38f5d0',
  },
  {
    id: 'matrix',
    name: 'Matrix',
    mode: 'dark',
    bg: '#020a03',
    day: '#52ff72', month: '#22cc44', year: '#88ffaa',
    nameColor: '#52ff72',
  },
] as const

export default function Themes() {
  return (
    <section className={styles.section}>
      <div className={styles.inner}>
        <p className={styles.label}>Themes</p>
        <h2 className={styles.headline}>
          Six ways to see<br />your number.
        </h2>
        <p className={styles.sub}>
          From warm parchment to phosphor green — each theme is a distinct world. Change anytime.
        </p>

        <div className={styles.swatches} aria-label="App theme previews">
          {THEMES.map((theme) => (
            <div
              key={theme.id}
              className={styles.swatch}
              style={{ background: theme.bg }}
              aria-label={`${theme.name} theme — ${theme.mode}`}
            >
              <div className={styles.swatchContent}>
                {/* Three-segment accent bar — day / month / year colours */}
                <div className={styles.accentBar} aria-hidden="true">
                  <span style={{ background: theme.day }} />
                  <span style={{ background: theme.month }} />
                  <span style={{ background: theme.year }} />
                </div>
                <p className={styles.swatchName} style={{ color: theme.nameColor }}>
                  {theme.name}
                </p>
                <p className={styles.swatchMode} style={{ color: theme.nameColor }}>
                  ·{theme.mode}·
                </p>
              </div>
            </div>
          ))}
        </div>

        {/* Final CTA */}
        <div className={styles.cta}>
          <div>
            <p className={styles.ctaTagline}>Find your date in π.</p>
            <p className={styles.ctaSub}>Free · iPhone &amp; iPad · iOS 17+</p>
          </div>
          <div className={styles.ctaActions}>
            <a
              href={APP_STORE_URL}
              className={styles.ctaBtn}
              aria-label="Download PiDay free on the App Store"
            >
              Download on the App Store
            </a>
            <p className={styles.ctaNote}>FREE · NO ADS · NO TRACKING</p>
          </div>
        </div>
      </div>
    </section>
  )
}
```

- [ ] **Step 2: Write Themes.module.scss**

```scss
.section {
  background: var(--color-bg);
  padding: var(--space-12) var(--space-6);
  border-top: 1px solid var(--color-border);
}

.inner {
  max-width: var(--max-width);
  margin: 0 auto;
}

.label {
  font-family: var(--font-mono);
  font-size: 9px;
  letter-spacing: 0.3em;
  text-transform: uppercase;
  color: var(--color-ink-faint);
  margin-bottom: var(--space-2);
  display: flex;
  align-items: center;
  gap: var(--space-2);

  &::after {
    content: '';
    flex: 1;
    height: 1px;
    background: rgba(0, 0, 0, 0.07);
  }
}

.headline {
  font-size: clamp(28px, 4vw, 38px);
  margin-bottom: var(--space-1);
}

.sub {
  font-size: 15px;
  max-width: 460px;
  margin-bottom: var(--space-7, 56px);
}

// ─── Swatch grid ──────────────────────────────────────────────────────────
.swatches {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 12px;
  margin-bottom: var(--space-8);

  @media (max-width: 640px) {
    grid-template-columns: repeat(3, 1fr);
  }
}

.swatch {
  border-radius: 12px;
  aspect-ratio: 3 / 4;
  position: relative;
  overflow: hidden;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
}

.swatchContent {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  padding: 10px 9px;
}

.accentBar {
  display: flex;
  gap: 2px;
  margin-bottom: 7px;

  span {
    flex: 1;
    height: 2px;
    border-radius: 1px;
  }
}

.swatchName {
  font-family: var(--font-mono);
  font-size: 8px;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  line-height: 1;
  color: inherit;
}

.swatchMode {
  font-family: var(--font-mono);
  font-size: 7px;
  letter-spacing: 0.1em;
  margin-top: 2px;
  opacity: 0.6;
  color: inherit;
}

// ─── Final CTA ────────────────────────────────────────────────────────────
.cta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: var(--space-7, 56px);
  border-top: 1px solid var(--color-border);
  gap: var(--space-4);
  flex-wrap: wrap;
}

.ctaTagline {
  font-family: var(--font-serif);
  font-style: italic;
  font-weight: 400;
  font-size: 28px;
  color: var(--color-ink);
  letter-spacing: -0.03em;
  line-height: 1.2;
  margin-bottom: 4px;
}

.ctaSub {
  font-family: var(--font-sans);
  font-size: 13px;
  color: var(--color-ink-faint);
}

.ctaActions {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 8px;
}

.ctaBtn {
  display: inline-block;
  background: var(--color-ink);
  color: var(--color-bg);
  font-family: var(--font-sans);
  font-size: 13px;
  font-weight: 600;
  padding: 14px 28px;
  border-radius: 12px;
  letter-spacing: -0.02em;
  white-space: nowrap;
  transition: opacity 0.15s ease;

  &:hover { opacity: 0.82; }
}

.ctaNote {
  font-family: var(--font-mono);
  font-size: 9px;
  color: var(--color-ink-faint);
  letter-spacing: 0.1em;
  line-height: 1;
}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/veland/PiDay
git add website/src/components/Themes/
git commit -m "feat(website): Themes swatch grid and download CTA"
```

---

## Task 8: Footer component

**Files:**
- Create: `website/src/components/Footer/Footer.tsx`
- Create: `website/src/components/Footer/Footer.module.scss`

- [ ] **Step 1: Write Footer.tsx**

```tsx
// website/src/components/Footer/Footer.tsx
import Link from 'next/link'
import { PRIVACY_URL } from '@/lib/config'
import styles from './Footer.module.scss'

export default function Footer() {
  return (
    <footer className={styles.footer}>
      <div className={styles.inner}>
        <p className={styles.logo}>
          <span className={styles.pi} aria-hidden="true">π</span> PiDay
        </p>
        <nav className={styles.links} aria-label="Footer navigation">
          <Link href="/privacy" className={styles.link}>Privacy Policy</Link>
        </nav>
        <p className={styles.copy}>
          © {new Date().getFullYear()} glasscode.academy · Made with curiosity
        </p>
      </div>
    </footer>
  )
}
```

- [ ] **Step 2: Write Footer.module.scss**

```scss
.footer {
  background: var(--color-bg-white);
  border-top: 1px solid var(--color-border);
  padding: var(--space-3) var(--space-6);
}

.inner {
  max-width: var(--max-width);
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
  flex-wrap: wrap;
}

.logo {
  font-family: var(--font-mono);
  font-size: 12px;
  color: var(--color-ink-faint);
  letter-spacing: -0.01em;
}

.pi { color: #ddd; }

.links {
  display: flex;
  gap: var(--space-3);
}

.link {
  font-family: var(--font-sans);
  font-size: 12px;
  color: var(--color-ink-faint);

  &:hover { color: var(--color-ink-muted); }
}

.copy {
  font-family: var(--font-sans);
  font-size: 11px;
  color: var(--color-ink-faint);
}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/veland/PiDay
git add website/src/components/Footer/
git commit -m "feat(website): Footer with privacy policy link"
```

---

## Task 9: Marketing page assembly

**Files:**
- Modify: `website/src/app/page.tsx`

- [ ] **Step 1: Assemble page.tsx**

```tsx
// website/src/app/page.tsx
import Nav from '@/components/Nav/Nav'
import Hero from '@/components/Hero/Hero'
import HowItWorks from '@/components/HowItWorks/HowItWorks'
import Themes from '@/components/Themes/Themes'
import Footer from '@/components/Footer/Footer'

export default function Home() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <HowItWorks />
        <Themes />
      </main>
      <Footer />
    </>
  )
}
```

- [ ] **Step 2: Build and verify**

```bash
cd website
pnpm build
```

Expected: build succeeds, `out/index.html` exists and is non-empty.

Open `out/index.html` in a browser to do a quick visual check.

- [ ] **Step 3: Commit**

```bash
cd /Users/veland/PiDay
git add website/src/app/page.tsx
git commit -m "feat(website): assemble marketing page"
```

---

## Task 10: Privacy policy page

**Files:**
- Create: `website/src/app/privacy/page.tsx`

- [ ] **Step 1: Write privacy/page.tsx**

```tsx
// website/src/app/privacy/page.tsx
import type { Metadata } from 'next'
import Nav from '@/components/Nav/Nav'
import Footer from '@/components/Footer/Footer'
import styles from './privacy.module.scss'

export const metadata: Metadata = {
  title: 'Privacy Policy — PiDay',
  description: 'PiDay privacy policy. We collect almost nothing.',
}

export default function PrivacyPage() {
  return (
    <>
      <Nav />
      <main className={styles.main}>
        <div className={styles.inner}>
          <p className={styles.updated}>Last updated: March 2026</p>
          <h1 className={styles.headline}>Privacy Policy</h1>
          <p className={styles.lead}>
            PiDay is a simple calculator — it looks up dates in the digits of pi.
            It doesn&rsquo;t need your name, your email, or your location.
            Here&rsquo;s the full picture.
          </p>

          <section className={styles.section}>
            <h2>What we collect</h2>
            <p>
              Almost nothing. Everything in PiDay stays on your device. Your saved dates,
              your chosen theme, your preferences — all stored locally in iOS&rsquo;s{' '}
              <code>UserDefaults</code> and never transmitted anywhere.
            </p>
            <p>
              The one exception: if you look up a date outside the years 2026–2035, the app
              sends that date (as a digit string like <code>14031995</code>) to the{' '}
              <a href="https://pisearch.joshkeegan.co.uk" rel="noopener noreferrer" target="_blank">
                PiSearch API
              </a>{' '}
              to find its position. No name, no device ID, no metadata — just the digits.
            </p>
          </section>

          <section className={styles.section}>
            <h2>Data we do not collect</h2>
            <ul>
              <li>No account, no sign-in, no email address</li>
              <li>No location data — never requested</li>
              <li>No contacts — the birthday picker reads only the date field of a contact you choose; nothing is stored or sent</li>
              <li>No device identifiers or advertising IDs</li>
              <li>No usage analytics or crash reporters beyond Apple&rsquo;s standard platform reporting</li>
            </ul>
          </section>

          <section className={styles.section}>
            <h2>Third-party services</h2>
            <p>PiDay uses two external services:</p>
            <ul>
              <li>
                <strong>PiSearch API</strong> (<code>pisearch.joshkeegan.co.uk</code>) — for
                date lookups outside the bundled range. Only the digit sequence is sent.
              </li>
              <li>
                <strong>Apple</strong> — the App Store, Apple&rsquo;s crash reporting
                infrastructure, and the StoreKit review prompt. Governed by{' '}
                <a href="https://www.apple.com/privacy/" rel="noopener noreferrer" target="_blank">
                  Apple&rsquo;s Privacy Policy
                </a>.
              </li>
            </ul>
          </section>

          <section className={styles.section}>
            <h2>Data retention</h2>
            <p>
              All data lives on your device. Deleting the app removes everything.
              We have no servers holding your data and no way to retrieve it.
            </p>
          </section>

          <section className={styles.section}>
            <h2>Children</h2>
            <p>
              PiDay is suitable for all ages. We do not knowingly collect any information
              from anyone, including children.
            </p>
          </section>

          <section className={styles.section}>
            <h2>Contact</h2>
            <p>
              Questions? Email us at{' '}
              <a href="mailto:privacy@glasscode.academy">privacy@glasscode.academy</a>.
            </p>
          </section>

          <section className={styles.section}>
            <h2>Changes to this policy</h2>
            <p>
              If anything changes, we&rsquo;ll update this page and the date above.
              The app will never collect more than what&rsquo;s described here without
              a visible, explicit update.
            </p>
          </section>
        </div>
      </main>
      <Footer />
    </>
  )
}
```

- [ ] **Step 2: Write privacy.module.scss**

Create `website/src/app/privacy/privacy.module.scss`:

```scss
.main {
  background: var(--color-bg-white);
  min-height: calc(100vh - var(--nav-height));
}

.inner {
  max-width: 680px;
  margin: 0 auto;
  padding: var(--space-10) var(--space-6) var(--space-12);
}

.updated {
  font-family: var(--font-mono);
  font-size: 10px;
  letter-spacing: 0.2em;
  text-transform: uppercase;
  color: var(--color-ink-faint);
  margin-bottom: var(--space-2);
}

.headline {
  font-size: clamp(32px, 5vw, 48px);
  margin-bottom: var(--space-3);
}

.lead {
  font-size: 17px;
  line-height: 1.7;
  color: var(--color-ink-muted);
  margin-bottom: var(--space-6);
  border-bottom: 1px solid var(--color-border);
  padding-bottom: var(--space-6);
}

.section {
  margin-bottom: var(--space-6);

  h2 {
    font-family: var(--font-serif);
    font-style: italic;
    font-weight: 400;
    font-size: 22px;
    color: var(--color-ink);
    margin-bottom: var(--space-2);
    letter-spacing: -0.02em;
  }

  p {
    font-size: 15px;
    line-height: 1.75;
    color: var(--color-ink-muted);
    margin-bottom: var(--space-2);

    &:last-child { margin-bottom: 0; }
  }

  ul {
    list-style: none;
    padding: 0;

    li {
      font-size: 15px;
      line-height: 1.75;
      color: var(--color-ink-muted);
      padding-left: var(--space-3);
      position: relative;
      margin-bottom: var(--space-1);

      &::before {
        content: '—';
        position: absolute;
        left: 0;
        color: var(--color-ink-faint);
        font-family: var(--font-serif);
      }
    }
  }

  code {
    font-family: var(--font-mono);
    font-size: 13px;
    background: rgba(0, 0, 0, 0.04);
    padding: 1px 5px;
    border-radius: 4px;
    color: var(--color-ink);
  }

  a {
    color: var(--color-ink);
    border-bottom: 1px solid var(--color-border);
    transition: border-color 0.15s;

    &:hover { border-color: var(--color-ink-muted); }
  }

  strong {
    font-weight: 600;
    color: var(--color-ink);
  }
}
```

- [ ] **Step 3: Build and verify**

```bash
cd website
pnpm build
```

Expected: `out/privacy/index.html` exists.

- [ ] **Step 4: Commit**

```bash
cd /Users/veland/PiDay
git add website/src/app/privacy/
git commit -m "feat(website): privacy policy page (App Store requirement)"
```

---

## Task 11: Deploy script and nginx setup

**Files:**
- Create: `website/deploy.sh`

- [ ] **Step 1: Create deploy.sh**

```bash
#!/usr/bin/env bash
# Deploy PiDay website to glasscode.academy
# Usage: bash deploy.sh
# Requirements:
#   - SSH alias "glasscode" configured in ~/.ssh/config
#   - nginx vhost for piday.glasscode.academy pointing to /var/www/piday.glasscode.academy
#   - pnpm installed locally
set -euo pipefail

REMOTE_HOST="glasscode"
REMOTE_PATH="/var/www/piday.glasscode.academy/"
SITE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "▸ Building..."
cd "$SITE_DIR"
pnpm build

echo "▸ Deploying to ${REMOTE_HOST}:${REMOTE_PATH}..."
rsync -avz --delete ./out/ "${REMOTE_HOST}:${REMOTE_PATH}"

echo "✓ Done — https://piday.glasscode.academy"
```

```bash
chmod +x website/deploy.sh
```

- [ ] **Step 2: Document the one-time server setup**

Add a comment block at the top of `deploy.sh` with nginx setup instructions (already included above). Also create `website/SERVER_SETUP.md`:

```markdown
# Server setup (one-time)

Run these on the glasscode server before first deploy:

```bash
# 1. Create web root
sudo mkdir -p /var/www/piday.glasscode.academy

# 2. Add nginx vhost
sudo tee /etc/nginx/sites-available/piday.glasscode.academy <<'EOF'
server {
    listen 80;
    server_name piday.glasscode.academy;
    root /var/www/piday.glasscode.academy;
    index index.html;
    location / { try_files $uri $uri/ $uri.html =404; }
}
EOF

sudo ln -s /etc/nginx/sites-available/piday.glasscode.academy \
           /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 3. After DNS propagates, add SSL
sudo certbot --nginx -d piday.glasscode.academy
```

DNS: add a CNAME or A record for `piday.glasscode.academy` → your server IP.
```

- [ ] **Step 3: Commit**

```bash
cd /Users/veland/PiDay
git add website/deploy.sh website/SERVER_SETUP.md
git commit -m "feat(website): rsync deploy script and server setup docs"
```

---

## Task 12: OG image placeholder and final verification

**Files:**
- Create: `website/public/og.png` (manual design step)

- [ ] **Step 1: Create a placeholder OG image**

The OG image is a manually designed 1200×630 PNG. For now, create a minimal placeholder so the build doesn't warn:

```bash
# Creates a 1200×630 black PNG placeholder — replace with real design before launch
cd website
node -e "
const { createCanvas } = require('canvas');
" 2>/dev/null || true

# If canvas isn't available, just copy any 1200x630 image as placeholder:
# cp /path/to/any/image.png public/og.png
# Or create one with ImageMagick if installed:
convert -size 1200x630 xc:'#0d0d12' \
  -font Helvetica -pointsize 80 -fill white \
  -gravity center -annotate 0 'π PiDay' \
  public/og.png 2>/dev/null || echo "⚠️  og.png not created — add manually to website/public/og.png before launch"
```

The final OG image should be designed separately and committed to `website/public/og.png`.

- [ ] **Step 2: Run all tests one final time**

```bash
cd website
pnpm test
```

Expected: all 4 tests PASS.

- [ ] **Step 3: Final build check**

```bash
cd website
pnpm build && echo "✓ Build clean"
ls out/index.html out/privacy/index.html
```

Expected: both files exist.

- [ ] **Step 4: Run dev server for visual inspection**

```bash
cd website
pnpm dev
```

Open http://localhost:3000 — verify:
- Nav is sticky and correct
- Hero shows two-column layout with digit canvas
- HowItWorks shows three numbered steps
- Themes shows six swatches and the CTA
- Footer shows privacy link
- `/privacy` page renders full policy

- [ ] **Step 5: Final commit**

```bash
cd /Users/veland/PiDay
git add website/public/
git commit -m "feat(website): add og.png placeholder, ready for deploy"
```

---

## Pre-launch checklist (manual steps before `bash deploy.sh`)

- [ ] Replace `APP_STORE_URL = '#'` in `website/src/lib/config.ts` with the live App Store link
- [ ] Design and commit the final `website/public/og.png` (1200×630)
- [ ] Add the privacy contact email `privacy@glasscode.academy` to the mail server
- [ ] Complete server setup from `website/SERVER_SETUP.md` (nginx vhost + certbot SSL)
- [ ] Add DNS record: `piday.glasscode.academy` → glasscode server IP
- [ ] Run `bash website/deploy.sh`
- [ ] Verify `https://piday.glasscode.academy` and `https://piday.glasscode.academy/privacy`
- [ ] Submit `https://piday.glasscode.academy/privacy` as the privacy URL in App Store Connect
