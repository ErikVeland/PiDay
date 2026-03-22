import indexData from '@/data/pi_2026_2035_index.json'

export type DateFormatOption =
  | 'yyyymmdd'
  | 'ddmmyyyy'
  | 'mmddyyyy'
  | 'yymmdd'
  | 'dmyNoLeadingZeros'

interface PiFormatMatch {
  query: string
  position: number
  excerpt: string
}

interface PiDateRecord {
  date: string
  formats: Partial<Record<DateFormatOption, PiFormatMatch>>
}

interface PiIndexPayload {
  metadata: {
    startYear: number
    endYear: number
    excerptRadius: number
  }
  dates: Record<string, PiDateRecord>
}

interface PiSearchLookupResponse {
  resultStringIdx: number
  surroundingDigits: {
    before: string
    after: string
  }
  numResults: number
}

export interface HeroLookupResult {
  isoDate: string
  dateLabel: string
  query: string
  format: DateFormatOption
  formatLabel: string
  source: 'bundled' | 'live'
  position: number
  before: string
  after: string
  dayStr: string
  monthStr: string
  yearStr: string
}

type QueryPair = readonly [DateFormatOption, string]

const PI_INDEX = indexData as PiIndexPayload
const ALL_FORMATS: DateFormatOption[] = [
  'ddmmyyyy',
  'mmddyyyy',
  'yyyymmdd',
  'yymmdd',
  'dmyNoLeadingZeros',
]
const LIVE_LOOKUP_URL = 'https://v2.api.pisearch.joshkeegan.co.uk/api/v1/Lookup'
const DEFAULT_EXCERPT_RADIUS = 20

export function normalizeIsoDate(input: string): string {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(input)) {
    throw new Error('Invalid date. Expected YYYY-MM-DD.')
  }

  const [year, month, day] = input.split('-').map(Number)
  const utc = new Date(Date.UTC(year, month - 1, day))
  if (
    utc.getUTCFullYear() !== year ||
    utc.getUTCMonth() !== month - 1 ||
    utc.getUTCDate() !== day
  ) {
    throw new Error('Invalid calendar date.')
  }

  return input
}

export async function lookupDateInPi(isoDate: string): Promise<HeroLookupResult | null> {
  const normalizedDate = normalizeIsoDate(isoDate)
  const date = parseIsoDate(normalizedDate)
  const queries = stringsForDate(date, ALL_FORMATS)
  const bundled = bundledLookup(normalizedDate, date, queries)

  if (bundled) {
    return bundled
  }

  return liveLookup(normalizedDate, date, queries)
}

function bundledLookup(
  isoDate: string,
  date: Date,
  queries: QueryPair[],
): HeroLookupResult | null {
  const year = Number(isoDate.slice(0, 4))
  if (year < PI_INDEX.metadata.startYear || year > PI_INDEX.metadata.endYear) {
    return null
  }

  const record = PI_INDEX.dates[isoDate]
  if (!record) {
    return null
  }

  const matches = queries
    .map(([format, query]) => {
      const match = record.formats[format]
      if (!match || match.query !== query) {
        return null
      }

      return {
        format,
        query,
        position: match.position,
        excerpt: match.excerpt,
      }
    })
    .filter((value): value is NonNullable<typeof value> => value !== null)

  const best = pickBestMatch(matches)
  if (!best) {
    return null
  }

  const excerptParts = sliceExcerpt(best.excerpt, best.query)
  const { day, month, year: yearPart } = queryParts(best.format, best.query, date)

  return {
    isoDate,
    dateLabel: formatDateLabel(date),
    query: best.query,
    format: best.format,
    formatLabel: formatLabel(best.format),
    source: 'bundled',
    position: best.position,
    before: excerptParts.before,
    after: excerptParts.after,
    dayStr: day,
    monthStr: month,
    yearStr: yearPart,
  }
}

