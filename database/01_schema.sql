begin;

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  email text not null unique check (email = lower(email)),
  student_id text unique,
  full_name text not null check (length(trim(full_name)) between 1 and 120),
  role text not null default 'Scholar' check (role in ('Scholar', 'Staff')),
  created_at timestamptz not null default now()
);

create table public.programs (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  max_gwa numeric(3,2) not null check (max_gwa between 1 and 5),
  min_units integer not null check (min_units >= 0),
  max_failed integer not null check (max_failed >= 0),
  max_incomplete integer not null check (max_incomplete >= 0),
  max_dropped integer not null check (max_dropped >= 0),
  deadline timestamptz not null
);

create table public.assignments (
  scholar_id uuid primary key references public.profiles(id),
  program_id uuid not null references public.programs(id),
  award_status text not null default 'Active' check (award_status in ('Active', 'Inactive')),
  assigned_at timestamptz not null default now()
);

create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  scholar_id uuid not null references public.assignments(scholar_id),
  program_id uuid not null references public.programs(id),
  academic_year text not null check (academic_year ~ '^[0-9]{4}-[0-9]{4}$' and substring(academic_year,6,4)::integer = substring(academic_year,1,4)::integer + 1),
  semester integer not null check (semester in (1,2,3)),
  gwa numeric(3,2) not null check (gwa between 1 and 5),
  units integer not null check (units >= 0),
  failed integer not null check (failed >= 0),
  incomplete integer not null check (incomplete >= 0),
  dropped integer not null check (dropped >= 0),
  evidence_ref text not null check (length(trim(evidence_ref)) between 1 and 2000),
  submitted_at timestamptz not null default clock_timestamp(),
  verification text not null default 'Pending' check (verification in ('Pending','Verified','Returned')),
  verification_reason text,
  compliance text not null default 'Not Evaluated' check (compliance in ('Not Evaluated','Compliant','With Deficiency')),
  checks jsonb not null default '[]',
  reasons jsonb not null default '[]',
  renewal text not null default 'Undecided' check (renewal in ('Undecided','Approved','Held')),
  decision_notes text,
  updated_at timestamptz not null default now(),
  unique (scholar_id, academic_year, semester),
  check (verification = 'Verified' or compliance = 'Not Evaluated'),
  check (renewal <> 'Approved' or (verification = 'Verified' and compliance = 'Compliant'))
);

create table public.history (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions(id),
  actor_id uuid not null references public.profiles(id),
  action text not null,
  notes text,
  snapshot jsonb not null,
  created_at timestamptz not null default clock_timestamp()
);

create index submissions_semester_idx on public.submissions(academic_year,semester);
create index history_submission_idx on public.history(submission_id,created_at);

create function public.my_profile_id() returns uuid
language sql stable security definer set search_path = ''
as $$ select id from public.profiles where auth_user_id = auth.uid() $$;

create function public.is_staff() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.profiles where auth_user_id = auth.uid() and role = 'Staff') $$;

create function public.bind_auth_profile() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles(auth_user_id,email,full_name)
  values (new.id,lower(new.email),split_part(new.email,'@',1))
  on conflict (email) do update set auth_user_id = excluded.auth_user_id
  where public.profiles.auth_user_id is null;
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
for each row execute function public.bind_auth_profile();

alter table public.profiles enable row level security;
alter table public.programs enable row level security;
alter table public.assignments enable row level security;
alter table public.submissions enable row level security;
alter table public.history enable row level security;

create policy profiles_read on public.profiles for select to authenticated
using (id = public.my_profile_id() or public.is_staff());
create policy programs_read on public.programs for select to authenticated using (true);
create policy assignments_read on public.assignments for select to authenticated
using (scholar_id = public.my_profile_id() or public.is_staff());
create policy submissions_read on public.submissions for select to authenticated
using (scholar_id = public.my_profile_id() or public.is_staff());
create policy history_read on public.history for select to authenticated
using (exists(select 1 from public.submissions s where s.id = submission_id and (s.scholar_id = public.my_profile_id() or public.is_staff())));

create function public.register_scholar(p_student_id text,p_full_name text,p_email text,p_program_id uuid) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_id uuid; v_auth uuid;
begin
  if not public.is_staff() then raise exception 'Staff access required' using errcode = '42501'; end if;
  if length(trim(p_student_id)) not between 1 and 40 or length(trim(p_full_name)) not between 1 and 120
    or p_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Valid student ID, name and email are required'; end if;
  select id into v_auth from auth.users where lower(email) = lower(trim(p_email));
  select id into v_id from public.profiles where email = lower(trim(p_email)) for update;
  if v_id is not null then
    if exists(select 1 from public.assignments where scholar_id = v_id)
      or exists(select 1 from public.profiles where id = v_id and role = 'Staff') then raise exception 'Email already registered or belongs to staff'; end if;
    update public.profiles set student_id = trim(p_student_id),full_name = trim(p_full_name) where id = v_id;
  else
    insert into public.profiles(auth_user_id,email,student_id,full_name)
    values(v_auth,lower(trim(p_email)),trim(p_student_id),trim(p_full_name)) returning id into v_id;
  end if;
  insert into public.assignments(scholar_id,program_id) values(v_id,p_program_id);
  return v_id;
