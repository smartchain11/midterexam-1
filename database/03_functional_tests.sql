begin;

create function pg_temp.assert_true(p_condition boolean,p_message text) returns void
language plpgsql as $$
begin
  if p_condition is distinct from true then raise exception 'FAIL: %',p_message; end if;
  raise notice 'PASS: %',p_message;
end;
$$;

create function pg_temp.expect_failure(p_sql text,p_match text,p_message text) returns void
language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if position(lower(p_match) in lower(sqlerrm)) > 0 then raise notice 'PASS: %',p_message; return; end if;
    raise;
  end;
  raise exception 'FAIL: expected rejection: %',p_message;
end;
$$;

select set_config('exam.staff_auth',(select auth_user_id::text from public.profiles where role='Staff' and auth_user_id is not null limit 1),true);
select set_config('exam.scholar_auth',(select auth_user_id::text from public.profiles where id='20000000-0000-4000-8000-000000000001'),true);
select pg_temp.assert_true(nullif(current_setting('exam.staff_auth'),'') is not null,'Staff account exists');
select pg_temp.assert_true(nullif(current_setting('exam.scholar_auth'),'') is not null,'B01 authentication account exists');
select set_config('request.jwt.claims',json_build_object('sub',current_setting('exam.staff_auth'),'role','authenticated')::text,true);
set local role authenticated;

select pg_temp.assert_true((select count(*)=34 from public.academic_programs),'ADSSU source-backed catalogue has 34 entries');
select pg_temp.assert_true((select student_id='M-008759' and test_case_id='B01' and academic_program_code='BSIT' and year_level=3 and section='B' from public.profiles where id='20000000-0000-4000-8000-000000000001'),'ADSSU seeded profile format');
select pg_temp.expect_failure($q$select public.register_adssu_scholar('B99','Synthetic Test','demo.test99@adssu.edu.ph','10000000-0000-4000-8000-000000000001','BSIT',3,'B','2026-2027')$q$,'Student ID','ADSSU invalid student ID denied');
select pg_temp.expect_failure($q$select public.register_adssu_scholar('M-009999','Synthetic Test','demo.test99@example.test','10000000-0000-4000-8000-000000000001','BSIT',3,'B','2026-2027')$q$,'ADSSU email','ADSSU invalid domain denied');
select pg_temp.expect_failure($q$select public.register_scholar('M-009999','Synthetic Test','demo.test99@adssu.edu.ph','10000000-0000-4000-8000-000000000001')$q$,'permission denied','ADSSU legacy registration bypass denied');

select public.evaluate_submission('30000000-0000-4000-8000-000000000001');
select pg_temp.assert_true((select compliance='Compliant' and reasons='[]'::jsonb from public.submissions where id='30000000-0000-4000-8000-000000000001'),'TC01 boundary');
select public.evaluate_submission('30000000-0000-4000-8000-000000000002');
select pg_temp.assert_true((select compliance='With Deficiency' and reasons='["GWA exceeds program maximum"]'::jsonb from public.submissions where id='30000000-0000-4000-8000-000000000002'),'TC02 GWA');
select public.evaluate_submission('30000000-0000-4000-8000-000000000003');
select pg_temp.assert_true((select compliance='Compliant' from public.submissions where id='30000000-0000-4000-8000-000000000003'),'TC03 program variation');
select public.evaluate_submission('30000000-0000-4000-8000-000000000004');
select pg_temp.assert_true((select reasons='["Insufficient enrolled units","Incomplete grades exceed allowance"]'::jsonb from public.submissions where id='30000000-0000-4000-8000-000000000004'),'TC04 multiple deficiencies');
select public.evaluate_submission('30000000-0000-4000-8000-000000000005');
select pg_temp.assert_true((select reasons='["Failed subjects exceed allowance","Late submission"]'::jsonb from public.submissions where id='30000000-0000-4000-8000-000000000005'),'TC05 failure and lateness');
select pg_temp.expect_failure($q$select public.evaluate_submission('30000000-0000-4000-8000-000000000006')$q$,'Verified evidence','TC06 evaluation gate');
select pg_temp.expect_failure($q$select public.decide_renewal('30000000-0000-4000-8000-000000000006','Approved','Test')$q$,'Verify and evaluate','TC06 renewal gate');

