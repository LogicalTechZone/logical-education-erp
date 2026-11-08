# Logical Education ERP — M1 P2 Security Architecture Blueprint

**Status: planning only; not implemented or approved for execution.** This design is cross-checked against `docs/p1/database-foundation.review.sql` V3. P1 V3 remains unapplied. No application, database, Auth, migration, RLS, function or configuration change is part of this document.

## 1. Purpose and security boundary

P2 must turn the twelve deny-by-default P1 tables into a least-privilege authorization boundary without making tenant provisioning or business workflows usable prematurely. P2 owns:

- authenticated membership, permission, role and branch helpers;
- RLS policies and only the narrow object grants those policies require;
- custom-role visibility isolation;
- structural branch-scope validation;
- transaction-safe active-Owner counting and last-Owner protection;
- append-only audit writers and audit immutability;
- the database authorization checks reused by later workflow RPCs.

P3 owns organization provisioning, branch management, invitation create/accept/revoke and membership-management workflows. P4 owns user-facing authentication/profile lifecycle. P9 alone owns Platform Admin bootstrap and cross-tenant platform operations. No future ERP module is enabled by this blueprint.

### Non-negotiable invariants

1. `auth.uid()` is the only ordinary end-user identity. Client user IDs, actor IDs, tenant claims, inviter IDs and `created_by` values are never authority.
2. A supplied `tenant_id` is a lookup key, not a trusted context. Every operation resolves the caller's active membership from `memberships.user_id = auth.uid()` and the requested tenant.
3. System roles are global (`roles.tenant_id IS NULL`). Custom roles must belong to the target tenant. P1's role-assignment trigger remains a structural backstop; P2 repeats authorization checks before every grant.
4. Permission keys authorize capabilities. Rank controls role delegation and management hierarchy; rank alone never grants a capability.
5. Branch roles require explicit `membership_branches` rows. Organization roles may act across their tenant only when their permission catalog allows it.
6. No client-supplied tenant ID on a row can relocate it. P1 immutable identity triggers and composite foreign keys remain in force.
7. Ordinary operations use the authenticated user JWT and RLS. The server service credential is not an alternative authorization path.
8. `service_role` retains zero direct P1 table, column and sequence grants. P2 does not add any. Trusted database routines run under a controlled function owner, not by exposing service credentials.
9. Unverified users receive no tenant access. Authentication/profile screens may handle their own account lifecycle, but membership and invitation acceptance require a verified Auth email.
10. Platform authority is tenant-independent. Owner and Organization Admin never imply Platform Admin.

## 2. Trusted tenant context

The effective context is resolved in this order:

1. Require a valid server-verified Supabase JWT and non-null `auth.uid()`.
2. Require the matching `auth.users` account to have a verified email. P2 must verify the actual Dev JWT/Auth representation before choosing the implementation; a boolean helper may read only the current account's verification state and must never expose Auth rows.
3. Resolve the caller's membership by `(auth.uid(), requested_tenant_id)`. Require `memberships.status = 'active'` and `tenants.status = 'active'` for normal tenant operations.
4. Resolve the role and its permission keys. Accept either the immutable global system role or a custom role whose `tenant_id` equals the requested tenant.
5. For an organization-scoped role, evaluate organization permissions directly. For a branch-scoped role, require an active, same-tenant branch and an explicit `membership_branches` assignment.
6. Derive actor, creator, inviter and acceptance identity inside the database routine. Ignore or reject any conflicting client identity fields.

`profiles.last_tenant_id` is only a navigation hint. Updating it does not grant access and must pass the same active-membership check. Suspended and archived tenants fail closed for ordinary P2 access; any future read-only suspended-tenant experience needs separate approval rather than an implicit exception.

## 3. Helper and policy architecture

P2 introduces narrow, `STABLE`, boolean `SECURITY DEFINER` helpers for policy evaluation. They read only the rows needed to answer the current caller's authorization question and return no table contents. Required helper behavior is specified in document 4.

All helpers and privileged routines must:

