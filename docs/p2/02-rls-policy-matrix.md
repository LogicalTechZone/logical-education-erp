# Logical Education ERP — M1 P2 RLS Policy Matrix

**Planning only.** All policies below are proposed, not created. P1 V3 is unapplied and currently has RLS enabled with zero policies on all twelve tables. `authenticated` has SELECT-only grants (safe columns only for invitations); `service_role` has no table or sequence privileges.

## 1. Matrix notation

- **Self:** `id/user_id = auth.uid()` as applicable.
- **Active member:** verified caller, active membership, active tenant.
- **Org permission:** active organization-scope membership with the named permission.
- **Branch permission:** either an authorized organization role or an active branch-role membership explicitly assigned to that same active branch.
- **Visible member:** self, an organization actor with `user.view`, or a branch actor with `user.view` sharing at least one authorized branch with the target.
- **Visible invitation:** an organization actor with `user.view`, or a branch actor with `user.view` whose authorized branches cover the invitation scope; organization-role invitations are organization-only.
- **No direct:** no authenticated table/column DML grant and no RLS write policy. A trusted routine may still perform the operation after its own checks.
- **Private only:** private trigger/definer routine; no application-role `EXECUTE` grant.

All read helpers deny null/unverified callers and inactive tenants unless a row is explicitly self-only and contains no tenant data. No `anon` policy or grant is proposed.

## 2. Complete twelve-table matrix

| Table | SELECT | INSERT | UPDATE | DELETE | Trusted mutation path |
|---|---|---|---|---|---|
| **tenants** | Active member with `organization.view`; exact requested/row tenant must match membership. Replace table SELECT with safe columns only: `id`, `name`, `slug`, `country`, `timezone`, `default_currency`, `contact_email`, `contact_phone`, `status`, `created_at`, `updated_at`. `settings`, `created_by`, `creation_key` and `active_owner_count` stay ungranted. No Platform Admin override in P2. | **No direct policy/grant.** | **No direct.** Never expose arbitrary identity/status/settings/counter updates. | **No direct.** | P3 `create_organization` and `update_organization`; `settings.view` safe read RPC and `settings.update` mutation. Future status workflow separately reviewed. P9 platform operations only. |
| **branches** | Active member with `branch.view`; organization roles see tenant branches, branch roles only assigned active branches. Historical inactive-branch visibility, if needed, requires an explicit safe exception; default is deny. | **No direct.** | **No direct.** | **No direct.** P1 `branch.delete` remains reserved. | P3 create/update/status RPCs; every branch ID resolved inside the caller's tenant and authority. |
| **profiles** | Self only. Co-member directory data is returned through a safe projection/RPC, not broad profile SELECT. | **No direct.** P4 signup/profile lifecycle creates it from the verified Auth identity. | Self only, and only proposed column grants for `full_name`, `avatar_url`, `phone`, `theme_preference`, `last_tenant_id`. `id`, timestamps and identity remain immutable. `last_tenant_id` must be null or an active tenant of the caller. | **No direct.** Existing Auth/profile deletion and membership RESTRICT contract remains. | P4 profile creation/lifecycle; ordinary self column update under RLS. |
| **roles** | Global system roles only when caller has `role.view` in at least one active tenant; custom roles only when caller has `role.view` in that exact tenant. | **No direct.** | **No direct.** P1 identity/system semantics remain immutable. | **No direct.** | Catalog seeds by reviewed migration. Custom-role workflow remains disabled because `role.manage` is reserved for M1. |
| **permissions** | Global catalog only when caller has `role.view` in at least one active tenant. | **No direct.** | **No direct.** | **No direct.** | Reviewed migration-controlled catalog only. |
| **role_permissions** | Caller must be able to view the parent role and have `role.view` in the relevant tenant. Global mappings follow global-role visibility; custom mappings never cross tenants. | **No direct.** | **No direct.** P1 pair identity is immutable. | **No direct.** | Reviewed catalog migration; future custom-role routine only after `role.manage` is explicitly enabled. |
| **memberships** | Self, or same-tenant `user.view` with organization scope, or branch-scoped `user.view` sharing an authorized branch. Branch actors do not see organization-only memberships through this policy. | **No direct.** | **No direct.** No client changes to role, status, user, tenant or invitation provenance. | **No direct.** Offboarding is a status transition, not deletion. | P3 invitation acceptance and membership/Owner RPCs; P2 Owner and branch invariant triggers. |
| **membership_branches** | Caller may view the parent membership and the referenced branch. Self read remains available for own active assignments. | **No direct.** | **No direct.** Pair identity is immutable. | **No direct.** | P3 membership branch-assignment/acceptance RPCs; internal cleanup during offboarding. |
| **invitations** | Only P1 safe columns. Visible to authorized tenant member managers as defined above. The invited email address alone does not grant row read; token lookup/acceptance is RPC-only. `token_hash` remains ungranted. | **No direct.** | **No direct.** | **No direct.** | P3 create/revoke/expire/accept RPCs. Acceptance derives all actor/time fields and never accepts a client hash. |
| **invitation_branches** | Caller must be able to view the parent invitation and referenced branch. No independent cross-tenant or token-based read. | **No direct.** | **No direct.** Pair identity is immutable. | **No direct.** | Created atomically with invitation; internal cascade on invitation deletion does not constitute an application deletion feature. |
| **audit_logs** | Same active tenant, organization-scope membership and `audit.view`. No branch-only audit policy because no branch column exists. No platform-wide read in P2. | **No direct.** Private audit writer/trigger only; no sequence privilege. | **No direct**, plus proposed immutable trigger rejecting all updates. | **No direct**, plus proposed immutable trigger rejecting all deletes. | P2 private append-only writers invoked by approved triggers/RPCs. |
| **platform_admins** | Self row only, so a user can learn their own status without enumerating other administrators. Empty until P9. | **No direct.** | **No direct.** | **No direct.** | P9 controlled verified-account grant/revoke only. Owner/Admin and invitation paths can never write it. |

