-- Fase 3 (SÓ no projeto de TESTES mxhhqxvrryvqcsvokyla): habilidades com PH, troca de classe pelos dois caminhos
-- e grupo no servidor (convite, saída, expulsão, divisão de experiência, PH, aurum e itens).
-- Ordem: este arquivo, fase3_dados_classes.sql, fase3_dados_habilidades.sql (dados de data/classes_v2.json).
-- Aplicado no projeto de testes em 21/11/2026 e conferido com dois personagens numa transação desfeita no fim.
-- Reverter: fase3_reverter.sql

-- ---------------------------------------------------------------- tabelas
create table if not exists game.classes_v2 (
  id text primary key, nome text not null, rank int not null, pai text, raca text not null,
  arquetipo text, elemento text, nivel int not null, caminho text
);
create table if not exists game.skills_v2 (
  id text primary key, class_id text not null references game.classes_v2(id) on delete cascade,
  nome text, ativa boolean not null, nivel_max int not null, rank int not null default 0, livro boolean not null default false,
  tabela jsonb not null  -- [{"n":1,"lv":20,"ph":4220,"au":2530}, ...]
);
create index if not exists skills_v2_class on game.skills_v2(class_id);
alter table game.characters add column if not exists ph bigint not null default 0;
alter table game.characters add column if not exists skills jsonb not null default '{}'::jsonb;

create table if not exists game.parties (
  id uuid primary key default gen_random_uuid(), leader uuid not null references game.characters(id) on delete cascade,
  loot text not null default 'rodizio', loot_idx int not null default 0, created_at timestamptz not null default now()
);
create table if not exists game.party_members (
  char_id uuid primary key references game.characters(id) on delete cascade,
  party_id uuid not null references game.parties(id) on delete cascade, joined_at timestamptz not null default now()
);
create index if not exists party_members_party on game.party_members(party_id);
create table if not exists game.party_invites (
  party_id uuid not null references game.parties(id) on delete cascade, char_id uuid not null references game.characters(id) on delete cascade,
  from_char uuid not null references game.characters(id) on delete cascade, created_at timestamptz not null default now(),
  primary key (party_id, char_id)
);
-- só as funções (security definer) mexem nessas tabelas
alter table game.classes_v2 enable row level security;
alter table game.skills_v2 enable row level security;
alter table game.parties enable row level security;
alter table game.party_members enable row level security;
alter table game.party_invites enable row level security;

-- ---------------------------------------------------------------- classes
-- classe atual no banco novo (sem classe: a base da raça)
create or replace function game.classe_v2(c game.characters) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce((select id from game.classes_v2 where id = c.class_id),
                  (select id from game.classes_v2 where rank = 0 and raca = c.race order by id limit 1));
$$;

-- caminho da base até a classe (as habilidades se acumulam)
create or replace function game.cadeia_v2(p_class text) returns text[]
language sql stable security definer set search_path = '' as $$
  with recursive k(id, pai, d) as (
    select id, pai, 0 from game.classes_v2 where id = p_class
    union all select c.id, c.pai, k.d + 1 from game.classes_v2 c join k on c.id = k.pai where k.d < 6)
  select coalesce(array_agg(id order by d desc), '{}') from k;
$$;

