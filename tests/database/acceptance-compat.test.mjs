import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync,readdirSync} from 'node:fs';import {restore,role} from '../../scripts/restore-fixture.mjs';
test('official gateway acceptance installs beside the existing isolated paid-course schema',async()=>{
 const db=await restore();try{
  // Construct an isolated pre-commerce paid-course schema. These drops are in-memory fixture setup only.
  const foundation=readdirSync('supabase/migrations').find(f=>f.endsWith('_production_commerce_foundation.sql'));await db.transaction(tx=>tx.exec(readFileSync('supabase/migrations/'+foundation,'utf8')));
  await db.exec('drop table public.commerce_refunds,public.commerce_entitlements,public.commerce_audit,public.commerce_orders,public.commerce_settings cascade;create table public.payment_sandbox_settings(singleton boolean primary key,enabled boolean,environment text);insert into public.payment_sandbox_settings values(true,true,\'sandbox\');');
  const sql=readFileSync('supabase/acceptance-migrations/'+readdirSync('supabase/acceptance-migrations')[0],'utf8');await db.transaction(tx=>tx.exec(sql));
  const s=(await db.query('select * from public.commerce_settings')).rows[0];assert.equal(s.provider_environment,'sandbox');assert.equal(s.live_enabled,true);assert.equal((await db.query('select enabled from public.payment_sandbox_settings')).rows[0].enabled,true);
  await role(db,'authenticated','11111111-1111-4111-8111-111111111111');assert.equal((await db.query('select public.is_academy_admin() a')).rows[0].a,true);await assert.rejects(db.query('select public.commerce_record_payment(null,null,1,\'BDT\',\'sandbox\',\'succeeded\',null,null)'),/permission denied/);
 }finally{await db.close();}
});
