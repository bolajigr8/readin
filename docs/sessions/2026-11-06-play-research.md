# 2026-11-06 — Google Play requirements research
Stage: between S1 (code done) and the next stage        Started from: NEXT.md (S1 waiting for Michael's key)

## Asked
Michael: he can now publish on Google Play Console; everything must follow Play rules (APK continues too). Research all
requirements (landing page / privacy policy etc.), check, give next steps. Question: Google Tag Manager or does Play monitor users?
He has not done the S1 tasks yet.

## Found (details + sources: PLAY_AND_DISTRIBUTION.md §7b)
- Closed test 12 testers × 14 days (personal accounts after 13 Nov 2023). Target API 36 since 31 Aug 2026 → ReadIn ✅ 36.
- 16 KB pages → ✅ all arm64 .so aligned (zipalign -P 16 + ELF LOAD align check on the S1 test APK).
- Play Billing available in Nigeria → Play build cannot sell Premium via Paystack; alt-billing programmes don't cover Nigeria.
- MANAGE_EXTERNAL_STORAGE → remove from Play build. FGS mediaPlayback → declaration + video. Account deletion in-app + web.
  Privacy policy page. Data safety. Reviewer login. Developer verification: Play apps auto-registered; global enforcement 2027.
- GTM not needed; Play Console vitals/statistics for free; Firebase (S6) for in-app behaviour.

## Changed
- PLAY_AND_DISTRIBUTION.md §7b (new), NEXT.md (proposed new order + questions). No code.

## Next step
Michael answers the 3 questions in NEXT.md; does S1.1 (key).
