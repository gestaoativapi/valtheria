# SOL-021 D59: diagnóstico do estiramento da calça P1 (só análise; não altera nenhum arquivo do repositório)
# Uso: python diag_calca.py <saida.json> <rotulo=calca.glb> [...]
import sys, json, collections, os, numpy as np
sys.path.insert(0, "/home/claude/sol021/cliente-godot/ferramentas/v3")
from gltf_io import load, acc, q2m
from testar_animacoes_base import Esqueleto, canais_animacao, amostra_pose, mloc
ANIMS = ["/home/claude/v3repo/cliente-godot/assets/chars/anims_a.glb", "/home/claude/v3repo/cliente-godot/assets/chars/anims_b.glb"]

class Malha:
    def __init__(self, path):
        j, b = load(path); self.esq = Esqueleto(path)
        sk = j['skins'][0]; self.joints = [j['nodes'][i]['name'] for i in sk['joints']]
        self.ibm = acc(j, b, sk['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
        pr = j['meshes'][0]['primitives'][0]; at = pr['attributes']
        self.P = acc(j, b, at['POSITION']).astype(float); self.J = acc(j, b, at['JOINTS_0']).astype(int)
        W = acc(j, b, at['WEIGHTS_0']).astype(float); self.W = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
        I = acc(j, b, pr['indices']).reshape(-1, 3)
        E = np.concatenate([I[:, [0, 1]], I[:, [1, 2]], I[:, [2, 0]]]); self.E = np.unique(np.sort(E, axis=1), axis=0)
    def pose(self, over):
        G = self.esq.globais(over)
        mats = np.stack([G[n] @ self.ibm[k] for k, n in enumerate(self.joints)])
        M = np.einsum('vk,vkij->vij', self.W, mats[self.J])
        return np.einsum('vij,vj->vi', M[:, :3, :3], self.P) + M[:, :3, 3], G

def analisar(path):
    c = Malha(path); P0, G0 = c.pose({})
    L0 = np.linalg.norm(P0[c.E[:, 0]] - P0[c.E[:, 1]], axis=1) + 1e-9
    poses = []
    for af in ANIMS:
        for nome, canais, dur in canais_animacao(af):
            for q, t in (("início", 0.0), ("meio", dur / 2), ("fim", dur)):
                Pp, _ = c.pose(amostra_pose(canais, t, c.esq))
                poses.append((nome, q, np.linalg.norm(Pp[c.E[:, 0]] - Pp[c.E[:, 1]], axis=1) / L0))
    p99 = sorted([(float(np.percentile(s, 99)), n, q) for n, q, s in poses], reverse=True)
    pior = max(poses, key=lambda x: np.percentile(x[2], 99)); st = pior[2]
    idx = np.where(st >= np.percentile(st, 99))[0]; vs = np.unique(c.E[idx].ravel())
    yq = G0["thigh_l"][1, 3]                                       # altura da articulação do quadril
    pesos = collections.Counter()
    for v in vs:
        top = sorted([(c.W[v, k], c.joints[c.J[v, k]]) for k in range(4) if c.W[v, k] > 0.05], reverse=True)
        pesos[" + ".join(f"{n}" for w, n in top[:3])] += 1
    mist = [v for v in vs if sum(1 for k in range(4) if c.W[v, k] > 0.2 and c.joints[c.J[v, k]].startswith("thigh")) >= 1
            and any(c.W[v, k] > 0.2 and c.joints[c.J[v, k]] == "pelvis" for k in range(4))]
    cru = [v for v in vs if any(c.W[v, k] > 0.15 and c.joints[c.J[v, k]] == "thigh_l" for k in range(4)) and any(c.W[v, k] > 0.15 and c.joints[c.J[v, k]] == "thigh_r" for k in range(4))]
    return {"vertices": int(len(P0)), "arestas": int(len(c.E)),
            "pior_quadro": {"p99": round(p99[0][0], 2), "anim": p99[0][1], "quadro": p99[0][2]},
            "oito_piores": [(round(a, 2), n, q) for a, n, q in p99[:8]],
            "quadros_p99_acima_2": sum(1 for a, _, _ in p99 if a > 2.0), "quadros_p99_acima_1_8": sum(1 for a, _, _ in p99 if a > 1.8),
            "vertices_no_1pct_pior": int(len(vs)),
            "acima_da_articulacao_do_quadril": int((P0[vs, 1] > yq - 0.02).sum()),
            "na_virilha_abs_x_menor_6cm": int((np.abs(P0[vs, 0]) < 0.06).sum()),
            "com_peso_coxa_e_bacia": len(mist), "com_peso_nas_duas_coxas": len(cru),
            "combinacoes_de_ossos": pesos.most_common(6),
            "altura_m_min_max": [round(float(P0[vs, 1].min()), 3), round(float(P0[vs, 1].max()), 3)], "y_quadril": round(float(yq), 3)}

saida = sys.argv[1]; res = {}
for a in sys.argv[2:]:
    rot, f = a.split("=", 1); res[rot] = analisar(f); print(rot, json.dumps(res[rot]["pior_quadro"]), res[rot]["quadros_p99_acima_2"], flush=True)
json.dump(res, open(saida, "w"), ensure_ascii=False, indent=1)
