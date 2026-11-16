# Cardiobug

A responsive cardiology learning website for GitHub Pages. Indigo/champagne branding, original pulse logo, SVG favicon and PNG app icons, original anatomical-inspired Three.js heart with pause/rotation, three clearly labeled sample reading courses, nine lessons, knowledge checks, account pages, and a student dashboard.

## Pages

- `index.html`: academy homepage, interactive 3D heart and ECG animation
- `courses.html`: search and topic filters
- `course.html?id=heart-foundations`: outcomes, curriculum and enrollment
- `lesson.html?course=heart-foundations&lesson=chambers`: lesson, quiz and saved completion
- `about.html`, `contact.html`, `resources.html`, `privacy.html`, `terms.html`
- `signin.html`, `signup.html`, `forgot-password.html`, `reset-password.html`, `dashboard.html`
- `404.html`; legacy clinic URLs link to academy equivalents

## Local development

No build or package installation is required. Serve the directory with `python3 -m http.server 8000`, then visit `http://localhost:8000`. ES modules require an HTTP server. `build_pages.py` regenerates the HTML shell; update its source before regenerating pages. JS and CSS are in `assets/`.

## Activate real student accounts (required)

GitHub Pages cannot run a private authentication/database server. This implementation uses Supabase Auth and a row-level-security database; it never creates fake local accounts or stores passwords itself.

1. Create a Supabase project. In Auth, enable email/password, require email confirmation, and set minimum password length to at least 12. Configure production SMTP and appropriate rate limits before opening registration.
2. Run `supabase/schema.sql` in the project's SQL editor. It creates the course catalog, enrollments and lesson progress, with RLS and minimal grants. Course/lesson IDs must match `assets/courses.js`.
3. Set Auth's Site URL to `https://kuniam68.github.io/Cardiology-/`. Add exact allowed redirect URLs for `signin.html`, `dashboard.html`, and `reset-password.html` under that path. Include local URLs only for development as needed.
   For password recovery that also works when the email opens a different browser tab/device, customize the Supabase Reset Password email link to `{{ .SiteURL }}/reset-password.html?token_hash={{ .TokenHash }}&type=recovery` (avoid a doubled slash if your Site URL already ends in `/`). The reset page exchanges the one-time token using `verifyOtp`, then removes it from the address bar. The standard PKCE recovery flow also works in the browser tab where it was requested.
4. Put the **public** project URL and publishable/anon key in `assets/config.js`. Never add the service-role key or provider secrets to GitHub. The public key is safe to expose only with correct database policies.
5. Optional Google sign-in: configure the Google OAuth provider and its callback URL in Supabase, then set `googleSignIn: true`. The button is hidden until enabled.
6. Test signup, email confirmation, sign-in/out, reset emails, a fresh browser session, and two separate accounts. One user must not be able to read/insert another user's enrollment or progress. Session state lives in tab-scoped sessionStorage, not a homemade password database.

Until settings are supplied, signup/signin are disabled with an accurate setup notice. Course reading and knowledge checks work without accounts. Enrollment/progress require activated accounts and a deployed schema. Existing progress is never represented as a professional credential.

## Contact and publication details

Set a real `contactEmail` in `assets/config.js`. Contact submissions open a draft in the visitor's email client; the visitor sends it there. There is no pretend “message sent” confirmation. Without an address the form is disabled. Add operator identity, contact details, retention policy and applicable legal disclosures to privacy/terms before opening accounts publicly.

Course content is sample editorial material, not reviewed/accredited medical training. No fabricated faculty profiles, testimonials, paid entitlements, videos, or certificates. Confirm editorial/medical review and provide your actual curriculum and operator identity before marketing as a professional training provider. The heart is an original procedural anatomical-inspired illustration, not a validated anatomical model.

## Deployment

