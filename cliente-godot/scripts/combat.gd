extends Node3D
const Criatura = preload("res://scripts/criatura.gd")
const CorpoChefe := preload("res://scripts/corpo_chefe.gd")
const HabChefe := preload("res://scripts/habilidades_chefe.gd")
const VisualMonstros := preload("res://scripts/visual_monstros.gd")
const Perfil := preload("res://scripts/perfil.gd")
# Combate: atributos do personagem (mesma fórmula do jogo web), monstros, alvo, ataque automático, habilidades, XP e morte.

const Character = preload("res://scripts/character.gd")
const FX = preload("res://scripts/fx.gd")

signal message(text: String)

var main: Node3D
var world: Node3D
var info: Dictionary
var rng := RandomNumberGenerator.new()
var active := false
var mobs: Array = []
var ruin_warned := {}
var target = null
var auto := false
var st := {}
var hp := 100.0
var mp := 50.0
var skills: Array = []
var cds: Array = []
var buffs: Array = []  # {"k", "v", "until"}
var shield := 0.0
var shield_until := 0.0
var next_atk := 0.0
var pending: Array = []  # golpes agendados: {"t", "mob", "dmg", "crit"}
var dead := false
var dead_t := 0.0
var combat_until := 0.0
var spawn_t := 0.0
var sync_t := 0.0
var swing := 0
var my_elem := ""
var debuffs := {}  # efeitos dos chefes no jogador: tipo -> [valor, até]
var boss_next := {}  # ponto de caça -> hora em que o chefe pode voltar
var pb := {}  # bônus das passivas de equipamento, buff e grupo (Passivas)
var casting := {}  # conjuração em andamento: {"i", "ini", "fim", "pos", "alvo"}
var vel_cl := {"vel_ataque": 333.0, "vel_conjuracao": 333.0}  # velocidades da classe (classes_v2)


func setup(m: Node3D) -> void:
	main = m
	world = m.world
	info = world.info
	rng.randomize()


# grau da arma na mão: 0 (NG) a 6 (SS), para dar força aos efeitos das habilidades
func _grau_arma() -> int:
	var eq: Dictionary = main.me.get("equipment") if main.me.get("equipment") is Dictionary else {}
	return load("res://scripts/enfeites.gd").indice(str(eq.get("arma", "")))


func now() -> float:
	return Time.get_ticks_msec() * 0.001


# ---------- atributos ----------
func _ench(slot: String, n: float) -> float:
	var a := [0.045, 0.03] if slot == "arma" else [0.035, 0.025]
	return 1.0 + minf(n, 10.0) * a[0] + maxf(0.0, n - 10.0) * a[1]


func _buff(k: String) -> float:
	var v := 1.0
	for b in buffs:
		if b.k == k and b.until > now():
			v += b.v
	return v


func recalc() -> void:
	var c: Dictionary = main.me
	var R: Dictionary = info.races.get(str(c.get("race", "humano")), info.races.humano)
	var t := str(c.get("type", "l"))
	if not (R.hp as Dictionary).has(t):
		t = (R.hp as Dictionary).keys()[0]
	var L := int(c.get("level", 1))
	var f := pow(1.05, L - 1)
	var cl: Dictionary = info.classes.get(str(c.get("class_id", "")), {"rank": 0, "arch": "guerreiro" if t == "l" else "mago", "name": ""})
	var rk := int(cl.rank)
	var eq: Dictionary = c.get("equipment") if c.get("equipment") is Dictionary else {}
	var en: Dictionary = c.get("enchant") if c.get("enchant") is Dictionary else {}
	var w: Dictionary = info.items.get(str(eq.get("arma", "")), {})
	var wm := _ench("arma", float(en.get(str(eq.get("arma", "")), 0))) if not w.is_empty() else 1.0
	var a := {}
	for slot in eq:
		var it: Dictionary = info.items.get(str(eq[slot]), {})
		if slot == "arma" or it.is_empty():
			continue
		var am := _ench(slot, float(en.get(str(eq[slot]), 0)))
		for k in it.stats:
			a[k] = float(a.get(k, 0.0)) + float(it.stats[k]) * (am if k in ["pdef", "mdef"] else 1.0)
	var ws: Dictionary = w.get("stats", {})
	var wk: Dictionary = info.weapons.get(str(w.get("kind", "")), {"range": 2.2, "spd": 0.9})
	var rm: float = info.rank_mult[clampi(rk, 0, 3)]
	var arch: Dictionary = info.arch.get(str(cl.arch), info.arch.guerreiro)
	st = {
		"maxHp": roundf(float(R.hp[t]) * f * (1.0 + 0.03 * rk) + float(a.get("hp", 0.0))),
		"maxMp": roundf(float(R.mp[t]) * f * (1.0 + 0.02 * rk) + float(a.get("mp", 0.0))),
		"patk": (float(R.patk[t]) + float(ws.get("patk", 0.0)) * wm + float(a.get("patk", 0.0))) * f * rm * _buff("patk"),
		"matk": (float(R.matk[t]) + float(ws.get("matk", 0.0)) * wm + float(a.get("matk", 0.0))) * f * rm * (1.0 + float(a.get("matkPct", 0.0))) * _buff("matk"),
		"pdef": (float(R.pdef) + float(a.get("pdef", 0.0))) * f * _buff("pdef"),
		"speed": 6.2 * float(R.spd) * _buff("speed"),
		"arco": str(w.get("kind", "")) == "arco",
		"range": float(wk.get("range", 2.2)),
		"interval": float(wk.get("spd", 1.0)) / _buff("atkspd"),
		"magic": bool(wk.get("magic", false)) or str(arch.get("atk", "p")) == "m",
		"class": str(cl.get("name", "")),
	}
	my_elem = str(info.get("race_elem", {}).get(str(c.get("race", "")), ""))
	# passivas de equipamento (arma, conjunto, encanto, acessórios, buffs, grupo): iguais para todos
	var ctx := _ctx_passivas()
	if main.ui != null:
		main.ui.ctx_passivas = ctx
	pb = Passivas.bonus(Passivas.ativas(c, info.items, ctx))
	st.patk *= 1.0 + float(pb.get("atq_fis", 0.0))
	st.matk *= 1.0 + float(pb.get("atq_mag", 0.0))
	st.pdef *= 1.0 + float(pb.get("def_fis", 0.0))
	st.maxHp = roundf(st.maxHp * (1.0 + float(pb.get("hp", 0.0))))
	st.maxMp = roundf(st.maxMp * (1.0 + float(pb.get("mp", 0.0))))
	st.speed *= 1.0 + float(pb.get("vel_mov", 0.0))
	st.interval /= maxf(0.5, 1.0 + float(pb.get("vel_atq", 0.0)))
	st.range += float(pb.get("alcance", 0.0))
	st["crit"] = 0.06 + float(pb.get("critico", 0.0))
	var antes := skills.size()
	skills = _skills_v2(c, L)
	if skills.is_empty() and not c.get("skills") is Dictionary:  # sem banco novo (servidor oficial): habilidades antigas do arquétipo
		for s in arch.skills:
			if int(s.lvl) <= L and skills.size() < 9:
				skills.append(s)
	while cds.size() < skills.size():
		cds.append(0.0)
	if antes != skills.size() and main.ui != null and active:
		main.ui.set_skills(skills)


# grupo por perto, buffs com marca e noite: decidem as passivas de efeito
func _ctx_passivas() -> Dictionary:
	var n := 1
	var g = main.get("grupo")
	if g != null and g.has_method("em_grupo") and g.em_grupo():
		n = maxi(1, g.membros.size())
	var bl: Array = []
	for b in buffs:
		if b.has("tag") and b.until > now():
			bl.append(b.tag)
	return {"grupo": n, "buffs": bl, "montado": bool(main.me.get("montado", false)), "pet": bool(main.me.get("pet_ativo", false))}


# habilidades ativas da classe (banco v2), acumuladas da base até a classe atual, no nível que o personagem tem
const V2_TIPO := {"ataque": "hit", "elemental": "hit", "critico": "hit", "atordoar": "hit", "prender": "hit", "puxar": "hit", "dreno": "hit",
	"area": "zone", "avanco": "dash", "provocar": "taunt", "debuff": "debuff", "buff": "buff", "aura": "buff", "alternar": "buff", "invocar": "buff",
	"cura": "heal", "cura_area": "heal", "reviver": "heal", "purificar": "heal"}

