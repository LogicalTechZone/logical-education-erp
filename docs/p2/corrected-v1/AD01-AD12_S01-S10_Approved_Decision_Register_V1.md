# Logical Education ERP — Approved AD01–AD12 and S01–S10 Decision Register

**Version:** V1 · 9 November 2026 (UTC)  
**Authority:** project-owner upload `Logical_Education_ERP_-_D1-D5_Controlled_pasted.md`, explicitly approving the proposed AD01–AD12 and S01–S10 recommendations and authorizing D1–D5 documentation correction only.  
**Status convention:** **APPROVED — ARCHITECTURE DIRECTION** means the recommendation is normative for corrected documents. It does not mean implemented, executed, hosted-feasible, tested or approved for SQL. Fields the recommendation expressly leaves unresolved remain blockers.

## 1. Source precedence and unchanged gates

1. Latest explicit owner approval and execution limits.
2. Existing binding product/security requirements and exact unapplied P1 V3 for P1 facts.
3. Corrected D1–D5 V1 as the reconciled P2/P3/P4/P9 planning contract.
4. Original D1–D5, reconciliation and decision-preparation reports as historical sources.

This approval supersedes historical “Proposed/Pending” labels for the 22 recommendations. It does **not** approve P1 execution, P2 SQL preparation/execution, P3/P4/P9 implementation, new storage, Auth changes, application changes or any test claim. P1 V3 and all original documents remain unchanged.

## 2. AD decision records

### AD01 — Profile self-write ownership

**Approved direction:** P2 installs self-only profile SELECT only. Profile creation, all self UPDATE grants/policies or RPC, theme and last-tenant writes belong wholly to P4. `p2_is_valid_last_tenant` moves to P4.  
**Dependencies/implications:** P3 tests use controlled pre-existing profiles; public self-service onboarding waits for P4/P5. P2 has zero direct authenticated DML.  
**Residual:** P4 must choose exactly one self-update path and any minimal offboarded-account projection. P1 header wording remains a documentary discrepancy only.  
**Corrected references:** D1 §§1–4/10; D2 §§1–5; D4 §§2–3/8; D5 ACL-03/PRV-04/NEW-P4-01.  
**Status:** APPROVED — ARCHITECTURE DIRECTION.

### AD02 — Helper names, signatures and EXECUTE grants

**Approved direction:** adopt ten current-caller P2 boolean facades: current verification, active member, organization permission, tenant permission, branch permission, any permission, role/membership/invitation visibility and platform self-status. Add `p2_has_tenant_permission`; remove undefined aliases. Internal Auth/rank/subset/branch-set routines remain private. Every tenant-bearing helper fails closed for unverified/inactive context.  
**Dependencies/implications:** signature-specific ACLs, schema USAGE and exact owner/dependency graph are mandatory. `p2_has_any_permission` is catalog-only and derives from active usable tenant contexts; it never authorizes a supplied tenant.  
**Residual:** private signatures, complete dependency graph and full-signature runtime ACL inventory must appear in final P2 SQL review.  
**Corrected references:** D1 §§2–3; D2 §§1–4; D3 §§3–6; D4 §§2–3.  
**Status:** APPROVED — ARCHITECTURE DIRECTION.

### AD03 — SECURITY DEFINER ownership and RLS model

**Approved direction:** prefer separate non-login lookup and invariant/audit owners with exact least capabilities, neither service_role nor inheritable by application roles. Require fresh hosted feasibility evidence; any table-owner/BYPASSRLS fallback needs separate review of exact blast radius.  
**Dependencies/implications:** SELECT alone does not avoid RLS recursion. Ownership, FORCE RLS, bypass, inheritance and nested EXECUTE must be evaluated together. Lookup owner gets no DML; audit writer gets no audit mutation rights.  
**Residual:** actual hosted roles, effective non-recursive mechanism and any fallback remain unresolved and block P2 SQL preparation.  
**Corrected references:** D1 §3; D2 §4; D4 §§1–3/10.  
**Status:** APPROVED — ARCHITECTURE DIRECTION.

### AD04 — Verified-email source of truth

**Approved direction:** use a private current-user Auth-row lookup exposed only as a verification boolean. Never trust editable metadata/browser state. Every tenant and platform-status helper uses the same gate; mutation routines reread authoritative state after waits.  
**Dependencies/implications:** unverified/currently invalid accounts lose tenant access; Owner counters do not silently recalculate on verification changes.  
**Residual:** exact hosted field and current-email/change/ban/session/deleted-user semantics require authorized preflight and P4/deployment evidence.  
**Corrected references:** D1 §§2/9; D2 §§1–3; D4 §§2–4/7–9.  
**Status:** APPROVED — ARCHITECTURE DIRECTION.

### AD05 — Owner counter, locks and deferred validation

