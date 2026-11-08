# Logical Education ERP — M1 P2 Security Tests and Acceptance Criteria

**Status: proposed tests only. None has been executed or marked passed.** P1 V3 remains unapplied; therefore no live P2 policy, RPC, Auth, concurrency or privilege result exists. Tests run only after P1 application/review and separately approved P2/P3 implementation as applicable.

## 1. Test method and evidence

Use the dedicated Dev project only. Create explicitly labeled test tenants/users inside isolated test transactions or a controlled test fixture process; never seed fake production organizations or business statistics. Concurrency tests require independent real database/API sessions and controlled cleanup because a single rolled-back transaction cannot prove inter-session behavior.

For each executed test record:

- test ID, exact schema/migration version and timestamp;
- actor/session type and fixture IDs;
- operation and relevant committed/rollback state;
- expected versus actual result, including error code where appropriate;
- counter/audit/branch/membership reconciliation queries;
- pass/fail/blocked status and any deviation.

Do not convert a permission error into proof of RLS by assumption: distinguish ACL denial, RLS empty results, policy rejection and RPC authorization errors. Test direct PostgREST/RPC calls as well as UI behavior.

## 2. Fixture matrix

Proposed isolated fixtures:

- Tenants A and B, both active; Tenant C suspended for negative tests.
- Tenant A branches A1 and A2; Tenant B branch B1. An inactive branch A3 for lifecycle tests.
- Verified users: Owner O1, second Owner O2, Organization Admin OA, Branch Manager BM(A1), Staff S(A1), Read Only RO(A1), outsider X with no A membership, and verified user I for invitations.
- An unverified Auth user UV and verified users with emails matching/not matching invitation recipients.
- Custom roles CRA in Tenant A and CRB in Tenant B, created only by controlled fixtures; custom-role management feature remains disabled.
- Independent sessions for O1/O2, inviter/invitee and concurrent revocation/acceptance.

All fixture identity/role rows must obey the actual P1 global-system-role semantics. No test may use rank or display name alone to fabricate Owner authority.

## 3. ACL, helper and RLS baseline

| ID | Test | Expected acceptance result |
|---|---|---|
| ACL-01 | Inspect effective table, column, sequence and function ACLs for anon, authenticated and service_role, including inheritance | Exactly approved grants; service_role has zero P1/P2 table/column/sequence/application-function privileges; no default PUBLIC execution on private routines |
| ACL-02 | Anonymous SELECT and all DML against all 12 tables | No rows/no mutation; no public policy or grant |
| ACL-03 | Direct authenticated INSERT/DELETE/TRUNCATE and general UPDATE on every table | Denied. Sole possible exception is the five documented self-profile UPDATE columns; no other direct write |
| ACL-04 | Authenticated `SELECT *` from invitations and explicit `token_hash` selection | Fails because safe column projection excludes hash; approved safe columns still work for authorized rows |
| ACL-05 | Authenticated `SELECT settings`, `created_by`, `creation_key`, `active_owner_count` from tenants | Fails; eleven approved safe tenant columns remain available only through RLS |
| ACL-06 | Attempt to invoke private Owner, audit and catalog trigger functions as anon/authenticated/service_role | EXECUTE denied; normal triggers still operate |
| HLP-01 | Exercise every SELECT policy with global system roles and same-tenant custom roles | No infinite recursion, missing global-role handling or unexpected empty authorized result |
| HLP-02 | Inspect helper/RPC owners, definer flags, volatility and empty search paths; attempt search-path shadowing | Only reviewed trusted owner; fully qualified behavior unchanged; no caller-controlled object resolution |
| HLP-03 | Pass null/foreign tenant, branch, role and arbitrary-user-like inputs to helpers | False/denial; no arbitrary-user oracle or sensitive row returned |
| HLP-04 | Unverified user attempts tenant SELECT and every mutation RPC | No tenant data/mutation even with a token or guessed IDs |

## 4. Tenant, branch and privacy isolation

