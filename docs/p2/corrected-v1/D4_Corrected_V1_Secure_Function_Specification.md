# Logical Education ERP — M1 P2 Secure RPC and Server Function Specification

**Document:** D4_Corrected_V1  
**Status:** corrected planning specification; every routine is proposed and uncalled. No P2/P3/P4/P9 function has been created.  
**Baseline:** original D4 SHA-256 `c1d4868eb071f864981b9b26b44038664f905726cf2f1689d275963ce7cecb89`; P1 V3 contains only four structural trigger functions and remains unapplied.  
**Decisions:** owner-approved AD01–AD12/S01–S10 recommendations incorporated. Unresolved hosted capabilities and business values remain explicit blockers. No tests are represented as executed.

## 1. Execution architecture and common hardening

### Ordinary requests

- Browser/server code uses the generated Supabase client and current user bearer token through `requireSupabaseAuth` where a TanStack wrapper is used.
- Ordinary SELECT uses ACLs, RLS and approved safe columns. The database repeats identity, membership, permission, rank and branch authorization; TypeScript and hidden buttons are not security boundaries.
- No ordinary tenant read/write, invitation or onboarding path uses the service-role Admin client. service_role retains zero direct P1/P2 table, column, sequence and application-function privileges.

### Every proposed routine

1. Use fixed `search_path = ''` and fully qualified objects/types/operators as required. No dynamic SQL or caller-controlled identifiers.
2. Use explicit input types, null/length/range checks and fixed allowlists. Return only documented safe fields and stable public error codes.
3. Read helpers are STABLE for policy use; authoritative mutation-time revalidation must reread current state after waits and may not reuse a stale STABLE result. State changers are VOLATILE.
4. SECURITY DEFINER is limited to controlled lookup/mutation needs. Function owner, effective RLS behavior and capabilities must match the approved ledger; service_role is not the owner model.
5. Revoke default PUBLIC execution. Grants are full-signature-specific. PUBLIC, anon and service_role receive no EXECUTE on any proposed routine; authenticated receives it only on the ten P2 facades and later separately approved endpoints.
6. Private trigger/writer/internal routines revoke authenticated too. Trigger firing does not require caller EXECUTE.
7. No arbitrary SQL, generic table mutation, arbitrary audit-event endpoint, caller-selected actor or broad row-returning authorization oracle.
8. One state transition equals one database RPC/transaction. A sequence of TanStack calls is not a transaction.
9. Trusted mutation writers lock **tenant → actor/target memberships in stable UUID order → invitation → branch/grant rows**, then reread and reauthorize. Triggers enforce invariants but cannot retroactively establish writer lock order.
10. Domain triggers are the sole row-transition audit producer. RPCs append only separately enumerated semantic events; every success audit shares the business transaction and rollback.
11. Internal errors exclude raw tokens/hashes, settings bodies, secrets and unnecessary PII. Public failures do not expose SQL, FK, tenant, role or inviter details.

## 2. Ownership, capabilities and verified identity

### AD03 owner/RLS feasibility gate

The preferred logical owner split is below. Names describe roles to be designed, not existing database roles or permission to create them.

| Logical owner | Maximum intended capabilities | Explicitly denied |
|---|---|---|
| `p2_lookup_owner` (non-login preferred) | Narrow SELECT on current Auth verification row and only required tenant/member/role/permission/branch/invitation/platform columns for boolean evaluation; EXECUTE on exact private dependencies | All DML, audit/sequence access, token_hash, arbitrary Auth rows/results, application role inheritance |
| `p2_invariant_audit_owner` (non-login preferred) | Narrow reads needed by guards; UPDATE only `tenants.active_owner_count`; INSERT only `audit_logs`; minimum audit identity-sequence usage; EXECUTE on exact private dependencies | General tenant/member/invitation/profile/catalog DML, audit UPDATE/DELETE/TRUNCATE privilege, application role inheritance |
| Future P3 workflow owner | Only separately reviewed fixed-command workflow capabilities | Not granted by P2 or this document |
| Existing P1 function owner | Existing structural role-validation read/trigger behavior | Inspected afresh; no assumed suitability as P2 owner |

