# Logical Education ERP — B18 Owner Review Evidence Digest

**Version:** V1 · 9 November 2026 (UTC)  
**Authority:** owner upload `Logical_Education_ERP_-_B18_Owner_Review_pasted.md`; read-only documentary review and creation of this digest only.  
**Disposition:** inventory, decision coverage, test-row synchronization and P1 baseline verified; **B18 closure supported only with explicit acceptance of the qualifications below, or separately authorized documentary clarification first.** B18 is not marked closed by this digest. No implementation gate is opened.

## 1. Verified document inventory

All paths below are relative to `docs/p2/corrected-v1/`. All twelve pre-existing package files exist and are nonempty. D1–D5 each identify `D#_Corrected_V1` in opening metadata and contain a Corrected V1 change history. Supporting documents identify V1; the matrix identifies V1 corrected against D1–D5. The README lists all eleven required deliverables. No required document is missing.

| Exact filename | Verified version | Lines | Bytes |
|---|---|---:|---:|
| `D1_Corrected_V1_Security_Architecture.md` | D1_Corrected_V1 | 201 | 22,578 |
| `D2_Corrected_V1_RLS_Policy_Matrix.md` | D2_Corrected_V1 | 115 | 14,447 |
| `D3_Corrected_V1_Role_Permission_Branch_Matrix.md` | D3_Corrected_V1 | 194 | 16,178 |
| `D4_Corrected_V1_Secure_Function_Specification.md` | D4_Corrected_V1 | 265 | 27,556 |
| `D5_Corrected_V1_Security_Test_Plan.md` | D5_Corrected_V1 | 274 | 69,911 |
| `AD01-AD12_S01-S10_Approved_Decision_Register_V1.md` | V1 | 137 | 14,980 |
| `Complete_130_Test_Traceability_Matrix_V1.md` | V1 | 195 | 92,949 |
| `D1-D5_Change_Log_V1.md` | V1 | 103 | 11,717 |
| `Cross_Document_Consistency_Audit_V1.md` | V1 | 124 | 13,163 |
| `Remaining_Issues_and_Blocker_Register_V1.md` | V1 | 39 | 7,698 |
| `P1_P2_Readiness_Assessment_V1.md` | V1 | 134 | 9,256 |
| `README.md` | Package V1 | 25 | 1,318 |

Raw-byte SHA-256 identifies the exact D1–D5 reviewed:

```text
D1 659aa0ff209648ea8b98ba4f8dfc18af077c9c5d566d51be95864ffe3a3945d8
D2 afa6960fcca672dc5ae799b0b8f05611cbaae755ccd83bf0e4017cfa8236284e
D3 0245a7988a67ff0d22d0faef96833aa292dd625bc6a6d245bd95dc989840914c
D4 a2d6252f8a1be5683c88192efc33d03a68a6ec0a78144bb4fb648686e389f8d0
D5 2cd1a1e0946516c5670c11ec22f11f184c291b28258e3ce6fd69d2a4016ff9c6
Matrix 9a4e436cd329b603229ff042beeebb5f9095666c01f066407827d6744f0d49cc
```

## 2. Key security requirements

