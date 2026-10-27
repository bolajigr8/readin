import { Callout } from '@/components/help'
import { PageHeader } from '@/components/page-header'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'

const TERMS: Array<[string, string]> = [
  ['Free plan', 'The normal account. Limited to the number of books you set on the Billing page (default 10). Can use features that are free, or that are in a free trial.'],
  ['Premium plan', 'A paid (or gifted) account: no book limit and every feature that is "Included in Premium". Paid Premium lasts the days of the plan and then returns to Free automatically.'],
  ['Free trial', 'A try-out of a feature for a number of days, starting the first time the user opens that feature. The clock runs on the server, so users cannot cheat it.'],
  ['Gift ("Grant access")', 'Full access to ONE feature for ONE user for a number of days, set by you. It does not change their plan.'],
  ['Block', 'Takes a feature away from ONE user, even if they are Premium. Reversible.'],
  ['Disabled account', 'The user cannot sign in at all and is signed out everywhere. Reversible. Their data is kept.'],
  ['Verified e-mail', 'The user confirmed their address by clicking the link in the welcome e-mail. Unverified users cannot sign in. You can verify someone by hand on their page.'],
  ['Administrator', 'An account with the Admin role. Created only with a script on your computer — never from this panel. Admins can always use every feature.'],
  ['Kobo', '₦1 = 100 kobo. Paystack works in kobo; this panel shows and accepts naira, so you never type kobo.'],
]

const TASKS: Array<[string, string]> = [
  ['Give someone Premium for free', 'Users → open the user → switch "Premium plan" on (no end date) — or use "Grant access" on a feature for a limited time.'],
  ['Change a price', 'Billing → Plans & prices → edit the ₦ amount → Save plans. Only new payments use the new price.'],
  ['Start accepting payments', 'Connect Paystack (Billing → Paystack: follow the steps), add at least one active plan, then switch "Show payments in the app" on. Try it in Paystack test mode first.'],
  ['Stop accepting payments', 'Billing → switch payments off. You will be asked whether to make the Habit Tracker free for everyone. The app hides every payment section.'],
  ['Make a feature free for everybody', 'Features → the feature → "Free for everyone" on → Save.'],
  ['Give everybody a longer trial', 'Features → the feature → "Free trial (days)" → Save. It also lengthens trials that are already running.'],
  ['A user says the e-mail never arrived', 'Users → open the user → "Verify e-mail now". (They can also ask for a new link on the confirmation page.)'],
  ['A user paid but is still Free', 'Billing → Recent payments. "Paid" = Premium was added (ask them to reopen the app). "Waiting" = Paystack has not confirmed yet; it activates by itself. If it stays like this, check the webhook URL in your Paystack dashboard.'],
  ['See who changed what', 'Audit log: every action made in this panel, with the time and address.'],
]

export default function GuidePage() {
  return (
    <>
      <PageHeader title="Guide" description="What everything in this panel means, in plain words." />
      <div className="grid gap-4">
        <Callout tone="tip" title="Nothing here is permanent">
          Every switch can be turned back. Deleting is rare: users, books and notes are never deleted from this panel. When in doubt, look at the Audit log.
        </Callout>

        <Card>
          <CardHeader>
            <CardTitle>The menu</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-3 text-sm leading-relaxed text-muted-foreground">
            <p><strong className="text-foreground">Dashboard</strong> &mdash; numbers at a glance: users, Premium users, revenue, trials.</p>
            <p><strong className="text-foreground">Users</strong> &mdash; search every account. Open one to change its plan, disable it, verify its e-mail, or give / block / reset access to a feature.</p>
            <p><strong className="text-foreground">Features</strong> &mdash; the rules for each feature: on/off, free for everyone, trial length, and whether Premium includes it.</p>
            <p><strong className="text-foreground">Billing</strong> &mdash; Paystack connection, plans and prices in naira, the payments switch, the free book limit and the list of payments.</p>
            <p><strong className="text-foreground">Audit log</strong> &mdash; a record of everything done here.</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Words used in this panel</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-3 text-sm leading-relaxed">
            {TERMS.map(([t, d]) => (
              <div key={t}>
                <div className="font-medium">{t}</div>
                <div className="text-muted-foreground">{d}</div>
              </div>
            ))}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Common jobs</CardTitle>
            <CardDescription>Step by step.</CardDescription>
          </CardHeader>
          <CardContent className="grid gap-3 text-sm leading-relaxed">
            {TASKS.map(([t, d]) => (
              <div key={t}>
                <div className="font-medium">{t}</div>
                <div className="text-muted-foreground">{d}</div>
              </div>
            ))}
          </CardContent>
        </Card>

        <Callout tone="info" title="How fast do changes reach the app?">
          Within about 30 seconds. The app asks the server for the latest rules when it opens and every few minutes while it is in use.
        </Callout>
      </div>
    </>
  )
}