- use a fixed empty `search_path` and fully qualified object references;
- contain no dynamic SQL and no caller-controlled identifiers;
- treat null identity, tenant, role or branch inputs as denial;
- avoid writing state in read helpers;
- use the existing P1 indexes for membership, role, branch and permission lookups;
- be owned only by the reviewed migration/function owner;
- revoke `EXECUTE` from `PUBLIC`, `anon` and `service_role`;
- grant `EXECUTE` only to `authenticated` where a policy or approved RPC needs it;
- never set `row_security = off` or expose service credentials.

Private trigger, audit and mutation routines revoke execution from every application role. Trigger execution does not require callers to invoke the trigger function directly.

The definer owner is trusted to read through RLS for helper evaluation, preventing recursive membership-policy evaluation. P2 must verify live function ownership and role attributes. RLS does not constrain a table owner or a `BYPASSRLS` role; application roles must never own these tables. `FORCE RLS` is not a substitute for ownership separation and is not added blindly because it can reintroduce helper recursion.

## 4. Table access model

Document 2 is the authoritative operation-by-operation matrix. The overall model is:

- authenticated users receive row-filtered read access only where needed;
- tenants use a safe-column projection excluding `settings`, `created_by`, `creation_key` and `active_owner_count`; settings require a separate `settings.view` RPC/projection;
- profiles additionally permit a narrow self-update of approved columns;
- invitations retain P1's safe-column-only read grant, excluding `token_hash`;
- no direct tenant, branch, role, membership, invitation, audit or platform-admin writes;
- all business mutations use reviewed, transactional database routines with explicit authorization;
- audit rows are inserted only by private trigger-controlled writers and can never be updated or deleted through application paths;
- Platform Admin rows are self-visible only in P2 and remain empty until P9.

P2 adds no direct `INSERT`, `UPDATE`, `DELETE` or `TRUNCATE` privilege for authenticated users except the explicitly enumerated self-profile column update. RLS policies are not a substitute for object grants, and grants are not a substitute for RLS.

## 5. Role and branch authorization

Document 3 preserves P1's five roles, fourteen permissions and thirty-seven mappings. `branch.delete` and `role.manage` remain reserved and do not enable UI or RPC features in M1.

### Delegation rules

- Owner may grant any system role, including Owner, within the same tenant.
- Organization Admin may grant Organization Admin or lower, never Owner.
- Branch Manager may grant only lower-ranked branch roles (`staff` and `read_only`) within every branch assigned to the invitation/membership.
- Staff and Read Only have no invitation or membership-management capability.
- Custom roles follow their scope, rank and actual mappings. Organization Admin can delegate only a custom role ranked strictly below 80; only Owner can delegate ranks of 80 or higher.
- Every non-Owner may delegate only a strictly lower rank. Thus an Organization Admin cannot invite or assign another Organization Admin. Managing an existing equal non-Owner peer is also denied. A distinct active Owner may manage another Owner subject to the last-Owner invariant. Self role/status changes use dedicated guarded workflows and cannot bypass those rules.

### Branch rules

- An organization role needs no `membership_branches` rows; its explicit permissions apply tenant-wide.
- A branch role must have at least one active assigned branch, and must not access an unassigned branch.
- A branch invitation must contain at least one branch; an organization invitation/membership must contain none.
- Every invited/assigned branch must be active, same-tenant and inside the inviter/manager's current authority.
- Continuing inviter authority is checked again at acceptance. If authority has narrowed, acceptance fails; the system never silently reduces the offered scope.

P2 deferred validation triggers should defend the branch-presence rules against future internal coding errors. P1 V3 does not currently enforce non-empty branch sets for branch roles or empty branch sets for organization roles.

## 6. Owner integrity and concurrency

P1's `active_owner_count` is storage only. P2 must install all of the following together; none is sufficient alone:

1. **Tenant-row serialization:** every insert, role/status update or delete that can add/remove an active Owner first locks the parent tenant row `FOR UPDATE`.
2. **Atomic counter maintenance:** a private trigger calculates old/new active-Owner deltas and updates `active_owner_count` in the same transaction. Callers never supply or directly update the counter.
3. **Immediate last-Owner rejection:** a transaction that would reduce an active tenant from one active Owner to zero fails before commit.
4. **Deferred invariant validation:** a deferrable constraint trigger re-checks at commit that each affected active tenant has at least one actual active Owner and that the actual count equals the stored counter. Deferred validation permits P3 to create a tenant and its first Owner atomically.
5. **Deterministic member locking:** multi-member operations lock target membership rows in a stable order after the tenant lock to reduce deadlocks.
6. **Audit in the same transaction:** Owner changes and their actor/target metadata commit or roll back with the mutation.

