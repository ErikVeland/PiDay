'use client'

import { useEffect, useState } from 'react'
import styles from './TodayWidget.module.scss'

interface PiResult {
  position: number
  before: string
  after: string
  query: string
  dayStr: string
  monthStr: string
  yearStr: string
  dateLabel: string
  numResults: number
}

function formatDate(d: Date): string {
  return d.toLocaleDateString('en-GB', {
    weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
  })
}

// Format today as DDMMYYYY
function toDDMMYYYY(d: Date): string {
  const dd = String(d.getDate()).padStart(2, '0')
  const mm = String(d.getMonth() + 1).padStart(2, '0')
  const yyyy = String(d.getFullYear())
  return `${dd}${mm}${yyyy}`
}

export default function TodayWidget() {
  const [result, setResult] = useState<PiResult | null>(null)
  const [error, setError] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const today = new Date()
    const query = toDDMMYYYY(today)
    const dd = query.slice(0, 2)
    const mm = query.slice(2, 4)
    const yyyy = query.slice(4, 8)

    fetch(`/api/pisearch?namedDigits=pi&find=${query}&resultId=0`)
      .then((r) => r.json())
      .then((data) => {
        if (!data.numResults) { setError(true); return }
        setResult({
          position: data.resultStringIdx + 1,
          before: data.surroundingDigits.before,
          after: data.surroundingDigits.after,
          query,
          dayStr: dd,
          monthStr: mm,
          yearStr: yyyy,
          dateLabel: formatDate(today),
          numResults: data.numResults,
        })
      })
      .catch(() => setError(true))
      .finally(() => setLoading(false))
  }, [])

  return (
    <section className={styles.section}>
      <div className={styles.inner}>
        <div className={styles.sectionLabel}>Today in π</div>
        <h2 className={styles.headline}>Where does today land?</h2>

        <div className={styles.card}>
          {loading && (
            <div className={styles.loading} aria-live="polite" aria-label="Looking up today in π">
              <span className={styles.loadingDots}>searching 5,000,000,000 digits</span>
            </div>
          )}

          {error && !loading && (
            <p className={styles.errorMsg}>Could not reach the π search API right now.</p>
          )}

          {result && !loading && (
            <>
              <div className={styles.dateRow}>
                <span className={styles.dateLabel}>{result.dateLabel}</span>
                <span className={styles.formatTag}>DDMMYYYY</span>
              </div>

              {/* Digit stream */}
              <div className={styles.digitRow} aria-label={`π digits around position ${result.position.toLocaleString()}`}>
                <span className={styles.context}>{result.before}</span>
                <span className={styles.day}>{result.dayStr}</span>
                <span className={styles.month}>{result.monthStr}</span>
                <span className={styles.year}>{result.yearStr}</span>
                <span className={styles.context}>{result.after}</span>
              </div>

              {/* Result chips */}
              <div className={styles.chips}>
                <div className={styles.chip}>
                  <span className={styles.chipLabel}>Day</span>
                  <span className={styles.chipValue} style={{ color: 'var(--color-day)' }}>{result.dayStr}</span>
                </div>
                <div className={styles.chip}>
                  <span className={styles.chipLabel}>Month</span>
                  <span className={styles.chipValue} style={{ color: 'var(--color-month)' }}>{result.monthStr}</span>
                </div>
                <div className={styles.chip}>
                  <span className={styles.chipLabel}>Year</span>
                  <span className={styles.chipValue} style={{ color: 'var(--color-year)' }}>{result.yearStr}</span>
                </div>
              </div>

              <p className={styles.position}>
                Position{' '}
                <strong className={styles.positionNum}>{result.position.toLocaleString()}</strong>
                {' · format DDMMYYYY · 5 billion digits searched'}
              </p>
            </>
          )}
        </div>
      </div>
    </section>
  )
}
