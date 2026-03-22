import type { Metadata } from 'next'
import Nav from '@/components/Nav/Nav'
import Footer from '@/components/Footer/Footer'
import styles from '../privacy/Privacy.module.scss'
import { SITE_URL, SUPPORT_EMAIL } from '@/lib/site'

export const metadata: Metadata = {
  title: 'Support',
  description: 'Get help with PiDay — the pi digit calendar app for iPhone, iPad and Mac.',
  alternates: {
    canonical: '/support',
  },
  openGraph: {
    title: 'Support — PiDay',
    description: 'Get help with PiDay — the pi digit calendar app for iPhone, iPad and Mac.',
    url: `${SITE_URL}/support`,
    images: [{ url: '/og-support.png', width: 1200, height: 630, alt: 'PiDay Support' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Support — PiDay',
    description: 'Get help with PiDay — the pi digit calendar app for iPhone, iPad and Mac.',
    images: [{ url: '/og-support.png', alt: 'PiDay Support' }],
  },
}

export default function SupportPage() {
  return (
    <>
      <Nav />
      <main className={styles.main}>
        <div className={styles.content}>
          <h1 className={styles.pageTitle}>Support</h1>
          <p className={styles.dateLine}>PiDay · iPhone, iPad and Mac</p>

          <p className={styles.intro}>
            Something not working, or just curious about how PiDay finds your date in pi?
            We&rsquo;re happy to help.
          </p>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>Contact</h2>
          <p className={styles.body}>
            Email us at{' '}
            <a href={`mailto:${SUPPORT_EMAIL}`} className={styles.contactEmail}>
              {SUPPORT_EMAIL}
            </a>{' '}
            and we&rsquo;ll get back to you as soon as we can.
          </p>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>Frequently asked questions</h2>

          <h3 className={styles.sectionHeading} style={{ fontSize: '17px', marginTop: '24px' }}>
            What does PiDay actually do?
          </h3>
          <p className={styles.body}>
            PiDay opens to today&rsquo;s date and shows you exactly where it appears in
            the first five billion decimal digits of pi — your date has a unique address
            in infinity. You can also search any other date and see a heat map of your
            whole month: hotter colours mean the date appears earlier in pi.
          </p>

          <h3 className={styles.sectionHeading} style={{ fontSize: '17px', marginTop: '24px' }}>
            How are dates searched?
          </h3>
          <p className={styles.body}>
            PiDay searches five date formats simultaneously — DDMMYYYY, MMDDYYYY,
            YYYYMMDD, YYMMDD, and D/M/YYYY — and shows the best app-style match,
            preferring padded dates over the shorter no-leading-zero format.
          </p>

          <h3 className={styles.sectionHeading} style={{ fontSize: '17px', marginTop: '24px' }}>
            Why is my date shown as &ldquo;not found&rdquo;?
          </h3>
          <p className={styles.body}>
            Every date does appear somewhere in pi — but beyond five billion digits, we
            can&rsquo;t confirm a match with the data we have. For dates outside the
            bundled 2026–2035 index, PiDay queries the PiSearch API. If your connection
            is offline or the API is unavailable, the search may fail temporarily.
          </p>

          <h3 className={styles.sectionHeading} style={{ fontSize: '17px', marginTop: '24px' }}>
            What is the &ldquo;position&rdquo; number?
          </h3>
          <p className={styles.body}>
            It&rsquo;s how far into the decimal expansion of pi your date first appears —
            position 1 is the first digit after the decimal point.
          </p>

          <h3 className={styles.sectionHeading} style={{ fontSize: '17px', marginTop: '24px' }}>
            Does PiDay collect any data?
          </h3>
          <p className={styles.body}>
            No. There are no accounts, no analytics, and no ads. All your saved dates
            and preferences stay on your device. See the{' '}
            <a href="/privacy" className={styles.contactEmail} style={{ fontSize: 'inherit' }}>
              privacy policy
            </a>{' '}
            for full details.
          </p>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>App version</h2>
          <p className={styles.body}>
            PiDay requires iOS 17 or later on iPhone and iPad, and macOS 14 or later on Mac.
            Make sure you&rsquo;re running the latest version from the App Store for the best
            experience.
          </p>
        </div>
      </main>
      <Footer />
    </>
  )
}
