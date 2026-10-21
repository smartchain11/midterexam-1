# ADSSU academic catalogue and profile format

Research checked against the university's public website on 2026-10-21. This examination prototype is not an official ADSSU service. Names below reflect the linked university pages; catalogue codes are normalized internal application codes, not a claim about official registrar codes.

## Main catalogue: 28 entries

Source: [ADSSU Baccalaureate Programs](https://adssu.edu.ph/baccalaureateprograms), supplemented by the [official Soil Science announcement](https://adssu.edu.ph/adssu-to-offer-bachelor-of-science-in-agriculture-major-in-soil-science). The main page contains 27 entries, including a diploma rather than exclusively bachelor's degrees. The Soil Science announcement adds a course effective first semester AY 2026–2027, CHED-Caraga RRPA No. 009, s. 2026.

### College of Agriculture

| Application code | Academic program |
|---|---|
| BSA-HORTI | BS in Agriculture major in Horticulture |
| BSA-ANSCI | BS in Agriculture major in Animal Science |
| BSA-AGRON | BS in Agriculture major in Agronomy |
| BSA-SOIL | BS in Agriculture major in Soil Science — effective AY 2026–2027 |
| BSAF | BS in Agroforestry |
| BSAGRIB | BS in Agribusiness |
| DIFT | Diploma in Inland Fisheries Technology |

### College of Computing and Information Sciences

| Application code | Academic program |
|---|---|
| BSIS | BS in Information System, using the wording on the official page |
| BSIT | BS in Information Technology |

### College of Engineering and Industrial Technology

| Application code | Academic program |
|---|---|
| BSECE | BS in Electronics Engineering |
| BSABE | BS in Agricultural and Biosystems Engineering |
| BSCE | BS in Civil Engineering |
| BIT-CT | Bachelor of Industrial Technology major in Civil Technology |
| BIT-ET | Bachelor of Industrial Technology major in Electronics Technology |
| BIT-WAFT | Bachelor of Industrial Technology major in Welding and Fabrication Technology |
| BIT-HVRAC | Bachelor of Industrial Technology major in Heating and Ventilating, Refrigeration and Air Conditioning |

### College of Teacher Education

| Application code | Academic program |
|---|---|
| BEED | Bachelor of Elementary Education |
| BSED-ENG | Bachelor of Secondary Education major in English |
| BSED-SCI | Bachelor of Secondary Education major in Science |
| BSED-MATH | Bachelor of Secondary Education major in Mathematics |
| BTLED-IA | Bachelor of Technology and Livelihood Education major in Industrial Arts |
| BTLED-AFA | Bachelor of Technology and Livelihood Education major in Agri-Fishery Arts |
| BTLED-HE | Bachelor of Technology and Livelihood Education major in Home Economics |
| ABEL | Bachelor of Arts in English Language |

### College of Arts and Sciences

| Application code | Academic program |
|---|---|
| BSBIO | BS in Biology |
| BSAM | BS in Applied Mathematics |
| BSES | BS in Environmental Science |

### College of Business Administration

| Application code | Academic program |
|---|---|
| BSENTREP | BS in Entrepreneurship |

## Graduate listings: six additional entries

Source: [official Graduate School Admission Schedule for AY 2025–2026](https://adssu.edu.ph/grad-school-sched), corroborated by the [second-semester graduate admissions announcement](https://adssu.edu.ph/asscat-graduate-school-is-now-accepting-applications-for-second-semester).

| Application code | Academic program |
|---|---|
| MAEL | Master of Arts in Educational Leadership |
| MAED-AL | Master of Arts in Education in Applied Linguistics |
| MSAG | Master of Science in Agriculture |
| PHDEL | Doctor of Philosophy in Educational Leadership |
| EDD-AL | Doctor of Education in Applied Linguistics |
| PHDAG | Doctor of Philosophy in Agriculture |

These six are documented graduate offerings, but their cited intake notice is for 2025–2026. Confirm current availability and arrangements with ADSSU. The public pages do not establish whether each degree is independently delivered, consortium-delivered or open every semester. They are marked with the older source note in the database. No invented graduate specializations are added.

## Completeness caveat

This is a source-backed catalogue, not a guaranteed exhaustive current registrar list across both campuses. Older institutional history/manuals also mention Agricultural Technology, Oil Palm Technology, Teachers' Certification Curriculum and an engineering master's program. The admissions site search result mentions TCC, but its full current list could not be retrieved. These historical/partially verified entries are not silently marked as current or added to the selectable catalogue. Confirm them with admissions if required. The verified database catalogue therefore has **34 entries: 28 main-page/new-offering entries plus six graduate listings**.

## Synthetic scholar mapping

All six profiles use `BSIT 3B`, profile academic year `2026-2027`, and semester submission year `2026-2027`. Their academic test values, scholarship policy, evidence status, timestamps and record UUIDs stay unchanged.

| Test case | Synthetic student ID | Fictional name | Synthetic format-only email |
|---|---|---|---|
| B01 | M-008759 | Amara Santos | demo.asantos01@adssu.edu.ph |
| B02 | M-008760 | Ben Rivera | demo.brivera02@adssu.edu.ph |
| B03 | M-008761 | Celia Cruz | demo.ccruz03@adssu.edu.ph |
| B04 | M-008762 | Diego Reyes | demo.dreyes04@adssu.edu.ph |
| B05 | M-008763 | Elena Flores | demo.eflores05@adssu.edu.ph |
| B06 | M-008764 | Felix Garcia | demo.fgarcia06@adssu.edu.ph |

These addresses reproduce the requested institutional domain only. They are not verified accounts and must not receive invitations, password resets or other messages. Create auto-confirmed test Auth accounts manually in a dedicated project. No real student identity should be used for examination data.

## Applying the upgrade

- **Fresh database:** run `01_schema.sql`, `02_seed.sql`, then `04_adssu_profiles.sql`, once each, before creating scholar Auth users.
- **Already ran the original schema and seed:** run only `04_adssu_profiles.sql`. It does not delete submissions, history or Auth users, and does not change their academic values. It updates only the six known fixture UUIDs carrying their original B01–B06 IDs or the corresponding new M-format IDs. Do not rerun `02_seed.sql`.
- **Already created scholar Auth accounts:** linked fixture emails stay unchanged to preserve login identity. For example, an existing B01 login at `b01@example.test` keeps working after its displayed student ID changes to M-008759. Do not edit only the profile email; Auth and profile identity must remain aligned. Use the query below to find the actual login email. Changing an existing login email to an ADSSU-format placeholder requires a separate administrator-managed operation and is not performed by this migration.
- **Already ran the upgrade:** do not rerun it. No reset or deletion is needed.

```sql
select test_case_id, student_id, full_name, email,
       academic_program_code, year_level, section, profile_academic_year,
       auth_user_id
from public.profiles
where test_case_id is not null
order by test_case_id;
```

The original `register_scholar` RPC is no longer directly granted to authenticated clients after the upgrade. The new `register_adssu_scholar` RPC validates the ID, domain, academic-program FK, year/section and academic year, then creates the profile and scholarship assignment atomically. It does not infer scholarship eligibility from academic course choice. Source-code comments remain absent.
