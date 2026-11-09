# Logical Education ERP — M1 P2 RLS Policy Matrix

**Document:** D2_Corrected_V1  
**Status:** corrected planning document; proposed policies/grants only; none has been created.  
**Baseline:** original D2 SHA-256 `50a4198cb34c900d87046020f21a17ae01dbdbad58cc6214fca5a6200616f909`; P1 V3 is unapplied. P1 V3 **specifies** RLS enabled with zero policies on all twelve tables; this is a source property, not a live observation.  
**Decisions:** AD01–AD12 and S01–S10 recommendations approved by the project owner. All runtime tests remain NOT EXECUTED.

## 1. Matrix notation and common gates

- **Verified:** private current-user Auth-row lookup returns current verified-email state; editable metadata and browser claims are not accepted.
- **Active member:** verified caller, active tenant, active membership and valid global/same-tenant custom role. Branch-scope callers additionally need at least one active assigned branch for active operational use.
- **Organization permission:** `p2_has_org_permission(tenant,key)`; organization scope only.
- **Tenant permission:** `p2_has_tenant_permission(tenant,key)`; organization roles use their mapping directly, while branch roles may use only explicitly mapped tenant-level capabilities and must retain an active assignment.
- **Branch permission:** `p2_has_branch_permission(tenant,branch,key)`; active same-tenant branch plus organization permission or explicit active branch assignment and permission.
- **Visible member/invitation:** D4 exact current-caller helper semantics. Self membership is not an unguarded `OR auth.uid()` arm.
- **No direct:** no authenticated table/column DML grant and no RLS write policy. A separately approved trusted routine may perform a future operation after its own checks.
- **Private only:** no PUBLIC/anon/authenticated/service_role EXECUTE; trigger/internal invocation only.
- **No anonymous access:** no anon policy or grant is proposed.

Only profile self-read is non-tenant and may use `id = auth.uid()` without tenant membership. Platform self-read/status requires verified identity. Every tenant-bearing self path fails closed for unverified, inactive tenant or inactive/unusable membership. Suspended/archived tenant access and inactive self-membership visibility have no P2 exception.

## 2. Complete twelve-table matrix

| Table | SELECT | INSERT | UPDATE | DELETE | TRUNCATE | Trusted/future path |
|---|---|---|---|---|---|---|
| **tenants** | `tenants_select_member`; active usable member with `p2_has_tenant_permission(id,'organization.view')`. Eleven safe columns only: `id`, `name`, `slug`, `country`, `timezone`, `default_currency`, `contact_email`, `contact_phone`, `status`, `created_at`, `updated_at`. | No direct | No direct | No direct | No direct | P3 organization create/update and separately approved settings RPCs. Counter updates are private P2 invariant maintenance; status workflows separately reviewed. |
| **branches** | `branches_select_scoped`; `p2_has_branch_permission(tenant_id,id,'branch.view')`. Only active same-tenant branches are visible; no inactive-history exception in P2. | No direct | No direct | No direct | No direct | P3 create/update/status. `branch.delete` remains reserved and disabled. |
| **profiles** | `profiles_select_self`; `id = auth.uid()` only. Co-member direct reads denied. | No direct in P2 | **No direct in P2**; no self-update policy or column grant | No direct | No direct | P4 Auth-derived initialization and exactly one later-approved self-update path; P3 safe directory projection only. |
| **roles** | `roles_select_catalog`; `p2_can_view_role(id)`. Global roles require `role.view` in at least one active usable tenant; custom roles require `role.view` in their exact tenant. | No direct | No direct | No direct | No direct; private system-catalog guard also covers global rows | Reviewed migrations only for global catalog; custom-role management remains disabled. |
| **permissions** | `permissions_select_catalog`; `p2_has_any_permission('role.view')`. | No direct | No direct | No direct | No direct; private catalog guard covers all permission rows | Reviewed migration-controlled catalog only. |
| **role_permissions** | `role_permissions_select_scoped`; `p2_can_view_role(role_id)`. Custom mappings inherit exact role tenancy. | No direct | No direct | No direct | No direct for application; private guard covers global system mappings | Reviewed global catalog migrations; custom-role mapping workflow disabled. |
| **memberships** | `memberships_select_scoped`; `p2_can_view_membership(id)`, including verified active context for self. | No direct | No direct | No direct | No direct | P3 acceptance/membership/Owner RPCs; P2 invariant triggers. Offboarding is status-based. |
| **membership_branches** | `membership_branches_select_scoped`; parent membership visible AND referenced branch visible with `branch.view`. No unshared assignment leakage. | No direct | No direct | No direct | No direct | P3 atomic assignment/acceptance/offboarding; P2 final-state validators. |
| **invitations** | `invitations_select_scoped`; `p2_can_view_invitation(id)`. P1 safe columns only; invited email/token possession alone grants no read. | No direct | No direct | No direct | No direct | P3 create/revoke/expire/accept; P1 immutable identity terms remain. |
| **invitation_branches** | `invitation_branches_select_scoped`; parent invitation visible AND referenced branch visible with `branch.view`. Complete offered-branch coverage is required for branch-actor parent visibility. | No direct | No direct | No direct | No direct | Created atomically by future P3 invitation workflow; historical links have no independent token-based read. |
| **audit_logs** | `audit_logs_select_organization`; non-null tenant plus `p2_has_org_permission(tenant_id,'audit.view')`. No branch-only or platform-wide read. | No direct; private writer only | No direct plus private immutable guard | No direct plus private immutable guard | No direct plus private BEFORE TRUNCATE guard | P2 private append-only domain/semantic writers; no application sequence privilege. |
| **platform_admins** | `platform_admins_select_self`; verified current user AND `user_id = auth.uid()`. No enumeration or tenant override. | No direct | No direct | No direct | No direct | P9 controlled verified-UUID insert/delete lifecycle only; table remains unbootstrapped in P2. |