end;
$$;

create function public.assign_program(p_scholar_id uuid,p_program_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_staff() then raise exception 'Staff access required' using errcode = '42501'; end if;
  perform 1 from public.assignments where scholar_id = p_scholar_id for update;
  if not found then raise exception 'Scholar assignment not found'; end if;
  if exists(select 1 from public.submissions where scholar_id = p_scholar_id) then raise exception 'Policy assignment is locked after the first submission'; end if;
  update public.assignments set program_id = p_program_id,assigned_at = clock_timestamp() where scholar_id = p_scholar_id;
end;
$$;

create function public.submit_grades(p_academic_year text,p_semester integer,p_gwa numeric,p_units integer,p_failed integer,p_incomplete integer,p_dropped integer,p_evidence_ref text,p_submission_id uuid default null) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_me uuid := public.my_profile_id(); v_program uuid; v_row public.submissions; v_action text;
begin
  if v_me is null or public.is_staff() then raise exception 'Scholar access required' using errcode = '42501'; end if;
  if p_gwa is null or p_gwa not between 1 and 5 or p_gwa <> round(p_gwa,2)
    or p_units is null or p_units < 0 or p_failed is null or p_failed < 0
    or p_incomplete is null or p_incomplete < 0 or p_dropped is null or p_dropped < 0 then
    raise exception 'GWA must be 1.00–5.00 with at most two decimals; units and counts must be nonnegative integers';
  end if;
  if p_evidence_ref is null or length(trim(p_evidence_ref)) not between 1 and 2000 then raise exception 'A grade-document reference is required'; end if;
  select program_id into v_program from public.assignments where scholar_id = v_me for update;
  if v_program is null then raise exception 'Ask staff to assign a scholarship program first'; end if;
  if p_submission_id is null then
    insert into public.submissions(scholar_id,program_id,academic_year,semester,gwa,units,failed,incomplete,dropped,evidence_ref)
    values(v_me,v_program,p_academic_year,p_semester,p_gwa,p_units,p_failed,p_incomplete,p_dropped,trim(p_evidence_ref)) returning * into v_row;
    v_action := 'Submitted';
  else
    select * into v_row from public.submissions where id = p_submission_id and scholar_id = v_me for update;
    if not found then raise exception 'Submission not accessible' using errcode = '42501'; end if;
    if v_row.verification <> 'Returned' then raise exception 'Only returned submissions may be corrected'; end if;
    if v_row.academic_year <> p_academic_year or v_row.semester <> p_semester then raise exception 'The semester of a correction cannot change'; end if;
    update public.submissions set gwa=p_gwa,units=p_units,failed=p_failed,incomplete=p_incomplete,dropped=p_dropped,evidence_ref=trim(p_evidence_ref),
      submitted_at=clock_timestamp(),verification='Pending',verification_reason=null,compliance='Not Evaluated',checks='[]',reasons='[]',renewal='Undecided',decision_notes=null,updated_at=clock_timestamp()
    where id=p_submission_id returning * into v_row;
    v_action := 'Corrected and resubmitted';
  end if;
  insert into public.history(submission_id,actor_id,action,notes,snapshot) values(v_row.id,v_me,v_action,'Awaiting verification',to_jsonb(v_row));
  return v_row.id;
exception when unique_violation then raise exception 'A submission already exists for this scholar, academic year and semester';
end;
$$;

create function public.verify_submission(p_submission_id uuid,p_status text,p_reason text) returns void
language plpgsql security definer set search_path = ''
as $$
declare v_row public.submissions;
begin
  if not public.is_staff() then raise exception 'Staff access required' using errcode = '42501'; end if;
  if p_status is null or p_status not in ('Verified','Returned') then raise exception 'Select Verified or Returned'; end if;
  if nullif(trim(p_reason),'') is null then raise exception 'A verification or return reason is required'; end if;
  select * into v_row from public.submissions where id=p_submission_id for update;
  if not found then raise exception 'Submission not found'; end if;
  if p_status = 'Verified' and v_row.verification <> 'Pending' then raise exception 'Only pending evidence may be verified'; end if;
  if p_status = 'Returned' and v_row.verification = 'Returned' then raise exception 'Already returned'; end if;
  update public.submissions set verification=p_status,verification_reason=trim(p_reason),compliance='Not Evaluated',checks='[]',reasons='[]',renewal='Undecided',decision_notes=null,updated_at=clock_timestamp()
  where id=p_submission_id returning * into v_row;
  insert into public.history(submission_id,actor_id,action,notes,snapshot) values(v_row.id,public.my_profile_id(),p_status,trim(p_reason),to_jsonb(v_row));
end;
$$;

create function public.evaluate_submission(p_submission_id uuid) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_row public.submissions; v_policy public.programs; v_checks jsonb; v_reasons jsonb;
begin
  if not public.is_staff() then raise exception 'Staff access required' using errcode = '42501'; end if;
  select * into v_row from public.submissions where id=p_submission_id for update;
  if not found then raise exception 'Submission not found'; end if;
  if v_row.verification <> 'Verified' or nullif(trim(v_row.evidence_ref),'') is null then raise exception 'Verified evidence is required before evaluation'; end if;
  select * into strict v_policy from public.programs where id=v_row.program_id;
  v_checks := jsonb_build_array(
    jsonb_build_object('label','GWA','passed',v_row.gwa <= v_policy.max_gwa,'actual',v_row.gwa,'limit',v_policy.max_gwa,'reason','GWA exceeds program maximum'),
    jsonb_build_object('label','Enrolled units','passed',v_row.units >= v_policy.min_units,'actual',v_row.units,'limit',v_policy.min_units,'reason','Insufficient enrolled units'),
    jsonb_build_object('label','Failed subjects','passed',v_row.failed <= v_policy.max_failed,'actual',v_row.failed,'limit',v_policy.max_failed,'reason','Failed subjects exceed allowance'),
    jsonb_build_object('label','Incomplete grades','passed',v_row.incomplete <= v_policy.max_incomplete,'actual',v_row.incomplete,'limit',v_policy.max_incomplete,'reason','Incomplete grades exceed allowance'),
    jsonb_build_object('label','Dropped subjects','passed',v_row.dropped <= v_policy.max_dropped,'actual',v_row.dropped,'limit',v_policy.max_dropped,'reason','Dropped subjects exceed allowance'),
    jsonb_build_object('label','Submission deadline','passed',v_row.submitted_at <= v_policy.deadline,'actual',v_row.submitted_at,'limit',v_policy.deadline,'reason','Late submission')
  );
  select coalesce(jsonb_agg(value->>'reason'),'[]'::jsonb) into v_reasons from jsonb_array_elements(v_checks) where not (value->>'passed')::boolean;
  update public.submissions set compliance=case when jsonb_array_length(v_reasons)=0 then 'Compliant' else 'With Deficiency' end,
    checks=v_checks,reasons=v_reasons,renewal='Undecided',decision_notes=null,updated_at=clock_timestamp()
  where id=p_submission_id returning * into v_row;
  insert into public.history(submission_id,actor_id,action,notes,snapshot) values(v_row.id,public.my_profile_id(),'Evaluated',v_row.compliance,to_jsonb(v_row));
  return to_jsonb(v_row);
end;
$$;

create function public.decide_renewal(p_submission_id uuid,p_decision text,p_notes text) returns void
language plpgsql security definer set search_path = ''
as $$
declare v_row public.submissions;
begin
  if not public.is_staff() then raise exception 'Staff access required' using errcode = '42501'; end if;
  if p_decision is null or p_decision not in ('Approved','Held') then raise exception 'Select Approved or Held'; end if;
  if nullif(trim(p_notes),'') is null then raise exception 'Decision notes are required'; end if;
  select * into v_row from public.submissions where id=p_submission_id for update;
  if not found then raise exception 'Submission not found'; end if;
  if v_row.verification <> 'Verified' or v_row.compliance = 'Not Evaluated' then raise exception 'Verify and evaluate the submission before deciding renewal'; end if;
  if p_decision='Approved' and v_row.compliance <> 'Compliant' then raise exception 'Deficient submissions cannot be approved'; end if;
  update public.submissions set renewal=p_decision,decision_notes=trim(p_notes),updated_at=clock_timestamp()
  where id=p_submission_id returning * into v_row;
  insert into public.history(submission_id,actor_id,action,notes,snapshot) values(v_row.id,public.my_profile_id(),'Renewal '||p_decision,trim(p_notes),to_jsonb(v_row));
end;
$$;

revoke all on public.profiles,public.programs,public.assignments,public.submissions,public.history from public,anon,authenticated;
grant select on public.profiles,public.programs,public.assignments,public.submissions,public.history to authenticated;
revoke all on function public.my_profile_id(),public.is_staff(),public.bind_auth_profile(),public.register_scholar(text,text,text,uuid),public.assign_program(uuid,uuid),public.submit_grades(text,integer,numeric,integer,integer,integer,integer,text,uuid),public.verify_submission(uuid,text,text),public.evaluate_submission(uuid),public.decide_renewal(uuid,text,text) from public,anon,authenticated;
grant execute on function public.my_profile_id(),public.is_staff(),public.register_scholar(text,text,text,uuid),public.assign_program(uuid,uuid),public.submit_grades(text,integer,numeric,integer,integer,integer,integer,text,uuid),public.verify_submission(uuid,text,text),public.evaluate_submission(uuid),public.decide_renewal(uuid,text,text) to authenticated;

commit;