At `READ COMMITTED`, a second concurrent transaction waits on the tenant lock and then re-reads the committed counter/state before applying its delta. Thus two Owners cannot concurrently remove themselves and both succeed. Serializable isolation may be used by workflow wrappers, but correctness must not depend solely on the application selecting it.

### Safe workflows

- **Add Owner / transfer:** an active Owner promotes an existing active same-tenant member. If the caller also relinquishes ownership, promote the target first and demote the caller second in one transaction.
- **Remove/downgrade Owner:** only an active Owner can do so, and only when at least one other active Owner remains. An Organization Admin can never perform it.
- **Membership removal:** use `status = 'removed'`; do not hard-delete membership history. Branch grants are revoked atomically and pending invitations issued under revoked authority become unusable through continuing-authority checks.

## 7. Invitation and membership security

The P3 workflows are designed now but remain unimplemented:

- Generate at least 32 cryptographically random bytes outside the database or through a reviewed CSPRNG source. Return the base64url token once.
- Store only lowercase SHA-256 hex in `invitations.token_hash`; P1's 64-hex validation and unique constraint remain. Never store, select, audit or log the raw token.
- Put the raw token in the URL fragment of the future acceptance link so normal HTTP request logs do not receive it; the client submits it over HTTPS only during acceptance.
- Default expiry is exactly the P1 default of seven days. Custom durations are not assumed for M1.
- Enforce the partial unique pending `(tenant_id, email)` index. Before creating a replacement, atomically mark naturally expired pending rows as `expired`; otherwise time-expired rows still occupying the `pending` status would block re-invitation.
- Acceptance requires a verified Auth email matching the invitation email case-insensitively, an active tenant, a pending unexpired invitation and continuing inviter authority.
- Lock the invitation row `FOR UPDATE`, then re-check status and expiry. Two acceptances cannot both succeed.
- Create an active membership and branch grants atomically, derive `accepted_by`, `accepted_at`, `joined_at` and `invited_by` from verified state, and mark the invitation accepted in the same transaction.
- Do not auto-reactivate an existing suspended/removed membership through a public token. That requires a separately authorized administrative reactivation decision.
- Revocation and role/branch changes re-check current actor capability, target rank and branch scope. Token rotation means revoke and recreate because P1 makes the hash immutable.

All token failures return a generic invalid/unavailable response. Detailed audit metadata must never contain the raw token or token hash.

## 8. Audit architecture

P2 audit triggers cover organization, branch, membership, role assignment, invitation, Owner and permission-sensitive mutations. They write through private definer routines with fixed object references. Business mutation and audit insert are one transaction.

- `actor_id` comes from `auth.uid()`; system actions use a null actor plus controlled metadata identifying the system actor.
- Action/entity names come from fixed trigger or RPC constants, not arbitrary client strings.
- Metadata uses an allowlist per event: target IDs, old/new status, role ID, branch IDs, request/correlation ID and safe changed-field names.
- Never log invitation tokens/hashes, Auth secrets, full settings documents, phone/address payloads or arbitrary request bodies.
- `ip` is server-derived only; null is acceptable when no trusted value exists.
- A `BEFORE UPDATE OR DELETE` guard rejects every audit mutation, including mistakes by privileged internal routines. Application roles receive no audit write or sequence privileges.
- Audit reads require organization-scope `audit.view`. Current P1 mappings grant it only to Owner and Organization Admin. Branch-level audit filtering is not claimed because `audit_logs` has no `branch_id`.
- Failed attempts rolled back with their business transaction do not leave a success audit. A separate denied-attempt telemetry design is optional later and must not weaken transaction atomicity or create a public audit-write endpoint.

## 9. Platform Admin isolation

P2 may define a current-user boolean helper and a self-only read policy. It does not grant or bootstrap any Platform Admin. P9 must separately design and approve:

- resolution of `logicaltechzoneofficial@gmail.com` to the authenticated immutable UUID only after verifying ownership of that Auth email;
- controlled grant/revoke routines and auditing;
- explicit platform permission checks independent of tenant membership and rank;
- narrow cross-tenant operations and safe projections;
- tests proving tenant Owners/Admins cannot insert platform rows or invoke platform operations.

