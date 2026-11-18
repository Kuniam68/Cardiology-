# Cardiobug production commerce operations

Production: `zeneffylfgiyezpegqto` / `Kuniam68/Cardiology-`.
Website: https://kuniam68.github.io/Cardiology-/
The existing dummy-payment journey remains separate. An official provider acceptance area is prepared at https://kuniam68.github.io/cardiobug-sandbox/gateway-acceptance/ using only szqiueneqmktiilagbdv. Its existing dummy course, purchase and progress records are preserved.

## Current state

Live checkout and refunds are disabled. No merchant credentials have been installed, no financial requests have been made, and no simulated completion action/tester bypass is included in production. Existing courses remain as they were; no existing course was converted to paid or repriced. A separate newly authored introductory course, `intro-cardiology`, is prepared as paid with both amounts awaiting owner approval; see INTRO_COURSE.md.

The administrator can edit courses, inspect enrollments/progress, set independent BDT/USD prices, inspect orders/audit events and prepare full-refund requests. Pricing does not enable payments. Converting a managed course to paid atomically preserves its original JSON privately and sanitizes the public payload. Publishing and editing preserve the protected-content boundary. Existing enrollments are grandfathered; the three bundled public samples always remain free. Existing legacy progress rows remain intact with nullable score fields.

## Provider and currency decision

SSLCOMMERZ hosted checkout was selected for Bangladesh. Its documented v4 API provides session creation, IPN, validation, merchant-reference reconciliation, refunds and refund-status lookup. The adapter is a separate module and injected into the request handler, allowing later gateway adapters with explicit verified capabilities.

The adapter enforces the documented BDT session range (10.00–500,000.00), fixed decimal precision, and provider billing-field limits. Account emails longer than the documented 50-character field are rejected safely before order creation; they are never truncated or sent to a different address.

The public documentation describes non-BDT currencies as conversion into BDT. Consequently this integration permits actual BDT collection only. USD prices are independently stored/displayed but USD collection is disabled. Native USD collection requires a merchant contract/provider with verified USD charge and settlement capabilities plus a separately tested adapter; changing a displayed currency is not sufficient.

Official sources, inspected 2026-11-18:
- https://developer.sslcommerz.com/doc/v4/
- https://sslcommerz.com/onboarding-requirements/
- https://supabase.com/docs/guides/functions/secrets

## Security and state transitions

The Edge Function uses its built-in server credentials and verifies every student/admin bearer against Supabase Auth `getUser`. Client actor IDs are never accepted. Administrative membership is checked in the database, never in user-editable metadata. JWT gateway checking is disabled only to allow provider notifications; actions do their own Auth verification. Callback authenticity is established by credential-authenticated provider validation/reconciliation over verified TLS. Browser callback status, amount, currency and redirect destinations never grant access.

Server creation reads the current course and price revision, locks the actor/course and price snapshot, and creates one immutable order per idempotency key. One provider-session claim is allowed per order. A failed/uncertain external request blocks blind retries; the same order must be reconciled. Hosted URLs are restricted to the correct provider HTTPS origin. Successful provider validation checks merchant reference, exact minor-unit amount, BDT currency, validation ID, bank reference and risk level. Replayed references cannot settle another order. Enrollment and entitlement activation occur transactionally; risky, mismatched and duplicate charges remain ungranted/reviewed. Only an enrolled authorized student can retrieve original paid lessons or save server-checked quiz progress.

Orders, entitlements, refunds, settings, private lessons and audit tables have RLS and no client write privileges. Private tables have no client policies intentionally. Payment/refund mutation RPCs are service-only. Student progress INSERT is revoked in favor of the enrollment/quiz-checked completion RPC. Read-only history returns a whitelisted order view without credentials, bank/card data or raw notifications. Billing details are sent only to the provider and are not persisted/logged by the application.

## Exact server secret configuration

Use the production project's **Edge Functions → Secrets** page (Owner/Administrator permissions), or an authorized Supabase CLI with a private ignored environment file. Never paste secrets into chat, a GitHub issue, frontend config or shell history. `.env.example` contains names only.

- `SSLCOMMERZ_STORE_ID`: the approved store ID for the selected environment.
- `SSLCOMMERZ_STORE_PASSWORD`: the corresponding merchant password.
- `COMMERCE_MODE`: currently defaults to `disabled`; later `sandbox` only on the isolated sandbox ref, or `live` only on production.
- `COMMERCE_PROVIDER_ACCEPTED`: defaults false; set true only after documented acceptance.
- `COMMERCE_LIVE_APPROVED`: defaults false; requires the owner's separate explicit live-activation approval.
- `COMMERCE_REFUNDS_APPROVED`: defaults false; requires separate financial approval and network/provider acceptance.

