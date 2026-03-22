import { describe, it, expect } from 'vitest'
import { buildDigitSpans } from './pi-digits'

describe('buildDigitSpans', () => {
  it('returns a single plain span when no parts match', () => {
    const result = buildDigitSpans('12345', '9', '8', '7')
    expect(result).toEqual([{ kind: 'plain', text: '12345' }])
  })

  it('highlights day, month, year spans correctly', () => {
    const result = buildDigitSpans('00140319951', '14', '03', '1995')
    expect(result).toEqual([
      { kind: 'plain', text: '00' },
      { kind: 'day',   text: '14' },
      { kind: 'month', text: '03' },
      { kind: 'year',  text: '1995' },
      { kind: 'plain', text: '1' },
    ])
  })

  it('handles day at the very start', () => {
    const result = buildDigitSpans('14rest', '14', 'xx', 'xxxx')
    expect(result).toEqual([
      { kind: 'day',   text: '14' },
      { kind: 'plain', text: 'rest' },
    ])
  })

  it('handles year at the very end', () => {
    const result = buildDigitSpans('start1995', 'xx', 'xx', '1995')
    expect(result).toEqual([
      { kind: 'plain', text: 'start' },
      { kind: 'year',  text: '1995' },
    ])
  })

  it('returns empty array for empty input', () => {
    expect(buildDigitSpans('', '14', '03', '1995')).toEqual([])
  })

  it('plain span when digit string does not contain any part', () => {
    expect(buildDigitSpans('999999', '00', '00', '0000')).toEqual([
      { kind: 'plain', text: '999999' },
    ])
  })
})
