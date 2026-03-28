import Nav from '@/components/Nav/Nav'
import Hero from '@/components/Hero/Hero'
import HowItWorks from '@/components/HowItWorks/HowItWorks'
import WhatIsPi from '@/components/WhatIsPi/WhatIsPi'
import Themes from '@/components/Themes/Themes'
import WhatsNew from '@/components/WhatsNew/WhatsNew'
import Footer from '@/components/Footer/Footer'
import { APP_STORE_URL, IOS_REQUIREMENT, SITE_DESCRIPTION, SITE_NAME, SITE_URL } from '@/lib/site'

export default function Home() {
  const structuredData = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'WebSite',
        name: SITE_NAME,
        url: SITE_URL,
        description: SITE_DESCRIPTION,
      },
      {
        '@type': 'SoftwareApplication',
        name: SITE_NAME,
        applicationCategory: 'UtilitiesApplication',
        operatingSystem: 'iOS, iPadOS, macOS',
        description: SITE_DESCRIPTION,
        url: SITE_URL,
        downloadUrl: APP_STORE_URL,
        image: `${SITE_URL}/og.png`,
        offers: {
          '@type': 'Offer',
          price: '0',
          priceCurrency: 'USD',
        },
        author: {
          '@type': 'Organization',
          name: 'glasscode.academy',
          url: SITE_URL,
        },
        featureList: [
          'Find today in five billion digits of pi',
          'Search birthdays and anniversaries across five date formats',
          'See earlier and later matches in a calendar heat map',
          'Compare two dates head-to-head with Date Battles',
          'Explore richer nerdy stats and share themed result cards',
          `Available on iPhone, iPad, and Mac with ${IOS_REQUIREMENT}`,
        ],
      },
    ],
  }

  return (
    <>
      <Nav />
      <main id="main-content" tabIndex={-1}>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
        />
        <Hero />
        <HowItWorks />
        <WhatsNew />
        <WhatIsPi />
        <Themes />
      </main>
      <Footer />
    </>
  )
}
