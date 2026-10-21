# Scholarship Monitoring and Academic Compliance

Vanilla HTML, CSS and JavaScript frontend with Supabase Auth, PostgreSQL, row-level security and protected RPC functions. No frontend framework, SDK, build step, or source-code comments.

## Setup

1. Create a new Supabase project. Use a dedicated test project, not a production database.
2. In SQL Editor, execute `database/01_schema.sql`, then `database/02_seed.sql`, then `database/04_adssu_profiles.sql`, once and in that order. The first two scripts prepare the original exam fixtures; the third converts their profile fields to ADSSU format and adds the academic catalogue. If you already ran the first two, run only `04_adssu_profiles.sql`. These migrations are not rerunnable; do not reset an existing project.
3. Initially disable public user signup and anonymous sign-ins in Authentication settings. For the optional student self-registration feature, first install migration 06 and follow the secure enablement section below; do not enable public signup with the original email-linking trigger.
4. In Authentication → Users, create an email/password staff account and a scholar account with email `demo.asantos01@adssu.edu.ph`. Mark them confirmed using the manual Create user operation; do not send invitation/reset emails to synthetic institutional addresses. Choose passwords privately, not in source code. Create B01 only after all three setup scripts. The remaining seed emails are listed in `docs/ADSSU_PROGRAMS.md`. If a seed already has a linked Auth account, the upgrade preserves its existing email and login; query `profiles` to see the correct address rather than creating a duplicate account.
5. Promote the staff profile through SQL Editor, replacing the email below. Never expose a role-management endpoint to scholars.

```sql
update public.profiles
set role = 'Staff'
where email = 'YOUR_STAFF_EMAIL';
```

6. This project's public Supabase URL and publishable key are included in `settings.js` as deployment defaults. For a different hosted project, update those public values in `settings.js`. For a localhost override, copy `config.example.js` to `config.js` and set its `supabaseUrl` and `supabaseAnonKey`. A valid localhost override takes precedence; hosted pages do not request `config.js`. These are public browser configuration values. Never use a secret or service-role key. `config.js` remains excluded from Git; `settings.js` intentionally contains browser-public configuration only. The optional administrator setup command still reads your local `config.js`.
7. Install Node.js 20.11+ and run `npm start` in this folder. No npm install is necessary. Open `http://127.0.0.1:3000`.

```powershell
Copy-Item config.example.js config.js
npm start
```

If PowerShell blocks `npm.ps1`, use `npm.cmd start` / `npm.cmd test`, or `node server.js` / `node --test tests/policy.test.js`. No execution-policy change is needed.

The optional Node server only serves static files; the application backend is Supabase. Static deployment requires `index.html`, `styles.css`, `app.js`, `domain.js`, `settings.js`, `catalogue.js`, `assets/adssu-logo.png`, and `data/scholarship-reference.json`. `config.js` is only loaded on localhost for local overrides. Do not serve database/test documents publicly. The included server uses an exact file allowlist, including the single public directory JSON file but no SQL/admin scripts. The logo is used in the header, login page and favicon; its source is recorded in `assets/README.md`.

## Scholarship reference directory

The public page and signed-in workspace include a searchable directory sourced from the user's other project, https://adssuscholarship.dev/. No login or additional SQL migration is needed to browse it. The snapshot contains 21 listings: 13 with document checklists and eight with incomplete lists. The default view shows the 13 checklist entries; select All listings or Missing document checklists to review the rest.

Each requirements dialog preserves the reported grade label and document list, with warnings for conflicting/possibly duplicated entries and suspicious SHS values. All listings are marked not provider-verified. Missing benefits, deadlines and renewal rules stay unknown. See `docs/OTHER_PROJECT_REVIEW.md` and `data/scholarship-reference.json` for provenance.

The directory is reference-only. It does not add any scholarship policy to the database, change the two exam policies, assign a scholarship, create an application or make eligibility/renewal decisions. There is deliberately no Apply button that would falsely imply a working application workflow for these additional programs.

## Configuration names

### Create password-enabled demo logins locally

After running database scripts 01 → 02 → 04, use this optional administrator setup command instead of manually creating Auth users:

```powershell
node scripts/create-test-users.js
```

It reads the configured project URL, prompts with hidden input for a Supabase **secret key or legacy service-role key**, then asks for separate staff and student passwords of at least 12 characters. Obtain the admin key privately from your project's API Keys settings. Do not paste it into chat, `config.js`, screenshots, shell command arguments or any source file. Only the existing public publishable key belongs in the browser configuration.

The command creates a confirmed staff login (default `demo.staff@adssu.edu.ph`), promotes its profile, and creates the B01 scholar login using the fixture's current email. It does not send invitations or write keys/passwords to files. The new secret-key format is sent only as `apikey`; the legacy service-role JWT also uses an Authorization header. This is an administrator-only local setup script and is not served by the application.