| Document | Most important requirements | Evidence |
|---|---|---|
| D1 — Architecture | `auth.uid()` is ordinary identity; authoritative current verification plus active, usable tenant/member/role/branch context. No Platform Admin tenant bypass. P2 read/invariant/private-audit primitives only; P3 business workflows, P4 profile lifecycle, P9 platform lifecycle. Tenant-first Owner locks, sole counter writer, immediate last-Owner protection and deferred actual/stored equality. | §§1–6, 8–9, 12 |
| D2 — Policy/ACL matrix | Exactly twelve proposed authenticated SELECT policies; zero direct authenticated P2 INSERT/UPDATE/DELETE/TRUNCATE. Eleven safe tenant columns; invitation hash denied. Self-only profile reads, verified-self platform reads, parent-plus-branch join visibility. Signature-specific facade execution; private dependencies and service_role receive no application privileges. | §§1–4; twelve-table and policy inventories |
| D3 — Role/branch matrix | Preserve five roles, fourteen permissions and thirty-seven mappings. Permission checks are mandatory; rank is additive. Non-Owners delegate/manage strictly lower roles, including Admin-to-Admin denial. Only exact global Owner has the guarded Owner exception. Custom roles are same-tenant, compatible-scope, enabled-permission subsets; active assigned branches confer authority, historical links do not. Reserved capabilities and Owner UI are not enabled. | §§1–8; platform independence §9 |
| D4 — Function contracts | Fixed empty search path, qualified objects, no dynamic SQL/arbitrary actor or row oracle. Conditional least-capability owner model requires hosted proof. Ten P2 boolean facades; one P4 last-tenant helper; private dependencies. One transaction per transition, common lock order and fresh post-wait authorization. Future invitations use ≥32 CSPRNG bytes, hash-only storage, insertion-time +7 days, generic failures, universal accepted replay rejection and failed-expiry rollback. Single domain-row audit producer. | §§1–4, 7–10 |
| D5 — Evidence plan | All 130 parents are proposed/unexecuted. Real JWT/direct PostgREST, positive and negative controls, independent sessions and commit-time deferred checks are required. ACL denial is not proof of RLS filtering; privileged harnesses must reach guards. Counter/audit rollback and phase-specific acceptance must be proven. P2 primitive races/measurements cannot be deferred to future workflows. | §§1–2, 6–9, 12–15; qualifications in §5 below |

These are documentary requirements, not evidence that controls exist or work.

## 3. Decision and test traceability

The register contains all **12 AD records and 10 S records**, approved as **architecture direction only**. Abbreviations such as `AD04/12` and `S03/04/05` expand to individual IDs; literal-token searches alone would incorrectly report missing AD12/S04. All 22 decisions appear in the test mappings after shorthand normalization; no out-of-range decision reference was found.

| Decision group | Consistent substantive representation |
|---|---|
| AD01 / S07 | P2 profile self-read only; P4 creation/write/theme/hint; controlled initialized P3 profiles (D1 §1, D2 §5, D4 §8, ACL-03/PRV-04/NEW-P4-01). |
| AD02–AD04 | Ten caller facades, private dependencies, hosted owner/RLS gate and authoritative verification (D1 §§2–3, D2 §§1/3–4, D4 §§2–3, HLP/NEW-P2). |
| AD05–AD06 / S06 | Owner serialization/count/final-state rules; active versus historical branch grants; offboarding parameters deferred (D1 §§5–6, D3 §§3/7, D4 §§3–4/6/8, OWN/BR/NEW-P2). |
| AD07 / S01–S02 | P2/P3 boundary; single row-event producer; audit/catalog UPDATE/DELETE/TRUNCATE protection (D1 §§7–8, D2 §§2/5, D4 §§3–4, AUD/NEW-P2-05/11). |
| AD08 | Strict-lower delegation, exact Owner exception and custom subsets; no Owner UI authority (D3 §§4/8, D4 §§7–8, RBAC/NEW-P3-06/07). |
| AD09 / S09 | Settings denied until approved organization-level allowlist (D2 §5, D3 §5, D4 §5, PRV-03/NEW-P3-03). |
| AD10 / S03–S05 / S08 | Failed-expiry rollback, universal accepted replay denial, insertion +7d, unresolved organization retry proof and durable direct-RPC/wrapper controls (D1 §7, D4 §§5/7/9, ACC/LIFE/DEP/PERF). |
| AD11 / S10 | Status-count is distinct from verified access; recovery/erasure separate, no RESTRICT bypass (D1 §6, D4 §§2/8, LIFE-01/NEW-P1-06/GAP-08). |
| AD12 | Verified platform self-status, no tenant bypass; P9-only verified-UUID grant/revoke/cascade design (D1 §9, D3 §9, D4 §8, PLT/NEW-P9-01). |