| ID | Test | Expected acceptance result |
|---|---|---|
| TEN-01 | Member of A SELECTs tenants/branches/memberships/invitations/audit for B by guessed IDs | Zero B rows; no metadata leakage through errors |
| TEN-02 | Member attempts direct or RPC INSERT/UPDATE/DELETE with A authority but B tenant ID | Denied; B rows, counters and audits unchanged |
| TEN-03 | Forge `last_tenant_id`, `created_by`, inviter, actor, accepted user or JWT tenant-like metadata | Authority remains based on `auth.uid()` and database membership; invalid last-tenant hint rejected |
| TEN-04 | Access suspended/archived Tenant C through ordinary policies/RPCs | Fail closed; only separately approved future recovery path could differ |
| BR-01 | BM/S/RO assigned A1 reads A1 and A2 | A1 visible according to permission; A2 invisible |
| BR-02 | BM(A1) updates A2 or creates/invites into A2/B1 | Denied atomically; only permitted A1 update/invitation fields can succeed |
| BR-03 | Branch user has zero `membership_branches` rows or only inactive A3 | Zero branch access; zero rows never mean all branches |
| BR-04 | Branch actor reads another member's assignments | Only shared authorized branches visible; no disclosure of that member's other branch assignments |
| BR-05 | Organization Owner/Admin reads/acts across A1/A2 | Allowed only for their exact mapped permissions; no membership_branches rows required |
| BR-06 | Organization-role membership/invitation is given branch links, or branch-role active membership/invitation has none | Commit-time validator rejects whole transaction |
| PRV-01 | One co-member directly SELECTs another profile | Denied; phone and last-tenant hint are not exposed |
| PRV-02 | Directory RPC called by branch manager and organization admin | Each receives only documented safe projection and authorized roster; no full profile/Auth fields |
| PRV-03 | User with only `organization.view` attempts settings RPC/direct settings column | Denied; `settings.view` is required and returns only allowlisted keys |
| PRV-04 | Self profile updates theme to dark, then invalid theme/identity/foreign last tenant | Light/dark self field succeeds; invalid theme, ID and foreign hint fail without changing identity |

## 5. Role, custom-role and escalation tests

| ID | Test | Expected acceptance result |
|---|---|---|
| RBAC-01 | Staff attempts organization, branch, membership, role, invitation and audit mutations | All denied; Staff has only organization.view and branch.view in P1 |
| RBAC-02 | Read Only attempts every modification path, including direct API and RPC | All denied; no UI-only assumption |
| RBAC-03 | Branch Manager attempts existing membership update | Denied because P1 Branch Manager lacks user.update despite having user.invite |
| RBAC-04 | Organization Admin assigns/invites Owner or updates an Owner | Denied; target membership/invitation and Owner counter unchanged |
| RBAC-05 | Organization Admin invites/assigns equal Organization Admin | Denied under strict-lower non-Owner delegation |
| RBAC-06 | Branch Manager invites Branch Manager or Organization Admin | Denied; only strictly lower branch roles within assigned branches |
| RBAC-07 | Owner grants Owner to another active member | Allowed through guarded RPC with tenant lock, counter/audit correctness |
| RBAC-08 | Assign CRB to Tenant A membership or invitation | Rejected by authorization and P1 same-tenant role integrity |
| RBAC-09 | Tenant B user reads CRA or CRA mappings | Denied; Tenant A authorized role viewer can read them |
| RBAC-10 | Modify global system role display fields, key/scope/rank or global role_permissions through application/definer paths | Rejected by catalog guards/ACLs; system catalog remains exact |
| RBAC-11 | Attempt to use reserved branch.delete or role.manage RPC/feature | No such enabled operation; permission seed alone does not expose functionality |
| RBAC-12 | Custom high rank/permission bundle attempts Owner or Platform Admin behavior | No Owner invariant recognition or platform authority; only explicit role identity and separate platform table apply |

## 6. Owner integrity and concurrency

| ID | Test | Expected acceptance result |
|---|---|---|
| OWN-01 | Demote, suspend, remove or delete the sole active Owner through every available path | Each rejected; original role/status, count=1 and no success audit remain |
| OWN-02 | Organization Admin attempts any Owner removal/demotion | Authorization denied regardless of user.update |
| OWN-03 | With O1 and O2 active, O1 removes self | Succeeds through guarded workflow; O2 remains active Owner; count=1; audit commits |
| OWN-04 | Transfer O1 ownership to active target and relinquish caller | Target becomes Owner before caller demotion in one transaction; final count correct and never committed at zero |
| OWN-05 | Transfer to foreign/inactive membership or by non-Owner | Full rollback; no partial successor promotion |
| OWN-06 | **Two independent sessions:** O1 and O2 concurrently remove themselves from the same two-Owner tenant | Tenant lock serializes; at most one succeeds; final actual and stored active Owner counts are exactly 1 |
| OWN-07 | Concurrent demotion and suspension of the same last Owner | Both cannot succeed; no zero-Owner committed state or counter drift |
| OWN-08 | Concurrent Owner addition and removal | Serialized result obeys minimum-one and stored count equals actual after both settle |
| OWN-09 | Force an audit or later-step failure after Owner mutation | Membership, counter and audit all roll back together |
| OWN-10 | Attempt direct counter update or submit counter in RPC payload | ACL/input rejection; counter derives only from actual transitions |
| OWN-11 | Activate tenant with zero active Owners | Deferred invariant rejects at commit |
| OWN-12 | Atomic create organization + first Owner | Commits with actual/stored count 1 despite deferred minimum check; tenant without Owner variant rolls back |
| OWN-13 | Reconcile count after every success, denial, retry and rollback above | `active_owner_count` always equals actual active global-Owner membership count; drift fails release |

