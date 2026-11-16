# Valtheria V3 — D58 (AUT-022): deformação por exemplos (RBF) para as túnicas, sem alterar esqueleto nem animações.
# Treino: poses tiradas das 28 animações oficiais em instantes que NÃO são os do teste (testar_animacoes.py mede em
# 0, meio e fim; aqui o treino usa (k + 0,5)/8 da duração, k = 0..7), para medir generalização e não decoreba.
# Para cada pose de treino calcula o deslocamento que afasta a saia da calça (mesmo método de corretivas_v3.py),
# já descontando as 13 formas corretivas atuais (modo "hibrido") ou sem elas (modo "puro").
# Os deslocamentos são comprimidos por PCA em K formas (blend shapes rbf_00..); um RBF gaussiano sobre a direção das
# coxas no referencial da saia prevê, por quadro, o peso de cada forma. O RBF vai junto no .glb (extras "rbf").
# Uso: python rbf_v3.py <tunica_base.glb ou _corretiva.glb> <calca.glb> <saida.glb> <anims_a> <anims_b> [modo] [K] [rel.json]
import sys, os, json, struct, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gltf_io import load, acc
from testar_animacoes_base import canais_animacao, amostra_pose, Esqueleto
from corretivas_base import FORMAS, CONSTRUCAO, LADOS, angulos, direcao, _eixos
from gltf_io import m2q
from corretivas_base import pesos, rbf_features
TUN, CAL, SAIDA, AA, AB = sys.argv[1:6]
MODO = sys.argv[6] if len(sys.argv) > 6 else "hibrido"
K = int(sys.argv[7]) if len(sys.argv) > 7 else 16
REL = sys.argv[8] if len(sys.argv) > 8 else None
FOLGA, PASSADAS, LAMBDA = 0.015, 8, 1e-3
AMOSTRAS = int(os.environ.get("V3_RBF_AMOSTRAS", "8"))   # quadros de treino por animação

# reaproveita Malha/esqueleto/vizinhança do gerador das formas corretivas (mesmas funções, sem executar o gerador)
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "corretivas_v3.py")).read()
src = src[src.index("class Malha"):src.index("alvos, rel")].replace("tun, cal = Malha(TUN), Malha(CAL)", "tun, cal = Malha(TUN), Malha(CAL)")
exec(src)

# formas corretivas já presentes no arquivo de entrada (modo híbrido)
pr0 = tun.j['meshes'][0]['primitives'][0]
nomes_corr = tun.j['meshes'][0].get('extras', {}).get('targetNames', [])
T_corr = np.stack([acc(tun.j, tun.b, t['POSITION']).astype(float) for t in pr0.get('targets', [])]) if pr0.get('targets') else None
if MODO == "puro": T_corr = None

def deslocamento(G):
    """deslocamento em repouso que afasta a saia da calça nesta pose (descontadas as formas corretivas no híbrido)"""
    D0 = np.zeros_like(tun.P)
    if T_corr is not None:
        w = pesos(G, G0); D0 = np.einsum('t,tvi->vi', np.array([w.get(n, 0.0) for n in nomes_corr]), T_corr)
    Pt, Nt, Mt = tun.pose(G, D0); Pc, Nc, _ = cal.pose(G)
    d = np.linalg.norm(Pt[:, None, :] - Pc[None, :, :], axis=2); k = d.argmin(1); dm = d.min(1)
    sd = np.einsum('ij,ij->i', Pt - Pc[k], Nc[k])
    empurra = np.where(saia & (dm < 0.08) & (sd < FOLGA), FOLGA - sd, 0.0)
    D = Nc[k] * empurra[:, None]; base = D.copy(); mag0 = np.linalg.norm(base, axis=1)
    for _ in range(PASSADAS):
        Dm = np.stack([D[v].mean(0) if len(v) else D[i] for i, v in enumerate(viz)])
        D = np.where(saia[:, None], 0.5 * D + 0.5 * Dm, 0.0)
        fraco = np.linalg.norm(D, axis=1) < mag0; D[fraco] = base[fraco]
    return np.einsum('vij,vj->vi', np.linalg.inv(Mt[:, :3, :3]), D), int((empurra > 0).sum())

# poses de treino (+ repouso, que deve dar deslocamento zero)
feats, alvos, info = [rbf_features(G0, G0)], [np.zeros(tun.P.shape)], []
for af in (AA, AB):
    for nome, canais, dur in canais_animacao(af):
        for kq in range(AMOSTRAS):
            G = esq.globais(amostra_pose(canais, dur * (kq + 0.5) / AMOSTRAS, esq))
            D, n = deslocamento(G)
            feats.append(rbf_features(G, G0)); alvos.append(D); info.append([nome, kq, n])
