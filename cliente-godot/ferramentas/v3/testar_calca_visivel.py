# Valtheria V3 — D59 (AUT-021): deformação da calça em duas métricas SEPARADAS, nas 28 animações (3 quadros cada).
#  - integral: p99 do estiramento de TODAS as arestas da calça (mesma métrica de testar_animacoes.py; não é substituída);
#  - região visível: p99 só das arestas cujos dois vértices ficam ABAIXO da barra da túnica no repouso
#    (barra medida por setor de 10° em volta do corpo; o que está acima dela fica coberto pela saia nas vistas normais).
# Também conta as bordas abertas da calça (arestas de uma face só) e quantas estão na região visível.
# Uso: python testar_calca_visivel.py <saida.json> <anims_a.glb> <anims_b.glb> <corpo.glb> <calca.glb> <tunica.glb>
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gltf_io import load, acc
from testar_animacoes_base import Esqueleto, canais_animacao, amostra_pose
SAIDA, AA, AB, CORPO, CALCA, TUNICA = sys.argv[1:7]

def malha(path):
    j, b = load(path); sk = j['skins'][0]
    joints = [j['nodes'][i]['name'] for i in sk['joints']]
    ibm = acc(j, b, sk['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
    pr = j['meshes'][0]['primitives'][0]; at = pr['attributes']
    P = acc(j, b, at['POSITION']).astype(float); J = acc(j, b, at['JOINTS_0']).astype(int)
    W = acc(j, b, at['WEIGHTS_0']).astype(float); W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
    I = acc(j, b, pr['indices']).reshape(-1, 3)
    return {"joints": joints, "ibm": ibm, "P": P, "J": J, "W": W, "I": I}

def posar(m, G):
    mats = np.stack([G[n] @ m["ibm"][k] for k, n in enumerate(m["joints"])])
    M = np.einsum('vk,vkij->vij', m["W"], mats[m["J"]])
    return np.einsum('vij,vj->vi', M[:, :3, :3], m["P"]) + M[:, :3, 3]

esq = Esqueleto(CORPO); G0 = esq.globais({})
cal, tun = malha(CALCA), malha(TUNICA)
E = np.concatenate([cal["I"][:, [0, 1]], cal["I"][:, [1, 2]], cal["I"][:, [2, 0]]]); Es = np.sort(E, axis=1)
E = np.unique(Es, axis=0)
# bordas abertas reais: solda os vértices repetidos nas costuras de UV antes de contar as arestas de uma face só
_, sold = np.unique(np.round(cal["P"], 5), axis=0, return_inverse=True); sold = sold.reshape(-1)
Iw = sold[cal["I"]]; Ew = np.sort(np.concatenate([Iw[:, [0, 1]], Iw[:, [1, 2]], Iw[:, [2, 0]]]), axis=1)
Ew = Ew[Ew[:, 0] != Ew[:, 1]]; uw, cw = np.unique(Ew, axis=0, return_counts=True)
rep = {}
for i, k in enumerate(sold): rep.setdefault(int(k), i)
bordas = np.array([[rep[int(a)], rep[int(b)]] for a, b in uw[cw == 1]]).reshape(-1, 2)
Pc0, Pt0 = posar(cal, G0), posar(tun, G0)
L0 = np.linalg.norm(Pc0[E[:, 0]] - Pc0[E[:, 1]], axis=1) + 1e-9
cx, cz = G0["pelvis"][0, 3], G0["pelvis"][2, 3]
az = lambda P: ((np.degrees(np.arctan2(P[:, 0] - cx, P[:, 2] - cz)) + 180) // 10).astype(int) % 36
barra = np.full(36, np.inf)
for s, y in zip(az(Pt0), Pt0[:, 1]): barra[s] = min(barra[s], y)
visivel_v = Pc0[:, 1] < barra[az(Pc0)] - 0.01
vis_e = visivel_v[E[:, 0]] & visivel_v[E[:, 1]]
bordas_vis = int((visivel_v[bordas[:, 0]] | visivel_v[bordas[:, 1]]).sum()) if len(bordas) else 0
res = []
for af in (AA, AB):
    for nome, canais, dur in canais_animacao(af):
        for q, t in (("início", 0.0), ("meio", dur / 2), ("fim", dur)):
            Pc = posar(cal, esq.globais(amostra_pose(canais, t, esq)))
            st = np.linalg.norm(Pc[E[:, 0]] - Pc[E[:, 1]], axis=1) / L0
            res.append({"anim": nome, "quadro": q, "p99_integral": round(float(np.percentile(st, 99)), 3),
                        "p99_visivel": round(float(np.percentile(st[vis_e], 99)), 3)})
saida = {"arquivo": os.path.basename(CALCA), "arestas": int(len(E)), "arestas_regiao_visivel": int(vis_e.sum()),
         "vertices_regiao_visivel": int(visivel_v.sum()), "vertices": int(len(Pc0)),
         "bordas_abertas": int(len(bordas)), "bordas_abertas_na_regiao_visivel": bordas_vis,
         "integral": {"pior_p99": max(r["p99_integral"] for r in res), "quadros_acima_2": sum(r["p99_integral"] > 2 for r in res),
                      "pior": max(res, key=lambda r: r["p99_integral"])["anim"]},
         "visivel": {"pior_p99": max(r["p99_visivel"] for r in res), "quadros_acima_2": sum(r["p99_visivel"] > 2 for r in res),
                     "pior": max(res, key=lambda r: r["p99_visivel"])["anim"]}, "quadros": res}
json.dump(saida, open(SAIDA, "w"), ensure_ascii=False, indent=1)
print(json.dumps({k: v for k, v in saida.items() if k != "quadros"}, ensure_ascii=False))
