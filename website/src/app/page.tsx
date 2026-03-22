import Nav from '@/components/Nav/Nav'
import Hero from '@/components/Hero/Hero'
import TodayWidget from '@/components/TodayWidget/TodayWidget'
import HowItWorks from '@/components/HowItWorks/HowItWorks'
import WhatIsPi from '@/components/WhatIsPi/WhatIsPi'
import Themes from '@/components/Themes/Themes'
import Footer from '@/components/Footer/Footer'

export default function Home() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <TodayWidget />
        <HowItWorks />
        <WhatIsPi />
        <Themes />
      </main>
      <Footer />
    </>
  )
}
