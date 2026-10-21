import { readFile } from 'node:fs/promises';
import { createInterface } from 'node:readline/promises';

const input = process.stdin;
const output = process.stdout;

async function ask(label) {
  const reader = createInterface({ input, output });
  try { return (await reader.question(label)).trim(); } finally { reader.close(); }
}

async function secret(label) {
  if (!input.isTTY || typeof input.setRawMode !== 'function') throw new Error('Run this command in an interactive terminal so secrets can be hidden.');
  output.write(label);
  return new Promise((resolve, reject) => {
    let value = '';
    input.setRawMode(true);
    input.resume();
    input.setEncoding('utf8');
    const finish = () => {
      input.removeListener('data', onData);
      input.setRawMode(false);
      input.pause();
      output.write('\n');
    };
    const onData = chunk => {
      for (const char of chunk) {
        if (char === '\u0003') { finish(); reject(new Error('Cancelled')); return; }
        if (char === '\r' || char === '\n') { finish(); resolve(value); return; }
        if (char === '\u007f' || char === '\b') { value = value.slice(0, -1); continue; }
        if (char >= ' ' && char !== '\u001b') value += char;
      }
    };
    input.on('data', onData);
  });
}

async function password(label) {
  const value = await secret(label);
  if (value.length < 12) throw new Error('Use a password with at least 12 characters.');
  if (value !== await secret('Confirm password: ')) throw new Error('Passwords do not match. No account was changed for this step.');
  return value;
}

async function main() {
  const source = await readFile(new URL('../config.js', import.meta.url), 'utf8');
  const projectUrl = source.match(/supabaseUrl\s*:\s*["'](https:\/\/[^"']+)["']/)?.[1]?.replace(/\/$/, '');
  if (!projectUrl) throw new Error('Set supabaseUrl in config.js first.');
  console.log(`Project: ${projectUrl}`);
  console.log('Use a dedicated examination project. Secrets are hidden, held in memory only, and never written to files.');
  const adminKey = (await secret('Supabase secret or service-role key: ')).trim();
  if (!adminKey || adminKey.startsWith('sb_publishable_')) throw new Error('A secret or service-role key is required, not the browser publishable key.');
  async function api(path, options = {}) {
    const response = await fetch(projectUrl + path, {
      method: options.method || 'GET',
      headers: { apikey: adminKey, ...(adminKey.startsWith('sb_secret_') ? {} : { Authorization: `Bearer ${adminKey}` }), 'Content-Type': 'application/json', Prefer: 'return=representation' },
      ...(options.body ? { body: JSON.stringify(options.body) } : {})
    });
    const text = await response.text();
    let data;
    try { data = text ? JSON.parse(text) : null; } catch { throw new Error(`Supabase returned an unexpected response (${response.status}).`); }
    if (!response.ok) throw new Error(data?.msg || data?.message || data?.error_description || `Supabase request failed (${response.status}).`);
    return data;
  }

  const fixtures = await api('/rest/v1/profiles?select=id,email,auth_user_id&test_case_id=eq.B01');
  if (fixtures.length !== 1) throw new Error('Run schema 01, seed 02, and ADSSU migration 04 first. Exactly one B01 fixture is required.');
  const staffEmail = (await ask('Staff email [demo.staff@adssu.edu.ph]: ') || 'demo.staff@adssu.edu.ph').toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(staffEmail)) throw new Error('Enter a valid staff email.');
  if (staffEmail === fixtures[0].email) throw new Error('Staff and student accounts must use different emails.');

  async function provision(email, role, fixture) {
    const rows = await api(`/rest/v1/profiles?select=id,role,auth_user_id&email=eq.${encodeURIComponent(email)}`);
    const existing = rows[0];
    if (role === 'Staff' && existing?.role === 'Scholar') {
      const assignments = await api(`/rest/v1/assignments?select=scholar_id&scholar_id=eq.${encodeURIComponent(existing.id)}`);
      if (assignments.length) throw new Error('That email belongs to an assigned scholar. Choose a separate staff email.');
    }
    if (fixture && existing?.id !== fixture.id) throw new Error('Student profile does not match the expected B01 fixture.');
    let authId = existing?.auth_user_id;
    if (authId) {
      console.log(`${role} account already exists: ${email}`);
      const choice = await ask('Replace its password and confirm this test account? Type YES to proceed, or press Enter to keep it: ');
      if (choice === 'YES') {
        const value = await password(`New ${role.toLowerCase()} password: `);
        await api(`/auth/v1/admin/users/${encodeURIComponent(authId)}`, { method: 'PUT', body: { password: value, email_confirm: true } });
        console.log(`${role} password updated.`);
      } else console.log(`${role} password kept unchanged.`);
    } else {
      const value = await password(`Choose ${role.toLowerCase()} password: `);
      const created = await api('/auth/v1/admin/users', { method: 'POST', body: { email, password: value, email_confirm: true } });
      authId = created.id || created.user?.id;
      if (!authId) throw new Error('Account creation returned no user ID. Check Authentication → Users before retrying.');
      if (existing) {
        const linked = await api(`/rest/v1/profiles?id=eq.${encodeURIComponent(existing.id)}&auth_user_id=is.null`, { method: 'PATCH', body: { auth_user_id: authId } });
        if (linked?.length !== 1) throw new Error('Auth account was created, but profile linking needs administrator review. No existing linked profile was overwritten.');
      }
      console.log(`${role} authentication account created without sending an invitation.`);
    }
    const updated = await api(`/rest/v1/profiles?auth_user_id=eq.${encodeURIComponent(authId)}`, {
      method: 'PATCH', body: role === 'Staff' ? { role: 'Staff', full_name: 'Demo Scholarship Staff' } : { role: 'Scholar' }
    });
    if (updated?.length !== 1) throw new Error(`Auth account exists, but its profile could not be linked. Check the profile trigger for ${email}.`);
    console.log(`Ready: ${role} Login → ${email}`);
  }

  await provision(staffEmail, 'Staff');
  await provision(fixtures[0].email, 'Scholar', fixtures[0]);
  console.log('Open http://127.0.0.1:3000 and use the passwords you entered. Keep credentials private.');
}

main().catch(error => { console.error(`Setup stopped: ${error.message}`); process.exitCode = 1; });
