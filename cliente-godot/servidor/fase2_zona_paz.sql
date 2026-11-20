-- Fase 2 — Zona de paz no servidor (20/11/2026). APLICAR SÓ NO PROJETO DE TESTES (valtheria-testes), nunca na produção.
-- Aditivo: cria game.zonas_paz e troca o corpo de public.game_save2 (mesma assinatura). Reverter: fase2_zona_paz_reverter.sql.
-- Regra (igual ao cliente, world.gd zona()): dentro de cidade (zone_at.safe) ou de área de paz cadastrada (povoados e
-- áreas de missão) ninguém morre: o HP salvo nunca fica abaixo de 1.

create table if not exists game.zonas_paz (
  id text primary key, name text not null, x real not null, z real not null, r real not null default 36);
alter table game.zonas_paz enable row level security;

create or replace function game.em_paz(px real, pz real) returns boolean
language plpgsql stable set search_path = '' as $$
declare zt jsonb;
begin
  zt := game.zone_at(px, pz);
  if zt is not null and coalesce((zt->>'safe')::boolean, false) then return true; end if;
  return exists (select 1 from game.zonas_paz a where sqrt((px - a.x)^2 + (pz - a.z)^2) < a.r);
end $$;

create or replace function public.game_save2(p_char uuid, p_x real, p_z real, p_hp real, p_mp real) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; gm boolean; mx jsonb; secs real; dist real; allow real; nx real; nz real; hp_novo real;
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
  hp_novo := greatest(0, least(p_hp, ((mx->>'hp')::real) * 1.15 + 50));
  if hp_novo < 1 and game.em_paz(nx, nz) then
    hp_novo := 1;  -- zona de paz: ninguém morre
  end if;
  update game.characters set x = nx, z = nz, pos_at = now(),
    hp = hp_novo,
    mp = greatest(0, least(p_mp, ((mx->>'mp')::real) * 1.15 + 50))
  where id = c.id;
  return jsonb_build_object('ok', true, 'paz', game.em_paz(nx, nz));
end $$;

revoke all on function game.em_paz(real, real) from public, anon, authenticated;