## 7. Invitation creation and secrecy

| ID | Test | Expected acceptance result |
|---|---|---|
| INV-01 | Inviter supplies another inviter membership/user, creator, expiry or accepted fields | Identity fields ignored/rejected; canonical inviter and seven-day expiry derived server-side |
| INV-02 | Owner/Admin/Branch Manager creates allowed invitation | Exact role/branch scope stored; only hash persisted; raw token returned once |
| INV-03 | Create organization-role invitation with branches or branch-role invitation without branches | Whole transaction rejected |
| INV-04 | BM(A1) includes A2 or B1 alongside valid A1 | Whole invitation rejected; no valid subset silently survives |
| INV-05 | Organization Admin creates Owner invitation or any equal/higher role | Rejected |
| INV-06 | Create two live pending invitations for same tenant/email concurrently | At most one live pending row; loser gets safe duplicate response; no partial branches |
| INV-07 | Existing pending row is past expiry, then create replacement | Old row transitions expired under control and new pending row succeeds; uniqueness remains intact |
| INV-08 | Inspect table reads, RPC responses after creation, audit metadata and application/database error logs | No raw token or token hash disclosed; only initial creation response contains raw token |
| INV-09 | Replay/rotate invitation terms by updating email, role, hash, inviter or expiry | P1 identity guard rejects; revoke and create a new invitation instead |
| INV-10 | Token generation review | At least 256 bits CSPRNG, base64url representation, lowercase 64-hex SHA-256 storage and unique hash; no predictable token accepted |

## 8. Invitation acceptance and revocation

| ID | Test | Expected acceptance result |
|---|---|---|
| ACC-01 | Valid verified matching user accepts pending unexpired invitation | One active membership, exact branch grants, accepted fields, historical inviter and audit commit atomically |
| ACC-02 | Wrong verified email or unverified matching user presents valid token | Generic unavailable response; no membership or invitation change |
| ACC-03 | Random, malformed, revoked or already accepted token | Generic unavailable response; no tenant/role/inviter enumeration |
| ACC-04 | Expired token, including expiry while request waits for a lock | Rejected using current time after lock wait; no membership/audit success |
| ACC-05 | Suspended tenant or inactive offered branch at acceptance | Entire acceptance rejected; no branch subset or membership |
| ACC-06 | Inviter was suspended/removed, lost user.invite, was demoted below offered rank or lost one offered branch | Continuing-authority check rejects whole invitation |
| ACC-07 | Invitation references foreign custom role or cross-tenant branch fixture | Structural/authorization rejection; no membership |
| ACC-08 | Existing active/invited/suspended/removed `(tenant,user)` membership accepts invitation | Conflict rejected; no automatic upsert, privilege increase or reactivation |
| ACC-09 | **Two sessions:** same invite accepted concurrently | At most one succeeds; one membership and one accepted transition; retry only recognized for same proven accepting user/result |
| ACC-10 | **Two sessions:** accept versus revoke | Serialized final state is either fully accepted with membership or revoked without membership, never both/partial |
| ACC-11 | **Two sessions:** accept versus inviter demotion/branch revocation | Re-read after locks determines one valid result; acceptance never uses stale pre-lock authority |
| ACC-12 | Revoke Owner invitation as Organization Admin or out-of-scope branch invitation as BM | Denied; invitation unchanged |
| ACC-13 | Revoke accepted invitation | Rejected as historical; membership is not implicitly removed |
| ACC-14 | Force membership/branch/audit failure during acceptance | Invitation status, membership, branch grants, Owner counter if relevant and audits all roll back |

## 9. Audit integrity

