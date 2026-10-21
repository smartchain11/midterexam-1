begin;

create table public.academic_programs (
  code text primary key,
  name text not null,
  college text not null,
  level text not null check (level in ('Undergraduate','Diploma','Masters','Doctoral')),
  source_url text not null,
  source_note text
);

insert into public.academic_programs(code,name,college,level,source_url)
select code,name,college,level,'https://adssu.edu.ph/baccalaureateprograms'
from (values
  ('BSA-HORTI','Bachelor of Science in Agriculture major in Horticulture','College of Agriculture','Undergraduate'),
  ('BSA-ANSCI','Bachelor of Science in Agriculture major in Animal Science','College of Agriculture','Undergraduate'),
  ('BSA-AGRON','Bachelor of Science in Agriculture major in Agronomy','College of Agriculture','Undergraduate'),
  ('BSAF','Bachelor of Science in Agroforestry','College of Agriculture','Undergraduate'),
  ('BSAGRIB','Bachelor of Science in Agribusiness','College of Agriculture','Undergraduate'),
  ('DIFT','Diploma in Inland Fisheries Technology','College of Agriculture','Diploma'),
  ('BSIS','Bachelor of Science in Information System','College of Computing and Information Sciences','Undergraduate'),
  ('BSIT','Bachelor of Science in Information Technology','College of Computing and Information Sciences','Undergraduate'),
  ('BSECE','Bachelor of Science in Electronics Engineering','College of Engineering and Industrial Technology','Undergraduate'),
  ('BSABE','Bachelor of Science in Agricultural and Biosystems Engineering','College of Engineering and Industrial Technology','Undergraduate'),
  ('BSCE','Bachelor of Science in Civil Engineering','College of Engineering and Industrial Technology','Undergraduate'),
  ('BIT-CT','Bachelor of Industrial Technology major in Civil Technology','College of Engineering and Industrial Technology','Undergraduate'),
  ('BIT-ET','Bachelor of Industrial Technology major in Electronics Technology','College of Engineering and Industrial Technology','Undergraduate'),
  ('BIT-WAFT','Bachelor of Industrial Technology major in Welding and Fabrication Technology','College of Engineering and Industrial Technology','Undergraduate'),
  ('BIT-HVRAC','Bachelor of Industrial Technology major in Heating and Ventilating, Refrigeration and Air Conditioning','College of Engineering and Industrial Technology','Undergraduate'),
  ('BEED','Bachelor of Elementary Education','College of Teacher Education','Undergraduate'),
  ('BSED-ENG','Bachelor of Secondary Education major in English','College of Teacher Education','Undergraduate'),
  ('BSED-SCI','Bachelor of Secondary Education major in Science','College of Teacher Education','Undergraduate'),
  ('BSED-MATH','Bachelor of Secondary Education major in Mathematics','College of Teacher Education','Undergraduate'),
  ('BTLED-IA','Bachelor of Technology and Livelihood Education major in Industrial Arts','College of Teacher Education','Undergraduate'),
  ('BTLED-AFA','Bachelor of Technology and Livelihood Education major in Agri-Fishery Arts','College of Teacher Education','Undergraduate'),
  ('BTLED-HE','Bachelor of Technology and Livelihood Education major in Home Economics','College of Teacher Education','Undergraduate'),
  ('ABEL','Bachelor of Arts in English Language','College of Teacher Education','Undergraduate'),
  ('BSBIO','Bachelor of Science in Biology','College of Arts and Sciences','Undergraduate'),
  ('BSAM','Bachelor of Science in Applied Mathematics','College of Arts and Sciences','Undergraduate'),
  ('BSES','Bachelor of Science in Environmental Science','College of Arts and Sciences','Undergraduate'),
  ('BSENTREP','Bachelor of Science in Entrepreneurship','College of Business Administration','Undergraduate')
) as courses(code,name,college,level);

insert into public.academic_programs(code,name,college,level,source_url,source_note) values
('BSA-SOIL','Bachelor of Science in Agriculture major in Soil Science','College of Agriculture','Undergraduate','https://adssu.edu.ph/adssu-to-offer-bachelor-of-science-in-agriculture-major-in-soil-science','Effective first semester AY 2026-2027; CHED-Caraga RRPA No. 009, s. 2026');

