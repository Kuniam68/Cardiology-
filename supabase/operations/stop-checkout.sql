-- Emergency stop: verify the project identity before execution. No data is removed.
-- Leave accepted provider mode/credentials in place to reconcile existing authorized payments.
begin;
set local lock_timeout='5s';
set local statement_timeout='10s';
do $$ begin
 if current_user<>'postgres' then raise exception 'Database owner required';end if;
 if not exists(select 1 from public.commerce_settings where singleton) then raise exception 'Commerce configuration absent';end if;
end $$;
update public.commerce_settings set live_enabled=false where singleton;
do $$ begin
 if exists(select 1 from public.commerce_settings where live_enabled) then raise exception 'Stop failed';end if;
end $$;
commit;
