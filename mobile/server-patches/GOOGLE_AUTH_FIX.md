# SECURITY: `/auth/google` does not verify the Google sign-in (found during the Flutter audit)

`server/src/controllers/auth.controller.ts → googleOAuth` trusts `googleId` + `email` sent by the client.
Anyone who knows an account's email can `POST /auth/google {googleId:"x", email:"victim@…", displayName:"x"}`
and receive that account's access + refresh tokens (it even links the fake googleId to the account).

The Flutter app now also sends `idToken` (a JWT signed by Google). Verify it on the server:

```bash
npm i google-auth-library
```
```ts
import { OAuth2Client } from 'google-auth-library'
const googleClient = new OAuth2Client()

// schema: add  idToken: z.string().min(1)   (make it required once the RN app is retired)
const ticket = await googleClient.verifyIdToken({
  idToken,
  audience: process.env.GOOGLE_WEB_CLIENT_ID, // the WEB client id (same value as GOOGLE_SERVER_CLIENT_ID in the app)
})
const p = ticket.getPayload()
if (!p || !p.sub || p.email_verified !== true) {
  return res.status(401).json({ success: false, message: 'Invalid Google token.' })
}
// IGNORE the client's googleId/email – use the verified ones:
const googleId = p.sub
const email = p.email!.toLowerCase()
const displayName = p.name ?? email.split('@')[0]
const avatar = p.picture
```
Add `GOOGLE_WEB_CLIENT_ID` to Render env. The app only sends `idToken` when it runs with
`--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>`, so that define is now REQUIRED for Google sign-in.
