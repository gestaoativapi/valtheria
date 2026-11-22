"""Forma de cada raça para as roupas (escolha de Robson 22/11): o corpo MakeHuman de cada raça é encaixado no
esqueleto oficial e comparado ao humano; a diferença (músculo, peso, ombros, pescoço) vira um campo de
deslocamento que o jogo aplica nas roupas e armaduras. Rosto e mãos atuais ficam como estão.
Saída: assets/corpos/forma_base_<g>.bin (posições do humano) e forma_<raca>_<g>.bin (deslocamentos),
float32 little-endian, 3 por vértice do corpo MakeHuman.
Uso: python3 forma_racas.py <mpfb_data> <pasta_assets_v3> <saida>"""
import bpy, json, os, sys
import numpy as np
from mathutils import Vector, Quaternion

DATA, V3, OUT = sys.argv[-3:]
os.makedirs(OUT, exist_ok=True)
import importlib.util
spec = importlib.util.spec_from_file_location("gc", os.path.join(os.path.dirname(os.path.abspath(__file__)), "gerar_corpos_lib.py"))
gc = importlib.util.module_from_spec(spec); spec.loader.exec_module(gc)
vs0, uvs, faces, grupos = gc.ler_base_completa(DATA)
corpo_idx = sorted({i for f in faces for (i, _) in f})
rig = json.load(open(os.path.join(DATA, "rigs", "standard", "rig.game_engine.json")))
pesos = json.load(open(os.path.join(DATA, "rigs", "standard", "weights.game_engine.json")))["weights"]
lista = [[] for _ in range(len(vs0))]
for bn, prs in pesos.items():
    for i, w in prs:
        lista[i].append((bn, w))
NOME = {"head": "Head", "Root": "root"}

def esqueleto(glb):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    # Godot usa Y para cima: devolve já em (x, z, -y) para casar com o espaço de repouso do esqueleto no jogo
    return {b.name: (np.array(arm.matrix_world @ b.head_local), np.array(arm.matrix_world @ b.tail_local)) for b in arm.data.bones}

def encaixa(nosso, gen, r):
    musc = r["musc"] if gen == "male" else max(0.0, r["musc"] - 0.25)
    V = np.array(gc.aplicar(DATA, vs0, gen, musc, r["peso"], r["alt"], r["prop"], r["locais"]), dtype=np.float64)
    B = np.stack([V[:, 0], -V[:, 2], V[:, 1]], axis=1) * 0.1
    B[:, 2] -= B[corpo_idx, 2].min()
    def ponto(e):
        if e["strategy"] == "CUBE":
            return B[list(grupos[e["cube_name"]])].mean(axis=0)
        return B[e["vertex_indices"]].mean(axis=0)
    mh = {n: (ponto(b["head"]), ponto(b["tail"]), b["parent"]) for n, b in rig.items()}
    k = (nosso["Head"][1][2] + 0.07) / B[corpo_idx, 2].max()
    tr = {}
    for n, (h, t, pai) in mh.items():
        on = NOME.get(n, n)
        if on not in nosso:
            continue
        hO, tO = nosso[on]
        dM = t - h; dO = tO - hO
        lM = np.linalg.norm(dM); lO = np.linalg.norm(dO)
        if lM < 1e-6 or lO < 1e-6:
            continue
        gira = not n.startswith(("clavicle", "pelvis", "Root", "head"))
        q = Vector(dM).rotation_difference(Vector(dO)) if gira else Quaternion()
        longo = n.startswith(("upperarm", "lowerarm", "thigh", "calf"))
        tr[n] = (h, hO, np.array(q.to_matrix()), dM / lM, lO / lM if longo else k, k)
    def T(n, v):
        while n not in tr and n in mh:
            n = mh[n][2]
        if n not in tr:
            return v
        h, hO, R, ax, s_ax, kk = tr[n]
        d = v - h; par = np.dot(d, ax); perp = d - par * ax
        return hO + R @ (ax * par * s_ax + perp * kk)
    out = np.zeros((len(corpo_idx), 3))
    for j, i in enumerate(corpo_idx):
        ws = lista[i]; tot = sum(w for _, w in ws)
        acc = np.zeros(3)
        for bn, w in ws:
            acc += T(bn, B[i]) * (w / tot)
        out[j] = acc
    # Blender Z-up -> Godot Y-up (x, z, -y)
    return np.stack([out[:, 0], out[:, 2], -out[:, 1]], axis=1).astype(np.float32)

