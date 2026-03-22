import Nav from '@/components/Nav/Nav'
import Hero from '@/components/Hero/Hero'
import HowItWorks from '@/components/HowItWorks/HowItWorks'
import Themes from '@/components/Themes/Themes'
import Footer from '@/components/Footer/Footer'

export default function Home() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <HowItWorks />
        <Themes />
      </main>
      <Footer />
    </>
  )
}
