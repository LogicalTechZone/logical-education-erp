# Logical Education ERP — Remaining Issues and Blocker Register

**Version:** V1 · 9 November 2026 (UTC)  
**Scope:** issues remaining after D1–D5 Corrected V1 and approval of AD01–AD12/S01–S10 recommendations.  
**Meaning:** “blocker” prevents the named next gate; it does not necessarily prevent documentary review. No issue below is silently resolved or marked implemented/tested.

| ID | Owner | Unresolved issue and impact | Required resolution | Blocks / phase |
|---|---|---|---|---|
| B01 | Project owner + database operator | P1 V3 remains unapplied; no live schema/ACL/RLS baseline or accepted P1 evidence exists | Separate exact-V3 execution approval, GitHub/Dev reconfirmation, fresh read-only preflight, migration-tool application, actual schema/ERD/tests and owner acceptance | All runtime/P2 work; P1 gate |
| B02 | Database/security architect + project owner | Preferred non-login owner split and non-recursive RLS behavior are not hosted-proven; broad fallback blast radius unknown | Authorized read-only owner/role/inheritance/FORCE RLS/bypass inspection; exact role/capability/dependency ledger; separate approval for any table-owner/BYPASSRLS fallback | P2 SQL preparation/execution; AD03 |
| B03 | Auth/security architect | Exact authoritative verification field and current-email/change/ban/session/deleted-user semantics are unverified | Authorized Auth-representation preflight and exact private current-user lookup/revalidation contract; real-JWT test plan | P2 SQL and P3/P4 identity acceptance; AD04 |
| B04 | Database/security architect | Exact private function signatures, nested dependencies, trigger order/events/recursion and owner capabilities are not yet SQL-reviewable | Complete full-signature function/trigger/ACL/schema/type/sequence inventory, including all four P1 functions and final dependency graph | P2 SQL preparation; AD02/03/05/06 |
| B05 | Database/security architect + project owner | S01 approves one producer but not exact action/entity strings, per-transition/workflow counts, semantic-event list or metadata fields | Approve concrete audit event/metadata/context/no-op ledger and UPDATE/DELETE/TRUNCATE maintenance boundary | P2 SQL and AUD/NEW-P2-11; S01/S02/GAP-10 |
| B06 | Product owner + backend/security architect | S06 does not choose exact per-status link retain/clear behavior, proactive pending-offer revoke versus pending-but-unusable handling, or corresponding audit effects | Approve status/transition matrix for invited/active/suspended/removed memberships and pending/expired/accepted/revoked invitations; retain fail-closed acceptance throughout | P3 offboarding/branch workflows; AD06/S06 |
| B07 | Product owner | No organization settings keys/types/nesting/projection/patch rules are approved; usable settings cannot be exposed safely | Supply exact organization-level allowlist and role-specific read/update behavior; Branch Manager read only approved org-level keys | P3 settings endpoints and PRV-03/NEW-P3-03; AD09/S09 |
| B08 | Product owner + backend architect | Organization creation retry lacks canonical original-request proof or a narrower retry contract; current edited tenant cannot prove original payload equality | Select canonical fields + immutable proof (separate schema approval if stored) or approve narrow retry semantics and safe errors | P3 create retry; LIFE-02/NEW-P3-02; AD10/S05 |
| B09 | Security/backend architect + project owner | Durable abuse-control storage/service and exact identity keys, counts, windows, failure policy and input bounds are absent; wrapper-only limits are bypassable | Select and approve controls covering direct RPC and wrappers; define restart/concurrency/failure behavior and bounded inputs; separately review new storage/service | Exposed P3 endpoints; DEP-03/NEW-DEP-02; AD10/S08 |
| B10 | Security/performance architect + project owner | Numeric volume/latency/throughput budgets, concurrency schedules, retry counts/backoff and measurable timing/error-equivalence thresholds are missing | Approve measurable P2 primitive and P3/deployment budgets and bounded fresh-reauthorization retry policy | PERF/NEW-DEP-04 and deployment acceptance; S08/GAP-05 |
| B11 | Product owner + backend architect | P1 validates only country/currency format, not authoritative catalogue membership | Select/version authoritative ISO validation source and valid/invalid test cases before public onboarding | P3/public onboarding; NEW-P3-01/GAP-09 |
| B12 | Auth/product architect | P4 self-update mechanism and optional offboarded-account projection are not selected; real public onboarding cannot be claimed from controlled P3 profiles | P4 design chooses one self-write path, profile initialization/replay and any minimal status projection; execute real signup/onboarding later | P4/P5 and NEW-P4-01/GAP-01/02/03 |
| B13 | Product owner + compliance/operations | Status-based Owner count does not ensure a usable verified sole Owner; retained memberships block erasure | Separate sole-Owner recovery and legal retention/erasure runbooks with ownership preservation and privacy review; no FK/counter bypass | P4/future launch operations; AD11/S10/GAP-08 |
| B14 | Platform/security architect + project owner | P9 grant/revoke/re-verification/repeat-bootstrap/Auth-cascade audit and operation projections are unspecified | Separate P9 verified-UUID lifecycle design, exact insert/delete/audit behavior and tests; no tenant/email frontend path | P9; AD12/NEW-P9-01 |
| B15 | Project owner + backend architect | AD08 defines hierarchy, not blanket approval for every future Owner endpoint or any transfer/additional-Owner UI | Separately approve exact P3 backend endpoint inventory and later UI scope; retain last-Owner controls | P3 Owner workflows/UI; AD08/GAP-06 |
| B16 | Project owner + documentation maintainer | P1 SQL header says P2 profile lifecycle while corrected D1/D4 assign it to P4; schema README says P2/P4 | Optional separate P1 documentation-only comment clarification; do not alter SQL under this package. Corrected D1–D5 use P4 as normative | Low documentary discrepancy; no schema impact; AD01 |
| B17 | Application/security architect | GAP-01–GAP-03 browser/session/theme/enumeration/recovery coverage is outside the 130 parent IDs | Add separately approved application/browser/deployment cases in P4/P5/P10; do not claim coverage from PRV-04 or signed-out checks | Application acceptance |
| B18 | Project owner | Corrected documents have not yet been reviewed/accepted as a package | Review exact corrected files, decision register, matrix, audit and blockers; separately authorize any next documentation or SQL step | P2 SQL preparation gate |

## Dependency notes

- B02–B05 jointly block safe P2 SQL; resolving one does not close the others.
- B06/B08/B09/B11 can remain future P3 requirements only while no affected endpoint is exposed; they cannot be waived in claims about those workflows.
- B07 blocks settings functionality only, not the P2 safe-column denial itself.
- B09/B10 do not remove mandatory P2 plan/primitive-stress evidence; numeric P2 budgets must be approved before that evidence can be accepted.
- B12/B13/B14/B15/B17 are future-phase gates and do not change the P1 schema or authorize phase reordering.
- B16 is a preserved historical comment mismatch, not permission to edit P1 or a contradiction in corrected D1–D5.

## Execution disposition

No SQL, migrations, database objects, RLS policies, triggers, functions, grants, Auth settings, application source or Lovable Cloud settings were changed. No database, Auth, application or implementation tests were executed. All 130 proposed parent tests remain NOT EXECUTED.
