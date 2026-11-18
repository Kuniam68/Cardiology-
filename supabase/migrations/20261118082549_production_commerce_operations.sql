SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
-- All privileged payment transitions are service-only. Client JWTs cannot execute them.
create function public.commerce_create_order(actor uuid,course_key text,selected_currency text,idempotency_key uuid,expected_environment text) returns public.commerce_orders language plpgsql security definer set search_path='' as $$
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
 if not found or p.amount_minor is null or p.amount_minor not between 1000 and 50000000 then raise exception 'Price unavailable for this gateway';end if;
 new_id:=gen_random_uuid();
 insert into public.commerce_orders(id,merchant_ref,user_id,course_id,request_key,currency,amount_minor,price_revision,environment) values(new_id,'CB'||substr(replace(new_id::text,'-',''),1,28),actor,course_key,idempotency_key,p.currency,p.amount_minor,p.revision,expected_environment) returning * into o;
 insert into public.commerce_audit(actor,event,order_id) values(actor,'order.created',o.id);return o;
end;$$;
create function public.commerce_order_guard() returns trigger language plpgsql set search_path='' as $$begin
 if (new.id,new.merchant_ref,new.user_id,new.course_id,new.request_key,new.currency,new.amount_minor,new.price_revision,new.environment,new.provider,new.created_at) is distinct from (old.id,old.merchant_ref,old.user_id,old.course_id,old.request_key,old.currency,old.amount_minor,old.price_revision,old.environment,old.provider,old.created_at) then raise exception 'Immutable order fields';end if;
 if (old.validation_id is not null and new.validation_id is distinct from old.validation_id) or (old.bank_reference is not null and new.bank_reference is distinct from old.bank_reference) or (old.session_key is not null and new.session_key is distinct from old.session_key) or (old.checkout_url is not null and new.checkout_url is distinct from old.checkout_url) then raise exception 'Immutable provider reference';end if;
 if new.status<>old.status and not (
  (old.status in ('initializing','pending','session_unknown') and new.status in ('pending','session_unknown','succeeded','failed','cancelled','review')) or
  (old.status in ('failed','cancelled','review') and new.status in ('succeeded','review')) or
  (old.status='succeeded' and new.status='refunded')) then raise exception 'Invalid order transition';end if;
 new.updated_at:=now();return new;end;$$;
create trigger commerce_immutable_order before update on public.commerce_orders for each row execute function public.commerce_order_guard();
create function public.commerce_claim_session(order_key uuid) returns boolean language plpgsql security definer set search_path='' as $$begin
 update public.commerce_orders set session_attempted=true where id=order_key and status='initializing' and not session_attempted;return found;end;$$;
create function public.commerce_attach_session(order_key uuid,provider_session text,provider_url text) returns public.commerce_orders language plpgsql security definer set search_path='' as $$
declare o public.commerce_orders;allowed text;begin
 select * into o from public.commerce_orders where id=order_key for update;if not found or o.status<>'initializing' then raise exception 'Session already attempted';end if;
 allowed:=case when o.environment='sandbox' then 'https://sandbox.sslcommerz.com/' else 'https://securepay.sslcommerz.com/' end;
 if length(coalesce(provider_session,'')) not between 1 and 255 or length(coalesce(provider_url,'')) not between 1 and 2000 or left(provider_url,length(allowed))<>allowed then raise exception 'Invalid hosted session';end if;
 update public.commerce_orders set session_key=provider_session,checkout_url=provider_url,status='pending' where id=o.id returning * into o;
 insert into public.commerce_audit(event,order_id) values('session.created',o.id);return o;end;$$;
create function public.commerce_session_unknown(order_key uuid) returns void language plpgsql security definer set search_path='' as $$begin
 update public.commerce_orders set status='session_unknown' where id=order_key and status='initializing';
 insert into public.commerce_audit(event,order_id) values('session.uncertain',order_key);end;$$;
create function public.commerce_claim_reconciliation(order_key uuid,actor uuid) returns boolean language plpgsql security definer set search_path='' as $$begin
 update public.commerce_orders set last_reconciled_at=now() where id=order_key and (user_id=actor or exists(select 1 from public.academy_admins where user_id=actor)) and (last_reconciled_at is null or last_reconciled_at<now()-interval '15 seconds');return found;end;$$;
