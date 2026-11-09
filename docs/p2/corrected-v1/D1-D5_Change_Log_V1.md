# Logical Education ERP — D1–D5 Controlled Correction Change Log

**Version:** V1 · 9 November 2026 (UTC)  
**Authority:** documentation-only correction with owner approval of AD01–AD12/S01–S10 recommendations.  
**Preservation:** original D1–D5 and P1 V3 were not overwritten or deleted. Corrected copies are new files under `docs/p2/corrected-v1/`.

## 1. Exact original versions

| Document | Original path | Original SHA-256 | Corrected copy |
|---|---|---|---|
| D1 | `docs/p2/01-security-architecture.md` | `a240edef2e46fc8da82753f988de66c2c66274c6499b65ae6d9c4e0280471e1f` | `D1_Corrected_V1_Security_Architecture.md` |
| D2 | `docs/p2/02-rls-policy-matrix.md` | `50a4198cb34c900d87046020f21a17ae01dbdbad58cc6214fca5a6200616f909` | `D2_Corrected_V1_RLS_Policy_Matrix.md` |
| D3 | `docs/p2/03-role-permission-branch-matrix.md` | `9416904d13b15d86d4c32c34bacc0e93151e7ff4210896365249c8564bdfb835` | `D3_Corrected_V1_Role_Permission_Branch_Matrix.md` |
| D4 | `docs/p2/04-secure-function-specification.md` | `c1d4868eb071f864981b9b26b44038664f905726cf2f1689d275963ce7cecb89` | `D4_Corrected_V1_Secure_Function_Specification.md` |
| D5 | `docs/p2/05-security-test-plan.md` | `b4d0e8adfffbeed4ad3c230b1af6fb17c31b4b52ff911f4ac2090fad14ab297d` | `D5_Corrected_V1_Security_Test_Plan.md` |

P1 V3 source SHA-256 remains `deebaca7ea8ea7e58fb2b96af74ac64f1d049fc1a4447ed5fa459f058504535a`; P1 schema review remains `ab4b8c65b18877d7b4727afed57fff98c6779e79865048fc0844582fa6818788`.

## 2. D1 — Security Architecture Blueprint

| Area | Original issue | Corrected V1 change | Decisions/findings |
|---|---|---|---|
| §1 phase ownership | Mixed P2 primitives, profile writes and future workflow acceptance | P2 limited to read/invariant/audit primitives; P3 workflows; P4 profile; P9 platform; public onboarding gated | AD01/07, S07; F02/F10/F20 |
| §2 trusted context | Verification source and inactive self behavior incomplete | Private current Auth lookup; active usable tenant/member gate on all tenant self paths; post-lock fresh reads | AD02/04/06; F05 |
| §3 helpers/owners | Vague owner and universal EXECUTE wording | Ten exact P2 facades; private dependencies; conditional least-capability owner model and hosted preflight gate | AD02/03; F03/F04 |
| §4 access | P2 self-profile UPDATE exception | Removed all direct authenticated P2 DML; retained safe columns and private audit writers | AD01/07 |
| §5 delegation | Admin equal-rank sentence conflicted with strict-lower rule | Admin strictly below 80; exact global Owner exception; custom enabled-permission subset; no UI implied | AD08; F01/F11 |
| §5 branches | Active/history and deactivation semantics incomplete | At-least-one-active rule, active new grants/offers, retained history, default deactivation rejection | AD06/S06; F06/F07/F19 |
| §6 Owner | Trigger ordering/freshness/recursion/cleanup incomplete | Tenant-first writers, one counter writer, immediate/deferred checks, activation/counter events, link cleanup and fresh retries | AD05/08; F07/F08/F11 |
| §7 invitations | Expiry/replay/retry ambiguity and P2/P3 mixing | P3-only; insertion+7d; failed expiry rollback; replacement expiry; universal accepted replay rejection; retry proof blocker | AD07/10, S03–S05; F15/F16/F18 |
| §8 audit | Possible duplicate trigger/RPC events; no TRUNCATE | Single row-event producer; enumerated semantic events; catalog/audit TRUNCATE; trusted metadata | AD07, S01/S02; F09 |
| §9 platform | Verification and lifecycle incomplete | Verified self-status only; P9 verified UUID insert/delete/cascade design future | AD04/12; F13 |
| §§10–12 gates | Full future test plan implied for P2 | P1 + P2 + applicable deployment evidence only; unresolved parameters explicitly listed | AD07/10; F10/F12 |

