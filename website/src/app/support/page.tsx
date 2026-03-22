import type { Metadata } from 'next'
import Nav from '@/components/Nav/Nav'
import Footer from '@/components/Footer/Footer'
import styles from '../privacy/Privacy.module.scss'

export const metadata: Metadata = {
  title: 'Support — PiDay',
  description: 'Get help with PiDay — the pi digit calendar app for iPhone, iPad and Mac.',
}

export default function SupportPage() {
  return (
    <>
      <Nav />
      <main className={styles.main}>
        <div className={styles.content}>
          <h1 className={styles.pageTitle}>Support</h1>
          <p className={styles.dateLine}>PiDay · iPhone, iPad &amp; Mac</p>

          <p className={styles.intro}>
            Something not working, or just curious about how PiDay finds your date in π?
            We&rsquo;re happy to help.
          </p>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>Contact</h2>
          <p className={styles.body}>
            Email us at{' '}
            <a href="mailto:support@glasscode.academy" className={styles.contactEmail}>
              support@glasscode.academy
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
            the first five billion decimal digits of π — your date has a unique address
            in infinity. You can also search any other date (birthdays, anniversaries)
            and see a heat map of your whole month: hotter colours mean the date appears
            earlier in π.
          </p>

          <h3 className={styles.sectionHeading} style={{ fontSize: '17px', marginTop: '24px' }}>
            How are dates searched?
          </h3>
          <p className={styles.body}>
            PiDay searches five date formats simultaneously — DDMMYYYY, MMDDYYYY,
            YYYYMMDD, YYMMDD, and D/M/YYYY — and shows the earliest match across all
            of them. You can filter to a specific format in Settings.
          </p>

          <h3 className={styles.sectionHeading} style={{ fontSize: '17px', marginTop: '24px' }}>
            Why is my date shown as &ldquo;not found&rdquo;?
          </h3>
          <p className={styles.body}>
            Every date does appear somewhere in π — but beyond five billion digits, we
            can&rsquo;t confirm a match with the data we have. For dates outside the
            bundled 2026–2035 index, PiDay queries the PiSearch API. If your connection
            is offline or the API is unavailable, the search may fail temporarily.
          </p>

          <h3 className={styles.sectionHeading} style={{ fontSize: '17px', marginTop: '24px' }}>
            What is the &ldquo;position&rdquo; number?
          </h3>
          <p className={styles.body}>
            It&rsquo;s how far into the decimal expansion of π your date first appears —
            position 1 is the first digit after the decimal point (1 in 3.14159…).
            You can toggle between 0-based and 1-based counting in Settings.
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
