-- Fase 1 / Frente A — aplicado no Supabase em 14/11/2026 (migrações fase1_validacao_servidor, fase1_kill4_guarda_alertas, fase1_portais_save2).
-- Aditivo: cria tabelas game.cidades, game.mob_fams, game.alertas, game.portais, colunas novas em game.characters e as funções game_save2, game_kill4, game_quest_accept, game_quest_done2. Nada antigo foi alterado.
-- Fase 1 / Frente A — validação no servidor (aditivo: nada existente é alterado ou removido)
create table if not exists game.cidades (
  id text primary key, name text not null, x real not null, z real not null,
  band int not null, lvl_min int not null, lvl_max int not null,
  size text not null default 'media', special text not null default '', spots jsonb not null default '[]');
create table if not exists game.mob_fams (id text primary key, name text not null, band int not null, boss boolean not null default false);
create table if not exists game.alertas (id bigserial primary key, char_id uuid, kind text not null, data jsonb not null default '{}', created_at timestamptz not null default now());
alter table game.cidades enable row level security;
alter table game.mob_fams enable row level security;
alter table game.alertas enable row level security;
alter table game.characters add column if not exists pos_at timestamptz;
alter table game.characters add column if not exists kills jsonb not null default '{}';
alter table game.characters add column if not exists boss_cd jsonb not null default '{}';
alter table game.characters add column if not exists qbase jsonb not null default '{}';

-- zona (mesma regra do cliente: world.gd nearest_town + combat.gd _level_at)
create or replace function game.zone_at(px real, pz real) returns jsonb
language plpgsql stable set search_path = '' as $$
declare t game.cidades; best game.cidades; bd real := 1e9; d real; w real; wb real; real_d real; k real;
begin
  for t in select * from game.cidades loop
    w := case when t.size = 'capital' then 200 when t.size = 'grande' then 128 when t.special = 'submarina' then 84 when t.special = 'ilha' then 60 else 86 end;
    d := case when t.size in ('capital','grande') then greatest(abs(px - t.x), abs(pz - t.z)) else sqrt((px - t.x)^2 + (pz - t.z)^2) end;
    if d - w < bd then bd := d - w; best := t; wb := w; end if;
  end loop;
  if best.id is null then return null; end if;
  real_d := case when best.size in ('capital','grande') then greatest(abs(px - best.x), abs(pz - best.z)) else sqrt((px - best.x)^2 + (pz - best.z)^2) end;
  k := least(1, greatest(0, (real_d - (wb - 12)) / 450.0));
  return jsonb_build_object('id', best.id, 'band', best.band, 'safe', real_d < wb - 12, 'dist', real_d,
    'L', greatest(1, round(best.lvl_min + (best.lvl_max - best.lvl_min) * k)::int));
end $$;

-- vida e mana máximas (mesma fórmula de combat.gd recalc)
create or replace function game.max_hpmp(c game.characters) returns jsonb
language plpgsql stable set search_path = '' as $$
declare r game.races; cl game.classes; f real; s_hp real := 0; s_mp real := 0; v text; it game.items;
begin
  select * into r from game.races where race = c.race and type = c.type;
  select * into cl from game.classes where id = c.class_id;
  for v in select value from jsonb_each_text(coalesce(c.equipment, '{}'::jsonb)) loop
    select * into it from game.items where id = v;
    if found then s_hp := s_hp + coalesce((it.data->'stats'->>'hp')::real, 0); s_mp := s_mp + coalesce((it.data->'stats'->>'mp')::real, 0); end if;
  end loop;
  f := power(1.05, c.level - 1);
  return jsonb_build_object('hp', r.hp * f * (1 + 0.03 * coalesce(cl.rank, 0)) + s_hp, 'mp', r.mp * f * (1 + 0.02 * coalesce(cl.rank, 0)) + s_mp);
end $$;

-- salvar com validação: vida/mana até o máximo, deslocamento dentro da velocidade possível
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

