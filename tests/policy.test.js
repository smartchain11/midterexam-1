import test from 'node:test';
import assert from 'node:assert/strict';
import { previewCompliance, validateSummary, validateScholarProfile, validateStudentSignup } from '../domain.js';

const excellence = { max_gwa: 2, min_units: 18, max_failed: 0, max_incomplete: 0, max_dropped: 0, deadline: '2026-11-06T17:00:00+08:00' };
const access = { ...excellence, max_gwa: 2.5, min_units: 15, max_dropped: 1 };
const base = { gwa: 2, units: 18, failed: 0, incomplete: 0, dropped: 0, evidence_ref: 'TEST-REFERENCE', verification: 'Verified', submitted_at: excellence.deadline, academic_year: '2026-2027', semester: 1 };

test('TC01 preview: exact GWA and deadline are compliant', () => {
  assert.deepEqual(previewCompliance(base, excellence), { compliance: 'Compliant', reasons: [] });
});
test('TC02 preview: GWA above limit', () => {
  assert.deepEqual(previewCompliance({ ...base, gwa: 2.01 }, excellence).reasons, ['GWA exceeds program maximum']);
});
test('TC03 preview: Access allows one dropped subject', () => {
  assert.equal(previewCompliance({ ...base, gwa: 2.5, units: 15, dropped: 1 }, access).compliance, 'Compliant');
});
test('TC04 preview: insufficient units and incomplete grade', () => {
  assert.deepEqual(previewCompliance({ ...base, gwa: 2.5, units: 14, incomplete: 1 }, access).reasons, ['Insufficient enrolled units', 'Incomplete grades exceed allowance']);
});
test('TC05 preview: failed subject and lateness', () => {
  assert.deepEqual(previewCompliance({ ...base, gwa: 1.75, failed: 1, submitted_at: '2026-11-06T17:01:00+08:00' }, excellence).reasons, ['Failed subjects exceed allowance', 'Late submission']);
});
test('TC06 preview: unverified or missing evidence blocks evaluation', () => {
  assert.throws(() => previewCompliance({ ...base, verification: 'Pending' }, access));
  assert.throws(() => previewCompliance({ ...base, evidence_ref: '' }, access));
});
test('TC07 validation: GWA 0.50, negative and fractional counts', () => {
  assert.equal(validateSummary(base).length, 0);
  assert.ok(validateSummary({ ...base, gwa: 0.5 }).length);
  assert.ok(validateSummary({ ...base, failed: -1 }).length);
  assert.ok(validateSummary({ ...base, units: 1.5 }).length);
});
test('Validation: GWA inclusive input boundaries, precision and year', () => {
  for (const gwa of [1, 5, 2.01]) assert.equal(validateSummary({ ...base, gwa }).length, 0);
  for (const gwa of [0.99, 5.01, NaN, 2.001]) assert.ok(validateSummary({ ...base, gwa }).length);
  assert.ok(validateSummary({ ...base, academic_year: '2026-2028' }).length);
  assert.ok(validateSummary({ ...base, evidence_ref: ' ' }).length);
});
test('Deadline: one millisecond late fails; UTC and Manila are equivalent', () => {
  assert.equal(previewCompliance({ ...base, submitted_at: '2026-11-06T09:00:00Z' }, excellence).compliance, 'Compliant');
  assert.deepEqual(previewCompliance({ ...base, submitted_at: '2026-11-06T09:00:00.001Z' }, excellence).reasons, ['Late submission']);
});
test('Selected policy changes outcome', () => {
  const row = { ...base, gwa: 2.25, units: 15, dropped: 1 };
  assert.equal(previewCompliance(row, access).compliance, 'Compliant');
  assert.equal(previewCompliance(row, excellence).reasons.length, 3);
});

const scholar = { student_id: 'M-008759', full_name: 'Amara Santos', email: 'demo.asantos01@adssu.edu.ph', academic_program_code: 'BSIT', year_level: 3, section: 'B', profile_academic_year: '2026-2027' };
test('ADSSU profile accepts the requested format', () => {
  assert.deepEqual(validateScholarProfile(scholar), []);
});
test('ADSSU profile rejects malformed student IDs and noninstitutional email', () => {
  for (const student_id of ['B01', '008759', 'M-8759', 'M-0087590']) assert.ok(validateScholarProfile({ ...scholar, student_id }).length);
  for (const email of ['test@gmail.com', 'test@adssu.edu.ph.attacker.test', '@adssu.edu.ph', 'a b@adssu.edu.ph']) assert.ok(validateScholarProfile({ ...scholar, email }).length);
});
test('ADSSU profile validates year, section, course and academic year', () => {
  for (const year_level of [0, 7, 1.5]) assert.ok(validateScholarProfile({ ...scholar, year_level }).length);
  assert.ok(validateScholarProfile({ ...scholar, academic_program_code: '' }).length);
  assert.ok(validateScholarProfile({ ...scholar, section: '3B' }).length);
  assert.ok(validateScholarProfile({ ...scholar, profile_academic_year: '2026-2028' }).length);
});
test('ADSSU profile accepts email case and lowercase section for normalization', () => {
  assert.deepEqual(validateScholarProfile({ ...scholar, email: 'Demo.Asantos01@ADSSU.EDU.PH', section: 'b' }), []);
});

const signup = { ...scholar, password: 'a'.repeat(12), confirm_password: 'a'.repeat(12) };
test('Student signup accepts a valid profile and matching 12-character passwords', () => {
  assert.deepEqual(validateStudentSignup(signup), []);
});
test('Student signup rejects missing or short passwords', () => {
  assert.ok(validateStudentSignup({ ...signup, password: undefined, confirm_password: undefined }).length);
  assert.ok(validateStudentSignup({ ...signup, password: 'a'.repeat(11), confirm_password: 'a'.repeat(11) }).length);
});
test('Student signup rejects password mismatch', () => {
  assert.ok(validateStudentSignup({ ...signup, confirm_password: 'b'.repeat(12) }).includes('Passwords do not match.'));
});
test('Student signup still enforces institutional identity and academic fields', () => {
  assert.ok(validateStudentSignup({ ...signup, email: 'student@example.test' }).length);
  assert.ok(validateStudentSignup({ ...signup, student_id: 'B01' }).length);
  assert.ok(validateStudentSignup({ ...signup, academic_program_code: '' }).length);
});