func _skills_v2(c: Dictionary, L: int) -> Array:
	var UI = load("res://scripts/ui.gd")
	var cv: Dictionary = UI.classes_v2()
	if cv.is_empty():
		return []
	var cid := str(c.get("class_id", ""))
	if not cv.classes.has(cid):
		cid = ""
		for k in cv.classes:
			if int(cv.classes[k].rank) == 0 and str(cv.classes[k].raca) == str(c.get("race", "humano")):
				cid = k
				break
	if cid == "":
		return []
	var stc: Dictionary = cv.classes[cid].get("status", {})
	vel_cl = {"vel_ataque": float(stc.get("vel_ataque", 333)), "vel_conjuracao": float(stc.get("vel_conjuracao", 333))}
	var out: Array = []
	for cc in UI.cadeia_classe(cid):
		for sid in cv.habilidades_da_classe.get(cc, []):
			var h: Dictionary = cv.habilidades[sid]
			if not h.ativa:
				continue
			var nv: int = UI.nivel_hab(h, c, L)
			if nv <= 0:
				continue
			out.append(_converter_v2(h, nv))
	if out.size() > 27:
		out = out.slice(out.size() - 27)  # as mais novas (ficam as da classe atual)
	return out


func _converter_v2(h: Dictionary, nv: int) -> Dictionary:
	var t: Dictionary = h.tabela[nv - 1]
	var tp := str(h.tipo)
	var pw := float(t.poder)
	var s := {"name": "%s %d" % [h.nome, nv], "type": V2_TIPO.get(tp, "hit"), "mp": int(t.mana), "cd": maxf(float(h.recarga), 1.0), "mult": 0.0, "aoe": 0.0,
		"stun": 0.0, "pct": 0.0, "dur": 0.0, "buff": null, "fx": str(h.elemento), "icone": str(h.icone), "v2": tp, "id": str(h.id), "nivel": nv,
		"gesto": str(h.get("movimento", {}).get("gesto", "")), "por": str(h.get("conjuracao", {}).get("por", "vel_conjuracao")),
		"base": float(h.get("conjuracao", {}).get("base", 0.0)), "fisica": str(h.categoria) == "golpe"}
	match tp:
		"ataque", "elemental", "dreno", "puxar":
			s.mult = pw
		"critico":
			s.mult = pw
			s["crit_extra"] = 0.25
		"atordoar":
			s.mult = pw
			s.stun = 1.6
		"prender":
			s.mult = maxf(pw, 0.6)
			s.stun = 2.6
		"area":
			s.mult = pw
			s.aoe = 5.0
		"avanco":
			s.mult = maxf(pw, 1.0)
		"provocar", "debuff":
			s.aoe = 8.0
			s.dur = 12.0
		"cura", "cura_area", "reviver", "purificar":
			s.pct = clampf(pw, 0.08, 0.6)
		"buff", "aura", "alternar", "invocar":
			var chave := "patk"
			if str(h.icone).begins_with("escudo") or str(h.icone).begins_with("cupula") or str(h.icone).begins_with("escamas") or str(h.icone).begins_with("manto"):
				chave = "pdef"
			elif str(h.icone).begins_with("bota") or str(h.icone).begins_with("tornado"):
				chave = "atkspd"
			elif not s.fisica and str(h.categoria) != "golpe" and str(h.icone).get_slice("_", 0) in ["orbe", "livro", "gema", "olho", "lua", "totem", "golem", "asas"]:
				chave = "matk"
			var v := pw if tp != "invocar" else 0.12 + 0.05 * float(h.rank)
			s.buff = {chave: v}
			s.dur = 60.0 if tp in ["aura", "alternar"] else 30.0
	return s


# tempo de conjuração: base × 333 ÷ velocidade (vel. de ataque nos golpes, vel. de conjuração nas magias), com buffs e passivas
func tempo_conj(s: Dictionary) -> float:
	var base := float(s.get("base", 0.0))
	if base <= 0.0:
		return 0.0
	var por := str(s.get("por", "vel_conjuracao"))
	var vel := float(vel_cl.get(por, 333.0))
	var extra := 1.0 + float(pb.get("vel_atq" if por == "vel_ataque" else "vel_conj", 0.0))
	if por == "vel_ataque":
		extra *= _buff("atkspd")
	return base * 333.0 / maxf(vel * extra, 1.0)


func start() -> void:
	clear()
	buffs = []
	cds = []
	recalc()
	hp = clampf(float(main.me.get("hp", st.maxHp)), 1.0, st.maxHp)
	mp = clampf(float(main.me.get("mp", st.maxMp)), 0.0, st.maxMp)
	if hp < st.maxHp * 0.2:
		hp = st.maxHp
	dead = false
	active = true
	main.ui.set_skills(skills)


func clear() -> void:
	for m in mobs:
		if is_instance_valid(m.node):
			m.node.queue_free()
	mobs = []
	target = null
	auto = false
	pending = []
	active = false


# ---------- monstros ----------
func _level_at(x: float, z: float) -> Dictionary:
	var nt: Dictionary = world.nearest_town(x, z)
	var t: Dictionary = nt.town
	var k := clampf((nt.dist - float(nt.safe)) / 450.0, 0.0, 1.0)
	return {"L": maxi(1, roundi(float(t.min) + (float(t.max) - float(t.min)) * k)), "band": int(t.band), "dist": nt.dist}


func _mob_model(fam: Dictionary) -> Dictionary:
	var id := str(fam.id)
	var sc := float(fam.scale)
	var node: Node3D
	var kind := "glb"
	var height := 1.0
	var modelo := str(fam.model)
	if bool(fam.get("boss", false)) and modelo == "quad":
		modelo = "fera_chefe"   # chefe de 4 patas: mutante que anda em 2 patas, com armadura e arma
	if Criatura.tem(id):
		# criatura com modelo próprio (CC0): corpo de verdade em vez de corpo humano decorado
		node = Criatura.criar(id, sc)
		if bool(fam.get("boss", false)):
			VisualMonstros.aura_chefe(node, Color(str(fam.get("color", "#888888"))).lightened(0.2), 0.45 * node.altura)
		return {"node": node, "kind": "criatura", "height": node.altura}
	match modelo:
		"fera_chefe":
			kind = "char"
			var sub := "javali" if id.contains("javali") else "lobo"
			var o := {"race": "beastman", "subtipo": sub, "gender": "m", "skin": 0, "sem_roupa": true, "sem_brasao": true, "armadura_mutante": "pesada_d",
				"equipment": {"armadura": "nenhuma", "arma": "martelo_ng" if str(fam.get("role", "")) != "mago" else "cajado_ng", "escudo": "egide_ng" if str(fam.get("role", "")) != "mago" else ""}}
			node = Character.create(o)
			node.scale = Vector3.ONE * sc * 0.9
			VisualMonstros.aplicar(id, "fera_chefe", node, true, Color(str(fam.get("color", "#888888"))))
			VisualMonstros.chefe(node, fam)
			height = node.height_m * sc * 0.9
		"humanoid", "golem", "ent", "dragon":
			kind = "char"
			var o := {"race": "humano", "gender": "m", "hair": 0, "equipment": {"armadura": "pesada_ng", "arma": "espada_ng"}}
			if id == "bandido":
				o = {"race": "orc", "gender": "m", "hair": 0, "equipment": {"armadura": "leve_ng", "arma": "machado_ng"}}
			elif id in ["esqueleto", "espectro"]:
				o.skin_color = "#d6d4c4"
			elif id in ["demonio", "senhor_dem"]:
				o.skin_color = "#a8281e"
				o.equipment.arma = "espadao_ng"
			elif id == "caido":
				o.skin_color = "#5a5f6c"
				o.equipment.arma = "espadao_ng"
			elif str(fam.model) == "golem":
				o = {"race": "gigante", "gender": "m", "hair": 0, "skin_color": "#7d7a72", "equipment": {"armadura": "pesada_ng"}}
			elif str(fam.model) == "ent":
				o = {"race": "gigante", "gender": "m", "hair": 0, "skin_color": "#4f6233", "equipment": {"armadura": "leve_ng"}}
			elif str(fam.model) == "dragon":
				o = {"race": "draconato", "gender": "m", "skin": 4}
			o.sem_brasao = true   # monstro não usa o brasão das raças
			if bool(fam.boss):
				# chefe: sem roupa humana; corpo na cor da criatura e armadura mutante por cima
				o.sem_roupa = true
				# golem e ent não vestem armadura: o corpo deles é a própria pedra / madeira (CorpoChefe)
				if not id in ["golem_anc", "ent_mil"]:
					o.armadura_mutante = {"senhor_dem": "pesada_b", "dragao": "pesada_a"}.get(id, "pesada_d")
				if not o.has("skin_color") and id != "dragao":
					o.skin_color = str(fam.get("color", "#888888"))
			node = Character.create(o)
			node.scale = Vector3.ONE * sc
			VisualMonstros.aplicar(id, str(fam.model), node, bool(fam.boss), Color(str(fam.get("color", "#888888"))))
			if not bool(fam.boss):
				CorpoChefe.comum(node, id)
			if bool(fam.boss):
				CorpoChefe.aplicar(node, id)
				VisualMonstros.chefe(node, fam)
			height = node.height_m * sc
		_:
			var file := "m_wolf"
			var target_h := 0.95
			if id == "cervo_luz":
				file = "m_wolf"   # cervo de luz: esqueleto do lobo com pernas longas e galhada
				target_h = 1.3
			elif id.contains("javali"):
				file = "m_wolf"   # o javali usa o esqueleto do lobo transformado (antes era o touro e parecia um boi)
				target_h = 0.85
			elif str(fam.model) == "spider":
				file = "e_spider"
				target_h = 0.8
			elif id == "lagarto":
				file = "z_raptor"
				target_h = 1.5
			var holder := Node3D.new()
			var sc_node: Node3D = (load("res://assets/world/%s.glb" % file) as PackedScene).instantiate()
			var bb := AABB()
			var first := true
			for mi in sc_node.find_children("*", "MeshInstance3D", true, false):
				var a: AABB = (mi as MeshInstance3D).get_aabb()
				bb = a if first else bb.merge(a)
				first = false
				(mi as MeshInstance3D).extra_cull_margin = 2.0
			var k := target_h * sc / maxf(bb.size.y, 0.01)
			if bb.size.y > 50.0 or bb.size.y < 0.05:
				k = sc  # caixa em unidade estranha: usa a escala do modelo
			sc_node.scale = Vector3.ONE * k
			if id.contains("javali"):
				VisualMonstros.javali(sc_node, bool(fam.boss))
			match id:
				"cervo_luz":
					VisualMonstros.cervo_luz(sc_node)
				"lobo_esp":
					VisualMonstros.lobo_espectral(sc_node)
				"lagarto":
					VisualMonstros.lagarto_mutante(sc_node)
				"besouro":
					VisualMonstros.besouro(sc_node)
				"rainha":
					VisualMonstros.rainha(sc_node)
			holder.add_child(sc_node)
			node = holder
			height = target_h * sc
	return {"node": node, "kind": kind, "height": height}


