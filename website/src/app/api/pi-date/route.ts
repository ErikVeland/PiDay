import { NextRequest, NextResponse } from 'next/server'
import { lookupDateInPi, normalizeIsoDate } from '@/lib/pi-lookup'

export async function GET(request: NextRequest) {
  const isoDateParam = request.nextUrl.searchParams.get('date')

  if (!isoDateParam) {
    return NextResponse.json({ error: 'Missing date query parameter.' }, { status: 400 })
  }

  try {
    const isoDate = normalizeIsoDate(isoDateParam)
    const result = await lookupDateInPi(isoDate)

    if (!result) {
      return NextResponse.json({ error: 'Date not found in the first five billion digits.' }, { status: 404 })
    }

    return NextResponse.json(result, {
      headers: {
        'Cache-Control': 's-maxage=3600, stale-while-revalidate=86400',
      },
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Pi lookup failed.'
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