## 3. Exact proposed policy inventory

The following are semantic predicates, not executable SQL. Helper signatures and truth tables are normative in D4 §2.

| Policy | Command / role | Predicate and privacy requirement |
|---|---|---|
| `tenants_select_member` | SELECT / authenticated | `p2_has_tenant_permission(id,'organization.view')`; safe eleven-column ACL required |
| `branches_select_scoped` | SELECT / authenticated | `p2_has_branch_permission(tenant_id,id,'branch.view')` |
| `profiles_select_self` | SELECT / authenticated | `id = auth.uid()`; no co-member arm and no P2 UPDATE policy |
| `roles_select_catalog` | SELECT / authenticated | `p2_can_view_role(id)` |
| `permissions_select_catalog` | SELECT / authenticated | `p2_has_any_permission('role.view')` |
| `role_permissions_select_scoped` | SELECT / authenticated | `p2_can_view_role(role_id)` |
| `memberships_select_scoped` | SELECT / authenticated | `p2_can_view_membership(id)`; no independent self arm |
| `membership_branches_select_scoped` | SELECT / authenticated | `p2_can_view_membership(membership_id)` AND `p2_has_branch_permission(tenant_id,branch_id,'branch.view')` |
| `invitations_select_scoped` | SELECT / authenticated | `p2_can_view_invitation(id)`; safe-column ACL remains mandatory |
| `invitation_branches_select_scoped` | SELECT / authenticated | `p2_can_view_invitation(invitation_id)` AND `p2_has_branch_permission(tenant_id,branch_id,'branch.view')` |
| `audit_logs_select_organization` | SELECT / authenticated | `tenant_id IS NOT NULL` AND `p2_has_org_permission(tenant_id,'audit.view')` |
| `platform_admins_select_self` | SELECT / authenticated | `p2_current_user_is_verified()` AND `user_id = auth.uid()` |

There are exactly twelve proposed SELECT policies and zero proposed INSERT/UPDATE/DELETE policies. No `USING (true)`, client-selected actor, arbitrary-user helper or Platform Admin tenant bypass is permitted.

### Important visibility consequences

- A multi-tenant user's `role.view` in Tenant A does not expose Tenant B custom roles, mappings, members or invitations.
- `p2_has_any_permission` is only a global-catalog visibility facade. It evaluates active usable memberships and never authorizes a supplied tenant or branch.
- A branch actor viewing another membership sees only assignments on currently authorized shared branches, never that member's other assignments.
- Branch-actor invitation visibility requires the entire offered branch set to be inside current authorized active branches. Organization-role invitations are organization-only.
- Historical/offboarded rows may remain stored without remaining readable to inactive callers. Current authority and historical structure are distinct.

## 4. Required grant and execution changes in eventual P2 review SQL

These are design requirements, not executed grants:

