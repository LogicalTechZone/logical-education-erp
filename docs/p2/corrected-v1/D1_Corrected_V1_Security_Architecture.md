# Logical Education ERP — M1 P2 Security Architecture Blueprint

**Document:** D1_Corrected_V1  
**Status:** corrected planning document; owner-approved AD01–AD12 and S01–S10 recommendations incorporated; not implemented or approved for SQL preparation/execution.  
**Baseline:** original D1 SHA-256 `a240edef2e46fc8da82753f988de66c2c66274c6499b65ae6d9c4e0280471e1f`; unapplied P1 V3 SHA-256 `deebaca7ea8ea7e58fb2b96af74ac64f1d049fc1a4447ed5fa459f058504535a`.  
**Execution boundary:** no SQL, migration, database, Auth, application or settings change is authorized or reported by this document. All tests referenced here remain proposed and NOT EXECUTED.

## 1. Purpose and phase boundary

P2 is a security-primitive phase. It must turn the twelve deny-by-default P1 tables into a least-privilege read and invariant boundary without exposing organization provisioning, invitation, membership, profile-lifecycle or platform-administration workflows.

| Phase | Normative ownership | Explicit exclusion |
|---|---|---|
| P1 | Twelve tables, five enums, constraints/indexes, fixed 5/14/37 catalogs, structural triggers, authenticated SELECT-only grants with zero policies and zero direct service_role privileges | Unapplied; no Owner counter synchronization, policies, business writes or profile signup handler |
| P2 | Current-user verification and authorization helpers; twelve read policies; safe column grants; custom-role isolation; branch/Owner invariants; catalog/audit immutability; private audit writers | No public business RPC, profile write, Platform Admin grant or P3 workflow test claim |
| P3 | Atomic organization, branch, directory, settings, invitation and membership/Owner RPCs after separate approval | No self-service public onboarding claim before P4; no reserved custom-role management or branch deletion |
| P4 | Auth-derived profile initialization, one approved self-update path, theme/last-tenant writes, signup verification and recovery UX | No tenant/platform authority from profile metadata |
| P9 | Verified-UUID Platform Admin bootstrap, grant/revoke, Auth-cascade audit design and narrow platform operations | No implicit tenant access or P2 bootstrap |

P3 controlled tests may use pre-existing initialized profiles. Public self-service onboarding remains gated until P4. This preserves the approved phase order and does not silently move profile creation into P2 or P3. Owner-management backend contracts may be designed for P3, but no ownership-transfer/additional-Owner screen is authorized by AD08.

### Non-negotiable invariants

1. `auth.uid()` is the only ordinary end-user identity. Client user IDs, actor IDs, inviter IDs, tenant claims and creator values are never authority.
2. A supplied tenant ID is a lookup key, not a trusted context. Authority comes from current verified Auth state, active tenant, active membership, valid role, permission mappings and branch assignments.
3. System roles are global and immutable to application/definer paths. Custom roles must belong to the target tenant and never acquire Owner or Platform Admin semantics through names, ranks or permission bundles.
4. Permission keys authorize capabilities. Rank only constrains delegation/management; it never substitutes for a permission check.
5. Organization roles have zero branch links. An active branch-role membership needs at least one active assigned branch; inactive links confer no authority.
6. Every tenant-bearing self-read also requires verified current identity, active tenant and active usable membership. Profile self-read is non-tenant and separate; Platform Admin self-status requires verified identity.
7. Ordinary reads use the user JWT, ACLs and RLS. Privileged routines use separately reviewed owners and repeat authorization; service_role receives no direct P1/P2 table, column, sequence or application-function privilege.
8. Unverified callers and suspended/archived tenants fail closed for tenant access. No inactive-self membership exception is introduced; any future offboarded-account status projection belongs to P4 and needs separate approval.
9. Platform authority is independent of every tenant role. No `OR is_platform_admin()` tenant-policy bypass is permitted.

## 2. Trusted tenant context

The effective context is resolved in this order:

