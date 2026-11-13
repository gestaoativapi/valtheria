extends Node3D
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


func setup(m: Node3D) -> void:
	main = m
	world = m.world
	info = world.info
	rng.randomize()


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
		"range": float(wk.get("range", 2.2)),
		"interval": float(wk.get("spd", 1.0)) / _buff("atkspd"),
		"magic": bool(wk.get("magic", false)) or str(arch.get("atk", "p")) == "m",
		"class": str(cl.get("name", "")),
	}
	my_elem = str(info.get("race_elem", {}).get(str(c.get("race", "")), ""))
	skills = []
	for s in arch.skills:
		if int(s.lvl) <= L and skills.size() < 6:
			skills.append(s)
	while cds.size() < skills.size():
		cds.append(0.0)


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
	var k := clampf((nt.dist - 70.0) / 450.0, 0.0, 1.0)
	return {"L": maxi(1, roundi(float(t.min) + (float(t.max) - float(t.min)) * k)), "band": int(t.band), "dist": nt.dist}


func _mob_model(fam: Dictionary) -> Dictionary:
	var id := str(fam.id)
	var sc := float(fam.scale)
	var node: Node3D
	var kind := "glb"
	var height := 1.0
	match str(fam.model):
		"humanoid", "golem", "ent", "dragon":
			kind = "char"
			var o := {"race": "humano", "gender": "m", "hair": 0, "equipment": {"armadura": "pesada_ng", "arma": "espada_ng"}}
			if id == "bandido":
				o = {"race": "orc", "gender": "m", "hair": 0, "equipment": {"armadura": "leve_ng", "arma": "machado_ng"}}
			elif id == "esqueleto":
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
			node = Character.create(o)
			node.scale = Vector3.ONE * sc
			height = node.height_m * sc
		_:
			var file := "m_wolf"
			var target_h := 0.95
			if id.contains("javali"):
				file = "a_bull"
				target_h = 1.15
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
			holder.add_child(sc_node)
			node = holder
			height = target_h * sc
	return {"node": node, "kind": kind, "height": height}


func _spawn(x: float, z: float) -> void:
	var li := _level_at(x, z)
	var fams: Array = (info.mobs[clampi(li.band, 0, info.mobs.size() - 1)] as Array).filter(func(f): return not f.boss)
	var fam: Dictionary = fams[rng.randi() % fams.size()]
	var L: int = clampi(int(li.L) + rng.randi_range(-1, 1), 1, 92)
	var ms: Array = info.mobstats[L - 1]
	var md := _mob_model(fam)
	var node: Node3D = md.node
	add_child(node)
	node.position = Vector3(x, world.height(x, z), z)
	node.rotation.y = rng.randf() * TAU
	var lb := Label3D.new()
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.pixel_size = 0.003
	lb.font_size = 56
	lb.outline_size = 12
	lb.text = "%s  Nv %d" % [fam.name, L]
	var diff := L - int(main.me.get("level", 1))
	lb.modulate = Color(1, 0.35, 0.35) if diff >= 5 else (Color(1, 0.85, 0.35) if diff >= 2 else (Color.WHITE if diff >= -2 else Color(0.55, 0.8, 0.6)))
	lb.position = Vector3(0, (float(md.height) + 0.35) / maxf(node.scale.y, 0.01), 0)
	lb.visibility_range_end = 45.0
	node.add_child(lb)
	var m := {"fam": fam, "L": L, "hp": float(ms[0]), "maxHp": float(ms[0]), "atk": float(ms[1]), "def": float(ms[2]), "xp": float(ms[3]), "node": node, "kind": md.kind, "home": node.position,
		"aggro": false, "next_atk": 0.0, "stun": 0.0, "wander": node.position, "wander_t": rng.randf() * 4.0, "dead": false, "dead_t": 0.0, "weak": 0.0, "anim": "", "height": md.height}
	m.ap = node.anim if md.kind == "char" else node.find_child("AnimationPlayer", true, false)
	_mob_anim(m, "idle")
	mobs.append(m)


