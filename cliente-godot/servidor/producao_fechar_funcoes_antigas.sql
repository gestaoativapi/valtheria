-- PRODUÇÃO (projeto irpzdghikvoezfeodyiq) — correção segura aprovada pelo Robson em 23/11/2026.
-- Fecha ao cliente só as duas funções antigas de recompensa que NENHUM jogo usa hoje:
--   game_kill  e  game_kill2.
-- NÃO fecha game_kill3 nem game_pvp: a versão web (backend.js) ainda chama as duas.
--   Elas só devem ser fechadas quando a web sair do ar.
-- O cliente nativo oficial usa game_kill4, que continua igual.
-- Como aplicar: Supabase > projeto de PRODUÇÃO > SQL Editor > colar tudo > Run.
-- Para desfazer: troque "revoke ... from" por "grant ... to authenticated" nas duas linhas.

revoke execute on function public.game_kill(uuid, integer, boolean) from authenticated, anon, public;
revoke execute on function public.game_kill2(uuid, integer, boolean, text) from authenticated, anon, public;

-- conferência (deve mostrar false nas duas primeiras e true nas outras):
select p.proname, has_function_privilege('authenticated', p.oid, 'execute') liberada_ao_jogo
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('game_kill', 'game_kill2', 'game_kill3', 'game_kill4', 'game_pvp')
 order by 1;
