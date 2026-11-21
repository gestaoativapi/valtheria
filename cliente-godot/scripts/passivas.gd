class_name Passivas
extends RefCounted
## Passivas de equipamento, buff e acessório (iguais para todos): valem enquanto a condição for verdadeira.
## Dados em data/classes_v2.json -> "passivas_equipamento". Cada grau acima do NG soma +15% ao bônus positivo.

const PECAS := ["armadura", "elmo", "luvas", "botas"]


static func dados() -> Dictionary:
	var cv: Dictionary = load("res://scripts/ui.gd").classes_v2()
	return cv.get("passivas_equipamento", {})


# contexto: {"grupo": membros por perto contando você, "montado": bool, "pet": bool, "buffs": [nomes], "noite": bool}
static func ativas(me: Dictionary, items: Dictionary, ctx: Dictionary = {}) -> Array:
	var eq: Dictionary = me.get("equipment") if me.get("equipment") is Dictionary else {}
	var en: Dictionary = me.get("enchant") if me.get("enchant") is Dictionary else {}
	var out: Array = []
	for pid in dados():
		var p: Dictionary = dados()[pid]
		var c: Dictionary = p.condicao
		var grau := 0
		var ok := true
		if c.has("arma"):
			var it: Dictionary = items.get(str(eq.get("arma", "")), {})
			ok = str(it.get("kind", "")) == str(c.arma)
			grau = int(it.get("grade", 0))
		if ok and c.has("escudo"):
			var id := str(eq.get("escudo", ""))
			var it: Dictionary = items.get(id, {})
			var k := str(it.get("kind", ""))
			if id.begins_with("egide"):
				k = "egide"
			ok = id != "" and k == str(c.escudo)
			grau = int(it.get("grade", 0))
		if ok and (c.has("conjunto") or c.has("conjunto_grau")):
			var n := 0
			var gmin := 9
			for sl in PECAS:
				var id := str(eq.get(sl, ""))
				var it: Dictionary = items.get(id, {})
				if it.is_empty():
					continue
				var k := str(it.get("kind", ""))
				for t in ["pesada", "leve", "robe"]:
					if t in id:
						k = t
				if c.has("conjunto") and k != str(c.conjunto):
					continue
				n += 1
				gmin = mini(gmin, int(it.get("grade", 0)))
			ok = n >= int(c.get("pecas", 4))
			grau = gmin if ok else 0
			if ok and c.has("conjunto_grau"):
				ok = gmin >= int(c.conjunto_grau)
		if ok and c.has("encanto_arma"):
			ok = int(en.get(str(eq.get("arma", "")), 0)) >= int(c.encanto_arma)
		if ok and c.has("item"):
			ok = false
			for sl in eq:
				if str(items.get(str(eq[sl]), {}).get("kind", "")) == "wings":
					ok = true
		if ok and c.has("acessorio"):
			ok = str(eq.get(str(c.acessorio), "")) != ""
			grau = int(items.get(str(eq.get(str(c.acessorio), "")), {}).get("grade", 0))
		if ok and c.has("montaria"):
			ok = bool(ctx.get("montado", false))
		if ok and c.has("pet"):
			ok = bool(ctx.get("pet", false))
		if ok and c.has("grupo"):
			ok = int(ctx.get("grupo", 1)) >= int(c.grupo)
		if ok and c.has("buff"):
			ok = str(c.buff) in ctx.get("buffs", []) or (str(c.buff) == "noite" and bool(ctx.get("noite", false)))
		if ok and c.has("raca"):
			ok = str(me.get("race", "")) in c.raca
		if ok:
			out.append({"p": p, "grau": grau})
	return out


# soma dos bônus das passivas ativas
static func bonus(lista: Array) -> Dictionary:
	var b := {}
	for e in lista:
		var f := 1.0 + float(e.p.get("por_grau", 0.15)) * float(e.grau)
		for k in e.p.bonus:
			var v := float(e.p.bonus[k])
			b[k] = float(b.get(k, 0.0)) + (v * f if v > 0.0 else v)
	return b


static func texto_bonus(p: Dictionary, grau: int) -> String:
	const NOME := {"atq_fis": "ataque físico", "atq_mag": "ataque mágico", "def_fis": "defesa física", "def_mag": "defesa mágica", "hp": "vida máx.", "mp": "mana máx.",
		"vel_atq": "vel. de ataque", "vel_conj": "vel. de conjuração", "vel_mov": "deslocamento", "critico": "chance de crítico", "cura": "cura",
		"regen_hp": "regeneração de vida", "regen_mp": "regeneração de mana", "dreno": "vida roubada por golpe", "bloqueio": "chance de bloquear",
		"atordoar": "chance de atordoar", "resist_atordoar": "resistência a atordoar", "precisao": "precisão", "esquiva": "esquiva", "alcance": "alcance (m)"}
	var f := 1.0 + float(p.get("por_grau", 0.15)) * grau
	var l: Array = []
	for k in p.bonus:
		var v := float(p.bonus[k])
		v = v * f if v > 0.0 else v
		l.append(("%+d %s" % [roundi(v), NOME.get(k, k)]) if k in ["precisao", "esquiva", "alcance"] else ("%+.1f%% %s" % [v * 100.0, NOME.get(k, k)]))
	return ", ".join(l)
