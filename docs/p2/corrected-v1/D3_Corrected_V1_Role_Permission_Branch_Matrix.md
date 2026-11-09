# Logical Education ERP — M1 P2 Role, Permission and Branch Authorization Matrix

**Document:** D3_Corrected_V1  
**Status:** corrected planning document; no role, permission, policy or workflow has been implemented.  
**Baseline:** original D3 SHA-256 `9416904d13b15d86d4c32c34bacc0e93151e7ff4210896365249c8564bdfb835`; actual unapplied P1 V3 catalog.  
**Decisions:** owner-approved AD01–AD12/S01–S10 recommendations incorporated. All referenced tests remain proposed and NOT EXECUTED.

## 1. Immutable system roles

| Role | Rank | Scope | Authority boundary |
|---|---:|---|---|
| Owner | 100 | Organization | Full enabled organization capability, all active branches, guarded Owner delegation subject to last-Owner invariant |
| Organization Admin | 80 | Organization | Tenant-wide administration within 12 mappings; cannot grant/manage equal Admin or any Owner |
| Branch Manager | 50 | Branch | Assigned-active-branch management and strictly lower branch-role invitations only |
| Staff | 20 | Branch | Organization and assigned-active-branch read under two current mappings |
| Read Only | 10 | Branch | Organization and assigned-active-branch read only; no protected business modification |

Rank controls delegation and management hierarchy. It never replaces a permission check. Platform Admin has no rank and is not a tenant role. Custom rank/name/permissions never confer exact Owner or Platform Admin identity.

## 2. Exact role-permission matrix

`Yes` means the mapping exists in P1 V3. `Reserved` means the permission exists but the feature is disabled in M1.

| Permission | Owner | Organization Admin | Branch Manager | Staff | Read Only |
|---|---|---|---|---|---|
| organization.view | Yes | Yes | Yes | Yes | Yes |
| organization.update | Yes | Yes | — | — | — |
| branch.view | Yes | Yes | Yes | Yes | Yes |
| branch.create | Yes | Yes | — | — | — |
| branch.update | Yes | Yes | Yes, assigned active branches | — | — |
| branch.delete | Reserved; disabled | — | — | — | — |
| user.view | Yes | Yes | Yes, scoped members | — | — |
| user.invite | Yes | Yes | Yes, strictly lower branch roles only | — | — |
| user.update | Yes | Yes | — | — | — |
| role.view | Yes | Yes | Yes | — | — |
| role.manage | Reserved; disabled | — | — | — | — |
| settings.view | Yes | Yes | Yes, approved org-level keys only after allowlist exists | — | — |
| settings.update | Yes | Yes | — | — | — |
| audit.view | Yes, organization-wide | Yes, organization-wide | — | — | — |
| **Mapping count** | **14** | **12** | **7** | **2** | **2** |

Total: **37 mappings**, matching P1 V3. Staff and Read Only intentionally share the two current foundation mappings; future modules must distinguish them through separately reviewed mappings. Owner's two reserved mappings are excluded from delegable enabled capabilities and do not enable features.

## 3. Organization, branch and historical-state evaluation

| Caller/resource state | Organization resource | Branch resource | Branch-row requirement |
|---|---|---|---|
| Active organization system/custom role | Verified active tenant/membership plus exact tenant permission | Exact permission across active tenant branches | Zero `membership_branches` rows |
| Active branch system/custom role | Only explicitly mapped tenant-level capability and at least one active assignment | Permission + active same-tenant branch + explicit active assignment | Nonempty links and at least one active branch |
| Inactive/suspended/removed caller | Deny tenant-bearing self and resource reads | Deny | Historical rows may remain but grant no access |
| Platform Admin | No implicit tenant access | No implicit branch access | Not applicable; P9 separate checks |

### Status-aware structural rules

- Organization memberships and invitations always have zero branch links.
- An active branch membership has at least one link and at least one active assigned branch. Every new/replacement link is active, distinct, same-tenant and inside actor authority.
- An inactive historical link confers no permission. An active membership with additional inactive links retains access only through its remaining active assignments.
- A newly created pending branch invitation has a nonempty, distinct, fully active offered set. A stored pending invitation whose branch or inviter authority later narrows is unusable at acceptance; its offered set is never silently reduced.
- Accepted, revoked and expired invitation history retains original links without requiring branches to remain active forever. Removed/suspended membership history may retain or clear links under the future P3 offboarding contract; exact per-status cleanup/proactive offer transition remains an S06 blocker.
- Branch deactivation is rejected when it would leave an active branch membership without an active assignment. No automatic offboarding alternative is approved.
- Deferred validation checks final state. Operational helpers independently fail closed on invalid or stale state.

Relevant tests: BR-01/03/06, NEW-P2-02/04/08, NEW-P3-04/11.

## 4. Role delegation and existing-member management

