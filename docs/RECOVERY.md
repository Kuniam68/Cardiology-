# Verified backup and non-destructive recovery

Baseline production revision: `29ab2414f7bf235cad1b09c49d526745cada9cc5`.
A complete Git bundle was created and `git bundle verify` passed before production changes.
Private backup directory: `/workspace/private/cardiobug-production-backup/` (directory mode 0700; data file 0600). This directory is outside the repository and is never uploaded by GitHub Pages.

`database-before.json` contains all six affected public application tables, their columns/constraints/RLS policies/grants, and original public function definitions/ACLs. The baseline had 4 Auth users, 1 managed course, 2 enrollments and 2 progress records. No Auth credentials, password hashes, SMTP secrets, API secrets or session tokens were exported. Auth count/confirmation fingerprint was recorded for integrity only.

The application snapshot was restored into isolated PGlite PostgreSQL, both initial migrations were applied, and each original row was compared before/after. The recovery switch was tested without removing orders, enrollments, progress or course data. Automated database regression tests additionally test new checkout, refund and access behavior. This verifies the affected application backup; it is not a full Supabase Auth/Storage backup or a claim of PITR availability.

Operational rollback:
1. Verify the project identity; execute `supabase/operations/stop-checkout.sql` with the database owner to stop new sessions while preserving in-flight reconciliation.
2. Keep the additive schema and existing records. Never roll back by dropping payment tables, deleting enrollments/progress or exposing original paid payloads.
3. Revert only a faulty frontend/function commit to a known compatible release; version modules to avoid mixed caches. The pre-commerce bundle is preserved for source recovery, but its old direct progress INSERT path is incompatible with the new verified scoring RPC. Do not restore that permission or blindly deploy the pre-commerce frontend over a paid installation.
4. If application data ever requires restoration, restore the private backup into a new isolated database first and compare it before requesting an owner-approved targeted recovery. Do not overwrite production with a stale snapshot: that would discard subsequent real enrollments/progress and is not authorized.

A routine stop/revert keeps all added score columns, protected-content policies, payment snapshots and audit history. Credentials and existing original course data are not changed by this release. Obtain a managed full-project backup/PITR retention suitable for live financial operation before activation; no paid plan or backup subscription was purchased here.

## Final completion recovery point

The subsequent frontend/payment-function completion has a separate verified baseline at `d12e8156a9f399a5ff7a31bc80e31445e67d705d`. Its private recovery directory is `/workspace/private/cardiobug-final-completion/`. The Git bundle was cloned and checked, all 14 application table snapshots matched a restored isolated PostgreSQL instance, and the safe stop SQL was exercised there. No production database objects or records were changed by that completion release. See FINAL_COMPLETION.md for scope and rollback instructions.
