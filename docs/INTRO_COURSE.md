# Introductory cardiology paid-course preparation

Production course ID: `intro-cardiology`.

- Course: https://kuniam68.github.io/Cardiology-/course.html?id=intro-cardiology
- Checkout: https://kuniam68.github.io/Cardiology-/checkout.html?course=intro-cardiology
- Administrator pricing: https://kuniam68.github.io/Cardiology-/pricing.html?course=intro-cardiology
- Course editor: https://kuniam68.github.io/Cardiology-/admin.html
- Payment operations: https://kuniam68.github.io/Cardiology-/payments-admin.html

This is newly authored, AI-assisted introductory educational content, not owner-approved clinical material or accredited training. The public catalog, course page and full lessons disclose the pending owner clinical/editorial review. The owner should review the original lessons and quizzes in the protected administrator editor before offering sales.

Four lessons cover the circulation route, valves and the cardiac cycle, electrical signals and the ECG, and coronary supply with the limits of introductory learning. Each includes a question, three choices and an explanation. Publicly readable information includes a separately authored preview, objectives, lesson titles/timing, editorial note and reference links. It excludes original lesson bodies, questions, choices, correct answers and explanations. Full course content is held only in private Supabase application data and private recovery files, not this repository.

## Pricing approval

The course is paid. Revision 2 displays provisional prices of ৳100.00 and $5.00. Students can review either amount with billing details. The provisional status blocks order creation until an administrator records commercial approval.

An authorized administrator can load this course's prices, enter independent owner-approved decimal amounts and save. Blank amounts remain unavailable. Saving a price changes neither historical order amounts nor merchant activation. USD display is independent from BDT, but SSLCOMMERZ native USD collection remains unsupported by this adapter. Do not treat currency conversion as native USD settlement.

## Applied safety change

The backward-compatible paid-course-prelaunch migration replaces only `commerce_set_prices` and `payment_public_payload`, retaining ownership, ACLs and RLS. Paid classification may now be saved before an amount is approved; order creation still requires a positive approved price in the gateway range. The public-payload allowlist now includes explicitly public preview, editorial note and reference metadata. Protected lesson fields retain the same locked placeholders.

Course creation uses the existing administrator-protected save and pricing functions in one guarded transaction. The private original is saved before paid publication becomes visible. Existing data, accounts, courses, progress, settings and permissions are checked for preservation. No enrollment or order is created.

## Recovery

Recovery baseline: `1a867a04c6a4d8d872800e76537b88ada409da5b`. The private directory `/workspace/private/cardiobug-intro-release/` holds the verified Git bundle, before-state application snapshot and private authored content. All 14 application tables were restored and compared in isolated PostgreSQL. The guarded creation transaction and non-destructive function rollback were exercised locally before production execution.

If a release regression appears, retain all data and protections, keep financial processing disabled, and restore the compatible frontend/function baseline. An authorized owner may apply `supabase/operations/rollback-paid-course-prelaunch.sql` after verifying the target and current definitions. If publication must be withdrawn, archive only this newly authored course through the existing administrator workflow; never delete course/user/progress rows or overwrite a newer production database with an old snapshot. This release does not claim full managed Auth/Storage/PITR recovery coverage.

## Merchant onboarding

Follow [PAYMENT_OPERATIONS.md](PAYMENT_OPERATIONS.md) for exact server-only secrets, callback/IPN endpoints, environment gates, provider sandbox acceptance, refund network requirements and separate financial activation approval. Credentials are not entered into this site's administrator forms. None of the course or pricing actions enables live checkout or financial refunds.

Primary educational references: [NHLBI anatomy](https://www.nhlbi.nih.gov/health/heart/anatomy), [NHLBI circulation](https://www.nhlbi.nih.gov/health/heart/blood-flow), [NHLBI heartbeat](https://www.nhlbi.nih.gov/health/heart/heart-beats), [MedlinePlus ECG](https://medlineplus.gov/lab-tests/electrocardiogram/). References support the introductory concepts; the providers do not endorse or accredit this course.
