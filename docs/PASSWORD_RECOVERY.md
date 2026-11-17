# Password recovery fix — 17 November 2026

## Cause

The normal client uses PKCE with tab-scoped `sessionStorage`. The verifier created when requesting a reset is unavailable in a different browser or email application's embedded browser. The old reset page also let the password form submit before asynchronous recovery initialization finished, checked for a generic stored session instead of a validated recovery session, and did not explicitly handle each supported callback format.

Normal account sign-in remains on PKCE and tab-scoped storage. Moving credentials into localStorage would not solve cross-browser recovery and was not used as a workaround.

## Required Supabase email template

In **Supabase → Authentication → Email Templates → Reset Password**, replace the reset action link with this HTML:

```html
<a href="https://kuniam68.github.io/Cardiology-/reset-password.html?token_hash={{ .TokenHash }}&amp;type=recovery">Reset your password</a>
```

Keep all other email branding and Brevo SMTP settings. This is a Supabase Auth template change, not a Brevo SMTP change. The token placeholder must remain a template variable; do not substitute a real token into source code or documentation.

In **Authentication → URL Configuration**, ensure the Site URL is `https://kuniam68.github.io/Cardiology-/` and this exact redirect is allowed:

```text
https://kuniam68.github.io/Cardiology-/reset-password.html
```

The template deliberately goes directly to the website with a one-time recovery token hash. The browser exchanges it with `verifyOtp({ token_hash, type: 'recovery' })`, which establishes a server-validated recovery session without needing the original browser's PKCE verifier. Do not replace this link with `{{ .ConfirmationURL }}` for this cross-browser flow; the standard PKCE callback still needs its original verifier.

There is no authorized Supabase management connection in the current session, so the template/redirect settings were not changed by the repository deployment. Use a **new** reset email after saving the template. Existing expired/used links cannot be revived, and old PKCE links opened in another browser cannot be safely exchanged without their original verifier.

## Page behavior

- The callback is captured in memory and immediately removed from the address bar. The page uses `no-referrer` and `noindex, nofollow` metadata.
- Password fields and submission are disabled in the HTML until recovery validation succeeds.
- The user clicks **Validate reset link** before the one-time token is consumed. Merely loading the page does not consume it, reducing problems with email link scanners.
- Recovery uses a separate in-memory Supabase session and a separate storage/broadcast key, not the student's or administrator's ordinary login session.
- A successful `getUser(access_token)` response must match the recovery session's user. This is checked before enabling the form and again before `updateUser`.
- Same-tab PKCE callbacks are explicitly exchanged only when the original password-recovery verifier is available. Old recovery-token fragment callbacks are explicitly established and validated with Supabase.
- Missing, malformed, expired, and already-used OTP links fail closed. A normal signed-in session is not accepted as evidence of recovery.
- New passwords must match confirmation and meet the existing 12-character minimum. Supabase password policies remain authoritative.
- Recovery is single-use in the page, expires locally after 15 minutes, and signs out only its isolated recovery session after a successful update. Existing account records, progress, admin roles, and other sessions are not modified by the frontend setup.
- After a successful update, sign in normally with the new password. Do not reload the reset page mid-flow: credentials are intentionally not persisted.

The public-key configuration, database schema/RLS, Turnstile settings and token forwarding on reset-email requests, and Brevo SMTP credentials were not changed.

## Tests and real-device validation

Automated recovery tests cover portable OTP links in an empty browser session, same-tab PKCE exchange, missing PKCE verifiers, legacy fragment callbacks, early submission, expired/used links, user mismatch, temporary network failure, duplicate password updates, session isolation, weak-password retry, and local expiration. The complete existing test suite and local-link checks also pass.

No real student's password was changed during tests. Without an email inbox/test account and mobile browser access, a live Brevo-to-Android/iOS recovery round trip cannot be claimed as verified. After updating the template:

1. Use your own disposable test account to request a reset from the forgot-password page.
2. Open the new email link in a different tab/browser on Android and iOS. Validate the link, confirm a new password, and sign in with it.
3. Confirm the old password fails and existing course progress remains available.
4. Reopen the same one-time-token link and confirm it is rejected. Test an expired link and a missing-link visit too.
5. Verify CAPTCHA remains in its existing mode on reset-email requests. No CAPTCHA enforcement or SMTP setting needs to change for this fix.

Never paste a real recovery URL, access token, refresh token, password, or secret key into an issue, chat, or browser log.