The four existing P1 functions are part of the mandatory dependency/ACL review:

| P1 signature | Existing security model | Required final inventory |
|---|---|---|
| `p1_guard_identity() RETURNS trigger` | Invoker; fixed empty path; no application EXECUTE | Actual owner, trigger arguments/events and immutable columns |
| `p1_validate_fields() RETURNS trigger` | Invoker; fixed empty path; no application EXECUTE | Actual owner, field rules and trigger events |
| `p1_validate_role_assignment() RETURNS trigger` | SECURITY DEFINER; fixed empty path; qualified global/custom role read with FOR SHARE; no application EXECUTE | Actual owner, roles SELECT capability/RLS behavior, lock ordering and membership/invitation triggers |
| `p1_touch_updated_at() RETURNS trigger` | Invoker; fixed empty path; no application EXECUTE | Actual owner, timestamp behavior and interaction with counter-only/audit triggers |

SELECT privileges alone do not bypass RLS. Before P2 SQL preparation, authorized read-only hosted evidence must establish whether these non-login owners can evaluate helpers without recursive RLS, and whether table ownership, FORCE RLS or BYPASSRLS changes the result. Any table-owner/BYPASSRLS fallback and its full blast radius needs separate explicit review. No blanket bypass is approved.

The final SQL review must include actual role names, login/inheritance/bypass attributes, table/function owners, every SELECT/INSERT/UPDATE/sequence/schema/type EXECUTE capability and a dependency graph. Application roles must not assume owners, replace functions, disable triggers or create shadow objects.

### AD04 verified-state contract

A private current-user Auth-row lookup resolves `auth.uid()` and returns only the required verification boolean to `p2_current_user_is_verified()`. The exact hosted verification field and current-email/change/ban/session semantics require fresh read-only preflight before SQL. Editable user metadata, stale JWT fields and browser-supplied email are never authoritative.

P3 email matching uses a separate private current-user email/verification lookup with no Auth row returned. After a lock wait it rereads both current email and verification. Verification loss denies tenant access but does not silently alter Owner counters. Account deletion/ban/session-revocation behavior across cached sessions, direct RPC and wrappers remains a P4/deployment evidence requirement.

## 3. Exact public and private function inventory

### Ten P2 authenticated current-caller facades

All return boolean, deny null/unauthorized context unless explicitly stated, reveal no rows and accept no arbitrary acting-user parameter.

| Signature | Exact contract | Authenticated EXECUTE |
|---|---|---|
| `p2_current_user_is_verified()` | Current Auth account exists and has authoritative verified-email state | Yes |
| `p2_is_active_member(p_tenant_id uuid)` | Verified caller + active tenant + active membership + valid global/same-tenant custom role; branch role also requires at least one active assignment | Yes |
| `p2_has_org_permission(p_tenant_id uuid,p_permission_key text)` | Active usable **organization-scope** caller in supplied tenant has exact mapped permission | Yes |
| `p2_has_tenant_permission(p_tenant_id uuid,p_permission_key text)` | Organization caller has exact mapping; branch caller may use exact mapped tenant-level capability only with active assignment. Never grants unscoped branch access | Yes |
| `p2_has_branch_permission(p_tenant_id uuid,p_branch_id uuid,p_permission_key text)` | Active tenant and active same-tenant branch; organization role needs mapping, branch role needs mapping + explicit active assignment | Yes |
| `p2_has_any_permission(p_permission_key text)` | True only if at least one active usable tenant context supplies the key through `p2_has_tenant_permission`; global catalog visibility only | Yes |
| `p2_can_view_role(p_role_id uuid)` | Global role: `p2_has_any_permission('role.view')`; custom role: `p2_has_tenant_permission(role.tenant_id,'role.view')` | Yes |
| `p2_can_view_membership(p_membership_id uuid)` | Verified active usable caller; self OR same-tenant organization `user.view` OR branch `user.view` sharing at least one currently authorized active branch. No organization-only target leakage to branch actors | Yes |
| `p2_can_view_invitation(p_invitation_id uuid)` | Same-tenant organization `user.view`, or branch `user.view` with the entire offered set inside current authorized active branches; organization offers organization-only | Yes |
| `p2_is_platform_admin()` | Verified current user has own platform row; no arbitrary user input and no tenant bypass | Yes |