## 3. D2 — RLS Policy Matrix

| Area | Original issue | Corrected V1 change | Decisions/findings |
|---|---|---|---|
| Opening | “Currently has RLS” sounded deployed | “P1 V3 specifies”; unapplied/source-versus-live distinction | F14 |
| §1 common gates | Self OR arms could bypass verification/active context | Only non-tenant profile self-read is separate; all tenant self paths use active verified helpers; platform self verified | AD02/04; F05/F13 |
| §2 matrix | No TRUNCATE column; P2 profile write; incomplete guard semantics | Twelve tables now cover SELECT/INSERT/UPDATE/DELETE/TRUNCATE and trusted phase path; zero P2 DML | AD01/07, S02 |
| §3 policy logic | Undefined helper aliases and unguarded membership self | Exactly twelve named SELECT policies using D4 signatures; no write policies or independent self arm | AD02; F03/F05 |
| Tenant/invitation privacy | Needed explicit column/grant boundary | Eleven tenant columns; invitation token_hash remains denied; settings/internal fields denied | AD09, BASE |
| §4 grants | Conditional profile columns and broad helper language | Profile UPDATE removed; signature-specific EXECUTE/schema USAGE/overload/nested ACL requirements; service_role zero | AD01/02/03 |
| §5 operations | Phase ownership ambiguous | Every mutation tagged P3/P4/P9/private P2; settings disabled pending allowlist | AD01/07/09/12 |
| §6 evidence | Policy acceptance lacked exact inventory | Added twelve-policy, privacy, ACL, positive/negative and plan/stress evidence links | AD02/07/10 |

## 4. D3 — Role, Permission and Branch Matrix

| Area | Original issue | Corrected V1 change | Decisions/findings |
|---|---|---|---|
| §§1–2 catalog | Correct baseline needed preservation | Exact five roles, 14 permissions, 37 mappings/ranks retained; reserved features remain disabled | BASE |
| §3 scope/history | “Active assignment” could invalidate history | Status-aware active-use, new-offer, retained-history and deactivation rules | AD06/S06; F06/F07 |
| §4 delegation | Owner exception/custom subset not fully consistent | Strict-lower non-Owner grant/manage; exact global Owner exception; enabled-permission subset excluding reserved keys | AD08; F01/F11 |
| §4 existing members | Generic outrank rule conflicted with Owner-to-Owner | Explicit Owner-only equal-rank backend exception; no transfer UI authorization | AD08 |
| §5 visibility | Branch/member/catalog behavior needed active context | Current active assigned scope, whole-offer containment, no cross-tenant catalog authority | AD02/04/06 |
| §6 invitation | Creation/acceptance lacked full corrected lifecycle | P3-only, post-lock authority, subset/scope, expiry/replay and no silent reduction | AD06–08/10 |
| §7 Owner | Link cleanup and one-Owner race expectation incomplete | Promotion/relinquishment zero links; both exits fail when starting at one | AD05/08 |
| §8 custom roles | Permission-subset algorithm not concrete | Six-step current actor set → reserved exclusion → subset → rank/scope → post-lock recheck → exact Owner exception | AD08 |
| §9 platform | Self-status verification/lifecycle missing | Verified self only; P9 separate grant/revoke/cascade | AD04/12 |

## 5. D4 — Secure RPC and Server Function Specification