async function liveLookup(
  isoDate: string,
  date: Date,
  queries: QueryPair[],
): Promise<HeroLookupResult | null> {
  const matches = await Promise.all(
    queries.map(async ([format, query]) => {
      const url = new URL(LIVE_LOOKUP_URL)
      url.searchParams.set('namedDigits', 'pi')
      url.searchParams.set('find', query)
      url.searchParams.set('resultId', '0')

      const response = await fetch(url, {
        headers: { Accept: 'application/json' },
        next: { revalidate: 3600 },
      })

      if (!response.ok) {
        throw new Error(`Pi search failed with ${response.status}`)
      }

      const data = (await response.json()) as PiSearchLookupResponse
      if (!data.numResults) {
        return null
      }

      return {
        format,
        query,
        position: data.resultStringIdx + 1,
        before: data.surroundingDigits.before,
        after: data.surroundingDigits.after,
      }
    }),
  )

  const best = pickBestMatch(matches.filter((value): value is NonNullable<typeof value> => value !== null))
  if (!best) {
    return null
  }

  const { day, month, year: yearPart } = queryParts(best.format, best.query, date)
  return {
    isoDate,
    dateLabel: formatDateLabel(date),
    query: best.query,
    format: best.format,
    formatLabel: formatLabel(best.format),
    source: 'live',
    position: best.position,
    before: best.before.slice(-DEFAULT_EXCERPT_RADIUS),
    after: best.after.slice(0, DEFAULT_EXCERPT_RADIUS),
    dayStr: day,
    monthStr: month,
    yearStr: yearPart,
  }
}

function pickBestMatch<T extends { format: DateFormatOption; position: number }>(matches: T[]): T | null {
  if (matches.length === 0) {
    return null
  }

  return matches.reduce((best, current) => {
    const bestPadded = best.format !== 'dmyNoLeadingZeros'
    const currentPadded = current.format !== 'dmyNoLeadingZeros'

    if (bestPadded !== currentPadded) {
      return currentPadded ? current : best
    }

    return current.position < best.position ? current : best
  })
}

function sliceExcerpt(excerpt: string, query: string) {
  const index = excerpt.indexOf(query)
  if (index === -1) {
    return {
      before: excerpt.slice(0, DEFAULT_EXCERPT_RADIUS),
      after: excerpt.slice(DEFAULT_EXCERPT_RADIUS, DEFAULT_EXCERPT_RADIUS * 2),
    }
  }

  return {
    before: excerpt.slice(Math.max(0, index - DEFAULT_EXCERPT_RADIUS), index),
    after: excerpt.slice(index + query.length, index + query.length + DEFAULT_EXCERPT_RADIUS),
  }
}

function parseIsoDate(isoDate: string): Date {
  const [year, month, day] = isoDate.split('-').map(Number)
  return new Date(year, month - 1, day)
}

function stringsForDate(date: Date, formats: DateFormatOption[]): QueryPair[] {
  const year = date.getFullYear()
  const month = date.getMonth() + 1
  const day = date.getDate()
  const yyyy = String(year).padStart(4, '0')
  const yy = String(year % 100).padStart(2, '0')
  const mm = String(month).padStart(2, '0')
  const dd = String(day).padStart(2, '0')

  return formats.map((format) => {
    switch (format) {
      case 'yyyymmdd':
        return [format, `${yyyy}${mm}${dd}`] as const
      case 'ddmmyyyy':
        return [format, `${dd}${mm}${yyyy}`] as const
      case 'mmddyyyy':
        return [format, `${mm}${dd}${yyyy}`] as const
      case 'yymmdd':
        return [format, `${yy}${mm}${dd}`] as const
      case 'dmyNoLeadingZeros':
        return [format, `${day}${month}${year}`] as const
    }
  })
}

function queryParts(format: DateFormatOption, query: string, date: Date) {
  switch (format) {
    case 'yyyymmdd':
      return { day: query.slice(6, 8), month: query.slice(4, 6), year: query.slice(0, 4) }
    case 'mmddyyyy':
      return { day: query.slice(2, 4), month: query.slice(0, 2), year: query.slice(4, 8) }
    case 'ddmmyyyy':
      return { day: query.slice(0, 2), month: query.slice(2, 4), year: query.slice(4, 8) }
    case 'yymmdd':
      return { day: query.slice(4, 6), month: query.slice(2, 4), year: query.slice(0, 2) }
    case 'dmyNoLeadingZeros': {
      const year = query.slice(-4)
      const dayMonth = query.slice(0, -4)
      const dayLength = date.getDate() < 10 ? 1 : 2
      return {
        day: dayMonth.slice(0, dayLength),
        month: dayMonth.slice(dayLength),
        year,
      }
    }
  }
}

function formatLabel(format: DateFormatOption) {
  switch (format) {
    case 'yyyymmdd':
      return 'YYYYMMDD'
    case 'ddmmyyyy':
      return 'DDMMYYYY'
    case 'mmddyyyy':
      return 'MMDDYYYY'
    case 'yymmdd':
      return 'YYMMDD'
    case 'dmyNoLeadingZeros':
      return 'D/M/YYYY'
  }
}

function formatDateLabel(date: Date) {
  return date.toLocaleDateString('en-GB', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  })
}