**Independent offline verification:** pipe-table parsing selected only full parent rows: eight cells in the matrix and seven in D5. Each has **130 rows, 130 unique IDs, zero duplicates, zero empty required cells and identical ID sets**. All six shared non-ID fields match exactly for every ID: **780 comparisons, zero differences**. Every matrix row has a requirement reference, decision reference, declared phase/prerequisite, category and unexecuted status.

| Primary phase recorded | Parent tests |
|---|---:|
| P1 | 9 |
| P2 | 35 |
| P3 | 70 |
| P4, mandatory earlier subsets | 4 |
| P9 | 2 |
| Deployment/performance | 10 |
| **Total** | **130** |

Original D5 independently yields **93 unique original IDs**, all retained. The remaining **37 additional IDs** match both historical preparation/reconciliation reports: NEW-P1 7, NEW-P2 12, NEW-P3 12, NEW-P4 1, NEW-P9 1, NEW-DEP 4. GAP-01–GAP-10 and legacy crosswalks are not additional parents. Preserved IDs do not imply unchanged expectations: 27 original expected-behavior cells were textually corrected.

All 130 status cells say **Proposed; NOT EXECUTED; executable now: No**. Phase counts establish the recorded classification, not that every dependency cell is unambiguous; see §5. Requirement references are narrative sections/ranges, not machine-resolvable requirement IDs. Seven new P1 rows cite P1 V3/schema and D5 prerequisites rather than a D1–D4 section, appropriately for their baseline purpose. Exhaustive semantic coverage of every cited subsection and historical additional-test expectation is not proven by row equality.

## 4. P1 baseline integrity and authorization

Raw-byte SHA-256 matches the recorded change-log/audit baselines:

```text
docs/p1/database-foundation.review.sql — FINAL REVIEW DRAFT v3, 473 lines
Expected: deebaca7ea8ea7e58fb2b96af74ac64f1d049fc1a4447ed5fa459f058504535a
Observed: deebaca7ea8ea7e58fb2b96af74ac64f1d049fc1a4447ed5fa459f058504535a

docs/p1/README.md — schema/ERD review v3
Expected: ab4b8c65b18877d7b4727afed57fff98c6779e79865048fc0844582fa6818788
Observed: ab4b8c65b18877d7b4727afed57fff98c6779e79865048fc0844582fa6818788
```

The five original D1–D5 hashes also match the change-log ledger. Decision-preparation, final reconciliation and 838-line product-brief hashes match the audit ledger: **10 fingerprinted baselines checked, 10 matches**. The product brief was located in the read-only upload mirror, not at a bare project-root filename. Hash matching establishes current byte identity, not that files were never temporarily changed.

**Documentary-ready** means the exact P1 V3 requirements and schema review are preserved and available for review. It does **not** authorize executing SQL. The draft specifies twelve RLS-enabled tables with zero policies, authenticated SELECT-only privileges, no direct service_role table/sequence privileges, catalog-only 5/14/37 seeds and deferred Owner/business/profile workflows. These remain draft properties, not fresh hosted observations.

P1 execution still requires separate approval naming the exact V3 fingerprint, dedicated Dev/GitHub reconfirmation, fresh read-only drift/extension/owner/inheritance/default-privilege preflight, reviewed transaction/recovery/fixture plan, migration-tool application, actual schema/ERD/ACL/RLS/structural results and explicit owner acceptance. Historical parser/five offline regression results were **not rerun** and are not runtime security evidence.

## 5. Consistency audit, discrepancies and incomplete material

The existing audit reports F01–F20 reconciled at the documentary level, preserving unresolved implementation parameters, and concludes ready for separate review but not SQL preparation/execution or runtime acceptance. Core phase/identity/delegation/branch/Owner/audit/expiry/platform directions support that boundary. **Its stronger statement that no undocumented contradictions remain needs qualification:** independent review found the following synchronized wording issues in D5 and the companion matrix. Matching rows can repeat the same ambiguity.

