import { validateSummary, validateScholarProfile, validateStudentSignup } from './domain.js';
import { resolvePublicConfig } from './settings.js?v=20261021-2';

if (['localhost', '127.0.0.1', '[::1]'].includes(window.location.hostname)) {
  try { await import('./config.js'); } catch {}
}

const $ = selector => document.querySelector(selector);
const escape = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
const config = resolvePublicConfig(window.APP_CONFIG);
window.APP_CONFIG = config;
const configured = Boolean(config);
const sessionKey = 'scholarship-session';
let session;
try { session = JSON.parse(sessionStorage.getItem(sessionKey) || 'null'); } catch { sessionStorage.removeItem(sessionKey); }
let me, profiles = [], programs = [], academicPrograms = [], assignments = [], submissions = [], activeId, refreshing;

function notice(message, error = false) {
  $('#notice').textContent = message;
  $('#notice').className = error ? 'error' : '';
  $('#notice').hidden = false;
  if ($('#detail').open) {
    let inline = $('#detail-notice');
    if (!inline) {
      inline = document.createElement('p');
      inline.id = 'detail-notice';
      inline.setAttribute('role', 'status');
      $('#detail-content').prepend(inline);
    }
    inline.textContent = message;
    inline.style.color = error ? '#a14f3f' : '#245b45';
  }
}

function saveSession(value) {
  session = value ? { ...value, expires_at: value.expires_at || Math.floor(Date.now() / 1000) + value.expires_in } : null;
  if (session) sessionStorage.setItem(sessionKey, JSON.stringify(session));
  else sessionStorage.removeItem(sessionKey);
}