# monstros que guardam as ruínas: mortos-vivos, cavaleiros caídos e golens
const RUIN_FAMS := ["esqueleto", "caido", "golem"]


func _ruin_fam(id: String) -> Dictionary:
	for g in info.mobs:
		for f in g:
			if str(f.id) == id:
				return f
	return {}


func _spawn(x: float, z: float, boss := false, boss_lvl := 0, spot := "", fam_force: Dictionary = {}) -> void:
	var __t := Time.get_ticks_usec()
	_spawn_medido(x, z, boss, boss_lvl, spot, fam_force)
	Perfil.soma("monstro", Time.get_ticks_usec() - __t)


func _spawn_medido(x: float, z: float, boss := false, boss_lvl := 0, spot := "", fam_force: Dictionary = {}) -> void:
	var li := _level_at(x, z)
	var fams: Array = (info.mobs[clampi(li.band, 0, info.mobs.size() - 1)] as Array).filter(func(f): return bool(f.boss) == boss)
	if not fam_force.is_empty():
		fams = [fam_force]
	if fams.is_empty():
		return
	var fam: Dictionary = fams[rng.randi() % fams.size()]
	var L: int = clampi(int(li.L) + rng.randi_range(-1, 1) + (3 if not fam_force.is_empty() else 0), 1, 92)
	if boss:
		L = clampi(boss_lvl, 1, 92)
	var ms: Array = (info.mobstats[L - 1] as Array).duplicate()
	if boss:  # mesma regra do jogo web: 14x a vida, 1,8x o ataque, 12x a experiência
		ms[0] = float(ms[0]) * 14.0
		ms[1] = float(ms[1]) * 1.8
		ms[3] = float(ms[3]) * 12.0
	var md := _mob_model(fam)
	var node: Node3D = md.node
	add_child(node)
	node.position = Vector3(x, world.height(x, z), z)
	node.rotation.y = rng.randf() * TAU
	if md.kind == "glb":  # base do modelo encostada no chão (medida já no mundo, com as escalas internas)
		var lo := 1e9
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			lo = minf(lo, ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).position.y)
		if lo < 1e8 and absf(node.position.y - lo) < 5.0:
			var inner: Node3D = node.get_child(0)
			inner.position.y += node.position.y - lo
	var lb := Label3D.new()
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# nome do monstro com tamanho fixo na tela (não vira um letreiro gigante de perto)
	lb.fixed_size = true
	lb.pixel_size = 0.00042
	lb.font_size = 42
	lb.outline_size = 10
	lb.text = ("CHEFE  %s  Nv %d" if boss else "%s  Nv %d") % [fam.name, L]
	var diff := L - int(main.me.get("level", 1))
	lb.modulate = Color(1, 0.35, 0.35) if diff >= 5 else (Color(1, 0.85, 0.35) if diff >= 2 else (Color.WHITE if diff >= -2 else Color(0.55, 0.8, 0.6)))
	lb.position = Vector3(0, (float(md.height) + 0.35) / maxf(node.scale.y, 0.01), 0)
	lb.visibility_range_end = 120.0 if boss else 45.0
	if boss:
		lb.font_size = 46
	node.add_child(lb)
	var m := {"fam": fam, "L": L, "hp": float(ms[0]), "maxHp": float(ms[0]), "atk": float(ms[1]), "def": float(ms[2]), "xp": float(ms[3]), "node": node, "kind": md.kind, "home": node.position,
		"aggro": false, "next_atk": 0.0, "stun": 0.0, "wander": node.position, "wander_t": rng.randf() * 4.0, "dead": false, "dead_t": 0.0, "weak": 0.0, "anim": "", "height": md.height, "boss": boss, "spot": spot}
	m.ap = node.anim if md.kind == "char" else (node.ap if md.kind == "criatura" else node.find_child("AnimationPlayer", true, false))
	_mob_anim(m, "idle")
	mobs.append(m)


func _mob_anim(m: Dictionary, what: String) -> void:
	if not what in ["hit", "death"] and now() < float(m.get("hit_ate", 0.0)):
		return  # ainda reagindo ao golpe recebido
	if m.kind == "criatura":  # ataque e golpe se repetem a cada vez; o resto só quando muda
		if m.anim != what or what in ["attack", "hit"]:
			m.anim = what
			m.node.estado(what)
		return
	if m.anim == what:
		return
	m.anim = what
	var ap: AnimationPlayer = m.ap
	if ap == null:
		return
	if m.kind == "char":
		var n: String = {"idle": "Idle", "walk": "Walk", "run": "Jog_Fwd", "attack": "Sword_Regular_A", "death": "Death01", "hit": "Hit_Chest"}.get(what, "Idle")
		if what in ["attack", "death", "hit"]:
			m.node.action(n)
		else:
			m.node.play(n)
		return
	var want: Array = {"idle": ["Idle"], "walk": ["Walk"], "run": ["Gallop", "Run", "Walk"], "attack": ["Attack", "Attack_Headbutt", "Bite_Front", "Bite"], "death": ["Death"], "hit": ["Idle_HitReact1", "Idle_HitReact_Left", "HitRecieve", "HitReact"]}.get(what, ["Idle"])
	if not ap.has_animation(want[0]) and what in ["idle", "walk", "run", "attack", "death"]:
		for n in ap.get_animation_list():  # nomes variam entre pacotes: procura por parte do nome
			if String(n).to_lower().contains({"idle": "idle", "walk": "walk", "run": "run", "attack": "attack", "death": "death"}[what]):
				want = [n]
				break
	for n in want:
		if ap.has_animation(n):
			if what in ["idle", "walk", "run"]:
				ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			ap.play(n, 0.2)
			return


