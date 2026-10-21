begin;

update public.profiles p
set test_case_id = 'B0' || n,
    student_id = 'M-' || lpad((8758 + n)::text, 6, '0'),
    academic_program_code = coalesce(p.academic_program_code, 'BSIT'),
    year_level = coalesce(p.year_level, 3),
    section = coalesce(p.section, 'B'),
    profile_academic_year = coalesce(p.profile_academic_year, '2026-2027'),
    email = case
      when p.auth_user_id is null and p.email = 'b0' || n || '@example.test'
      then (array[
        'demo.asantos01@adssu.edu.ph',
        'demo.brivera02@adssu.edu.ph',
        'demo.ccruz03@adssu.edu.ph',
        'demo.dreyes04@adssu.edu.ph',
        'demo.eflores05@adssu.edu.ph',
        'demo.fgarcia06@adssu.edu.ph'
      ])[n]
      else p.email
    end
from generate_series(1, 6) n
where p.id = ('20000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
  and p.student_id in ('B0' || n, 'M-' || lpad((8758 + n)::text, 6, '0'));

commit;

select test_case_id, student_id, full_name, email,
       academic_program_code, year_level, section, profile_academic_year
from public.profiles
where test_case_id in ('B01','B02','B03','B04','B05','B06')
order by test_case_id;
