# Valtheria V3 — teste das 28 animações oficiais (anims_a + anims_b, SEM alterá-las) num personagem montado por peças.
# Para cada animação, 3 quadros (início, meio, fim):
#  - deformação: estiramento das arestas em relação ao repouso (p99 e máximo), por peça;
#  - atravessamento: para cada par (camada de fora, camada de dentro), % dos vértices de fora que passam para
#    dentro da camada de dentro (distância com sinal < -3 mm ao longo da normal da camada de dentro); agora também
#    em número absoluto de vértices (AUT-020);
#  - saia x volume da coxa (AUT-020): conta os vértices da face externa da saia que entram mais de 3 mm na coxa
#    vestida (superfície da calça de referência, posada na mesma animação e quadro). Também registra, como apoio,
#    o teste por cápsula (eixo thigh -> calf, raio medido na calça), que é mais severo perto da virilha.
# Uso: python testar_animacoes.py <saida.json> <anims_a.glb> <anims_b.glb> <peca.glb> [<peca.glb> ...] [--coxa=<calca_ref.glb>]
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gltf_io import load, acc, q2m
SAIDA, AA, AB = sys.argv[1], sys.argv[2], sys.argv[3]
PECAS = [a for a in sys.argv[4:] if not a.startswith('--')]
COXA_REF = ([a[7:] for a in sys.argv[4:] if a.startswith('--coxa=')] or [None])[0]

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
        # AUT-021 (D58): formas corretivas (morph targets) acionadas pelo ângulo da coxa — mesma fórmula do controlador Godot
        self.T = None; pr0 = j['meshes'][0]['primitives'][0]
        if pr0.get('targets') and len(j['meshes']) == 1 and len(j['meshes'][0]['primitives']) == 1:
            self.T = np.stack([acc(j, b, t['POSITION']).astype(float) for t in pr0['targets']])
            self.T_nomes = j['meshes'][0].get('extras', {}).get('targetNames', [])
            self.rbf = j['meshes'][0].get('extras', {}).get('rbf')   # AUT-022: modelo RBF (pesos das formas rbf_xx)
            self.G0 = None
        E = np.concatenate([self.I[:, [0, 1]], self.I[:, [1, 2]], self.I[:, [2, 0]]]); self.E = np.unique(np.sort(E, axis=1), axis=0)
    def pose(self, over):
        loc = {n: mloc(over.get(n, {}).get('t', self.rt[n]), over.get(n, {}).get('r', self.rr[n]), self.rs[n]) for n in self.joints}
        G = {}
        def g(n):
            if n in G: return G[n]
            G[n] = (g(self.pai[n]) @ loc[n]) if self.pai[n] else loc[n]; return G[n]
        self.ultimo_G = {n: g(n) for n in self.joints}
        mats = np.stack([g(n) @ self.ibm[k] for k, n in enumerate(self.joints)])
        M = np.einsum('vk,vkij->vij', self.W, mats[self.J])
        P0 = self.P
        if self.T is not None:
            from corretivas_base import pesos
            if self.G0 is None:
                self.G0 = {}
                loc0 = {n: mloc(self.rt[n], self.rr[n], self.rs[n]) for n in self.joints}
                def g0(n):
                    if n in self.G0: return self.G0[n]
                    self.G0[n] = (g0(self.pai[n]) @ loc0[n]) if self.pai[n] else loc0[n]; return self.G0[n]
                for n in self.joints: g0(n)
            w = pesos(self.ultimo_G, self.G0)
            if self.rbf:
                from corretivas_base import rbf_pesos
                if self.rbf.get("modo") == "puro": w = {}
                w.update(rbf_pesos(self.ultimo_G, self.G0, self.rbf))
            self.ultimos_pesos = w
            P0 = self.P + np.einsum('t,tvi->vi', np.array([w.get(nm, 0.0) for nm in self.T_nomes]), self.T)
        P = np.einsum('vij,vj->vi', M[:, :3, :3], P0) + M[:, :3, 3]
        N = np.einsum('vij,vj->vi', M[:, :3, :3], self.N); N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
        return P, N

pecas = [Peca(p) for p in PECAS]
ref = pecas[0]
# fator de translação do quadril (a animação foi feita para o esqueleto Quaternius)
ja, ba = load(AA)
y_anim = [n for n in ja['nodes'] if n.get('name') == 'pelvis'][0].get('translation', [0, 1, 0])[1]
HIP = 1.0  # regra do jogo para humanos (character.gd usa a translação do quadril como está; AUT-020 corrigiu o fator)

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

# ---- saia x volume da coxa ----
def eixo_coxa(G, lado):
    return G[f'thigh_{lado}'][:3, 3], G[f'calf_{lado}'][:3, 3]
def dist_eixo(P, a, b):
    ab = b - a; t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1); return np.linalg.norm(P - (a + t[:, None] * ab), axis=1), t
def saia_coxa(Pt_pose, G):
    dentro = np.zeros(len(SAIA), bool)
    for lado in 'lr':
        a, b = eixo_coxa(G, lado); d, t = dist_eixo(Pt_pose[SAIA], a, b)
        r = np.interp(t * 9, np.arange(10), RAIO[lado])
        dentro |= (d < r + 0.006 - 0.003) & (t > 0.03) & (t < 0.97)    # entrou >3 mm na calça/coxa
    return int(dentro.sum())

