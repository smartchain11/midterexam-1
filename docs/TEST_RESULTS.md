# Test results and evidence

## Execution boundary

No Supabase connection or real test account credentials were supplied. Mandatory end-to-end tests below are **Not run**, not Pass. Run the SQL test suite and browser steps before changing these results. Local `npm test` checks the independent JavaScript preview/validation model only; it does not verify the authoritative PostgreSQL implementation, login, RLS or refresh persistence.

Local execution on 2026-10-21: `node --test tests/policy.test.js` completed with **10 passed, 0 failed**. JavaScript syntax checks completed for the application and static server. PowerShell blocked `npm.ps1`; the equivalent direct Node command was used. This is not a pass for the ten mandatory end-to-end tests.

After the ADSSU profile update, the expanded local suite completed with **14 passed, 0 failed**, including four profile-format validation tests. `node --check app.js` also passed. The new migration, catalogue grants and ADSSU registration RPC still require execution against Supabase; their backend checks are included in `database/03_functional_tests.sql` and are not reported as passed.

After adding student self-registration, `node --test tests/policy.test.js` completed with **18 passed, 0 failed**, including four signup-validation cases. Syntax checks passed for `app.js` and `scripts/create-test-users.js`. This verifies local validation only; migration 06, email confirmation, pending registration approval and identity-claim protections remain pending live execution.

After directory integration and deployment-configuration fallback, `node --test tests/directory-config.test.js tests/policy.test.js` completed with **28 passed, 0 failed**. Browser checks confirmed 13 default cards, 21 in All listings, eight in Missing document checklists, a single Bunawan search match and a working requirements dialog containing its residency-document requirement. The available viewport had no page-level horizontal overflow and no setup warning. Six HTTP checks confirmed the page, settings module, directory module and JSON return 200 while SQL/admin scripts remain blocked with 403. Missing-local-config fallback and secret-key rejection were verified as module tests, not as a production-host deployment test. These checks do not establish that live Supabase authentication or exam workflows pass.

Static-server smoke checks: **7 passed**, covering HTML/JS/CSS responses, missing configuration returning 404 without crashing, protected SQL/server source returning 403, and a successful request after the missing file. Browser inspection confirmed the login page and setup warning render, with no horizontal overflow at the available viewport. This is not a completed responsive-device or authenticated workflow test.

## Expected seeded outcomes

After the ADSSU upgrade, B01–B06 are test-case labels: the corresponding student IDs are M-008759–M-008764, with BSIT 3B profiles. See `ADSSU_PROGRAMS.md` for source-backed courses and account mapping. If you already created the old `b01@example.test` Auth account, its login is preserved; otherwise create the new synthetic B01 account at `demo.asantos01@adssu.edu.ph`, manually auto-confirmed without sending email.

All six records are AY 2026-2027, Semester 1. Before evaluation their compliance is Not Evaluated and renewal is Undecided. B01–B05 are synthetic preverified fixtures; B06 is Pending. The expected compliance below is the result of a later evaluation, not a fabricated recorded result.

| Scholar | Program | Expected evaluation | Reasons |
|---|---|---|---|
| B01 | Excellence | Compliant | GWA 2.00, units 18 and exact 17:00 deadline all pass |
| B02 | Excellence | With Deficiency | GWA 2.01 exceeds 2.00 |
| B03 | Access | Compliant | GWA 2.50, units 15 and one drop are allowed |
| B04 | Access | With Deficiency | 14 units below 15; one INC exceeds zero |
| B05 | Excellence | With Deficiency | One failed subject; submission at 17:01 is late |
| B06 | Access | Blocked / Not Evaluated | Pending evidence prevents final evaluation; after verification, its supplied academic values pass |

## Mandatory results table

| ID | Input / action | Expected result | Actual result | Pass / fail | Evidence reference |
|---|---|---|---|---|---|
| TC01 | Staff evaluate B01 | Compliant at inclusive GWA and deadline boundaries | Not run against Supabase | Not run | Pending: `TC01-boundary.png`, SQL notices |
| TC02 | Staff evaluate B02 | With Deficiency; GWA reason | Not run against Supabase | Not run | Pending: `TC02-gwa.png` |
| TC03 | Staff evaluate B03 | Compliant; Access permits one dropped subject | Not run against Supabase | Not run | Pending: `TC03-access.png` |
| TC04 | Staff evaluate B04 | Both insufficient units and incomplete-grade reasons | Not run against Supabase | Not run | Pending: `TC04-multiple.png` |
| TC05 | Staff evaluate B05 | Failed-subject and late-submission reasons | Not run against Supabase | Not run | Pending: `TC05-late.png` |
| TC06 | Evaluate and approve B06 while Pending | Both requests denied; state unchanged | Not run against Supabase | Not run | Pending: `TC06-gate.png` |
| TC07 | B01 duplicate term; new term with GWA 0.50 or negative count | All rejected with clear messages; no extra record | Not run against Supabase | Not run | Pending: `TC07-validation.png` |
| TC08 | B01 query B02 and attempt verification/direct updates | Backend returns no B02 rows; privileged operations denied | Not run against Supabase | Not run | Pending: `TC08-backend.png` |
| TC09 | Staff return B01; B01 corrects/resubmits; refresh | Pending, Not Evaluated and Undecided persist with earlier history | Not run against Supabase | Not run | Pending: `TC09-correction.png`, `TC09-refresh.png` |
| TC10 | Staff approve B03, hold B02, attempt deficient approval; Scholar attempts decision | Valid staff decisions persist; deficient approval and Scholar decision denied | Not run against Supabase | Not run | Pending: `TC10-renewal.png` |

