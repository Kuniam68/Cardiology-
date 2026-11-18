SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
-- Equivalent SELECT authorization, with one permissive policy per role/action.
alter policy published_courses_read on public.academy_courses to anon;
alter policy admin_courses_read on public.academy_courses to authenticated using((published and not archived) or public.is_academy_admin());
alter policy readable_payment_settings on public.payment_course_settings to anon;
alter policy admin_payment_settings on public.payment_course_settings to authenticated using(public.course_is_available(course_id) or public.is_academy_admin());
alter policy readable_payment_prices on public.payment_prices to anon;
alter policy admin_payment_prices on public.payment_prices to authenticated using(public.course_is_available(course_id) or public.is_academy_admin());
create index academy_enrollments_course on public.enrollments(course_id);
create index academy_lesson_progress_lesson on public.lesson_progress(course_id,lesson_id);
