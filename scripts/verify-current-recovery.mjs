// Local recovery verification only. Never opens a network/database connection.
import {readFileSync,writeFileSync} from 'node:fs';
import {restore} from './restore-fixture.mjs';
import {readdirSync} from 'node:fs';
import assert from 'node:assert/strict';
const path=process.env.CARDIOBUG_CURRENT_SNAPSHOT;
if(!path)throw new Error('Specify a private CARDIOBUG_CURRENT_SNAPSHOT file.');
const snapshot=JSON.parse(readFileSync(path,'utf8')),db=await restore();
const stable=v=>Array.isArray(v)?v.map(stable):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,stable(v[k])])):v;
try{
 for(const name of readdirSync('supabase/migrations').sort())await db.transaction(tx=>tx.exec(readFileSync('supabase/migrations/'+name,'utf8')));
 const users=new Set(['academy_admins','enrollments','lesson_progress','commerce_orders','commerce_entitlements'].flatMap(t=>(snapshot.tables[t]||[]).map(x=>x.user_id)));
 for(const id of users)await db.query('insert into auth.users(id) values($1) on conflict do nothing',[id]);
 const order=['course_catalog','course_lessons','academy_admins','academy_courses','enrollments','lesson_progress','payment_course_settings','payment_course_content','payment_prices','commerce_settings','commerce_orders','commerce_entitlements','commerce_refunds','commerce_audit'];
 for(const table of order){
  const pk=(await db.query("select a.attname from pg_index i cross join lateral unnest(i.indkey) with ordinality k(attnum,pos) join pg_attribute a on a.attrelid=i.indrelid and a.attnum=k.attnum where i.indrelid=$1::regclass and i.indisprimary order by k.pos",['public.'+table])).rows.map(x=>x.attname);
  for(const row of snapshot.tables[table]){
   const cols=Object.keys(row),updates=cols.filter(k=>!pk.includes(k));
   await db.query('insert into public.'+table+'('+cols.join(',')+') overriding system value values('+cols.map((_,i)=>'$'+(i+1)).join(',')+') on conflict('+pk.join(',')+') '+(updates.length?'do update set '+updates.map(k=>k+'=excluded.'+k).join(','):'do nothing'),cols.map(k=>['json','jsonb'].includes(snapshot.columns.find(c=>c.table_name===table&&c.column_name===k)?.data_type)&&row[k]!==null?JSON.stringify(row[k]):row[k]));
  }
  const rows=(await db.query('select to_jsonb(r) row from public.'+table+' r')).rows.map(r=>r.row);
  const normalize=a=>a.map(r=>JSON.stringify(stable(r))).sort();
  assert.ok(JSON.stringify(normalize(rows))===JSON.stringify(normalize(snapshot.tables[table])),'Exact recovery: '+table);
 }
 await db.exec(readFileSync('supabase/operations/stop-checkout.sql','utf8'));
 assert.equal((await db.query('select live_enabled from public.commerce_settings')).rows[0].live_enabled,false);
 const proof={applicationTablesRestored:order.length,exactRowsMatch:true,emergencyStopTested:true,fullAuthStoragePITRBackup:false};
 if(process.env.CARDIOBUG_GUARDED_SQL){
  await db.exec(readFileSync(process.env.CARDIOBUG_GUARDED_SQL,'utf8'));
  assert.equal((await db.query("select published and not archived and public.payment_course_is_paid(id) ready from public.academy_courses where id='intro-cardiology'")).rows[0].ready,true);
  proof.guardedCourseTransactionTested=true;
 }
 if(process.env.CARDIOBUG_RECOVERY_PROOF)writeFileSync(process.env.CARDIOBUG_RECOVERY_PROOF,JSON.stringify(proof,null,2)+'\n');
 console.log(JSON.stringify(proof));
}finally{await db.close();}
