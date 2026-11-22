"""Fase 2: encaixa o corpo anatômico (MakeHuman/MPFB2, CC0) no esqueleto oficial de 65 ossos, sem alterar o
esqueleto. Cada osso do rig 'game_engine' do MPFB (mesmos nomes do nosso) leva a malha do lugar dele para o
lugar do nosso osso em repouso (posição, direção e comprimento); os pesos de pele vêm do próprio MPFB.
Uso: python3 encaixar_corpo.py <mpfb_data> <glb_oficial> <saida.glb> <raca> <m|f>"""
import bpy, json, gzip, os, sys, math
import numpy as np
from mathutils import Vector, Quaternion, Matrix

DATA, GLB, SAIDA, RACA, GEN = sys.argv[-5:]
sys.path.insert(0, os.path.dirname(__file__))
import importlib.util
spec = importlib.util.spec_from_file_location("gc", os.path.join(os.path.dirname(__file__), "gerar_corpos_lib.py"))
gc = importlib.util.module_from_spec(spec); spec.loader.exec_module(gc)

# ---------- malha MakeHuman com as formas da raça ----------
vs, uvs, faces, grupos = gc.ler_base_completa(DATA)
r = gc.RACAS[RACA]
musc = r["musc"] if GEN == "m" else max(0.0, r["musc"] - 0.25)
vs = gc.aplicar(DATA, vs, "male" if GEN == "m" else "female", musc, r["peso"], r["alt"], r["prop"], r["locais"])
V = np.array(vs, dtype=np.float64)
B = np.stack([V[:, 0], -V[:, 2], V[:, 1]], axis=1) * 0.1      # Y-up dm -> Z-up m
corpo_idx = sorted({i for f in faces for (i, _) in f})
B[:, 2] -= B[corpo_idx, 2].min()

def centro(nome):
    ids = grupos.get(nome)
    return B[list(ids)].mean(axis=0) if ids else None

rig = json.load(open(os.path.join(DATA, "rigs", "standard", "rig.game_engine.json")))
def ponto(e):
    if e["strategy"] == "CUBE":
        return centro(e["cube_name"])
    return B[e["vertex_indices"]].mean(axis=0)
mh = {n: (ponto(b["head"]), ponto(b["tail"]), b["parent"]) for n, b in rig.items()}
pesos = json.load(open(os.path.join(DATA, "rigs", "standard", "weights.game_engine.json")))["weights"]

# ---------- esqueleto oficial ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
nosso = {}
for b in arm.data.bones:
    nosso[b.name] = (np.array(arm.matrix_world @ b.head_local), np.array(arm.matrix_world @ b.tail_local))
NOME = {"head": "Head", "Root": "root"}
def nosso_nome(n):
    return NOME.get(n, n)

alt_mh = B[corpo_idx, 2].max()
alt_nosso = nosso["Head"][1][2] + 0.07
k_esp = alt_nosso / alt_mh   # espessura acompanha a altura do esqueleto

def quat(a, b):
    a = Vector(a).normalized(); b = Vector(b).normalized()
    return a.rotation_difference(b)

transf = {}
for n, (h, t, pai) in mh.items():
    on = nosso_nome(n)
    if on not in nosso or h is None or t is None:
        continue
    hO, tO = nosso[on]
    dM = t - h; dO = tO - hO
    lM = np.linalg.norm(dM); lO = np.linalg.norm(dO)
    if lM < 1e-6 or lO < 1e-6:
        continue
    # clavícula, bacia, raiz e cabeça: só posição (a direção desses ossos é convenção de cada rig, não anatomia);
    # braços, pernas, coluna, mãos, pés e dedos giram para a pose em T do nosso esqueleto
    gira = not (n.startswith(("clavicle", "pelvis", "Root", "head")))
    q = quat(dM, dO) if gira else Quaternion()
    R = np.array(q.to_matrix())
    ax = dM / lM
    # só os ossos longos esticam no comprimento; cabeça, mãos, pés, dedos, bacia e clavículas mantêm a forma
    longo = n.startswith(("upperarm", "lowerarm", "thigh", "calf"))
    s_ax = lO / lM if longo else k_esp
    transf[n] = (h, hO, R, ax, s_ax)

def T(n, v):
    while n not in transf and n in mh:
        n = mh[n][2]
    if n not in transf:
        return v
    h, hO, R, ax, s_ax = transf[n]
    d = v - h
    par = np.dot(d, ax)
    perp = d - par * ax
    d2 = ax * par * s_ax + perp * k_esp
    return hO + R @ d2

# pesos por vértice
lista = [[] for _ in range(len(B))]
for bn, prs in pesos.items():
    for i, w in prs:
        lista[i].append((bn, w))
novo = B.copy()
for i in corpo_idx:
    ws = lista[i]
    tot = sum(w for _, w in ws)
    if tot <= 0:
        continue
    acc = np.zeros(3)
    for bn, w in ws:
        acc += T(bn, B[i]) * (w / tot)
    novo[i] = acc

# ---------- monta a malha nova presa ao esqueleto ----------
for o in list(bpy.data.objects):
    if o.type == "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
mapa = {o: n for n, o in enumerate(corpo_idx)}
me = bpy.data.meshes.new("corpo")
me.from_pydata([tuple(novo[i]) for i in corpo_idx], [], [tuple(mapa[i] for (i, _) in f) for f in faces])
uvl = me.uv_layers.new(name="UVMap")
li = 0
for f in faces:
    for (_, t) in f:
        uvl.data[li].uv = uvs[t]
        li += 1
me.shade_smooth() if hasattr(me, "shade_smooth") else None
ob = bpy.data.objects.new("corpo", me)
bpy.context.scene.collection.objects.link(ob)
ob.parent = arm
mod = ob.modifiers.new("Armature", "ARMATURE"); mod.object = arm
grupos_v = {}
for bn, prs in pesos.items():
    on = nosso_nome(bn)
    if on not in nosso:
        continue
    g = grupos_v.get(on) or ob.vertex_groups.new(name=on)
    grupos_v[on] = g
    for i, w in prs:
        if i in mapa and w > 0:
            g.add([mapa[i]], w, "ADD")
mat = bpy.data.materials.new("pele"); mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.78, 0.58, 0.46, 1)
me.materials.append(mat)
for p in me.polygons:
    p.use_smooth = True
bpy.ops.export_scene.gltf(filepath=SAIDA, export_format="GLB", export_skins=True, export_animations=False)
print("ok", SAIDA, len(corpo_idx), "vértices", "k_esp", round(k_esp, 3))
