# V2 — gera os corpos de avaliação (masculino e feminino) com o MPFB2. Roda isolado, fora do repositório.
import sys, bpy, addon_utils, importlib, json
bpy.ops.wm.read_factory_settings(use_empty=True)
addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
def imp(p, k):
    for m in list(sys.modules):
        if m.endswith(p): return getattr(importlib.import_module(m), k)
HumanService = imp("mpfb.services.humanservice", "HumanService")
TargetService = imp("mpfb.services.targetservice", "TargetService")

def altura(o):
    zs = [(o.matrix_world @ v.co).z for v in o.data.vertices if True]
    return max(zs) - min(zs)

def visivel_altura(o):
    # altura sem a geometria auxiliar (grupo HelperGeometry)
    gi = o.vertex_groups.get("HelperGeometry")
    dg = bpy.context.evaluated_depsgraph_get()
    ev = o.evaluated_get(dg); me = ev.to_mesh()
    zs = [(o.matrix_world @ v.co).z for v in me.vertices]
    h = max(zs) - min(zs); ev.to_mesh_clear(); return h

def criar(nome, macro, alvo, rig_tipo):
    lo, hi = 0.0, 1.0
    h = None
    for i in range(9):
        macro["height"] = (lo + hi) / 2
        bpy.ops.wm.read_factory_settings(use_empty=True)
        hum = HumanService.create_human(macro_detail_dict=dict(macro))
        h = visivel_altura(hum)
        if h < alvo: lo = macro["height"]
        else: hi = macro["height"]
    rig = HumanService.add_builtin_rig(hum, rig_tipo)
    hum.name = nome; rig.name = nome + "_rig"
    # congela as formas (alvos do MPFB) e remove a geometria auxiliar
    bpy.context.view_layer.objects.active = hum
    if hum.data.shape_keys:
        hum.shape_key_add(name="final", from_mix=True)
        for kb in list(hum.data.shape_keys.key_blocks):
            if kb.name != "final": hum.shape_key_remove(kb)
        hum.shape_key_remove(hum.data.shape_keys.key_blocks["final"])
    for md in list(hum.modifiers):
        if md.type == "MASK":
            bpy.ops.object.modifier_apply(modifier=md.name)
    tris = sum(len(p.vertices) - 2 for p in hum.data.polygons)
    info = {"nome": nome, "altura_m": round(visivel_altura(hum), 3), "vertices": len(hum.data.vertices), "triangulos": tris,
            "ossos": len(rig.data.bones), "rig": rig_tipo, "macro": macro,
            "ossos_nomes": [b.name for b in rig.data.bones]}
    bpy.ops.object.select_all(action="DESELECT")
    hum.select_set(True); rig.select_set(True)
    bpy.ops.export_scene.gltf(filepath=f"/home/claude/v2/saida/{nome}.glb", use_selection=True, export_skins=True, export_animations=False, export_yup=True)
    return info

res = []
res.append(criar("v2_corpo_masculino", {"gender": 1.0, "age": 0.5, "muscle": 0.65, "weight": 0.5, "proportions": 0.8, "height": 0.5, "cupsize": 0.5, "firmness": 0.5, "race": {"asian": 0.33, "caucasian": 0.34, "african": 0.33}}, 1.80, "game_engine"))
res.append(criar("v2_corpo_feminino", {"gender": 0.0, "age": 0.5, "muscle": 0.5, "weight": 0.5, "proportions": 0.8, "height": 0.5, "cupsize": 0.5, "firmness": 0.6, "race": {"asian": 0.33, "caucasian": 0.34, "african": 0.33}}, 1.68, "game_engine_with_breast"))
json.dump(res, open("/home/claude/v2/saida/medidas.json", "w"), ensure_ascii=False, indent=1)
for r in res: print(r["nome"], r["altura_m"], "m", r["vertices"], "vert", r["triangulos"], "tri", r["ossos"], "ossos")
