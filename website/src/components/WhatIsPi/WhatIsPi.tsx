import styles from './WhatIsPi.module.scss'

// First 104 digits of π after the decimal — displayed as the visual centrepiece
const PI_DIGITS = '3.14159265358979323846264338327950288419716939937510582097494459230781640628620899862803482534211706798214808651328230664709'

export default function WhatIsPi() {
  return (
    <section className={styles.section}>
      <div className={styles.inner}>

        {/* Section label */}
        <div className={styles.sectionLabel}>What is π</div>

        {/* Large digit display — the visual centrepiece */}
        <div className={styles.digitDisplay} aria-hidden="true">
          <span className={styles.piSymbol}>π =</span>
          <span className={styles.piDigits}>{PI_DIGITS.slice(2)}</span>
          <span className={styles.ellipsis}>…</span>
        </div>

        {/* Two-column prose */}
        <div className={styles.prose}>
          <div className={styles.col}>
            <h2 className={styles.headline}>
              The ratio at the heart of every circle.
            </h2>
            <p className={styles.body}>
              π is the ratio of a circle&rsquo;s circumference to its diameter — always,
              exactly, inevitably. Draw a circle of any size, measure its circumference,
              divide by its diameter, and you get the same number: 3.14159265…
            </p>
            <p className={styles.body}>
              But π refuses to stop. Unlike simple fractions (⅓ = 0.333…, which at least
              has a pattern), π is <em>irrational</em> — its decimal expansion neither
              terminates nor repeats. Mathematicians have computed it to over 100 trillion
              digits, and no pattern has ever emerged.
            </p>
          </div>

          <div className={styles.col}>
            <h2 className={styles.headline}>
              Transcendental. Infinite. Unknowable.
            </h2>
            <p className={styles.body}>
              π is also <em>transcendental</em> — it cannot be the solution to any
              algebraic equation with rational coefficients. This is why squaring the
              circle is impossible. π isn&rsquo;t just hard to pin down; it
              fundamentally resists every algebraic cage ever built for it.
            </p>
            <p className={styles.body}>
              And because it never repeats, it almost certainly contains every possible
              finite sequence of digits — your birthday, your phone number, every book
              ever written in numeric form, hiding somewhere in its infinite length.
              Probably. We can&rsquo;t prove it yet. But we can search.
            </p>
          </div>
        </div>

        {/* Pull quote */}
        <blockquote className={styles.pullQuote}>
          <p className={styles.pullQuoteText}>
            &ldquo;Probably contains every possible sequence of digits.
            We can&rsquo;t prove it yet.
            But we can search.&rdquo;
          </p>
        </blockquote>

      </div>
    </section>
  )
}
