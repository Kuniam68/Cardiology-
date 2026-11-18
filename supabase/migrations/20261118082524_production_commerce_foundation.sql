-- Backward-compatible production commerce foundation. No existing course/user rows change.
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
DO $$ BEGIN
 IF current_user <> 'postgres' THEN RAISE EXCEPTION 'Database owner required'; END IF;
 IF to_regclass('public.payment_course_settings') IS NOT NULL OR to_regclass('public.commerce_orders') IS NOT NULL THEN RAISE EXCEPTION 'Commerce already exists; inspect migration history'; END IF;
 IF to_regprocedure('public.save_academy_course(text,jsonb,boolean)') IS NULL OR to_regclass('public.lesson_progress') IS NULL THEN RAISE EXCEPTION 'Academy foundation required'; END IF;
END $$;
create table public.payment_course_settings(course_id text primary key references public.course_catalog(id),paid boolean not null default false);
create table public.payment_prices(course_id text references public.course_catalog(id),currency text check(currency in ('BDT','USD')),amount_minor bigint check(amount_minor between 1 and 1000000000),revision integer not null default 1 check(revision>0),updated_at timestamptz not null default now(),primary key(course_id,currency));
create table public.payment_course_content(course_id text primary key references public.course_catalog(id),payload jsonb not null);
create table public.commerce_settings(singleton boolean primary key default true check(singleton),live_enabled boolean not null default false,merchant_approved boolean not null default false,provider_environment text not null default 'disabled' check(provider_environment in ('disabled','sandbox','live')),verified_currencies text[] not null default array['BDT']::text[] check(verified_currencies <@ array['BDT']::text[]));
insert into public.commerce_settings(singleton) values(true);
create table public.commerce_orders(
 id uuid primary key default gen_random_uuid(),merchant_ref varchar(30) not null unique,
 user_id uuid not null references auth.users(id),course_id text not null references public.course_catalog(id),request_key uuid not null,
 currency text not null check(currency='BDT'),amount_minor bigint not null check(amount_minor between 1000 and 50000000),price_revision integer not null check(price_revision>0),
 environment text not null check(environment in ('sandbox','live')),provider text not null default 'sslcommerz' check(provider='sslcommerz'),
 status text not null default 'initializing' check(status in ('initializing','pending','session_unknown','succeeded','failed','cancelled','review','refunded')),
 session_attempted boolean not null default false,session_key text,checkout_url text,validation_id text unique,bank_reference text unique,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),last_reconciled_at timestamptz,
 unique(user_id,request_key)
);
create unique index commerce_one_active_order on public.commerce_orders(user_id,course_id,environment) where status in ('initializing','pending','session_unknown','review');
create index commerce_orders_user_created on public.commerce_orders(user_id,created_at desc);
create index commerce_orders_course on public.commerce_orders(course_id);
create table public.commerce_entitlements(user_id uuid not null,course_id text not null,order_id uuid not null unique references public.commerce_orders(id),active boolean not null default true,primary key(user_id,course_id,order_id),foreign key(user_id,course_id) references public.enrollments(user_id,course_id));
create index commerce_entitlements_course on public.commerce_entitlements(course_id);
create table public.commerce_refunds(id uuid primary key default gen_random_uuid(),order_id uuid not null unique references public.commerce_orders(id),actor uuid not null references auth.users(id),refund_trans_id varchar(30) not null unique,amount_minor bigint not null check(amount_minor>0),reason text not null check(length(reason) between 5 and 255),status text not null default 'requested' check(status in ('requested','submitting','unknown','processing','refunded','cancelled','failed')),provider_reference text unique,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create index commerce_refunds_actor on public.commerce_refunds(actor);
create table public.commerce_audit(id bigint generated always as identity primary key,actor uuid,event text not null,order_id uuid references public.commerce_orders(id),details jsonb not null default '{}'::jsonb,created_at timestamptz not null default now());
create index commerce_audit_order on public.commerce_audit(order_id,created_at desc);
DO $$ DECLARE t text;BEGIN
 FOREACH t IN ARRAY ARRAY['payment_course_settings','payment_prices','payment_course_content','commerce_settings','commerce_orders','commerce_entitlements','commerce_refunds','commerce_audit'] LOOP
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 END LOOP;
END $$;
revoke all on sequence public.commerce_audit_id_seq from public,anon,authenticated,service_role;
grant select on public.payment_course_settings,public.payment_prices to anon,authenticated;
-- Server-side operations only; neither client roles nor service_role get direct payment writes.
grant select on public.commerce_settings,public.commerce_orders,public.commerce_refunds,public.commerce_audit,public.academy_admins to service_role;
create policy readable_payment_settings on public.payment_course_settings for select to anon,authenticated using(public.course_is_available(course_id));
create policy admin_payment_settings on public.payment_course_settings for select to authenticated using(public.is_academy_admin());
create policy readable_payment_prices on public.payment_prices for select to anon,authenticated using(public.course_is_available(course_id));
create policy admin_payment_prices on public.payment_prices for select to authenticated using(public.is_academy_admin());
-- This internal metadata lookup must work for anonymous catalog policies too.
create or replace function public.course_is_available(course_key text) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select published and not archived from public.academy_courses where id=course_key),course_key in ('heart-foundations','ecg-essentials','prevention'));
$$;
revoke all on function public.course_is_available(text) from public,anon,authenticated,service_role;
grant execute on function public.course_is_available(text) to anon,authenticated;
create function public.payment_course_is_paid(course_key text) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select paid from public.payment_course_settings where course_id=course_key),false);
$$;
revoke all on function public.payment_course_is_paid(text) from public,anon,authenticated,service_role;
grant execute on function public.payment_course_is_paid(text) to anon,authenticated;
create function public.payment_has_access(course_key text) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (public.is_academy_admin() or (public.course_is_available(course_key) and (not public.payment_course_is_paid(course_key) or (exists(select 1 from public.enrollments where user_id=auth.uid() and course_id=course_key) and (not exists(select 1 from public.commerce_entitlements where user_id=auth.uid() and course_id=course_key) or exists(select 1 from public.commerce_entitlements where user_id=auth.uid() and course_id=course_key and active))))));
$$;
revoke all on function public.payment_has_access(text) from public,anon,authenticated,service_role;
grant execute on function public.payment_has_access(text) to authenticated;
alter policy own_enrollments_insert on public.enrollments with check(user_id=(select auth.uid()) and public.course_is_available(course_id) and not public.payment_course_is_paid(course_id));
create function public.payment_get_content(course_key text) returns jsonb language plpgsql stable security definer set search_path='' as $$ BEGIN
 if auth.uid() is null or not public.payment_has_access(course_key) then raise exception 'Course access required' using errcode='42501';end if;
 return (select payload from public.payment_course_content where course_id=course_key and public.payment_course_is_paid(course_key));END;$$;
