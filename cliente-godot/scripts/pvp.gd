extends Node
# PEDIDO 006: PvP com o servidor como autoridade. SÓ no executável de teste (net.ambiente_teste()).
# O cliente só pede o golpe (game_pvp2); o servidor confere vida, zona de paz, distância, ritmo,
# recarga da habilidade e posição recente, calcula o dano e grava a vida do alvo.
# O alvo é avisado pelo canal ("h") e relê a própria vida NO SERVIDOR (o aviso em si não vale como dano).

var main: Node3D
var alvo := ""  # id do personagem atacado
var t_golpe := 0.0
var t_salvar := 0.0
var _swing := 0
var _aguardando := false


func setup(m: Node3D) -> void:
	main = m
	main.net.remote_pvp.connect(_rx)


func atacar(id: String) -> void:
	if main.combat.dead or id == "" or id == str(main.me.get("id", "")):
		return
	alvo = id
	t_golpe = 0.0
	main.combat.target = null
	main.combat.stop_auto()
	var o: Dictionary = main.social.others.get(id, {})
	main.ui.say("Atacando %s (PvP)" % str(o.get("name", "?")))


func parar() -> void:
	alvo = ""
	if main.player:
		main.player.em_guarda = false


func _alcance() -> float:
	var p = main.player
	return 30.0 if p.magic_idle else 5.0


func _process(dt: float) -> void:
	if alvo == "" or not main.playing:
		return
	if main.combat.dead:
		parar()
		return
	var o: Dictionary = main.social.others.get(alvo, {})
	if o.is_empty() or not is_instance_valid(o.get("node")):
		main.ui.say("Alvo fora de vista")
		parar()
		return
	var node: Node3D = o.node
	var p: Node3D = main.player
	main.combat.combat_until = main.combat.now() + 6.0
	p.em_guarda = true
	var d: Vector2 = Vector2(node.position.x - p.position.x, node.position.z - p.position.z)
	if d.length() > _alcance():
		main.target = node.position  # anda até o alvo
		main.has_target = true
		return
	main.has_target = false
	p.rotation.y = atan2(d.x, d.y)
	# posição recente no servidor (ele recusa golpe com posição de mais de 10 s)
	t_salvar -= dt
	if t_salvar <= 0.0:
		t_salvar = 2.0
		main._save_now(true)
	t_golpe -= dt
	if t_golpe <= 0.0 and not _aguardando and not p.is_busy():
		t_golpe = 1.0  # o servidor aceita no máximo 1 golpe a cada 0,8 s
		_golpe(o)


func _golpe(o: Dictionary) -> void:
	var p = main.player
	_swing += 1
	p.action("Spell_Simple_Shoot" if p.magic_idle else ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"][_swing % 3])
	_aguardando = true
	var id := alvo
	var r: Dictionary = await main.net.rpc_call("game_pvp2", {"p_char": main.net.char_id, "p_target": id})
	_aguardando = false
	if not r.ok or not (r.data is Dictionary):
		main.ui.say(str(r.get("erro", "Falha no golpe")))
		return
	var dd: Dictionary = r.data
	if dd.has("recusado"):
		if str(dd.recusado) != "Golpes rápidos demais":
			main.ui.say(str(dd.recusado))
		if str(dd.recusado) in ["O alvo já caiu", "Zona de paz", "Alvo inválido"]:
			parar()
		return
	main.net.rt_pvp({"a": id, "b": main.net.char_id})
	if is_instance_valid(o.get("node")):
		var n: Node3D = o.node
		main.combat._float_text(n.position + Vector3(0, float(n.get("height_m") if n.get("height_m") != null else 1.8), 0),
			"-%d" % int(dd.get("dmg", 0)), Color(1.0, 0.85, 0.3) if bool(dd.get("crit", false)) else Color(1, 0.55, 0.4), 1.3 if bool(dd.get("crit", false)) else 1.0)
		if n.has_method("action"):
			n.action("Hit_Chest")
	if main.social.others.has(id):
		main.social.others[id].hp = 100.0 * float(dd.get("target_hp", 0.0)) / maxf(float(dd.get("target_max", 1.0)), 1.0)
	if bool(dd.get("killed", false)):
		main.ui.say("Você derrubou o adversário" + (" (PK: karma aumentou)" if bool(dd.get("pk", false)) else ""))
		parar()


# aviso de golpe recebido: relê a vida no servidor (fonte da verdade)
func _rx(pl: Dictionary) -> void:
	if str(pl.get("a", "")) != main.net.char_id or main.combat.dead:
		return
	var r: Dictionary = await main.net.rpc_call("game_state", {"p_char": main.net.char_id})
	if not r.ok or not (r.data is Dictionary) or not ((r.data as Dictionary).get("char") is Dictionary):
		return
	var hp_srv := float(r.data.char.get("hp", main.combat.hp))
	if hp_srv >= main.combat.hp:
		return
	var dano: float = main.combat.hp - hp_srv
	main.combat.hp = hp_srv
	main.combat.combat_until = main.combat.now() + 6.0
	main.combat._float_text(main.player.position + Vector3(0, main.player.height_m, 0), "-%d" % int(dano), Color(1, 0.4, 0.35))
	main.tremer(0.05)
	if main.ui.has_method("flash_dano"):
		main.ui.flash_dano(0.6)
	if not main.player.is_busy():
		main.player.action("Hit_Head" if randf() < 0.35 else "Hit_Chest")
	var atacante := str(pl.get("b", ""))
	if alvo == "" and main.social.others.has(atacante):
		main.ui.say("%s está atacando você" % str(main.social.others[atacante].get("name", "?")))
	if hp_srv <= 0.0:
		main.combat._die()