| ID | Test | Expected acceptance result |
|---|---|---|
| AUD-01 | Client inserts arbitrary audit event or supplies actor/action/metadata to a mutation RPC | No public writer; actor/action derived internally; forged fields rejected/ignored |
| AUD-02 | Authenticated/service_role modifies, deletes or truncates audit rows and uses identity sequence | ACL denial; immutable trigger also rejects privileged application update/delete |
| AUD-03 | Owner/Admin with audit.view reads Tenant A and attempts B/null-tenant platform events | A organization audit visible; B and global/platform rows invisible |
| AUD-04 | Branch Manager/Staff/Read Only attempts audit read | Denied under current mappings; no invented branch filtering |
| AUD-05 | Successful organization, branch, membership, role, invitation and Owner operations | Exactly expected safe events with derived actor/time and same-transaction commit |
| AUD-06 | Rejected or deliberately failed mutation | No success audit or partial business row; denial telemetry is not falsely claimed |
| AUD-07 | Inspect metadata for invitations/settings/member changes | No raw token/hash, full settings dump, arbitrary request body or unnecessary PII |

## 10. Platform Admin isolation

| ID | Test | Expected acceptance result |
|---|---|---|
| PLT-01 | Owner/Admin inserts, updates or deletes platform_admins through direct API or tenant RPC | Denied; tenant permission/rank has no effect |
| PLT-02 | User submits logicaltechzoneofficial@gmail.com or another email as authorization input | No grant; email strings never authorize frontend/backend operations |
| PLT-03 | Non-admin calls `p2_is_platform_admin` and attempts to enumerate platform_admins | Helper false for self; self-only policy reveals no other admin rows |
| PLT-04 | Platform Admin row is absent before P9 | Table remains empty; no bootstrap/grant occurred in P2 |
| PLT-05 | Platform Admin attempts ordinary tenant action without separate P9 operation | No automatic cross-tenant bypass; P2 tenant policies remain independent |
| PLT-06 | Future P9 bootstrap test placeholder | Resolve the confirmed email to verified Auth UUID, audit grant, prove wrong/unverified email fails; remains blocked until P9 |

## 11. Lifecycle, deployment and performance gates

| ID | Test | Expected acceptance result |
|---|---|---|
| LIFE-01 | Removed/suspended member loses ordinary access, then Auth hard deletion is attempted with retained membership | Access denied, but Auth/profile deletion rolls back under membership RESTRICT as documented; no false erasure claim |
| LIFE-02 | Organization creation retry with same/different creator and same creation key | Only same creator + same payload gets idempotent result; another creator cannot claim/read it |
| DEP-01 | Inspect browser bundle, network responses and server logs | No service credential, raw invitation token after initial creation, token hash or sensitive settings payload |
| DEP-02 | Exercise server wrappers without valid bearer/CSRF and with malformed inputs | Authentication/input rejection; database authorization remains effective if wrapper checks are bypassed |
| DEP-03 | Review invitation abuse controls | Durable rate limiting exists before exposed P3 endpoints rely on it; in-memory counters are not accepted as durable proof |
| PERF-01 | Analyze every policy/helper plan on realistic permitted/denied datasets | Expected indexes used; no uncontrolled roster-wide helper explosion; optimization retains every predicate |
| PERF-02 | Concurrent deadlock stress using tenant→membership→invitation→branch lock order | No persistent deadlock/incorrect state; any deadlock retries are bounded and never skip reauthorization |

## 12. Release acceptance criteria

P2 security acceptance requires all P2-scoped tests to pass on the exact approved migration and all P3 workflow tests to remain explicitly blocked until P3 exists. No business provisioning is enabled before Owner/concurrency and onboarding gates pass. P3 invitation acceptance is not ready until every applicable invitation race, token secrecy and continuing-authority test passes.

A release is rejected for any of the following:

- cross-tenant or unassigned-branch data exposure;
- direct client or service_role privilege beyond the approved matrix;
- Owner count drift, committed zero-active-Owner tenant or failed two-session race;
- Organization Admin/tenant Owner Platform Admin escalation;
- invitation token/hash disclosure or acceptance after expiry/revocation/wrong email/lost inviter authority;
- mutable/deletable audit records or audits committing without their business mutation;
- recursive policies, mutable search paths, unintended PUBLIC EXECUTE or unverified definer ownership;
- unexecuted, failed or flaky security tests reported as passed.

## 13. Current execution report

- **Executed in this planning task:** document review and design cross-check only.
- **Database/Auth/application tests executed:** none.
- **P1/P2 migrations applied:** none.
- **P2/P3 functions or policies created:** none.
- **Next approval gate:** review these five documents; P1 execution remains a separate prior decision, and P2 implementation requires separate explicit approval.