revoke all on function public.payment_get_content(text) from public,anon,authenticated,service_role;
grant execute on function public.payment_get_content(text) to authenticated;
create function public.payment_public_payload(full_payload jsonb) returns jsonb language sql immutable set search_path='' as $$
 select jsonb_build_object(
 'id',full_payload->'id','title',full_payload->'title','subtitle',full_payload->'subtitle',
 'category',full_payload->'category','description',full_payload->'description','outcomes',full_payload->'outcomes',
 'isSample',full_payload->'isSample','level',full_payload->'level','art',full_payload->'art',
 'lessons',coalesce((select jsonb_agg(jsonb_build_object(
 'id',l->>'id','title',l->>'title','minutes',(l->>'minutes')::integer,'content','Enroll to access this lesson.',
 'question','This lesson requires course access.','options',jsonb_build_array('Locked','Locked','Locked'),'answer',0,'explanation','Complete checkout to access this lesson.'
 ) order by position) from jsonb_array_elements(full_payload->'lessons') with ordinality as lessons(l,position)),'[]'::jsonb));
$$;
-- Prevent the existing publishing RPC from leaking paid lesson content.
alter function public.save_academy_course(text,jsonb,boolean) rename to payment_base_save_course;
revoke all on function public.payment_base_save_course(text,jsonb,boolean) from public,anon,authenticated,service_role;
create function public.save_academy_course(course_id text,course_payload jsonb,is_published boolean default false) returns void language plpgsql security definer set search_path='' as $$
begin
 -- Shared advisory lock serializes content/pricing changes for this course.
 perform pg_advisory_xact_lock(hashtextextended(course_id,0));
 if auth.uid() is null or not public.is_academy_admin() then raise exception 'Administrator access required' using errcode='42501';end if;
 if public.payment_course_is_paid(course_id) and exists(select 1 from jsonb_array_elements(course_payload->'lessons') l where l->>'content'='Enroll to access this lesson.' or l->>'question'='This lesson requires course access.') then raise exception 'Locked placeholders cannot overwrite original content';end if;
 perform public.payment_base_save_course(course_id,course_payload,is_published);
 if public.payment_course_is_paid(course_id) then
  insert into public.payment_course_content values(course_id,course_payload) on conflict on constraint payment_course_content_pkey do update set payload=excluded.payload;
  update public.academy_courses set payload=public.payment_public_payload(course_payload) where id=course_id;
 end if;