Example CLI pattern after authorization: `supabase secrets set --project-ref VERIFIED_PROJECT_ID --env-file /private/path/merchant.env`. Verify that CLI version's `--help` before running. No token or password should appear as an inline command argument. Standard Supabase runtime credentials are already injected by the platform and must never be copied to frontend files.

Do not set approval flags while only configuring credentials. The database `commerce_settings` row independently requires the correct environment, merchant approval and `live_enabled`; no frontend/admin toggle can enable it. The frontend `paymentCheckoutEnabled` flag is currently false and will need a separately approved versioned deployment when activation is authorized.

## Callback endpoints

Production function base:
`https://zeneffylfgiyezpegqto.supabase.co/functions/v1/academy-payments`

POST callbacks:
- `/callback/success`
- `/callback/fail`
- `/callback/cancel`
- `/callback/ipn`

Session creation sets all four URLs automatically. Configure the IPN listener in the merchant portal too. The official sandbox uses the same callback suffixes under https://szqiueneqmktiilagbdv.supabase.co/functions/v1/academy-payments; never configure the production listener in a sandbox merchant account or vice versa. Notifications do not use a student session. Browser returns go only to the fixed production `checkout.html` path with the order/course IDs, and the frontend reloads authoritative order state. Supabase Auth email redirect settings, SMTP and credentials are unchanged.

## Acceptance before activation

1. Confirm that the merchant provider accepts the current GitHub Pages storefront URL or requires an owned custom domain. Obtain a dedicated official SSLCOMMERZ sandbox store and then an approved live merchant account. Merchant onboarding must confirm Cardiobug's actual business category, entity identity, bank account, KYC and required licenses/documents. The education and proprietorship checklists differ; do not assume an education institution classification.
2. Publish the actual legal business/support details, course prices/content, and owner-approved purchase/refund terms. The current site transparently says purchases are closed; it does not invent a business address, support mailbox or refund promise.
3. Use the installed official acceptance area at https://kuniam68.github.io/cardiobug-sandbox/gateway-acceptance/ and sandbox project szqiueneqmktiilagbdv. No manual database setup is required. Set official sandbox store credentials and COMMERCE_MODE=sandbox, COMMERCE_PROVIDER_ACCEPTED=true in that sandbox project only; the latter authorizes provider tests there and is not evidence of production acceptance. The sandbox database is configured for sandbox testing, but absent server mode/credentials keep checkout unavailable. COMMERCE_LIVE_APPROVED remains false. Use an existing confirmed test login. Because the current student already completed the original dummy course, use a fresh dedicated paid test course created through the sandbox administrator interface or a fresh test account to exercise a new purchase; do not delete the existing enrollment/progress. Supabase Auth email callbacks continue using the existing root sandbox URLs. The old dummy checkout remains at the sandbox root.
4. Complete provider-hosted BDT sandbox payments, failure/cancellation/retry, validation/IPN delivery, session-loss recovery, delayed notifications, duplicates, risk review, refunds, reconciliation, mobile browser and email-session tests. Keep actual card entry exclusively on the official sandbox hosted page. Record provider acceptance evidence before marking it accepted.
5. Confirm that merchant network requirements work from the deployed Supabase region. SSLCOMMERZ documents public-IP registration for refund APIs. Supabase shared Edge egress must not be assumed to provide a merchant-approved static IP. Arrange a provider-approved allowlisting/static-egress arrangement if required; do not disable TLS or route credentials through an untrusted proxy. Refund execution remains disabled until this is resolved and tested.
6. Install live credentials securely while all activation gates remain closed. Verify readiness booleans in `payments-admin.html`; that view never returns secret values.
7. Obtain separate explicit activation approval. Only then record acceptance, set the server/database approvals and environment, enable the versioned frontend, and perform the provider-approved live acceptance procedure. This assignment does not approve those financial actions.

Actual native USD collection is a separate provider-capability requirement, not a configuration flag in the BDT adapter.

## Refund and recovery operations

Only full BDT refunds are implemented. An administrator can prepare a request with a reason; that creates an audit record and does not move money. Execution is a separate explicitly gated action. Requests have a stable provider refund transaction ID. Uncertain results are never automatically resubmitted; use refund reconciliation or merchant support. A verified completed refund revokes only the matching entitlement, preserving enrollment history and lesson progress. A different active paid entitlement or administrator access is unaffected. Partial refunds and chargeback/dispute automation are not represented as implemented provider capabilities.

Run `supabase/operations/stop-checkout.sql` only on the verified project to stop new sessions. Keep accepted credentials/environment available to reconcile legitimate in-flight payments. Do not delete orders or alter historic amounts. Review pending/risky/duplicate orders in the administrator page. Provider callbacks are not sufficient evidence on their own.
