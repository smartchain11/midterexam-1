export function validateScholarProfile(value) {
  const errors = [];
  if (!/^M-\d{6}$/.test(value.student_id?.trim() || '')) errors.push('Student ID must use M- followed by six digits.');
  if (!/^[a-z0-9][a-z0-9._%+-]*@adssu\.edu\.ph$/i.test(value.email?.trim() || '')) errors.push('Use an ADSSU email address ending in @adssu.edu.ph.');
  if (!value.full_name?.trim() || value.full_name.trim().length > 120) errors.push('A full name of 1–120 characters is required.');
  if (!value.academic_program_code) errors.push('Select an academic program.');
  if (!Number.isInteger(value.year_level) || value.year_level < 1 || value.year_level > 6) errors.push('Year level must be 1–6.');
  if (!/^[A-Z]{1,3}$/i.test(value.section?.trim() || '')) errors.push('Section must be 1–3 letters.');
  if (!/^\d{4}-\d{4}$/.test(value.profile_academic_year || '') || Number(value.profile_academic_year?.slice(5)) !== Number(value.profile_academic_year?.slice(0, 4)) + 1) errors.push('Profile academic year must use consecutive years such as 2026-2027.');
  return errors;
}

export function validateStudentSignup(value) {
  const errors = validateScholarProfile(value);
  if (typeof value.password !== 'string' || value.password.length < 12) errors.push('Password must have at least 12 characters.');
  if (value.password !== value.confirm_password) errors.push('Passwords do not match.');
  return errors;
}

export function validateSummary(value) {
  const errors = [];
  if (!Number.isFinite(value.gwa) || value.gwa < 1 || value.gwa > 5 || Math.abs(value.gwa * 100 - Math.round(value.gwa * 100)) > 1e-8) errors.push('GWA must be 1.00–5.00 with at most two decimals.');
  for (const key of ['units', 'failed', 'incomplete', 'dropped']) {
    if (!Number.isSafeInteger(value[key]) || value[key] < 0 || value[key] > 2147483647) errors.push(`${key} must be a nonnegative integer.`);
  }
  if (!value.evidence_ref?.trim() || value.evidence_ref.trim().length > 2000) errors.push('A grade-document reference of 1–2000 characters is required.');
  if (!/^\d{4}-\d{4}$/.test(value.academic_year) || Number(value.academic_year.slice(5)) !== Number(value.academic_year.slice(0, 4)) + 1) errors.push('Academic year must be consecutive years, such as 2026-2027.');
  if (![1, 2, 3].includes(value.semester)) errors.push('Select a valid semester.');
  return errors;
}

export function previewCompliance(row, policy) {
  if (row.verification !== 'Verified' || !row.evidence_ref?.trim()) throw new Error('Verified evidence is required before evaluation');
  const checks = [
    ['GWA', row.gwa <= policy.max_gwa, 'GWA exceeds program maximum'],
    ['Enrolled units', row.units >= policy.min_units, 'Insufficient enrolled units'],
    ['Failed subjects', row.failed <= policy.max_failed, 'Failed subjects exceed allowance'],
    ['Incomplete grades', row.incomplete <= policy.max_incomplete, 'Incomplete grades exceed allowance'],
    ['Dropped subjects', row.dropped <= policy.max_dropped, 'Dropped subjects exceed allowance'],
    ['Submission deadline', new Date(row.submitted_at) <= new Date(policy.deadline), 'Late submission']
  ];
  const reasons = checks.filter(check => !check[1]).map(check => check[2]);
  return { compliance: reasons.length ? 'With Deficiency' : 'Compliant', reasons };
}
