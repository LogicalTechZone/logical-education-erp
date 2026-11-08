# Logical Education ERP — Revised M1 Architecture Review

**Planning only.** This revision does not authorize migrations, database changes, access grants or application development. Explicit approval of M1 development is still required; reviewing/approving planning refinements alone does not start implementation.

The complete versioned technical document is available in Files as **Logical_Education_ERP_M1_Architecture_v2.md**, retaining the original assessment, ERD, dictionary, permission matrix, navigation, design system and ten-phase sequence while correcting the affected security sections.

## Confirmed requirements
- Email verification is required before account access.
- M1 invitations are secure copyable links; email delivery is deferred.
- Initial Platform Admin email: **logicaltechzoneofficial@gmail.com**. This identifies the bootstrap account, not a frontend authorization rule.
- Theme choices are **Light (default)** and **Dark** only.
- TanStack server functions with PostgreSQL RPC are conditionally approved, subject to verified authorization and secret isolation.
- No fake dashboard statistics, future ERP modules, ownership-transfer UI, subscription integration or email provider in M1.

## Updated schema decisions
- Retain tenants, branches, profiles, memberships, roles, permissions, role_permissions, invitations and audit_logs; add membership_branches, invitation_branches and platform_admins.
- Keep five immutable global system roles plus tenant-owned custom-role capability. Ordinary tenant role edits are deferred. Add a partial unique index on roles.key WHERE tenant_id IS NULL, in addition to tenant/key uniqueness.
- Database validation on membership and invitation role assignment accepts only global system roles or matching-tenant custom roles; role tenancy/identity is immutable. Custom roles cannot represent Owner or platform authority.
- Replace invitation branch UUID arrays with invitation_branches. Composite foreign keys link both invitation and branch within the same tenant. Invitations also reference the inviter's membership within that tenant.
- membership_branches uses matching-tenant composite foreign keys for both parents.
- tenants.active_owner_count is an internal transactional counter, not editable through user/API updates. Membership triggers atomically maintain it; an Owner-exit decrement succeeds only when the current count exceeds one. Multiple Owners are allowed; at least one survives.
- Membership-to-profile deletion is restricted, preventing an Auth/profile cascade from silently deleting the last Owner. Profiles otherwise remain tied to auth.users with cascade lifecycle handling.
- platform_admins stores the authenticated user's UUID, completely separate from tenant memberships and roles. No browser or tenant-role write path exists.

## RLS and access plan
- Every table has explicit grants in the same migration, followed by RLS and policies. No anonymous table access in M1.
- Ordinary tenant operations use the authenticated user's JWT. Permission helpers derive identity from auth.uid(), require verified account and active membership/tenant, and never trust submitted roles or ownership.
- System role and permission catalogs are readable to verified authenticated users. Custom roles and their role_permissions require membership of their owning tenant plus role.view. Foreign custom permission rows are hidden.
- Branch-scoped callers can read/manage only permitted branches and permitted member/invitation projections. Scoped invitation visibility requires all offered branches to be within the caller's access.
- Profile base access is self-only. A scoped directory returns only safe display fields, never unrelated profile/email/preferences payloads.
- Direct membership/invitation/join-table mutations are denied. Narrow transactional RPCs independently authorize these operations; SECURITY DEFINER is not assumed to preserve RLS.
- Audit records are database-controlled and append-only for ordinary users. Raw tokens and token hashes are excluded from audit metadata and user-facing invitation projections.
- Helpers/RPCs use fixed empty search_path, qualified objects and restricted EXECUTE grants. No platform-admin exception is added to normal tenant RLS.

## Security decisions
### Invitation authority
Creation and acceptance both validate tenant, role-grant authority, every branch and the inviter's current active permission. Branch-scoped invitations need a nonempty authorized subset; organization-scope roles require an organization-scope inviter. Revoked authority or disabled branches cause rejection. Acceptance requires the current verified invited email, locks the relevant records, and creates membership, branch assignments, accepted state and audit atomically. Existing memberships are not silently upgraded/reactivated.

Generate 32 cryptographically secure random bytes and store only SHA-256 hash. Return the copyable link once; prefer a URL fragment to avoid HTTP token logging, clear it after reading and send via authenticated POST. Enforce seven-day expiry and single use; redact tokens from logs/telemetry. No email provider in M1.