**Approved direction:** tenant-first trusted writers; stable member lock order; one atomic counter-delta writer; immediate active-tenant 1→0 rejection; deferred final-state reread/count equality; activation and counter-only changes trigger validation; explicit recursion/order controls; bounded full-transaction retry with fresh authorization.  
**Dependencies/implications:** independent two-session P2 primitive evidence is mandatory before P3 workflows. Active tenants need ≥1 Owner; all tenants need stored=actual.  
**Residual:** exact SQL trigger graph and numeric retry/performance values require final review; runtime correctness is unproven.  
**Corrected references:** D1 §6; D3 §7; D4 §§1/3–4/8; D5 OWN/NEW-P2-06/07.  
**Status:** APPROVED — ARCHITECTURE DIRECTION.

### AD06 — Branch lifecycle and historical assignments

**Approved direction:** organization rows have zero links; active branch memberships have nonempty links and at least one active branch; all new/replacement grants and new pending offers are active. Inactive retained links give no authority; accepted/revoked/expired history retains links. Branch deactivation is rejected if it leaves an active member without an active assignment; atomic offboarding alternative needs separate approval.  
**Dependencies/implications:** validators use final state and must not require historical rows or inviters to remain active forever. Acceptance always rechecks current branch/inviter authority.  
**Residual:** exact per-status offboarding cleanup and proactive pending-offer transitions remain S06 P3 blockers.  
**Corrected references:** D1 §5; D2 §§1–3; D3 §§3/5–7; D4 §§3/6–8.  
**Status:** APPROVED — ARCHITECTURE DIRECTION.

### AD07 — Invitation, audit and phase boundary

**Approved direction:** P2 owns read isolation, authorization predicates, invariant guards and private audit writers only. P3 owns token/create/expire/accept/revoke and membership workflows. Domain triggers are the sole row-transition event producer; RPCs only append enumerated semantic events. Audit/system catalogs receive UPDATE/DELETE/TRUNCATE protection.  
**Dependencies/implications:** P2 release cannot claim working invitations or require future-phase parent tests to pass. Counter-only updates emit no settings event.  
**Residual:** exact action/entity/event-count and metadata ledgers remain S01/S02 pre-SQL blockers.  
**Corrected references:** D1 §§1/7–8/12; D2 §§2–5; D4 §§1/3–9; D5 §13.  
**Status:** APPROVED — ARCHITECTURE DIRECTION.

### AD08 — Role delegation and Owner exceptions

**Approved direction:** every non-Owner grants/manages strictly lower roles only; Admin cannot grant/manage equal Admin. Exact global Owner alone has the same-tenant Owner exception subject to last-Owner rules. Custom target permissions must be a subset of current enabled delegable actor keys excluding reserved capabilities. Organization promotion and relinquishment clear branch links.  
**Dependencies/implications:** checks apply at create/assignment/acceptance and after waits. Future P3 backend contracts may use the Owner exception; no transfer/additional-Owner UI or reserved feature is authorized.  
**Residual:** exact future P3 endpoint inventory requires separate P3 approval; custom-role management remains disabled.  
**Corrected references:** D1 §§5–6; D3 §§4/6–8; D4 §§3/7–8.  
**Status:** APPROVED — ARCHITECTURE DIRECTION.

### AD09 — Organization settings projection

**Approved direction:** direct settings JSON remains denied. Future P3 safe read/update RPCs return/change only explicitly approved organization-level keys; Branch Manager receives only those same approved org-level read keys, never branch-private payloads.  
**Dependencies/implications:** no key/type is inferred from the generic SaaS brief or Saudi validation use case.  
**Residual:** owner must supply exact keys, types, nesting, projection and patch rules. Until then settings endpoints and positive workflow tests remain disabled/blocked.  
**Corrected references:** D1 §10; D2 §§2/5; D3 §§2/5; D4 §5.  
**Status:** APPROVED — ARCHITECTURE DIRECTION.

### AD10 — Abuse control, retry and replay contract

**Approved direction:** durable controls must cover direct RPC and wrappers before exposed P3 endpoints. Reject all accepted-token replays. Failed expired acceptance persists no expiry/audit. Successful replacement expires old elapsed pending rows atomically. Expiry is authoritative server insertion timestamp + exactly seven days, with current-time checks after waits.  
**Dependencies/implications:** no in-memory durability claim; no failed transaction both rolls back and persists expiry.  
**Residual:** organization original-request proof versus narrower retry contract; abuse storage/service, limits, identity keys, windows, failure behavior, input bounds and numeric performance/retry budgets remain unresolved.  
**Corrected references:** D1 §§7/10–12; D4 §§5/7/9; D5 INV/ACC/LIFE/DEP/PERF.  
**Status:** APPROVED — ARCHITECTURE DIRECTION.

### AD11 — Owner account recovery and hard erasure

