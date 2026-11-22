-- Desfaz o PEDIDO 004 no projeto de testes.
do $$ declare d text; begin
  d := pg_get_functiondef('public.game_kill5(uuid,text,real,real,text)'::regprocedure);
  d := replace(d, E'  perform game.ch(p_char);\n  if not game.gm_ok(game.ch(p_char)) then\n    declare mot text := game.ritmo_ok(p_char, p_fam);\n    begin\n      if mot is not null then return jsonb_build_object(''recusado'', mot); end if;\n    end;\n  end if;\n', '');
  execute d;
end $$;
drop function if exists game.ritmo_ok(uuid, text);
drop table if exists game.ritmo_abate;
grant execute on function public.game_kill(uuid, integer, boolean) to authenticated;
grant execute on function public.game_kill2(uuid, integer, boolean, text) to authenticated;
grant execute on function public.game_kill3(uuid, integer, boolean, text) to authenticated;
grant execute on function public.game_kill4(uuid, text, real, real, text) to authenticated;