1. Require a valid server-verified Supabase JWT and non-null `auth.uid()`.
2. Resolve current email-verification state through a private current-user Auth-row lookup. Never use editable metadata, a browser claim or a stale pre-lock boolean as proof.
3. Resolve the caller membership by `(auth.uid(), requested_tenant_id)` and require active membership and active tenant.
4. Resolve the role and permission keys. Accept only a global system role or a custom role whose `tenant_id` equals the requested tenant.
5. For organization scope, require zero branch links. For branch scope, require at least one active same-tenant assignment for active operational use.
6. Evaluate organization or branch permission with the exact D4 helper semantics. Rank and Platform Admin status never widen these checks.
7. Derive actor, creator, inviter and acceptance identity inside the trusted routine. Reject conflicting client identity fields.
8. After every mutation lock wait, re-read authoritative identity, tenant, membership, role, permission and branch state. A STABLE policy-helper result obtained before the wait is not sufficient mutation proof.

`profiles.last_tenant_id` is only a P4 navigation hint. P2 installs no last-tenant validator or profile write. The P4 helper may return true for a null hint or an active usable membership, but that helper does not itself grant tenant access.

## 3. Helper, ownership and RLS architecture

D4 §§1–3 is the exact function and capability contract. P2 has ten authenticated-callable current-caller boolean facades:

- `p2_current_user_is_verified()`;
- `p2_is_active_member(uuid)`;
- `p2_has_org_permission(uuid,text)`;
- `p2_has_tenant_permission(uuid,text)`;
- `p2_has_branch_permission(uuid,uuid,text)`;
- `p2_has_any_permission(text)`;
- `p2_can_view_role(uuid)`;
- `p2_can_view_membership(uuid)`;
- `p2_can_view_invitation(uuid)`;
- `p2_is_platform_admin()`.

`p2_is_valid_last_tenant(uuid)` is P4-only. Undefined aliases `p2_has_org_or_branch_permission` and `p2_can_access_branch` are removed. All helper grants are signature-specific; PUBLIC, anon and service_role EXECUTE are revoked. Private Auth lookup, subset/rank/branch-set, trigger and audit routines have no application-role EXECUTE.

### Ownership gate

The approved preference is separate non-login lookup and invariant/audit owners with the least object capabilities, neither service_role nor inheritable by application roles. This is a capability ceiling, not evidence that hosted role creation or a non-recursive RLS mechanism is available.

Before P2 SQL preparation, a separately authorized read-only Dev preflight must establish actual owner/role feasibility, inheritance, table/function ownership, FORCE RLS and bypass behavior. SELECT grants alone do not bypass RLS. A table-owner or BYPASSRLS fallback has a broader blast radius and requires explicit review; it is not silently approved by AD03. No function may set `row_security = off`, use dynamic SQL or expose arbitrary rows.

## 4. Table access model

D2 is the authoritative operation-by-operation matrix.

- Authenticated users receive row-filtered read access only through the twelve named SELECT policies.
- Tenant table-level SELECT is replaced by eleven safe columns. `settings`, `created_by`, `creation_key` and `active_owner_count` remain ungranted.
- Invitation SELECT remains safe-column-only and excludes `token_hash`.
- Profile SELECT is self-only. P2 installs no profile INSERT/UPDATE/DELETE policy or grant; all five safe self-fields and last-tenant validation move to P4.
- No direct authenticated INSERT, UPDATE, DELETE or TRUNCATE privilege/policy is added to any P1 table in P2.
- All future business mutations use one reviewed transactional RPC with explicit post-lock authorization.
- Audit rows are appended by private trigger-controlled writers only. UPDATE, DELETE and TRUNCATE guards protect audit and the controlled system catalogs; trusted operators able to disable triggers remain an administrative boundary, not tamper-proof forensic storage.
- Platform Admin rows are verified-self-visible only and remain permanently unbootstrapped in P2. Rolled-back test fixtures do not constitute a grant.

RLS filters rows, not columns. Object grants and RLS are both required; neither replaces the other.