If migration 04 was applied while the fixture tables were empty, and an older 02 seed was run afterward, B01–B06 can have blank test-case labels. Run `database/05_repair_seed_profiles.sql` in SQL Editor after confirming migration 04 exists. It repairs only the six known fixture UUIDs, preserves customized names and existing linked-account emails, fills missing course fields, and converts unlinked old synthetic emails. It does not delete records, change academic summaries, or create/reset login passwords. Then rerun the user-setup command. Do not rerun schema 01 or migration 04 to repair this ordering issue.

If an account already exists, its password stays unchanged unless you explicitly type `YES` at the replacement prompt. Assigned scholar accounts cannot be promoted to staff by this setup command. An error can leave an earlier account successfully created; inspect the output and rerun rather than deleting accounts or resetting the database. No setup accounts have been created automatically by generating this script.

| Name | Location | Purpose |
|---|---|---|
| `supabaseUrl` | `window.APP_CONFIG` in `config.js` | Project API URL |
| `supabaseAnonKey` | `window.APP_CONFIG` in `config.js` | Publishable or anon key |

No server environment variables are required. Passwords are entered interactively. Session tokens are stored in browser session storage, refreshed before expiry, and cleared on sign-out. Use trusted devices and HTTPS outside localhost.

## Workflows

### Student self-registration

This additional feature requires `database/06_student_registration.sql`, applied once after migrations 01 and 04 (and the seed/repair if needed). It replaces the original auth trigger so unconfirmed public signups cannot automatically link to an existing scholar profile by email.

After applying 06, open Supabase Authentication settings:

1. Enable Email sign-in and Allow new users to sign up.
2. Keep **Confirm email enabled**. Do not disable email verification for public signup. Set a minimum password length of at least 12 if available.
3. Under URL Configuration, set Site URL to `http://127.0.0.1:3000` for this local demo, or the exact HTTPS deployment URL when hosted. A confirmation link redirects back to the login page; users then enter their credentials to sign in. The app does not consume a confirmation URL's session tokens automatically.
4. Configure an appropriate mail provider/SMTP and respect Supabase email rate limits. The default sender may limit delivery to authorized addresses; use a real authorized ADSSU mailbox for an instructor-approved email-confirmation demonstration. Never send confirmation/invitation messages to the fictitious seed addresses.

Choose **Scholar Login → New student? Create an account**. Enter ID, name, institutional email, academic course/year/section, academic year and a password. No scholarship-policy or role field is offered. After email confirmation, the student's first Scholar Login completes the profile through `complete_student_registration`. Until staff assign a policy, the dashboard shows awaiting assignment and hides the submission form; the backend also rejects submission without an assignment.

Staff see completed registrations in **Pending student registrations** and explicitly approve an assignment using one of the two persisted scholarship policies. Students cannot assign themselves a policy or acquire Staff rights. Public catalogue access exposes only course code/name/college/level, not student records. Email ownership is required to link an unbound pre-registered profile; its student ID must also match. Existing Staff profiles and profiles linked to another Auth user cannot be claimed. User metadata supplies only student-entered profile values, never authorization.

For synthetic testing without a deliverable mailbox, continue using the local administrator account-setup command or Supabase manual confirmed-user creation. After 06, the admin setup command explicitly links existing unbound seed profiles. Merely adding an unconfirmed Auth user does not finish a self-registration or put it in the staff assignment queue.

The public signup flow requires actual email delivery, mailbox verification and live backend testing; it has not been executed against your Supabase project during generation. Existing seeded/manual accounts continue using their assigned credentials. Student ID authenticity and academic details require staff review; an institutional mailbox alone is not proof of scholarship eligibility.

- The login form has visible Scholar Login and Staff Login options. The selected role must match the authenticated account's database profile before the app saves the session or opens a dashboard. Selecting Staff does not assign that role or bypass backend access controls. Switch back to Scholar for student accounts.

- Profiles use student IDs such as `M-008759` and course/year/section such as `BSIT 3B`, with profile academic year `2026-2027`. B01–B06 remain separate test-case labels. These are fictional identities; the user's actual example ID and email are not seeded.
- Academic courses are stored in `academic_programs`, independently from `programs` (the two fictional scholarship policies). Registration and search/filter expose this distinction. See `docs/ADSSU_PROGRAMS.md` for sources, catalogue limitations and upgrade instructions. The catalogue does not imply official scholarship eligibility or current admissions availability.

