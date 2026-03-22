import type { MetadataRoute } from 'next'
import { APPLE_TOUCH_ICON, SITE_DESCRIPTION, SITE_NAME } from '@/lib/site'

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: SITE_NAME,
    short_name: SITE_NAME,
    description: SITE_DESCRIPTION,
    start_url: '/',
    display: 'standalone',
    background_color: '#f9f8f5',
    theme_color: '#f9f8f5',
    icons: [
      {
        src: APPLE_TOUCH_ICON,
        sizes: '512x512',
        type: 'image/png',
      },
    ],
  }
}
