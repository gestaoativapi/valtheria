# Valtheria V3 — teste das 28 animações oficiais (anims_a + anims_b, SEM alterá-las) num personagem montado por peças.
# Para cada animação, 3 quadros (início, meio, fim):
#  - deformação: estiramento das arestas em relação ao repouso (p99 e máximo), por peça;
#  - atravessamento: para cada par (camada de fora, camada de dentro), % dos vértices de fora que passam para
#    dentro da camada de dentro (distância com sinal < -3 mm ao longo da normal da camada de dentro).
# Uso: python testar_animacoes.py <saida.json> <anims_a.glb> <anims_b.glb> <peca.glb> [<peca.glb> ...]
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gltf_io import load, acc, q2m
SAIDA, AA, AB, PECAS = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]

def mloc(t, r, s):
    M = np.eye(4); M[:3, :3] = q2m(r) @ np.diag(s); M[:3, 3] = t; return M

class Peca:
    def __init__(self, path):
        j, b = load(path); self.nome = os.path.basename(path).replace('.glb', '')
        par = {}
        for i, n in enumerate(j['nodes']):
            for c in n.get('children', []): par[c] = i
        sk = j['skins'][0]; self.joints = [j['nodes'][i]['name'] for i in sk['joints']]; js = set(sk['joints'])
        self.rt = {j['nodes'][i]['name']: np.array(j['nodes'][i].get('translation', [0, 0, 0]), float) for i in sk['joints']}
        self.rr = {j['nodes'][i]['name']: np.array(j['nodes'][i].get('rotation', [0, 0, 0, 1]), float) for i in sk['joints']}
        self.rs = {j['nodes'][i]['name']: np.array(j['nodes'][i].get('scale', [1, 1, 1]), float) for i in sk['joints']}
        self.pai = {j['nodes'][i]['name']: (j['nodes'][par[i]]['name'] if par.get(i) in js else None) for i in sk['joints']}
        self.ibm = acc(j, b, sk['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
        Ps, Ns, Js, Ws, Is = [], [], [], [], []; off = 0
        for m in j['meshes']:
            for pr in m['primitives']:
                at = pr['attributes']; P = acc(j, b, at['POSITION']).astype(float)
                Ps.append(P); Ns.append(acc(j, b, at['NORMAL']).astype(float)); Js.append(acc(j, b, at['JOINTS_0']).astype(int))
                W = acc(j, b, at['WEIGHTS_0']).astype(float); Ws.append(W / np.maximum(W.sum(1, keepdims=True), 1e-9))
                Is.append(acc(j, b, pr['indices']).reshape(-1, 3) + off); off += len(P)
        self.P, self.N, self.J, self.W, self.I = map(np.concatenate, (Ps, Ns, Js, Ws, Is))
        E = np.concatenate([self.I[:, [0, 1]], self.I[:, [1, 2]], self.I[:, [2, 0]]]); self.E = np.unique(np.sort(E, axis=1), axis=0)
    def pose(self, over):
        loc = {n: mloc(over.get(n, {}).get('t', self.rt[n]), over.get(n, {}).get('r', self.rr[n]), self.rs[n]) for n in self.joints}
        G = {}
        def g(n):
            if n in G: return G[n]
            G[n] = (g(self.pai[n]) @ loc[n]) if self.pai[n] else loc[n]; return G[n]
        mats = np.stack([g(n) @ self.ibm[k] for k, n in enumerate(self.joints)])
        M = np.einsum('vk,vkij->vij', self.W, mats[self.J])
        P = np.einsum('vij,vj->vi', M[:, :3, :3], self.P) + M[:, :3, 3]
        N = np.einsum('vij,vj->vi', M[:, :3, :3], self.N); N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
        return P, N

pecas = [Peca(p) for p in PECAS]
ref = pecas[0]
# fator de translação do quadril (a animação foi feita para o esqueleto Quaternius)
ja, ba = load(AA)
y_anim = [n for n in ja['nodes'] if n.get('name') == 'pelvis'][0].get('translation', [0, 1, 0])[1]
HIP = ref.rt['pelvis'][1] / y_anim if abs(y_anim) > 1e-6 else 1.0

def tipo(nome):
    for k in ('pc_', 'rp_', 'ca_'):
        if nome.startswith(k): return nome
    return nome
def camada(nome):  # quem fica por fora de quem
    if 'tunica' in nome: return 'tunica'
    if 'calca' in nome: return 'calca'
    if 'botas' in nome: return 'botas'
    if nome.startswith('ca_'): return 'cabelo'
    if nome.startswith('pc_'): return 'corpo'
    return nome
idx = {camada(p.nome): k for k, p in enumerate(pecas)}
PARES = [(a, b) for a, b in [('tunica', 'calca'), ('botas', 'calca'), ('tunica', 'corpo'), ('cabelo', 'tunica'), ('cabelo', 'corpo')] if a in idx and b in idx]
rest = [p.pose({}) for p in pecas]
L0 = [np.linalg.norm(r[0][p.E[:, 0]] - r[0][p.E[:, 1]], axis=1) + 1e-9 for p, r in zip(pecas, rest)]
# pares de vizinhos no repouso (vértice de fora -> vértice de dentro mais próximo, até 5 cm)
viz = {}
for a, b in PARES:
    Po, Pi = rest[idx[a]][0], rest[idx[b]][0]
    near = np.empty(len(Po), int); dist = np.empty(len(Po))
    for s in range(0, len(Po), 2048):
        d = np.linalg.norm(Po[s:s + 2048, None, :] - Pi[None, :, :], axis=2); near[s:s + 2048] = d.argmin(1); dist[s:s + 2048] = d.min(1)
    sd0 = np.einsum('ij,ij->i', Po - Pi[near], rest[idx[b]][1][near])
    ok = (dist < 0.05) & (sd0 > 0.0)  # só os que começam por fora e perto
    viz[(a, b)] = (np.where(ok)[0], near[ok])

def amostra(path, sm, t):
    ts, vs = sm['in'], sm['out']
    if t <= ts[0]: return vs[0]
    if t >= ts[-1]: return vs[-1]
    i = np.searchsorted(ts, t) - 1; f = (t - ts[i]) / (ts[i + 1] - ts[i]); v = vs[i] * (1 - f) + vs[i + 1] * f
    if path == 'rotation':
        if np.dot(vs[i], vs[i + 1]) < 0: v = vs[i] * (1 - f) - vs[i + 1] * f
        v = v / np.linalg.norm(v)
    return v

res = []
for af in (AA, AB):
    ja, ba = load(af)
    for an in ja['animations']:
        canais = []
        for c in an['channels']:
            nome = ja['nodes'][c['target']['node']]['name']; s = an['samplers'][c['sampler']]
            canais.append((nome, c['target']['path'], {'in': acc(ja, ba, s['input']).reshape(-1), 'out': acc(ja, ba, s['output'])}))
        dur = max(c[2]['in'][-1] for c in canais)
        for q, t in [('início', 0.0), ('meio', dur / 2), ('fim', dur)]:
            over = {}
            for nome, path, sm in canais:
                if nome not in ref.rt: continue
                v = amostra(path, sm, t)
                if path == 'rotation': over.setdefault(nome, {})['r'] = v
                elif path == 'translation': over.setdefault(nome, {})['t'] = v * HIP
            poses = [p.pose(over) for p in pecas]
            linha = {'anim': an['name'], 'quadro': q, 'deformacao': {}, 'atravessamento_pct': {}}
            for p, (Pp, _), l0 in zip(pecas, poses, L0):
                st = np.linalg.norm(Pp[p.E[:, 0]] - Pp[p.E[:, 1]], axis=1) / l0
                linha['deformacao'][p.nome] = {'p99': round(float(np.percentile(st, 99)), 3), 'max': round(float(st.max()), 3)}
            for a, b in PARES:
                vo, vi = viz[(a, b)]
                if len(vo) == 0: continue
                Po = poses[idx[a]][0][vo]; Pi, Ni = poses[idx[b]][0][vi], poses[idx[b]][1][vi]
                sd = np.einsum('ij,ij->i', Po - Pi, Ni)
                linha['atravessamento_pct'][f'{a}/{b}'] = round(100.0 * float((sd < -0.003).mean()), 2)
            res.append(linha)
json.dump({'hip': round(float(HIP), 4), 'pares': [f'{a}/{b}' for a, b in PARES], 'poses': res}, open(SAIDA, 'w'), ensure_ascii=False, indent=1)
anims = sorted(set(r['anim'] for r in res))
pior = {}
for r in res:
    for k, v in r['atravessamento_pct'].items(): pior[k] = max(pior.get(k, 0), v)
dp = {}
for r in res:
    for k, v in r['deformacao'].items(): dp[k] = max(dp.get(k, 0), v['p99'])
print(json.dumps({'animacoes': len(anims), 'poses': len(res), 'pior_atravessamento_pct': pior, 'pior_deformacao_p99': dp}, ensure_ascii=False))
