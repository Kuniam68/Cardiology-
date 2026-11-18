# Cardiobug Supabase setup

Production is installed and migrated at `zeneffylfgiyezpegqto`. Do not rerun the legacy `schema.sql` bootstrap over this project. The current migration plan/history, payment operations guide and recovery procedure are authoritative. Account credentials, SMTP and existing email redirects were preserved during the commerce upgrade.

Client code uses only the public publishable key. Privileged keys and merchant credentials belong only in server secrets. Students read their own learning records, and all new lesson completion writes use the server-verified quiz RPC. Administrative authorization comes from `academy_admins`, never editable user metadata.

## Configure email redirects AFTER publication

Published website: **https://kuniam68.github.io/Cardiology-/**

In Supabase **Authentication → URL Configuration**:

- Site URL: `https://kuniam68.github.io/Cardiology-/`
- Add these exact redirect URLs:
  - `https://kuniam68.github.io/Cardiology-/signin.html`
  - `https://kuniam68.github.io/Cardiology-/dashboard.html`
  - `https://kuniam68.github.io/Cardiology-/reset-password.html`

Keep email confirmation enabled. Configure a production SMTP sender and its delivery/rate limits before accepting a large number of registrations.

The frontend explicitly supplies the matching confirmation and password recovery redirect URLs. They must be allowed in the project; supplying them in frontend code does not configure Supabase automatically.

For email links that can open in a new browser/tab, use the following destinations in Supabase email templates (Site URL above includes its trailing slash):

- Confirm signup: `{{ .SiteURL }}signin.html?token_hash={{ .TokenHash }}&type=email`
- Reset password: `{{ .SiteURL }}reset-password.html?token_hash={{ .TokenHash }}&type=recovery`

The pages exchange these one-time tokens with Supabase and remove them from the address bar. Existing standard PKCE links also work in their originating browser tab. No email links or real accounts were created during the initial read-only connection check.

## Turnstile

The public Turnstile site key is configured in `assets/config.js` as `turnstileSiteKey`. Allow `kuniam68.github.io` in Cloudflare's site settings. Keep `turnstileMode: 'optional'` while testing, and keep CAPTCHA enforcement **disabled in Supabase** as requested. No server-side authentication/CAPTCHA setting was changed by publishing the frontend.

Relevant forms send available tokens for registration, password login, confirmation resend and password-reset email requests. Expired/consumed tokens are cleared. Updating the password uses the authenticated recovery session.

Later, after frontend tests pass, set the Turnstile secret directly in Supabase's CAPTCHA settings, enable enforcement there, and switch the frontend to `required`. A frontend flag alone does not enforce CAPTCHA server-side. Never commit the Turnstile secret.

## Test before opening registration widely

1. Register an email address you control. Confirm the account through its email link, then sign in and sign out.
2. Request a password reset, follow the email link, set a new password, and verify the old password fails.
3. Enroll in a sample course, complete a knowledge check, and confirm the dashboard preserves progress after signing in again.
4. Use two separate test accounts. Verify each can access its own records, and direct API attempts to select or insert the other user's private records are rejected or return no rows. Never disable RLS for testing.
5. Test Turnstile completion, expiry, loading failure and token reset in optional mode before enabling server enforcement.
6. For the course manager, grant your verified user admin from the SQL editor as documented in the main README. A student account must be denied course-management operations.

Live email delivery, recovery, account isolation and student progress cannot be declared verified until redirects, schema and test accounts are set up.
