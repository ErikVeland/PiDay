import { HERO_DIGITS, HERO_DATE, HERO_POSITION, buildDigitSpans } from '@/lib/pi-digits'
import { APP_STORE_URL } from '@/lib/config'
import styles from './Hero.module.scss'

// A large blob of π digits for the decorative background texture.
// We repeat HERO_DIGITS several times to ensure the texture fills the viewport.
const BG_DIGITS = HERO_DIGITS.repeat(8)

export default function Hero() {
  const spans = buildDigitSpans(HERO_DIGITS, HERO_DATE.day, HERO_DATE.month, HERO_DATE.year)

  return (
    <section className={styles.hero}>
      {/* Decorative π digit texture — purely visual, hidden from screen readers */}
      <div className={styles.heroBg} aria-hidden="true">
        {BG_DIGITS}
      </div>

      {/* Left column — headline + copy + CTAs */}
      <div className={styles.content}>
        <p className={styles.eyebrow}>π · 3.14159 26535…</p>

        <h1 className={styles.headline}>Your date lives in π.</h1>

        <p className={styles.body}>
          The nerdiest calendar app ever made. Every day, see exactly where today&rsquo;s
          date hides in five billion digits of π. Look up your birthday and discover
          your unique address in infinity.
        </p>

        <div className={styles.actions}>
          <a
            href={APP_STORE_URL}
            className={styles.btnPrimary}
            aria-label="Download PiDay free on the App Store"
          >
            Download free
          </a>
          <span className={styles.btnSecondary}>iPhone, iPad &amp; Mac</span>
        </div>
      </div>

      {/* Right column — digit canvas card */}
      <div className={styles.canvas}>
        <p className={styles.canvasLabel}>π — first 5 billion digits</p>

        <div className={styles.canvasBox}>
          {/* Digit stream with day/month/year highlighted in accent colours */}
          <div className={styles.digitRow} aria-label="π digit excerpt with date highlighted">
            {spans.map((span, i) => {
              if (span.kind === 'day') {
                return (
                  <span key={i} style={{ color: 'var(--color-day)', fontWeight: 700 }}>
                    {span.text}
                  </span>
                )
              }
              if (span.kind === 'month') {
                return (
                  <span key={i} style={{ color: 'var(--color-month)', fontWeight: 700 }}>
                    {span.text}
                  </span>
                )
              }
              if (span.kind === 'year') {
                return (
                  <span key={i} style={{ color: 'var(--color-year)', fontWeight: 700 }}>
                    {span.text}
                  </span>
                )
              }
              // kind === 'plain'
              return <span key={i}>{span.text}</span>
            })}
          </div>

          {/* Result chips — day / month / year breakdown */}
          <div className={styles.resultGrid}>
            <div className={styles.resultChip}>
              <span className={styles.resultLabel}>Day</span>
              <span className={styles.resultValue} style={{ color: 'var(--color-day)' }}>
                14
              </span>
              <span className={styles.resultSub}>March</span>
            </div>

            <div className={styles.resultChip}>
              <span className={styles.resultLabel}>Month</span>
              <span className={styles.resultValue} style={{ color: 'var(--color-month)' }}>
                03
              </span>
              <span className={styles.resultSub}>π Day ✦</span>
            </div>

            <div className={styles.resultChip}>
              <span className={styles.resultLabel}>Year</span>
              <span className={styles.resultValue} style={{ color: 'var(--color-year)' }}>
                1995
              </span>
              <span className={styles.resultSub}>found</span>
            </div>
          </div>

          {/* Position line */}
          <p className={styles.positionLine}>
            Position{' '}
            <strong className={styles.positionBold}>{HERO_POSITION}</strong>
            {' · format DDMMYYYY · 5 billion digits searched'}
          </p>
        </div>
      </div>
    </section>
  )
}