# volume por região (metros, para fora da pele): é o que dá a silhueta de cada raça por cima das proporções
# do esqueleto; o corpo MakeHuman encaixado sozinho muda pouco (1 cm), porque o esqueleto já iguala os ossos
VOLUME = {
    "orc": {"spine_03": .035, "spine_02": .025, "spine_01": .02, "clavicle": .03, "upperarm": .025, "lowerarm": .02, "thigh": .02, "calf": .015, "neck_01": .02},
    "anao": {"spine_03": .03, "spine_02": .045, "spine_01": .045, "pelvis": .03, "clavicle": .025, "upperarm": .02, "lowerarm": .02, "thigh": .02, "calf": .015, "neck_01": .015},
    "gigante": {"spine_03": .03, "spine_02": .02, "spine_01": .015, "clavicle": .03, "upperarm": .025, "lowerarm": .02, "thigh": .02, "calf": .015, "neck_01": .02},
    "beastman": {"spine_03": .025, "spine_02": .012, "clavicle": .025, "upperarm": .02, "lowerarm": .015, "thigh": .015, "neck_01": .02},
    "draconato": {"spine_03": .02, "spine_02": .008, "clavicle": .02, "upperarm": .015, "lowerarm": .01, "thigh": .01},
    "elfo": {"spine_02": -.012, "spine_01": -.012, "upperarm": -.008, "lowerarm": -.006, "thigh": -.008, "calf": -.006},
    "sombrio": {"spine_03": .006, "spine_02": -.01, "spine_01": -.01, "upperarm": -.004, "thigh": -.006, "calf": -.004},
}

def normais(P):
    N = np.zeros_like(P)
    mapa = {o: j for j, o in enumerate(corpo_idx)}
    for f in faces:
        ids = [mapa[i] for (i, _) in f]
        a, b, c = P[ids[0]], P[ids[1]], P[ids[2]]
        n = np.cross(b - a, c - a)
        for j in ids:
            N[j] += n
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    return N

def volume(P, raca, gen):
    tab = VOLUME.get(raca, {})
    if not tab:
        return np.zeros_like(P)
    N = normais(P)
    # Godot: a frente do corpo é +Z; garante normais para fora (média apontando para longe do eixo do corpo)
    centro = P.mean(axis=0)
    if np.mean(np.sum(N * (P - centro), axis=1)) < 0:
        N = -N
    amt = np.zeros(len(P))
    for j, i in enumerate(corpo_idx):
        ws = lista[i]; tot = sum(w for _, w in ws)
        a = 0.0
        for bn, w in ws:
            base = bn[:-2] if bn.endswith(("_l", "_r")) else bn
            a += tab.get(base, 0.0) * w / tot
        amt[j] = a
    k = 1.0 if gen == "male" else 0.7
    return (N * amt[:, None] * k).astype(np.float32)

for g, gen in (("m", "male"), ("f", "female")):
    nosso = esqueleto(os.path.join(V3, f"pc_humano_{g}.glb"))
    base = encaixa(nosso, gen, gc.RACAS["humano"])
    base.tofile(os.path.join(OUT, f"forma_base_{g}.bin"))
    for raca, r in gc.RACAS.items():
        if raca == "humano":
            continue
        d = encaixa(nosso, gen, r) - base + volume(base, raca, gen)
        d.tofile(os.path.join(OUT, f"forma_{raca}_{g}.bin"))
        print(raca, g, "desloc. máx", round(float(np.abs(d).max()), 3), "médio", round(float(np.linalg.norm(d, axis=1).mean()), 4))
print("ok", len(corpo_idx), "vértices")
