// Restore a private production application snapshot into an isolated PostgreSQL fixture.
// No production connections and no authentication credentials are used.
import {readFileSync} from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
export const backup=JSON.parse(readFileSync(process.env.CARDIOBUG_BACKUP_FILE||new URL('../tests/fixtures/production-schema.json',import.meta.url),'utf8'));
export async function restore(){
 const db=new PGlite();
 await db.exec(`create schema auth;create role anon;create role authenticated;create role service_role bypassrls;grant usage on schema public,auth to anon,authenticated,service_role;
 create table auth.users(id uuid primary key,email_confirmed_at timestamptz default now());
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;`);
 const ids=new Set([...backup.tables.academy_admins,...backup.tables.enrollments].map(x=>x.user_id));
 for(const id of ids)await db.query('insert into auth.users(id) values($1)',[id]);
 for(const table of Object.keys(backup.tables)){
  const cols=backup.columns.filter(c=>c.table_name===table);
  await db.exec('create table public.'+table+' ('+cols.map(c=>c.column_name+' '+c.data_type+(c.column_default?' default '+c.column_default:'')+(c.is_nullable==='NO'?' not null':'')).join(',')+')');
  for(const row of backup.tables[table]){const keys=Object.keys(row);await db.query('insert into public.'+table+'('+keys.join(',')+') values('+keys.map((_,i)=>'$'+(i+1)).join(',')+')',keys.map(k=>typeof row[k]==='object'&&row[k]!==null?JSON.stringify(row[k]):row[k]));}
 }
 for(const c of [...backup.constraints].sort((a,b)=>Number(a.definition.startsWith('FOREIGN'))-Number(b.definition.startsWith('FOREIGN'))))await db.exec('alter table public.'+c.table.replace(/^public\./,'')+' add constraint '+c.name+' '+c.definition);
 for(const f of backup.functions)await db.exec(f.definition);
 for(const row of backup.acl){if(row.rls)await db.exec('alter table public.'+row.table+' enable row level security');await db.exec('revoke all on public.'+row.table+' from public,anon,authenticated,service_role');}
 await db.exec('grant select on public.academy_courses,public.course_catalog,public.course_lessons to anon,authenticated;grant select on public.academy_admins to authenticated;grant select,insert on public.enrollments,public.lesson_progress to authenticated;');
 for(const p of backup.policies)await db.exec('create policy '+p.policyname+' on public.'+p.tablename+' as '+p.permissive+' for '+p.cmd+' to '+p.roles.join(',')+(p.qual?' using ('+p.qual+')':'')+(p.with_check?' with check ('+p.with_check+')':''));
 for(const f of backup.functions){await db.exec('revoke all on function public.'+f.name+'('+f.identity+') from public,anon,authenticated,service_role');if(f.acl?.some(x=>x.startsWith('authenticated=')))await db.exec('grant execute on function public.'+f.name+'('+f.identity+') to authenticated');}
 return db;
}
export async function role(db,name,id=''){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[id,JSON.stringify({sub:id,role:name})]);await db.exec('set role '+name);}