## Browser procedure

1. Complete README setup. Use a staff browser session and a separate private-window B01 session. Never capture passwords or token values.
2. As staff, choose 2026-2027/Semester 1. Open B01–B05 and evaluate each. Compare every reason with the seeded-outcomes table. Initial totals after these evaluations: 6 assigned, 1 pending, 2 compliant, 3 deficient.
3. Attempt evaluation and approval of B06. Capture error messages without changing fixture values. Verify B06 only after recording TC06.
4. In B01's session, use the selected original term to attempt a duplicate. For invalid-value cases, choose Semester 2, enter GWA 0.50 or a negative failed count and confirm rejection. To prove database validation rather than HTML validation only, run the corresponding SQL tests or RPC requests below.
5. Use the B01 session's browser console to run backend checks below. Record responses, never bearer tokens or session storage.
6. As staff, return B01 with a reason. As B01, open it, correct the reference and resubmit. Reload the page, sign back in if needed, and confirm Pending with preserved Returned and Corrected events. If testing after the deadline, expect later evaluation to show lateness.
7. As staff approve B03 and hold B02 with notes. Attempt to approve B02 and confirm denial. B01's decision RPC must also be denied.
8. Search B04/name, filter Access and With Deficiency, switch semester, refresh and check both row results and counters. Capture the dashboard.
9. Register a seventh synthetic scholar and assign a program. Reload to confirm persistence, then create its matching Auth account privately to test a fresh valid summary. This adds an assignment but does not alter the original six fixtures.

## Scholar-side backend checks

Execute only in the B01 test-account session. These commands reuse the existing browser session without printing credentials.

```javascript
const account = JSON.parse(sessionStorage.getItem('scholarship-session'));
const headers = { apikey: APP_CONFIG.supabaseAnonKey, Authorization: `Bearer ${account.access_token}`, 'Content-Type': 'application/json' };
const endpoint = APP_CONFIG.supabaseUrl + '/rest/v1';
await (await fetch(endpoint + '/submissions?id=eq.30000000-0000-4000-8000-000000000002&select=*', { headers })).json();
await (await fetch(endpoint + '/rpc/verify_submission', { method: 'POST', headers, body: JSON.stringify({ p_submission_id: '30000000-0000-4000-8000-000000000001', p_status: 'Verified', p_reason: 'Unauthorized test' }) })).json();
await (await fetch(endpoint + '/rpc/decide_renewal', { method: 'POST', headers, body: JSON.stringify({ p_submission_id: '30000000-0000-4000-8000-000000000001', p_decision: 'Approved', p_notes: 'Unauthorized test' }) })).json();
```

Expected: empty array for B02; permission errors for verification and renewal. Re-login if the access token expired. Do not print or screenshot `account`, `headers`, or authentication network payloads.

## Additional checks

### Student self-registration extension (not executed against Supabase)

Install migration 06 before enabling public signup. Keep Confirm email enabled and configure delivery to authorized real ADSSU test mailboxes. Never send email to the synthetic seed addresses. Use only instructor-approved synthetic profile data, and retain actual results/evidence separately.

| ID | Action | Expected result | Actual |
|---|---|---|---|
| SR01 | Open New student? Create an account | Course catalogue loads without exposing private student rows | Not run |
| SR02 | Submit invalid ID/domain, short/mismatched passwords | Validation rejects; malformed direct completion RPC also rejects profile fields | Not run end-to-end |
| SR03 | Register without confirming email, attempt Scholar Login/completion | Auth or database confirmation gate blocks completion; no scholarship assignment is created | Not run |
| SR04 | Confirm owned ADSSU email and sign in as Scholar | Profile completes, awaiting-assignment message appears; no grade submission allowed yet | Not run |
| SR05 | Staff approve initial assignment | Persisted policy assignment appears; student can submit after refresh | Not run |
| SR06 | Scholar call approve_student_assignment or attempt direct assignment/role writes | Staff RPC and database grants reject | Not run |
| SR07 | Try claiming a seeded ID through a different mailbox or staff email/profile | Unique ID or role/ownership validation denies; no existing identity or role changed | Not run |
| SR08 | Public signup for a seeded email before verifying ownership | Existing seeded profile is not automatically bound by the auth trigger | Not run |
| SR09 | Confirm seeded email with matching ID and complete registration | Only the verified owning account links; stored seeded academic values and name remain unchanged | Not run |

Student signup has no role/policy choice. A second browser session is recommended for testing staff approval and the student's refresh. The supplied local admin setup command can create confirmed synthetic accounts without mailbox delivery, but that is not evidence that the public confirmation-email flow works.

- Tab through login/form controls at 375px and 1280px widths.
- Log out and confirm no record UI remains. A signed-out API request must not reveal data.
- Try direct profile role escalation and direct submission writes in the transactional SQL suite.
- Confirm the displayed award remains Active for deficient/held records.
- Confirm every successful verification, evaluation and renewal includes an actor, timestamp, notes and snapshot.

## Defect and limitation log

| Item | Status / impact |
|---|---|
| Supabase execution and Auth not configured in this workspace | Blocking live acceptance and screenshots, not a claimed pass |
| True refresh-persistence evidence | Must be performed in browser; SQL transaction tests alone cannot establish it |
| Current assignments only | Semester dashboard's assigned count is current assignments, not historical assignment membership |
| Cloud outage | Local frontend remains runnable; cloud data/auth operations do not work offline |
| Diagram image export | Use-case PNG/SVG supplied; ERD image export remains a submission task if required |

Add every newly observed defect with reproduction steps, impact and resolution. Do not replace Not run with Pass without execution evidence.
