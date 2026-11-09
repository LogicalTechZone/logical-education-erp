# Logical Education ERP — D1–D5 Cross-Document Consistency Audit

**Version:** V1 · 9 November 2026 (UTC)  
**Audit type:** documentary technical reconciliation only.  
**Result:** **READY FOR SEPARATE DOCUMENTARY REVIEW; NOT READY FOR SQL PREPARATION/EXECUTION OR RUNTIME ACCEPTANCE.** No unresolved contradiction is hidden; remaining issues are explicit in the blocker register.

## 1. Sources and exact baseline verified

The audit re-read the complete original D1–D5, approved Decision Closure and Documentation Correction Preparation v1, Final Architecture Reconciliation & Readiness Report v1, P1 V3 SQL/schema review, uploaded product brief/PRD-equivalent, Architecture v2 ERD/role matrix/test suites and the correction authorization upload.

| Source | Exact version / verification |
|---|---|
| D1–D5 originals | Five project files; SHA-256 values match the approved source ledger in `D1-D5_Change_Log_V1.md` |
| Decision preparation | `/mnt/documents/Logical_Education_ERP_Decision_Closure_and_Documentation_Correction_Preparation_v1.md`; SHA-256 `14c2af7818fe8af5590162884d6a0aba0d87694772935114f113785deb4644fc` |
| Reconciliation | `/mnt/documents/Logical_Education_ERP_M1_P2_Final_Architecture_Reconciliation_Readiness_Report_v1.md`; SHA-256 `74f73be6f32cc2e6ac1ec0c2380eef525bc2c07aba529b93683095c1cc04d9ad` |
| P1 SQL | `docs/p1/database-foundation.review.sql` V3; SHA-256 `deebaca7ea8ea7e58fb2b96af74ac64f1d049fc1a4447ed5fa459f058504535a`; unapplied |
| P1 schema/ERD | `docs/p1/README.md` review v3; SHA-256 `ab4b8c65b18877d7b4727afed57fff98c6779e79865048fc0844582fa6818788` |
| Product brief | `PROJECT_LOGICAL_EDUCATION_ERP_pasted.md`, 838 lines; SHA-256 `9a254f675370787c66a6841901a676da42b029375983fe2e49a432456e4a39cb`; no separate formal PRD/Saudi specification located |
| Architecture v2 | Historical M1 direction/ERD/phase plan; later explicit P1 privileges and current AD/S decisions supersede stale direct-write/service-role wording |
| Authorization | `Logical_Education_ERP_-_D1-D5_Controlled_pasted.md`; documentation correction and AD/S recommendation approval only |

No separate formal PRD or Saudi Culinary Training Center specification was found; the uploaded product brief is the verified PRD-equivalent. The reusable multi-tenant product boundary is preserved.

## 2. F01–F20 closure audit