| Review issue | Exact evidence | Impact / clarification needed |
|---|---|---|
| R1 — Owner minimum wording conflates tenant states | D5 line 194; matrix line 128; NEW-P2-06 expected behavior ends with drift **or zero-Owner activation** rejected “for active and inactive tenants.” D1 §6 and D4 §4 require equality for all tenants but minimum-one only for active tenants. | Wording should separate drift rejection for every tenant from rejection of activation with zero Owners. Suspended/archived tenants require stored=actual, not minimum-one. Governing direction is clear; row wording is not. |
| R2 — P3 dependencies on P2 parents | OWN-07/08/11: D5 lines 99–100/103, matrix 65–66/69; AUD-02/03/04: D5 146–148, matrix 94–96. P2/G2 cells append “applicable P3 Owner RPC” or “applicable P3 mutation.” | If mandatory, these conflict with P2 primitive evidence before P3. Specify controlled P2 fixture/primitive harness; identify P3 repetitions as later supplementary evidence, not prerequisites. No phase may be reordered on this wording. |
| R3 — Overgeneralized deployment dependencies | INV-08, DEP-01–03, NEW-DEP-01–03: D5 118/170–172/215–217; matrix 78/112–114/149–151. Common cells include “P2 plans/primitive stress” despite future token/UI/wrapper objectives. | Identify each actual feature prerequisite and any genuine earlier subset. Preserve applicable P2 plan/stress requirements on PERF-01/02 and NEW-DEP-04. Recorded count of ten deployment parents is verified; exact phase semantics need clarification. |
| B16 — Preserved historical profile-phase wording | P1 SQL header lines 4–5 says P2 profile lifecycle; P1 README line 49 says P2/P4; corrected D1/D4 make P4 normative. | Known low-impact historical comment discrepancy, not schema change. Separate permission is needed for any P1 comment clarification. |

**No source document was corrected in this review.** R1–R3 are evidence-plan/documentary issues, not executed vulnerabilities or failed security tests. They qualify the readiness assessment's “internally reconciled” wording; they do not contradict its **not authorized/not ready for SQL** conclusion. They should accompany any B18 acceptance, or be resolved under a separate documentation-only authorization before unconditional acceptance.

No mandatory package file is absent or empty. D4's exact private signatures/ACL/dependency/trigger graph, hosted Auth/owner feasibility and concrete audit ledger are intentionally incomplete under B02–B05. Offboarding/settings/retry/abuse/budgets/catalogue/profile/recovery/P9/browser contracts remain explicitly deferred below. Their disclosure supports documentary review, not implementation completeness. The prior audit also reports no separate formal PRD/Saudi specification; this digest does not claim a fresh exhaustive search for such documents.

## 6. B01–B18 outstanding issues and gates

All issues retain the owners/resolutions in the blocker register. This digest closes none automatically.

| ID | Outstanding resolution | Gate / urgency |
|---|---|---|
| B01 | Exact P1 approval, fresh Dev/GitHub/preflight, application and actual acceptance evidence | Immediate P1 execution/acceptance; blocks all P2 runtime work |
| B02 | Hosted non-login owner/nonrecursive RLS feasibility and separately reviewed fallback blast radius | Immediate before P2 SQL preparation |
| B03 | Authoritative verification/current-email/ban/session/deletion lookup contract | Immediate before P2 SQL; later P3/P4 identity evidence |
| B04 | Full private signatures, P1/P2 owners/capabilities/ACLs, triggers/order/recursion/dependency graph | Immediate before P2 SQL preparation |
| B05 | Exact audit action/entity/semantic events, counts, metadata/no-op and maintenance ledger | Immediate before P2 SQL and audit acceptance |
| B06 | Per-status retain/clear/offboarding/pending-offer transitions and audit effects | Future P3 workflows; fail-closed access/acceptance already normative |
| B07 | Organization settings keys/types/nesting/projection/patch and role behavior | Future P3 settings only; current direct-column denial remains |
| B08 | Canonical immutable original-request proof or narrower organization retry contract | Future P3 creation retry; new storage needs separate schema review |
| B09 | Durable direct-RPC/wrapper abuse controls, keys/counts/windows/input bounds/failure policy | Before exposed P3 endpoints/deployment; cannot waive applicable P2 evidence |
| B10 | Numeric P2/P3 workload/latency/throughput/timing/error thresholds, schedules/retry/backoff | Cross-phase: P2 measurement/preparation checklist and acceptance; later P3/deployment |
| B11 | Versioned authoritative country/currency catalogue and concrete cases | Future P3/public onboarding; P1 format checks alone insufficient |
| B12 | One P4 profile-write/init/replay path, optional status projection and real onboarding | Future P4/P5 |
| B13 | Sole-Owner recovery and lawful retention/erasure without FK/counter bypass | Future P4/launch operations |
| B14 | Verified-UUID platform grant/revoke/reverification/bootstrap/cascade audit/projections | Future P9 only |
| B15 | Exact Owner backend endpoint inventory and separately approved UI scope | Future P3 Owner operations/UI; AD08 is not blanket authority |
| B16 | Optional historical P1 profile-phase comment clarification | Low documentary discrepancy; no schema impact; separate permission |
| B17 | Separately approved browser/session/theme/enumeration/recovery cases outside 130 parents | Future P4/P5/P10 application acceptance |
| B18 | Explicit corrected-package review/acceptance, with R1–R3 disposition | Immediate documentary gate; owner reports readiness/blocker review, not unconditional full-package acceptance |

