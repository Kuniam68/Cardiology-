-- Run once in your Supabase SQL editor before enabling public registration.
-- This script contains no credentials. RLS isolates each student's learning data.
begin;
create table if not exists public.course_catalog (
 id text primary key,
 title text not null
);
create table if not exists public.course_lessons (
 course_id text not null references public.course_catalog(id),
 lesson_id text not null,
 primary key (course_id,lesson_id)
);
insert into public.course_catalog(id,title) values
 ('heart-foundations','Cardiovascular foundations'),
 ('ecg-essentials','ECG essentials'),
 ('prevention','Risk and everyday heart health')
on conflict(id) do update set title=excluded.title;
insert into public.course_lessons(course_id,lesson_id) values
 ('heart-foundations','chambers'),('heart-foundations','valves'),('heart-foundations','coronary'),
 ('ecg-essentials','electrical'),('ecg-essentials','waves'),('ecg-essentials','approach'),
 ('prevention','risk'),('prevention','measurements'),('prevention','habits')
on conflict do nothing;
create table if not exists public.enrollments (
 user_id uuid not null references auth.users(id) on delete cascade,
 course_id text not null references public.course_catalog(id),
 created_at timestamptz not null default now(),
 primary key(user_id,course_id)
);
create table if not exists public.lesson_progress (
 user_id uuid not null,
 course_id text not null,
 lesson_id text not null,
 completed_at timestamptz not null default now(),
 primary key(user_id,course_id,lesson_id),
 foreign key(user_id,course_id) references public.enrollments(user_id,course_id) on delete cascade,
 foreign key(course_id,lesson_id) references public.course_lessons(course_id,lesson_id)
);
alter table public.course_catalog enable row level security;
alter table public.course_lessons enable row level security;
alter table public.enrollments enable row level security;
alter table public.lesson_progress enable row level security;
drop policy if exists catalog_read on public.course_catalog;
create policy catalog_read on public.course_catalog for select to anon,authenticated using(true);
drop policy if exists lessons_read on public.course_lessons;
create policy lessons_read on public.course_lessons for select to anon,authenticated using(true);
drop policy if exists own_enrollments_read on public.enrollments;
create policy own_enrollments_read on public.enrollments for select to authenticated using((select auth.uid())=user_id);
drop policy if exists own_enrollments_insert on public.enrollments;
create policy own_enrollments_insert on public.enrollments for insert to authenticated with check((select auth.uid())=user_id);
drop policy if exists own_progress_read on public.lesson_progress;
create policy own_progress_read on public.lesson_progress for select to authenticated using((select auth.uid())=user_id);
drop policy if exists own_progress_insert on public.lesson_progress;
create policy own_progress_insert on public.lesson_progress for insert to authenticated with check((select auth.uid())=user_id);
-- No client update/delete policies or privileges. The frontend uses insert-on-conflict-do-nothing.
revoke all on public.enrollments,public.lesson_progress from anon;
revoke all on public.enrollments,public.lesson_progress from authenticated;
grant select,insert on public.enrollments,public.lesson_progress to authenticated;
revoke all on public.course_catalog,public.course_lessons from anon,authenticated;
grant select on public.course_catalog,public.course_lessons to anon,authenticated;
commit;

