import Link from 'next/link'
import styles from './Footer.module.scss'

export default function Footer() {
  return (
    <footer className={styles.footer}>
      <span className={styles.wordmark}>π PiDay</span>
      <nav className={styles.links} aria-label="Footer navigation">
        <Link href="/privacy" className={styles.link}>Privacy</Link>
        <Link href="/support" className={styles.link}>Support</Link>
        <span className={styles.copy}>© 2026 glasscode.academy</span>
      </nav>
    </footer>
  )
}
