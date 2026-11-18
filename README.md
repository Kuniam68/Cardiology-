# Cardiobug Academy

Production: https://kuniam68.github.io/Cardiology-/

Cardiology learning with verified email accounts, free enrollment, protected paid-course support, quizzes, saved progress and an administrator course/enrollment manager.

**Live checkout is unavailable.** Production contains no dummy-payment completion action and no test-account enrollment bypass. The separate `cardiobug-sandbox` website remains the place for dummy purchases.

Payment infrastructure uses SSLCOMMERZ hosted checkout for verified BDT collection. USD course prices are independent but USD collection is deliberately unavailable because the provider documentation describes conversion to BDT. No merchant credentials are included.

- `admin.html`: courses, drafts, protected editing, publication and enrollment/progress visibility.
- `pricing.html`: independent BDT/USD prices and atomic paid-content protection.
- `payments-admin.html`: readiness, orders, reconciliation, audit and guarded full-refund requests.
- `checkout.html?course=COURSE_ID`: course summary, exact prices, billing/hosted checkout and verified status; payment submission remains disabled.
- `dashboard.html`: enrollments, completion, scores and private payment history.

Read [payment operations](docs/PAYMENT_OPERATIONS.md) for exact server secret names, callback endpoints, merchant/provider acceptance and the separate activation gates. Read [backup and recovery](docs/RECOVERY.md) before any database operation. Existing SMTP, Auth redirects, accounts, course content and student records are preserved.

Development: `npm ci`, `npm test`, `npm run check`. The test suite uses synthetic local PostgreSQL fixtures and mocked provider APIs. `CARDIOBUG_LOCAL=1 node scripts/browser-acceptance.mjs` runs isolated desktop/mobile/iPad browser acceptance using Playwright and Chromium; all Auth/Data/Function/provider requests are intercepted. Without that variable the static frontend loads from deployment, but Auth/Data/provider requests still use isolated fixtures. These tests do not claim actual merchant acceptance or an authenticated real-customer payment.

`supabase/schema.sql` is a legacy bootstrap for a new empty isolated test database. Never rerun it over this migrated production database. The versioned migration plan and hosted history are authoritative for upgrades.