**Approved direction:** retain active-membership Owner invariant; do not recalculate counters from verification state. Define locked-out Owner recovery and personal-data erasure separately outside P2/P3.  
**Dependencies/implications:** active Owner count is not proof of a usable verified account. Retained memberships continue to block Auth hard deletion through RESTRICT.  
**Residual:** operational recovery and legal retention/erasure runbooks remain future P4/compliance work.  
**Corrected references:** D1 §§6/10; D4 §§2/8; D5 LIFE/NEW-P1-06/GAP-08.  
**Status:** APPROVED — ARCHITECTURE DIRECTION.

### AD12 — P9 Platform Admin lifecycle

**Approved direction:** P2 exposes verified self-status/read only with no tenant bypass. P9 alone resolves `logicaltechzoneofficial@gmail.com` to its verified immutable UUID and performs controlled insert/delete grant/revoke with audit and explicit Auth-cascade behavior. No P2 status column, seed or grant.  
**Dependencies/implications:** tenant Owner/Admin and platform authority remain independent.  
**Residual:** P9 revoke/re-verification/repeat-bootstrap/cascade-audit mechanics and operation projections require separate P9 design/approval.  
**Corrected references:** D1 §9; D2 §§2–5; D3 §9; D4 §§2/8.  
**Status:** APPROVED — ARCHITECTURE DIRECTION.

## 3. Subordinate security decision records

| ID | Approved direction | Residual dependency / impact | Status |
|---|---|---|---|
| **S01** | Domain trigger produces each row-transition event once; RPCs only separately listed semantic events; counter-only tenant updates produce no settings event | Exact action/entity strings, workflow event counts, semantic-event list and metadata allowlists remain required before P2 SQL | APPROVED — ARCHITECTURE DIRECTION |
| **S02** | Guard global roles/mappings and permissions catalog; protect audit/system catalogs against UPDATE/DELETE/TRUNCATE; acknowledge trusted-owner limits | Exact trigger coverage/maintenance exception and privileged-path tests remain; not tamper-proof forensic storage | APPROVED — ARCHITECTURE DIRECTION |
| **S03** | Failed expired acceptance persists no row/audit change; successful replacement expires old pending row atomically | P3 implementation/race evidence only; no alternative committed-expiry rejection design | APPROVED — ARCHITECTURE DIRECTION |
| **S04** | Reject every accepted-token replay, including same user | A narrow same-user completed-result retry would require a new explicit decision; currently prohibited | APPROVED — ARCHITECTURE DIRECTION |
| **S05** | Expiry = server insertion timestamp + exactly seven days; acceptance uses current authoritative time after waits | Organization canonical original-request proof or narrower retry contract remains unresolved; new proof storage needs schema review | APPROVED — ARCHITECTURE DIRECTION |
| **S06** | Membership removal is status-based; preserve other-tenant access/history; clear effective grants where approved; acceptance always rechecks continuing authority | Exact per-status retain/clear matrix, proactive revoke versus pending-but-unusable offers and audit effects remain P3 blockers | APPROVED — ARCHITECTURE DIRECTION |
| **S07** | Keep phase order; controlled initialized profiles for P3 tests; public self-service onboarding gated until P4 | P4 lifecycle/write path and real signup-to-onboarding acceptance remain future | APPROVED — ARCHITECTURE DIRECTION |
| **S08** | Enforce durable controls on direct RPC and wrapper; define bearer/origin/CSRF and bounded full-transaction retry | Exact storage/service, limits/keys/windows/failure policy, input sizes, numeric workloads/latency/throughput/retry budgets remain unresolved | APPROVED — ARCHITECTURE DIRECTION |
| **S09** | Branch Manager settings read exposes only approved org-level keys and no branch-private payload | Owner-supplied key/type/projection catalogue required; no settings keys currently approved | APPROVED — ARCHITECTURE DIRECTION |
| **S10** | Status-based Owner count remains separate from verified access; no silent account-deletion bypass | Sole-Owner recovery and legal erasure process remain future operational/compliance work | APPROVED — ARCHITECTURE DIRECTION |

S01–S10 are decision records, not Architecture v2 test suites S1–S5. Zero-padding is intentional.

## 4. Finding disposition summary

All F01–F20 have been applied to corrected D1–D5 at the documentary level. F03/F04, F06/F07/F09, F12/F13, F18/F19 retain explicit implementation or future-phase parameters rather than false closure. F01/F02/F05/F08/F10/F11/F14/F15/F16/F17/F20 are reconciled as documentary rules; their runtime evidence remains unexecuted. The complete finding-by-finding audit is in `Cross_Document_Consistency_Audit_V1.md`.

## 5. Change history

**V1:** converted all 22 proposed recommendations into owner-approved architecture direction; preserved every residual value and approval gate; mapped decisions to corrected documents/tests; made no database, Auth, application or settings change and executed no implementation test.
