# PiDay Website — Design Spec
**Date:** 2026-03-22
**URL:** https://piday.glasscode.academy
**Stack:** Next.js 16 (static export) · SCSS modules · No Tailwind · SSH rsync deploy

---

## Summary

A single-page marketing website for the PiDay iOS app. Minimal Mathematical aesthetic — off-white ground, no decoration except the digits of π themselves. Classic serif (Georgia italic) for headlines, SF Mono for all digit sequences, system sans for body text. Three sections, no JavaScript frameworks beyond Next.js itself.

---

## Visual Identity

### Design Direction
**Minimal Mathematical** — white space as deliberate silence. The π symbol and the digit stream are the only decoration. Feels like a Cambridge maths textbook met a modern product site.

### Colour Palette
```
Background (page ground):   #f9f8f5  — warm off-white
Section 2 background:       #ffffff  — pure white
Ink (primary text):         #111111
Muted ink:                  #777777
Very muted / labels:        #bbbbbb
Borders / dividers:         rgba(0,0,0,0.07)
Button background:          #111111
Button text:                #f9f8f5

Digit accent — Day:         #d95c28  (orange — matches app Ember/default)
Digit accent — Month:       #0e9a8e  (teal)
Digit accent — Year:        #4a7abf  (blue)
```

### Typography
| Role | Font | Weight | Style |
|------|------|--------|-------|
| Headlines (h1, h2) | Georgia | 400 | Italic |
| Digit streams | SF Mono / Menlo / monospace | 700 for highlights, 400 otherwise | Normal |
| Body copy | System sans (-apple-system, sans-serif) | 400 | Normal |
| Labels / eyebrows | SF Mono / monospace | 400 | Normal, UPPERCASE, letter-spaced |
| CTAs / buttons | System sans | 600 | Normal |

### Background Digit Texture
The hero section has the actual digits of π (hardcoded string, first ~500 digits) rendered at very low opacity (`rgba(0,0,0,0.045)`) as a full-bleed background texture. This is purely decorative, `aria-hidden`, `user-select: none`.

---

## Page Structure

### Navigation (sticky)
- Left: `π PiDay` wordmark in SF Mono
- Right: "App Store →" pill button (outlined, dark ink)
- Background: `rgba(249,248,245,0.97)` + backdrop-filter blur
- Height: 56px

### Section 1 — Hero
**Layout:** Two-column grid, 1fr / 1fr, aligned center, min-height ~540px
**Background:** `#f9f8f5` + faint π digit texture

**Left column (content):**
- Eyebrow: `π · 3.14159 26535…` — SF Mono, 11px, letter-spaced, muted
- H1: `"Your date lives in π."` — Georgia italic, 52px, color `#111`
- Body: 16px Georgia, muted, max-width 380px — 1–2 sentences explaining the concept
- CTA row: primary dark button "Download free" + secondary link "iPhone & iPad"

**Right column (digit canvas):**
- White card, subtle shadow, 10px border-radius
- Label: `π — first 5 billion digits` in SF Mono caps
- Digit stream: hardcoded excerpt of π showing a date highlighted in three colors (DD in orange, MM in teal, YYYY in blue)
- Result row: three chips showing Day / Month / Year with their accent color and position info
- Position line: `Position 47,832,104 · format DDMMYYYY · 5 billion digits searched`

### Section 2 — How it works
**Background:** `#ffffff`
**Layout:** Full-width section, 96px vertical padding

**Top:**
- Section label: `How it works` — SF Mono caps, 9px, letter-spaced, with a right-extending hairline rule
- H2: `"Three steps to your place in infinity."` — Georgia italic, 38px

