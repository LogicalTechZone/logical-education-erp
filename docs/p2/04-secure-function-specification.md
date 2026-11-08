# Logical Education ERP — M1 P2 Secure RPC and Server Function Specification

**Planning only.** Every routine below is proposed. None exists in P1 V3 except the four structural P1 trigger functions. No function has been created or called, and no server/application code has changed.

## 1. Execution architecture

### Ordinary requests

- Browser/server code uses the generated Supabase client and the authenticated user's bearer token through `requireSupabaseAuth` where a TanStack server wrapper is used.
- The database RPC repeats every identity, membership, permission, rank and branch check. TypeScript validation and UI hiding are never the security boundary.
- Ordinary SELECT uses RLS and the approved safe columns. No server route needs the service-role Admin client.
- P2 preserves zero direct `service_role` table, column, sequence and application-function privileges. A definer routine executes with its reviewed function owner's narrow capabilities; it is not a service-role DML path.

### Function hardening common to every routine

1. Fixed `search_path = ''`; fully qualified tables, types, operators/functions where necessary.
2. Explicit input types, length/range checks, null rejection and fixed allowlists. No dynamic SQL or caller-provided object names.
3. `SECURITY DEFINER` only where controlled lookup/mutation requires it. Read helpers are `STABLE`; state changers are `VOLATILE`.
4. Function owner is a trusted reviewed migration/security owner, ideally non-login; application roles have no ownership or role membership in it. Live ownership and `BYPASSRLS` attributes must be inspected.
5. Revoke default `PUBLIC` execution. Public policy helpers and approved user RPCs grant only `authenticated` EXECUTE; private triggers/writers revoke PUBLIC, anon, authenticated and service_role execution.
6. No arbitrary SQL, arbitrary audit-event endpoint, generic table mutation or caller-selected actor/user identity.
7. Return only documented safe fields. Database errors become stable public error codes; detailed internal logs exclude tokens, hashes, settings bodies and unnecessary PII.
8. One database RPC equals one transaction. A sequence of TanStack server calls is not a transaction and is forbidden for multi-row acceptance, Owner transfer or provisioning.
9. Mutation routines acquire locks in this order: **tenant → actor/target memberships in stable UUID order → invitation → branch/grant rows**. Re-read and reauthorize after waits. Use `clock_timestamp()` for expiry after a wait.
10. Successful mutations append their audit rows in the same transaction. Any failure rolls back data, Owner counter and audit together.

## 2. P2 authenticated boolean helpers

These helpers support policies and RPCs. They reveal only a boolean about the current caller, never arbitrary users' rows. Null/unverified identity returns false. They must not be used as the sole check after a mutation lock wait; the mutation routine revalidates current locked state.

| Proposed function | Inputs | Purpose and authorization logic | Privileges / failures |
|---|---|---|---|
| `p2_current_user_is_verified()` | none | Match `auth.uid()` to the current Auth account and return verified-email state. Actual Dev Auth/JWT representation requires preflight; no client metadata is trusted. | Authenticated EXECUTE only; false on null/missing/unverified. Returns no Auth fields. |
| `p2_is_active_member(p_tenant_id uuid)` | tenant | Current verified caller has active membership and active tenant. Global system role or same-tenant custom role required. | Authenticated EXECUTE; false on null, suspended/removed membership or inactive tenant. |
| `p2_has_org_permission(p_tenant_id uuid, p_permission_key text)` | tenant, permission | Active organization-scope membership in requested tenant with exact mapped permission. | Authenticated EXECUTE; false for branch role, foreign custom role, missing mapping or inactive tenant. |
| `p2_has_branch_permission(p_tenant_id uuid, p_branch_id uuid, p_permission_key text)` | tenant, branch, permission | Organization role with permission OR branch role with permission plus explicit same-tenant active branch assignment. | Authenticated EXECUTE; false for unassigned/inactive/foreign branch. Zero branch rows means no branch access. |
| `p2_has_any_permission(p_permission_key text)` | permission | Whether current verified caller holds the permission in at least one active tenant; used only for global catalog visibility, never tenant mutation. | Authenticated EXECUTE; no tenant data returned. |
| `p2_can_view_role(p_role_id uuid)` | role | Global system role visible with `role.view` in an active tenant; custom role requires `role.view` in its exact tenant. | Authenticated EXECUTE; handles global `tenant_id IS NULL` explicitly. |
| `p2_can_view_membership(p_membership_id uuid)` | target membership | Self, or same-tenant organization `user.view`, or branch `user.view` with at least one shared authorized branch. | Authenticated EXECUTE; branch users cannot enumerate organization-only members. |
| `p2_can_view_invitation(p_invitation_id uuid)` | invitation | Organization `user.view`, or branch `user.view` where the branch invitation is wholly inside the actor's authorized branch set. Organization-role invitations are organization-only. | Authenticated EXECUTE; invited email or token possession does not activate this read helper. |
| `p2_is_valid_last_tenant(p_tenant_id uuid)` | nullable tenant | True for null or an active tenant where the current caller is an active member. Used only for self-profile hint update. | Authenticated EXECUTE; does not grant tenant access by itself. |
| `p2_is_platform_admin()` | none | Current `auth.uid()` exists in `platform_admins`. Never substitutes for tenant checks and grants no cross-tenant P2 policy. | Authenticated EXECUTE; false when null/absent. No bootstrap or arbitrary-user parameter. |

