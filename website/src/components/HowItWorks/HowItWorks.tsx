import styles from './HowItWorks.module.scss'

const HEAT_CELLS = [
  '#d95c28', '#e8934a', '#c2dcd8', '#ebebeb',
  '#e8934a', '#c2dcd8', '#ebebeb', '#ebebeb',
  '#c2dcd8', '#ebebeb', '#ebebeb', '#ebebeb',
  '#ebebeb', '#ebebeb', '#ebebeb', '#ebebeb',
]

export default function HowItWorks() {
  return (
    <section className={styles.section}>
      <div className={styles.inner}>
        <div className={styles.sectionLabel}>How it works</div>

        <div className={styles.layout}>
          <h2 className={styles.headline}>Three steps to your place in infinity.</h2>

          {/* Left column: stacked steps */}
          <div className={styles.left}>
            <div className={styles.steps}>
              {/* Step 1 */}
              <div className={styles.step}>
                <div className={styles.stepNumber}>01</div>
                <div className={styles.stepVisual}>
                  <span className={styles.digitChip} style={{ color: 'var(--color-day)', borderColor: 'var(--color-day)' }}>14</span>
                  <span className={styles.digitChip} style={{ color: 'var(--color-month)', borderColor: 'var(--color-month)' }}>03</span>
                  <span className={styles.digitChip} style={{ color: 'var(--color-year)', borderColor: 'var(--color-year)' }}>1995</span>
                </div>
                <h3 className={styles.stepTitle}>Pick your date</h3>
                <p className={styles.stepBody}>
                  Open to today, or pick any birthday, anniversary, or date that matters. PiDay searches across five billion digits of π in every date format simultaneously.
                </p>
              </div>

              {/* Step 2 */}
              <div className={styles.step}>
                <div className={styles.stepNumber}>02</div>
                <div className={styles.stepVisual}>
                  <div className={styles.heatGrid}>
                    {HEAT_CELLS.map((color, i) => (
                      <div key={i} className={styles.heatCell} style={{ background: color }} />
                    ))}
                  </div>
                </div>
                <h3 className={styles.stepTitle}>See the heat map</h3>
                <p className={styles.stepBody}>
                  A calendar fills with colour — hotter dates appear earlier in π. See at a glance how your whole month compares, date by date.
                </p>
              </div>

              {/* Step 3 */}
              <div className={styles.step}>
                <div className={styles.stepNumber}>03</div>
                <div className={styles.stepVisual}>
                  <span className={styles.shareChip} style={{ background: 'rgba(217,92,40,0.10)', color: 'var(--color-day)' }}>Day 14</span>
                  <span className={styles.shareChip} style={{ background: 'rgba(14,154,142,0.10)', color: 'var(--color-month)' }}>Month 03</span>
                  <span className={styles.shareChip} style={{ background: 'rgba(74,122,191,0.10)', color: 'var(--color-year)' }}>Year 1995</span>
                </div>
                <h3 className={styles.stepTitle}>Share the discovery</h3>
                <p className={styles.stepBody}>
                  Save your result as a card and share it. Six themes, multiple date formats, and a canvas of π digits you can scroll forever.
                </p>
              </div>
            </div>
          </div>

          {/* Right column: phone screenshot */}
          <div className={styles.right}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/screenshot.png"
              alt="PiDay app showing a calendar heat map of March 2026"
              className={styles.phone}
              width={330}
              height={715}
            />
          </div>
        </div>
      </div>
    </section>
  )
}