GitHub Pages: deploy `main` / repository root. `.nojekyll` is retained. Links and redirects use the repository subpath. External dependencies: Google Fonts; pinned Three.js 0.174.0 and Supabase JS 2.49.8 from jsDelivr. The heart has a local SVG fallback if WebGL/CDN loading fails. Reduced motion is respected. Authentication additionally needs your configured Supabase project.

## Checks

Run `node --test tests/*.test.mjs` and `python3 scripts/check_site.py`. Browser QA and live provider tests are additional checks, not implied by these tests passing. The provider tests need configured project settings.

## Manage future courses

Visit `https://kuniam68.github.io/Cardiology-/admin.html` after account activation. Course administration is implemented in `assets/admin.js` and enforced by Supabase RPC functions and RLS in `supabase/schema.sql`.

1. Apply the **entire updated** schema, including the course-management and draft-privacy sections. It is designed to be rerunnable.
2. Create and verify your own user account. Find that user's UUID under Supabase Authentication → Users.
3. In the SQL editor, run `insert into public.academy_admins(user_id) values ('YOUR-AUTH-USER-UUID') on conflict do nothing;`. This is an owner-only administrative setup step. No frontend user can grant themselves this role; editable user metadata is never trusted for authorization.
4. Sign in and open **Course manager**. Choose **New course** or **Copy a sample to edit**.
5. Add a title, category, description, learning outcomes and lessons. Lessons support plain-text paragraphs, duration, and a three-option knowledge check. Add, remove, and reorder lessons. Keep existing IDs stable so saved progress remains associated with the correct lesson.
6. **Save draft** keeps content private to administrators. **Save & publish** makes it readable in the course catalog immediately, without another GitHub deployment. Save draft on a published course unpublishes it. **Archive** hides a course without deleting student records; **Restore** reverses that action. Publishing an archived course also restores it.
7. Leave the sample checkbox enabled until you replace the content with real material. It adds clear labels to cards, course pages, and lessons. Published course text is HTML-escaped. The manager does not accept executable HTML.

Without Supabase configuration, the bundled sample library is shown. With a working configured catalog, only published, unarchived courses are shown; an empty catalog shows an empty state. If the catalog cannot be reached, the clearly labeled bundled sample library is used with an explicit warning. Course management uses free readable content; paid entitlements, media uploads, and accreditation are not implemented.

## Cloudflare Turnstile (staged activation)

Set only the **public site key** in `assets/config.js` as `turnstileSiteKey`. Add `kuniam68.github.io` to its allowed hostnames. The code supports three modes:

- `off`: do not load a widget or send a token.
- `optional` (current default): render the widget when a site key exists; send fresh tokens to Supabase when available, but allow a request without a token while Supabase enforcement is disabled.
- `required`: require a successful widget result before submitting registration, password login, confirmation-email resend, or password-reset email requests. Expired or consumed tokens are reset. Authenticated password updates use the verified recovery session rather than an unsupported CAPTCHA argument.

The frontend mode is **not server enforcement**. When ready, put the Turnstile **secret** directly into Supabase Authentication's CAPTCHA configuration and enable Turnstile enforcement there; never put the secret into this repository or share it in frontend configuration. Then switch the frontend to `required` and test real signup, sign-in, resend and reset requests. Supabase must reject missing/invalid tokens server-side. Keep optional mode while enforcement is not activated, as requested.

For confirmation emails that work when opened in a different browser, set the Supabase Confirm Signup email template link to `{{ .SiteURL }}signin.html?token_hash={{ .TokenHash }}&type=email` when Site URL ends with `/`. The sign-in page verifies the one-time token and removes it from the URL. Existing PKCE confirmation links remain supported. Set the recovery template similarly to `{{ .SiteURL }}reset-password.html?token_hash={{ .TokenHash }}&type=recovery`.

Public project settings and the Turnstile site key are still blank. Contact delivery stays disabled until a real academy email is supplied. Live account, RLS and CAPTCHA enforcement tests require the actual project configuration.