| Finding | Corrected disposition | Residual owner / requirement |
|---|---|---|
| F01 Admin equal-rank contradiction | **Documentary closed:** D1/D3/D4/D5 all require strict-lower non-Owner delegation/management | Runtime RBAC-05/INV-05 unexecuted |
| F02 Profile phase ownership | **Closed in corrected set:** P2 self-read only; P4 creation/write/theme/hint | B16 preserves P1 header/README historical wording; B12 P4 design |
| F03 Undefined helpers | **Documentary closed:** ten exact P2 facades, one P4 hint helper, no aliases | B04 final private signatures/dependency/ACL graph |
| F04 Definer owner/RLS model | **Direction closed; implementation open:** conditional least-capability split and no silent fallback | B02 hosted feasibility; B04 exact ledger |
| F05 Inactive/unverified self reads | **Documentary closed:** every tenant self path uses active verified usable context; profile/platform non-tenant rules explicit | B03 Auth semantics; B12 optional future status projection |
| F06 Branch history/current authority | **Approved rule applied:** active-use vs retained history separated | B06 exact offboarding/offers matrix |
| F07 Trigger event dependencies | **Documentary contract completed:** tenant/counter/membership/branch/catalog/final-state events listed | B04 exact SQL graph; B06 transitions; runtime tests pending |
| F08 Owner locking/freshness | **Documentary closed:** tenant-first writers, one counter writer, immediate/deferred checks and fresh retries aligned | B04/B10 exact SQL/numeric retry; runtime races pending |
| F09 Audit producers/immutability | **Producer model closed:** domain row events once, semantic events separate, audit/catalog TRUNCATE included | B05 exact event names/counts/metadata |
| F10 P2 versus P3 release gates | **Documentary closed:** P2 only its tests/subsets; future parents blocked | Actual phase evidence remains absent |
| F11 Owner exception/link cleanup | **Documentary closed:** exact global Owner exception and zero-link conversions aligned | B15 future endpoint/UI approval; runtime tests pending |
| F12 Abuse/performance controls | **Direction closed:** direct RPC + wrapper durability and bounded retries required | B09/B10 storage/values/budgets |
| F13 Platform verification/lifecycle | **P2 boundary closed:** verified self/non-bypass; P9 owns lifecycle | B14 P9 cascade/revoke/projections |
| F14 Live-sounding P1 wording | **Closed:** D2 says P1 V3 specifies and unapplied | None |
| F15 Expiry persistence | **Closed:** failed acceptance no persistent change; successful replacement expires old row | P3 race evidence pending |
| F16 Accepted replay | **Closed:** all accepted replays, including same user, rejected | P3 evidence pending; new decision needed for any exception |
| F17 Blanket test expectations | **Closed:** truth tables, P4 self-edit exclusion, entropy/hash separation | B10 measurable budgets; concrete subcases before execution |
| F18 Retry proof/time anchor | **Expiry closed; organization retry open:** insertion+7d aligned | B08 canonical proof/narrow retry |
| F19 Offboarding/pending offers | **Current security closed; transition choice open:** fail-closed access/acceptance always | B06 exact cleanup/revoke/audit matrix |
| F20 Profile prerequisite/public onboarding | **Closed:** controlled P3 fixtures; public onboarding waits P4/P5 | B12 real lifecycle/browser acceptance |

No finding is represented as a passed runtime security check.

## 3. D1–D5 mutual consistency results

| Topic | D1 | D2 | D3 | D4 | D5 | Result |
|---|---|---|---|---|---|---|
| P2 profile writes | Excluded | No grant/policy | No profile authority | P4 one future path | ACL-03 no exception; PRV-04 P4 | Consistent |
| Helper inventory | Ten P2 named | Same predicates/twelve policies | Same scope semantics | Exact signatures/truth table | HLP/NEW-P2 tests | Consistent |
| Tenant self visibility | Verified active usable | No independent self OR | Active current scope | Same helper gate | Negative/positive splits | Consistent |
| Non-Owner delegation | Strictly lower | No direct writes | Strictly lower grant/manage | Same post-lock checks | RBAC/INV expectations | Consistent |
| Owner exception | Exact global Owner | No tenant bypass | Same-tenant guarded backend | Future P3 only | Owner tests; no UI claim | Consistent |
| Branch active/history | ≥1 active for active member; history retained | Active current visibility only | Same status matrix | Final-state validators | BR/NEW-P2/NEW-P3 splits | Consistent; B06 residual |
| Owner counter | One writer + locks + deferred | No direct counter access | Exact Owner identity/count | Complete protocol | OWN/NEW-P2 races | Consistent; runtime pending |
| Invitation expiry | Insert+7d; failed no change | Read-only P2 | P3 checks | Same implementation contract | INV/ACC corrected | Consistent |
| Accepted replay | Reject all | No token read path | Reject all | Generic unavailable | ACC-03/09 aligned | Consistent |
| Audit | Domain row event once | Private append + guards | Role assignment only | Producer/cardinality ledger | AUD corrected | Consistent; B05 residual |
| Settings | Deny until allowlist | Column denied/P3 disabled | Approved org keys only | Endpoints disabled | PRV/NEW-P3 blocked | Consistent; B07 residual |
| Abuse/performance | Direct+wrapper; values missing | Plan evidence required | No change | Same wrapper contract | Deployment blocked pending values | Consistent; B09/B10 |
| Platform | Verified self/no bypass | Self policy only | Independent grant | P9 future lifecycle | PLT/NEW-P9 phases | Consistent |
| P2 release | P1 + P2 + applicable deployment | P2 evidence list | Acceptance criteria | Live verification list | Phase-specific gates | Consistent |

## 4. Baseline and PRD/ERD/matrix reconciliation

### P1 V3