select set_config('request.jwt.claims',json_build_object('sub',current_setting('exam.scholar_auth'),'role','authenticated')::text,true);
select pg_temp.expect_failure($q$select public.submit_grades('2026-2027',1,2.0,18,0,0,0,'TEST')$q$,'already exists','TC07 duplicate');
select pg_temp.expect_failure($q$select public.submit_grades('2026-2027',2,0.50,18,0,0,0,'TEST')$q$,'GWA must','TC07 invalid GWA');
select pg_temp.expect_failure($q$select public.submit_grades('2026-2027',2,2.0,18,-1,0,0,'TEST')$q$,'nonnegative','TC07 negative count');
select pg_temp.assert_true((select count(*)=0 from public.submissions where scholar_id <> public.my_profile_id()),'TC08 other scholar submissions invisible');
select pg_temp.assert_true((select count(*)=0 from public.history where submission_id='30000000-0000-4000-8000-000000000002'),'TC08 other scholar history invisible');
select pg_temp.expect_failure($q$select public.verify_submission('30000000-0000-4000-8000-000000000001','Verified','Attempt')$q$,'Staff access','TC08 scholar cannot verify');
select pg_temp.expect_failure($q$update public.profiles set role='Staff' where id=public.my_profile_id()$q$,'permission denied','TC08 no role escalation');
select pg_temp.expect_failure($q$update public.submissions set verification='Verified' where scholar_id=public.my_profile_id()$q$,'permission denied','TC08 no direct workflow bypass');

select set_config('request.jwt.claims',json_build_object('sub',current_setting('exam.staff_auth'),'role','authenticated')::text,true);
select public.verify_submission('30000000-0000-4000-8000-000000000001','Returned','TC09 evidence needs correction');
select set_config('request.jwt.claims',json_build_object('sub',current_setting('exam.scholar_auth'),'role','authenticated')::text,true);
select public.submit_grades('2026-2027',1,2.0,18,0,0,0,'CORRECTED-TEST-REFERENCE','30000000-0000-4000-8000-000000000001');
select pg_temp.assert_true((select verification='Pending' and compliance='Not Evaluated' and renewal='Undecided' from public.submissions where id='30000000-0000-4000-8000-000000000001'),'TC09 correction resets state');
select pg_temp.assert_true((select count(*)>=2 from public.history where submission_id='30000000-0000-4000-8000-000000000001' and action in ('Returned','Corrected and resubmitted')),'TC09 preserved history');

select set_config('request.jwt.claims',json_build_object('sub',current_setting('exam.staff_auth'),'role','authenticated')::text,true);
select public.decide_renewal('30000000-0000-4000-8000-000000000003','Approved','TC10 compliant renewal');
select public.decide_renewal('30000000-0000-4000-8000-000000000002','Held','TC10 deficient renewal');
select pg_temp.assert_true((select renewal='Approved' from public.submissions where id='30000000-0000-4000-8000-000000000003'),'TC10 compliant approved');
select pg_temp.assert_true((select renewal='Held' from public.submissions where id='30000000-0000-4000-8000-000000000002'),'TC10 deficient held');
select pg_temp.expect_failure($q$select public.decide_renewal('30000000-0000-4000-8000-000000000002','Approved','Attempt')$q$,'cannot be approved','TC10 deficient approval blocked');
select set_config('request.jwt.claims',json_build_object('sub',current_setting('exam.scholar_auth'),'role','authenticated')::text,true);
select pg_temp.expect_failure($q$select public.decide_renewal('30000000-0000-4000-8000-000000000001','Approved','Attempt')$q$,'Staff access','TC10 scholar cannot decide');

reset role;
rollback;