create or replace function public.game_class_change2(p_char uuid, p_class text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; nc game.classes_v2; atual text;
begin
  c := game.ch(p_char);
  select * into nc from game.classes_v2 where id = p_class;
  if not found then raise exception 'Classe inexistente'; end if;
  atual := game.classe_v2(c);
  if nc.pai is distinct from atual then raise exception 'Essa classe não continua a sua classe atual'; end if;
  if nc.raca <> c.race then raise exception 'Essa classe é de outra raça'; end if;
  if c.level < nc.nivel then raise exception 'Requer nível %', nc.nivel; end if;
  -- cidade: zona segura do mapa novo (capital e vilas) ou cidade antiga
  if not (coalesce((game.zone_at(c.x, c.z) ->> 'safe')::boolean, false) or game.in_safe(c.x, c.z)) then
    raise exception 'Fale com o Mestre de Classes em uma cidade';
  end if;
  update game.characters set class_id = nc.id where id = c.id;
  insert into game.chat (name, is_gm, kind, msg) values ('Sistema', true, 'sistema', c.name || ' tornou-se ' || nc.nome || '!');
  return jsonb_build_object('classe', nc.id, 'nome', nc.nome);
end $$;

-- ---------------------------------------------------------------- habilidades
-- aprender ou subir um nível: precisa ser da sua classe (ou das anteriores), ter o nível de personagem, PH e aurum
create or replace function public.game_skill_learn(p_char uuid, p_skill text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; s game.skills_v2; atual int; prox jsonb;
begin
  c := game.ch(p_char);
  select * into s from game.skills_v2 where id = p_skill;
  if not found then raise exception 'Habilidade inexistente'; end if;
  if not (s.class_id = any (game.cadeia_v2(game.classe_v2(c)))) then raise exception 'Essa habilidade não é da sua classe'; end if;
  atual := coalesce((c.skills ->> s.id)::int, 0);
  if atual >= s.nivel_max then raise exception 'Habilidade já está no nível máximo'; end if;
  prox := s.tabela -> atual;
  if c.level < (prox ->> 'lv')::int then raise exception 'Requer nível %', (prox ->> 'lv'); end if;
  if c.ph < (prox ->> 'ph')::bigint then raise exception 'Faltam % PH', (prox ->> 'ph')::bigint - c.ph; end if;
  if c.aurum < (prox ->> 'au')::bigint then raise exception 'Faltam % de aurum', (prox ->> 'au')::bigint - c.aurum; end if;
  if s.livro and atual = 0 and exists (select 1 from game.items where id = 'tomo_tecnica') then
    if not exists (select 1 from game.inventory where char_id = c.id and item_id = 'tomo_tecnica' and qty > 0) then
      raise exception 'Precisa de um Tomo de Técnica';
    end if;
    perform game.inv_take(c.id, 'tomo_tecnica', 1);
  end if;
  update game.characters set ph = ph - (prox ->> 'ph')::bigint, aurum = aurum - (prox ->> 'au')::bigint,
    skills = skills || jsonb_build_object(s.id, atual + 1) where id = c.id;
  return jsonb_build_object('skill', s.id, 'nivel', atual + 1, 'ph', c.ph - (prox ->> 'ph')::bigint, 'aurum', c.aurum - (prox ->> 'au')::bigint);
end $$;

-- PH por monstro (independe da experiência): cresce com o nível do monstro; chefe vale 8
create or replace function game.ph_monstro(lv int, boss boolean) returns bigint
language sql immutable set search_path = '' as $$
  select (ceil(3 * power(greatest(lv, 1), 1.35)) * case when boss then 8 else 1 end)::bigint;
$$;

-- soma experiência sem tirar nível (usada para os membros do grupo)
create or replace function game.xp_add(p_id uuid, p_xp bigint) returns int
language plpgsql security definer set search_path = '' as $$
declare c game.characters; ups int := 0;
begin
  select * into c from game.characters where id = p_id for update;
  c.xp := greatest(0, c.xp + p_xp);
  while c.level < 80 and c.xp >= game.need(c.level) loop c.xp := c.xp - game.need(c.level); c.level := c.level + 1; ups := ups + 1; end loop;
  if c.level >= 80 then c.xp := least(c.xp, game.need(80)); end if;
  update game.characters set xp = c.xp, level = c.level where id = p_id;
  return ups;
end $$;

-- ---------------------------------------------------------------- grupo
create or replace function game.meu_grupo(p_char uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select party_id from game.party_members where char_id = p_char;
$$;

create or replace function public.game_party_invite(p_char uuid, p_name text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; alvo game.characters; g uuid; n int;
begin
  c := game.ch(p_char);
  select * into alvo from game.characters where lower(name) = lower(trim(p_name));
  if not found then raise exception 'Personagem não encontrado'; end if;
  if alvo.id = c.id then raise exception 'Você não pode se convidar'; end if;
  if game.meu_grupo(alvo.id) is not null then raise exception '% já está em um grupo', alvo.name; end if;
  g := game.meu_grupo(c.id);
  if g is null then
    insert into game.parties (leader) values (c.id) returning id into g;
    insert into game.party_members (char_id, party_id) values (c.id, g);
  elsif (select leader from game.parties where id = g) <> c.id then
    raise exception 'Só o líder convida';
  end if;
  select count(*) into n from game.party_members where party_id = g;
  if n >= 9 then raise exception 'O grupo já tem 9 membros'; end if;
  delete from game.party_invites where created_at < now() - interval '2 minutes';
  insert into game.party_invites (party_id, char_id, from_char) values (g, alvo.id, c.id)
    on conflict (party_id, char_id) do update set created_at = now();
  return jsonb_build_object('grupo', g, 'convidado', alvo.id, 'nome', alvo.name);
end $$;

create or replace function public.game_party_answer(p_char uuid, p_party uuid, p_accept boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; n int;
begin
  c := game.ch(p_char);
  if not exists (select 1 from game.party_invites where party_id = p_party and char_id = c.id and created_at > now() - interval '2 minutes') then
    raise exception 'Convite expirado';
  end if;
  delete from game.party_invites where char_id = c.id;
  if not p_accept then return jsonb_build_object('ok', true); end if;
  if game.meu_grupo(c.id) is not null then raise exception 'Você já está em um grupo'; end if;
  select count(*) into n from game.party_members where party_id = p_party;
  if n >= 9 then raise exception 'O grupo está cheio'; end if;
  insert into game.party_members (char_id, party_id) values (c.id, p_party);
  return public.game_party_info(p_char);
end $$;

create or replace function public.game_party_leave(p_char uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; g uuid; novo uuid;
begin
  c := game.ch(p_char);
  g := game.meu_grupo(c.id);
  if g is null then return jsonb_build_object('ok', true); end if;
  delete from game.party_members where char_id = c.id;
  select char_id into novo from game.party_members where party_id = g order by joined_at limit 1;
  if novo is null or (select count(*) from game.party_members where party_id = g) < 2 then
    delete from game.parties where id = g;  -- ninguém sozinho fica em grupo
  elsif (select leader from game.parties where id = g) = c.id then
    update game.parties set leader = novo where id = g;
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.game_party_kick(p_char uuid, p_target uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; g uuid;
begin
  c := game.ch(p_char);
  g := game.meu_grupo(c.id);
  if g is null or (select leader from game.parties where id = g) <> c.id then raise exception 'Só o líder expulsa'; end if;
  if p_target = c.id then raise exception 'Use sair do grupo'; end if;
  delete from game.party_members where char_id = p_target and party_id = g;
  if (select count(*) from game.party_members where party_id = g) < 2 then delete from game.parties where id = g; end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.game_party_loot(p_char uuid, p_mode text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; g uuid;
begin
  c := game.ch(p_char);
  g := game.meu_grupo(c.id);
  if g is null or (select leader from game.parties where id = g) <> c.id then raise exception 'Só o líder escolhe a divisão'; end if;
  if p_mode not in ('livre', 'rodizio') then raise exception 'Modo inválido'; end if;
  update game.parties set loot = p_mode where id = g;
  return jsonb_build_object('loot', p_mode);
end $$;

create or replace function public.game_party_info(p_char uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; g uuid;
begin
  c := game.ch(p_char);
  g := game.meu_grupo(c.id);
  return jsonb_build_object(
    'grupo', g,
    'lider', (select leader from game.parties where id = g),
    'loot', (select loot from game.parties where id = g),
    'membros', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name, 'level', m.level, 'class_id', m.class_id, 'race', m.race,
        'hp', m.hp, 'mp', m.mp, 'x', m.x, 'z', m.z) order by pm.joined_at)
      from game.party_members pm join game.characters m on m.id = pm.char_id where pm.party_id = g), '[]'::jsonb),
    'convites', coalesce((select jsonb_agg(jsonb_build_object('grupo', i.party_id, 'de', f.name))
      from game.party_invites i join game.characters f on f.id = i.from_char
      where i.char_id = c.id and i.created_at > now() - interval '2 minutes'), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------- abate com PH e divisão no grupo
-- Chama o abate validado (game_kill4). Sozinho: ganha PH. Em grupo, entre os membros a até 60 m que salvaram a posição
-- nos últimos 2 minutos: experiência e PH somam +15% por membro extra e são divididos pelo peso do nível;
-- o aurum é dividido em partes iguais; no modo rodízio os itens vão, a cada abate, para o próximo membro.
create or replace function public.game_kill5(p_char uuid, p_fam text, p_x real, p_z real, p_spot text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r jsonb; c game.characters; g uuid; pt game.parties; perto uuid[]; n int; soma numeric; xp_total numeric; ph_total numeric;
        m record; parte numeric; dono uuid; k text; q int; au_parte bigint; lv int; boss boolean; ups int; divisao jsonb := '[]'::jsonb;
begin
  r := public.game_kill4(p_char, p_fam, p_x, p_z, p_spot);
  if r ? 'recusado' then return r; end if;
  select * into c from game.characters where id = p_char;
  lv := coalesce((r ->> 'L')::int, c.level);
  boss := coalesce((select f.boss from game.mob_fams f where f.id = p_fam), false);
  g := game.meu_grupo(c.id);
  if g is not null then
    select array_agg(pm.char_id order by pm.joined_at) into perto
      from game.party_members pm join game.characters o on o.id = pm.char_id
     where pm.party_id = g and (o.id = c.id or (sqrt((o.x - p_x)^2 + (o.z - p_z)^2) <= 60 and o.pos_at > now() - interval '2 minutes'));
  end if;
  n := coalesce(array_length(perto, 1), 1);
  if n <= 1 then
    update game.characters set ph = ph + game.ph_monstro(lv, boss) where id = c.id;
    return r || jsonb_build_object('ph', game.ph_monstro(lv, boss));
  end if;
  select * into pt from game.parties where id = g;
  select sum(level) into soma from game.characters where id = any (perto);
  xp_total := (r ->> 'xp')::numeric * (1 + 0.15 * (n - 1));
  ph_total := game.ph_monstro(lv, boss) * (1 + 0.15 * (n - 1));
  au_parte := ((r ->> 'aurum')::bigint / n);
  -- quem matou já recebeu a experiência e o aurum inteiros: acerta a parte dele
  for m in select id, level, name from game.characters where id = any (perto) loop
    parte := xp_total * m.level / soma;
    if m.id = c.id then
      ups := game.xp_add(m.id, round(parte - (r ->> 'xp')::numeric)::bigint);
      update game.characters set aurum = aurum - ((r ->> 'aurum')::bigint - au_parte), ph = ph + round(ph_total * m.level / soma) where id = m.id;
    else
      ups := game.xp_add(m.id, round(parte)::bigint);
      update game.characters set aurum = aurum + au_parte, ph = ph + round(ph_total * m.level / soma) where id = m.id;
    end if;
    divisao := divisao || jsonb_build_object('id', m.id, 'nome', m.name, 'xp', round(parte), 'ph', round(ph_total * m.level / soma), 'aurum', au_parte, 'subiu', ups);
  end loop;
  -- itens no rodízio
  if pt.loot = 'rodizio' and r ? 'drops' then
    dono := perto[1 + (pt.loot_idx % n)];
    update game.parties set loot_idx = loot_idx + 1 where id = g;
    if dono <> c.id then
      for k, q in select key, value::int from jsonb_each_text(r -> 'drops') loop
        if exists (select 1 from game.inventory where char_id = c.id and item_id = k and qty >= q) then
          perform game.inv_take(c.id, k, q);
          perform game.inv_add(dono, k, q);
        end if;
      end loop;
    end if;
    r := r || jsonb_build_object('itens_para', dono, 'itens_para_nome', (select name from game.characters where id = dono));
  end if;
  select xp, level into c.xp, c.level from game.characters where id = c.id;
  return r || jsonb_build_object('grupo', divisao, 'xp', round(xp_total * c.level / soma), 'xp_now', c.xp, 'level', c.level,
    'aurum', au_parte, 'ph', round(ph_total * c.level / soma));
end $$;

-- game_state devolve também PH e habilidades (já estão em characters; to_jsonb(c) leva as colunas novas)

grant execute on function public.game_class_change2(uuid, text), public.game_skill_learn(uuid, text), public.game_party_invite(uuid, text),
  public.game_party_answer(uuid, uuid, boolean), public.game_party_leave(uuid), public.game_party_kick(uuid, uuid), public.game_party_loot(uuid, text),
  public.game_party_info(uuid), public.game_kill5(uuid, text, real, real, text) to authenticated;
revoke execute on function public.game_class_change2(uuid, text), public.game_skill_learn(uuid, text), public.game_party_invite(uuid, text),
  public.game_party_answer(uuid, uuid, boolean), public.game_party_leave(uuid), public.game_party_kick(uuid, uuid), public.game_party_loot(uuid, text),
  public.game_party_info(uuid), public.game_kill5(uuid, text, real, real, text) from anon, public;
revoke execute on function game.xp_add(uuid, bigint) from anon, authenticated, public;
