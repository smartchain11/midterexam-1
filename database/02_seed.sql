begin;

insert into public.programs(id,name,max_gwa,min_units,max_failed,max_incomplete,max_dropped,deadline) values
('10000000-0000-4000-8000-000000000001','Excellence Scholar',2.00,18,0,0,0,'2026-11-06 17:00:00+08'),
('10000000-0000-4000-8000-000000000002','Access Scholar',2.50,15,0,0,1,'2026-11-06 17:00:00+08');

insert into public.profiles(id,student_id,full_name,email) values
('20000000-0000-4000-8000-000000000001','M-008759','Amara Santos','demo.asantos01@adssu.edu.ph'),
('20000000-0000-4000-8000-000000000002','M-008760','Ben Rivera','demo.brivera02@adssu.edu.ph'),
('20000000-0000-4000-8000-000000000003','M-008761','Celia Cruz','demo.ccruz03@adssu.edu.ph'),
('20000000-0000-4000-8000-000000000004','M-008762','Diego Reyes','demo.dreyes04@adssu.edu.ph'),
('20000000-0000-4000-8000-000000000005','M-008763','Elena Flores','demo.eflores05@adssu.edu.ph'),
('20000000-0000-4000-8000-000000000006','M-008764','Felix Garcia','demo.fgarcia06@adssu.edu.ph');

insert into public.assignments(scholar_id,program_id)
select p.id,case when n in (1,2,5) then '10000000-0000-4000-8000-000000000001'::uuid else '10000000-0000-4000-8000-000000000002'::uuid end
from generate_series(1,6) n join public.profiles p on p.id=('20000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;

insert into public.submissions(id,scholar_id,program_id,academic_year,semester,gwa,units,failed,incomplete,dropped,evidence_ref,submitted_at,verification,verification_reason)
select ('30000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,p.id,a.program_id,'2026-2027',1,
  case n when 1 then 2.00 when 2 then 2.01 when 3 then 2.50 when 4 then 2.50 when 5 then 1.75 else 2.25 end,
  case when n in (1,2,5) then 18 when n=4 then 14 else 15 end,
  case when n=5 then 1 else 0 end,case when n=4 then 1 else 0 end,case when n=3 then 1 else 0 end,
  'SYNTHETIC-GRADE-B0'||n,
  case n when 1 then '2026-11-06 17:00:00+08'::timestamptz when 5 then '2026-11-06 17:01:00+08'::timestamptz else '2026-11-05 17:00:00+08'::timestamptz end,
  case when n=6 then 'Pending' else 'Verified' end,
  case when n=6 then null else 'Synthetic preverified examination fixture' end
from generate_series(1,6) n join public.profiles p on p.id=('20000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid join public.assignments a on a.scholar_id=p.id;

insert into public.history(submission_id,actor_id,action,notes,snapshot)
select id,scholar_id,'Seeded fixture','Synthetic test input; preverified status is fixture setup, not a live staff action',to_jsonb(s) from public.submissions s;

commit;
