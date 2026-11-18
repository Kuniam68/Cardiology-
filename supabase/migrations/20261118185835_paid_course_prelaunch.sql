-- Paid prelaunch pricing and explicit public preview metadata. No data/ACL changes.
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
DO $$ BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'Database owner required';END IF;
 IF md5(pg_get_functiondef('public.commerce_set_prices(text,boolean,bigint,bigint)'::regprocedure))<>'9d4e45b8821d72cfa858ee251bf12d11' THEN RAISE EXCEPTION 'Reviewed function drift: commerce_set_prices';END IF;
 IF md5(pg_get_functiondef('public.payment_public_payload(jsonb)'::regprocedure))<>'9eb3ac1c7d7a3da66c9f2ee32d494e9a' THEN RAISE EXCEPTION 'Reviewed function drift: payment_public_payload';END IF;
 IF EXISTS(select 1 from public.commerce_settings where live_enabled or merchant_approved or provider_environment<>'disabled') THEN RAISE EXCEPTION 'Checkout must remain disabled';END IF;
END $$;
CREATE OR REPLACE FUNCTION public.commerce_set_prices(course_key text, is_paid boolean, price_bdt bigint, price_usd bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare original jsonb; was_paid boolean;
begin
 if auth.uid() is null or not public.is_academy_admin() then raise exception 'Administrator access required' using errcode='42501';end if;
 if course_key in ('heart-foundations','ecg-essentials','prevention') and is_paid then raise exception 'Public samples remain free';end if;
 if is_paid is null or (price_bdt is not null and price_bdt not between 1 and 1000000000) or (price_usd is not null and price_usd not between 1 and 1000000000) then raise exception 'Invalid prices';end if;
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
end;$function$
;
CREATE OR REPLACE FUNCTION public.payment_public_payload(full_payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 select jsonb_build_object(
 'id',full_payload->'id','title',full_payload->'title','subtitle',full_payload->'subtitle',
 'preview',case when jsonb_typeof(full_payload->'preview')='string' then left(full_payload->>'preview',1500) else '' end,
 'editorialNote',case when jsonb_typeof(full_payload->'editorialNote')='string' then left(full_payload->>'editorialNote',400) else '' end,
 'sources',case when jsonb_typeof(full_payload->'sources')='array' then (select coalesce(jsonb_agg(s),'[]'::jsonb) from jsonb_array_elements(full_payload->'sources') s where case when jsonb_typeof(s)='array' then jsonb_array_length(s)=2 else false end and jsonb_typeof(s->0)='string' and jsonb_typeof(s->1)='string' and length(s->>0) between 1 and 150 and length(s->>1)<=500 and s->>1 ~ '^https://') else '[]'::jsonb end,
 'category',full_payload->'category','description',full_payload->'description','outcomes',full_payload->'outcomes',
 'isSample',full_payload->'isSample','level',full_payload->'level','art',full_payload->'art',
 'lessons',coalesce((select jsonb_agg(jsonb_build_object(
 'id',l->>'id','title',l->>'title','minutes',(l->>'minutes')::integer,'content','Enroll to access this lesson.',
 'question','This lesson requires course access.','options',jsonb_build_array('Locked','Locked','Locked'),'answer',0,'explanation','Complete checkout to access this lesson.'
 ) order by position) from jsonb_array_elements(full_payload->'lessons') with ordinality as lessons(l,position)),'[]'::jsonb));
$function$
;