**Three-column step grid** (separated by hairline rules):
1. **Pick your date** — visual: digit stream with date highlighted; body copy about 5B digit search across all formats simultaneously
2. **See the heat map** — visual: mini calendar grid with heat-level colour cells (hot/warm/cool/faint using the app's actual palette); body copy about month comparison view
3. **Share the discovery** — visual: three share chips with colour dots; body copy about themes, formats, shareable card

Each step: numbered `01`/`02`/`03` in SF Mono, italic Georgia title, system sans body.

### Section 3 — Themes + Download CTA
**Background:** `#f9f8f5`
**Layout:** Full-width section, 96px vertical padding

**Top:**
- Section label: `Themes`
- H2: `"Six ways to see your number."` — Georgia italic, 38px
- Subhead: one sentence about themes, Georgia 15px muted

**Theme swatches grid** (6 columns):
Each swatch is a tall card (aspect-ratio 3/4) with:
- Background colour matching the app theme's `swatchBackground`
- A 3-segment accent bar showing Day / Month / Year colours
- Theme name in SF Mono
- `·light·` or `·dark·` tag

Themes: Frost, Slate, Coppice, Ember, Aurora, Matrix (in that order)

**Final CTA** (separated by hairline, flex row):
- Left: `"Find your date in π."` — Georgia italic 28px + `Free · iPhone & iPad · iOS 17+` muted
- Right: "Download on the App Store" button (dark, large) + `FREE · NO ADS · NO TRACKING` note in SF Mono

### Footer
- White background, hairline top border
- Left: `π PiDay` in SF Mono muted
- Right: `© 2026 glasscode.academy · Made with curiosity`

---

## Technical Architecture

### Stack
- **Framework:** Next.js 16, App Router
- **Output:** `output: 'export'` — fully static HTML/CSS/JS, no server runtime
- **Styling:** SCSS modules per component, no Tailwind, no CSS-in-JS
- **Fonts:** `next/font/google` — Playfair Display as Georgia fallback for web (or system Georgia), plus `next/font/local` or system monospace stack
- **Images:** `next/image` with `unoptimized: true` (required for static export)
- **Animations:** CSS keyframes only, no JS animation libraries

### Project Structure
```
website/
├── src/
│   ├── app/
│   │   ├── layout.tsx        — root layout, font vars, metadata
│   │   ├── page.tsx          — single page, imports all sections
│   │   └── globals.scss      — reset, CSS custom properties, base typography
│   ├── components/
│   │   ├── Nav/
│   │   │   ├── Nav.tsx
│   │   │   └── Nav.module.scss
│   │   ├── Hero/
│   │   │   ├── Hero.tsx
│   │   │   └── Hero.module.scss
│   │   ├── HowItWorks/
│   │   │   ├── HowItWorks.tsx
│   │   │   └── HowItWorks.module.scss
│   │   ├── Themes/
│   │   │   ├── Themes.tsx
│   │   │   └── Themes.module.scss
│   │   └── Footer/
│   │       ├── Footer.tsx
│   │       └── Footer.module.scss
│   └── lib/
│       └── pi-digits.ts      — hardcoded π excerpt + digit highlighting utility
├── public/
│   └── (app screenshots, og image)
├── next.config.ts
├── package.json
└── tsconfig.json
```

### SCSS Approach
- One `globals.scss` for: CSS custom properties (all colours, font stacks, spacing scale), reset, base `body`/`h1`-`h6`/`p` styles
- Per-component `.module.scss` for everything else — no global class leakage
- No `@apply`, no utility classes — real SCSS: nesting, `&` selectors, `@mixin`, `@include`
- Spacing via a consistent 8px grid (`--space-1: 8px` through `--space-12: 96px`)

### Static Export Config
```ts
// next.config.ts
const config = {
  output: 'export',
  trailingSlash: true,
  images: { unoptimized: true },
}
```

---

## Deployment

### Server Assumption
nginx on the `glasscode` SSH host, serving from `/var/www/piday.glasscode.academy/`.

### DNS
Add a CNAME or A record for `piday.glasscode.academy` pointing to the glasscode server. Add an nginx vhost for the subdomain.

### Deploy Script (`deploy.sh`)
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "▸ Building..."
pnpm build

echo "▸ Deploying to glasscode..."
rsync -avz --delete ./out/ glasscode:/var/www/piday.glasscode.academy/

echo "✓ Done — https://piday.glasscode.academy"
```

Run with: `bash deploy.sh` from the `website/` directory.

### nginx vhost (to be added on server)
```nginx
server {
    listen 80;
    server_name piday.glasscode.academy;
    root /var/www/piday.glasscode.academy;
    index index.html;
    location / { try_files $uri $uri/ $uri.html =404; }
}
```
SSL via `certbot --nginx -d piday.glasscode.academy` after DNS propagates.

---

## Content

### Copy (final)
- **H1:** *Your date lives in π.*
- **Body (hero):** Somewhere in the infinite decimal expansion of pi, your birthday is hiding. PiDay finds it — and shows you exactly where.
- **Step 1:** Pick any birthday, anniversary, or date that matters. PiDay searches across five billion digits of π in every date format simultaneously.
- **Step 2:** A calendar fills with colour — hotter dates appear earlier in π. See at a glance how your whole month compares, date by date.
- **Step 3:** Save your result as a card and share it. Six themes, multiple date formats, and a canvas of π digits you can scroll forever.
- **Themes sub:** From warm parchment to phosphor green — each theme is a distinct world. Change anytime.
- **Final CTA:** *Find your date in π.*

### App Store Link
Placeholder `#` until live link is available. Stored in a single `lib/config.ts` constant so it's one edit to update.

---

## Open Graph / SEO
- Title: `PiDay — Find your birthday in π`
- Description: `Your birthday is hiding somewhere in the infinite digits of pi. PiDay finds it.`
- OG image: 1200×630, dark background, the π symbol large, a digit stream with a date highlighted — generated as a static PNG in `public/og.png`

---

## Accessibility
- All decorative digit textures: `aria-hidden="true"`
- Colour is never the sole indicator (digit highlighting also uses font-weight)
- App Store button has descriptive `aria-label`
- Reduced-motion: CSS `@media (prefers-reduced-motion)` suppresses any scroll animations

---

## Out of Scope
- No JavaScript animation libraries (Framer Motion, GSAP, etc.)
- No contact form, no email capture
- No analytics (by choice — "NO TRACKING" is part of the brand message)
- No i18n
- No dark mode toggle (the site is intentionally light-only; the app handles its own theming)
