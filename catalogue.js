const $ = selector => document.querySelector(selector);
const escape = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
let listings = [];
let lastButton;

function needsReview(item) {
  return item.review_flags.filter(flag => flag !== 'provider_verification_required');
}

export function filterListings(items, search, quality) {
  const query = search.trim().toLowerCase();
  return items.filter(item => {
    const matches = [item.name, item.description, ...item.reported_documents].join(' ').toLowerCase().includes(query);
    return matches && (quality === 'all' || (quality === 'detailed' && item.reported_documents.length > 0) || (quality === 'incomplete' && item.reported_documents.length === 0));
  });
}

function render() {
  const visible = filterListings(listings, $('#directory-search').value, $('#directory-quality').value);
  $('#directory-count').textContent = `${visible.length} of ${listings.length} listings`;
  $('#directory-status').hidden = visible.length > 0;
  $('#directory-status').textContent = 'No scholarships match your search.';
  $('#directory-cards').innerHTML = visible.map(item => `<article class="card scholarship-card"><span class="eyebrow">PORTAL LISTING · NOT VERIFIED</span><h3>${escape(item.name)}</h3><p class="muted">${escape(item.description)}</p><p class="small"><strong>Grade label on source:</strong> ${escape(item.reported_grade_requirement)}</p>${needsReview(item).length ? '<p class="small review-note">Data needs review — see requirements.</p>' : '<p class="small muted">Confirm rules and availability with the provider.</p>'}<button class="secondary" data-scholarship="${escape(item.source_ref)}">View requirements →</button></article>`).join('');
}

function showDetails(ref, button) {
  const item = listings.find(row => row.source_ref === ref);
  if (!item) return;
  lastButton = button;
  $('#scholarship-details-title').textContent = item.name;
  const reviewLabels = {
    conflicting_grade_rules: 'Another potentially overlapping listing reports different grade rules.',
    suspicious_shs_grade_scale: 'The SHS grade value appears inconsistent with other entries. Do not use it for eligibility decisions.',
    generic_description: 'This description is generic and needs provider confirmation.',
    missing_document_list: 'The portal does not provide a specific document checklist.',
    eligibility_wording_requires_provider_confirmation: 'Eligibility wording must be confirmed with the issuing authority.'
  };
  const notes = [...new Set(needsReview(item).map(flag => reviewLabels[flag] || (flag.startsWith('possible_') ? 'Possible duplicate or overlapping scholarship listing; provider review is required.' : 'Provider review is required.')))];
  $('#scholarship-details-content').innerHTML = `<p>${escape(item.description)}</p><h3>Reported grade requirement</h3><p>${escape(item.reported_grade_requirement)}</p><p class="muted small">Transcribed from the source. Comparison operators, application-versus-renewal rules and effective policy dates are not specified. The source says 1.0 is best for college grades.</p><h3>Documents listed on the portal</h3>${item.reported_documents.length ? `<ul class="checks">${item.reported_documents.map(document => `<li>${escape(document)}</li>`).join('')}</ul>` : '<p class="review-note">No specific documents are listed. This does not mean no documents are required.</p>'}${notes.length ? `<h3>Review notes</h3><ul class="checks">${notes.map(note => `<li>${escape(note)}</li>`).join('')}</ul>` : ''}<p class="directory-disclaimer">Award amounts, application deadlines, enrolled-unit requirements and failed/INC/drop allowances are not provided in this snapshot. Confirm them with the provider. This directory does not affect exam compliance or renewal decisions.</p><a href="https://adssuscholarship.dev/#programs" target="_blank" rel="noopener noreferrer">View source portal ↗</a>`;
  $('#scholarship-details').showModal();
}

async function startDirectory() {
  try {
    const response = await fetch(new URL('./data/scholarship-reference.json', import.meta.url));
    if (!response.ok) throw new Error('Could not load the scholarship directory. Check that the data file is included in your deployment.');
    const data = await response.json();
    listings = data.scholarships;
    $('#directory-date').textContent = data.observed_date;
    render();
  } catch (error) {
    $('#directory-status').hidden = false;
    $('#directory-status').textContent = error.message;
  }
}

if (typeof document !== 'undefined') {
  $('#directory-search').addEventListener('input', render);
  $('#directory-quality').addEventListener('change', render);
  $('#directory-cards').addEventListener('click', event => {
    const button = event.target.closest('[data-scholarship]');
    if (button) showDetails(button.dataset.scholarship, button);
  });
  $('#close-scholarship-details').onclick = () => $('#scholarship-details').close();
  $('#scholarship-details').addEventListener('close', () => { if (lastButton?.isConnected) lastButton.focus(); });
  startDirectory();
}