coxa_ok = 'tunica' in idx
if coxa_ok:
    ref.pose({}); G0 = ref.ultimo_G
    cal = Peca(COXA_REF) if COXA_REF else (pecas[idx['calca']] if 'calca' in idx else None)
    Pc = cal.pose({})[0]
    RAIO = {}
    for lado in 'lr':
        a, b = eixo_coxa(G0, lado); d, t = dist_eixo(Pc, a, b)
        jt = cal.joints.index(f'thigh_{lado}')
        peso = (cal.W * (cal.J == jt)).sum(1)                       # só a parte da calça que segue a coxa
        lado_ok = (Pc[:, 0] * (a[0]) > 0) & (t > 0.02) & (t < 0.98) & (peso > 0.7)
        perf = []
        for k in range(10):
            m = lado_ok & (t >= k / 10) & (t < (k + 1) / 10)
            perf.append(float(np.percentile(d[m], 40)) - 0.006 if m.sum() > 8 else np.nan)   # pele = calça - 6 mm
        perf = np.array(perf); bons = ~np.isnan(perf)
        RAIO[lado] = np.interp(np.arange(10), np.arange(10)[bons], perf[bons]) if bons.any() else np.full(10, 0.07)
    tun = pecas[idx['tunica']]; Pt, Nt = rest[idx['tunica']]
    y_quadril = G0['thigh_l'][1, 3]
    saia = Pt[:, 1] < y_quadril + 0.03
    cx = Pt[saia].mean(0)
    externa = np.einsum('ij,ij->i', Nt[:, [0, 2]], Pt[:, [0, 2]] - cx[[0, 2]]) > 0     # descarta o forro (normal para dentro)
    SAIA = np.where(saia & externa)[0]
    print('raio_coxa_cm', {k: [round(100 * x, 1) for x in v] for k, v in RAIO.items()}, 'saia_coxa_repouso', saia_coxa(Pt, G0), file=sys.stderr)
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
            linha = {'anim': an['name'], 'quadro': q, 'tempo': round(float(t), 3), 'deformacao': {}, 'atravessamento_pct': {}, 'atravessamento_abs': {}}
            for p, (Pp, _), l0 in zip(pecas, poses, L0):
                st = np.linalg.norm(Pp[p.E[:, 0]] - Pp[p.E[:, 1]], axis=1) / l0
                linha['deformacao'][p.nome] = {'p99': round(float(np.percentile(st, 99)), 3), 'max': round(float(st.max()), 3)}
            for a, b in PARES:
                vo, vi = viz[(a, b)]
                if len(vo) == 0: continue
                Po = poses[idx[a]][0][vo]; Pi, Ni = poses[idx[b]][0][vi], poses[idx[b]][1][vi]
                sd = np.einsum('ij,ij->i', Po - Pi, Ni)
                linha['atravessamento_pct'][f'{a}/{b}'] = round(100.0 * float((sd < -0.003).mean()), 2)
                linha['atravessamento_abs'][f'{a}/{b}'] = [int((sd < -0.003).sum()), int(len(vo))]
            if coxa_ok:
                ref.pose(over)
                n = saia_coxa(poses[idx['tunica']][0], ref.ultimo_G)
                linha['saia_coxa_capsula'] = [n, int(len(SAIA))]
                # medida principal: superfície real da coxa vestida (calça de referência posada) contra a face externa da saia
                Pc_p, Nc_p = cal.pose(over); Ps = poses[idx['tunica']][0][SAIA]
                d = np.linalg.norm(Ps[:, None, :] - Pc_p[None, :, :], axis=2); k = d.argmin(1); dm = d.min(1)
                sd = np.einsum('ij,ij->i', Ps - Pc_p[k], Nc_p[k])
                n2 = int(((dm < 0.06) & (sd < -0.003)).sum())
                linha['saia_coxa'] = [n2, int(len(SAIA))]; linha['saia_coxa_pct'] = round(100.0 * n2 / max(len(SAIA), 1), 2)
            res.append(linha)
json.dump({'hip': round(float(HIP), 4), 'pares': [f'{a}/{b}' for a, b in PARES], 'poses': res}, open(SAIDA, 'w'), ensure_ascii=False, indent=1)
anims = sorted(set(r['anim'] for r in res))
pior = {}
for r in res:
    for k, v in r['atravessamento_pct'].items(): pior[k] = max(pior.get(k, 0), v)
dp = {}
for r in res:
    for k, v in r['deformacao'].items(): dp[k] = max(dp.get(k, 0), v['p99'])
saida = {'animacoes': len(anims), 'poses': len(res), 'pior_atravessamento_pct': pior, 'pior_deformacao_p99': dp}
if coxa_ok:
    piores = sorted(res, key=lambda r: -r['saia_coxa'][0])[:6]
    saida['saia_coxa'] = {'vertices_saia': int(len(SAIA)), 'pior_pct': max(r['saia_coxa_pct'] for r in res),
                          'quadros_acima_1pct': sum(1 for r in res if r['saia_coxa_pct'] > 1.0),
                          'piores': [(r['anim'], r['quadro'], r['saia_coxa'][0]) for r in piores]}
print(json.dumps(saida, ensure_ascii=False))
