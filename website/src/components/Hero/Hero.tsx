'use client'

import { useEffect, useState } from 'react'
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

  useEffect(() => {
    const today = new Date()
    const isoDate = [
      String(today.getFullYear()),
      String(today.getMonth() + 1).padStart(2, '0'),
      String(today.getDate()).padStart(2, '0'),
    ].join('-')

    fetch(`/api/pi-date?date=${isoDate}`)
      .then(async (response) => {
        if (!response.ok) {
          throw new Error('Lookup failed')
        }
        return response.json() as Promise<HeroResult>
      })
      .then((data) => setResult(data))
      .catch(() => setError(true))
      .finally(() => setLoading(false))
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
    <section className={styles.hero}>
      <div className={styles.heroBg} aria-hidden="true">
        {BG_DIGITS}
      </div>

      <div className={styles.content}>
        <p className={styles.eyebrow}>pi · 3.14159 26535… · live lookup</p>

        <h1 className={styles.headline}>Today lives in pi.</h1>

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
            <div className={styles.loading} aria-live="polite" aria-label="Looking up today in pi">
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
                fallback while the app service is unavailable.
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

              <div className={styles.resultGrid}>
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