-- Course management. Apply this section as well when upgrading an existing installation.
begin;
create table if not exists public.academy_admins (
 user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.academy_admins enable row level security;
drop policy if exists admin_self_read on public.academy_admins;
create policy admin_self_read on public.academy_admins for select to authenticated using((select auth.uid())=user_id);
revoke all on public.academy_admins from anon,authenticated;
grant select on public.academy_admins to authenticated;
create or replace function public.is_academy_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.academy_admins where user_id=(select auth.uid())); $$;
revoke all on function public.is_academy_admin() from public;
grant execute on function public.is_academy_admin() to authenticated;
create table if not exists public.academy_courses (
 id text primary key check(id ~ '^[a-z][a-z0-9-]{1,79}$'),
 payload jsonb not null,
 published boolean not null default false,
 archived boolean not null default false,
 updated_at timestamptz not null default now()
);
alter table public.academy_courses enable row level security;
drop policy if exists published_courses_read on public.academy_courses;
create policy published_courses_read on public.academy_courses for select to anon,authenticated using(published and not archived);
drop policy if exists admin_courses_read on public.academy_courses;
create policy admin_courses_read on public.academy_courses for select to authenticated using(public.is_academy_admin());
revoke all on public.academy_courses from anon,authenticated;
grant select on public.academy_courses to anon,authenticated;
create or replace function public.save_academy_course(course_id text, course_payload jsonb, is_published boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
declare lesson jsonb; seen text[] := '{}'; lesson_key text;
begin
 if not public.is_academy_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
 if course_id is null or course_id !~ '^[a-z][a-z0-9-]{1,79}$' then raise exception 'Invalid course ID'; end if;
 if course_payload is null or jsonb_typeof(course_payload) <> 'object' or pg_column_size(course_payload)>500000 then raise exception 'Invalid or oversized course'; end if;
 if coalesce(length(trim(course_payload->>'title')),0) not between 1 and 2000
 or coalesce(length(trim(course_payload->>'subtitle')),0) not between 1 and 2000
 or coalesce(length(trim(course_payload->>'category')),0) not between 1 and 2000
 or coalesce(length(trim(course_payload->>'description')),0) not between 1 and 2000 then raise exception 'Complete course information'; end if;
 if jsonb_typeof(course_payload->'outcomes') is distinct from 'array' then raise exception 'Learning outcomes required'; end if;
 if jsonb_array_length(course_payload->'outcomes') not between 1 and 12 then raise exception 'Provide 1-12 outcomes'; end if;
 if exists(select 1 from jsonb_array_elements(course_payload->'outcomes') x where jsonb_typeof(x)<>'string' or length(trim(x#>>'{}')) not between 1 and 500) then raise exception 'Invalid learning outcome'; end if;
 if jsonb_typeof(course_payload->'lessons') is distinct from 'array' then raise exception 'Lessons required'; end if;
 if jsonb_array_length(course_payload->'lessons') not between 1 and 60 then raise exception 'Provide 1-60 lessons'; end if;
 for lesson in select value from jsonb_array_elements(course_payload->'lessons') loop
  lesson_key:=lesson->>'id';
  if lesson_key is null or lesson_key !~ '^[a-z][a-z0-9-]{1,79}$' or lesson_key=any(seen) then raise exception 'Invalid or duplicate lesson ID'; end if;
  seen:=array_append(seen,lesson_key);
  if coalesce(length(trim(lesson->>'title')),0) not between 1 and 200 or coalesce(length(trim(lesson->>'content')),0) not between 1 and 50000 then raise exception 'Lesson title and content required'; end if;
  if coalesce(lesson->>'minutes','') !~ '^[0-9]{1,3}$' then raise exception 'Invalid lesson duration'; end if;
  if (lesson->>'minutes')::integer not between 1 and 600 then raise exception 'Invalid lesson duration'; end if;
  if coalesce(length(trim(lesson->>'question')),0)=0 or coalesce(length(trim(lesson->>'explanation')),0)=0 then raise exception 'Knowledge check required'; end if;
  if jsonb_typeof(lesson->'options') is distinct from 'array' then raise exception 'Three answer options required'; end if;
  if jsonb_array_length(lesson->'options')<>3 or coalesce(lesson->>'answer','') !~ '^[012]$' then raise exception 'Invalid knowledge check'; end if;
  if exists(select 1 from jsonb_array_elements(lesson->'options') x where jsonb_typeof(x)<>'string' or length(trim(x#>>'{}')) not between 1 and 500) then raise exception 'Invalid answer option'; end if;
 end loop;
 insert into public.course_catalog(id,title) values(course_id,course_payload->>'title') on conflict(id) do update set title=excluded.title;
 foreach lesson_key in array seen loop
  insert into public.course_lessons(course_id,lesson_id) values(course_id,lesson_key) on conflict do nothing;
 end loop;
 insert into public.academy_courses(id,payload,published) values(course_id,course_payload,coalesce(is_published,false))
 on conflict(id) do update set payload=excluded.payload,published=excluded.published,archived=case when excluded.published then false else academy_courses.archived end,updated_at=now();
end; $$;
revoke all on function public.save_academy_course(text,jsonb,boolean) from public;
grant execute on function public.save_academy_course(text,jsonb,boolean) to authenticated;
create or replace function public.archive_academy_course(course_id text, archive boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not public.is_academy_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
 update public.academy_courses set archived=coalesce(archive,true),updated_at=now() where id=course_id;
 if not found then raise exception 'Course not found'; end if;
end; $$;
revoke all on function public.archive_academy_course(text,boolean) from public;
grant execute on function public.archive_academy_course(text,boolean) to authenticated;
commit;
-- After signing up and confirming YOUR account, grant yourself admin from the SQL editor:
-- insert into public.academy_admins(user_id) values ('YOUR-AUTH-USER-UUID') on conflict do nothing;
-- Never grant admin from user-editable metadata or a frontend role toggle.

-- Hide unpublished course metadata and prevent enrollment by guessing a draft ID.
begin;
create or replace function public.course_is_available(course_key text) returns boolean
language sql stable security definer set search_path = '' as $$
 select coalesce(
  (select published and not archived from public.academy_courses where id=course_key),
  course_key in ('heart-foundations','ecg-essentials','prevention')
 );
$$;
revoke all on function public.course_is_available(text) from public;
grant execute on function public.course_is_available(text) to anon,authenticated;
drop policy if exists catalog_read on public.course_catalog;
create policy catalog_read on public.course_catalog for select to anon,authenticated using(public.course_is_available(id));
drop policy if exists lessons_read on public.course_lessons;
create policy lessons_read on public.course_lessons for select to anon,authenticated using(public.course_is_available(course_id));
drop policy if exists own_enrollments_insert on public.enrollments;
create policy own_enrollments_insert on public.enrollments for insert to authenticated with check((select auth.uid())=user_id and public.course_is_available(course_id));
commit;
