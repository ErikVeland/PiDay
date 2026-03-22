import { APP_STORE_URL } from '@/lib/site'
import styles from './Themes.module.scss'

interface Theme {
  name: string
  mode: 'light' | 'dark'
  bg: string
  dayColor: string
  monthColor: string
  yearColor: string
}

const THEMES: Theme[] = [
  {
    name: 'Frost',
    mode: 'light',
    bg: '#f5f5f7',
    dayColor: '#2a7ef5',
    monthColor: '#34aadc',
    yearColor: '#5ac8fa',
  },
  {
    name: 'Slate',
    mode: 'dark',
    bg: '#1c1c1e',
    dayColor: '#d95c28',
    monthColor: '#0e9a8e',
    yearColor: '#4a7abf',
  },
  {
    name: 'Coppice',
    mode: 'dark',
    bg: '#1a2318',
    dayColor: '#7ab648',
    monthColor: '#c8a850',
    yearColor: '#5a9e6f',
  },
  {
    name: 'Ember',
    mode: 'light',
    bg: '#fdf6ee',
    dayColor: '#d95c28',
    monthColor: '#c8783c',
    yearColor: '#a0522d',
  },
  {
    name: 'Aurora',
    mode: 'dark',
    bg: '#0a0e1a',
    dayColor: '#7b68ee',
    monthColor: '#00d4aa',
    yearColor: '#ff6b9d',
  },
  {
    name: 'Matrix',
    mode: 'dark',
    bg: '#0d1a0d',
    dayColor: '#00ff41',
    monthColor: '#00cc33',
    yearColor: '#39ff14',
  },
]

export default function Themes() {
  return (
    <section className={styles.section}>
      <div className={styles.inner}>
        {/* Section label */}
        <div className={styles.sectionLabel}>Themes</div>

        {/* H2 */}
        <h2 className={styles.headline}>Six ways to see your number.</h2>

        {/* Subhead */}
        <p className={styles.subhead}>
          From warm parchment to phosphor green — each theme is a distinct world. Change anytime.
        </p>

        {/* Theme swatch grid */}
        <div className={styles.swatchGrid}>
          {THEMES.map((theme) => {
            const nameColor =
              theme.mode === 'light' ? 'rgba(0,0,0,0.7)' : 'rgba(255,255,255,0.7)'
            const modeColor =
              theme.mode === 'light' ? 'rgba(0,0,0,0.4)' : 'rgba(255,255,255,0.4)'

            return (
              <div
                key={theme.name}
                className={styles.swatch}
                style={{ background: theme.bg }}
              >
                {/* Three-segment accent bar */}
                <div className={styles.accentBar}>
                  <div style={{ background: theme.dayColor }} />
                  <div style={{ background: theme.monthColor }} />
                  <div style={{ background: theme.yearColor }} />
                </div>

                {/* Theme name */}
                <div>
                  <div className={styles.themeName} style={{ color: nameColor }}>
                    {theme.name}
                  </div>
                  <div className={styles.themeMode} style={{ color: modeColor }}>
                    {theme.mode === 'light' ? '· light ·' : '· dark ·'}
                  </div>
                </div>
              </div>
            )
          })}
        </div>

        {/* Final CTA */}
        <div className={styles.cta}>
          <div className={styles.ctaLeft}>
            <p className={styles.ctaHeadline}>Find your date in π.</p>
            <p className={styles.ctaSub}>Free · iPhone, iPad &amp; Mac · iOS 17+</p>
          </div>

          <div className={styles.ctaRight}>
            <a
              href={APP_STORE_URL}
              className={styles.btnPrimary}
              aria-label="Download PiDay free on the App Store"
            >
              Download on the App Store
            </a>
            <p className={styles.finePrint}>FREE · NO ADS · NO TRACKING</p>
          </div>
        </div>
      </div>
    </section>
  )
}