**P4 only:** `p2_is_valid_last_tenant(p_tenant_id uuid)` (rename to a P4 prefix during P4 design) returns true for null or an active usable tenant of the current caller, solely within the approved self-update path. Null is a valid hint, not a general exception to helper denial.

### Common truth table

| Caller/resource state | Tenant/member/role/branch helpers | Global catalog helper | Platform self helper |
|---|---|---|---|
| Null/no current user, unverified, deleted/unresolvable Auth account | False | False | False |
| Verified + suspended/archived tenant | False for that tenant | False if no other active usable tenant | Independent verified self status only |
| Verified + invited/suspended/removed membership | False for that tenant | False if no other active usable tenant | Independent |
| Verified + active organization membership + same-tenant/global valid role | Permission-dependent; zero branch links required | Permission-dependent | Independent |
| Verified + active branch membership + zero/only inactive assignments | False for active operational use | False through that membership | Independent |
| Verified + active branch membership + ≥1 active assignment | Tenant permission only when mapped; branch permission only for assigned active branches | `role.view` dependent | Independent |
| Foreign tenant/branch/custom role | False | False for foreign custom role | Independent |
| Multi-tenant user | Evaluated independently per tenant; A never authorizes B | True only if at least one active usable context has required key | Independent |

HLP-01–HLP-04, NEW-P2-02/03/04/10 and TEN-01 verify this table; no pure unit test replaces real PostgreSQL/RLS evidence.

### Private dependencies and enforcement routines

No application role receives EXECUTE on these routines.

| Proposed routine | Trigger/internal purpose | Required behavior |
|---|---|---|
| Private current-user Auth/email lookups | AD04 identity source | Current user only; boolean/minimal internal value; no public Auth rows |
| Private rank/scope/enabled-permission-subset checks | D3 delegation | Current post-lock actor/target mappings; exclude reserved capabilities; no arbitrary-user API |
| `p2_guard_system_catalog` | Global roles, global mappings and all permissions INSERT/UPDATE/DELETE | Reject application/definer catalog changes, including display fields and permission descriptions; separately reviewed migration maintenance only |
| `p2_guard_system_catalog_truncate` | BEFORE TRUNCATE on roles/permissions/role_permissions as applicable | Reject controlled system-catalog truncation; custom-role operational impact must be considered in final trigger design |
| `p2_validate_branch_sets` | Deferrable final-state validation on memberships/grants/invitations/invitation branches and branch-status dependencies | Apply D1/D3 status-aware rules using fresh final rows; retain history; deny invalid active final state |
| `p2_sync_active_owner` | Membership insert/role/status/delete and tenant counter dependency | Sole counter writer; exact global Owner OLD/NEW delta; no client counter input; no parallel RPC increments |
| `p2_prevent_last_owner_loss` | Owner-removing transition | After tenant lock/current reread, reject active tenant 1→0 immediately |
| `p2_check_owner_invariant` | Deferrable final-state validation on affected tenants/memberships and tenant activation/counter changes | Active tenant actual count ≥1; every tenant stored=actual; fresh final-state reads |
| `p2_guard_audit_immutable` | BEFORE UPDATE/DELETE on audit | Reject every ordinary/privileged application mutation |
| `p2_guard_audit_truncate` | BEFORE TRUNCATE on audit | Reject; retention/purge requires separate future design |
| `p2_append_audit` | Fixed internal arguments from approved domain/semantic producers | Derived tenant/actor/time, allowlisted metadata, private INSERT/sequence only |
| `p2_audit_<domain>` | AFTER approved row transitions | Exactly one event per changed row; fixed action/entity and safe metadata; no duplicate RPC row event |

The final P2 SQL review must enumerate trigger events, timing, ordering and recursion guards for tenant status/counter, membership role/status/delete, branch status, grant replacement, invitation status and catalog mutation. Counter-only tenant updates must not emit organization settings events or re-enter Owner transition logic. P1 role-integrity FOR SHARE locks and existing identity/field/touch triggers are included in the dependency review.