- Twelve tables, five enums, sixteen supporting indexes, two partial unique indexes, four structural functions and 5/14/37 catalog seeds remain unchanged.
- Corrected documents preserve zero P1 policies, authenticated SELECT-only grants, safe invitation projection and zero direct service_role table/column/sequence privileges.
- P2 proposes eleven safe tenant columns and no direct authenticated DML; it does not retroactively describe those as P1 properties.
- Composite FKs, canonical inviter membership, immutable identity, Auth/profile cascade + membership RESTRICT and format-only country/currency limits are preserved.
- No corrected document requires a P1 schema change. B16 records only the historical profile-phase comment mismatch.

### Product brief / Architecture v2 ERD and role matrix

- Multi-tenant reusable SaaS, active-membership organization switching, branch restriction, verified email, copyable invitations, Light(default)/Dark only, audit foundation and separate Platform Admin remain intact.
- The ERD still matches the same twelve tables and relationships; no new entity is introduced.
- The exact D3 matrix matches P1 V3; reserved `branch.delete`/`role.manage` are not treated as enabled capabilities.
- Later owner decisions supersede Architecture v2's stale direct-write/service-role examples. Owner backend exception is scoped to future P3 contracts and does not authorize transfer/additional-Owner UI.
- No future ERP module, fake record/statistic, transactional email or Saudi-only product boundary is introduced.

### Proposed P2 security architecture

D1/D2/D4 agree that P2 is read policies/helpers/invariants/private writers only. D3 supplies business truth rules; D5 classifies complete parent tests and earlier subsets. No P3 endpoint is described as existing or required to pass for P2 completion.

## 5. Complete test inventory reconciliation

- **130 unique IDs:** 93 original + 37 additional; no missing, renamed or duplicate identifiers.
- **Primary phases:** P1 9, P2 35, P3 70, P4 4, P9 2, Deployment/performance 10.
- Every row contains ID, objective, corrected expected behavior, related decision, corrected document/requirement, phase dependency, category and execution status.
- Every status is `Proposed; NOT EXECUTED; executable now: No` with prerequisites.
- Composite parent/earlier subsets, independent-session races and commit-time deferred checks are preserved.
- Overlaps are intentional distinct evidence, not duplicates. No obsolete ID was removed.
- GAP-01–GAP-10 remain analytical gaps, not extra IDs. Original Tests 1–14 and legacy S1–S5 are crosswalks, not extra IDs.
- Historical 120-statement parsing and five offline P1 regression checks remain separate historical source evidence, not live test passes.

## 6. Discrepancy report

| Discrepancy | Owner | Impact | Resolution requirement |
|---|---|---|---|
| No live P1/P2 evidence | Project owner/database operator | Cannot claim execution/security readiness | Complete B01 and later phase gates with actual results |
| Hosted definer/Auth feasibility unknown | Database/Auth security architects | Cannot safely prepare exact P2 functions | Resolve B02/B03/B04 before P2 SQL |
| Audit values incomplete | Database/security architect | Cannot write/test exact event ledger | Resolve B05 |
| Offboarding transitions incomplete | Product owner/backend architect | Cannot implement complete P3 cleanup/offers behavior | Resolve B06 |
| Settings/retry/abuse/performance values missing | Named owners in blocker register | Affected P3/deployment parents cannot pass | Resolve B07–B10 |
| Country/currency catalogue absent | Product/backend | Public onboarding validation incomplete | Resolve B11 |
| Future P4/P9/Owner UI/browser scope | Named future-phase owners | No future workflow acceptance claim | Resolve B12–B15/B17 at separate gates |
| P1 profile comment wording | Documentation maintainer | Low historical documentation mismatch only | Optional B16 separate clarification; no SQL change here |

There are **no remaining undocumented contradictions between corrected D1–D5**. The items above are disclosed blockers or preserved historical-source discrepancies, not silently inconsistent corrected requirements.

## 7. Source integrity and execution boundary

Original D1–D5/P1 fingerprints were checked before correction and are required to match again at package delivery. No SQL, migration, database object, policy, trigger, function, grant, Auth setting, application source or Lovable Cloud setting was changed. No database, Auth, application or implementation test was executed. Static document checks only support this documentary conclusion.

## 8. Audit conclusion

The corrected package is internally consistent and traceable to the approved recommendations and verified baseline. It is suitable for a separate owner documentary review. P1 and P2 execution, P2 SQL preparation, P3/P4/P9 implementation and every runtime/security acceptance claim remain separately blocked.
