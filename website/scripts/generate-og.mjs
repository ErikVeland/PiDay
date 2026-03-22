/**
 * Build-time OG image generator.
 * Runs before `next build` to produce static PNG files in public/.
 * Uses Satori (JSX → SVG) + @resvg/resvg-js (SVG → PNG).
 *
 * Usage: node scripts/generate-og.mjs
 */

import satori from 'satori'
import { renderAsync } from '@resvg/resvg-js'
import { writeFileSync, mkdirSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const PUBLIC_DIR = join(__dirname, '..', 'public')
mkdirSync(PUBLIC_DIR, { recursive: true })

// ── Colour tokens (match globals.scss) ──────────────────────────────────────
const C = {
  bg:      '#0d0d0f',   // near-black — OG images pop more on dark
  surface: '#161618',   // card surface
  border:  'rgba(255,255,255,0.07)',
  ink:     '#f0f0f0',
  muted:   'rgba(255,255,255,0.45)',
  faint:   'rgba(255,255,255,0.18)',
  day:     '#d95c28',
  month:   '#0e9a8e',
  year:    '#4a7abf',
}

// ── Fonts (embedded as base64 is heavy; use system stack via weight hints) ──
// Satori requires at least one font. We embed a minimal subset of a
// monospace font. For simplicity we use the Google Fonts API at build time
// (server-to-server, no tracking impact) to fetch a small Latin subset.
// Fetch font binary from a URL
async function fetchFont(url) {
  const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } })
  if (!res.ok) throw new Error(`Font fetch failed: ${res.status} ${url}`)
  return Buffer.from(await res.arrayBuffer())
}

// Resolve actual font file URLs from Google Fonts CSS API
async function resolveFontUrls(family) {
  const url = `https://fonts.googleapis.com/css2?family=${encodeURIComponent(family)}&display=swap`
  const res = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; node/og-gen)' },
  })
  const css = await res.text()
  return [...css.matchAll(/url\((https:\/\/fonts\.gstatic\.com[^)]+)\)/g)].map(m => m[1])
}

// A short π excerpt with the target date embedded
const PI_BEFORE = '31415926535897932384626433832795'
const DATE_DD   = '14'
const DATE_MM   = '03'
const DATE_YYYY = '1995'
const PI_AFTER  = '11706798214808651328230664709384'

