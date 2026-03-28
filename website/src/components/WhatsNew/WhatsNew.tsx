import styles from './WhatsNew.module.scss'

const FEATURES = [
  {
    title: 'Nerdy Stats 2.0',
    body: 'A deeper stats page with hall-of-fame dates, luckiest months, format upsets, repeat-run oddities, and Pi Day-specific trivia.',
    kicker: 'Deeper stats',
  },
  {
    title: 'Date Battles',
    body: 'Pick any two dates and let pi decide the winner. Compare positions, winning margins, and rarity in a single polished matchup card.',
    kicker: 'Friendly rivalry',
  },
  {
    title: 'Shareable Weirdness',
    body: 'Classic and nerd share cards, saved-date leaderboards, and a few hidden reactions for famous numbers that deserved a little love.',
    kicker: 'Delightful details',
  },
]

export default function WhatsNew() {
  return (
    <section className={styles.section}>
      <div className={styles.inner}>
        <div className={styles.sectionLabel}>Version 1.1</div>
        <div className={styles.header}>
          <h2 className={styles.headline}>A fuller, stranger, more lovable PiDay.</h2>
          <p className={styles.body}>
            Version 1.1 turns PiDay into more than a lookup tool. It now has richer stats, playful date
            matchups, better sharing, and just enough hidden nonsense to reward curious people.
          </p>
        </div>

        <div className={styles.grid}>
          {FEATURES.map((feature) => (
            <article key={feature.title} className={styles.card}>
              <div className={styles.kicker}>{feature.kicker}</div>
              <h3 className={styles.title}>{feature.title}</h3>
              <p className={styles.copy}>{feature.body}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}
