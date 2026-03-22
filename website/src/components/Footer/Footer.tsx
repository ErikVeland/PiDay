import styles from './Footer.module.scss'

export default function Footer() {
  return (
    <footer className={styles.footer}>
      <span className={styles.wordmark}>π PiDay</span>
      <span className={styles.copy}>© 2026 glasscode.academy · Made with curiosity</span>
    </footer>
  )
}
