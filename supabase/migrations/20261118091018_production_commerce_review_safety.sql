SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
-- Preserve an audit record for late duplicate/risky verified charges without a second grant.
create or replace function public.commerce_order_guard() returns trigger language plpgsql set search_path='' as $$begin
 if (new.id,new.merchant_ref,new.user_id,new.course_id,new.request_key,new.currency,new.amount_minor,new.price_revision,new.environment,new.provider,new.created_at) is distinct from (old.id,old.merchant_ref,old.user_id,old.course_id,old.request_key,old.currency,old.amount_minor,old.price_revision,old.environment,old.provider,old.created_at) then raise exception 'Immutable order fields';end if;
 if (old.validation_id is not null and new.validation_id is distinct from old.validation_id) or (old.bank_reference is not null and new.bank_reference is distinct from old.bank_reference) or (old.session_key is not null and new.session_key is distinct from old.session_key) or (old.checkout_url is not null and new.checkout_url is distinct from old.checkout_url) then raise exception 'Immutable provider reference';end if;
 if new.status<>old.status and not (
  (old.status in ('initializing','pending','session_unknown') and new.status in ('pending','session_unknown','succeeded','failed','cancelled','review')) or
  (old.status in ('failed','cancelled','review') and new.status in ('succeeded','review')) or
  (old.status in ('succeeded','review') and new.status='refunded')) then raise exception 'Invalid order transition';end if;
 new.updated_at:=now();return new;end;$$;
create or replace function public.commerce_record_payment(order_key uuid,merchant_transaction text,verified_amount bigint,verified_currency text,verified_environment text,verified_status text,validation_reference text,bank_transaction text) returns public.commerce_orders language plpgsql security definer set search_path='' as $$
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
 if target='succeeded' and exists(select 1 from public.commerce_entitlements where user_id=o.user_id and course_id=o.course_id and active and order_id<>o.id) then target:='review';end if;
 if target='succeeded' and (not public.course_is_available(o.course_id) or not public.payment_course_is_paid(o.course_id)) then target:='review';end if;
 update public.commerce_orders set status=target,validation_id=coalesce(nullif(validation_reference,''),validation_id),bank_reference=coalesce(nullif(bank_transaction,''),bank_reference) where id=o.id returning * into o;
 if target='succeeded' then
  insert into public.enrollments(user_id,course_id) values(o.user_id,o.course_id) on conflict do nothing;
  insert into public.commerce_entitlements(user_id,course_id,order_id) values(o.user_id,o.course_id,o.id) on conflict do nothing;
 end if;
 insert into public.commerce_audit(event,order_id,details) values('payment.'||target,o.id,jsonb_build_object('currency',o.currency,'amount_minor',o.amount_minor));return o;end;$$;
create or replace function public.commerce_request_refund(actor uuid,order_key uuid,reason_text text) returns public.commerce_refunds language plpgsql security definer set search_path='' as $$
declare o public.commerce_orders;r public.commerce_refunds;new_id uuid;begin
 if not exists(select 1 from public.academy_admins where user_id=actor) then raise exception 'Administrator required' using errcode='42501';end if;
 select * into o from public.commerce_orders where id=order_key for update;if not found or (o.status not in ('succeeded','review') or o.validation_id is null or o.bank_reference is null) then raise exception 'Settled order required';end if;
 select * into r from public.commerce_refunds where order_id=order_key;if found then return r;end if;
 new_id:=gen_random_uuid();insert into public.commerce_refunds(id,order_id,actor,refund_trans_id,amount_minor,reason) values(new_id,order_key,actor,'RF'||substr(replace(new_id::text,'-',''),1,28),o.amount_minor,trim(reason_text)) returning * into r;
 insert into public.commerce_audit(actor,event,order_id) values(actor,'refund.requested',order_key);return r;end;$$;
create or replace function public.commerce_record_refund(refund_key uuid,provider_ref text,verified_status text) returns public.commerce_refunds language plpgsql security definer set search_path='' as $$
declare r public.commerce_refunds;begin
 select * into r from public.commerce_refunds where id=refund_key for update;if not found then raise exception 'Refund unavailable';end if;
 if verified_status is null or verified_status not in ('unknown','processing','refunded','cancelled','failed') then raise exception 'Invalid refund state';end if;
 if r.status='refunded' then return r;end if;
 if r.status not in ('submitting','unknown','processing') then raise exception 'Refund not submitted';end if;
 if r.provider_reference is not null and provider_ref is distinct from r.provider_reference then raise exception 'Conflicting refund reference';end if;
 if verified_status in ('processing','refunded') and coalesce(provider_ref,'')='' then raise exception 'Refund reference required';end if;
 update public.commerce_refunds set status=verified_status,provider_reference=coalesce(provider_ref,provider_reference),updated_at=now() where id=r.id returning * into r;
 if verified_status='refunded' then
  update public.commerce_orders set status='refunded' where id=r.order_id and status in ('succeeded','review');
  update public.commerce_entitlements set active=false where order_id=r.order_id;
 end if;
 insert into public.commerce_audit(event,order_id) values('refund.'||verified_status,r.order_id);return r;end;$$;
-- Review rows block new checkout in commerce_create_order but may coexist with a later in-flight order.
create unique index commerce_one_pending_order on public.commerce_orders(user_id,course_id,environment) where status in ('initializing','pending','session_unknown');
drop index public.commerce_one_active_order;