func _manage_spawns(dt: float) -> void:
	spawn_t -= dt
	if spawn_t > 0.0:
		return
	spawn_t = 1.0
	var p: Vector3 = main.player.position
	for i in range(mobs.size() - 1, -1, -1):
		var m: Dictionary = mobs[i]
		var far: bool = (m.node.position as Vector3).distance_to(p) > (240.0 if m.boss or String(m.spot).begins_with("ruina:") else 150.0) and not m.aggro
		if far or (m.dead and now() - float(m.dead_t) > 5.0):
			if target == m:
				target = null
				auto = false
			m.node.queue_free()
			mobs.remove_at(i)
	# um chefe por ponto de caça; volta 5 minutos depois de derrotado
	for t in info.towns:
		for sp in t.get("spots", []):
			var key := "%s:%s" % [t.id, sp.name]
			var sd := Vector2(float(sp.x) - p.x, float(sp.z) - p.z).length()
			if sd < 170.0 and now() >= float(boss_next.get(key, 0.0)) and not mobs.any(func(m): return m.spot == key):
				if world.height(float(sp.x), float(sp.z)) > 1.2:
					_spawn(float(sp.x), float(sp.z), true, int(sp.lvl), key)
					if sd < 120.0:
						message.emit("Um chefe ronda %s" % sp.name)
	# ruínas: até 6 guardiões por sítio, perto do jogador
	for l in info.get("landmarks", []):
		if str(l.id) == "era_neon" or str(l.id) in world.CASTLE_POIS:
			continue
		var ld := Vector2(float(l.x) - p.x, float(l.z) - p.z).length()
		if ld > float(l.r) + 90.0:
			continue
		var key := "ruina:" + str(l.id)
		var here := mobs.filter(func(m): return m.spot == key and not m.dead).size()
		if here == 0 and ld < float(l.r) + 50.0 and not ruin_warned.has(key):
			ruin_warned[key] = true
			message.emit("Guardiões rondam %s" % l.name)
		for k in mini(2, 6 - here):
			var a := rng.randf() * TAU
			var rr := rng.randf_range(4.0, float(l.r) * 0.6)
			var x := float(l.x) + sin(a) * rr
			var z := float(l.z) + cos(a) * rr
			if world.height(x, z) > 1.2:
				_spawn(x, z, false, 0, key, _ruin_fam(RUIN_FAMS[rng.randi() % RUIN_FAMS.size()]))
	var alive := mobs.filter(func(m): return not m.dead and not m.boss and not String(m.spot).begins_with("ruina:")).size()
	var tries := 0
	while alive < 12 and tries < 8:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(35.0, 95.0)
		var x := p.x + sin(a) * r
		var z := p.z + cos(a) * r
		if x < 30.0 or z < 30.0 or x > world.size - 30.0 or z > world.size - 30.0:
			continue
		var ntm: Dictionary = world.nearest_town(x, z)
		if ntm.dist < float(ntm.wall) + 30.0 or not world.zone_at(x, z).is_empty() or world.height(x, z) < 1.2 or world.normal(x, z).y < 0.85 or world.ground(x, z).r > 0.5:
			continue
		_spawn(x, z)
		alive += 1


func _mob_tick(m: Dictionary, dt: float) -> void:
	var node: Node3D = m.node
	if m.dead:
		return
	var t := now()
	var pp: Vector3 = main.player.position
	var d := Vector2(pp.x - node.position.x, pp.z - node.position.z).length()
	if t < float(m.stun):
		return
	if not m.aggro and m.fam.aggro and not dead and not main.gm_hide and d < 11.0 and not world.zona(pp.x, pp.z).paz:
		m.aggro = true
	if m.aggro and (dead or (node.position as Vector3).distance_to(m.home) > 55.0):
		m.aggro = false
		m.hp = m.maxHp
	if m.aggro and m.boss and not dead and HabChefe.tick(self, m, dt):
		return
	# comportamentos próprios (MESA-015.1): o cervo foge quando atacado; o espectro se teleporta perto
	var comp := str(m.fam.get("comportamento", ""))
	if comp == "foge" and m.aggro:
		var fuga := Vector3(node.position.x - pp.x, 0, node.position.z - pp.z)
		if fuga.length() > 0.05 and d < 25.0:
			var zig := sin(t * 3.0) * 0.6
			fuga = (fuga.normalized() + Vector3(-fuga.z, 0, fuga.x).normalized() * zig).normalized()
			var np2: Vector3 = node.position + fuga * 5.2 * dt
			node.position = Vector3(np2.x, world.height(np2.x, np2.z), np2.z)
			node.rotation.y = lerp_angle(node.rotation.y, atan2(fuga.x, fuga.z), minf(1.0, dt * 8.0))
			_mob_anim(m, "run")
		else:
			m.aggro = false
		return
	if comp == "teleporta" and m.aggro and t > float(m.get("tele_t", 0.0)) and d < 14.0:
		m.tele_t = t + 6.0
		var a2 := randf() * TAU
		var alvo := pp + Vector3(sin(a2), 0, cos(a2)) * 6.0
		FX.burst(self, node.position + Vector3(0, 1.0, 0), "sombra", 1.0)
		node.position = Vector3(alvo.x, world.height(alvo.x, alvo.z), alvo.z)
		FX.burst(self, node.position + Vector3(0, 1.0, 0), "sombra", 1.0)
	var goal: Vector3 = node.position
	var speed := 0.0
	if m.aggro:
		var reach: float = 1.6 + float(m.height) * 0.5
		if d > reach:
			goal = pp
			speed = 4.2
		elif t >= float(m.next_atk):
			m.next_atk = t + 2.0
			m.anim = ""
			_mob_anim(m, "attack")
			node.rotation.y = atan2(pp.x - node.position.x, pp.z - node.position.z)
			var atk: float = float(m.atk) * (0.75 if t < float(m.weak) else 1.0)
			var dmg := atk * atk / (atk + float(st.pdef) * 0.5) * rng.randf_range(0.9, 1.1)
			_hurt_player(dmg)
			FX.burst(self, _chest(), str(m.fam.get("elem", "")), 0.5)
	else:
		m.wander_t = float(m.wander_t) - dt
		if float(m.wander_t) <= 0.0:
			var ruin := String(m.spot).begins_with("ruina:")
			m.wander_t = rng.randf_range(3.0, 7.0) if ruin else rng.randf_range(4.0, 11.0)
			var a := rng.randf() * TAU
			if rng.randf() < 0.3 and not ruin:
				m.wander = node.position  # fica parado, olhando em volta
				node.rotation.y += rng.randf_range(-1.2, 1.2)
			else:
				m.wander = (m.home as Vector3) + Vector3(sin(a), 0, cos(a)) * rng.randf_range(2.0, 14.0 if ruin else 11.0)
		if (node.position as Vector3).distance_to(m.wander) > 0.6:
			goal = m.wander
			speed = 1.3
	if speed > 0.0:
		var dir := Vector3(goal.x - node.position.x, 0, goal.z - node.position.z)
		if dir.length() > 0.05:
			dir = dir.normalized()
			var np: Vector3 = node.position + dir * speed * dt
			node.position = Vector3(np.x, world.height(np.x, np.z), np.z)
			node.rotation.y = lerp_angle(node.rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 8.0))
			_mob_anim(m, "run" if speed > 2.0 else "walk")
	elif m.anim in ["walk", "run"] or (m.anim == "attack" and t > float(m.next_atk) - 1.2):
		_mob_anim(m, "idle")


# ---------- sopro racial da dragonita (MESA-015.1): cone de 12 m e 55°, 85% do dano, recarga 12 s, 25% do fôlego ----------
var sopro_pronto := 0.0


func sopro_racial() -> void:
	var dv = main.player.get("asas")
	if dv == null or dead:
		return
	var sp: Dictionary = HabChefe.dados().get("sopro_dragonita", {})
	var t := now()
	if t < sopro_pronto:
		_float_text(main.player.position + Vector3(0, main.player.height_m + 0.3, 0), "sopro em %ds" % ceili(sopro_pronto - t), Color(0.8, 0.8, 0.8))
		return
	if main.folego.planando:
		return   # sem sopro planando (MESA-015.1)
	var custo: float = main.folego.maximo * float(sp.get("custo_folego_pct", 25)) / 100.0
	if main.folego.atual < custo:
		_float_text(main.player.position + Vector3(0, main.player.height_m + 0.3, 0), "sem fôlego", Color(0.8, 0.8, 0.8))
		return
	main.folego.atual -= custo
	sopro_pronto = t + float(sp.get("recarga", 12))
	dv.sopro("fogo")
	var frente := Vector2(sin(main.player.rotation.y), cos(main.player.rotation.y))
	var meio := deg_to_rad(float(sp.get("angulo", 55)) * 0.5)
	for m in mobs:
		if m.dead:
			continue
		var v := Vector2((m.node as Node3D).position.x - main.player.position.x, (m.node as Node3D).position.z - main.player.position.z)
		if v.length() > float(sp.get("alcance", 12)) or (v.length() > 0.8 and absf(frente.angle_to(v.normalized())) > meio):
			continue
		var r := _damage(float(sp.get("dano_pct", 85)) / 100.0)
		pending.append({"t": t + 0.5, "mob": m, "dmg": r.dmg, "crit": r.crit, "fx": "fogo", "size": 0.8})


# ---------- efeitos dos chefes no jogador (MESA-015.1) ----------
const NOME_DEBUFF := {"lentidao": "LENTIDÃO", "enraizamento": "ENRAIZADO", "atordoamento": "ATORDOADO", "veneno": "VENENO",
	"queimadura": "QUEIMADURA", "recuo": "EMPURRADO", "afinidade_reduzida": "AFINIDADE REDUZIDA"}


func aplicar_debuff(tipo: String, valor: float, dur: float, origem: Vector3) -> void:
	var t := now()
	if tipo == "recuo":
		var pp: Vector3 = main.player.position
		var dir := Vector3(pp.x - origem.x, 0, pp.z - origem.z)
		if dir.length() > 0.01:
			var np: Vector3 = world.resolve(pp + dir.normalized() * valor, pp)
			main.player.position = Vector3(np.x, world.height(np.x, np.z), np.z)
	else:
		debuffs[tipo] = [valor, t + dur]
	_float_text(main.player.position + Vector3(0, main.player.height_m + 0.4, 0), str(NOME_DEBUFF.get(tipo, tipo.to_upper())), Color(0.95, 0.6, 1.0))


