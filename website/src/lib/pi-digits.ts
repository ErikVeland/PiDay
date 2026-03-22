/**
 * Hero digit excerpt — a section of the real π digits arranged so that
 * "14031995" (14 March 1995 in DDMMYYYY) appears highlighted in the hero.
 *
 * The surrounding digits are real π digits; the embedded sequence makes
 * the target date appear at a predictable position for the demo.
 */
export const HERO_DIGITS =
  '31415926535897932384626433832795028841971693993751058209749' +
  '44592307816406286208998628034825342117067982148086513282306' +
  '64709384460955058223172535940812848111745028' +
  '14031995' + // 14 March 1995 in DDMMYYYY — the highlighted date
  '27101938521105559644622948954930381964428810975665933446128'

/** The illustrative position shown in the hero (not exact, chosen for plausibility). */
export const HERO_POSITION = '47,832,104'

/** The date parts highlighted in the hero. */
export const HERO_DATE = { day: '14', month: '03', year: '1995' } as const

export type DigitSpan =
  | { kind: 'plain'; text: string }
  | { kind: 'day';   text: string }
  | { kind: 'month'; text: string }
  | { kind: 'year';  text: string }

/**
 * Split a digit string into annotated spans for coloured rendering.
 *
 * Scans left-to-right. At each position, checks whether day, month, or year
 * starts here (in that priority order) and emits the corresponding span.
 * Remaining characters are collected into plain spans.
 */
export function buildDigitSpans(
  digits: string,
  day: string,
  month: string,
  year: string,
): DigitSpan[] {
  const spans: DigitSpan[] = []
  let i = 0
  let plainStart = 0

  const flush = (end: number) => {
    if (end > plainStart) {
      spans.push({ kind: 'plain', text: digits.slice(plainStart, end) })
    }
  }

  while (i < digits.length) {
    if (day && digits.startsWith(day, i)) {
      flush(i)
      spans.push({ kind: 'day', text: day })
      i += day.length
      plainStart = i
    } else if (month && digits.startsWith(month, i)) {
      flush(i)
      spans.push({ kind: 'month', text: month })
      i += month.length
      plainStart = i
    } else if (year && digits.startsWith(year, i)) {
      flush(i)
      spans.push({ kind: 'year', text: year })
      i += year.length
      plainStart = i
    } else {
      i++
    }
  }

  flush(digits.length)
  return spans
}
