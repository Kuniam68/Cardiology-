# Production commerce validation — 18 November 2026

Production website: https://kuniam68.github.io/Cardiology-/
Official provider acceptance: https://kuniam68.github.io/cardiobug-sandbox/gateway-acceptance/
Existing dummy website: https://kuniam68.github.io/cardiobug-sandbox/

## Installed scope

Production uses four versioned commerce migrations and `academy-payments`, with live checkout/refunds disabled. The isolated sandbox has one additional guarded compatibility migration and its own `academy-payments`; the previous dummy-payment function remains separate. The compatibility migration explicitly requires the existing sandbox marker and cannot install on production. Production never routes payments to the dummy simulator.

The official sandbox server has no merchant credentials/mode configured, so it reports unavailable. Its database settings authorize only future isolated provider tests. Production independently retains `live_enabled=false`, `merchant_approved=false`, environment `disabled`, and frontend `paymentCheckoutEnabled=false`.

Completed features: protected paid-course editing/publication, independent BDT/USD pricing, native BDT hosted checkout integration, immutable order snapshots, authenticated account ownership, provider-verified notifications, reconciliation, idempotent enrollment, server-scored quizzes, saved progress, private payment history, administrative order/readiness/audit/refund views, full-refund request/verification and safe access revocation without deleting learning records.

## Evidence

- 138 automated production assertions passed, including PostgreSQL migration/security/integrity/scoring/refund tests and provider/handler tests.
- 83 existing dummy-sandbox regression assertions passed.
- 23 production pages and 23 official-acceptance pages passed static link/asset/anchor/ID checks.
- 69 actual deployed production route/viewport checks passed with no detected JavaScript errors, horizontal overflow or automated WCAG axe findings. Desktop, phone and iPad-sized layouts were checked; the production median DOMContentLoaded was 580 ms in this environment, not a general performance benchmark.
- 69 official acceptance route/viewport checks passed, including disabled billing controls, closed checkout and sandbox-only network targeting. An initial test used Playwright's fieldset `isDisabled()` helper incorrectly; checking native fieldset/input disabled semantics confirmed the controls were disabled. A transient course-load timeout was investigated; the independent read returned the expected paid metadata/prices with successful APIs. The final audit supports one explicitly recorded availability retry and fails if the repeated load fails.
- Deployed-static desktop/Android-style/iPad-style purchase-to-quiz-to-dashboard journeys passed with isolated Auth/Data/provider fixtures. Failure, cancellation, refresh, protected access, wrong/correct answers, progress/history and admin editing/order visibility were covered. These do not represent a real merchant payment or a real authenticated customer browser session.
- Hosted production read-only role checks asserted `current_user` and both JWT claim settings. Students cannot execute settlement functions, read private payment tables or access admin enrollment records; administrators retain enrollment visibility. Anonymous users see published metadata, not protected content or payment RPC execution.
- Production application rows exactly match the pre-change backup projection. Four Auth users, one managed course, two enrollments and two progress records were preserved; Auth confirmation/identity fingerprint is unchanged. No production orders, refunds, payment entitlements or prices were created.
- Existing sandbox purchase, enrollment, progress and prices were preserved. The approved student's original paid lesson is still readable after authorization, with MD5 `becc28e47cc0ce45bf4f7a621331d9f8`; official gateway orders/refunds remain empty.
- Live payment-function GET reports unavailable; anonymous actions and unapproved notifications are rejected. Actual card/bank/payment processing was never initiated.

The live catalog bug found during verification was fixed and regression-tested: the listing's `#catalog` container now triggers live data loading instead of showing static samples. Cache versions were advanced. Missing foreign-key indexes and redundant permissive SELECT policy findings were corrected without changing authorization semantics.

## Remaining advisor findings

Security Advisor: six deny-by-default private RLS tables intentionally have no client policies; two anonymous boolean metadata helpers and nine authenticated guarded SECURITY DEFINER functions are flagged for executable access. Their search paths, callers, grants and runtime authorization were reviewed. Privileged settlement/refund RPCs are service-only. Removing intended execution grants would break legitimate course access/admin/scoring behavior.

Leaked-password protection remains disabled. Available integration tools do not expose Auth configuration mutation; review the setting and applicable plan in Supabase Dashboard before customer launch: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection . No SMTP/Auth settings, credentials or confirmation requirements were weakened.

Performance Advisor: only unused-index INFO notices remain on new/low-traffic tables. Required indexes are retained. Health Advisor: no findings.

## Honest limits and acceptance gates

No merchant account/credentials or authorized signed-in customer browser session was available. Provider acceptance, real email delivery, physical Android/iPad Safari and live financial behavior are not claimed as independently verified. Browser device tests use Chromium viewport/touch/user-agent emulation. Paid-course database behavior was tested in isolated PostgreSQL and with explicit hosted read-only authorization checks.

Native USD collection is not implemented with the BDT adapter: SSLCOMMERZ's published API describes conversion into BDT. USD prices remain independent and visible, but USD checkout is disabled. A verified native-USD provider/capability needs a separate accepted adapter.

Before sales: complete actual business/domain/KYC/bank onboarding; supply the academy's real support/legal/refund terms; securely install merchant credentials; run official sandbox/provider acceptance; resolve any provider refund-IP requirements; review password protection/backup retention; and obtain the owner's separate explicit live-activation approval. No manual application database setup is needed for the prepared official acceptance area. See PAYMENT_OPERATIONS.md for exact secret names, callback URLs, sandbox test setup and activation gates.

The application-scoped logical backup and full Git bundles are verified; all original application rows restored and survived isolated migration/recovery testing. Managed full-project Auth/Storage backup or PITR availability was not verified or purchased. See RECOVERY.md; never discard subsequent customer records by restoring a stale snapshot.
