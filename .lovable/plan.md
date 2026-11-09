# M1 Organization Creation — Minimum Secure Workflow Review

## Actual findings
- Live read-only Dev inspection found no organization-creation/P3 operation and no Auth signup profile initializer.
- Tenants, memberships, profiles and audit logs each contain zero rows. No existing business record was changed.
- This external unmanaged Supabase connection supplies no authenticated browser session. Login/logout, persistence/expiry, populated organization reads, membership-dependent onboarding and authenticated mobile navigation are **not verified**. No credentials or fabricated sessions will be requested.

## Smallest proposed implementation
1. Keep the existing interface, tables, safe projections, RLS and audit/Owner safeguards unchanged.
2. Prepare one fixed-command `create_organization` database operation for exact SQL review. Applying it requires separate migration authorization.
3. Require a verified current user with a controlled initialized profile. Public signup profile initialization remains separately gated; do not silently add it.
4. In one transaction create the organization and initial active global Owner membership. Derive creator and role internally; existing triggers maintain Owner count and audit history. Return only safe organization fields.
5. Connect the existing onboarding form through an authenticated TanStack server function with client/server/database validation. Provide loading, safe failure and success states; preserve the submission key across retries and refresh the directory/dashboard with authorized read-back.

## Prerequisites before SQL preparation
- Approve the authoritative country/currency source and version for database-side catalog validation. P1 format checks are insufficient.
- Approve a retry contract: either immutable original-request proof (separate storage review), or a narrower contract where same-creator key replay returns the existing authorized organization without applying new fields, explicitly reports replay and makes no same-payload verification claim. Foreign-creator key reuse must not disclose records.
- Supply the controlled profile prerequisite through a separately approved administrative/profile lifecycle process. No automatic test accounts or profile writes.

## Technical boundary
- No caller-selected creator, Owner role, status or counter; database revalidates Auth identity and all inputs.
- Fixed search path, qualified objects, narrow reviewed function ownership/capabilities and signature-specific authenticated execution only. No PUBLIC/anon/service_role execution, broad direct DML grants or ordinary service-role client.
- Serialize creator/key retries; preserve invariant locking and atomic rollback of tenant, membership, counter and audit.
- Do not add profile lifecycle, settings writes or Platform Admin promotion to this command.

## Verification after separate authorization
- Real authenticated creation and directory read-back; exact initial Owner/counter state; invalid/duplicate rejection; anonymous/unverified and foreign-key-replay denial; rollback on partial failures.
- Real authenticated desktop/mobile application checks, persistence, expiry and logout.
- Do not commit disposable tenant fixtures on Dev: immutable audit history prevents clean removal. Use an approved isolated test environment for destructive/failure/concurrency cases. Create a real Dev organization only with explicit owner authorization.

**Current changes:** review plan and roadmap only. No application, database, Auth settings or migration changes. Remaining advanced P2 checks stay separately tracked and do not block approved frontend development.