- Staff register a student ID, name and email, then select a persisted policy. Create the matching Auth user in the Supabase dashboard. If the Auth user already exists, registration attaches the academic profile to it. Student IDs and emails are unique.
- Staff can change a policy assignment before any semester submission exists. Later changes and policy exceptions are out of scope.
- Scholars submit using the selected year and semester. GWA accepts two decimals, 1.00–5.00; units and subject counts are nonnegative integers. A document reference, not an uploaded document, is required.
- Staff verify evidence or return it with a reason. Only pending submissions may be verified. Verified records may be returned to correct mistakes. Returning invalidates the current evaluation and renewal decision while retaining history.
- Scholars correct only returned records. The academic year and semester stay fixed. Resubmission sets a new submission timestamp, Pending verification, Not Evaluated compliance and Undecided renewal. The latest submission time is checked against the deadline; the original timestamp remains in history.
- Staff evaluate verified submissions. All six policy checks and all deficiency reasons are persisted by the database. The browser does not make authoritative decisions.
- Staff approve compliant records or hold evaluated records. Reasons/notes are required. Re-evaluation invalidates an earlier renewal decision; staff must decide again.
- Award status stays separate and unchanged. There is no automatic disqualification, payment release or alteration of official grades.
- Dashboard counters use the selected year and semester and are not reduced by text/program/result filters. Assigned scholars counts all visible current assignments, including scholars without submissions. Assignments are current rather than historical, as this MVP has no semester-specific assignment lifecycle.

## Security

RLS limits scholars to their own profile, assignment, submissions and history. Staff can read all. Authenticated clients have SELECT only, with no INSERT/UPDATE/DELETE table grants. Mutation RPCs check the caller's role and ownership, use a fixed search path, acquire row locks and write history within the same transaction. Scholars cannot update their role, verification, decision, timestamps or audit records. No custom user-metadata role is trusted. Trigger functions are not callable by API clients.

Administrative SQL Editor and service-role actions bypass these protections by design; never give those credentials to end users. Public signup must stay disabled unless migration 06 is installed and email confirmation is enabled. Admin changes to an existing account's email require administrator review and are not an application workflow.

## Tests and evidence

Run `npm test` for independent policy-preview, browser-input-validation, directory search/data-integrity and public-configuration checks. These do **not** establish that Supabase RLS or RPCs work. The preview model is a test oracle, not used for production evaluation.

After setup, run `database/03_functional_tests.sql` in SQL Editor. It switches to the actual `authenticated` PostgreSQL role and simulates staff/B01 JWT subjects to exercise real RLS, table grants and mutation functions. It covers TC01–TC10 database conditions and ends in `ROLLBACK`, preserving fixtures. It requires staff and B01 Auth accounts. Run it before changing the original fixtures; a manual workflow may change expected statuses. SQL notices show PASS results; any assertion failure aborts the transaction. If it aborts before ROLLBACK, issue `rollback;` before another query.

The SQL test does not prove browser refresh persistence or authentication-token issuance. Perform the browser steps in `docs/TEST_RESULTS.md`, including actual sign-in as two users, attempted REST access, refresh and screenshots. Record real results only. Supabase tests were not executed during generation because no connected project was supplied.

## Deliverables

- `docs/ANALYSIS.md`: A1–A6 and traceability.
- `docs/use-case-diagram.png`: clean 2700 × 2220 UML diagram, with actors on opposite sides and use cases between them.
- `docs/use-case-diagram.svg`: editable vector version with the same layout.
- `docs/use-cases.puml`: PlantUML semantic source with reused include behaviors and a conditional extend relationship.
- `docs/erd.mmd`: Mermaid ERD.
- `docs/ADSSU_PROGRAMS.md`: researched university courses, synthetic profile mapping, and safe upgrade instructions.
- `docs/TEST_RESULTS.md`: expected results and honest execution status.
- `evidence/README.md`: screenshot checklist.
- `database/`: schema/access controls, six fixtures, ADSSU profile/catalogue upgrade, and transactional backend tests. Setup order is 01 → 02 → 04; the optional 03 script is the rollback test suite.

Replace `StudentID` in the folder name with your actual ID. Add your name/program/date to the report. The use-case PNG and SVG are already rendered; render the ERD with an instructor-approved Mermaid tool if an image is required. To regenerate the exact use-case layout on Windows, run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/render-use-cases.ps1`; this applies to that process only and does not change the machine execution policy. Supply test-account access privately to the instructor, never in screenshots or Git. Submit a ZIP or GitHub repository URL as instructed; publishing is not performed automatically.

## Known limitations and fallback

- A Supabase project must be configured before sign-in and data operations work. No credentials or hosted project are bundled.
- A local static copy can run offline, but authentication and persistence still require Supabase network access. This is not a local database substitute. If the network fails, include the exact error, these run instructions, source and schema; do not claim a working offline backend.
- No evidence upload, Registrar API, SMS, payment, appeals, policy exceptions or password recovery UI. Student self-registration is available only after migration 06 and email-delivery configuration.
- Program policies and deadlines are administrator-seeded. Each of the two records uses the examination's single deadline; future deadlines require administrative policy versioning.
- Dashboard data is fetched in one request per table. The six-record examination dataset is supported; pagination and server-side search would be necessary beyond the project's API row limit.
- Live database acceptance has not been completed during generation. Local automated checks and public-directory browser checks are recorded separately from mandatory authenticated functional evidence.