## 5. Role delegation and branch lifecycle

D3 preserves exactly five roles, fourteen permissions and thirty-seven mappings. `branch.delete` and `role.manage` remain reserved and disabled.

### Delegation and management

- Every non-Owner may invite, assign or manage only strictly lower-ranked roles. Organization Admin cannot grant or manage another Organization Admin or any Owner. Branch Manager cannot grant or manage an equal Branch Manager and has no `user.update` for existing memberships.
- The exact global Owner role is the only equal-rank exception. An active Owner may grant/manage Owner within the same tenant through guarded future P3 workflows and last-Owner controls.
- A custom target's permission set must be a subset of the actor's current enabled delegable permission keys, excluding `branch.delete` and `role.manage`. Organization actors may delegate compatible organization or narrower branch scope; branch actors may delegate only branch scope wholly inside their assigned branches.
- Promotion from branch to organization scope atomically removes all membership branch links. Relinquishing Owner demotes the caller to Organization Admin with zero links. No branch link survives an organization-role conversion.
- These are future P3 backend rules. They do not enable custom-role management, reserved capabilities or an Owner-transfer UI.

### Branch state and history

- Organization memberships/invitations always have zero branch links.
- An active branch membership must have a nonempty link set with at least one currently active branch. Every newly added/replacement grant must be active, same-tenant and authorized. Additional inactive historical links may remain but grant no access.
- A newly created pending branch invitation must have a nonempty, distinct, fully active offered set. Accepted, revoked and expired invitations retain their original links. A pending offer that later becomes inactive or exceeds inviter authority remains structurally stored but is unusable at acceptance; it is never silently reduced.
- Non-active/offboarded memberships may retain or clear historical links under the future P3 offboarding contract. The exact per-status cleanup and proactive pending-invitation transition remains a P3 blocker under S06; P2 always denies current access and acceptance revalidates authority regardless.
- Branch deactivation is rejected if it would leave any active branch membership without an active assignment. A separate atomic offboarding alternative requires explicit later approval; it is not the default.
- Deferred validators re-read final state. They must not require historical accepted/revoked/expired invitations or removed memberships to retain active branches or perpetual inviter authority.

## 6. Owner integrity and concurrency

P1's `active_owner_count` is storage only. P2 must install one coordinated protocol:

1. Every trusted writer determines the affected tenant and locks the tenant row before actor/target membership DML. Multi-member rows are locked in stable UUID order; multi-tenant maintenance sorts tenant IDs first.
2. Only one private counter-delta trigger writes `active_owner_count`. It computes OLD/NEW contributions using the exact global `owner` role (organization scope, rank 100), never a custom name/rank or client value.
3. After lock waits, current counter/state is re-read. An active tenant's 1→0 transition is rejected immediately, including demotion, suspension, removal and delete.
4. A deferrable final-state validator re-reads committed-state candidates rather than queued OLD/NEW snapshots. Active tenants require at least one actual active Owner; every tenant requires stored count to equal actual count.
5. Tenant activation and every counter-only change enqueue the same deferred validation. Suspended/archived tenants still require counter equality. Initial zero→one provisioning may be temporary inside one transaction but cannot commit at zero.
6. Trigger ordering and recursion are explicit. Counter-only tenant updates do not emit organization-settings events or count as a new Owner transition. The design may not depend on accidental alphabetical trigger order.
7. Owner promotion/demotion performs the branch-link cleanup in §5 and appends its audit atomically. Transfer promotes first and optionally demotes second in the same transaction.
8. READ COMMITTED waiters re-read after the tenant lock. Higher-isolation serialization/deadlock failures require bounded full-transaction retries with fresh authorization; retry counts and timing budgets remain S08 blockers.

At two active Owners, concurrent exits can permit at most one success. At one active Owner, every competing exit must fail and the final actual/stored count must remain one. Tests OWN-01–OWN-13, NEW-P2-06/07 and PERF-02 apply; primitive P2 races are mandatory before P3 exists.

