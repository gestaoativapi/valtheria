# Valtheria V3 — D58 (AUT-021): formas corretivas (blend shapes) da túnica, acionadas pelo ângulo da coxa.
# Não altera o esqueleto nem as animações. Gera um .glb NOVO (a túnica aprovada não é substituída).
# Método (pose-space): para cada coxa e cada pose de construção (frente 45°, frente 90°, trás 45°, fora 45°, só essa
# coxa girada a partir do repouso), a túnica é posada junto com a calça de referência; os vértices da saia que ficam a
# menos de FOLGA da superfície da calça são empurrados para fora ao longo da normal da calça; o campo de deslocamento é
# suavizado na malha e convertido para o espaço de repouso pela inversa da matriz de skinning de cada vértice.
# Uso: python corretivas_v3.py <tunica.glb> <calca_ref.glb> <saida.glb> [relatorio.json]
import sys, os, json, struct, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gltf_io import load, acc, q2m, m2q
from testar_animacoes_base import Esqueleto, mloc
from corretivas_base import FORMAS, CONSTRUCAO, LADOS, angulos, pesos, direcao, _eixos
TUN, CAL, SAIDA = sys.argv[1], sys.argv[2], sys.argv[3]
REL = sys.argv[4] if len(sys.argv) > 4 else None
FOLGA = float(os.environ.get("V3_CORR_FOLGA", "0.015"))         # distância mínima saia -> superfície da calça (m)
PASSADAS = 8           # suavização do campo de deslocamento