create function public.commerce_record_payment(order_key uuid,merchant_transaction text,verified_amount bigint,verified_currency text,verified_environment text,verified_status text,validation_reference text,bank_transaction text) returns public.commerce_orders language plpgsql security definer set search_path='' as $$
declare o public.commerce_orders;target text;begin
 select * into o from public.commerce_orders where id=order_key for update;if not found then raise exception 'Order unavailable';end if;
 if merchant_transaction is distinct from o.merchant_ref or verified_amount is distinct from o.amount_minor or verified_currency is distinct from o.currency or verified_environment is distinct from o.environment then raise exception 'Receipt mismatch';end if;
 if verified_status not in ('succeeded','failed','cancelled','review') or verified_status is null then raise exception 'Invalid provider state';end if;
 if verified_status in ('succeeded','review') and (length(coalesce(validation_reference,'')) not between 1 and 100 or length(coalesce(bank_transaction,'')) not between 1 and 100) then raise exception 'Verified references required';end if;
 if o.status='refunded' then return o;end if;
 if o.status='succeeded' then
  if validation_reference is distinct from o.validation_id or bank_transaction is distinct from o.bank_reference then raise exception 'Conflicting settled payment';end if;return o;
 end if;
 if o.status in ('failed','cancelled','review') and verified_status in ('failed','cancelled') then return o;end if;
 target:=verified_status;
 if target='succeeded' and (not public.course_is_available(o.course_id) or not public.payment_course_is_paid(o.course_id)) then target:='review';end if;
 update public.commerce_orders set status=target,validation_id=coalesce(nullif(validation_reference,''),validation_id),bank_reference=coalesce(nullif(bank_transaction,''),bank_reference) where id=o.id returning * into o;
 if target='succeeded' then
  insert into public.enrollments(user_id,course_id) values(o.user_id,o.course_id) on conflict do nothing;
  insert into public.commerce_entitlements(user_id,course_id,order_id) values(o.user_id,o.course_id,o.id) on conflict do nothing;
 end if;
 insert into public.commerce_audit(event,order_id,details) values('payment.'||target,o.id,jsonb_build_object('currency',o.currency,'amount_minor',o.amount_minor));return o;end;$$;
create function public.commerce_request_refund(actor uuid,order_key uuid,reason_text text) returns public.commerce_refunds language plpgsql security definer set search_path='' as $$
declare o public.commerce_orders;r public.commerce_refunds;new_id uuid;begin
 if not exists(select 1 from public.academy_admins where user_id=actor) then raise exception 'Administrator required' using errcode='42501';end if;
 select * into o from public.commerce_orders where id=order_key for update;if not found or o.status<>'succeeded' then raise exception 'Settled order required';end if;
 select * into r from public.commerce_refunds where order_id=order_key;if found then return r;end if;
 new_id:=gen_random_uuid();insert into public.commerce_refunds(id,order_id,actor,refund_trans_id,amount_minor,reason) values(new_id,order_key,actor,'RF'||substr(replace(new_id::text,'-',''),1,28),o.amount_minor,trim(reason_text)) returning * into r;
 insert into public.commerce_audit(actor,event,order_id) values(actor,'refund.requested',order_key);return r;end;$$;
create function public.commerce_claim_refund(actor uuid,refund_key uuid) returns public.commerce_refunds language plpgsql security definer set search_path='' as $$
declare r public.commerce_refunds;begin
 if not exists(select 1 from public.academy_admins where user_id=actor) then raise exception 'Administrator required' using errcode='42501';end if;
 update public.commerce_refunds set status='submitting',updated_at=now() where id=refund_key and status='requested' returning * into r;if not found then raise exception 'Refund already attempted; reconcile instead';end if;return r;end;$$;
create function public.commerce_record_refund(refund_key uuid,provider_ref text,verified_status text) returns public.commerce_refunds language plpgsql security definer set search_path='' as $$
declare r public.commerce_refunds;begin
 select * into r from public.commerce_refunds where id=refund_key for update;if not found then raise exception 'Refund unavailable';end if;
 if verified_status is null or verified_status not in ('unknown','processing','refunded','cancelled','failed') then raise exception 'Invalid refund state';end if;
 if r.status='refunded' then return r;end if;
 if r.status not in ('submitting','unknown','processing') then raise exception 'Refund not submitted';end if;
 if r.provider_reference is not null and provider_ref is distinct from r.provider_reference then raise exception 'Conflicting refund reference';end if;
 if verified_status in ('processing','refunded') and coalesce(provider_ref,'')='' then raise exception 'Refund reference required';end if;
 update public.commerce_refunds set status=verified_status,provider_reference=coalesce(provider_ref,provider_reference),updated_at=now() where id=r.id returning * into r;
 if verified_status='refunded' then
  update public.commerce_orders set status='refunded' where id=r.order_id and status='succeeded';
  update public.commerce_entitlements set active=false where order_id=r.order_id;
 end if;
 insert into public.commerce_audit(event,order_id) values('refund.'||verified_status,r.order_id);return r;end;$$;
-- Explicit allowlist of service RPCs. Privileged trigger/helper execution is never a client API.
DO $$ DECLARE f record;BEGIN
 FOR f IN SELECT p.oid::regprocedure signature,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' and p.proname in ('commerce_create_order','commerce_claim_session','commerce_order_guard','commerce_attach_session','commerce_session_unknown','commerce_claim_reconciliation','commerce_record_payment','commerce_request_refund','commerce_claim_refund','commerce_record_refund') LOOP
  execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
  if f.proname<>'commerce_order_guard' then execute format('grant execute on function %s to service_role',f.signature);end if;
 END LOOP;
END $$;