## 4. Owner/deferred protocol and audit event contract

### Owner protocol

1. Trusted writer locks tenant before membership DML and locks member rows in stable order.
2. The sole counter trigger computes exact global Owner deltas after current-state reread; active 1→0 is rejected before apply.
3. Deferred checks reread final rows under tenant serialization. Temporary initial zero→one is valid only if commit finishes with one Owner; temporary branch/grant transitions are valid only if final state satisfies AD06.
4. Tenant activation and any counter-only change enqueue Owner validation. Suspended/archived tenants require counter equality even though minimum-one applies to active tenants.
5. Promotion to organization role clears target links; relinquishing Owner leaves caller with zero links. Removed/suspended history follows AD06/S06 without forcing historical invitations to retain active branches.
6. READ COMMITTED waiters issue fresh reads after locks. Higher isolation aborts require bounded whole-transaction retry from authentication onward; stale authorization is never reused. S08 retry counts/backoff remain unspecified.

### Audit producer ledger

| Transition class | Producer | Cardinality / restriction |
|---|---|---|
| Tenant, branch, membership, role-assignment, invitation and Owner row transitions | Corresponding private domain trigger | Exactly one row event per changed row; no duplicate RPC row event |
| Separately enumerated workflow semantic events | Approved RPC through private writer | Only events explicitly listed in final review; never substitutes for or duplicates row event |
| Counter-only tenant update | Owner counter mechanism | No organization-settings event; no additional Owner transition event |
| Rejected/failed transaction | None for success audit | Data, counter and audit roll back together |
| System-null actor | Private controlled event only | Controlled system metadata; no arbitrary client null actor |
| Audit/catalog UPDATE/DELETE/TRUNCATE | Guard | Reject; trusted operator able to disable triggers remains outside tamper-proof guarantee |

S01/S02 approve this model but do not supply exact action/entity strings, per-event metadata allowlists or every semantic event. Those exact values are a blocker to P2 SQL preparation. Tests AUD-01–AUD-07, NEW-P2-05/11 and GAP-10 must assert concrete counts and fields once approved.

## 5. Future P3 organization and settings RPCs

Nothing in §§5–8 is implemented or exposed by P2.

### `create_organization`

- Inputs: `creation_key`, name, slug, country, timezone, currency and approved contact fields; no creator, status, counter or role ID.
- Requires verified current user and an initialized controlled profile. Public self-service onboarding remains gated until P4/P5.
- Requires authoritative country/currency catalogue membership, not P1 format-only checks; source/version remains a prerequisite.
- Derives `created_by = auth.uid()` and global Owner internally; tenant + first Owner + counter + audit are atomic.
- P1 stores creator/key but no immutable canonical original-request proof. Before retry behavior is implemented, owner must approve either canonical input + immutable original-request proof (new storage needs separate schema review) or a narrower retry contract. Until then, no same-payload/idempotent-success guarantee may be claimed and LIFE-02/NEW-P3-02 remain blocked.
- A foreign creator can never claim/read another creator's organization through key reuse.

### `update_organization`

Requires post-lock active same-tenant organization `organization.update`; fixed editable fields only. ID, slug, creator, creation key, status, counter and timestamps are excluded. Changed fields and audit commit atomically.

### `get_organization_settings` / `update_organization_settings`

Direct tenant settings column remains denied. No settings key/type is approved under AD09/S09, so these endpoints remain disabled and no usable settings response is claimed. Once owner supplies an org-level key/type/projection catalogue:

- read requires `settings.view` and returns only approved organization-level keys, including for Branch Manager;
- update requires organization-scope `settings.update`, accepts only an allowlisted flat/defined patch and rejects unknown/wrong/nested unauthorized keys atomically;
- secret values and full settings bodies never enter audit/logs.

PRV-03, NEW-P3-03 and related deployment tests remain blocked until that catalogue exists.

## 6. Future P3 branch and directory RPCs

### `create_branch` / `update_branch`