| Area | Original issue | Corrected V1 change | Decisions/findings |
|---|---|---|---|
| §1 hardening | Owner/lock/audit language incomplete | Fixed signatures/ACLs, post-lock fresh state, tenant-first writers and single audit producer | AD02/03/05/07 |
| §2 owner/Auth | “Reviewed owner” and verification source not exact | Logical capability ceilings, non-recursive RLS feasibility gate and private current-user Auth lookup | AD03/04; F04/F05 |
| §3 helpers | Missing tenant helper; last-tenant in P2; no truth table | Ten P2 + one P4 facades; exact contracts and common state truth table; private dependencies | AD01/02/04/06; F03/F17 |
| §3 private guards | Permissions/TRUNCATE/branch-status events omitted | Catalog and audit UPDATE/DELETE/TRUNCATE guards; dependency-complete final-state validator list | AD05–07, S02 |
| §4 Owner/audit | Deferred freshness, recursion, duplicate/cardinality risks | Final-state reads, activation/counter events, counter-only exclusion and producer/cardinality ledger | AD05/07, S01 |
| §5 organization/settings | Retry proof and settings keys missing | Controlled profile prerequisite; retry contract blocker; endpoints disabled until exact settings catalogue | AD01/09/10, S05/S07/S09 |
| §6 branch/directory | Deactivation/history effects incomplete | Default reject last active assignment; current acceptance fails; safe scoped directory P3 | AD06; F06/F07 |
| §7 invitation | Expiry anchor, failed persistence and replay contradictions | Post-wait insertion+7d; failed expiry no change; successful replacement expiry; all accepted replays denied | AD10, S03–S05 |
| §8 membership/P4/P9 | Owner exception/link cleanup/offboarding and phase choices incomplete | Strict-lower/Owner rules, atomic branch sets, cleanup blocker, one P4 write path and P9 lifecycle boundary | AD01/06/08/11/12 |
| §9 deployment | Wrapper-only abuse and no numeric contract | Direct RPC + wrapper durability required; bearer/origin/CSRF; all missing values explicit blockers | AD10/S08; F12 |
| §10 verification | Needed exact runtime inventory | Owners/ACLs/overloads/schema/types, policy truth tables, primitive races, audit, deployment evidence | AD02–10 |

## 6. D5 — Security Tests and Acceptance Criteria

| Area | Original issue | Corrected V1 change | Decisions/findings |
|---|---|---|---|
| Inventory | 93 originals; 37 additions only in reports | Preserved 93 and incorporated 37 = 130 unique IDs; no duplicates/deletions | Task reconciliation |
| Row traceability | ID/test/expected only | Added phase/prerequisites, decisions, category and status; companion matrix adds corrected requirement references | AD01–12/S01–10 |
| Profile tests | ACL-03 P2 exception; PRV-04 phase mismatch | No P2 writes; PRV-04 and NEW-P4-01 are P4 | AD01/S07 |
| Helper/Read Only | Blanket null/every-modification expectations | D4 truth table; legitimate P4 self edits excluded | AD01/02; F17 |
| Branch/Owner | Historical links and OWN-07 ambiguity | Status-aware expectations; starting at one Owner both exits fail | AD05/06/08 |
| Invitation | Replay/expiry/time-anchor contradictions | Universal replay rejection, failed-expiry rollback, replacement success expiry and insertion+7d | AD10/S03–S05 |
| Settings/audit | Missing concrete prerequisites | Settings/event-value blockers explicit; role means role assignment; one domain row event | AD07/09, S01/S09 |
| Deployment | Wrapper-only/durability/budget gaps | Direct RPC coverage and numeric contract blockers; P2 primitive plan/stress still mandatory | AD10/S08 |
| Release gates | Full future plan implied for P2 | P1/P2/applicable deployment gates separated; later parents blocked not waived | AD07 |
| Legacy/gaps | Crosswalk/gaps separate from D5 | Tests 1–14, S1–S5 and GAP-01–GAP-10 retained as references, not extra IDs | Reconciliation |

## 7. Supporting deliverables

- `AD01-AD12_S01-S10_Approved_Decision_Register_V1.md` — all 22 approvals and residuals.
- `Complete_130_Test_Traceability_Matrix_V1.md` — complete eight-field row ledger.
- `Cross_Document_Consistency_Audit_V1.md` — F01–F20 and baseline reconciliation.
- `Remaining_Issues_and_Blocker_Register_V1.md` — owner/impact/resolution for every unresolved issue.
- `P1_P2_Readiness_Assessment_V1.md` — documentary versus execution readiness.

## 8. Change-control result

No original source was edited; no P1 SQL or comment was changed; no applied migration directory was created; no SQL, database, Auth, application or settings change was made. Static document structure checks are not implementation tests. All 130 runtime/security tests remain NOT EXECUTED.