## 3. Policy-level logic by table

The following is semantic logic, not executable migration SQL. Helper names are specified in document 4.

### tenants

- Policy `tenants_select_member`: `p2_has_org_or_branch_permission(tenant_id, 'organization.view')` with tenant active. Every P1 system role has this permission; custom roles need the explicit mapping.
- No tenant write policies. The future provisioning RPC derives `created_by = auth.uid()` and controls `creation_key`; organization update uses a fixed allowlist.

### branches

- Policy `branches_select_scoped`: active tenant + `p2_can_access_branch(tenant_id, id, 'branch.view')`.
- No write policies. A future RPC must not accept a branch ID from another tenant and merely rely on a later update failure; it must authorize tenant and branch before mutation.

### profiles

- Policy `profiles_select_self`: `id = auth.uid()`.
- Policy `profiles_update_self`: `USING id = auth.uid()` and `WITH CHECK id = auth.uid()` plus a helper validating `last_tenant_id`.
- Proposed grants are column-level UPDATE only for the five safe fields. No UPDATE on `id`, `created_at` or `updated_at`; the existing trigger maintains `updated_at`.
- Direct co-member SELECT stays denied to avoid exposing phone and cross-tenant navigation hints.

### roles

- Policy `roles_select_catalog`: for global rows, caller has `role.view` in any active tenant; for custom rows, caller has `role.view` in `roles.tenant_id`.
- Helper reads role tenancy under definer privileges; it does not join through the same RLS-protected role row recursively.
- No write policy. `UNIQUE (tenant_id,key)` plus the partial global system-key index and P1 validation remain structural controls.

### permissions

- Policy `permissions_select_catalog`: caller has `role.view` in at least one active tenant.
- No per-tenant customization: this is a global controlled catalog. No write policy.

### role_permissions

- Policy `role_permissions_select_scoped`: `p2_can_view_role(role_id)` and the caller has `role.view` in that role's tenant context.
- No write policy. A future custom-role RPC must validate role tenancy and each permission key; it must never update global system mappings.

### memberships

- Policy `memberships_select_self_or_scoped`: self OR `p2_can_view_membership(id)`.
- `p2_can_view_membership` resolves the target tenant, target role scope and shared branch set without relying on target-row visibility.
- No write policy. This prevents direct last-Owner removal, role escalation, tenant transfer and provenance forgery even if a future server function accidentally issues a broad update under a user JWT.

### membership_branches

- Policy `membership_branches_select_scoped`: `p2_can_view_membership(membership_id)` AND branch visibility, with self-assignment read allowed.
- No write policy. Composite foreign keys ensure membership and branch tenancy agree; P2 validators ensure role/branch-set semantics.

