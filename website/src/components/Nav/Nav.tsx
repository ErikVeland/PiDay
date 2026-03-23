import Link from 'next/link'
import { APP_STORE_URL } from '@/lib/site'
import styles from './Nav.module.scss'

export default function Nav() {
  return (
    <nav className={styles.nav} aria-label="Primary">
      <Link href="/" className={styles.wordmark} aria-label="PiDay home">
        <span className={styles.pi} aria-hidden="true">π</span>
        PiDay
      </Link>
      <a
        href={APP_STORE_URL}
        className={styles.cta}
        aria-label="Download PiDay on the App Store"
        rel="noopener noreferrer"
      >
        App Store →
      </a>
    </nav>
  )
}