### Last active Owner concurrency
Lock tenant first, then targets in stable order. Revalidate actor/target after lock acquisition in a subsequent READ COMMITTED statement. Do not rely on a COUNT query with a stale statement snapshot. The atomic protected counter guards concurrent Owner exits even when prior reads were stale; rollbacks restore it. Higher-isolation conflicts require whole-transaction retries. Provisioning cannot commit without its initial Owner. Multi-tenant maintenance locks tenants in UUID order. Account-wide disablement is not an M1 feature; future/trusted operator workflows must preserve effective ownership before disabling accounts.

### Platform Admin bootstrap
After explicit development approval, use a controlled migration or trusted server-side administrative process to resolve exactly one confirmed Auth account for **logicaltechzoneofficial@gmail.com**, verify its current authenticated identity and email ownership, then insert its immutable UUID into platform_admins idempotently with audit evidence. If absent/unverified, grant nothing until verified signup. No bootstrap is executed during planning, no frontend email authorization, no public privilege trigger, and no Owner/Admin promotion path. Later administration remains an operator-controlled process in M1.

### Server execution and privileged operations
The framework supports server-only handler execution and private environment secrets; published behavior is not yet verified. Keep privileged authorization routines in server-only modules and load the privileged client inside the handler only after user-scoped platform authorization. Never expose service-role keys in VITE variables, browser bundles, logs or returned data.

Preserve anti-CSRF protection and register bearer attachment for authenticated server functions. Validate JWTs and verified identity; ordinary operations retain JWT/RLS access. Every service-role operation checks the initiating actor, action and target first, projects only needed fields and writes audit evidence. Do not expose generic privileged table/query/RPC proxies. Platform status changes serialize with tenant permission-sensitive mutations.

## Revised implementation sequence — only after development approval
1. Tables, enums, explicit grants, partial indexes, composite foreign keys and immutable identity validation; seed system catalogs only.
2. Helpers, RLS, scoped directory, audit and transactional Owner guards.
3. Atomic onboarding, copyable invitation lifecycle, role/status and branch-assignment RPCs.
4. Verified-email signup/login/logout/recovery and exactly-two-theme design tokens.
5. Protected application shell, onboarding and organization switching.
6. Branch create/view/edit/activate/deactivate.
7. Users/invitations and role/permission read views.
8. Organization settings and real-data dashboard.
9. Separate Platform Admin area and controlled verified-account bootstrap.
10. Acceptance tests and evidence report; deploy-only checks after deployment is authorized.

## Explicit test gates
Retain all fourteen original acceptance tests and add:
- **Cross-tenant role assignment:** membership AND invitation paths reject foreign roles at database level; system duplicates rejected despite NULL tenant.
- **Invitation branch restrictions:** foreign/unassigned/disabled branches, empty scoped grants, scope escalation, lost inviter authority, wrong/unverified email and token replay denied; authorized exact subset succeeds atomically.
- **Concurrent last-Owner protection:** independent database sessions with barriers race demotion, status and deletion/maintenance paths; one survivor remains and counter matches actual rows. Ordinary equal-rank/self edits are separately denied. Include rollback and stale-isolation cases.
- **Unauthorized service-role operations:** anonymous/forged/expired JWTs and tenant Owners/Admins denied before privileged-client creation/use; instrument zero privileged calls. Authorized platform UUID succeeds and produces audit evidence.
- **Custom-role permission isolation:** direct API and RPC joins return no unrelated tenant roles/permissions; authorized same-tenant catalog access succeeds.

Also verify real signup confirmation/recovery, direct API grants, scoped profiles, token expiry/acceptance races, per-user theme persistence and deployed secret boundaries. Tests are planned, not executed; no security or readiness claim until evidence exists.

## Approval and configuration gates
The initial Platform Admin email is now confirmed. **M1 development remains blocked solely on explicit development approval.** External Supabase Auth settings/redirects still need hosted verification before auth testing; the account must exist and be verified before its platform grant. GitHub sync and Production environment remain unverified/deferred. No application or database changes have been made in this revision.