### Helper consistency and performance

- Authorization helpers use current database role/permission records, not custom JWT role claims.
- A helper owner subject to the same RLS would recurse; the live owner must have the deliberately reviewed lookup capability. This trusted read path must not be exposed as a general row-returning function.
- Existing P1 indexes support tenant/user/status, role and branch lookups. Query-plan tests are required; caching authorization in browser or process memory is not permitted.

## 3. P2 private enforcement routines

These are trigger/internal functions, not callable API endpoints. `EXECUTE` is revoked from PUBLIC, anon, authenticated and service_role. Trigger firing continues under normal PostgreSQL trigger semantics.

| Proposed routine | Trigger/inputs | Purpose and transaction rules | Required privileges / failure behavior |
|---|---|---|---|
| `p2_guard_system_catalog` | Before insert/update/delete affecting global system roles or their mappings | Keep all five system-role records and global mappings immutable to application and definer paths, including names/descriptions and mapping changes. Future catalog migrations deliberately manage the guard under review. | Private trigger owner. Reject unauthorized catalog mutation; no client bypass flag. |
| `p2_validate_branch_sets` | Deferrable constraint trigger on memberships, membership_branches, invitations, invitation_branches | At commit: organization role has zero branch links; branch role has at least one; every link is same-tenant and active where operational access requires it. | Private trigger owner. Reject entire transaction on empty branch-role set, organization-role links, foreign/inactive required branch or scope mismatch. |
| `p2_sync_active_owner` | Membership insert, role/status update and delete | Lock parent tenant, compute OLD/NEW active-global-Owner delta, update `active_owner_count` atomically. Never accept a counter input. | Private trigger owner only. All owner-affecting writers must use the same trigger mechanism; no RPC-side parallel increments. |
| `p2_prevent_last_owner_loss` | Before owner-removing membership transition | After tenant lock, reject an active tenant's 1→0 Owner transition, including demotion, suspension, removal and delete. | Private trigger owner. Reject with stable `LAST_ACTIVE_OWNER_REQUIRED`; no partial status/counter/audit change. |
| `p2_check_owner_invariant` | Deferrable constraint trigger on affected tenants/memberships | At commit, lock/re-read and compare actual active Owner count to stored counter; active tenant requires count ≥1. Tenant activation also fires this validation. | Private trigger owner. Reject drift or zero-Owner active tenant. Deferred checking allows atomic tenant + first Owner provisioning. |
| `p2_guard_audit_immutable` | Before audit update/delete | Reject every update/delete, including privileged application mistakes. | Private trigger owner; no application exception. Retention/purge requires separate future design. |
| `p2_append_audit` | Internal fixed arguments from approved triggers/RPCs | Append one allowlisted event with derived tenant/actor/time and sanitized metadata. | Private definer insert plus identity-sequence use only; no application EXECUTE. Null actor only for controlled system events. |
| `p2_audit_<domain>` | After approved tenant/branch/membership/invitation/catalog transitions | Build fixed action names and safe old/new metadata. Owner role/status changes get dedicated events. | Private only. Same transaction as business mutation; rollback removes audit. Never include token/hash, full settings or arbitrary request JSON. |