func _debuff_ativo(tipo: String) -> bool:
	return debuffs.has(tipo) and now() < float(debuffs[tipo][1])


# multiplicador do passo do jogador (lentidão, enraizado, atordoado)
func mult_movimento() -> float:
	if _debuff_ativo("enraizamento") or _debuff_ativo("atordoamento"):
		return 0.0
	if _debuff_ativo("lentidao"):
		return clampf(1.0 - float(debuffs.lentidao[0]) / 100.0, 0.2, 1.0)
	return 1.0


func _debuffs_tick(dt: float) -> void:
	for k in ["veneno", "queimadura"]:
		if _debuff_ativo(k):
			# valor = intensidade: 0,4% da vida máxima por segundo por ponto
			hp -= st.maxHp * float(debuffs[k][0]) * 0.004 * dt
			combat_until = now() + 6.0
			if hp <= 1.0 and not dead and main.world.zona(main.player.position.x, main.player.position.z).paz:
				hp = 1.0  # veneno não mata dentro da zona de paz
			elif hp <= 0.0 and not dead:
				hp = 0.0
				_die()


# ---------- dano ----------
func _float_text(pos: Vector3, text: String, col: Color, esc := 1.0) -> void:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true  # números de dano do mesmo tamanho na tela, perto ou longe
	l.pixel_size = 0.0006
	l.font_size = 60
	l.outline_size = 12
	l.text = text
	l.modulate = col
	l.position = pos + Vector3(rng.randf_range(-0.3, 0.3), 0, 0)
	add_child(l)
	var tw := create_tween()
	if esc > 1.0:  # salto: cresce rápido e volta ao tamanho
		l.scale = Vector3.ONE * esc * 1.6
		tw.tween_property(l, "scale", Vector3.ONE * esc, 0.12)
	tw.tween_property(l, "position", l.position + Vector3(0, 1.3, 0), 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


func _hurt_player(dmg: float) -> void:
	if dead or main.gm_god:
		return
	if main.world.zona(main.player.position.x, main.player.position.z).paz:
		return  # zona de paz (cidades e áreas de missão): ninguém morre
	combat_until = now() + 6.0
	if rng.randf() < float(pb.get("bloqueio", 0.0)) + float(pb.get("esquiva", 0.0)) * 0.004:
		_float_text(main.player.position + Vector3(0, main.player.height_m, 0), "Bloqueio", Color(0.75, 0.85, 1.0))
		return
	if shield > 0.0 and now() < shield_until:
		var ab := minf(shield, dmg)
		shield -= ab
		dmg -= ab
	hp -= dmg
	_float_text(main.player.position + Vector3(0, main.player.height_m, 0), "-%d" % int(dmg), Color(1, 0.4, 0.35))
	# dano recebido: borda da tela avermelha e a câmera treme na proporção do golpe
	var frac := clampf(dmg / maxf(float(st.get("maxHp", 100.0)), 1.0), 0.0, 1.0)
	main.tremer(0.015 + frac * 0.12)
	if main.ui.has_method("flash_dano"):
		main.ui.flash_dano(0.25 + frac * 1.6)
	if hp <= 0.0:
		hp = 0.0
		_die()


func _die() -> void:
	dead = true
	dead_t = now()
	auto = false
	target = null
	main.has_target = false
	main.player.action("Death01")
	main.player.busy_until = now() + 4.0
	message.emit("Você caiu em combate. Voltando para a cidade...")
	for m in mobs:
		m.aggro = false


func _revive() -> void:
	var back: Vector3 = main.home
	if main.me.has("id") and main.net.token != "":
		await main.net.rpc_call("game_die", {"p_char": main.net.char_id})
		var s: Dictionary = await main.net.state(main.net.char_id)
		if not s.is_empty():
			main.me = s
			back = Vector3(float(s.get("x", back.x)), 0, float(s.get("z", back.z)))
	else:
		var nt: Dictionary = world.nearest_town(main.player.position.x, main.player.position.z)
		back = Vector3(float(nt.town.x) + 3.5, 0, float(nt.town.z) + 6.0)
	recalc()
	hp = st.maxHp
	mp = st.maxMp
	main._place_player(back)
	main.player.busy_until = 0.0
	main.player.play("Idle")
	dead = false
	main.ui.set_who(main.me)


func _hit_mob(m: Dictionary, dmg: float, crit: bool) -> void:
	if m.dead:
		return
	m.hp = float(m.hp) - dmg
	m.aggro = true
	combat_until = now() + 6.0
	var cabeca := (m.node as Node3D).position + Vector3(0, float(m.height), 0)
	if crit:  # crítico: número maior e a palavra em laranja acima, que "salta" e sobe
		_float_text(cabeca + Vector3(0, 0.45, 0), "Crítico", Color(1.0, 0.55, 0.15), 1.25)
		_float_text(cabeca, "%d" % int(dmg), Color(1, 0.88, 0.3), 1.5)
	else:
		_float_text(cabeca, "%d" % int(dmg), Color.WHITE)
	_impacto(m, dmg, crit)
	if float(m.hp) <= 0.0:
		m.dead = true
		m.dead_t = now()
		m.anim = ""
		_mob_anim(m, "death")
		if target == m:
			target = null
			auto = false
		_reward(m)


# impacto do golpe (fase de combate, 22/11): o monstro pisca claro, recua um passo, faz a reação de dor e solta
# faíscas no ponto do golpe; no crítico o jogo "segura" 60 ms e a câmera treme um pouco. Golpes que tiram muita
# vida pesam mais. Nada disso muda dano ou regra: é só leitura do golpe.
var _mat_pisca: StandardMaterial3D


func _impacto(m: Dictionary, dmg: float, crit: bool) -> void:
	var no := m.node as Node3D
	if no == null or not is_instance_valid(no):
		return
	var peso := clampf(dmg / maxf(float(m.get("maxHp", 100.0)), 1.0) * 4.0, 0.0, 1.0)
	var forte := crit or peso > 0.45
	# recuo para longe de quem bateu
	var de: Vector3 = main.player.position
	var dir := no.position - de
	dir.y = 0.0
	if dir.length() > 0.01 and not bool(m.boss):
		var passo := (0.32 if forte else 0.14) / maxf(float(m.get("height", 1.8)) / 1.8, 0.6)
		var tw := no.create_tween()
		tw.tween_property(no, "position", no.position + dir.normalized() * passo, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# reação de dor (não em todo golpe, para não travar o monstro)
	if float(m.hp) > 0.0 and (forte or rng.randf() < 0.45):
		m.hit_ate = now() + 0.35
		m.anim = ""
		_mob_anim(m, "hit")
	# pisca claro
	if _mat_pisca == null:
		_mat_pisca = StandardMaterial3D.new()
		_mat_pisca.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_pisca.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_pisca.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_pisca.albedo_color = Color(1.0, 0.92, 0.8, 0.55)
	var malhas := no.find_children("*", "MeshInstance3D", true, false)
	for mi in malhas:
		(mi as MeshInstance3D).material_overlay = _mat_pisca
	var t := get_tree().create_timer(0.09 if not forte else 0.13, true, false, true)
	t.timeout.connect(func():
		for mi in malhas:
			if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == _mat_pisca:
				(mi as MeshInstance3D).material_overlay = null)
	# faíscas no ponto do golpe (altura do peito, do lado de quem bateu)
	var ponto := no.position + Vector3(0, float(m.get("height", 1.8)) * 0.62, 0) - dir.normalized() * 0.3
	FX.flare(main, ponto, Color(1.0, 0.85, 0.55) if not crit else Color(1.0, 0.6, 0.2), 0.55 if not forte else 0.95, 0.16, 1.2)
	if forte:
		main.tremer(0.06 if crit else 0.04)
		_segura(0.06)


# hitstop: o tempo do jogo quase para por um instante no golpe forte (o relógio real continua)
var _segurando := false
func _segura(seg: float) -> void:
	if _segurando or Engine.time_scale < 0.99:
		return
	_segurando = true
	Engine.time_scale = 0.06
	var t := get_tree().create_timer(seg, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		_segurando = false)


var _prox_abate := 0.0  # PEDIDO 004: próximo horário livre para avisar um abate ao servidor de testes

func _reward(m: Dictionary) -> void:
	var c: Dictionary = main.me
	var lvl := int(c.get("level", 1))
	var L := int(m.L)
	if m.boss:
		boss_next[m.spot] = now() + 300.0
	var head: Vector3 = main.player.position + Vector3(0, main.player.height_m + 0.5, 0)
	if c.has("id") and main.net.token != "":
		# online: experiência, dinheiro e itens vêm do servidor
		# game_kill4: o servidor decide nível, chefe e recompensa pela posição; o cliente só diz quem caiu e onde
		var mp3: Vector3 = (m.node as Node3D).position
		var fn_abate := "game_kill5" if main.net.ambiente_teste() else "game_kill4"  # testes: PH e divisão no grupo
		if main.net.ambiente_teste():
			# PEDIDO 004: o servidor de testes aceita 1 abate a cada 0,8 s (no máximo 70 por minuto).
			# Abates juntos (habilidade em área) entram em fila, 1 aviso por segundo; nenhum se perde.
			var agora := Time.get_ticks_msec() * 0.001
			var espera := _prox_abate - agora
			_prox_abate = maxf(agora, _prox_abate) + 1.0
			if espera > 0.0:
				await get_tree().create_timer(espera).timeout
		var r: Dictionary = await main.net.rpc_call(fn_abate, {"p_char": main.net.char_id, "p_fam": str(m.fam.id), "p_x": mp3.x, "p_z": mp3.z, "p_spot": str(m.spot) if m.boss else null})
		if not r.ok or not (r.data is Dictionary):
			message.emit(r.erro if r.erro != "" else "O servidor não registrou a vitória")
			return
		if (r.data as Dictionary).has("recusado"):
			message.emit(str(r.data.recusado))
			return
		var d: Dictionary = r.data
		c.level = int(d.get("level", lvl))
		c.xp = float(d.get("xp_now", c.get("xp", 0)))
		c.aurum = float(c.get("aurum", 0)) + float(d.get("aurum", 0))
		_float_text(head, "+%d XP" % int(d.get("xp", 0)), Color(0.6, 0.85, 1.0))
		var got: Array = []
		if float(d.get("aurum", 0)) > 0.0:
			got.append("%d aurum" % int(d.aurum))
		if d.get("drops") is Dictionary:
			for k in d.drops:
				got.append("%s x%d" % [info.items.get(str(k), {}).get("name", k), int(d.drops[k])])
				main.net.inventory[k] = int(main.net.inventory.get(k, 0)) + int(d.drops[k])
		if d.get("unique") != null:
			got.append("ITEM ÚNICO: %s" % info.items.get(str(d.unique), {}).get("name", d.unique))
		if d.has("ph"):
			c["ph"] = int(c.get("ph", 0)) + int(d.ph)
			got.append("%d PH" % int(d.ph))
		if d.get("grupo") is Array and (d.grupo as Array).size() > 1:
			var partes: Array = []
			for g in d.grupo:
				partes.append("%s %d XP" % [str(g.nome), int(g.xp)])
			main.ui.chat_line("", "Grupo dividiu: " + ", ".join(partes), "grupo")
		if d.has("itens_para") and str(d.itens_para) != str(c.get("id", "")):
			main.ui.chat_line("", "Itens deste abate foram para %s (rodízio)." % str(d.get("itens_para_nome", "outro membro")), "grupo")
			if d.get("drops") is Dictionary:
				for k in d.drops:
					main.net.inventory[k] = maxi(0, int(main.net.inventory.get(k, 0)) - int(d.drops[k]))
		if not got.is_empty():
			main.ui.chat_line("", "Você recebeu: " + ", ".join(got), "sistema")
	else:
		var pen := 1.0
		if L < lvl - 5:
			pen = maxf(0.1, 1.0 - (lvl - 5 - L) * 0.15)
		var gain := roundi(float(m.xp) * pen * float(info.get("rate_xp", 1.0)))
		c.xp = float(c.get("xp", 0)) + gain
		var nl := lvl
		while nl < 80 and float(c.xp) >= float(info.xpneed[nl - 1]):
			c.xp = float(c.xp) - float(info.xpneed[nl - 1])
			nl += 1
		c.level = nl
		_float_text(head, "+%d XP" % gain, Color(0.6, 0.85, 1.0))
	if int(c.level) > lvl:
		recalc()
		hp = st.maxHp
		mp = st.maxMp
		main.ui.set_skills(skills)
		main.ui.set_who(c)
		FX.burst(self, main.player.position + Vector3(0, 0.2, 0), "holy", 2.4)
		message.emit("Nível %d!" % int(c.level))
		if int(c.level) in info.get("rank_lvl", []):
			main.ui.chat_line("", "Você já pode evoluir de classe: fale com o Mestre de Classes na cidade (tecla K).", "sistema")


func _damage(mult: float, el := "", crit_extra := 0.0, fisica := -1) -> Dictionary:
	var magica: bool = st.magic if fisica < 0 else fisica == 0
	var atk: float = st.matk if magica else st.patk
	var def: float = float(target.def) if target else 0.0
	# vantagem elemental (só contra monstros; em jogador vale a resistência do alvo): mais dano e mais crítico
	var vm := 1.0
	var vc := 0.0
	if el != "" and target and target.has("fam"):
		var cv: Dictionary = load("res://scripts/ui.gd").classes_v2()
		var fe := str(target.fam.get("elem", ""))
		if not cv.is_empty() and cv.vantagem.has(el) and cv.vantagem[el].has(fe):
			var r: Dictionary = cv.regra_elemental[["desvantagem", "neutro", "vantagem"][int(cv.vantagem[el][fe]) + 1]]
			vm = float(r.dano)
			vc = float(r.critico)
	var crit := rng.randf() < float(st.get("crit", 0.06)) + vc + crit_extra
	var dmg := atk * mult * vm * atk / (atk + def * 0.5) * rng.randf_range(0.92, 1.08) * (2.0 if crit else 1.0)
	return {"dmg": dmg, "crit": crit, "vant": vm}


# ---------- ações do jogador ----------
func pick(origin: Vector3, dir: Vector3):
	var best = null
	var bt := 1e9
	for m in mobs:
		if m.dead:
			continue
		var c: Vector3 = (m.node as Node3D).position + Vector3(0, float(m.height) * 0.5, 0)
		var t := (c - origin).dot(dir)
		if t < 0.0:
			continue
		var miss := (origin + dir * t).distance_to(c)
		if miss < maxf(0.8, float(m.height) * 0.6) and t < bt:
			bt = t
			best = m
	return best


func next_target() -> void:
	var best = null
	var bd := 60.0
	for m in mobs:
		if m.dead or m == target:
			continue
		var d: float = (m.node as Node3D).position.distance_to(main.player.position)
		if d < bd:
			bd = d
			best = m
	if best:
		target = best
		auto = false


func engage(m) -> void:
	if dead or m == null:
		return
	target = m
	auto = true


func stop_auto() -> void:
	auto = false


func use_skill(i: int) -> void:
	if dead or i < 0 or i >= skills.size() or _debuff_ativo("atordoamento"):
		return
	if not casting.is_empty():
		message.emit("Já está conjurando")
		return
	var s: Dictionary = skills[i]
	var t := now()
	if t < float(cds[i]):
		return
	if mp < float(s.mp):
		message.emit("Mana insuficiente")
		return
	var ty := str(s.type)
	var offensive := ty in ["hit", "multi", "chain", "zone", "trap", "dash", "leap"]
	if offensive:
		if target == null or target.dead:
			next_target()
		if target == null:
			message.emit("Escolha um alvo")
			return
		var mg0: bool = (not bool(s.get("fisica", false))) if s.has("v2") else st.magic
		var reach: float = float(st.range) + (10.0 if mg0 or ty in ["dash", "leap"] else 1.2)
		if (target.node as Node3D).position.distance_to(main.player.position) > reach:
			auto = true
			message.emit("Longe demais: aproximando")
			return
	var conj := tempo_conj(s)
	if conj >= 0.2:
		_iniciar_conj(i, s, conj)
		return
	_executar(i)


# início da conjuração: gesto do corpo, círculo e elemento nas mãos; andar ou ser atordoado interrompe
func _iniciar_conj(i: int, s: Dictionary, conj: float) -> void:
	var t := now()
	casting = {"i": i, "ini": t, "fim": t + conj, "pos": main.player.position, "alvo": target, "nome": str(s.name)}
	if target:
		_face(target)
	var mg: bool = (not bool(s.get("fisica", false))) if s.has("v2") else st.magic
	var el := str(s.get("fx", ""))
	var kg := 1.0 + 0.12 * _grau_arma()
	var g := str(s.get("gesto", ""))
	if g == "":
		g = "erguer" if mg else "golpe"
	main.player.tocar_gesto(g, conj + 0.35)
	if mg:
		main.player.action("Spell_Simple_Shoot")
		FX.circulo_magico(main.player, el if el != "" else "arcane", conj + 0.25, 1.0 * kg)
	FX.reacao(main.player, el, "conjurador", main.player.height_m, 0.6 + 0.1 * _grau_arma())
	main.player.busy_until = t + conj
	if main.ui.has_method("cast_bar"):
		main.ui.cast_bar(str(s.name), 0.0, conj)


func _conj_tick(t: float) -> void:
	if casting.is_empty():
		return
	var ci: Dictionary = casting
	var mexeu: bool = main.player.position.distance_to(ci.pos) > 0.35
	var sem_alvo: bool = ci.alvo != null and ci.alvo.dead
	if dead or mexeu or _debuff_ativo("atordoamento") or sem_alvo:
		casting = {}
		main.player.busy_until = t
		if main.ui.has_method("cast_bar"):
			main.ui.cast_bar("", -1.0, 0.0)
		message.emit("Conjuração interrompida" if not sem_alvo else "Alvo perdido")
		return
	if t >= float(ci.fim):
		casting = {}
		if main.ui.has_method("cast_bar"):
			main.ui.cast_bar("", -1.0, 0.0)
		_executar(int(ci.i))
		return
	if main.ui.has_method("cast_bar"):
		main.ui.cast_bar(str(ci.nome), (t - float(ci.ini)) / maxf(float(ci.fim) - float(ci.ini), 0.01), float(ci.fim) - t)


func _executar(i: int) -> void:
	if i >= skills.size():
		return
	var s: Dictionary = skills[i]
	var t := now()
	var ty := str(s.type)
	var offensive := ty in ["hit", "multi", "chain", "zone", "trap", "dash", "leap"]
	if offensive and (target == null or target.dead):
		next_target()
		if target == null:
			return
	if mp < float(s.mp):
		message.emit("Mana insuficiente")
		return
	var v2 := s.has("v2")
	var mg: bool = (not bool(s.get("fisica", false))) if v2 else st.magic
	mp -= float(s.mp)
	cds[i] = t + float(s.cd)
	var fx_el := str(s.get("fx", ""))
	if fx_el == "":
		fx_el = my_elem if (mg or not offensive) else ""
	var arqueiro: bool = st.get("arco", false) and offensive and not mg
	if arqueiro:
		main.player.disparar_arco()  # habilidade de arqueiro: o mesmo tiro completo
	else:
		main.player.action("Spell_Simple_Shoot" if (mg or not offensive) else "Sword_Attack")
	# efeitos por tipo de habilidade: círculo de conjuração para magias, meia-lua de luz para golpes de arma.
	# O grau da arma aumenta o tamanho e acrescenta camadas (pedido de Robson 21/11: do NG ao SS a forma de
	# jogar a magia e a força elemental ficam bem destacadas): B clarão nas mãos, A segundo círculo e
	# rastro duplo, S projétil duplo e raio de luz, SS tudo maior.
	var gw := _grau_arma()
	var kg := 1.0 + 0.12 * gw
	# gesto do corpo conforme o tipo da habilidade (muda com a raça e o sexo) e o elemento nas mãos de quem solta
	var gesto := "golpe"
	if ty == "heal":
		gesto = "prece"
	elif ty in ["buff", "shield"]:
		gesto = "abrir"
	elif ty == "taunt":
		gesto = "rugir"
	elif ty == "dash":
		gesto = "investir"
	elif ty == "debuff":
		gesto = "apontar"
	elif mg:
		gesto = "erguer" if (float(s.get("aoe", 0.0)) > 0.0 or ty == "zone") else "empurrar"
	elif ty in ["multi", "chain"] or float(s.get("aoe", 0.0)) > 0.0:
		gesto = "girar"
	elif float(s.get("stun", 0.0)) > 0.0:
		gesto = "cravar"
	if v2 and str(s.get("gesto", "")) != "":
		gesto = str(s.gesto)
	if not arqueiro:
		main.player.tocar_gesto(gesto, 0.75 if not mg else 0.95)
	FX.reacao(main.player, fx_el, "conjurador", main.player.height_m, kg)
	var cor_el: Color = FX.colors(fx_el if fx_el != "" else "holy")[1]
	if mg or not offensive:
		var el_c := fx_el if fx_el != "" else "arcane"
		FX.circulo_magico(main.player, el_c, 0.85, (1.1 + 0.25 * float(s.get("aoe", 0.0) > 0.0)) * kg)
		if gw >= 4:
			get_tree().create_timer(0.12).timeout.connect(func(): if is_instance_valid(main.player): FX.circulo_magico(main.player, el_c, 0.7, 1.9 * kg))
		if gw >= 3:
			FX.flare(self, _chest() + Vector3(0, 0.25, 0), FX.colors(el_c)[0], 0.6 + 0.15 * gw, 0.4)
	elif not arqueiro:
		var golpes := 2 if ty in ["multi", "chain"] else 1
		for g in golpes:
			var inc := 0.35 if g == 0 else -0.45
			if g == 0:
				FX.corte(main.player, cor_el.lerp(Color(1, 0.95, 0.8), 0.4), 1.6 * (1.0 + 0.07 * gw), 1.15, inc)
				if gw >= 4:  # rastro duplo
					FX.corte(main.player, cor_el, 1.9 * (1.0 + 0.07 * gw), 1.3, inc + 0.25)
			else:
				get_tree().create_timer(0.14).timeout.connect(func(): if is_instance_valid(main.player): FX.corte(main.player, cor_el, 1.7, 1.0, inc))
	main.player.busy_until = t + 0.55
	if offensive:
		auto = true
		_face(target)
		var mult := float(s.mult) if float(s.mult) > 0.0 else 1.2
		var list: Array = [target]
		# forma do ataque pelo tipo da habilidade (banco v2)
		var tpos: Vector3 = (target.node as Node3D).global_position
		match str(s.get("v2", "")):
			"area":
				if mg:  # magia em área: o elemento cai do céu sobre a zona
					FX.chuva(self, tpos, fx_el, 3.2 * kg, 5 + gw, 0.6)
				else:  # golpe em área: giro com dois cortes e onda no chão em volta de quem golpeia
					FX.onda_choque(self, main.player.global_position, fx_el, 3.0 * kg, 0.4)
					FX.corte(main.player, cor_el, 2.2 * kg, 0.9, 0.05, 0.3)
			"atordoar":
				FX.onda_choque(self, tpos, fx_el, 2.4 * kg, 0.45)
			"prender":
				FX.espinhos(self, tpos, fx_el, maxf(0.9, float(target.height) * 0.45), 7, float(s.stun))
			"critico":
				FX.corte_x(main.player, cor_el, 1.8 * kg)
			"puxar":
				FX.relampago(self, _chest(), _center(target), FX.colors(fx_el)[0])
			"dreno":
				var alvo_d = target
				get_tree().create_timer(0.35).timeout.connect(func():
					if alvo_d != null and is_instance_valid(alvo_d.node):
						FX.magia(self, _center(alvo_d), _chest(), fx_el, 0.35))
			"avanco":
				FX.onda_choque(self, main.player.global_position, "vento", 1.6, 0.3)
		if mg:
			FX.magia(self, _chest() + Vector3(0, 0.3, 0), _center(target), fx_el)
			if gw >= 5:  # projétil duplo e raio de luz até o alvo
				var alvo_m = target
				get_tree().create_timer(0.1).timeout.connect(func():
					if alvo_m != null and is_instance_valid(alvo_m.node):
						FX.magia(self, _chest() + Vector3(0.3, 0.5, 0), _center(alvo_m), fx_el)
						FX.relampago(self, _chest() + Vector3(0, 0.4, 0), _center(alvo_m), FX.colors(fx_el if fx_el != "" else "raio")[0]))
		if float(s.aoe) > 0.0 or ty == "zone":
			FX.zona(self, (target.node as Node3D).global_position, fx_el if fx_el != "" else "arcane", clampf(maxf(float(s.aoe), 4.0), 3.0, 7.0) * kg, 1.0)
		if float(s.aoe) > 0.0 or ty in ["multi", "chain", "zone"]:
			var rad := maxf(float(s.aoe), 5.0)
			for m in mobs:
				if m != target and not m.dead and (m.node as Node3D).position.distance_to((target.node as Node3D).position) < rad:
					list.append(m)
		for m in list:
			var keep = target
			target = m
			var r := _damage(mult, fx_el if v2 else "", float(s.get("crit_extra", 0.0)), (0 if mg else 1) if v2 else -1)
			target = keep
			if r.get("vant", 1.0) > 1.01 and m == list[0]:
				_float_text(_center(m) + Vector3(0, 0.6, 0), "Vantagem!", FX.colors(fx_el)[0], 0.8)
			if str(s.get("v2", "")) == "dreno" or float(pb.get("dreno", 0.0)) > 0.0:
				hp = minf(st.maxHp, hp + r.dmg * (0.3 if str(s.get("v2", "")) == "dreno" else 0.0) + r.dmg * float(pb.get("dreno", 0.0)))
			if str(s.get("v2", "")) == "puxar" and m == list[0]:
				var alvo_n: Node3D = m.node
				var frente: Vector3 = main.player.position + (alvo_n.position - main.player.position).normalized() * 1.8
				create_tween().tween_property(alvo_n, "position", Vector3(frente.x, alvo_n.position.y, frente.z), 0.3)
			pending.append({"t": t + 0.35, "mob": m, "dmg": r.dmg, "crit": r.crit, "fx": fx_el, "size": kg})
			if float(s.stun) > 0.0:
				m.stun = t + float(s.stun)
	elif ty == "heal":
		var amount: float = st.maxHp * float(s.pct) if float(s.pct) > 0.0 else float(st.matk) * maxf(float(s.mult), 1.0) * 2.0
		hp = minf(st.maxHp, hp + amount)
		_float_text(main.player.position + Vector3(0, main.player.height_m, 0), "+%d" % int(amount), Color(0.5, 1.0, 0.6))
		FX.coluna(self, main.player.global_position, fx_el if fx_el != "" else "holy", 5.0 * kg, 0.9 * kg, 1.0)
		if str(s.get("v2", "")) in ["cura_area", "reviver"]:
			FX.onda_choque(self, main.player.global_position, fx_el if fx_el != "" else "luz", 5.0, 0.8)
		if str(s.get("v2", "")) == "purificar":
			debuffs.clear()
		FX.burst(self, _chest(), fx_el if fx_el != "" else "holy", 1.1)
	elif ty == "shield":
		shield = st.maxHp * maxf(float(s.pct), 0.15)
		shield_until = t + maxf(float(s.dur), 8.0)
		FX.aura(main.player, fx_el if fx_el != "" else "ice", maxf(float(s.dur), 8.0))
	elif ty == "buff" and s.buff is Dictionary:
		for k in s.buff:
			buffs.append({"k": k, "v": float(s.buff[k]), "until": t + maxf(float(s.dur), 8.0)})
		recalc()
		FX.aura(main.player, fx_el if fx_el != "" else "holy", maxf(float(s.dur), 8.0))
	elif ty in ["debuff", "taunt"]:
		FX.burst(self, main.player.position + Vector3(0, 0.3, 0), fx_el if fx_el != "" else "dark", 2.2)
		FX.onda_choque(self, main.player.global_position, fx_el if fx_el != "" else "sombra", maxf(float(s.aoe), 6.0), 0.6)
		for m in mobs:
			if not m.dead and (m.node as Node3D).position.distance_to(main.player.position) < maxf(float(s.aoe), 8.0):
				m.aggro = true
				if ty == "debuff":
					m.weak = t + maxf(float(s.dur), 8.0)
	message.emit(str(s.name))


func _chest() -> Vector3:
	return main.player.position + Vector3(0, main.player.height_m * 0.6, 0)


func _center(m) -> Vector3:
	return (m.node as Node3D).position + Vector3(0, float(m.height) * 0.55, 0)


func _face(m) -> void:
	var d: Vector3 = (m.node as Node3D).position - main.player.position
	main.facing = atan2(d.x, d.z)
	main.player.rotation.y = main.facing


# anel do alvo no chão: quem está selecionado fica com um círculo girando nos pés (como nos MMOs clássicos)
var _anel: MeshInstance3D
const ANEL_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 cor : source_color = vec3(1.0, 0.75, 0.2);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float a = atan(p.y, p.x);
	float anel = smoothstep(0.80, 0.86, d) * (1.0 - smoothstep(0.92, 0.98, d));
	float tracos = step(0.0, sin(a * 3.0 - TIME * 2.4)) * smoothstep(0.66, 0.70, d) * (1.0 - smoothstep(0.74, 0.78, d));
	float miolo = (1.0 - smoothstep(0.0, 0.9, d)) * 0.08 * step(d, 1.0);
	ALBEDO = cor * (anel * 1.3 + tracos * 0.9 + miolo) * (0.85 + 0.15 * sin(TIME * 4.0));
}
"""


func _anel_alvo() -> void:
	var ok: bool = target != null and not target.dead and is_instance_valid(target.node)
	if not ok:
		if _anel != null:
			_anel.visible = false
		return
	if _anel == null:
		_anel = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE
		_anel.mesh = pm
		var mt := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = ANEL_SHADER
		mt.shader = sh
		_anel.material_override = mt
		_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_anel)
	var n: Node3D = target.node
	var r := clampf(float(target.get("height", 1.8)) * 0.36, 0.7, 3.0)
	_anel.visible = true
	_anel.global_position = n.global_position + Vector3(0, 0.06, 0)
	_anel.scale = Vector3(r * 2.0, 1, r * 2.0)


func _physics_process(dt: float) -> void:
	if not active:
		return
	_anel_alvo()
	var t := now()
	_manage_spawns(dt)
	for m in mobs:
		_mob_tick(m, dt)
	for i in range(pending.size() - 1, -1, -1):
		if t >= float(pending[i].t):
			_hit_mob(pending[i].mob, pending[i].dmg, pending[i].crit)
			if is_instance_valid(pending[i].mob.node):
				FX.burst(self, _center(pending[i].mob), str(pending[i].get("fx", "")), float(pending[i].get("size", 0.6)))
				var mn: Node3D = pending[i].mob.node
				FX.reacao(mn, str(pending[i].get("fx", "")), "alvo", maxf(1.0, (_center(pending[i].mob).y - mn.global_position.y) * 1.8), float(pending[i].get("size", 1.0)))
				if pending[i].crit or float(pending[i].get("size", 0.6)) >= 1.0:  # golpe forte: clarão no impacto
					FX.flare(self, _center(pending[i].mob), FX.colors(str(pending[i].get("fx", "")))[0], 1.2 if pending[i].crit else 0.9, 0.3)
			pending.remove_at(i)
	_debuffs_tick(dt)
	_conj_tick(t)
	if dead:
		debuffs.clear()
		if t - dead_t > 4.0 and dead_t > 0.0:
			dead_t = 0.0
			_revive()
		return
	if buffs.size() > 0 and buffs.any(func(b): return b.until <= t):
		buffs = buffs.filter(func(b): return b.until > t)
		recalc()
	# regeneração: lenta em combate, rápida fora
	var k := 0.004 if t < combat_until else 0.03
	hp = minf(st.maxHp, hp + st.maxHp * k * dt)
	mp = minf(st.maxMp, mp + st.maxMp * (0.012 if t < combat_until else 0.04) * dt)
	if target and target.dead:
		target = null
		auto = false
	if auto and target and casting.is_empty():
		var tp: Vector3 = (target.node as Node3D).position
		var d := Vector2(tp.x - main.player.position.x, tp.z - main.player.position.z).length()
		var reach: float = float(st.range) + float(target.height) * 0.3 + (9.0 if st.magic else 0.0)
		if d > reach:
			main.target = tp
			main.has_target = true
			main.chasing = true
		else:
			main.has_target = false
			main.chasing = false
			if t >= next_atk and not main.player.is_busy():
				next_atk = t + float(st.interval) * 1.15
				_face(target)
				swing += 1
				var r := _damage(1.0)
				if st.get("arco", false) and not st.magic:
					# arco: ergue, puxa a corda até a boca e solta; a flecha sai na hora da soltura e voa até o alvo
					main.player.disparar_arco()
					var de := _chest() + Vector3(0, 0.25, 0)
					var ate := _center(target)
					get_tree().create_timer(0.62).timeout.connect(func(): FX.flecha(self, de, ate, clampf(de.distance_to(ate) / 40.0, 0.12, 0.6)))
					pending.append({"t": t + 0.62 + clampf(de.distance_to(ate) / 40.0, 0.12, 0.6), "mob": target, "dmg": r.dmg, "crit": r.crit, "fx": "", "size": 0.55})
				else:
					main.player.action("Spell_Simple_Shoot" if st.magic else ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"][swing % 3])
					main.player.busy_until = t + 0.5
					pending.append({"t": t + 0.3, "mob": target, "dmg": r.dmg, "crit": r.crit, "fx": my_elem if st.magic else "", "size": 0.55})
				if st.magic:
					FX.bolt(self, _chest(), _center(target), my_elem)
	else:
		main.chasing = false


# ---------- GM ----------
func gm_kill(m: Dictionary, reward := true) -> void:
	if m.dead:
		return
	if reward:
		_hit_mob(m, float(m.hp) + 1.0, false)
	else:
		m.dead = true
		if is_instance_valid(m.node):
			(m.node as Node3D).queue_free()
		mobs.erase(m)
		if target == m:
			target = null


func gm_area(r: float, reward: bool) -> int:
	var pp: Vector3 = main.player.position
	var hit: Array = mobs.filter(func(m): return not m.dead and (m.node as Node3D).position.distance_to(pp) <= r)
	for m in hit:
		gm_kill(m, reward)
	return hit.size()


func gm_spawn(fam_id: String, x: float, z: float) -> bool:
	for band in info.mobs:
		for f in band:
			if str(f.id) == fam_id:
				_spawn(x, z, bool(f.boss), int(main.me.get("level", 1)), "gm", f)
				return true
	return false