async function generateImage({ title, subtitle, filename }) {
  // ── Fetch fonts once ────────────────────────────────────────────────────
  const [interUrls, jbUrls] = await Promise.all([
    resolveFontUrls('Inter:wght@400;700'),
    resolveFontUrls('JetBrains Mono:wght@400'),
  ])
  const [interRegular, interBold, jetbrainsRegular] = await Promise.all([
    fetchFont(interUrls[0]),
    fetchFont(interUrls[1] ?? interUrls[0]),
    fetchFont(jbUrls[0]),
  ])

  const fonts = [
    { name: 'Inter', data: interRegular, weight: 400, style: 'normal' },
    { name: 'Inter', data: interBold,    weight: 700, style: 'normal' },
    { name: 'JetBrains Mono', data: jetbrainsRegular, weight: 400, style: 'normal' },
  ]

  // ── Layout (1200 × 630) ─────────────────────────────────────────────────
  const svg = await satori(
    {
      type: 'div',
      props: {
        style: {
          width: '1200px',
          height: '630px',
          background: C.bg,
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          padding: '64px 72px',
          fontFamily: 'Inter',
          position: 'relative',
        },
        children: [

          // ── Top row: wordmark + tagline ──────────────────────────────────
          {
            type: 'div',
            props: {
              style: { display: 'flex', alignItems: 'center', gap: '12px' },
              children: [
                {
                  type: 'div',
                  props: {
                    style: {
                      fontFamily: 'JetBrains Mono',
                      fontSize: '18px',
                      color: C.muted,
                      letterSpacing: '1px',
                    },
                    children: 'π PiDay',
                  },
                },
              ],
            },
          },

          // ── Centre: big headline ─────────────────────────────────────────
          {
            type: 'div',
            props: {
              style: {
                display: 'flex',
                flexDirection: 'column',
                gap: '16px',
              },
              children: [
                {
                  type: 'div',
                  props: {
                    style: {
                      fontSize: title.length > 25 ? '52px' : '64px',
                      fontWeight: 700,
                      color: C.ink,
                      lineHeight: '1.1',
                      letterSpacing: '-2px',
                    },
                    children: title,
                  },
                },
                subtitle
                  ? {
                      type: 'div',
                      props: {
                        style: {
                          fontSize: '22px',
                          color: C.muted,
                          fontWeight: 400,
                          letterSpacing: '-0.5px',
                          maxWidth: '720px',
                        },
                        children: subtitle,
                      },
                    }
                  : null,
              ].filter(Boolean),
            },
          },

          // ── Bottom: digit stream card ────────────────────────────────────
          {
            type: 'div',
            props: {
              style: {
                display: 'flex',
                flexDirection: 'column',
                gap: '14px',
              },
              children: [
                // Digit stream
                {
                  type: 'div',
                  props: {
                    style: {
                      fontFamily: 'JetBrains Mono',
                      fontSize: '16px',
                      letterSpacing: '3px',
                      display: 'flex',
                      flexWrap: 'wrap',
                    },
                    children: [
                      {
                        type: 'span',
                        props: { style: { color: C.faint }, children: PI_BEFORE },
                      },
                      {
                        type: 'span',
                        props: { style: { color: C.day, fontWeight: 700 }, children: DATE_DD },
                      },
                      {
                        type: 'span',
                        props: { style: { color: C.month, fontWeight: 700 }, children: DATE_MM },
                      },
                      {
                        type: 'span',
                        props: { style: { color: C.year, fontWeight: 700 }, children: DATE_YYYY },
                      },
                      {
                        type: 'span',
                        props: { style: { color: C.faint }, children: PI_AFTER },
                      },
                    ],
                  },
                },
                // Three accent dots
                {
                  type: 'div',
                  props: {
                    style: { display: 'flex', gap: '8px', alignItems: 'center' },
                    children: [
                      { type: 'div', props: { style: { width: '8px', height: '8px', borderRadius: '50%', background: C.day } } },
                      { type: 'div', props: { style: { fontFamily: 'JetBrains Mono', fontSize: '10px', color: C.day, letterSpacing: '1px' }, children: 'DAY' } },
                      { type: 'div', props: { style: { width: '8px', height: '8px', borderRadius: '50%', background: C.month, marginLeft: '12px' } } },
                      { type: 'div', props: { style: { fontFamily: 'JetBrains Mono', fontSize: '10px', color: C.month, letterSpacing: '1px' }, children: 'MONTH' } },
                      { type: 'div', props: { style: { width: '8px', height: '8px', borderRadius: '50%', background: C.year, marginLeft: '12px' } } },
                      { type: 'div', props: { style: { fontFamily: 'JetBrains Mono', fontSize: '10px', color: C.year, letterSpacing: '1px' }, children: 'YEAR' } },
                    ],
                  },
                },
              ],
            },
          },

        ],
      },
    },
    {
      width: 1200,
      height: 630,
      fonts,
    }
  )

  const resvg = await renderAsync(svg, { fitTo: { mode: 'width', value: 1200 } })
  const png = resvg.asPng()
  const outPath = join(PUBLIC_DIR, filename)
  writeFileSync(outPath, png)
  console.log(`✓ ${filename} (${Math.round(png.length / 1024)} KB)`)
}

// ── Generate all OG images ───────────────────────────────────────────────────
console.log('Generating OG images…')
await Promise.all([
  generateImage({
    title: 'Find your date in π.',
    subtitle: 'The nerdiest calendar app. Every date has a unique address in the infinite digits of π.',
    filename: 'og.png',
  }),
  generateImage({
    title: 'Privacy Policy',
    subtitle: 'No tracking. No ads. No account. PiDay — piday.glasscode.academy',
    filename: 'og-privacy.png',
  }),
  generateImage({
    title: 'Support',
    subtitle: 'Questions about PiDay? We\'re here. PiDay — piday.glasscode.academy',
    filename: 'og-support.png',
  }),
])
console.log('Done.')