No email comparison in frontend code, tenant role mapping, invitation or organization RPC can confer platform authority.

## 10. P1 V3 gaps and dependencies

These are explicitly identified, not silently patched:

| Gap or dependency | Proposed treatment | Phase/approval |
|---|---|---|
| Owner counter and minimum-one invariant are unenforced | Add coordinated tenant-locking, counter and deferred validation triggers | P2, separately approved migration |
| Branch-role non-empty and organization-role empty branch sets are not structural | Add deferred validation triggers plus RPC checks | P2 |
| Audit rows lack immutability and controlled writers | Add private audit triggers/writers and update/delete guard | P2 |
| Tenant table SELECT would expose the full settings JSON and internal fields to every member | Replace it with safe-column SELECT; settings require `settings.view` and a safe RPC projection | P2 privilege design |
| Profile rows contain phone and last-tenant hint; broad co-member SELECT would expose them | Keep direct profile SELECT self-only; use a safe directory RPC/projection | P2 policy; P3 directory |
| System-role display fields and global mappings are protected by ACLs but not complete privileged-writer immutability guards | Add P2 catalog guards for application/definer paths; future reviewed migrations may deliberately change the catalog | P2 |
| Audit rows have no branch ID | Restrict audit reads to organization scope; do not pretend branch filtering is possible | P2; schema change only if future branch audit is requested |
| Time-expired invitations remain `pending` until transitioned | Lazily expire inside create/accept workflows under row locks | P3; no schema change |
| Existing membership conflicts with invitation acceptance | Reject safely; no automatic reactivation | P3 |
| Verified-email representation needs live verification | Inspect Dev Auth/JWT behavior before coding the boolean helper | P2 preflight |
| Tenant/Owner bootstrap cannot pass an immediate zero-Owner rule | Use deferred invariant validation and one atomic provisioning transaction | P2 trigger design; P3 provisioning |
| Country/currency checks are format-only | Authoritative catalog validation remains an onboarding prerequisite | Before P3 onboarding |
| Generic request idempotency is not schema-backed | Only organization creation has `creation_key`; other retries are state-checked, not claimed exactly-once | Later review if required |
| No durable invitation rate-limit, delivery/outbox or general workflow-idempotency storage exists | Server wrappers must not claim durable abuse controls from in-memory state; approve storage or an external control before exposed P3 endpoints rely on it | P3 prerequisite/decision |
| Platform operations are unspecified and unauthorized | No bootstrap or cross-tenant platform RPC | P9 |

No new table or column is required for the core P2 design. Any later decision to add one requires a new reviewed migration; this blueprint does not create it.

## 11. Threats and trade-offs

- **Helper recursion:** avoided by controlled definer ownership, but this makes ownership and fixed paths critical live checks.
- **Helper performance:** boolean lookups may execute per row. P1 indexes support them; query plans and realistic-volume tests are required before declaring performance acceptable.
- **Definer blast radius:** narrow boolean helpers and fixed-command workflow RPCs reduce it. No general-purpose SQL executor or arbitrary table mutation function is permitted.
- **Global role visibility:** restricted to members with `role.view`; invitation acceptance uses a safe RPC rather than opening catalog reads to anonymous users.
- **Profile privacy:** self-only direct reads are stricter but require a dedicated directory projection for member lists.
- **Tenant suspension:** fail-closed is simple and safe but means tenant users cannot self-resolve suspension; P9 support workflows must handle it later.
- **Audit denial events:** same-transaction auditing records successful changes, not every rejected attempt. Security monitoring may require a separate, rate-limited design later.
- **Invitation authority revalidation:** safer than honoring stale grants, but a legitimate invite becomes unavailable if the inviter loses scope; an authorized Owner/Admin must reissue it.

## 12. Release gates

P2 is not complete merely because policies compile. Completion requires the full test plan in document 5, including two-session Owner races, direct PostgREST/JWT tests, token-hash privilege checks, helper ownership/path/ACL inspection, audit immutability and counter reconciliation. P1 must first be applied, verified and reviewed. P2 implementation then requires its own explicit approval and final SQL review. P3 remains separately gated.