### invitations

- Policy `invitations_select_scoped_safe_columns`: `p2_can_view_invitation(id)`.
- The policy cannot make an ungranted column safe; the P1 column privilege excluding `token_hash` must remain. No later `GRANT SELECT ON public.invitations TO authenticated` table-level grant is permitted.
- No write policy. Creation, expiry, revocation and acceptance are controlled RPC operations.

### invitation_branches

- Policy `invitation_branches_select_scoped`: parent invitation visible AND referenced branch visible to the actor.
- No write policy. RPCs must verify all rows as one set; they cannot insert a subset and continue after a forbidden branch fails.

### audit_logs

- Policy `audit_logs_select_organization`: active same-tenant organization-scope role with `audit.view`.
- No application insert policy despite auditing requirements; only private writers append.
- No update/delete policies and a database guard blocks privileged accidental mutations. The identity sequence remains ungranted to every application role.

### platform_admins

- Policy `platform_admins_select_self`: `user_id = auth.uid()`.
- No write policy. The P2 `p2_is_platform_admin()` helper may answer only for the current user; no policy makes it a tenant authorization shortcut.

## 4. Required grant changes in the eventual P2 review SQL

These are design requirements, not executed grants:

1. Preserve all P1 SELECT grants and safe invitation column projection.
2. Add only column-level authenticated UPDATE for the five approved profile fields if self-update is included in P2; otherwise defer both grant and policy to P4.
3. Grant authenticated `EXECUTE` only on explicitly public boolean policy helpers and approved user-JWT RPCs.
4. Do not grant authenticated or service_role table INSERT/DELETE/TRUNCATE, general table UPDATE, audit sequence usage, or direct token-hash SELECT.
5. Revoke `EXECUTE` on private triggers, audit writers and invariant routines from PUBLIC, anon, authenticated and service_role.
6. Keep `service_role` table, column and sequence privileges at zero. Server functions use `requireSupabaseAuth` and the user bearer token; privileged work is authorized inside narrow definer RPCs.

## 5. Write-operation authorization matrix

| Operation | Direct client JWT | Trusted routine | Core checks |
|---|---|---|---|
| Create organization | Deny | P3 | Verified user, slug/payload validation, creation-key retry ownership, atomic first Owner and audit |
| Update organization | Deny | P3 | Active same-tenant `organization.update`; fixed fields; audit |
| Create/update branch | Deny | P3 | Org `branch.create/update`, or assigned-branch `branch.update` only for allowed fields; audit |
| Delete branch | Deny | Not enabled in M1 | Reserved permission is not implementation |
| Create custom role/mappings | Deny | Not enabled in M1 | `role.manage` reserved; no silent activation |
| Update own safe profile fields | Allow narrow columns + self RLS | Not required | Verified identity for tenant hint; no identity changes |
| Create invitation | Deny | P3 | `user.invite`, rank delegation, full branch authority, duplicate/expiry handling, token hash only |
| Accept invitation | Deny | P3 | Verified matching email, token hash, row lock, expiry/status, continuing inviter authority, membership conflict |
| Revoke invitation | Deny | P3 | Current `user.invite`, target rank and branch authority, pending status; audit |
| Change role/status/branches | Deny | P3 | `user.update`, target hierarchy, branch scope, tenant and Owner locks, invariant triggers, audit |
| Append audit | Deny | Private P2 only | Fixed event allowlist, same transaction, no secrets |
| Modify audit | Deny | None | Immutable trigger rejects |
| Grant Platform Admin | Deny | P9 only | Verified exact account, separate platform authorization and audit |

## 6. RLS acceptance conditions

- Every table has only its explicitly approved policies; no accidental `USING (true)` write or broad authenticated read.
- Anonymous and unverified callers receive no tenant rows.
- Cross-tenant and unassigned-branch reads return no rows; direct writes fail by privilege even before RLS.
- Self-only profile and platform rows never expose other users' data.
- Invitation `token_hash` fails column privilege checks for every application role, including service_role unless separately changed by a future reviewed migration.
- Policies neither recurse nor depend on client-provided JWT tenant metadata.
- Table owner/bypass roles are documented as trusted and are never used for ordinary requests.
- Query plans use expected indexes and complete within the agreed test environment performance budget; no performance optimization may remove an authorization predicate.
