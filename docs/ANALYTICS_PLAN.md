# Analytics & crash reporting plan (Firebase / GA4)

## Principles
* One class: `AnalyticsService` (interface) → `FirebaseAnalyticsService`; `NoopAnalyticsService` for tests, debug builds and when the user has not consented. **No Firebase call anywhere else.**
* Use Firebase **recommended event names/parameters** when one exists; custom events only otherwise. Never log `first_open`/`session_start`/`screen_view`/`app_update` manually — GA4 collects them (`first_open`, DAU/MAU, retention, engagement time come for free).
* **No PII**: never e-mail, name, phone, tokens, payment details, free-text notes, book file names from the phone. Local imported books → hash of the local id or just `source: local`.
* Collection starts only after consent (see Consent). Debug builds: collection off unless Michael enables DebugView.
* Limits: event name ≤40 chars, ≤25 params, string value ≤100 chars. Register custom dimensions in GA4 for the params below (Michael, console).

## Event catalogue
| Brief name | Send as | Params | Where |
|---|---|---|---|
| first_open | *(automatic)* | — | — |
| onboarding_started / completed | `tutorial_begin` / `tutorial_complete` | — | onboarding screens |
| sign_up | `sign_up` | `method`=email | after successful register |
| login | `login` | `method`=email/biometric | after login (not for silent refresh) |
| logout | `logout` (custom) | — | sign-out |
| book_opened | `book_opened` | `book_id`(gutenberg id or `local`), `book_category`, `source`, `format` | opening reader/viewer |
| reading_started | `reading_started` | `book_id`, `source` | first page-turn/scroll of a session |
| reading_session_completed | `reading_session_completed` | `book_id`, `reading_duration_sec`, `progress_delta_pct` | session ends (reader closed/app backgrounded ≥30 s), only if duration ≥10 s |
| reading_completed | `reading_completed` | `book_id`, `book_category` | progress reaches ≥98 % (once per book per user) |
| bookmark_added / removed | `bookmark_added` / `bookmark_removed` | `book_id` | bookmarks provider |
| reading_goal_completed | `reading_goal_completed` | `goal_type` | challenge/goal completes |
| paywall_viewed | `paywall_viewed` | `placement` (profile/limit/habits) | upgrade screen / paywall opened |
| subscription_plan_selected | `select_item` + param `item_list_name=plans` | `item_id`=planId | plan tapped |
| subscription_started | `begin_checkout` | `value`, `currency`=NGN, `items[]` | checkout created (**not** a purchase) |
| subscription_success / purchase | **`purchase`** | `transaction_id`=Paystack reference, `value` (₦, decimal), `currency`=NGN, `items[{item_id,item_name,price,quantity}]`, `payment_method` | **only after** server `verify` says `success`; dedupe by persisting logged references |
| subscription_cancelled | `subscription_cancelled` | `subscription_plan` | refund/dispute/admin revoke seen on refresh |
| subscription_expired | `subscription_expired` | `subscription_plan` | `premiumUntil` passed (once per period) |
| subscription_renewed | `subscription_renewed` | `subscription_plan`, `subscription_duration` | second+ successful purchase while/after premium |
| search_performed | `search` | `search_term` (≤100 chars, Discover only), `source` | Discover search |
| book_downloaded | `book_downloaded` | `book_id`, `source`=gutenberg | download finished |
| notification_opened | `notification_opened` | `type`=habit_reminder | tap on reminder |
| feature_used | `feature_used` | `feature_name` ∈ read_aloud, ambient_sounds, habits, notes_export, import, scan_device, quick_settings, highlights, shelves | first use per session |
| app update prompt | `app_update_prompt` | `action`=shown/accepted/dismissed, `mandatory` | S2 |

Always attach `app_version` only if GA4's automatic dimension is insufficient. **User properties:** `plan` (free/premium), `distribution` (direct/play), `app_flavor`; `setUserId` = SHA-256 hash of the server user id (never e-mail), cleared on logout.
Revenue accuracy: value from the server's verified payment (kobo/100), never from the plan list on the phone. Refunds: server marks the payment refunded → app sends `subscription_cancelled`; reconcile revenue in GA4 vs admin *Payments* (admin is the financial truth). Optional S6.7: server-side Measurement Protocol `purchase` for webhook-only confirmations (needs `app_instance_id` from the app at checkout).

## Consent
First-launch card: “Help improve ReadIn — share anonymous usage data?” **Accept / No thanks**; stored in prefs; changeable in Profile → Privacy (two switches: *Usage statistics*, *Crash reports*). Until accepted: `setAnalyticsCollectionEnabled(false)` + manifest default off; also `setConsent(analyticsStorage: denied, adStorage: denied, adUserData: denied, adPersonalization: denied)`. We show **no ads** → remove the `AD_ID` permission (`<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>`), set `google_analytics_adid_collection_enabled=false`, `google_analytics_default_allow_ad_personalization_signals=false`. Disclose in the privacy policy + Play Data safety.

## Crashlytics
`FlutterError.onError = recordFlutterFatalError`; `PlatformDispatcher.instance.onError` → `recordError(fatal: true)`; isolate error listener; non-fatal `recordError` in key catch blocks via one helper `reportError(e, st, {context})` that strips tokens/URLs with query strings. Custom keys: `app_version`, `build`, `distribution`, `flavor`, `api_host`. Debug builds: collection disabled (or separate key `environment=dev`). Don't enable obfuscation initially (avoids symbol-upload complexity); if enabled later add `--split-debug-info` + symbol upload. A test-crash button exists only in the debug dev gallery.

## Reports (Michael builds in GA4 after data flows)
DAU/MAU & stickiness, new vs returning, engagement time, retention cohorts, acquisition (first user source — for APK downloads add UTM params to the landing-page download link is NOT possible after install; use a referrer-less approach: ask “How did you hear about us?” optionally on onboarding as a user property `acquisition_source`). Funnels: `paywall_viewed → select_item → begin_checkout → purchase`; `book_opened → reading_started → reading_completed`; onboarding funnel. Custom dimensions to register: `book_category`, `source`, `format`, `placement`, `feature_name`, `goal_type`, `payment_method`, `subscription_plan`.