class Malha:
    def __init__(self, path):
        self.j, self.b = load(path); j, b = self.j, self.b; self.esq = Esqueleto(path)
        sk = j['skins'][0]; self.joints = [j['nodes'][i]['name'] for i in sk['joints']]
        self.ibm = acc(j, b, sk['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
        pr = j['meshes'][0]['primitives'][0]; at = pr['attributes']
        self.P = acc(j, b, at['POSITION']).astype(float); self.N = acc(j, b, at['NORMAL']).astype(float)
        self.J = acc(j, b, at['JOINTS_0']).astype(int)
        W = acc(j, b, at['WEIGHTS_0']).astype(float); self.W = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
        self.I = acc(j, b, pr['indices']).reshape(-1, 3)
    def matrizes(self, G):
        mats = np.stack([G[n] @ self.ibm[k] for k, n in enumerate(self.joints)])
        return np.einsum('vk,vkij->vij', self.W, mats[self.J])
    def pose(self, G, delta=None):
        M = self.matrizes(G); P = self.P + (delta if delta is not None else 0)
        Pp = np.einsum('vij,vj->vi', M[:, :3, :3], P) + M[:, :3, 3]
        Np = np.einsum('vij,vj->vi', M[:, :3, :3], self.N); Np /= np.maximum(np.linalg.norm(Np, axis=1, keepdims=True), 1e-9)
        return Pp, Np, M

tun, cal = Malha(TUN), Malha(CAL)
esq = tun.esq; G0 = esq.globais({})

def rot_min(a, b):
    """rotação mínima que leva o vetor unitário a até b"""
    v = np.cross(a, b); c = float(a @ b)
    if np.linalg.norm(v) < 1e-9: return np.eye(3)
    K = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + K + K @ K * (1.0 / (1.0 + c))

def pose_construcao(spec):
    """gira cada coxa citada até a direção (flexão, abdução) pedida, no referencial da bacia em repouso"""
    F, U, L = _eixos(G0); over = {}
    for s, sinal in LADOS:
        if s not in spec: continue
        f, a = np.radians(spec[s][0]), np.radians(spec[s][1])
        d0 = direcao(G0, s, G0)
        f0 = np.arctan2(d0 @ F, -(d0 @ U)); a0 = np.arcsin(np.clip(sinal * (d0 @ L), -1, 1))
        ft, at = f0 + f, a0 + a
        d = np.sin(at) * sinal * L + np.cos(at) * (np.sin(ft) * F - np.cos(ft) * U)
        Rp0 = G0["pelvis"][:3, :3]
        Rw = Rp0 @ rot_min(d0, d / np.linalg.norm(d)) @ Rp0.T          # rotação no mundo (bacia em repouso)
        Rg = Rw @ G0[f"thigh_{s}"][:3, :3]
        Rpar = G0[esq.pai[f"thigh_{s}"]][:3, :3]
        over[f"thigh_{s}"] = {"r": m2q(Rpar.T @ Rg)}
    return over

# vizinhança da túnica (para suavizar o campo) e região da saia (abaixo do cinto, no repouso)
viz = [[] for _ in range(len(tun.P))]
for a, b, c in tun.I:
    for u, v in ((a, b), (b, c), (c, a)): viz[u].append(v); viz[v].append(u)
viz = [np.unique(v) for v in viz]
y_quadril = G0["thigh_l"][1, 3]
saia = tun.P[:, 1] < y_quadril + 0.06

alvos, rel = [], {"folga_m": FOLGA, "passadas": PASSADAS, "formas": {}}
for nome in FORMAS:
    over = pose_construcao(CONSTRUCAO[nome])
    G = esq.globais(over)
    w = pesos(G, G0); ang = angulos(G, G0)
    # formas já construídas entram com o peso que teriam nesta pose: a nova forma corrige só o que sobra
    Dprev = sum((w.get(n, 0.0) * T for n, T in zip(FORMAS, alvos)), np.zeros_like(tun.P))
    Pt, Nt, Mt = tun.pose(G, Dprev); Pc, Nc, _ = cal.pose(G)
    d = np.linalg.norm(Pt[:, None, :] - Pc[None, :, :], axis=2); k = d.argmin(1); dm = d.min(1)
    sd = np.einsum('ij,ij->i', Pt - Pc[k], Nc[k])
    empurra = np.where(saia & (dm < 0.08) & (sd < FOLGA), FOLGA - sd, 0.0)
    D = Nc[k] * empurra[:, None]
    base = D.copy(); mag0 = np.linalg.norm(base, axis=1)
    for _ in range(PASSADAS):
        Dm = np.stack([D[v].mean(0) if len(v) else D[i] for i, v in enumerate(viz)])
        D = np.where(saia[:, None], 0.5 * D + 0.5 * Dm, 0.0)
        fraco = np.linalg.norm(D, axis=1) < mag0
        D[fraco] = base[fraco]
    wp = max(w.get(nome, 1.0), 1e-6)                                # peso da própria forma na pose de construção (1,0)
    Dr = np.einsum('vij,vj->vi', np.linalg.inv(Mt[:, :3, :3]), D) / wp
    alvos.append(Dr.astype(np.float32))
    rel["formas"][nome] = {"pose": CONSTRUCAO[nome], "angulo_medido": {k2: [round(float(v[0]), 1), round(float(v[1]), 1)] for k2, v in ang.items()},
                           "peso_na_pose": round(float(w.get(nome, 0)), 3), "vertices_empurrados": int((empurra > 0).sum()),
                           "vertices_afetados": int((np.linalg.norm(D, axis=1) > 1e-4).sum()), "desloc_max_mm": round(float(np.linalg.norm(D, axis=1).max() * 1000), 1)}
    print(nome, rel["formas"][nome], flush=True)

# grava o .glb novo com os morph targets (somente POSITION) — o resto do arquivo é copiado como está
j = json.loads(json.dumps(tun.j)); buf = bytearray(tun.b)
for D in alvos:
    while len(buf) % 4: buf.append(0)
    off = len(buf); buf.extend(D.tobytes())
    j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': D.nbytes})
    j['accessors'].append({'bufferView': len(j['bufferViews']) - 1, 'componentType': 5126, 'count': int(len(D)), 'type': 'VEC3',
                           'min': D.min(0).tolist(), 'max': D.max(0).tolist()})
pr = j['meshes'][0]['primitives'][0]
pr['targets'] = [{'POSITION': len(j['accessors']) - len(alvos) + i} for i in range(len(alvos))]
j['meshes'][0]['weights'] = [0.0] * len(alvos)
j['meshes'][0].setdefault('extras', {})['targetNames'] = FORMAS
while len(buf) % 4: buf.append(0)
j['buffers'][0]['byteLength'] = len(buf)
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
glb = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(buf), 0x004E4942) + bytes(buf)
open(SAIDA, 'wb').write(glb)
rel["arquivo"] = os.path.basename(SAIDA); rel["bytes"] = len(glb)
if REL: json.dump(rel, open(REL, 'w'), ensure_ascii=False, indent=1)
print("FEITO", SAIDA, len(glb))
