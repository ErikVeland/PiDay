'use client'

import { useEffect, useRef, useState } from 'react'
import { HERO_DATE, HERO_DIGITS, HERO_POSITION, buildDigitSpans } from '@/lib/pi-digits'
import { APP_STORE_URL } from '@/lib/site'
import styles from './Hero.module.scss'

const BG_DIGITS = HERO_DIGITS.repeat(8)

interface HeroResult {
  isoDate: string
  dateLabel: string
  query: string
  format: string
  formatLabel: string
  source: 'bundled' | 'live'
  position: number
  before: string
  after: string
  dayStr: string
  monthStr: string
  yearStr: string
}

export default function Hero() {
  const [result, setResult] = useState<HeroResult | null>(null)
  const [error, setError] = useState(false)
  const [loading, setLoading] = useState(true)
  const latestIsoDateRef = useRef<string | null>(null)

  useEffect(() => {
    latestIsoDateRef.current = result?.isoDate ?? null
  }, [result?.isoDate])

  useEffect(() => {
    let cancelled = false
    let midnightTimer: number | null = null

    const lookupToday = async () => {
      const isoDate = localIsoDate()
      setLoading(true)
      setError(false)

      try {
        const response = await fetch(`/api/pi-date?date=${isoDate}`, { cache: 'no-store' })
        if (!response.ok) {
          throw new Error('Lookup failed')
        }

        const data = await response.json() as HeroResult
        if (!cancelled) {
          setResult(data)
        }
      } catch {
        if (!cancelled) {
          setError(true)
        }
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }

    const scheduleMidnightRefresh = () => {
      if (midnightTimer) {
        window.clearTimeout(midnightTimer)
      }

      const now = new Date()
      const nextMidnight = new Date(now)
      nextMidnight.setHours(24, 0, 5, 0)
      midnightTimer = window.setTimeout(async () => {
        await lookupToday()
        scheduleMidnightRefresh()
      }, nextMidnight.getTime() - now.getTime())
    }

    const handleVisibilityChange = () => {
      if (!document.hidden && latestIsoDateRef.current !== localIsoDate()) {
        void lookupToday()
      }
    }

    void lookupToday()
    scheduleMidnightRefresh()
    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      cancelled = true
      if (midnightTimer) {
        window.clearTimeout(midnightTimer)
      }
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [])

  const fallbackSpans = buildDigitSpans(HERO_DIGITS, HERO_DATE.day, HERO_DATE.month, HERO_DATE.year)
  const liveSpans = result
    ? [
        { kind: 'plain' as const, text: result.before },
        { kind: 'day' as const, text: result.dayStr },
        { kind: 'month' as const, text: result.monthStr },
        { kind: 'year' as const, text: result.yearStr },
        { kind: 'plain' as const, text: result.after },
      ]
    : fallbackSpans

  return (
    <section className={styles.hero} aria-labelledby="hero-title">
      <div className={styles.heroBg} aria-hidden="true">
        {BG_DIGITS}
      </div>

      <div className={styles.content}>
        <p className={styles.eyebrow}>pi · 3.14159 26535… · live lookup</p>

        <h1 id="hero-title" className={styles.headline}>Today lives in pi.</h1>

        <p className={styles.body}>
          PiDay opens to today and finds the earliest place your date appears in five
          billion digits of pi, using the same bundled index and live lookup rules as
          the app. Search birthdays, anniversaries, and anything else that matters.
        </p>

        <div className={styles.actions}>
          <a
            href={APP_STORE_URL}
            className={styles.btnPrimary}
            aria-label="Download PiDay free on the App Store"
            rel="noopener noreferrer"
          >
            Download free
          </a>
          <span className={styles.btnSecondary}>iPhone, iPad and Mac</span>
        </div>
      </div>

      <div className={styles.canvas}>
        <div className={styles.canvasHeader}>
          <p className={styles.canvasLabel}>today in pi</p>
          <p className={styles.canvasMeta}>
            {result ? `${result.dateLabel} · ${result.source}` : 'waiting for today'}
          </p>
        </div>

        <div className={styles.canvasBox}>
          {loading && (
            <div className={styles.loading} role="status" aria-live="polite" aria-label="Looking up today in pi">
              <span className={styles.loadingDots}>searching 5,000,000,000 digits</span>
            </div>
          )}

          {error && !loading && (
            <>
              <div className={styles.digitRow} aria-label="Illustrative pi digit excerpt">
                {fallbackSpans.map((span, i) => renderSpan(span, i))}
              </div>
              <p className={styles.errorMsg}>
                Today&apos;s live lookup could not load right now. Showing an illustrative
                fallback and retrying automatically when the page becomes active again.
              </p>
              <p className={styles.positionLine}>
                Position <strong className={styles.positionBold}>{HERO_POSITION}</strong>
                {' · illustrative demo excerpt'}
              </p>
            </>
          )}

          {!error && (
            <>
              <div className={styles.digitRow} aria-label="Pi digit excerpt with today highlighted">
                {liveSpans.map((span, i) => renderSpan(span, i))}
              </div>

              <div className={styles.resultGrid} aria-label="Search result summary">
                <div className={styles.resultChip}>
                  <span className={styles.resultLabel}>Day</span>
                  <span className={styles.resultValue} style={{ color: 'var(--color-day)' }}>
                    {result?.dayStr ?? HERO_DATE.day}
                  </span>
                  <span className={styles.resultSub}>today</span>
                </div>

                <div className={styles.resultChip}>
                  <span className={styles.resultLabel}>Month</span>
                  <span className={styles.resultValue} style={{ color: 'var(--color-month)' }}>
                    {result?.monthStr ?? HERO_DATE.month}
                  </span>
                  <span className={styles.resultSub}>{result?.formatLabel ?? 'DDMMYYYY'}</span>
                </div>

                <div className={styles.resultChip}>
                  <span className={styles.resultLabel}>Year</span>
                  <span className={styles.resultValue} style={{ color: 'var(--color-year)' }}>
                    {result?.yearStr ?? HERO_DATE.year}
                  </span>
                  <span className={styles.resultSub}>{result ? `${result.source} source` : 'demo fallback'}</span>
                </div>
              </div>

              <p className={styles.positionLine}>
                Position{' '}
                <strong className={styles.positionBold}>
                  {result ? result.position.toLocaleString() : HERO_POSITION}
                </strong>
                {` · format ${result?.formatLabel ?? 'DDMMYYYY'} · 5 billion digits searched`}
              </p>
            </>
          )}
        </div>
      </div>
    </section>
  )
}

function localIsoDate() {
  const formatter = new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  })

  const parts = formatter.formatToParts(new Date())
  const year = parts.find((part) => part.type === 'year')?.value
  const month = parts.find((part) => part.type === 'month')?.value
  const day = parts.find((part) => part.type === 'day')?.value

  if (!year || !month || !day) {
    const today = new Date()
    return [
      String(today.getFullYear()),
      String(today.getMonth() + 1).padStart(2, '0'),
      String(today.getDate()).padStart(2, '0'),
    ].join('-')
  }

  return `${year}-${month}-${day}`
}

function renderSpan(
  span: { kind: 'plain' | 'day' | 'month' | 'year'; text: string },
  key: number,
) {
  if (span.kind === 'day') {
    return (
      <span key={key} style={{ color: 'var(--color-day)', fontWeight: 700 }}>
        {span.text}
      </span>
    )
  }

  if (span.kind === 'month') {
    return (
      <span key={key} style={{ color: 'var(--color-month)', fontWeight: 700 }}>
        {span.text}
      </span>
    )
  }

  if (span.kind === 'year') {
    return (
      <span key={key} style={{ color: 'var(--color-year)', fontWeight: 700 }}>
        {span.text}
      </span>
    )
  }

  return <span key={key}>{span.text}</span>
}
