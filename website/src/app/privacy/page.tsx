import type { Metadata } from 'next'
import Nav from '@/components/Nav/Nav'
import Footer from '@/components/Footer/Footer'
import styles from './Privacy.module.scss'
import { PRIVACY_EMAIL, SITE_URL } from '@/lib/site'

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: 'PiDay collects no personal data. No tracking, no ads, no account required.',
  alternates: {
    canonical: '/privacy',
  },
  openGraph: {
    title: 'Privacy Policy — PiDay',
    description: 'PiDay collects no personal data. No tracking, no ads, no account required.',
    url: `${SITE_URL}/privacy`,
    images: [{ url: '/og-privacy.png', width: 1200, height: 630, alt: 'PiDay Privacy Policy' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Privacy Policy — PiDay',
    description: 'PiDay collects no personal data. No tracking, no ads, no account required.',
    images: [{ url: '/og-privacy.png', alt: 'PiDay Privacy Policy' }],
  },
}

export default function PrivacyPage() {
  return (
    <>
      <Nav />
      <main className={styles.main}>
        <div className={styles.content}>
          <h1 className={styles.pageTitle}>Privacy Policy</h1>
          <p className={styles.dateLine}>Last updated: March 2026</p>

          <p className={styles.intro}>
            PiDay is a simple tool. It doesn&apos;t know who you are, track what
            you do, or sell anything. There are no accounts, no ads, and no
            third-party analytics frameworks.
          </p>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>What we collect</h2>
          <p className={styles.body}>
            The table below covers every category of data we considered. The
            short answer is: almost nothing leaves your device.
          </p>

          <table className={styles.table}>
            <thead>
              <tr>
                <th>Data</th>
                <th>Collected?</th>
                <th>Notes</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Name, email, account</td>
                <td className={styles.no}>No</td>
                <td>No account system</td>
              </tr>
              <tr>
                <td>Location</td>
                <td className={styles.no}>No</td>
                <td>Never requested</td>
              </tr>
              <tr>
                <td>Contacts</td>
                <td className={styles.no}>No</td>
                <td>Birthday contact picker reads only the date field; nothing is stored server-side</td>
              </tr>
              <tr>
                <td>Device identifiers</td>
                <td className={styles.no}>No</td>
                <td></td>
              </tr>
              <tr>
                <td>Usage analytics</td>
                <td className={styles.no}>No</td>
                <td>No third-party SDK</td>
              </tr>
              <tr>
                <td>Date queries</td>
                <td>Transiently</td>
                <td>
                  Dates outside the bundled 2026–2035 range are sent to the
                  PiSearch API (pisearch.joshkeegan.co.uk) as digit strings
                  only — no personal metadata
                </td>
              </tr>
              <tr>
                <td>Saved dates</td>
                <td>Locally only</td>
                <td>Stored in UserDefaults on-device; never transmitted</td>
              </tr>
              <tr>
                <td>Preferences</td>
                <td>Locally only</td>
                <td>Theme, font, date format — UserDefaults on-device</td>
              </tr>
              <tr>
                <td>Crash / diagnostics</td>
                <td>Via Apple only</td>
                <td>Standard iOS crash reporting through Apple&apos;s platform; no additional SDK</td>
              </tr>
            </tbody>
          </table>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>Third-party services</h2>
          <p className={styles.body}>
            <strong>PiSearch API</strong> (pisearch.joshkeegan.co.uk) — used
            when you search a date outside the bundled 2026–2035 range. Only
            the digit sequence representing your date is sent — no metadata, no
            device ID, no location.
          </p>
          <p className={styles.body}>
            <strong>Apple</strong> — App Store delivery, standard iOS crash
            reporting, and StoreKit review prompt. Subject to Apple&apos;s own
            privacy policy.
          </p>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>Data retention</h2>
          <p className={styles.body}>
            All saved dates and preferences stay on your device. If you delete
            the app, all data is deleted with it. We don&apos;t store anything
            server-side.
          </p>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>Children</h2>
          <p className={styles.body}>
            PiDay is suitable for all ages. No personal data is collected from
            anyone, including children.
          </p>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>Contact</h2>
          <p className={styles.body}>
            Questions? Email us at{' '}
            <a href={`mailto:${PRIVACY_EMAIL}`} className={styles.contactEmail}>
              {PRIVACY_EMAIL}
            </a>
          </p>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>Changes</h2>
          <p className={styles.body}>
            This policy may be updated occasionally. The date at the top of
            this page shows when it was last revised. Continued use of the app
            after a policy update means you&apos;ve seen the new version.
          </p>
        </div>
      </main>
      <Footer />
    </>
  )
}