F = np.array(feats); A = np.stack(alvos)                       # (N, 6), (N, V, 3)
idx_saia = np.where(saia)[0]
X = A[:, idx_saia, :].reshape(len(A), -1)                       # só os vértices da saia entram na PCA
U, S, Vt = np.linalg.svd(X, full_matrices=False)
K = min(K, len(S)); base_pca = Vt[:K]                           # (K, 3*Vs)
C = X @ base_pca.T                                              # coeficientes de cada pose (N, K)
energia = float((S[:K] ** 2).sum() / max((S ** 2).sum(), 1e-12))
# RBF gaussiano: largura = mediana das distâncias entre poses de treino
Dd = np.linalg.norm(F[:, None, :] - F[None, :, :], axis=2)
sigma = float(np.median(Dd[Dd > 0]))
M = int(os.environ.get("V3_RBF_CENTROS", "0"))                  # 0 = um centro por pose de treino
if 0 < M < len(F):
    # centros por amostragem do ponto mais distante (determinística, começa no repouso) e ajuste por mínimos quadrados
    sel = [0]; dmin = Dd[0].copy()
    while len(sel) < M:
        i = int(dmin.argmax()); sel.append(i); dmin = np.minimum(dmin, Dd[i])
    Fc = F[sel]; Phi_nm = np.exp(-(np.linalg.norm(F[:, None, :] - Fc[None, :, :], axis=2) / sigma) ** 2)
    Wrbf = np.linalg.solve(Phi_nm.T @ Phi_nm + LAMBDA * np.eye(M), Phi_nm.T @ C)
    Phi = Phi_nm; F_out = Fc
else:
    Phi = np.exp(-(Dd / sigma) ** 2)
    Wrbf = np.linalg.solve(Phi + LAMBDA * np.eye(len(F)), C)  # (N, K)
    F_out = F
formas = np.zeros((K, len(tun.P), 3), np.float32)
formas[:, idx_saia, :] = base_pca.reshape(K, len(idx_saia), 3)
erro_treino = float(np.abs(Phi @ Wrbf - C).max())

# grava: formas corretivas originais (se houver) + rbf_00..rbf_K-1, e o modelo RBF em extras
j = json.loads(json.dumps(tun.j)); buf = bytearray(tun.b)
pr = j['meshes'][0]['primitives'][0]
if MODO == "puro": pr.pop('targets', None); nomes = []
else: nomes = list(nomes_corr)
alvos_novos = [formas[k] for k in range(K)]
for D in alvos_novos:
    while len(buf) % 4: buf.append(0)
    off = len(buf); buf.extend(D.astype(np.float32).tobytes())
    j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': D.nbytes})
    j['accessors'].append({'bufferView': len(j['bufferViews']) - 1, 'componentType': 5126, 'count': int(len(D)), 'type': 'VEC3',
                           'min': D.min(0).tolist(), 'max': D.max(0).tolist()})
pr.setdefault('targets', [])
pr['targets'] += [{'POSITION': len(j['accessors']) - K + i} for i in range(K)]
nomes += [f"rbf_{k:02d}" for k in range(K)]
j['meshes'][0]['weights'] = [0.0] * len(nomes)
ex = j['meshes'][0].setdefault('extras', {}); ex['targetNames'] = nomes
ex['rbf'] = {"modo": MODO, "sigma": round(sigma, 6), "centros": np.round(F_out, 6).tolist(), "pesos": np.round(Wrbf, 6).tolist(),
             "formas": [f"rbf_{k:02d}" for k in range(K)], "caracteristicas": "direção da coxa l e r no referencial da saia (6 valores)"}
while len(buf) % 4: buf.append(0)
j['buffers'][0]['byteLength'] = len(buf)
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
open(SAIDA, 'wb').write(struct.pack('<III', 0x46546C67, 2, 28 + len(js) + len(buf)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(buf), 0x004E4942) + bytes(buf))
# o mesmo modelo em arquivo ao lado, para o controlador do Godot (que não lê extras de malha do glTF)
json.dump(ex['rbf'], open(SAIDA.replace('.glb', '.rbf.json'), 'w'), separators=(',', ':'))
rel = {"modo": MODO, "poses_treino": len(F), "K": K, "energia_pca": round(energia, 4), "sigma": round(sigma, 4),
       "erro_max_treino": round(erro_treino, 6), "formas_total": len(nomes), "bytes": os.path.getsize(SAIDA)}
print(json.dumps(rel))
if REL: json.dump(rel, open(REL, 'w'), indent=1)
