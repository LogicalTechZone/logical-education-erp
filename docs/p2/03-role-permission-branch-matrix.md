# Logical Education ERP — M1 P2 Role, Permission and Branch Authorization Matrix

**Planning only.** Values below come from the actual P1 V3 catalog: five system roles, fourteen permissions and thirty-seven role-permission mappings. No role or permission is added or enabled by this document.

## 1. Immutable system roles

| Role | Rank | Scope | Authority boundary |
|---|---:|---|---|
| Owner | 100 | Organization | Full enabled M1 organization capability, all branches, Owner delegation subject to last-Owner invariant |
| Organization Admin | 80 | Organization | Tenant-wide administration except Owner delegation and reserved capabilities |
| Branch Manager | 50 | Branch | Assigned-branch management and lower-role invitations only |
| Staff | 20 | Branch | Organization and assigned-branch read in the current P1 catalog |
| Read Only | 10 | Branch | Organization and assigned-branch read only |

Rank controls delegation and management hierarchy. It never replaces a permission check. Platform Admin has no rank and is not a tenant role.

## 2. Exact role-permission matrix

`Yes` means the mapping exists in P1 V3. `Reserved` means the permission exists but the feature is not enabled in M1.

| Permission | Owner | Organization Admin | Branch Manager | Staff | Read Only |
|---|---|---|---|---|---|
| organization.view | Yes | Yes | Yes | Yes | Yes |
| organization.update | Yes | Yes | — | — | — |
| branch.view | Yes | Yes | Yes | Yes | Yes |
| branch.create | Yes | Yes | — | — | — |
| branch.update | Yes | Yes | Yes, assigned branches | — | — |
| branch.delete | Reserved; not enabled | — | — | — | — |
| user.view | Yes | Yes | Yes, scoped members | — | — |
| user.invite | Yes | Yes | Yes, lower branch roles only | — | — |
| user.update | Yes | Yes | — | — | — |
| role.view | Yes | Yes | Yes | — | — |
| role.manage | Reserved; not enabled | — | — | — | — |
| settings.view | Yes | Yes | Yes | — | — |
| settings.update | Yes | Yes | — | — | — |
| audit.view | Yes, organization-wide | Yes, organization-wide | — | — | — |
| **Mapping count** | **14** | **12** | **7** | **2** | **2** |

Total: **37 mappings**, matching P1 V3. Staff and Read Only intentionally have the same current foundation permissions; future operational modules must distinguish them through separately reviewed permission mappings rather than invented P2 capabilities.

## 3. Organization versus branch evaluation

| Caller role scope | Organization resource | Branch resource | Required branch rows |
|---|---|---|---|
| Organization system/custom role | Check active tenant + organization permission | Check active tenant + requested permission; may span tenant branches | Must have zero `membership_branches` rows |
| Branch system/custom role | Only explicitly mapped organization read/capability | Check permission + active same-tenant branch + explicit assignment | Must have at least one active assignment |
| Platform Admin | No implicit tenant access | No implicit branch access | Not applicable; P9 separate checks |

An organization role's lack of branch rows is not missing configuration; it denotes tenant-wide scope. A branch role with no rows is invalid for active use and fails closed.

## 4. Role delegation matrix

This matrix concerns inviting or assigning a target role. The actor must also hold `user.invite` or `user.update` as appropriate and satisfy tenant/branch scope.

| Actor \ Target | Owner | Organization Admin | Branch Manager | Staff | Read Only | Custom role |
|---|---|---|---|---|---|---|
| Owner | Allow, same tenant | Allow | Allow | Allow | Allow | Allow if same tenant and rank ≤100 |
| Organization Admin | **Deny** | **Deny equal-rank delegation** | Allow | Allow | Allow | Allow only same tenant and rank <80 |
| Branch Manager | **Deny** | **Deny** | **Deny equal-rank delegation** | Allow, assigned branches only | Allow, assigned branches only | Only branch scope, rank <50, permitted permission set and assigned branches |
| Staff | Deny | Deny | Deny | Deny | Deny | Deny |
| Read Only | Deny | Deny | Deny | Deny | Deny | Deny |

Custom roles cannot use reserved system keys or rank 100 under P1 validation. `role.manage` is reserved, so P2/P3 does not expose custom-role creation/editing even though read isolation and future delegation rules are defined.

### Existing-member management

- Owner may manage another Owner only through Owner-safe RPCs and never remove/downgrade the final active Owner.
- Organization Admin cannot change any Owner and cannot elevate itself or another member to Owner.
- Non-Owner equal-rank peer management is denied. This prevents two Organization Admins from arbitrarily removing or demoting each other through a generic update path.
- Branch Manager has no `user.update` in P1, so it cannot change existing membership role/status/branch sets; its invitation capability does not imply membership administration.
- Self-service profile edits are separate. Self role, status, branch or platform changes are always denied outside guarded workflows.

## 5. Branch authorization matrix

