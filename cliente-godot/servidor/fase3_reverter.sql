-- Desfaz a fase 3 no projeto de TESTES
drop function if exists public.game_kill5(uuid, text, real, real, text);
drop function if exists public.game_party_info(uuid);
drop function if exists public.game_party_loot(uuid, text);
drop function if exists public.game_party_kick(uuid, uuid);
drop function if exists public.game_party_leave(uuid);
drop function if exists public.game_party_answer(uuid, uuid, boolean);
drop function if exists public.game_party_invite(uuid, text);
drop function if exists public.game_skill_learn(uuid, text);
drop function if exists public.game_class_change2(uuid, text);
drop function if exists game.meu_grupo(uuid);
drop function if exists game.xp_add(uuid, bigint);
drop function if exists game.ph_monstro(int, boolean);
drop function if exists game.cadeia_v2(text);
drop function if exists game.classe_v2(game.characters);
delete from game.classes c where c.id like '%\_2b' or c.id like '%\_3b';  -- caminhos B (sem personagens nelas)
drop table if exists game.party_invites, game.party_members, game.parties, game.skills_v2, game.classes_v2;
alter table game.characters drop column if exists ph, drop column if exists skills;