The actor needs the operation's permission (`user.invite` or `user.update`), active verified context and full tenant/branch authority in addition to this matrix.

| Actor \ Target | Owner | Organization Admin | Branch Manager | Staff | Read Only | Custom role |
|---|---|---|---|---|---|---|
| Owner | Allow through guarded future P3 path, same tenant | Allow | Allow | Allow | Allow | Same tenant, rank <100, enabled-permission subset |
| Organization Admin | **Deny** | **Deny equal-rank grant/management** | Allow | Allow | Allow | Same tenant, rank <80, compatible/narrower scope and enabled-permission subset |
| Branch Manager | **Deny** | **Deny** | **Deny equal-rank grant** | Allow, assigned active branches only | Allow, assigned active branches only | Branch scope, rank <50, enabled-permission subset and assigned active branches only |
| Staff | Deny | Deny | Deny | Deny | Deny | Deny |
| Read Only | Deny | Deny | Deny | Deny | Deny | Deny |

### Exact global Owner exception

Only the immutable global role with key `owner`, organization scope and rank 100 may grant/manage Owner. This exception permits backend Owner-to-Owner operations in future separately approved P3 RPCs; it does not authorize an Owner-transfer/additional-Owner UI. Last-Owner protection always applies.

### Existing-member rules

- Non-Owners must strictly outrank both the existing target and the proposed new role. Organization Admins cannot demote/remove each other and cannot elevate themselves or others to Owner/Admin.
- An active Owner may manage another active Owner only through Owner-safe workflows. Self role/status/branch changes cannot bypass guarded workflows.
- Branch Manager has `user.invite` but no `user.update`; it cannot change an existing membership's role, status or branch set.
- Promotion from branch role to Owner/organization role atomically clears all target branch links. Ownership transfer promotes first and optionally demotes the caller to Organization Admin second; the caller ends with zero links.
- The last active Owner cannot be demoted, suspended, removed or deleted. With another active Owner remaining, guarded self-removal is permitted.

Relevant tests: RBAC-03–RBAC-08/12, OWN-01–OWN-08, NEW-P3-06/07.

## 5. Branch authorization matrix

| Operation | Owner / Organization Admin | Branch Manager | Staff / Read Only |
|---|---|---|---|
| View branch | All active tenant branches with `branch.view` | Assigned active branches only | Assigned active branches only |
| Create branch | Allowed with `branch.create` in future P3 | Deny, including assigned branch | Deny |
| Update branch | Tenant branches with `branch.update` in future P3 | Assigned active branches with `branch.update`; fixed editable fields | Deny |
| Change branch status | Organization-scope `branch.update` only; reject invalid final active assignments | Deny | Deny |
| Delete branch | Disabled in M1 | Deny | Deny |
| View members | All tenant memberships with `user.view` | Only memberships sharing a currently authorized active branch; organization-only memberships hidden | Self only while active/usable |
| View member branch grants | Authorized tenant rows with both parent/branch visibility | Only currently authorized shared branch rows | Own currently authorized rows only |
| Invite Staff/Read Only | Any active tenant branch within enabled-permission rules | Every offered branch must be currently assigned and active | Deny |
| Invite Branch Manager | Owner/Admin only | Deny equal rank | Deny |
| Assign organization role | Owner/Admin within strict-lower rules; Owner exception for Owner | Deny | Deny |
| View audit | Organization-wide with organization-scope `audit.view` | Deny under current seven mappings | Deny |
| View settings | P3 approved org-level projection only | Same approved org-level keys only; no branch-private payload | Deny |

Branch Manager's `organization.view`, `settings.view` and `role.view` never widen branch access. Global catalog visibility requires an active usable membership; permission in Tenant A does not authorize Tenant B.

## 6. Invitation authorization — future P3

### Creation

1. Resolve inviter from `auth.uid()` to canonical inviter membership; never accept caller-selected inviter identity.
2. Require current verified email, active tenant/membership and `user.invite` after locks.
3. Require global system or same-tenant custom target role and apply §4 rank/scope/permission-subset rules. Reserved keys are excluded from every target's delegable set.
4. Organization-role offer: empty branch list. Branch-role offer: nonempty, distinct, active same-tenant list wholly inside inviter authority.
5. Branch actors may offer only branch scope and may not widen to organization scope.
6. Derive inviter, status, creation and expiry server-side. Store only token hash; explicit insertion timestamp plus exactly seven days governs expiry.
7. A successful replacement atomically expires matching elapsed pending rows and inserts the new invitation/grants. Any invalid branch or permission rejects the entire transaction.

### Acceptance and revocation

Acceptance re-reads current committed state after waits and requires pending/unexpired status, verified case-insensitive email match, active tenant/all offered branches, valid role, no membership conflict, valid branch-set semantics and continuing inviter active `user.invite`, rank/scope/subset and full branch authority.

