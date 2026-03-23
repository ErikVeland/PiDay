import type { Metadata } from 'next'
import Nav from '@/components/Nav/Nav'
import Footer from '@/components/Footer/Footer'
import styles from '../privacy/Privacy.module.scss'
import { SITE_URL, SUPPORT_EMAIL } from '@/lib/site'

export const metadata: Metadata = {
  title: 'Accessibility',
  description: 'Accessibility information for PiDay on iPhone, iPad, Mac, and the PiDay website.',
  alternates: {
    canonical: '/accessibility',
  },
  openGraph: {
    title: 'Accessibility — PiDay',
    description: 'Accessibility information for PiDay on iPhone, iPad, Mac, and the PiDay website.',
    url: `${SITE_URL}/accessibility`,
    images: [{ url: '/og-support.png', width: 1200, height: 630, alt: 'PiDay Accessibility' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Accessibility — PiDay',
    description: 'Accessibility information for PiDay on iPhone, iPad, Mac, and the PiDay website.',
    images: [{ url: '/og-support.png', alt: 'PiDay Accessibility' }],
  },
}

export default function AccessibilityPage() {
  return (
    <>
      <Nav />
      <main id="main-content" className={styles.main} tabIndex={-1}>
        <div className={styles.content}>
          <h1 className={styles.pageTitle}>Accessibility</h1>
          <p className={styles.dateLine}>Last updated: March 23, 2026</p>

          <p className={styles.intro}>
            PiDay is designed to support common tasks for as many people as possible across
            iPhone, iPad, Mac, and the web. That includes opening the app, looking up a date,
            navigating the calendar, adjusting preferences, and finding help using assistive
            technologies and clear visual presentation.
          </p>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>App accessibility</h2>
          <p className={styles.body}>
            PiDay for iPhone and iPad includes explicit support for VoiceOver, Reduced Motion,
            and Dark Interface. Common controls are labeled, loading updates are announced,
            calendar dates expose spoken descriptions, and the main pi canvas is summarized for
            screen readers instead of requiring per-digit navigation.
          </p>
          <p className={styles.body}>
            The app also includes appearance controls, multiple themes, and adjustable digit
            sizes so people can tailor the visual presentation to their needs.
          </p>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>Website accessibility</h2>
          <p className={styles.body}>
            The PiDay website supports keyboard navigation, visible focus indication, skip links,
            semantic landmarks, reduced motion preferences, and readable contrast for core
            content and navigation. Decorative visuals are hidden from assistive technologies
            where appropriate, and live status updates in the hero section are announced politely.
          </p>
          <p className={styles.body}>
            We review the site against WCAG 2.2 AA principles and continue refining it as the
            product evolves.
          </p>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>Accessibility features</h2>
          <ul className={styles.list}>
            <li>VoiceOver-friendly labels and spoken status updates in the app</li>
            <li>Reduced Motion support in the app and on the website</li>
            <li>Dark appearance support in the app</li>
            <li>Keyboard-accessible website navigation</li>
            <li>Skip-to-content support and visible focus styles on the website</li>
            <li>Clear page structure with headings, landmarks, and readable body text</li>
          </ul>

          <hr className={styles.divider} />

          <h2 className={styles.sectionHeading}>Contact us</h2>
          <p className={styles.body}>
            If you encounter an accessibility barrier in PiDay or on this website, email{' '}
            <a href={`mailto:${SUPPORT_EMAIL}`} className={styles.contactEmail}>
              {SUPPORT_EMAIL}
            </a>
            {' '}with the device, platform, and feature you were using. We take that feedback
            seriously and use it to improve future releases.
          </p>
        </div>
      </main>
      <Footer />
    </>
  )
}