### Owner trigger protocol

An active Owner is an active membership assigned the approved global system role `owner` with organization scope and rank 100. Custom names, rank or permissions never qualify. The counter mechanism covers insert, role change, status change and delete. Tenant reactivation and every privileged writer must participate in the same locking/invariant protocol.

At `READ COMMITTED`, a waiter must re-read state after obtaining the tenant lock. Deferred validation is defense-in-depth, not a replacement for immediate checks and serialization. `active_owner_count` is never accepted from a client or returned through ordinary tenant SELECT.

## 4. P3 organization and settings RPCs

These workflows consume P2 controls but are not implemented by approving P2.

### `create_organization`

- **Inputs:** `creation_key`, name, slug, country, timezone, default currency and approved contact fields. No creator, status, Owner counter or role ID input.
- **Authentication:** verified current user with an initialized profile.
- **Authorization:** new-user provisioning permission is the controlled ability to create one's own organization; no existing tenant membership is required. Authoritative country/currency validation must be completed first.
- **Tenant validation:** derive `created_by = auth.uid()`; resolve the immutable global Owner role internally.
- **Transaction:** validate idempotent retry; insert tenant, insert first active Owner membership, fire counter/deferred invariant checks and append audit atomically.
- **Privileges:** authenticated EXECUTE on this one RPC; private definer writes. No general tenant/membership grants.
- **Failure:** duplicate slug/key, invalid catalog values, missing profile or any invariant failure rolls back all rows. A retry with an existing creation key succeeds only if creator and original payload match; never return another creator's organization.

### `update_organization`

- **Inputs:** tenant ID and allowlisted organization/contact fields. Exclude ID, slug, creator, creation key, status, counter and timestamps.
- **Authentication/authorization:** verified caller; active same-tenant organization role with `organization.update`.
- **Transaction:** lock tenant, reauthorize, apply only supplied approved fields and audit changed-field names/safe values.
- **Failure:** foreign/inactive tenant, insufficient permission or validation failure leaves all unchanged.

### `get_organization_settings`

- **Inputs:** tenant ID.
- **Authorization:** active same-tenant `settings.view`.
- **Returns:** explicit allowlisted settings keys and organization fields, not an arbitrary full row. Direct tenant SELECT excludes `settings` entirely.
- **Privileges/transaction:** authenticated EXECUTE; read-only definer or safe view; no writes. Missing permission returns no settings.

### `update_organization_settings`

- **Inputs:** tenant ID and an allowlisted settings patch, not arbitrary nested replacement.
- **Authorization:** active same-tenant organization role with `settings.update`.
- **Transaction:** lock/reauthorize, validate keys/types, update and audit only changed keys; secret values are not logged.
- **Failure:** unknown key, wrong type, Branch Manager without `settings.update`, or foreign tenant rejects the whole patch.

## 5. P3 branch and directory RPCs

### `create_branch`

- **Inputs:** tenant, name/code/address/contact/country/timezone; no tenant switching or status input beyond controlled default.
- **Authorization:** active organization role with `branch.create`.
- **Transaction:** lock/reauthorize tenant, insert and audit. Unique `(tenant_id,code)` resolves concurrent duplicates.
- **Failures:** foreign tenant, Branch Manager/Staff/Read Only, duplicate code or invalid fields; no partial row/audit.

### `update_branch`

- **Inputs:** tenant, branch ID and fixed editable contact/address/name fields.
- **Authorization:** organization `branch.update` for tenant branches or assigned-branch `branch.update` for Branch Manager.
- **Transaction:** tenant lock, branch lookup/lock, reauthorization, update and audit.
- **Failures:** unassigned, inactive or foreign branch denies; no status or identity mutation through this RPC.

### `set_branch_status`

- **Inputs:** tenant, branch ID, active/inactive target.
- **Authorization:** organization-scope `branch.update` only; branch managers cannot deactivate a branch through their ordinary update capability.
- **Transaction:** lock tenant/branch, revalidate, update status, and evaluate affected active branch memberships/invitations. No physical deletion.
- **Failures:** invalid status or attempt to leave invalid active branch assignments rejects unless the approved workflow explicitly offboards those assignments atomically. `branch.delete` remains unavailable.