Any failure rejects the whole acceptance without silently dropping branches, lowering role or substituting inviter. Failed expired acceptance persists no expiry/audit change. Every accepted-token replay, including same-user retry, is rejected generically. Existing active/invited/suspended/removed membership is never automatically upserted/reactivated.

Organization Owner/Admin may revoke only invitations within current delegation and tenant authority; Admin cannot revoke Owner/equal-Admin offers. Branch Manager may revoke only strictly lower branch offers wholly inside current assigned active branches. Accepted history cannot be revoked.

Relevant tests: INV-01–INV-10, ACC-01–ACC-14, NEW-P3-07–NEW-P3-10.

## 7. Owner-specific rules

| Scenario | Required result |
|---|---|
| Add second Owner | Active exact Owner only; future guarded P3 RPC; tenant lock; counter +1; branch cleanup; audit |
| Transfer without relinquishment | Target becomes Owner; caller remains Owner; count increases correctly |
| Transfer and relinquish | Promote target then demote caller to Organization Admin in one transaction; both have zero branch links; never commit zero Owners |
| Organization Admin self/peer promotion | Deny regardless of `user.update` |
| Owner removes self with another active Owner | Allow through guarded workflow; counter -1; audit |
| Last Owner demotion/suspension/removal/delete | Reject; membership, links, counter and audit unchanged |
| Two concurrent exits from two Owners | At most one succeeds; final actual/stored count exactly 1 |
| Two concurrent exits from one Owner | Both fail; final actual/stored count exactly 1 |
| Counter-only tampering | Deferred final-state validation rejects drift for active and inactive tenants |
| Verification loss/ban | Does not silently recalculate counter; access still fails verification gate; recovery is separate |

Relevant tests: OWN-01–OWN-13, NEW-P1-06, NEW-P2-06/07 and NEW-P3-06/12.

## 8. Custom-role isolation and permission-subset rule

Even while management is disabled:

- custom roles and mappings are visible only in their exact tenant to active usable callers with `role.view`;
- membership/invitation assignment accepts custom roles only when `roles.tenant_id = target tenant`;
- global roles, global mappings and the permissions catalog are immutable to application/definer paths, including UPDATE/DELETE/TRUNCATE guards;
- custom names/ranks/permission bundles never satisfy exact Owner or Platform Admin identity;
- organization custom roles have zero branch rows; branch custom roles follow §3 active/history rules.

### Delegable-set algorithm

For each proposed invitation or assignment:

1. Compute the actor's current permission mappings for the active role in the target tenant.
2. Remove reserved keys `branch.delete` and `role.manage` and any other capability not enabled for delegation.
3. Require the target custom role's complete permission set to be a subset of that actor set. An empty subset is not by itself authorization; operation permission, rank and scope checks still apply.
4. Require strictly lower rank for every non-Owner and compatible/narrower scope. Branch actors require branch scope and complete offered/assigned branch containment.
5. Re-run the same computation at invitation acceptance and after every lock wait. Role/mapping changes can invalidate an offer; no snapshot of creation-time authority is accepted.
6. Only exact global Owner may delegate Owner; custom rank 100 is already structurally forbidden and can never use the exception.

Relevant tests: RBAC-08–RBAC-12, NEW-P2-03, NEW-P3-07.

## 9. Platform authority matrix

| Capability | Owner | Organization Admin | Platform Admin |
|---|---|---|---|
| Manage own tenant within permissions | Yes | Limited | Not implicitly |
| Grant Owner | Yes, guarded future P3 | No | Not through tenant paths |
| Read/write other tenants | No | No | Only separately approved P9 operations |
| View own platform-admin row | Only if separately granted and verified | Only if separately granted and verified | Yes, verified self only |
| Grant/revoke Platform Admin | No | No | P9 controlled insert/delete process only |
| Bootstrap initial platform identity | No | No | P9 verified UUID process only |

Possessing tenant Owner and Platform Admin rows would represent two independent grants; neither derives from the other. P2 helper/read requires verified current identity and never bypasses tenant policies.

## 10. Acceptance criteria and change history

- Catalog remains exactly 5 roles, 14 permissions and 37 mappings unless a separately reviewed migration changes it.
- Every capability check uses current permission keys; rank checks are additive and reserved capabilities stay disabled.
- All branch tests prove positive assigned access and negative unassigned/inactive access, including history/current-authority distinctions.
- Owner and Platform Admin escalation tests cover direct API and trusted RPC inputs, not only hidden buttons.
- Custom-role tests prove role, mapping, membership and invitation isolation plus enabled-permission subsets.
- No future module inherits broad access automatically.

**Corrected V1:** resolved equal-Admin contradiction; added exact Owner backend exception without UI authorization; defined active/history branch semantics and deactivation default; added promotion/demotion link cleanup; defined custom enabled-permission subset and post-lock revalidation; applied verified platform self-status and P9 lifecycle boundary. Original D3 remains unchanged.
