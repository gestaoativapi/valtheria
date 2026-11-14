-- PROCEDIMENTO DE REVERSÃO DA FASE 1 (NÃO EXECUTAR SEM AUTORIZAÇÃO DO ROBSON)
-- Desfaz só o que a Fase 1 criou. As funções antigas (game_save, game_kill2, game_kill3, game_quest_done...) nunca foram alteradas.
-- 1) Jogo: voltar o cliente para a versão anterior (git revert do commit da Fase 1 na main, ou baixar a release anterior).
-- 2) Servidor:
drop function if exists public.game_quest_done2(uuid, text);
drop function if exists public.game_quest_accept(uuid, text);
drop function if exists public.game_kill4(uuid, text, real, real, text);
drop function if exists public.game_save2(uuid, real, real, real, real);
drop function if exists game.max_hpmp(game.characters);
drop function if exists game.zone_at(real, real);
-- 3) Tabelas novas (os dados nelas são só de apoio: cidades, monstros, portais e alertas)
-- drop table if exists game.portais; drop table if exists game.alertas; drop table if exists game.mob_fams; drop table if exists game.cidades;
-- 4) Colunas novas em characters (pos_at, kills, boss_cd, qbase): podem ficar; nenhuma função antiga as usa.
-- 5) Se algum personagem precisar voltar ao estado de 14/11/2026 (cópia game.bkp_20261114_*), por exemplo:
-- update game.characters c set level=b.level, xp=b.xp, aurum=b.aurum, x=b.x, z=b.z, hp=b.hp, mp=b.mp, quests=b.quests from game.bkp_20261114_characters b where b.id=c.id and c.id='<ID>';