func _mob_anim(m: Dictionary, what: String) -> void:
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
	var want: Array = {"idle": ["Idle"], "walk": ["Walk"], "run": ["Gallop", "Walk"], "attack": ["Attack", "Attack_Headbutt"], "death": ["Death"], "hit": ["Idle_HitReact1", "Idle_HitReact_Left"]}.get(what, ["Idle"])
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
		var far: bool = (m.node.position as Vector3).distance_to(p) > 150.0 and not m.aggro
		if far or (m.dead and now() - float(m.dead_t) > 5.0):
			if target == m:
				target = null
				auto = false
			m.node.queue_free()
			mobs.remove_at(i)
	var alive := mobs.filter(func(m): return not m.dead).size()
	var tries := 0
	while alive < 12 and tries < 8:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(35.0, 95.0)
		var x := p.x + sin(a) * r
		var z := p.z + cos(a) * r
		if x < 30.0 or z < 30.0 or x > world.size - 30.0 or z > world.size - 30.0:
			continue
		if world.nearest_town(x, z).dist < 115.0 or world.height(x, z) < 1.2 or world.normal(x, z).y < 0.85 or world.ground(x, z).r > 0.5:
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
	if not m.aggro and m.fam.aggro and not dead and d < 11.0 and world.nearest_town(pp.x, pp.z).dist > 80.0:
		m.aggro = true
	if m.aggro and (dead or (node.position as Vector3).distance_to(m.home) > 55.0):
		m.aggro = false
		m.hp = m.maxHp
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
			m.wander_t = rng.randf_range(4.0, 9.0)
			var a := rng.randf() * TAU
			m.wander = (m.home as Vector3) + Vector3(sin(a), 0, cos(a)) * rng.randf_range(2.0, 9.0)
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


