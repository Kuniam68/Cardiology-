# Cardiobug Turnstile frontend testing

The public site key is configured in `assets/config.js`. Mode remains `optional` and no Supabase CAPTCHA enforcement setting was changed. The site stays compatible with GitHub Pages: the browser obtains a widget token and passes it to Supabase Auth; no Turnstile secret or private verification endpoint is deployed in GitHub.

## Check in Safari

1. Ensure `kuniam68.github.io` is an allowed hostname for this widget in Cloudflare.
2. Open the deployed signup, signin and forgot-password pages. The Turnstile widget should appear inside each form.
3. Complete verification, then submit a request using your own test account. Available tokens are supplied to Supabase as `captchaToken`. Confirmation email resend uses a fresh token, too.
4. Confirm that a submitted token is reset, and that an expired or errored widget clears its previous token.
5. While Supabase enforcement remains disabled, a request without a token is allowed by optional mode. This is staged compatibility, not proof of CAPTCHA protection.

Authenticated password changes use the recovery session from the reset email. Supabase's password-update endpoint does not accept a CAPTCHA argument; the password-reset email request is the CAPTCHA-integrated step.

## Later server activation

After frontend testing succeeds, configure the Turnstile secret directly in Supabase Authentication's CAPTCHA settings and enable enforcement there. Then change the website mode to `required`. Supabase must reject missing/invalid tokens server-side. Never place the secret in GitHub or frontend configuration.

Local automated checks cover token forwarding, expiry/error cleanup, reset, and optional/required behavior. A real Cloudflare challenge and successful email/password flows require live browser testing with a test account; they were not simulated as verified production requests.
