# PULSE Academy

A responsive cardiology learning website for GitHub Pages. Indigo/champagne branding, original pulse logo, SVG favicon and PNG app icons, original anatomical-inspired Three.js heart with pause/rotation, three introductory reading courses, nine lessons, knowledge checks, account pages, and a student dashboard.

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
4. Put the **public** project URL and publishable/anon key in `assets/config.js`. Never add the service-role key or provider secrets to GitHub. The public key is safe to expose only with correct database policies.
5. Optional Google sign-in: configure the Google OAuth provider and its callback URL in Supabase, then set `googleSignIn: true`. The button is hidden until enabled.
6. Test signup, email confirmation, sign-in/out, reset emails, a fresh browser session, and two separate accounts. One user must not be able to read/insert another user's enrollment or progress. Session state lives in tab-scoped sessionStorage, not a homemade password database.

Until settings are supplied, signup/signin are disabled with an accurate setup notice. Course reading and knowledge checks work without accounts. Enrollment/progress require activated accounts and a deployed schema. Existing progress is never represented as a professional credential.

## Contact and publication details

Set a real `contactEmail` in `assets/config.js`. Contact submissions open a draft in the visitor's email client; the visitor sends it there. There is no pretend “message sent” confirmation. Without an address the form is disabled. Add operator identity, contact details, retention policy and applicable legal disclosures to privacy/terms before opening accounts publicly.

Course content is introductory editorial material, not reviewed/accredited medical training. No fabricated faculty profiles, testimonials, paid entitlements, videos, or certificates. Confirm editorial/medical review and provide your actual curriculum and operator identity before marketing as a professional training provider. The heart is an original procedural anatomical-inspired illustration, not a validated anatomical model.

## Deployment

GitHub Pages: deploy `main` / repository root. `.nojekyll` is retained. Links and redirects use the repository subpath. External dependencies: Google Fonts; pinned Three.js 0.174.0 and Supabase JS 2.49.8 from jsDelivr. The heart has a local SVG fallback if WebGL/CDN loading fails. Reduced motion is respected. Authentication additionally needs your configured Supabase project.

## Checks

Run `node --test tests/*.test.mjs` and `python3 scripts/check_site.py`. Browser QA and live provider tests are additional checks, not implied by these tests passing. The provider tests need configured project settings.