### `get_member_directory`

- **Inputs:** tenant and optional branch filter/pagination.
- **Authorization:** `user.view`; organization actors see the tenant roster, branch actors only memberships sharing their authorized branches.
- **Returns:** membership ID, necessary user identifier, display name, avatar, role ID/name/scope/rank, membership status and only actor-visible branch assignments. Never return phone, last-tenant hint, Auth email verification data or full profile rows.
- **Failures/performance:** foreign tenant or missing permission denies; branch filter cannot broaden scope. Stable pagination and index/query-plan checks required.

## 6. P3 invitation RPCs

### `create_invitation`

- **Inputs:** tenant, email, role ID and branch ID array. No inviter user/membership, expiry, status, acceptance or hash input.
- **Authentication/authorization:** verified caller, active inviter membership derived from `auth.uid()`, active tenant and `user.invite`.
- **Delegation:** Owner may offer Owner; every non-Owner offers only strictly lower rank. Target role is global system or same-tenant custom; custom target permissions must be within the actor's delegable authority. Branch Manager offers only branch-scoped Staff/Read Only or qualifying lower custom roles.
- **Branch validation:** organization role => empty list; branch role => nonempty distinct active same-tenant list wholly within inviter authority.
- **Token:** generate at least 32 bytes with a reviewed CSPRNG (P1's available pgcrypto source may be used after live schema preflight), encode base64url, store only lowercase SHA-256 hex. Return the raw token once in the creation response. Never return it from any read RPC.
- **Transaction:** lock tenant and inviter membership; reauthorize; mark naturally expired matching pending rows expired; insert invitation and all branch rows; audit safe event; unique pending `(tenant,email)` handles races.
- **Failures:** duplicate live pending invite, rank escalation, any unauthorized branch, inactive tenant/branch or invalid email/hash causes full rollback. Copy-link delivery happens only after commit. Transactional email remains deferred.

### `revoke_invitation`

- **Inputs:** tenant and invitation ID; no status/actor input.
- **Authorization:** current `user.invite`, target rank within actor delegation ceiling and complete branch authority. Organization Admin cannot revoke an Owner invitation.
- **Transaction:** lock tenant, inviter/actor and invitation in common order; re-read pending/current expiry; transition pending to revoked and audit.
- **Failures:** accepted invitation, foreign tenant, lost branch authority or insufficient rank. Expired rows may be marked expired rather than revoked; no token data returned.

### `accept_invitation`

- **Inputs:** raw token only. No tenant, email, accepted user, role, branch or inviter input.
- **Authentication:** valid current user, initialized profile, current verified Auth email. Possession of token alone is insufficient.
- **Lookup:** hash the submitted token with the reviewed SHA-256 implementation; perform a private minimal hash lookup to discover invitation/tenant. Return one generic unavailable response for bad token, wrong email, revoked, expired or unauthorized acceptance.
- **Transaction/locks:** discover hash, then lock tenant → inviter/new or existing membership rows in stable order → invitation → branch rows. Re-read after every wait and use current time for expiry.
- **Reauthorization:** require pending and unexpired, matching verified email case-insensitively, active tenant/branches, valid role, and continuing inviter active membership, `user.invite`, rank and full branch authority. Never silently reduce scope.
- **Mutation:** insert active membership with `joined_at` and historical `invited_by` derived from canonical inviter membership; copy exact branch grants; set invitation accepted with `accepted_by = auth.uid()` and current timestamp; audit both events atomically.
- **Existing membership:** reject active, invited, suspended or removed conflicts; never upsert into a stronger role or automatically restore offboarded access. Reinstatement requires a separate authorized workflow.
- **Failures/races:** wrong/unverified email, invalid/expired/revoked/accepted token, stale inviter, foreign role/branch, membership conflict or invariant failure rolls back everything. Simultaneous accept/accept and accept/revoke serialize; only one permitted result commits.
- **Retry:** a retry may report the already-completed result only when the same accepting user and exact completed acceptance are proven; otherwise generic rejection. Exactly-once delivery or general idempotency is not claimed without durable storage.

## 7. P3 membership and Owner RPCs

### `update_membership`

- **Inputs:** tenant, target membership ID and an explicit desired role/status/branch-set change. No target user/tenant/creator/invited_by/counter input.
- **Authorization:** active same-tenant organization `user.update`; Branch Manager has no such permission. Actor must outrank the existing target and satisfy strict-lower delegation for a new non-Owner role. Only Owner manages Owner.
- **Transaction:** lock tenant then actor/target rows; re-read current state; validate role tenancy, rank/permission subset, branch containment and branch-set semantics; invoke Owner triggers; clear grants on removal as approved; audit atomically.
- **Failures:** self escalation, equal non-Owner peer management, Organization Admin changing Owner, cross-tenant role/branch, last-Owner loss or inactive required branch rejects all.

### `transfer_ownership`

- **Inputs:** tenant, target active membership ID and boolean `relinquish_caller`.
- **Authorization:** caller is current active Owner; target is active same-tenant member. No client role ID needed.
- **Transaction:** lock tenant and both memberships; promote target to the internal global Owner role first; if relinquishing, demote caller to Organization Admin second; synchronize counter and audit in one transaction.
- **Failures:** target foreign/inactive, caller not Owner or any invariant failure rolls back both transitions. The transaction never exposes a committed zero-Owner state.

### `remove_owner`

- **Inputs:** tenant and target Owner membership ID.
- **Authorization:** active Owner only, including self-removal only when another active Owner remains.
- **Transaction:** common locks, re-read actual active Owner count, set target status removed, clear branch grants if any, update counter and audit.
- **Failures:** last active Owner, Organization Admin caller, foreign target or concurrent losing request returns `LAST_ACTIVE_OWNER_REQUIRED`/authorization error with no changes.

### `replace_membership_branches`

- **Inputs:** tenant, target branch-role membership and complete desired branch set.
- **Authorization:** organization `user.update`, target hierarchy and every branch same-tenant/active. No partial per-row client inserts/deletes.
- **Transaction:** common locks, validate nonempty set and target branch scope, replace as one atomic operation, revalidate invitations whose continuing authority depends on affected actor branches, audit.
- **Failures:** empty set for active branch role, organization-role target, foreign/inactive branch or hierarchy violation rolls back all.

## 8. P4/P9 boundaries

- **P4 profile initialization:** a private Auth/profile lifecycle routine derives the profile ID from the new Auth user. It never creates tenant membership or platform authority. Email-verification UI and recovery remain P4; P2/P3 database checks still enforce verification.
- **Self profile update:** either the narrow direct column grants + self RLS in document 2 or a dedicated RPC, not both unnecessarily. Theme accepts only `light`/`dark`; last tenant is only a validated hint.
- **P9 Platform Admin:** no grant/revoke/bootstrap RPC is approved here. The future process resolves the confirmed email to the verified Auth UUID, checks separate platform authority and audits the action. Tenant roles never satisfy it.

## 9. TanStack server-wrapper contract

For each exposed workflow, a thin server function should:

1. validate input shape and call the authenticated context;
2. apply durable rate/abuse controls where required, especially token acceptance and invitation creation;
3. call exactly one transactional RPC for the state transition;
4. map stable database error codes to safe user-facing messages;
5. return only documented fields; raw invitation token appears only in successful create response;
6. avoid Admin/service-role clients and avoid logging raw request bodies;
7. derive request correlation/IP only from trusted deployment data, never spoofable client JSON.

P1 has no durable rate-limit/outbox/general idempotency tables. Serverless in-memory counters are not durable security controls. P3 must separately approve the storage/service used for abuse protection rather than claim it exists.

## 10. Required live privilege verification

After separately approved implementation, inspect and test:

- function owners, volatility, definer status, empty search paths and qualified references;
- EXECUTE ACLs including inherited PUBLIC defaults and service_role denials;
- zero service_role table/column/sequence privileges;
- safe tenant and invitation column projections;
- absence of general authenticated DML grants;
- no exposed private audit/Owner trigger routines;
- no service credentials in browser bundles or responses;
- actual RLS behavior under anon, verified/unverified authenticated and independent concurrent sessions.

These checks are planned, not executed or passed in this planning task.