insert into public.academic_programs(code,name,college,level,source_url,source_note)
select code,name,'Graduate School',level,'https://adssu.edu.ph/grad-school-sched','Listed in the official AY 2025-2026 admissions notice; current intake availability requires university confirmation'
from (values
  ('MAEL','Master of Arts in Educational Leadership','Masters'),
  ('MAED-AL','Master of Arts in Education in Applied Linguistics','Masters'),
  ('MSAG','Master of Science in Agriculture','Masters'),
  ('PHDEL','Doctor of Philosophy in Educational Leadership','Doctoral'),
  ('EDD-AL','Doctor of Education in Applied Linguistics','Doctoral'),
  ('PHDAG','Doctor of Philosophy in Agriculture','Doctoral')
) as courses(code,name,level);

alter table public.academic_programs enable row level security;
create policy academic_programs_read on public.academic_programs for select to authenticated using (true);
revoke all on public.academic_programs from public,anon,authenticated;
grant select on public.academic_programs to authenticated;

alter table public.profiles
  add column test_case_id text unique,
  add column academic_program_code text references public.academic_programs(code),
  add column year_level integer check (year_level between 1 and 6),
  add column section text check (section ~ '^[A-Z]{1,3}$'),
  add column profile_academic_year text check (profile_academic_year ~ '^[0-9]{4}-[0-9]{4}$' and substring(profile_academic_year,6,4)::integer = substring(profile_academic_year,1,4)::integer + 1);

update public.profiles p set
  student_id=v.student_id,
  test_case_id=v.test_case_id,
  academic_program_code='BSIT',year_level=3,section='B',profile_academic_year='2026-2027',
  email=case when p.auth_user_id is null and p.email=v.old_email then v.demo_email else p.email end
from (values
  ('20000000-0000-4000-8000-000000000001'::uuid,'B01','M-008759','b01@example.test','demo.asantos01@adssu.edu.ph'),
  ('20000000-0000-4000-8000-000000000002'::uuid,'B02','M-008760','b02@example.test','demo.brivera02@adssu.edu.ph'),
  ('20000000-0000-4000-8000-000000000003'::uuid,'B03','M-008761','b03@example.test','demo.ccruz03@adssu.edu.ph'),
  ('20000000-0000-4000-8000-000000000004'::uuid,'B04','M-008762','b04@example.test','demo.dreyes04@adssu.edu.ph'),
  ('20000000-0000-4000-8000-000000000005'::uuid,'B05','M-008763','b05@example.test','demo.eflores05@adssu.edu.ph'),
  ('20000000-0000-4000-8000-000000000006'::uuid,'B06','M-008764','b06@example.test','demo.fgarcia06@adssu.edu.ph')
) as v(id,test_case_id,student_id,old_email,demo_email)
where p.id=v.id and p.student_id in (v.test_case_id,v.student_id);

create function public.register_adssu_scholar(p_student_id text,p_full_name text,p_email text,p_program_id uuid,p_academic_program_code text,p_year_level integer,p_section text,p_profile_academic_year text) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_id uuid;
begin
  if not public.is_staff() then raise exception 'Staff access required' using errcode = '42501'; end if;
  if p_student_id is null or trim(p_student_id) !~ '^M-[0-9]{6}$' then raise exception 'Student ID must use M- followed by six digits'; end if;
  if p_email is null or lower(trim(p_email)) !~ '^[a-z0-9][a-z0-9._%+-]*@adssu\.edu\.ph$' then raise exception 'Use an ADSSU email address ending in @adssu.edu.ph'; end if;
  if p_academic_program_code is null or not exists(select 1 from public.academic_programs where code=p_academic_program_code) then raise exception 'Select a listed academic program'; end if;
  if p_year_level is null or p_year_level not between 1 and 6 or p_section is null or upper(trim(p_section)) !~ '^[A-Z]{1,3}$' then raise exception 'Year level must be 1-6 and section must be 1-3 letters'; end if;
  if p_profile_academic_year is null or p_profile_academic_year !~ '^[0-9]{4}-[0-9]{4}$' then raise exception 'Use an academic year such as 2026-2027'; end if;
  if substring(p_profile_academic_year,6,4)::integer <> substring(p_profile_academic_year,1,4)::integer + 1 then raise exception 'Academic years must be consecutive'; end if;
  v_id := public.register_scholar(trim(p_student_id),p_full_name,lower(trim(p_email)),p_program_id);
  update public.profiles set academic_program_code=p_academic_program_code,year_level=p_year_level,section=upper(trim(p_section)),profile_academic_year=p_profile_academic_year where id=v_id;
  return v_id;
end;
$$;

revoke all on function public.register_scholar(text,text,text,uuid) from authenticated;
revoke all on function public.register_adssu_scholar(text,text,text,uuid,text,integer,text,text) from public,anon,authenticated;
grant execute on function public.register_adssu_scholar(text,text,text,uuid,text,integer,text,text) to authenticated;

notify pgrst, 'reload schema';
commit;