Require exact organization `branch.create` or organization/assigned-active-branch `branch.update`; fixed fields, tenant-first locks, post-lock reauthorization, unique tenant/code handling and atomic audit. Branch Manager cannot create, change identity or change status.

### `set_branch_status`

Only organization-scope `branch.update`. Active→inactive is rejected if any active branch membership would be left without an active assignment. An alternative atomic offboarding workflow requires separate explicit approval. Existing pending/historical invitation links may remain but acceptance fails if any offered branch is inactive; no silent scope reduction. Reactivation revalidates all affected final state.

NEW-P2-08 covers primitive status dependencies; NEW-P3-04 covers the full workflow and races.

### `get_member_directory`

Requires `user.view`; organization actors see authorized tenant roster and branch actors only memberships sharing current authorized active branches. Returns only membership ID, necessary user identifier, display name, avatar, role ID/name/scope/rank, membership status and actor-visible assignments. Never returns phone, last-tenant hint, Auth verification data or full profiles. Stable pagination/filtering cannot broaden scope (PRV-02, NEW-P3-05).

## 7. Future P3 invitation RPCs

### `create_invitation`

- Inputs: tenant, email, role ID and branch ID array only. No inviter, expiry, status, acceptance or hash input.
- Apply verified current inviter, active tenant/membership, `user.invite`, D3 strict-lower/Owner exception, custom enabled-permission subset and full branch containment after locks.
- Organization offer => no branches; branch offer => nonempty distinct fully active same-tenant branches. Any unauthorized item rejects all.
- Generate ≥32 CSPRNG bytes, base64url encode and store only lowercase SHA-256 hex. Return raw token once only after commit. Hash shape and entropy are separate evidence (INV-10).
- Explicitly set `created_at` and `expires_at` from one authoritative server insertion timestamp captured after waits; expiry is exactly +7 days. Do not rely on P1 transaction-start `now()` for this contract.
- Only successful replacement creation atomically transitions matching elapsed pending rows to expired and inserts the replacement. Unique pending `(tenant,email)` handles concurrent duplicates. Failure persists no replacement/expiry success audit.

### `revoke_invitation`

Requires current `user.invite`, target delegation rank and complete branch authority. Admin cannot revoke Owner/equal-Admin offers; Branch Manager cannot revoke equal/higher/out-of-scope offers. Accepted invitations are historical and cannot be revoked. Expired handling must not contradict S03.

### `accept_invitation`

- Input raw token only. Requires current verified Auth email, case-insensitive match and initialized profile. No tenant/email/accepted-user/role/branch/inviter input.
- Private minimal hash lookup discovers the invitation without exposing hash/tenant metadata; all failures use one generic unavailable response.
- Lock common order, reread after waits and use current authoritative time. Require pending/unexpired, active tenant and every offered branch, valid role, no membership conflict and continuing inviter active `user.invite`, rank/scope/subset/full branch authority.
- Insert exact active membership/grants, derive historical inviter and accepted fields, transition once and audit atomically. Existing active/invited/suspended/removed membership rejects; no upsert/reactivation.
- Failed expired acceptance leaves invitation and audit unchanged. It never both rolls back and commits expiry.
- Every accepted-token replay, including same-user retry, receives generic unavailable. No completed-result replay is approved.
- Simultaneous accept/accept and accept/revoke serialize; only one valid result commits. Token rotation is revoke/recreate because P1 terms/hash are immutable.

Tests INV-01–INV-10, ACC-01–ACC-14 and NEW-P3-07–NEW-P3-10 remain P3-blocked.

## 8. Future P3 membership, P4 profile and P9 platform contracts

### Membership and Owner RPCs

`update_membership`, `replace_membership_branches`, `transfer_ownership` and `remove_owner` require current `user.update`/exact Owner authority as applicable, tenant-first locks and post-lock target/new-role hierarchy, enabled-permission subset, branch containment and final-state invariants.

