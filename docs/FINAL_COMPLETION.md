# Main website completion — 18 November 2026

Target: Kuniam68/Cardiology- / production Supabase zeneffylfgiyezpegqto only. The normal production accounts, Auth project, public key, session storage, email redirects, SMTP and confirmation behavior are preserved. No sandbox login is required on the main website.

## Completed improvements

- Payment method categories are explicitly labeled as non-selectable previews. The provider chooses actual approved methods only after checkout is activated.
- Closed checkout disables billing and currency controls, gives clear enrollment guidance and never offers dummy completion.
- Stored payment status works with an order ID alone, independently of current course publication, prices or catalog availability. Query-string success claims are ignored.
- Existing course access blocks another purchase. The server rechecks the caller's current authorization through the existing user-scoped access RPC before creation or returning a pending provider URL. Uncertain authorization fails closed; payment-status records remain readable by their owner.
- Free checkout works without payment-provider availability. If a server quote is unavailable, authorized catalog data can be shown read-only; paid submission stays disabled until a server quote succeeds.
- Payment history includes dates, exact historical amounts, readable status labels, secure order-status links and a retry action. Legacy unscored completions are preserved without displaying a misleading 0/0 quiz score.
- Payment administration includes filters/search, readiness descriptions, inline refund-request forms and a separate explicitly gated financial confirmation. No browser prompt is required. Verified review-state orders can be submitted for a non-financial refund request; backend authorization/receipt requirements remain authoritative.
- Billing phone constraints are compatible with modern HTML pattern validation; error, empty and temporary-unavailability states provide safe retry/navigation paths.

## Integrity and recovery

No production database migration, data write, policy change, Auth setting change or privilege grant is required for this release. The payment function adds only a caller-scoped read of the existing access RPC.

Recovery point: production commit d12e8156a9f399a5ff7a31bc80e31445e67d705d. Private backup: /workspace/private/cardiobug-final-completion/. The Git bundle was verified and cloned successfully; the restored source passed syntax checking. All 14 application table snapshots exactly matched an isolated PostgreSQL restore. The emergency stop was tested locally without deleting records. These are application-scoped backups, not a claim of managed Auth/Storage/PITR coverage.

For rollback, keep checkout/refunds disabled, restore the frontend from that compatible release, and redeploy its academy-payments function if necessary. Retain the database schema, records, policies and scoring RPCs. Never drop tables, restore an older whole-database snapshot over newer learning records, or enable a simulator. See RECOVERY.md and supabase/operations/stop-checkout.sql for the existing safe stop procedure.

## Testing boundary

Automated PostgreSQL/security/regression assertions and isolated desktop/Android-style/iPad-style browser fixtures cover unavailable merchant transactions. Live anonymous checks verify the deployed main website, layout, accessibility, production project targeting and disabled controls. Explicit read-only database checks verify existing records and authorization. Authenticated browser fixtures are not a real customer session, physical Safari testing or official provider acceptance.

## Still dependent on owner/provider input

An approved SSLCOMMERZ merchant account, securely installed server credentials, official sandbox/provider acceptance (including callback/refund network requirements), actual business/support/refund details and separate written activation approval remain required before sales. Actual USD collection remains unavailable unless a native-USD provider capability is verified and integrated; independent USD prices are not conversions.

Leaked-password protection remains a known Supabase configuration finding. Available integration tools do not support its Auth configuration mutation; review the setting/plan in Dashboard. Intentional private RLS tables and guarded SECURITY DEFINER execution notices remain documented. No permission was removed blindly and no authentication restriction was weakened.
