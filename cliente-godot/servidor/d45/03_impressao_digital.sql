with
tb as (select c.oid, c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='game' and c.relkind='r' and c.relname not like 'bkp_%'),
conteudo as (select relname, (xpath('/row/h/text()', query_to_xml(format($q$select count(*)||':'||coalesce(md5(string_agg(m,',' order by m)),'-') h from (select md5((to_jsonb(r)-'owner'-'since')::text) m from game.%I r) s$q$, relname), false, true, '')))[1]::text h from tb where relname in ('races','classes','items','recipes','shop','quests','boss_drops','nodes','towns','teleports','castles','cidades','mob_fams','portais')),
fn as (select p.proname||'('||pg_get_function_identity_arguments(p.oid)||')' k, md5(pg_get_functiondef(p.oid)) d, n.nspname s from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('game','public') and not exists (select 1 from pg_depend dp where dp.objid=p.oid and dp.deptype='e')),
pol as (select schemaname||'.'||tablename||'.'||policyname||':'||cmd||':'||coalesce(qual,'')||':'||coalesce(with_check,'') k from pg_policies where schemaname in ('game','public')),
rls as (select relname||':'||c.relrowsecurity k from pg_class c join tb using(relname)),
trg as (select c.relname||'.'||t.tgname||':'||md5(pg_get_triggerdef(t.oid)) k from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where not t.tgisinternal and (n.nspname='game' or (n.nspname='auth' and t.tgname like '%game%'))),
pub as (select pubname||':'||schemaname||'.'||tablename k from pg_publication_tables where schemaname in ('game','public')),
fk as (select c.conname, (xpath('/row/n/text()', query_to_xml(format('select count(*) n from %s t where %s is not null and not exists (select 1 from %s r where r.%I = t.%I)', c.conrelid::regclass, a.attname, c.confrelid::regclass, af.attname, a.attname), false, true, '')))[1]::text::int orfaos
  from pg_constraint c join pg_namespace n on n.oid=c.connamespace join pg_attribute a on a.attrelid=c.conrelid and a.attnum=c.conkey[1] join pg_attribute af on af.attrelid=c.confrelid and af.attnum=c.confkey[1]
  where c.contype='f' and n.nspname='game' and array_length(c.conkey,1)=1)
select json_build_object(
 'tabelas', (select count(*) from tb),
 'conteudo', (select json_object_agg(relname,h order by relname) from conteudo),
 'funcoes', (select count(*) from fn), 'funcoes_md5', (select md5(string_agg(k||d,',' order by k)) from fn),
 'politicas', (select count(*) from pol), 'politicas_md5', (select md5(string_agg(k,',' order by k)) from pol),
 'rls_md5', (select md5(string_agg(k,',' order by k)) from rls), 'rls_on', (select count(*) from pg_class c join tb using(relname) where c.relrowsecurity),
 'gatilhos', (select string_agg(split_part(k,':',1),',' order by k) from trg), 'gatilhos_md5', (select md5(string_agg(k,',' order by k)) from trg),
 'publicacao', (select string_agg(k,',' order by k) from pub),
 'fks', (select count(*) from fk), 'fk_orfaos', (select coalesce(sum(orfaos),0) from fk)
)::text as impressao;