# ---------- dano ----------
func _float_text(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.004
	l.font_size = 72
	l.outline_size = 14
	l.text = text
	l.modulate = col
	l.position = pos + Vector3(rng.randf_range(-0.3, 0.3), 0, 0)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position", l.position + Vector3(0, 1.3, 0), 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


func _hurt_player(dmg: float) -> void:
	if dead:
		return
	combat_until = now() + 6.0
	if shield > 0.0 and now() < shield_until:
		var ab := minf(shield, dmg)
		shield -= ab
		dmg -= ab
	hp -= dmg
	_float_text(main.player.position + Vector3(0, main.player.height_m, 0), "-%d" % int(dmg), Color(1, 0.4, 0.35))
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
	_float_text((m.node as Node3D).position + Vector3(0, float(m.height), 0), ("%d!" if crit else "%d") % int(dmg), Color(1, 0.85, 0.3) if crit else Color.WHITE)
	if float(m.hp) <= 0.0:
		m.dead = true
		m.dead_t = now()
		m.anim = ""
		_mob_anim(m, "death")
		if target == m:
			target = null
			auto = false
		_reward(m)


func _reward(m: Dictionary) -> void:
	var c: Dictionary = main.me
	var lvl := int(c.get("level", 1))
	var L := int(m.L)
	var pen := 1.0
	if L < lvl - 5:
		pen = maxf(0.1, 1.0 - (lvl - 5 - L) * 0.15)
	var gain := roundi(float(m.xp) * pen * float(info.get("rate_xp", 1.0)))
	c.xp = float(c.get("xp", 0)) + gain
	var up := false
	while lvl < 80 and float(c.xp) >= float(info.xpneed[lvl - 1]):
		c.xp = float(c.xp) - float(info.xpneed[lvl - 1])
		lvl += 1
		up = true
	c.level = lvl
	_float_text(main.player.position + Vector3(0, main.player.height_m + 0.5, 0), "+%d XP" % gain, Color(0.6, 0.85, 1.0))
	if up:
		recalc()
		hp = st.maxHp
		mp = st.maxMp
		main.ui.set_skills(skills)
		main.ui.set_who(c)
		message.emit("Nível %d!" % lvl)
	if c.has("id") and main.net.token != "":
		main.net.rpc_call("game_kill3", {"p_char": main.net.char_id, "p_mob_level": L, "p_boss": false, "p_fam": str(m.fam.id)})


func _damage(mult: float) -> Dictionary:
	var atk: float = st.matk if st.magic else st.patk
	var def: float = float(target.def) if target else 0.0
	var crit := rng.randf() < 0.06
	var dmg := atk * mult * atk / (atk + def * 0.5) * rng.randf_range(0.92, 1.08) * (2.0 if crit else 1.0)
	return {"dmg": dmg, "crit": crit}


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
	if dead or i < 0 or i >= skills.size():
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
		var reach: float = float(st.range) + (10.0 if st.magic or ty in ["dash", "leap"] else 1.2)
		if (target.node as Node3D).position.distance_to(main.player.position) > reach:
			auto = true
			message.emit("Longe demais: aproximando")
			return
	mp -= float(s.mp)
	cds[i] = t + float(s.cd)
	var fx_el := str(s.get("fx", ""))
	if fx_el == "":
		fx_el = my_elem if (st.magic or not offensive) else ""
	main.player.action("Spell_Simple_Shoot" if (st.magic or not offensive) else "Sword_Attack")
	main.player.busy_until = t + 0.55
	if offensive:
		auto = true
		_face(target)
		var mult := float(s.mult) if float(s.mult) > 0.0 else 1.2
		var list: Array = [target]
		if st.magic:
			FX.bolt(self, _chest(), _center(target), fx_el)
		if float(s.aoe) > 0.0 or ty in ["multi", "chain", "zone"]:
			var rad := maxf(float(s.aoe), 5.0)
			for m in mobs:
				if m != target and not m.dead and (m.node as Node3D).position.distance_to((target.node as Node3D).position) < rad:
					list.append(m)
		for m in list:
			var keep = target
			target = m
			var r := _damage(mult)
			target = keep
			pending.append({"t": t + 0.35, "mob": m, "dmg": r.dmg, "crit": r.crit, "fx": fx_el, "size": 1.0})
			if float(s.stun) > 0.0:
				m.stun = t + float(s.stun)
	elif ty == "heal":
		var amount: float = st.maxHp * float(s.pct) if float(s.pct) > 0.0 else float(st.matk) * maxf(float(s.mult), 1.0) * 2.0
		hp = minf(st.maxHp, hp + amount)
		_float_text(main.player.position + Vector3(0, main.player.height_m, 0), "+%d" % int(amount), Color(0.5, 1.0, 0.6))
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


func _physics_process(dt: float) -> void:
	if not active:
		return
	var t := now()
	_manage_spawns(dt)
	for m in mobs:
		_mob_tick(m, dt)
	for i in range(pending.size() - 1, -1, -1):
		if t >= float(pending[i].t):
			_hit_mob(pending[i].mob, pending[i].dmg, pending[i].crit)
			if is_instance_valid(pending[i].mob.node):
				FX.burst(self, _center(pending[i].mob), str(pending[i].get("fx", "")), float(pending[i].get("size", 0.6)))
			pending.remove_at(i)
	if dead:
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
	if auto and target:
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
				main.player.action("Spell_Simple_Shoot" if st.magic else ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"][swing % 3])
				main.player.busy_until = t + 0.5
				var r := _damage(1.0)
				pending.append({"t": t + 0.3, "mob": target, "dmg": r.dmg, "crit": r.crit, "fx": my_elem if st.magic else "", "size": 0.55})
				if st.magic:
					FX.bolt(self, _chest(), _center(target), my_elem)
	else:
		main.chasing = false