async function request(path, options = {}, authenticate = true) {
  if (!configured) throw new Error('Copy config.example.js to config.js and enter your Supabase URL and public key.');
  if (authenticate && session && session.expires_at < Date.now() / 1000 + 60) {
    refreshing ??= request('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: { refresh_token: session.refresh_token } }, false)
      .then(saveSession).catch(error => { saveSession(null); showLogin(); throw error; }).finally(() => { refreshing = null; });
    await refreshing;
  }
  const response = await fetch(config.supabaseUrl.replace(/\/$/, '') + path, {
    method: options.method || 'GET',
    headers: { apikey: config.supabaseAnonKey, ...(authenticate && session ? { Authorization: `Bearer ${session.access_token}` } : {}), 'Content-Type': 'application/json', ...(options.headers || {}) },
    ...(options.body !== undefined ? { body: JSON.stringify(options.body) } : {})
  });
  const text = await response.text();
  let data;
  try { data = text ? JSON.parse(text) : null; } catch { throw new Error('Unexpected response from Supabase. Check your project URL.'); }
  if (!response.ok) {
    if (response.status === 401 && authenticate) { saveSession(null); showLogin(); }
    throw new Error(data?.msg || data?.message || data?.error_description || data?.error || `Request failed (${response.status})`);
  }
  return data;
}

const rpc = (name, body) => request(`/rest/v1/rpc/${name}`, { method: 'POST', body });
const get = table => request(`/rest/v1/${table}?select=*`);
const person = id => profiles.find(profile => profile.id === id);
const program = id => programs.find(item => item.id === id);
const academicLabel = profile => profile?.academic_program_code ? `${profile.academic_program_code} ${profile.year_level || ''}${profile.section || ''}`.trim() : 'Not specified';
const date = value => value ? new Intl.DateTimeFormat('en-PH', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Manila' }).format(new Date(value)) + ' PHT' : '—';
const badge = value => `<span class="badge ${['Compliant', 'Verified', 'Approved', 'Active'].includes(value) ? 'good' : ['With Deficiency', 'Returned'].includes(value) ? 'bad' : ['Pending', 'Held'].includes(value) ? 'warn' : ''}">${escape(value)}</span>`;

async function run(button, action) {
  if (button) button.disabled = true;
  try { await action(); } catch (error) { notice(error.message, true); } finally { if (button) button.disabled = false; }
}

function showLogin() {
  me = null;
  profiles = []; assignments = []; submissions = [];
  $('#workspace').hidden = true;
  $('#login').hidden = false;
  $('#identity').replaceChildren();
  if ($('#detail').open) $('#detail').close();
}

async function load() {
  [profiles, programs, assignments, submissions, academicPrograms] = await Promise.all([get('profiles'), get('programs'), get('assignments'), get('submissions'), get('academic_programs')]);
  me = profiles.find(profile => profile.auth_user_id === session?.user?.id);
  if (!me) throw new Error('No profile found. Ask your administrator to check account setup.');
  $('#login').hidden = true;
  $('#workspace').hidden = false;
  const staff = me.role === 'Staff';
  $('#staff-panel').hidden = !staff;
  $('#scholar-panel').hidden = staff;
  const assigned = assignments.some(item => item.scholar_id === me.id);
  $('#assignment-notice').hidden = staff || assigned;
  $('#submission-form').hidden = !staff && !assigned;
  $('#page-title').textContent = staff ? 'Semester overview' : 'My scholarship';
  $('#identity').innerHTML = `<span>${escape(me.full_name)} · ${escape(me.role)}</span><button id="logout" class="secondary">Sign out</button>`;
  $('#logout').onclick = () => run($('#logout'), async () => {
    try { await request('/auth/v1/logout', { method: 'POST' }); } finally { saveSession(null); showLogin(); }
  });
  const options = programs.map(item => `<option value="${escape(item.id)}">${escape(item.name)}</option>`).join('');
  const filter = $('#program-filter').value;
  $('#program-filter').innerHTML = '<option value="">All policies</option>' + options;
  $('#program-filter').value = filter;
  $('#register-program').innerHTML = options;
  $('#assignment-program').innerHTML = options;
  const pending = profiles.filter(profile => profile.role === 'Scholar' && profile.student_id && profile.auth_user_id && profile.academic_program_code && !assignments.some(item => item.scholar_id === profile.id));
  $('#pending-registrations').innerHTML = pending.length ? pending.map(profile => `<form class="form-grid pending-assignment" data-scholar="${escape(profile.id)}"><div><strong>${escape(profile.full_name)}</strong><p class="muted small">${escape(profile.student_id)} · ${escape(academicLabel(profile))}<br>${escape(profile.email)}</p></div><label>Scholarship policy<select name="program_id" required>${options}</select></label><button>Approve assignment</button></form>`).join('') : '<p class="muted">No students awaiting assignment.</p>';
  academicPrograms.sort((a, b) => a.college.localeCompare(b.college) || a.name.localeCompare(b.name));
  const academicOptions = academicPrograms.map(item => `<option value="${escape(item.code)}">${escape(item.code)} · ${escape(item.name)}${['Masters', 'Doctoral'].includes(item.level) ? ' · Graduate' : ''}</option>`).join('');
  const academicFilter = $('#academic-filter').value;
  $('#academic-filter').innerHTML = '<option value="">All courses</option>' + academicOptions;
  $('#academic-filter').value = academicFilter;
  $('#register-academic-program').innerHTML = '<option value="">Select academic program</option>' + academicOptions;
  $('#assignment-scholar').innerHTML = assignments.map(item => `<option value="${escape(item.scholar_id)}">${escape(person(item.scholar_id)?.student_id)} · ${escape(person(item.scholar_id)?.full_name)}</option>`).join('');
  $('#policies').innerHTML = programs.map(item => `<div class="policy"><h3>${escape(item.name)}</h3><p>GWA ≤ <strong>${Number(item.max_gwa).toFixed(2)}</strong> · Units ≥ <strong>${item.min_units}</strong></p><p>Failed ≤ ${item.max_failed} · Incomplete ≤ ${item.max_incomplete} · Dropped ≤ ${item.max_dropped}</p><p>Deadline: ${date(item.deadline)}</p></div>`).join('');
  if (!$('#submission-form').children.length) $('#submission-form').innerHTML = summaryFields() + '<button>Submit for verification</button>';
  render();
}

function render() {
  const term = submissions.filter(row => row.academic_year === $('#year').value && row.semester === Number($('#semester').value));
  const stats = [
    ['Assigned scholars', assignments.length],
    ['Pending verification', term.filter(row => row.verification === 'Pending').length],
    ['Compliant', term.filter(row => row.compliance === 'Compliant').length],
    ['With deficiency', term.filter(row => row.compliance === 'With Deficiency').length]
  ];
  $('#stats').innerHTML = stats.map(([label, count]) => `<div class="stat"><span>${label}</span><strong>${count.toString().padStart(2, '0')}</strong></div>`).join('');
  const search = $('#search').value.trim().toLowerCase();
  const visible = term.filter(row => {
    const scholar = person(row.scholar_id);
    return `${scholar?.student_id} ${scholar?.full_name} ${scholar?.test_case_id || ''}`.toLowerCase().includes(search)
      && (!$('#program-filter').value || row.program_id === $('#program-filter').value)
      && (!$('#academic-filter').value || scholar?.academic_program_code === $('#academic-filter').value)
      && (!$('#compliance-filter').value || row.compliance === $('#compliance-filter').value);
  }).sort((a, b) => (person(a.scholar_id)?.student_id || '').localeCompare(person(b.scholar_id)?.student_id || ''));
  $('#records').innerHTML = visible.map(row => {
    const scholar = person(row.scholar_id);
    return `<tr><td><strong>${escape(scholar?.full_name)}</strong><small>${escape(scholar?.student_id)}${scholar?.test_case_id ? ' · ' + escape(scholar.test_case_id) : ''}</small></td><td>${escape(academicLabel(scholar))}</td><td>${escape(program(row.program_id)?.name)}</td><td>${Number(row.gwa).toFixed(2)} / ${row.units}</td><td>${badge(row.verification)}</td><td>${badge(row.compliance)}</td><td>${badge(row.renewal)}</td><td><button class="secondary" data-detail="${escape(row.id)}">View →</button></td></tr>`;
  }).join('');
  $('#record-count').textContent = `${visible.length} records`;
  $('#empty').hidden = visible.length > 0;
}

function summaryFields(row = {}) {
  return [['gwa', 'General weighted average', '1', '5', '0.01'], ['units', 'Enrolled units', '0', '2147483647', '1'], ['failed', 'Failed subjects', '0', '2147483647', '1'], ['incomplete', 'Incomplete grades', '0', '2147483647', '1'], ['dropped', 'Dropped subjects', '0', '2147483647', '1']].map(([name, label, min, max, step]) => `<label>${label}<input name="${name}" type="number" min="${min}" max="${max}" step="${step}" value="${escape(row[name] ?? '')}" required></label>`).join('')
    + `<label class="wide">Grade-document reference<input name="evidence_ref" maxlength="2000" value="${escape(row.evidence_ref || '')}" placeholder="Document ID or grade-document URL" required></label>`;
}

async function submit(form, row) {
  const data = Object.fromEntries(new FormData(form));
  for (const field of ['gwa', 'units', 'failed', 'incomplete', 'dropped']) data[field] = Number(data[field]);
  data.academic_year = row?.academic_year || $('#year').value;
  data.semester = row?.semester || Number($('#semester').value);
  const errors = validateSummary(data);
  if (errors.length) throw new Error(errors.join(' '));
  await rpc('submit_grades', Object.fromEntries([...Object.entries(data).map(([key, value]) => [`p_${key}`, value]), ['p_submission_id', row?.id || null]]));
  form.reset();
  if ($('#detail').open) $('#detail').close();
  await load();
  notice('Summary submitted. Evidence is now Pending verification.');
}

async function openDetail(id) {
  const row = submissions.find(item => item.id === id);
  if (!row) throw new Error('Submission no longer available. Refresh the page.');
  activeId = id;
  const history = await request(`/rest/v1/history?select=*&submission_id=eq.${encodeURIComponent(id)}&order=created_at.desc`);
  const scholar = person(row.scholar_id);
  const assignment = assignments.find(item => item.scholar_id === row.scholar_id);
  $('#detail-content').innerHTML = `<h3>${escape(scholar?.full_name)} · ${escape(scholar?.student_id)}${scholar?.test_case_id ? ' · ' + escape(scholar.test_case_id) : ''}</h3><p class="muted">${escape(academicLabel(scholar))} · ${escape(row.academic_year)} · Semester ${row.semester} · ${escape(program(row.program_id)?.name)}</p><p class="muted small">Profile year: ${escape(scholar?.profile_academic_year || 'Not specified')} · ${escape(scholar?.email)}</p>
    <dl><dt>GWA / units</dt><dd>${Number(row.gwa).toFixed(2)} / ${row.units}</dd><dt>Failed / INC / dropped</dt><dd>${row.failed} / ${row.incomplete} / ${row.dropped}</dd><dt>Evidence reference</dt><dd>${escape(row.evidence_ref)}</dd><dt>Submitted</dt><dd>${date(row.submitted_at)}</dd><dt>Verification</dt><dd>${badge(row.verification)} ${escape(row.verification_reason)}</dd><dt>Compliance</dt><dd>${badge(row.compliance)}</dd><dt>Renewal</dt><dd>${badge(row.renewal)} ${escape(row.decision_notes)}</dd><dt>Award status</dt><dd>${badge(assignment?.award_status || 'Active')}</dd></dl>
    <h3>Policy checks</h3>${row.checks.length ? `<ul class="checks">${row.checks.map(check => `<li>${check.passed ? '✓' : '✗'} ${escape(check.label)}: ${escape(check.actual)} · policy threshold ${escape(check.limit)}</li>`).join('')}</ul>` : '<p class="muted">No final evaluation recorded.</p>'}
    ${row.reasons.length ? `<p><strong>Deficiencies:</strong> ${row.reasons.map(escape).join('; ')}</p>` : ''}
    ${me.role === 'Staff' ? `<h3>Staff actions</h3><form id="verify-form" class="form-grid"><label>Evidence decision<select name="status"><option>Verified</option><option>Returned</option></select></label><label>Reason<input name="reason" required maxlength="2000"></label><button>Record verification</button></form><button id="evaluate">Evaluate compliance</button><form id="renewal-form" class="form-grid"><label>Renewal decision<select name="decision"><option>Approved</option><option>Held</option></select></label><label>Decision notes<input name="notes" required maxlength="2000"></label><button>Record renewal</button></form><p class="muted small">Re-verification and re-evaluation invalidate earlier decisions. Earlier entries remain in history.</p>` : row.verification === 'Returned' ? `<h3>Correct and resubmit</h3><form id="correction-form" class="form-grid">${summaryFields(row)}<button>Resubmit for verification</button></form><p class="muted small">Resubmission records a new timestamp and is checked against the deadline again.</p>` : ''}
    <h3>Audit history</h3><ul class="history">${history.map(item => `<li><strong>${escape(item.action)}</strong> · ${escape(item.notes)}<small>${date(item.created_at)} · ${escape(person(item.actor_id)?.full_name || item.actor_id)}</small><details><summary>Recorded snapshot</summary><pre>${escape(JSON.stringify(item.snapshot, null, 2))}</pre></details></li>`).join('')}</ul>`;
  if (!$('#detail').open) $('#detail').showModal();
  if ($('#verify-form')) $('#verify-form').onsubmit = event => {
    event.preventDefault();
    run(event.submitter, async () => {
      const data = Object.fromEntries(new FormData(event.target));
      await rpc('verify_submission', { p_submission_id: id, p_status: data.status, p_reason: data.reason });
      await load(); await openDetail(id); notice('Verification recorded.');
    });
  };
  if ($('#evaluate')) $('#evaluate').onclick = event => run(event.target, async () => {
    await rpc('evaluate_submission', { p_submission_id: id });
    await load(); await openDetail(id); notice('Policy evaluation recorded.');
  });
  if ($('#renewal-form')) $('#renewal-form').onsubmit = event => {
    event.preventDefault();
    run(event.submitter, async () => {
      const data = Object.fromEntries(new FormData(event.target));
      await rpc('decide_renewal', { p_submission_id: id, p_decision: data.decision, p_notes: data.notes });
      await load(); await openDetail(id); notice('Renewal decision recorded.');
    });
  };
  if ($('#correction-form')) $('#correction-form').onsubmit = event => { event.preventDefault(); run(event.submitter, () => submit(event.target, row)); };
}

function updateLoginRole() {
  const role = $('#login-form input[name="login_role"]:checked').value;
  $('#login-title').textContent = `${role} Login`;
  $('#login-description').textContent = role === 'Staff' ? 'Manage scholars, verify evidence and record renewal decisions.' : 'Access your submissions, verification status and renewal decision.';
  $('#login-submit').innerHTML = `Log in as ${role} <span>→</span>`;
  $('#show-signup').hidden = role === 'Staff';
}

for (const radio of document.querySelectorAll('input[name="login_role"]')) radio.addEventListener('change', updateLoginRole);

$('#login-form').onsubmit = event => {
  event.preventDefault();
  run(event.submitter, async () => {
    const data = Object.fromEntries(new FormData(event.target));
    const { login_role: selectedRole, ...credentials } = data;
    const authenticated = await request('/auth/v1/token?grant_type=password', { method: 'POST', body: credentials }, false);
    const headers = { Authorization: `Bearer ${authenticated.access_token}` };
    let accepted = false;
    try {
      const registration = authenticated.user.user_metadata?.student_registration;
      if (selectedRole === 'Scholar' && registration) {
        await request('/rest/v1/rpc/complete_student_registration', { method: 'POST', headers, body: {
          p_student_id: registration.student_id, p_full_name: registration.full_name,
          p_academic_program_code: registration.academic_program_code, p_year_level: registration.year_level,
          p_section: registration.section, p_profile_academic_year: registration.profile_academic_year
        } }, false);
      }
      const matching = await request(`/rest/v1/profiles?select=role&auth_user_id=eq.${encodeURIComponent(authenticated.user.id)}`, { headers }, false);
      if (matching[0]?.role !== selectedRole) throw new Error(`This account is not registered as ${selectedRole}. Choose the correct login option or ask your administrator to check your profile.`);
      accepted = true;
    } finally {
      if (!accepted) {
        try { await request('/auth/v1/logout', { method: 'POST', headers }, false); } catch {}
      }
    }
    saveSession(authenticated);
    event.target.reset();
    updateLoginRole();
    await load();
    $('#notice').hidden = true;
  });
};

function showSignup(show) {
  $('#login-form').hidden = show;
  $('#signup-panel').hidden = !show;
  if (!show) updateLoginRole();
}

function registrationSuccess(title, message) {
  $('#registration-success-title').textContent = title;
  $('#registration-success-message').textContent = message;
  if (!$('#registration-success').open) $('#registration-success').showModal();
}

$('#close-registration-success').onclick = () => $('#registration-success').close();
$('#registration-success').addEventListener('close', () => {
  const target = $('#workspace').hidden ? $('#login-form input[name="password"]') : $('#register-form input[name="student_id"]');
  target.focus();
});
for (const button of document.querySelectorAll('.password-toggle')) button.onclick = () => {
  const input = document.getElementById(button.dataset.password);
  const show = input.type === 'password';
  input.type = show ? 'text' : 'password';
  button.textContent = show ? 'Hide' : 'Show';
  button.setAttribute('aria-pressed', String(show));
  button.setAttribute('aria-label', `${show ? 'Hide' : 'Show'} ${input.name === 'confirm_password' ? 'confirmation password' : 'password'}`);
};

$('#show-signup').onclick = event => run(event.target, async () => {
  const catalogue = await request('/rest/v1/rpc/registration_programs', { method: 'POST', body: {} }, false);
  $('#signup-program').innerHTML = '<option value="">Select academic program</option>' + catalogue.map(item => `<option value="${escape(item.code)}">${escape(item.code)} · ${escape(item.name)}</option>`).join('');
  showSignup(true);
  $('#signup-panel h2').tabIndex = -1;
  $('#signup-panel h2').focus();
});
$('#back-to-login').onclick = () => showSignup(false);
$('#signup-form').onsubmit = event => {
  event.preventDefault();
  run(event.submitter, async () => {
    const { password, confirm_password: confirmation, ...profile } = Object.fromEntries(new FormData(event.target));
    profile.year_level = Number(profile.year_level);
    profile.email = profile.email.trim().toLowerCase();
    const errors = validateStudentSignup({ ...profile, password, confirm_password: confirmation });
    if (errors.length) throw new Error(errors.join(' '));
    const result = await request('/auth/v1/signup', { method: 'POST', body: { email: profile.email, password, data: { student_registration: profile } } }, false);
    if (result?.access_token) {
      try { await request('/auth/v1/logout', { method: 'POST', headers: { Authorization: `Bearer ${result.access_token}` } }, false); } catch {}
    }
    event.target.reset();
    for (const button of document.querySelectorAll('.password-toggle')) {
      document.getElementById(button.dataset.password).type = 'password';
      button.textContent = 'Show';
      button.setAttribute('aria-pressed', 'false');
      button.setAttribute('aria-label', `Show ${button.dataset.password === 'signup-confirm-password' ? 'confirmation password' : 'password'}`);
    }
    showSignup(false);
    $('#login-form input[value="Scholar"]').checked = true;
    updateLoginRole();
    $('#login-form input[name="email"]').value = profile.email;
    notice('Check your ADSSU inbox and confirm your email, then use Scholar Login. Existing accounts should sign in instead. Staff must assign your scholarship before grade submission.');
    registrationSuccess('Registration submitted', 'Your registration request was received.\n\nCheck your ADSSU inbox for the confirmation email, then sign in using the email and password you entered. If you already have an account, sign in instead.\n\nStaff must assign your scholarship policy before you can submit grades.');
  });
};
$('#pending-registrations').onsubmit = event => {
  const form = event.target.closest('.pending-assignment');
  if (!form) return;
  event.preventDefault();
  run(event.submitter, async () => {
    await rpc('approve_student_assignment', { p_scholar_id: form.dataset.scholar, p_program_id: new FormData(form).get('program_id') });
    await load();
    notice('Student scholarship assignment approved. They can now submit grades.');
  });
};
$('#register-form').onsubmit = event => {
  event.preventDefault();
  run(event.submitter, async () => {
    const data = Object.fromEntries(new FormData(event.target));
    data.year_level = Number(data.year_level);
    const errors = validateScholarProfile(data);
    if (errors.length) throw new Error(errors.join(' '));
    await rpc('register_adssu_scholar', Object.fromEntries(Object.entries(data).map(([key, value]) => [`p_${key}`, value])));
    event.target.reset(); await load(); notice('Scholar registered and program assigned.');
    registrationSuccess('Student profile registered', 'The student profile and scholarship assignment were saved successfully.\n\nThis staff form does not create a login password. The student can create their account through student registration with the same email, or an administrator can create their login privately.');
  });
};
$('#assignment-form').onsubmit = event => {
  event.preventDefault();
  run(event.submitter, async () => {
    const data = Object.fromEntries(new FormData(event.target));
    await rpc('assign_program', { p_scholar_id: data.scholar_id, p_program_id: data.program_id });
    await load(); notice('Program assignment saved.');
  });
};
$('#submission-form').onsubmit = event => { event.preventDefault(); run(event.submitter, () => submit(event.target)); };
$('#refresh').onclick = event => run(event.target, async () => { await load(); if ($('#detail').open) await openDetail(activeId); notice('Data refreshed.'); });
for (const selector of ['#year', '#semester', '#search', '#program-filter', '#academic-filter', '#compliance-filter']) $(selector).addEventListener('input', render);
$('#records').onclick = event => { const button = event.target.closest('[data-detail]'); if (button) run(button, () => openDetail(button.dataset.detail)); };
$('#close-detail').onclick = () => $('#detail').close();
if (!configured) notice('Setup required: copy config.example.js to config.js and enter your Supabase URL and publishable/anon key.', true);
else if (session) run(null, load);