end;$$;
revoke all on function public.save_academy_course(text,jsonb,boolean) from public,anon,authenticated,service_role;
grant execute on function public.save_academy_course(text,jsonb,boolean) to authenticated;
revoke all on function public.payment_public_payload(jsonb) from public,anon,authenticated,service_role;
create function public.commerce_set_prices(course_key text,is_paid boolean,price_bdt bigint,price_usd bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare original jsonb; was_paid boolean;
begin
 if auth.uid() is null or not public.is_academy_admin() then raise exception 'Administrator access required' using errcode='42501';end if;
 if course_key in ('heart-foundations','ecg-essentials','prevention') and is_paid then raise exception 'Public samples remain free';end if;
 if is_paid is null or (is_paid and price_bdt is null and price_usd is null) or (price_bdt is not null and price_bdt not between 1 and 1000000000) or (price_usd is not null and price_usd not between 1 and 1000000000) then raise exception 'Invalid prices';end if;
 perform pg_advisory_xact_lock(hashtextextended(course_key,0));
 select payload into original from public.academy_courses where id=course_key for update;
 if not found then raise exception 'Managed course required';end if;
 was_paid:=public.payment_course_is_paid(course_key);
 if is_paid and not was_paid then
  insert into public.payment_course_content values(course_key,original) on conflict(course_id) do update set payload=excluded.payload;
  update public.academy_courses set payload=public.payment_public_payload(original) where id=course_key;
 elsif not is_paid and was_paid then
  update public.academy_courses set payload=(select payload from public.payment_course_content where course_id=course_key) where id=course_key;
 end if;
 insert into public.payment_course_settings values(course_key,is_paid) on conflict(course_id) do update set paid=excluded.paid;
 insert into public.payment_prices values(course_key,'BDT',price_bdt,1,now()),(course_key,'USD',price_usd,1,now())
 on conflict(course_id,currency) do update set amount_minor=excluded.amount_minor,revision=payment_prices.revision+case when payment_prices.amount_minor is distinct from excluded.amount_minor then 1 else 0 end,updated_at=case when payment_prices.amount_minor is distinct from excluded.amount_minor then now() else payment_prices.updated_at end;
 insert into public.commerce_audit(actor,event,details) values(auth.uid(),'prices.saved',jsonb_build_object('course_id',course_key,'paid',is_paid,'BDT',price_bdt,'USD',price_usd));
 return jsonb_build_object('paid',is_paid,'BDT',price_bdt,'USD',price_usd);
end;$$;
revoke all on function public.commerce_set_prices(text,boolean,bigint,bigint) from public,anon,authenticated,service_role;
grant execute on function public.commerce_set_prices(text,boolean,bigint,bigint) to authenticated;
ALTER TABLE public.lesson_progress ADD COLUMN quiz_score smallint, ADD COLUMN quiz_total smallint;
ALTER TABLE public.lesson_progress ADD CONSTRAINT lesson_progress_score_valid CHECK ((quiz_score IS NULL AND quiz_total IS NULL) OR (quiz_score IS NOT NULL AND quiz_total IS NOT NULL AND quiz_total=1 AND quiz_score=1));
CREATE FUNCTION public.academy_complete_lesson(course_key text,lesson_key text,selected_answer integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE actor uuid := auth.uid(); content jsonb; expected integer;
BEGIN
 IF actor IS NULL OR NOT public.payment_has_access(course_key) OR NOT public.course_is_available(course_key) OR NOT EXISTS(SELECT 1 FROM public.enrollments e WHERE e.user_id=actor AND e.course_id=course_key) THEN RAISE EXCEPTION 'Enroll in this course before saving progress' USING ERRCODE='42501';END IF;
 IF selected_answer IS NULL OR selected_answer NOT BETWEEN 0 AND 2 THEN RAISE EXCEPTION 'Choose a valid quiz answer' USING ERRCODE='22023';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.course_lessons l WHERE l.course_id=course_key AND l.lesson_id=lesson_key) THEN RAISE EXCEPTION 'Lesson not found' USING ERRCODE='22023';END IF;
 IF public.payment_course_is_paid(course_key) THEN
  SELECT p.payload INTO content FROM public.payment_course_content p WHERE p.course_id=course_key;
 ELSE
  SELECT c.payload INTO content FROM public.academy_courses c WHERE c.id=course_key;
 END IF;
 IF content IS NOT NULL THEN
  SELECT (l->>'answer')::integer INTO expected FROM jsonb_array_elements(content->'lessons') l WHERE l->>'id'=lesson_key;
 ELSE
  -- Existing bundled free samples: preserve their completion behavior.
  expected := CASE course_key||'/'||lesson_key
   WHEN 'heart-foundations/chambers' THEN 2 WHEN 'heart-foundations/valves' THEN 0 WHEN 'heart-foundations/coronary' THEN 0
   WHEN 'ecg-essentials/electrical' THEN 1 WHEN 'ecg-essentials/waves' THEN 0 WHEN 'ecg-essentials/approach' THEN 1
   WHEN 'prevention/risk' THEN 1 WHEN 'prevention/measurements' THEN 1 WHEN 'prevention/habits' THEN 1 END;
 END IF;
 IF expected IS NULL OR expected NOT BETWEEN 0 AND 2 THEN RAISE EXCEPTION 'Quiz is unavailable' USING ERRCODE='22023';END IF;
 IF selected_answer<>expected THEN RETURN jsonb_build_object('correct',false,'score',0,'total',1,'saved',false);END IF;
 INSERT INTO public.lesson_progress(user_id,course_id,lesson_id,quiz_score,quiz_total) VALUES(actor,course_key,lesson_key,1,1)
 ON CONFLICT(user_id,course_id,lesson_id) DO UPDATE SET quiz_score=1,quiz_total=1;
 RETURN jsonb_build_object('correct',true,'score',1,'total',1,'saved',true);
END;$function$;
REVOKE ALL ON FUNCTION public.academy_complete_lesson(text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.academy_complete_lesson(text,text,integer) TO authenticated;
-- All new completion writes are verified against enrollment and the original quiz on the server.
REVOKE INSERT ON public.lesson_progress FROM authenticated;
CREATE FUNCTION public.academy_admin_enrollments()
RETURNS TABLE(user_id uuid,course_id text,enrolled_at timestamptz,completed_lessons integer,lesson_total integer,quiz_score integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_academy_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';END IF;
 RETURN QUERY SELECT e.user_id,e.course_id,e.created_at,count(lp.lesson_id)::integer,
 coalesce(jsonb_array_length(c.payload->'lessons'),(SELECT count(*)::integer FROM public.course_lessons cl WHERE cl.course_id=e.course_id)),
 coalesce(sum(lp.quiz_score),0)::integer
 FROM public.enrollments e LEFT JOIN public.academy_courses c ON c.id=e.course_id
 LEFT JOIN public.lesson_progress lp ON lp.user_id=e.user_id AND lp.course_id=e.course_id
 GROUP BY e.user_id,e.course_id,e.created_at,c.payload ORDER BY e.created_at DESC;
END;$function$;
REVOKE ALL ON FUNCTION public.academy_admin_enrollments() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.academy_admin_enrollments() TO authenticated;