1. Revoke P1 table-level authenticated SELECT on tenants and grant only the eleven listed columns. Never grant tenants `settings`, `created_by`, `creation_key` or `active_owner_count` to authenticated.
2. Preserve every other required P1 SELECT grant, especially the explicit invitation safe-column projection. Never replace it with table-level SELECT or expose `token_hash`.
3. Add **no** authenticated table/column INSERT, UPDATE, DELETE or TRUNCATE grant in P2. In particular, remove the original D2 proposal for five profile UPDATE columns; those belong to P4 after one path is selected.
4. Grant authenticated EXECUTE only on the ten exact P2 boolean facades in D4 §2, with full signatures and any required schema USAGE. Revoke PUBLIC, anon and service_role EXECUTE on every routine; additionally revoke authenticated on every private dependency, trigger, writer and invariant routine.
5. Do not rely on schema placement instead of ACLs. Inspect overloads, defaults, nested EXECUTE, schema/type privileges, ownership and inherited role capabilities.
6. Keep service_role table, column, sequence and application-function privileges at zero. Ordinary server functions use the authenticated user bearer token; narrow definer routines use separately reviewed owners.
7. Audit identity-sequence privileges remain private to the approved audit writer owner only. No application role receives audit INSERT or sequence usage.

## 5. Phase-tagged write-operation authorization matrix

| Operation | P2 direct client JWT | Trusted routine / phase | Core checks |
|---|---|---|---|
| Create/update organization | Deny | P3 | Verified initialized profile, exact fields, post-lock permission, Owner/audit atomicity; retry contract pending |
| Read/update settings | Deny | P3, disabled until AD09/S09 key/type allowlist exists | `settings.view`/`settings.update`, approved org-level keys only, atomic patch |
| Create/update/status branch | Deny | P3 | Exact permission, active assigned scope, fixed fields, last-active-assignment rejection or separately approved offboarding |
| Delete branch | Deny | Not enabled | Reserved permission is not implementation |
| Create/edit custom role/mappings | Deny | Not enabled | `role.manage` reserved; isolation policies do not enable management |
| Create/update own profile | Deny in P2 | P4 only | Auth-derived identity; one approved path; five safe fields; Light/Dark only; valid nullable last-tenant hint |
| Create/accept/revoke/expire invitation | Deny | P3 | Current inviter authority, strict-lower/Owner exception, full branches, token secrecy, expiry/replay contract |
| Change role/status/branches | Deny | P3 | `user.update`, hierarchy/subset, Owner locks/invariants, exact branch-set semantics and audit |
| Append audit | Deny | Private P2 | Fixed event producer, trusted actor/context, sanitized metadata, same transaction |
| Update/delete/truncate audit or system catalogs | Deny | No ordinary path | Private guards reject; reviewed maintenance is a trusted administrative exception only |
| Grant/revoke Platform Admin | Deny | P9 only | Verified exact UUID, independent platform authorization and audit; no email-string input |

## 6. Acceptance conditions and evidence boundary

Documentary acceptance of this matrix does not claim live security. After separately approved implementation, evidence must establish:

- exact twelve-policy inventory, commands, roles and predicates, with no unintended self/write arm (NEW-P2-01);
- effective table/column/sequence/function ACLs, inheritance and owners, including zero service_role privileges (ACL-01–ACL-06, NEW-P2-09/10);
- anonymous, unverified, inactive, cross-tenant and unassigned-branch denial with positive same-tenant/assigned controls (HLP-01–HLP-04, TEN-01, BR-01/03/04);
- self-only profiles and verified self-only platform status without enumeration (PRV-01, PLT-03, NEW-P2-12);
- custom role/mapping isolation and reserved-feature absence (RBAC-09–RBAC-12, NEW-P2-03/05);
- safe invitation and join-table visibility without token/email-based read or unshared assignment leakage (NEW-P2-04);
- organization-only audit read plus private UPDATE/DELETE/TRUNCATE protection (AUD-02–AUD-04, NEW-P2-11);
- query plans and realistic permitted/denied workloads measured against separately approved S08 budgets without removing predicates (PERF-01/02, NEW-DEP-04).

ACL denial, RLS empty results, policy rejection and RPC authorization errors must be distinguished. P3 workflow and P4 profile-write parent tests remain blocked and do not gate P2 completion except for their mandatory P2 subsets.

## 7. Change history

**Corrected V1:** changed live-sounding P1 wording to source wording (F14); removed P2 profile writes (AD01); replaced undefined helpers with exact D4 facades (AD02); gated all tenant-bearing self reads on verified active usable context (AD04/AD06); added exact twelve-policy inventory, TRUNCATE semantics, catalog/audit guards, signature-specific EXECUTE and schema requirements; preserved zero direct P2 DML and zero service_role privileges; separated P3/P4/P9 operations and tests.

Original D2 remains unchanged. This corrected matrix is ready for documentary review only.
