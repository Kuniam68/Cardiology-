set local lock_timeout = '5s';
alter table public.payment_prices add column provisional boolean not null default false;

-- Both operations share commerce_set_prices' course-level transaction lock.
create function public.academy_configure_prices(course_key text, is_paid boolean,
 price_bdt bigint, price_usd bigint, display_only boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare prior_bdt bigint; prior_usd bigint;
begin
 if auth.uid() is null or not public.is_academy_admin() then
   raise exception 'Administrator access required' using errcode='42501';
 end if;
 if display_only is null then raise exception 'Choose a pricing status'; end if;
 perform pg_advisory_xact_lock(hashtextextended(course_key,0));
 select max(amount_minor) filter(where currency='BDT'),max(amount_minor) filter(where currency='USD')
 into prior_bdt,prior_usd from public.payment_prices where course_id=course_key;
 perform public.commerce_set_prices(course_key,is_paid,price_bdt,price_usd);
 update public.payment_prices set provisional=display_only,
   revision=revision+case when amount_minor is not distinct from
     (case currency when 'BDT' then prior_bdt else prior_usd end) then 1 else 0 end,
   updated_at=now()
 where course_id=course_key and provisional<>display_only;
 insert into public.commerce_audit(actor,event,details) values(auth.uid(),'pricing.status',
   jsonb_build_object('course_id',course_key,'provisional',display_only));
end; $$;
revoke all on function public.academy_configure_prices(text,boolean,bigint,bigint,boolean) from public,anon,authenticated,service_role;
grant execute on function public.academy_configure_prices(text,boolean,bigint,bigint,boolean) to authenticated;
CREATE OR REPLACE FUNCTION public.commerce_create_order(actor uuid, course_key text, selected_currency text, idempotency_key uuid, expected_environment text)
 RETURNS commerce_orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s public.commerce_settings;p public.payment_prices;o public.commerce_orders;new_id uuid;
begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email_confirmed_at is not null) then raise exception 'Confirmed account required' using errcode='42501';end if;
 select * into s from public.commerce_settings where singleton for share;
 if not s.live_enabled or not s.merchant_approved or s.provider_environment<>expected_environment or expected_environment not in ('sandbox','live') then raise exception 'Checkout unavailable' using errcode='42501';end if;
 if selected_currency is null or selected_currency<>'BDT' or not(selected_currency=any(s.verified_currencies)) or idempotency_key is null then raise exception 'Currency unavailable';end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||'/'||course_key,1));
 select * into o from public.commerce_orders where user_id=actor and request_key=idempotency_key;
 if found then
  if o.course_id<>course_key or o.currency<>selected_currency or o.environment<>expected_environment then raise exception 'Idempotency conflict';end if;return o;
 end if;
 if not public.course_is_available(course_key) or not public.payment_course_is_paid(course_key) then raise exception 'Paid course unavailable';end if;
 if exists(select 1 from public.enrollments where user_id=actor and course_id=course_key) and (not exists(select 1 from public.commerce_entitlements where user_id=actor and course_id=course_key) or exists(select 1 from public.commerce_entitlements where user_id=actor and course_id=course_key and active)) then raise exception 'Already enrolled';end if;
 select * into o from public.commerce_orders where user_id=actor and course_id=course_key and environment=expected_environment and status in ('initializing','pending','session_unknown','review');
 if found then return o;end if;
 if (select count(*) from public.commerce_orders where user_id=actor and created_at>now()-interval '1 hour')>=10 then raise exception 'Too many checkout attempts';end if;
 -- Same course lock as pricing prevents a torn price revision.
 perform pg_advisory_xact_lock(hashtextextended(course_key,0));
 select * into p from public.payment_prices where course_id=course_key and currency=selected_currency;
 if not found or p.provisional or p.amount_minor is null or p.amount_minor not between 1000 and 50000000 then raise exception 'Price unavailable for this gateway';end if;
 new_id:=gen_random_uuid();
 insert into public.commerce_orders(id,merchant_ref,user_id,course_id,request_key,currency,amount_minor,price_revision,environment) values(new_id,'CB'||substr(replace(new_id::text,'-',''),1,28),actor,course_key,idempotency_key,p.currency,p.amount_minor,p.revision,expected_environment) returning * into o;
 insert into public.commerce_audit(actor,event,order_id) values(actor,'order.created',o.id);return o;
end;$function$
;