-- abate validado: família, nível, chefe e posição decididos pelo servidor
create or replace function public.game_kill4(p_char uuid, p_fam text, p_x real, p_z real, p_spot text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; gm boolean; f game.mob_fams; z jsonb; secs real; lv int; sp jsonb; t game.cidades; key text; r jsonb;
begin
  c := game.ch(p_char);
  gm := game.gm_ok(c);
  select * into f from game.mob_fams where id = p_fam;
  if not found then raise exception 'Monstro desconhecido'; end if;
  secs := least(3600, extract(epoch from (now() - coalesce(c.pos_at, now() - interval '1 hour'))));
  if not gm and sqrt((p_x - c.x)^2 + (p_z - c.z)^2) > 70 + 14 * secs then
    insert into game.alertas (char_id, kind, data) values (c.id, 'abate_longe', jsonb_build_object('fam', p_fam, 'em', jsonb_build_array(p_x, p_z), 'pos', jsonb_build_array(c.x, c.z), 'segundos', round(secs)));
    raise exception 'Posição fora de sincronia';
  end if;
  z := game.zone_at(p_x, p_z);
  if z is null then raise exception 'Zona desconhecida'; end if;
  if not gm and (z->>'safe')::boolean then raise exception 'Não há monstros dentro da cidade'; end if;
  if not gm and f.band <> (z->>'band')::int then
    insert into game.alertas (char_id, kind, data) values (c.id, 'familia_fora', jsonb_build_object('fam', p_fam, 'band', f.band, 'zona', z));
    raise exception 'Este monstro não vive nesta região';
  end if;
  lv := (z->>'L')::int;
  if f.boss then
    key := null;
    if p_spot is not null then
      select * into t from game.cidades where id = split_part(p_spot, ':', 1);
      if found then
        select s into sp from jsonb_array_elements(t.spots) s where s->>'name' = substr(p_spot, length(t.id) + 2) limit 1;
        if sp is not null and sqrt((p_x - (sp->>'x')::real)^2 + (p_z - (sp->>'z')::real)^2) < 60 then
          key := p_spot; lv := (sp->>'lvl')::int;
        end if;
      end if;
    end if;
    if key is null and not gm then
      insert into game.alertas (char_id, kind, data) values (c.id, 'chefe_sem_ponto', jsonb_build_object('fam', p_fam, 'spot', p_spot, 'em', jsonb_build_array(p_x, p_z)));
      raise exception 'Chefe fora do seu ponto de caça';
    end if;
    if key is not null and not gm and coalesce((c.boss_cd->>key)::timestamptz, '-infinity') > now() - interval '290 seconds' then
      raise exception 'Este chefe ainda não voltou';
    end if;
    if key is not null then update game.characters set boss_cd = boss_cd || jsonb_build_object(key, now()) where id = c.id; end if;
  end if;
  r := public.game_kill3(p_char, lv, f.boss, p_fam);
  update game.characters set kills = kills || jsonb_build_object(p_fam, coalesce((kills->>p_fam)::int, 0) + 1) where id = c.id;
  return r || jsonb_build_object('L', lv);
end $$;

-- missões: aceitar marca a contagem de partida; concluir confere os abates reais e depois usa a regra antiga de recompensa
create or replace function public.game_quest_accept(p_char uuid, p_quest text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; qq game.quests; fam text;
begin
  c := game.ch(p_char);
  select * into qq from game.quests where id = p_quest;
  if not found then raise exception 'Missão inexistente'; end if;
  fam := qq.goal->>'fam';
  update game.characters set qbase = qbase || jsonb_build_object(p_quest, jsonb_build_object('n', coalesce((kills->>fam)::int, 0), 'at', now())) where id = c.id;
  return jsonb_build_object('ok', true, 'base', coalesce((c.kills->>fam)::int, 0));
end $$;

create or replace function public.game_quest_done2(p_char uuid, p_quest text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c game.characters; qq game.quests; typ text; fam text; need int; have int; t game.cidades; z jsonb;
begin
  c := game.ch(p_char);
  select * into qq from game.quests where id = p_quest;
  if not found then raise exception 'Missão inexistente'; end if;
  typ := qq.goal->>'type'; fam := qq.goal->>'fam';
  if typ in ('kill', 'boss') then
    if not (c.qbase ? p_quest) then raise exception 'Aceite a missão primeiro'; end if;
    need := case when typ = 'boss' then 1 else coalesce((qq.goal->>'n')::int, 1) end;
    have := coalesce((c.kills->>fam)::int, 0) - coalesce((c.qbase->p_quest->>'n')::int, 0);
    if have < need then raise exception 'Faltam % de %', need - have, need; end if;
  elsif typ = 'reach' then
    select * into t from game.cidades where id = qq.goal->>'town';
    if found then
      z := game.zone_at(c.x, c.z);
      if z->>'id' <> t.id or (z->>'dist')::real > 220 then raise exception 'Chegue a %', t.name; end if;
    end if;
  end if;
  update game.characters set qbase = qbase - p_quest where id = c.id;
  return public.game_quest_done(p_char, p_quest);
end $$;

revoke all on function public.game_save2(uuid, real, real, real, real) from public, anon;
revoke all on function public.game_kill4(uuid, text, real, real, text) from public, anon;
revoke all on function public.game_quest_accept(uuid, text) from public, anon;
revoke all on function public.game_quest_done2(uuid, text) from public, anon;
grant execute on function public.game_save2(uuid, real, real, real, real) to authenticated;
grant execute on function public.game_kill4(uuid, text, real, real, text) to authenticated;
grant execute on function public.game_quest_accept(uuid, text) to authenticated;
grant execute on function public.game_quest_done2(uuid, text) to authenticated;
revoke all on function game.zone_at(real, real) from public, anon, authenticated;
revoke all on function game.max_hpmp(game.characters) from public, anon, authenticated;

insert into game.cidades (id,name,x,z,band,lvl_min,lvl_max,size,special,spots) values
('aurora','Vila Aurora',1500,2550,0,1,19,'media','','[{"name": "Campos do Amanhecer", "x": 1246, "z": 2458, "lvl": 10}, {"name": "Bosque dos Javalis", "x": 1734, "z": 2415, "lvl": 10}]'::jsonb),
('dourado','Vale Dourado',650,2050,1,20,39,'grande','','[{"name": "Planície dos Bandidos", "x": 515, "z": 2284, "lvl": 30}, {"name": "Ninho das Aranhas", "x": 558, "z": 1796, "lvl": 30}]'::jsonb),
('pedra','Pedra Alta',2350,1950,2,40,51,'media','','[{"name": "Pedreira dos Golens", "x": 2485, "z": 2184, "lvl": 46}, {"name": "Cripta Esquecida", "x": 2485, "z": 1716, "lvl": 46}]'::jsonb),
('sylvar','Sylvar',1500,1450,3,52,60,'media','arvore','[{"name": "Coração da Mata", "x": 1754, "z": 1542, "lvl": 56}, {"name": "Vale Espectral", "x": 1246, "z": 1542, "lvl": 56}]'::jsonb),
('rubra','Cidadela Rubra',650,800,4,61,75,'grande','','[{"name": "Deserto Escarlate", "x": 500, "z": 917, "lvl": 68}, {"name": "Fenda Demoníaca", "x": 697, "z": 534, "lvl": 68}]'::jsonb),
('celeste','Bastião Celeste',2350,650,5,76,80,'media','montanha','[{"name": "Ninho dos Dragões", "x": 2303, "z": 916, "lvl": 78}, {"name": "Ruínas de Aeternum", "x": 2176, "z": 443, "lvl": 78}]'::jsonb),
('presas','Clã das Presas',1000,1500,1,20,39,'media','','[]'::jsonb),
('umbraval','Umbraval',2150,1300,3,52,60,'media','caverna','[]'::jsonb),
('pico','Pico do Dragão',1450,420,4,61,75,'media','montanha','[]'::jsonb),
('noctis','Castelo Noctis',2720,1150,5,76,80,'grande','','[]'::jsonb),
('glacial','Fortaleza Glacial',330,330,5,76,80,'media','frio','[]'::jsonb),
('capital','Valtheria Real',1500,1985,0,1,30,'capital','','[]'::jsonb),
('porto','Porto Maré-Alta',2390,2440,2,40,51,'grande','praia','[]'::jsonb),
('coralis','Ilha de Coralis',2560,2790,2,40,51,'media','ilha','[]'::jsonb),
('abissal','Abissália',2290,2800,0,1,19,'media','submarina','[]'::jsonb)
on conflict (id) do update set name=excluded.name,x=excluded.x,z=excluded.z,band=excluded.band,lvl_min=excluded.lvl_min,lvl_max=excluded.lvl_max,size=excluded.size,special=excluded.special,spots=excluded.spots;
insert into game.mob_fams (id,name,band,boss) values
('javali','Javali Selvagem',0,false),
('lobo','Lobo Cinzento',0,false),
('rei_javali','Rei Javali',0,true),
('bandido','Orc Bandido',1,false),
('aranha','Aranha Gigante',1,false),
('rainha','Rainha Aracnídea',1,true),
('golem','Golem de Pedra',2,false),
('esqueleto','Esqueleto Guerreiro',2,false),
('golem_anc','Golem Ancestral',2,true),
('ent','Ent Corrompido',3,false),
('lobo_esp','Lobo Espectral',3,false),
('ent_mil','Ent Milenar',3,true),
('demonio','Demônio Rubro',4,false),
('lagarto','Lagarto Guerreiro',4,false),
('senhor_dem','Senhor Demônio',4,true),
('dragonete','Dragonete',5,false),
('caido','Cavaleiro Caído',5,false),
('dragao','Dragão Celeste',5,true)
on conflict (id) do update set name=excluded.name,band=excluded.band,boss=excluded.boss;