- Non-Owner equal-rank management and self escalation are denied. Only exact Owner manages Owner.
- Branch Manager has no existing-membership `user.update`.
- Full branch replacement is atomic; active branch roles need at least one active final assignment and organization roles need zero links.
- Owner promotion clears target links; transfer promotes first and optionally demotes caller to Organization Admin with zero links; remove is status-based.
- Exact per-status historical link cleanup and whether relevant pending invitations are proactively revoked or left pending-but-unusable remain S06 P3 blockers. In either case current access/acceptance fails closed and other-tenant access/history is preserved.
- Failure at membership, grant, counter or audit stage rolls back everything (NEW-P3-06/11/12).

### P4 profile lifecycle

P4 owns Auth-derived profile creation/replay and exactly one self-update mechanism: either narrow direct column grants + self RLS or one dedicated RPC, selected in the P4 design. P2 installs neither. The five possible self fields are `full_name`, `avatar_url`, `phone`, `theme_preference`, `last_tenant_id`; identity/timestamps remain immutable. Theme is only Light(default)/Dark. Last tenant is a nullable active-membership navigation hint, never authority. P3 tests use controlled initialized profiles; public onboarding waits for P4/P5.

### P9 Platform Admin

P2 only supplies verified self status/read and non-bypass. P9 separately specifies verified current-email resolution of `logicaltechzoneofficial@gmail.com` to immutable Auth UUID, controlled insert/delete grant/revoke, repeat bootstrap, wrong/unverified/current-email mismatch denial, explicit platform operation projections and Auth-cascade audit. Tenant roles never satisfy P9 checks and no seed/grant occurs now.

## 9. TanStack wrapper, abuse and deployment contract

For each later exposed workflow, a thin server function must:

1. validate bounded input shape and authenticate the current user;
2. enforce durable abuse controls on **both direct PostgREST RPC and wrapper paths**, or use a separately reviewed exposure restriction that makes bypass impossible;
3. call exactly one transactional RPC for the state transition;
4. map stable errors to safe messages without SQL/FK/tenant/token leakage;
5. return documented safe fields; raw invitation token appears only in successful post-commit create response;
6. avoid Admin/service-role clients and raw request-body logging;
7. derive correlation/IP only from trusted deployment data;
8. define bearer versus ambient-cookie behavior, Origin/CSRF checks, malformed/missing/expired JWT handling and direct-RPC equivalence.

S08 does not supply storage/service, identity/limit keys, counts/windows, failure-open/closed behavior, maximum input sizes, numeric volume/latency/throughput budgets or retry counts/backoff. These are blockers, not permission to invent values. In-memory counters are not durable proof. P2 still requires policy-plan and primitive concurrency/stress qualification before business endpoints; P3 deployment parents wait for their complete feature and approved budgets.

Relevant tests: DEP-01–DEP-03, PERF-01/02, NEW-DEP-01–NEW-DEP-04 and GAP-03/04/05/07.

## 10. Required live verification after separate approvals

- Exact owners, role attributes, definer/volatility, empty paths, qualified references and dependency graph.
- Full-signature EXECUTE ACLs including PUBLIC/inheritance/overloads/schema/type/nested calls; zero service_role table/column/sequence/application-function privileges.
- Safe tenant/invitation columns and zero direct authenticated DML in P2.
- Exact twelve read policies, no recursion and positive/negative truth-table behavior under real verified/unverified JWTs.
- Owner counter drift/activation/two-session races, branch-status final-state validation and bounded fresh-reauthorization retries.
- Private audit writers, exact event counts/metadata, UPDATE/DELETE/TRUNCATE guards and rollback.
- Real direct PostgREST and wrapper paths, deployed secret/token boundaries, durable abuse enforcement and measured S08 budgets once approved.

These checks are planned, not executed or passed.

## 11. Change history

**Corrected V1:** added exact ten-P2/one-P4 helper inventory and truth table; removed undefined aliases; established owner/capability/preflight gate and fresh Auth lookup; completed tenant-first Owner, deferred final-state, recursion and retry requirements; added branch-status/history semantics; established single audit producer and catalog/audit TRUNCATE guards; moved all business routines explicitly to P3 and profile lifecycle to P4; applied insertion-time expiry, failed-expiry rollback and universal accepted replay rejection; marked organization retry proof, settings keys, offboarding transitions, abuse values, P9 lifecycle and hosted ownership as blockers. Original D4 remains unchanged.
