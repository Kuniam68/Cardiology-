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
