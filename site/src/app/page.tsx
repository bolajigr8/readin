import { Features, FormatMarquee } from '@/components/features'
import { Hero } from '@/components/hero'
import { Faq, FinalCta, HowItWorks, Privacy } from '@/components/sections'
import { SiteFooter } from '@/components/site-footer'
import { SiteHeader } from '@/components/site-header'

export default function Home() {
  return (
    <>
      <SiteHeader />
      <main>
        <Hero />
        <FormatMarquee />
        <Features />
        <HowItWorks />
        <Privacy />
        <Faq />
        <FinalCta />
      </main>
      <SiteFooter />
    </>
  )
}
