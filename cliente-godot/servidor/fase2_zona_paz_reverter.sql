-- Reverte a Fase 2 (zona de paz no servidor): volta game_save2 da Fase 1 e remove o que foi criado.
create or replace function public.game_save2(p_char uuid, p_x real, p_z real, p_hp real, p_mp real) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; gm boolean; mx jsonb; secs real; dist real; allow real; nx real; nz real;
begin
  c := game.ch(p_char);
  gm := game.gm_ok(c);
  nx := greatest(5, least(2995, p_x)); nz := greatest(5, least(2995, p_z));
  secs := least(3600, extract(epoch from (now() - coalesce(c.pos_at, now() - interval '1 hour'))));
  dist := sqrt((nx - c.x)^2 + (nz - c.z)^2);
  allow := 40 + 14 * secs;
  if not gm and dist > allow then
    insert into game.alertas (char_id, kind, data) values (c.id, 'movimento', jsonb_build_object('de', jsonb_build_array(c.x, c.z), 'para', jsonb_build_array(nx, nz), 'dist', round(dist), 'segundos', round(secs)));
    update game.characters set pos_at = now() where id = c.id;
    return jsonb_build_object('ok', false, 'motivo', 'movimento', 'x', c.x, 'z', c.z);
  end if;
  mx := game.max_hpmp(c);
  update game.characters set x = nx, z = nz, pos_at = now(),
    hp = greatest(0, least(p_hp, ((mx->>'hp')::real) * 1.15 + 50)),
    mp = greatest(0, least(p_mp, ((mx->>'mp')::real) * 1.15 + 50))
  where id = c.id;
  return jsonb_build_object('ok', true);
end $$;

drop function if exists game.em_paz(real, real);
drop table if exists game.zonas_paz;
