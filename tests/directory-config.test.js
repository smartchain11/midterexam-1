import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { filterListings } from '../catalogue.js';
import { defaultPublicConfig, isPublicConfig, resolvePublicConfig } from '../settings.js';

const data = JSON.parse(await readFile(new URL('../data/scholarship-reference.json', import.meta.url), 'utf8'));
const items = data.scholarships;
const override = { supabaseUrl: 'https://example.supabase.co', supabaseAnonKey: 'sb_publishable_example' };

test('Directory preserves all 21 source entries with unique references', () => {
  assert.equal(items.length, 21);
  assert.equal(new Set(items.map(item => item.source_ref)).size, 21);
  assert.ok(data.verification_status.includes('not independently verified'));
});
test('Directory separates 13 document checklists from eight incomplete entries', () => {
  assert.equal(filterListings(items, '', 'detailed').length, 13);
  assert.equal(filterListings(items, '', 'incomplete').length, 8);
  assert.equal(filterListings(items, '', 'all').length, 21);
});
test('Directory searches names case-insensitively and preserves duplicate candidates', () => {
  assert.equal(filterListings(items, '  CHED TULONG  ', 'all').length, 2);
  assert.equal(filterListings(items, 'Bunawan', 'detailed').length, 1);
});
test('Directory searches document names and handles no matches', () => {
  assert.equal(filterListings(items, 'NCIP', 'all').length, 1);
  assert.equal(filterListings(items, 'unlisted scholarship xyz', 'all').length, 0);
});
test('Directory keeps suspicious source data flagged rather than silently fixing it', () => {
  const generic = items.find(item => item.source_ref === 'scholarshipModal93');
  assert.equal(generic.reported_grade_requirement, '2 for SHS / 3.0 for College');
  assert.ok(generic.review_flags.includes('suspicious_shs_grade_scale'));
  assert.deepEqual(generic.reported_documents, []);
});
test('Deployment fallback is valid public configuration without a local config.js', () => {
  assert.equal(isPublicConfig(defaultPublicConfig), true);
  assert.equal(resolvePublicConfig(undefined), defaultPublicConfig);
});
test('Valid local public configuration overrides deployment defaults', () => {
  assert.equal(resolvePublicConfig(override), override);
});
test('Missing or placeholder configuration uses fallback and never becomes active', () => {
  assert.equal(resolvePublicConfig({ supabaseUrl: 'https://YOUR_PROJECT.supabase.co', supabaseAnonKey: 'YOUR_KEY' }), defaultPublicConfig);
  assert.equal(resolvePublicConfig(null, null), null);
});
test('Public configuration rejects secret keys and non-HTTPS URLs', () => {
  assert.equal(isPublicConfig({ ...override, supabaseAnonKey: 'sb_secret_example' }), false);
  assert.equal(isPublicConfig({ ...override, supabaseUrl: 'http://example.supabase.co' }), false);
  assert.equal(isPublicConfig({ ...override, supabaseUrl: 'https://user:password@example.supabase.co' }), false);
});
test('Legacy JWT configuration permits anon role but not service-role keys', () => {
  const key = role => `e30.${Buffer.from(JSON.stringify({ role })).toString('base64url')}.test`;
  assert.equal(isPublicConfig({ ...override, supabaseAnonKey: key('anon') }), true);
  assert.equal(isPublicConfig({ ...override, supabaseAnonKey: key('service_role') }), false);
});
