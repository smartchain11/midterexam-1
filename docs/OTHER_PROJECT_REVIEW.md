# Public scholarship data review

**Source:** https://adssuscholarship.dev/  
**Observed:** 2026-10-21  
**Scope:** Read-only review of the public home page, scholarship cards and their View Requirements modals. No account was created, no application was submitted, no private student data was accessed, and no changes were made to that website.

## Summary

The public portal displays **21 scholarship cards** with **21 requirements modals**. Thirteen entries have descriptions and explicit document lists; eight have generic descriptions and no specific documents listed. These are observations about the portal's published content, not confirmation of official provider rules or current application availability.

All extracted entries are saved in `data/scholarship-reference.json`. The `source_ref` values are public HTML modal identifiers, not a verified interpretation of the other project's private database keys. Descriptions and grade labels are transcribed, including questionable values, rather than silently corrected.

## Detailed public entries

Grade labels below mean **as displayed on the source website**. The page calls these minimum grade requirements and notes that 1.0 is best in college. It does not explicitly specify comparison operators, separate admission from renewal, or identify policy versions. Do not use these numbers as authoritative automated eligibility rules.

| Scholarship | Reported grade label | Reported documents |
|---|---|---|
| TES (Tertiary Education Subsidy) | No strict GWA requirement | COR; Certificate of Indigency |
| CHED Tulong Dunong (TDP) | No strict GWA requirement | COR; ITR |
| DOST-SEI Undergraduate Scholarship | SHS 85 / College 2.5 | COR; SHS Report Card |
| PGAS Baccalaureate (Non-IP) | SHS 85 / College 2.5 | COR; Barangay Certificate of Residency; ITR |
| PGAS Baccalaureate (Indigenous Peoples) | SHS 80 / College 3.0 | COR; NCIP Certification |
| PGAS PWD Scholarship | SHS 80 / College 3.0 | COR; PWD ID |
| Mayor's Scholarship (Prosperidad) | SHS 85 / College 2.5 | COR; Barangay Certificate of Residency |
| Iskolar ng Bayugan (City Grant) | SHS 85 / College 2.5 | COR; Barangay Certificate of Residency |
| Mayor's Scholarship (San Francisco) | SHS 85 / College 2.5 | COR; Barangay Certificate of Residency |
| SFWD Scholarship (San Francisco) | SHS 85 / College 2.5 | COR; ITR |
| Mayor's Scholarship (Bunawan) | SHS 85 / College 2.5 | COR; Barangay Certificate of Residency |
| Mayor's Scholarship (Loreto) | SHS 80 / College 3.0 | COR; Barangay Certificate of Residency |
| Philsaga Mining (PMC) SDMP | SHS 80 / College 3.0 | COR; Barangay Certificate of Residency |

COR = Certificate of Registration; ITR = Income Tax Return. A list on the portal may be incomplete; absence of a document from a list is not proof it is unnecessary.

## Eight entries requiring additional review

Each of these reports **2 for SHS / 3.0 for College**, a generic description starting with “Official”, and **No specific documents listed**:

1. Academic Excellence Grant
2. CHED Tulong Dunong
3. DOST Science & Tech Scholarship
4. LGU Agusan del Sur Financial Aid
5. ADSSU Athletic/Sports Grant
6. Cultural & Arts Scholarship
7. LandBank Educational Assistance
8. GBF TeachSTEM Scholarship

The repeated SHS value `2` is suspicious alongside the other entries' percentage-style `80` and `85`. It may be a mapping, scale, default-value or data-entry issue; the public page alone cannot establish its cause. Do not convert it to 80/85, infer a valid scale, or import it as a verified threshold. Words such as “Official” in a card description are the portal's claims and are not independent verification of provider sponsorship or ADSSU authorization.

## Data-quality findings

| Priority | Finding | Suggested action |
|---|---|---|
| High | CHED Tulong Dunong appears twice: detailed entry says no strict GWA, generic entry reports College 3.0 | Ask the provider which policy/version applies; investigate duplicates without deleting records or merging applications blindly |
| High | DOST-SEI and DOST Science & Tech may overlap, with College 2.5 versus 3.0 | Check whether these are distinct grants, intake/renewal rules, or duplicates before merging |
| High | Eight SHS grade labels use `2`, unlike the other percentage-style labels | Store SHS and college scales explicitly and review source data/rendering |
| High | No amounts, application deadlines, minimum units or failed/INC/drop allowances in the extracted cards/modals | Add provider-backed values with effective dates; use unknown/null rather than invented defaults |
| Medium | Eight entries lack a specific document checklist | Obtain requirements from the provider and distinguish Not configured from No documents required |
| Medium | Generic descriptions do not explain benefits, coverage or important eligibility conditions | Replace boilerplate with attributed, verified summaries |
| Medium | IP entry uses an ancestry eligibility phrase without a linked provider policy | Confirm appropriate eligibility criteria and wording with the issuing authority; do not implement this phrase as an automatic rule |
| Medium | Public cards do not distinguish initial application rules from renewal rules | Model separate policies and effective semesters; a renewal GWA must not be assumed to be the admissions threshold |

## Public interface observations

- The home page supports scholarship browsing and Bootstrap-style requirements modals.
- Apply Now and Proceed to Apply lead to the login page for all observed cards. This does not establish whether the chosen scholarship survives authentication; that needs an authorized account-based test.
- Navigation exposes login and student registration routes. Authentication, uploads, staff review, database design and backend access controls were not assessed in this read-only public review.
- A direct text fetch failed, but the browser loaded the page with a hosting-related query parameter. No conclusion about overall site uptime or security follows from that one fetch failure.

## Safe reuse in the examination project

Keep these public listings in a **reference catalogue**, separate from the exam's mandatory `Excellence Scholar` and `Access Scholar` evaluation policies. The exam requires exactly specified academic conditions, evidence gate and deadline; similarly named real-world listings must not override them.

The initial review did not change policies or the external website. Following the user's request, the snapshot is now displayed in the exam app as a public, reference-only directory with name/document search, checklist completeness filters and requirements dialogs. The directory uses the local JSON file rather than a new policy table. No SQL migration or exam-policy change is required. The same warnings and unknown values are preserved, and no application/eligibility function is implied. Publishing the exam project does not modify the source portal.