Membership offboarding uses status, not hard deletion. Auth/profile deletion remains blocked by any retained membership through P1 RESTRICT. Status-based Owner count is not recalculated from verification state; sole-Owner recovery and legal erasure are separate future runbooks, not implicit platform escalation.

## 7. Invitation and membership security — future P3 only

P2 supplies read and invariant primitives; it does not expose token or membership workflows.

- Generate at least 32 cryptographically random bytes with a reviewed CSPRNG, return base64url once after commit and store only lowercase SHA-256 hex. P1 hash-format validation does not prove entropy.
- Use a URL fragment for the future copyable link, clear it after hydration, submit over authenticated HTTPS and never persist the token in browser storage, analytics, errors or audit. Transactional email remains deferred.
- P3 explicitly derives `created_at` and `expires_at` from one authoritative server insertion timestamp after waits; expiry is exactly seven days later. P1's `now()` default is transaction-start semantics and is not the approved P3 insertion anchor.
- Failed acceptance of an expired token makes no persistent invitation or audit change. A successful replacement creation atomically marks matching elapsed pending rows expired before inserting the new pending row; uniqueness still handles races.
- Every accepted-token replay, including same-user replay, receives the generic unavailable response. A narrow same-user completed-result retry is not approved.
- Acceptance hashes the raw token privately, locks in the common order, re-reads current time/state after waits and requires verified case-insensitive email match, active tenant/branches, valid role and continuing inviter permission/rank/full branch authority.
- Acceptance creates exact membership/grants and accepted fields atomically. Existing active/invited/suspended/removed memberships reject; no automatic reactivation or role upgrade occurs.
- Organization creation retry semantics are not yet implementable: P1 stores creator/key but no immutable canonical original-request proof. AD10/S05 requires either a separately reviewed proof/canonicalization design or a narrower approved retry contract before LIFE-02/NEW-P3-02 can pass.

All token failures use one generic unavailable response without token, hash, tenant, role or inviter disclosure.

## 8. Audit architecture

P2 audit triggers cover only installed row transitions. Domain triggers are the sole producer of each row-transition event; RPCs may append only separately enumerated semantic events and must never repeat the same row event.

- Exactly one row-transition event is produced per changed row by its domain trigger. Counter-only tenant updates emit no organization-settings event. “Role” audit tests mean role assignment, not disabled custom-role management.
- Exact action/entity strings, event-specific cardinality and metadata allowlists must be included in the final P2 SQL review. S01 approves the producer model but does not invent those values; their absence blocks SQL preparation, not this documentary review.
- Actor derives from trusted current identity. System events may use null actor only with controlled metadata. Correlation/IP values come only from trusted deployment context; null is acceptable.
- Metadata never includes raw tokens/hashes, Auth secrets, full settings documents, arbitrary request bodies or unnecessary PII. Sequence gaps after rollback are normal and do not prove missing atomicity.
- Private BEFORE UPDATE/DELETE and BEFORE TRUNCATE guards protect audit. Equivalent guards cover global roles, their mappings and the permissions catalog. No application-role audit INSERT or identity-sequence privilege exists.
- Failed business transactions leave no success audit. Denied-attempt telemetry is not claimed and may not become a public audit writer.

Relevant tests: AUD-01–AUD-07, NEW-P2-05/11 and GAP-10.

## 9. Platform Admin isolation

P2 `p2_is_platform_admin()` answers only verified current-user status; `platform_admins_select_self` uses the same verification gate. Neither grants tenant access, and no tenant helper calls Platform Admin as an alternative authority.

P9 alone must design and approve resolution of `logicaltechzoneofficial@gmail.com` to the authenticated immutable UUID after current email ownership verification, controlled insert/delete grant/revoke, repeat-bootstrap behavior, explicit operation projections and Auth-cascade audit behavior. No email comparison in frontend code or tenant RPC can confer authority. Exact P9 cascade/revocation evidence remains future and blocked.

Relevant tests: PLT-01–PLT-06 and NEW-P2-12/NEW-P9-01.

