-- PEDIDO-CLAUDE 004 (22/11/2026) — limite de ritmo de abates. SÓ no projeto de testes valtheria-testes (mxhhqxvrryvqcsvokyla).
-- Aplicado como migração "pedido004_ritmo_abates". Reverter: pedido004_reverter.sql.
-- Regras: intervalo mínimo de 0,8 s entre abates e no máximo 70 por janela de 60 s, por personagem; GM isento.
-- Pedidos simultâneos: trava de linha (FOR UPDATE) por personagem; entram em fila e só 1 passa.
-- Recusa: devolve {"recusado": motivo}, grava em game.alertas (kind 'ritmo_abate') e não concede nada.
-- Também fecha a chamada direta, pelo cliente, das funções internas game_kill, game_kill2, game_kill3 e game_kill4
-- (game_kill3 aceitava nível e chefe escolhidos pelo cliente). O cliente de teste usa só game_kill5.
-- Limitação: reduz a repetição, mas não prova que o monstro existiu; isso exige ficha de nascimento de uso único (etapa futura).

create table if not exists game.ritmo_abate (
  char_id uuid primary key references game.characters(id) on delete cascade,
  ultimo timestamptz not null default '-infinity',
  janela_ini timestamptz not null default now(),
  n_janela int not null default 0,
  recusados int not null default 0
);
alter table game.ritmo_abate enable row level security;
revoke all on game.ritmo_abate from anon, authenticated;

create or replace function game.ritmo_ok(p_char uuid, p_fam text) returns text
language plpgsql security definer set search_path = '' as $$
declare r game.ritmo_abate; motivo text;
begin
  insert into game.ritmo_abate (char_id) values (p_char) on conflict do nothing;
  select * into r from game.ritmo_abate where char_id = p_char for update;
  if now() - r.janela_ini > interval '60 seconds' then
    r.janela_ini := now(); r.n_janela := 0;
  end if;
  if now() - r.ultimo < interval '800 milliseconds' then
    motivo := 'Abates rápidos demais';
  elsif r.n_janela >= 70 then
    motivo := 'Limite de abates por minuto';
  end if;
  if motivo is not null then
    update game.ritmo_abate set recusados = recusados + 1, janela_ini = r.janela_ini, n_janela = r.n_janela where char_id = p_char;
    insert into game.alertas (char_id, kind, data) values (p_char, 'ritmo_abate',
      jsonb_build_object('fam', p_fam, 'motivo', motivo, 'ms_desde_ultimo', round(extract(epoch from (now() - r.ultimo)) * 1000), 'n_janela', r.n_janela));
    return motivo;
  end if;
  update game.ritmo_abate set ultimo = now(), janela_ini = r.janela_ini, n_janela = r.n_janela + 1 where char_id = p_char;
  return null;
end $$;
revoke all on function game.ritmo_ok(uuid, text) from public, anon, authenticated;

-- game_kill5: trecho inserido no início (antes de qualquer recompensa)
--   perform game.ch(p_char);
--   if not game.gm_ok(game.ch(p_char)) then
--     declare mot text := game.ritmo_ok(p_char, p_fam);
--     begin
--       if mot is not null then return jsonb_build_object('recusado', mot); end if;
--     end;
--   end if;
-- (aplicado por substituição do texto da função no próprio banco; ver migração)

revoke execute on function public.game_kill(uuid, integer, boolean) from authenticated, anon, public;
revoke execute on function public.game_kill2(uuid, integer, boolean, text) from authenticated, anon, public;
revoke execute on function public.game_kill3(uuid, integer, boolean, text) from authenticated, anon, public;
revoke execute on function public.game_kill4(uuid, text, real, real, text) from authenticated, anon, public;
grant execute on function public.game_kill5(uuid, text, real, real, text) to authenticated;
