-- Teste das funções da Fase 1, feito dentro de uma transação desfeita no fim (não altera dados).
-- Troque o sub e o id pelo de um personagem SEM GM antes de rodar.
begin;
create temp table tr(n int, t text, r text) on commit drop;
select set_config('request.jwt.claims','{"sub":"<OWNER>","role":"authenticated"}', true);
do $$
declare ch uuid := '<CHAR_ID>'; r jsonb; e text;
begin
  update game.characters set pos_at = now() - interval '20 seconds', x=1250, z=2250 where id = ch;
  r := public.game_save2(ch, 1300, 2260, 999999, 999999); insert into tr values (1, 'HP falso limitado ao máximo', r::text);
  r := public.game_save2(ch, 2900, 300, 50, 50); insert into tr values (2, 'teleporte recusado', r::text);
  update game.characters set pos_at = now(), x=1250, z=2250, last_kill = now() - interval '5 seconds' where id = ch;
  r := public.game_kill4(ch, 'lobo', 1255, 2252, null); insert into tr values (3, 'lobo válido', r::text);
  update game.characters set last_kill = now() - interval '5 seconds' where id = ch;
  r := public.game_kill4(ch, 'dragao', 1255, 2252, null); insert into tr values (4, 'dragão na pradaria recusado', r::text);
  r := public.game_kill4(ch, 'rei_javali', 1255, 2252, null); insert into tr values (5, 'chefe sem ponto recusado', r::text);
  update game.characters set pos_at = now(), x=1246, z=2450, last_kill = now() - interval '5 seconds' where id = ch;
  r := public.game_kill4(ch, 'rei_javali', 1246, 2458, 'aurora:Campos do Amanhecer'); insert into tr values (6, 'chefe no ponto', (r - 'drops')::text);
  begin update game.characters set last_kill = now() - interval '5 seconds' where id = ch; r := public.game_kill4(ch, 'rei_javali', 1246, 2458, 'aurora:Campos do Amanhecer'); insert into tr values (7,'chefe repetido', r::text);
  exception when others then get stacked diagnostics e = message_text; insert into tr values (7,'chefe repetido recusado', e); end;
  r := public.game_quest_accept(ch, 'm01');
  begin r := public.game_quest_done2(ch, 'm01'); insert into tr values (8,'m01 sem abates', r::text);
  exception when others then get stacked diagnostics e = message_text; insert into tr values (8,'m01 sem abates recusada', e); end;
end $$;
select json_agg(tr order by n) from tr;
rollback;
