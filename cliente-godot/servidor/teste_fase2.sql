-- Teste da Fase 2 dentro de uma transação desfeita no fim (não altera dados). Só no projeto de testes.
-- Troque <OWNER> e <CHAR_ID> por um personagem SEM GM.
begin;
create temp table tr(n int, t text, r text) on commit drop;
select set_config('request.jwt.claims','{"sub":"<OWNER>","role":"authenticated"}', true);
do $$
declare ch uuid := '<CHAR_ID>'; r jsonb; h real;
begin
  update game.characters set pos_at = now() - interval '5 seconds', x=1500, z=2550 where id = ch;   -- Vila Aurora
  r := public.game_save2(ch, 1501, 2551, 0, 10); select hp into h from game.characters where id = ch;
  insert into tr values (1, 'HP 0 dentro da cidade vira 1', r::text || ' hp=' || h);
  update game.characters set pos_at = now() - interval '5 seconds', x=1246, z=2458 where id = ch;   -- Campos do Amanhecer
  r := public.game_save2(ch, 1247, 2458, 0, 10); select hp into h from game.characters where id = ch;
  insert into tr values (2, 'HP 0 em zona de batalha continua 0', r::text || ' hp=' || h);
end $$;
select json_agg(tr order by n) from tr;
rollback;