## 10. P1 V3 dependencies and unresolved prerequisites

| Item | Approved treatment | Gate |
|---|---|---|
| P1 unapplied | Review/apply exact V3 only after separate execution approval; no documentary correction edits it | P1 execution and acceptance |
| Profile wording in P1 header/README | Later owner-approved D1/D4 phase ownership is P4; preserve P1 files unchanged and record the documentary discrepancy | Separate P1 comment clarification only if requested |
| Owner/branch/audit enforcement | Add coordinated P2 guards/private writers after exact SQL review | P2 |
| Tenant/profile/invitation privacy | P2 safe columns and self/scoped reads; settings/directory RPCs remain P3 | P2/P3 |
| Definer ownership/Auth representation | Fresh hosted read-only feasibility and authoritative current-user verification-field preflight | Before P2 SQL |
| Branch/history | Status-aware final-state validators and current-authority helpers per §5 | P2; cleanup transitions P3 |
| Audit values | Exact event/action/metadata ledger still required; producer and immutability model approved | Before P2 SQL |
| Country/currency | P1 checks format only; select/version an authoritative validation source | Before public P3 onboarding |
| Settings | No key/type is approved; direct column denied and settings RPC remains disabled until owner supplies allowlist | P3 blocker |
| Retry/replay/expiry | Replay/failed-expiry/insertion-anchor rules approved; organization original-request proof remains unresolved | P3 blocker |
| Abuse/performance | Controls must cover direct RPC and wrappers; numeric limits, input bounds, workloads, latency and retry budgets are not supplied | P2 measurement/P3 exposure blocker |
| Recovery/erasure | Status-count invariant retained; recovery and legal erasure runbooks separate | P4/future |
| Platform lifecycle | P2 verified self/non-bypass only; P9 lifecycle and cascade audit future | P9 |

No new table, column, service grant or Auth change is implied by this corrected architecture.

## 11. Threats and trade-offs

- **Definer recursion/blast radius:** narrow booleans reduce disclosure, but ownership and effective RLS behavior remain a hard preflight gate.
- **Helper performance:** realistic permitted/denied plans and primitive stress are mandatory in P2; no universal index-scan promise is made for small fixtures and no numeric budget is invented.
- **Strict inactive-self denial:** prevents tenant metadata leakage but requires a future minimal P4 status projection if product UX needs it.
- **Historical branch retention:** preserves audit/provenance while current helpers deny inactive links; exact offboarding cleanup remains P3 work.
- **Strict replay rejection:** simplifies secrecy but a lost acceptance response cannot be recovered by replay; any alternative needs a new decision.
- **Audit immutability:** UPDATE/DELETE/TRUNCATE guards reduce mistakes but do not make a trusted database operator tamper-proof.
- **Public onboarding delay:** controlled P3 fixtures can prove workflows, but real signup-to-onboarding acceptance waits for P4/P5.

## 12. Release gates

P2 completion requires accepted P1, the exact approved P2 SQL, all P2-scoped tests and mandatory earlier-phase subsets, relevant P2 deployment/plan/primitive-stress evidence, and owner review of actual results. P3/P4/P9 parent tests remain blocked—not waived, failed or passed—and cannot be used as P2 completion claims.

P3 exposure additionally requires accepted P2, separate P3 approval, authoritative country/currency validation, exact settings/retry/offboarding contracts where used, durable direct-RPC/wrapper abuse controls and approved numeric limits/budgets. Public self-service onboarding also waits for P4/P5. P9 remains independently gated.

## 13. Change history and traceability

**Corrected V1:** resolved F01–F20 within D1 by applying AD01–AD12 and S01–S10; removed P2 profile writes; corrected equal-rank delegation; defined ten P2 facades; separated branch history from current authority; completed Owner trigger requirements; established single-producer audit and TRUNCATE coverage; corrected replay/expiry/insertion timing; limited P2 release to P2 evidence; retained unresolved hosted/business parameters as blockers.

Original D1 remains unchanged. This document is ready for documentary review only, not SQL preparation or execution.