| Operation | Owner / Organization Admin | Branch Manager | Staff / Read Only |
|---|---|---|---|
| View branch | All active tenant branches with `branch.view` | Assigned active branches only | Assigned active branches only |
| Create branch | Allowed with `branch.create` | Deny | Deny |
| Update branch | All tenant branches with `branch.update` | Assigned branches with `branch.update`; fixed editable fields | Deny |
| Delete branch | Not enabled in M1 | Deny | Deny |
| View members | All tenant memberships with `user.view` | Memberships sharing an authorized branch; organization-only memberships hidden | Self only |
| Invite Staff/Read Only | Any active tenant branch | Only when every invited branch is currently assigned to the manager | Deny |
| Invite Branch Manager | Owner/Admin only | Deny equal rank | Deny |
| Assign organization role | Owner/Admin within rank rules | Deny | Deny |
| View audit | Organization-wide with `audit.view` | Deny in current catalog | Deny |

Branch Manager's `organization.view`, `settings.view` and `role.view` do not widen branch access. They expose only the relevant organization/catalog information under their respective read policies.

## 6. Invitation authorization

### Creation

1. Resolve inviter from `auth.uid()` and `inviter_membership_id`; never accept a caller-selected inviter identity.
2. Require active tenant/membership, verified email and `user.invite`.
3. Validate role assignment using P1 same-tenant/global-role integrity plus the delegation matrix.
4. Organization-role invitation: branch list must be empty.
5. Branch-role invitation: branch list must be nonempty, distinct, active and same-tenant.
6. Organization actor: any tenant branch within rank/permission rules.
7. Branch actor: every invited branch must be in the actor's own active `membership_branches` set.
8. A Branch Manager can offer only roles strictly below rank 50. Organization Admin can offer at most rank 80. Only Owner can offer Owner.
9. Store only the token hash and derive expiry/inviter/timestamps server-side.

### Acceptance

Re-run all of these against current committed state:

- token corresponds to a pending, unexpired invitation;
- caller Auth email is verified and matches invitation email case-insensitively;
- tenant and all required branches remain active;
- inviter membership remains active and still has `user.invite`;
- inviter still outranks/is authorized for the offered role and every offered branch;
- role remains valid for the tenant;
- no conflicting membership exists;
- branch-set semantics remain valid.

Any failure rejects the whole acceptance. Do not silently drop branches, lower the role or substitute another inviter.

### Revocation

- Organization Owner/Admin may revoke invitations within their delegation rank and tenant.
- Branch Manager may revoke only lower-ranked branch invitations wholly inside current assigned branches.
- Owner-only invitations cannot be revoked by Organization Admin.
- Accepted invitations are historical and cannot be revoked; remove/suspend the membership through a separate authorized workflow.

## 7. Owner-specific rules

| Scenario | Required result |
|---|---|
| Add second Owner | Active Owner only; tenant lock; counter +1; audit |
| Transfer ownership | Promote target then optionally demote caller in one transaction; never pass through zero Owners |
| Organization Admin self-promotes | Deny regardless of `user.update` |
| Owner removes self with another active Owner | Allow through guarded workflow; counter -1; audit |
| Last Owner removes/downgrades self | Reject; membership, counter and audit unchanged |
| Suspend/remove last Owner | Same rejection as downgrade |
| Delete last Owner membership | Reject even though normal offboarding uses status, not delete |
| Two concurrent removals of the only two Owners | At most one succeeds; second re-reads after tenant lock and fails |
| Counter drift | Commit-time validation rejects affected transaction; no silent counter reset |

Owner role identity is determined from the immutable global system role with key `owner`, organization scope and rank 100. Custom roles cannot satisfy Owner invariants merely by name or high rank.

## 8. Custom-role isolation

Even while management is disabled, P2 read policies must support the existing schema safely:

- custom role rows are visible only in their own tenant to callers with `role.view`;
- custom role-permission mappings inherit that same tenancy;
- membership/invitation assignment accepts a custom role only when `roles.tenant_id = target tenant`;
- global system role rows and mappings are never editable by tenant actors;
- a custom role's name or rank never grants Owner or Platform Admin status;
- branch-scoped custom roles require explicit branch assignments;
- organization-scoped custom roles receive no branch rows and only their explicitly mapped permissions;
- delegation must consider target rank and branch scope, not only whether the actor possesses every target permission. Before custom-role management is enabled, an additional rule must prevent delegating permissions the actor does not possess or define Owner as the explicit exception.

## 9. Platform authority matrix

| Capability | Owner | Organization Admin | Platform Admin |
|---|---|---|---|
| Manage own tenant within permissions | Yes | Limited | Not implicitly |
| Grant Owner | Yes, guarded | No | Not through tenant role paths |
| Read/write other tenants | No | No | Only separately approved P9 operations |
| View own platform-admin row | Only if separately granted | Only if separately granted | Yes |
| Grant/revoke Platform Admin | No | No | P9 controlled operation only |
| Bootstrap initial platform identity | No | No | P9 verified UUID process only |

Possessing a tenant Owner membership and a Platform Admin row would represent two independent grants; neither derives from the other.

## 10. Acceptance criteria

- Catalog counts remain exactly 5 roles, 14 permissions and 37 mappings unless a separately reviewed migration changes them.
- Every capability check uses permission keys and current role mappings; rank checks are additive.
- All branch tests prove both positive access and negative access to an unassigned same-tenant branch.
- Owner and Platform Admin escalation tests cover direct API calls and trusted RPC inputs, not only hidden buttons.
- Custom-role tests prove tenant isolation for roles, mappings, memberships and invitations.
- No future module inherits broad access automatically; each future permission mapping and policy must pass this same tenant/branch review.
