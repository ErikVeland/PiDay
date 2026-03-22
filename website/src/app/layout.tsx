import type { Metadata } from 'next'
import './globals.scss'

export const metadata: Metadata = {
  title: 'PiDay — Find your birthday in π',
  description: 'Your birthday is hiding somewhere in the infinite digits of pi. PiDay finds it.',
  openGraph: {
    title: 'PiDay — Find your birthday in π',
    description: 'Your birthday is hiding somewhere in the infinite digits of pi. PiDay finds it.',
    images: [{ url: '/og.png', width: 1200, height: 630 }],
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