B01/B18 and B02–B05 are immediate preparation dependencies; B10 has a mandatory P2 component, not merely a future blocker. B06–B09/B11/B15 can remain future requirements only while affected P3 operations are not exposed. B12–B14/B17 remain later-phase gates. Closing B18 alone does not close any of them.

## 7. B18 owner-review checklist

- [x] Exact D1–D5 filenames/versions and all supporting files verified in place.
- [x] All AD01–AD12/S01–S10 represented as approved direction, not execution authority.
- [x] 130 unique IDs, 93+37 provenance, row synchronization, requirement/phase fields and all-unexecuted status verified.
- [x] P1 V3/schema and original D1–D5 baseline fingerprints matched.
- [x] Audit/readiness/blockers reviewed; R1–R3 newly disclosed and B16 preserved.
- [x] Documentary readiness distinguished from execution and runtime acceptance.
- [ ] Owner explicitly accepts the exact corrected package **with R1–R3 qualifications**, or separately authorizes clarification and reviews resulting versions before acceptance.
- [ ] Owner records B18 disposition and acknowledges B01–B17 remain open as applicable.
- [ ] Any subsequent preparation, preflight or execution receives its own explicit scope-specific authorization.

The upload states that the owner reviewed the readiness assessment and blocker register. It requests evidence **to support** B18 closure; it does not itself supply unconditional acceptance of the complete D1–D5 package. Existing source B18/checklists remain untouched and retain their historical review-pending wording.

## 8. Recommended next gate and limitations

**Next gate: owner disposition of this digest and R1–R3.** Prefer separately authorized documentation-only clarification of the affected D5/matrix/readiness/audit wording, followed by review of the exact clarified package and explicit B18 acceptance. Qualified documentary acceptance is an alternative only if the owner expressly records these issues; neither option grants SQL authority.

After that, P1 exact-V3 execution approval/preflight/acceptance remains separate under B01. P2 SQL preparation still requires accepted P1, resolved B02–B05, approved relevant B10 requirements and explicit preparation-only permission. No P2 draft or implementation is authorized here.

Verification used actual files, full-document review, independent read-only audits, Markdown parsing and raw-byte hashing. No hosted database/Auth/GitHub state, effective live ACLs or runtime security was checked. No SQL, migration, database/settings mutation, application change or implementation test was performed. Static documentary checks do not mark any of the 130 tests executed/passed. Historical authorization context is the register and owner conversation/uploads, not a new hosted verification.

This review preserves all original/corrected source documents and P1 SQL; only this new digest and the task roadmap are written. No Files copy was requested. **Output:** `docs/p2/corrected-v1/B18_Owner_Review_Evidence_Digest_V1.md`. Work stops at documentary delivery.