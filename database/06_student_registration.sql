begin;

create or replace function public.bind_auth_profile() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles(auth_user_id,email,full_name)
  values(new.id,lower(new.email),left(split_part(new.email,'@',1),120))
  on conflict(email) do nothing;
  return new;
end;
$$;

create function public.complete_student_registration(p_student_id text,p_full_name text,p_academic_program_code text,p_year_level integer,p_section text,p_profile_academic_year text) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_email text; v_confirmed timestamptz; v_row public.profiles; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in and confirm your email first' using errcode='42501'; end if;
  select lower(email),email_confirmed_at into v_email,v_confirmed from auth.users where id=auth.uid() for update;
  if v_confirmed is null then raise exception 'Confirm your email before completing registration' using errcode='42501'; end if;
  if v_email !~ '^[a-z0-9][a-z0-9._%+-]*@adssu\.edu\.ph$' then raise exception 'Registration requires an ADSSU email address'; end if;
  if p_student_id is null or trim(p_student_id) !~ '^M-[0-9]{6}$' then raise exception 'Student ID must use M- followed by six digits'; end if;
  if p_full_name is null or length(trim(p_full_name)) not between 1 and 120 then raise exception 'A full name of 1-120 characters is required'; end if;
  if p_academic_program_code is null or not exists(select 1 from public.academic_programs where code=p_academic_program_code) then raise exception 'Select a listed academic program'; end if;
  if p_year_level is null or p_year_level not between 1 and 6 or p_section is null or upper(trim(p_section)) !~ '^[A-Z]{1,3}$' then raise exception 'Year level must be 1-6 and section must be 1-3 letters'; end if;
  if p_profile_academic_year is null or p_profile_academic_year !~ '^[0-9]{4}-[0-9]{4}$' then raise exception 'Use an academic year such as 2026-2027'; end if;
  if substring(p_profile_academic_year,6,4)::integer <> substring(p_profile_academic_year,1,4)::integer+1 then raise exception 'Academic years must be consecutive'; end if;
  select * into v_row from public.profiles where email=v_email for update;
  if found then
    if v_row.role <> 'Scholar' or (v_row.auth_user_id is not null and v_row.auth_user_id <> auth.uid()) then raise exception 'This profile cannot be registered as a student' using errcode='42501'; end if;
    if v_row.student_id is not null then
      if v_row.student_id <> trim(p_student_id) then raise exception 'Student ID does not match the registered profile'; end if;
      update public.profiles set auth_user_id=auth.uid() where id=v_row.id;
      return v_row.id;
    end if;
    update public.profiles set auth_user_id=auth.uid(),student_id=trim(p_student_id),full_name=trim(p_full_name),academic_program_code=p_academic_program_code,
      year_level=p_year_level,section=upper(trim(p_section)),profile_academic_year=p_profile_academic_year where id=v_row.id returning id into v_id;
  else
    insert into public.profiles(auth_user_id,email,student_id,full_name,academic_program_code,year_level,section,profile_academic_year)
    values(auth.uid(),v_email,trim(p_student_id),trim(p_full_name),p_academic_program_code,p_year_level,upper(trim(p_section)),p_profile_academic_year) returning id into v_id;
  end if;
  return v_id;
exception when unique_violation then raise exception 'This student ID or email is already registered; contact Scholarship Staff';
end;
$$;

create function public.approve_student_assignment(p_scholar_id uuid,p_program_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare v_row public.profiles;
begin
  if not public.is_staff() then raise exception 'Staff access required' using errcode='42501'; end if;
  select * into v_row from public.profiles where id=p_scholar_id for update;
  if not found or v_row.role <> 'Scholar' or v_row.student_id is null or v_row.auth_user_id is null or v_row.academic_program_code is null then raise exception 'A completed student registration is required'; end if;
  if not exists(select 1 from auth.users where id=v_row.auth_user_id and email_confirmed_at is not null) then raise exception 'Student must confirm their email first'; end if;
  insert into public.assignments(scholar_id,program_id) values(p_scholar_id,p_program_id);
exception when unique_violation then raise exception 'This student already has a scholarship assignment';
end;
$$;

create function public.registration_programs() returns table(code text,name text,college text,level text)
language sql stable security definer set search_path = ''
as $$ select a.code,a.name,a.college,a.level from public.academic_programs a order by a.college,a.name $$;

revoke all on function public.complete_student_registration(text,text,text,integer,text,text),public.approve_student_assignment(uuid,uuid),public.registration_programs() from public,anon,authenticated;
grant execute on function public.complete_student_registration(text,text,text,integer,text,text),public.approve_student_assignment(uuid,uuid) to authenticated;
grant execute on function public.registration_programs() to anon,authenticated;

notify pgrst,'reload schema';
commit;
