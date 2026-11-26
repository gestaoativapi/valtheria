# Padrão Valtheria (26/11): refaz a pele do ROSTO a partir da imagem de frente, sem as manchas da assadura geral.
# O corpo final tem os mesmos vértices e UVs da malha assada (só escala/posição mudam), então o rosto é
# reprojetado na malha da assadura e escrito na textura final, em resolução maior.
# uso: python3 rosto_frontal.py <chave> [--tam=2048]   (ex.: humano_f)
import sys, numpy as np, trimesh
from PIL import Image
from scipy import ndimage

AQUI = '/home/claude/valtheria/cliente-godot/'
chave = sys.argv[1]
tam = 2048
for x in sys.argv[2:]:
    if x.startswith('--tam='): tam = int(x[6:])

def recorte(img, tol=60):
    a = np.asarray(img.convert('RGB')).astype(int)
    bg = np.median(np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)]), 0)
    fg = (np.abs(a - bg).sum(2) > tol) & ~(a.min(2) > 235)
    fg = ndimage.binary_opening(fg, iterations=2)
    lab, n = ndimage.label(fg)
    if n > 1:
        t = ndimage.sum(fg, lab, range(1, n + 1)); fg = lab == (1 + int(np.argmax(t)))
    ys, xs = np.where(fg)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    cor = a[y0:y1, x0:x1].astype(np.float32); m = fg[y0:y1, x0:x1]
    m = ndimage.binary_erosion(m, iterations=2)
    idx = ndimage.distance_transform_edt(~m, return_distances=False, return_indices=True)
    return cor[idx[0], idx[1]], m

def amostra(img, x, y):  # bilinear
    H, W = img.shape[:2]
    x = np.clip(x, 0, W - 1.001); y = np.clip(y, 0, H - 1.001)
    x0 = x.astype(int); y0 = y.astype(int); fx = (x - x0)[:, None]; fy = (y - y0)[:, None]
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x0 + 1] * fx * (1 - fy) + img[y0 + 1, x0] * (1 - fx) * fy + img[y0 + 1, x0 + 1] * fx * fy)

import os
_orig = next(c for c in [f'/home/claude/racas/saida/{chave}_tex.glb', f'/home/claude/orc/{chave}_tex.glb'] if os.path.exists(c))
m = trimesh.load(_orig, force='mesh', process=False)
V = m.vertices.astype(np.float64); Fc = m.faces; N = m.vertex_normals; T = m.visual.uv
lo, hi = V.min(0), V.max(0); alt = hi[1] - lo[1]
cor, msk = recorte(Image.open(f'{AQUI}ferramentas/racas/fontes/{chave}_frente.jpg'))
H, W = msk.shape
base_png = f'{AQUI}assets/chars/body_{chave}_{chave}_cor.jpg'
# sempre a partir da textura gravada no git (rodar duas vezes não acumula)
import subprocess, io
bruto = subprocess.run(['git', '-C', AQUI, 'show', 'HEAD:./assets/chars/' + base_png.split('/')[-1]], capture_output=True).stdout
base = np.asarray(Image.open(io.BytesIO(bruto)).convert('RGB').resize((tam, tam), Image.LANCZOS)).astype(np.float32)

# região do rosto/cabeça (mesmo critério da assadura) com borda suave para baixo (pescoço)
y_cab = lo[1] + 0.86 * alt
PX = T * (tam - 1); PX = PX.copy(); PX[:, 1] = (tam - 1) - PX[:, 1]
novo = base.copy(); peso = np.zeros((tam, tam), np.float32); ilha = np.zeros((tam, tam), bool); altm = np.zeros((tam, tam), np.float32); nzm = np.ones((tam, tam), np.float32)
fy = V[Fc][:, :, 1].max(1)
for f in Fc[fy > lo[1] + 0.80 * alt]:
    p = PX[f]
    x0 = max(int(np.floor(p[:, 0].min())) - 1, 0); x1 = min(int(np.ceil(p[:, 0].max())) + 1, tam - 1)
    y0 = max(int(np.floor(p[:, 1].min())) - 1, 0); y1 = min(int(np.ceil(p[:, 1].max())) + 1, tam - 1)
    gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
    if abs(d) < 1e-12: continue
    l0 = ((p[1, 1] - p[2, 1]) * (gx - p[2, 0]) + (p[2, 0] - p[1, 0]) * (gy - p[2, 1])) / d
    l1 = ((p[2, 1] - p[0, 1]) * (gx - p[2, 0]) + (p[0, 0] - p[2, 0]) * (gy - p[2, 1])) / d
    l2 = 1 - l0 - l1
    k = (l0 >= -0.05) & (l1 >= -0.05) & (l2 >= -0.05)
    if not k.any(): continue
    L = np.stack([l0[k], l1[k], l2[k]], 1)
    pos = L @ V[f]; nor = L @ N[f]; nor /= np.linalg.norm(nor, axis=1, keepdims=True) + 1e-9
    u = (pos[:, 0] - lo[0]) / (hi[0] - lo[0]); t = (hi[1] - pos[:, 1]) / alt
    c = amostra(cor, u * (W - 1), t * (H - 1))
    # peso: frente manda; some de lado; borda suave no pescoço
    w = np.clip((nor[:, 2] + 0.02) / 0.40, 0, 1) * np.clip((pos[:, 1] - (lo[1] + 0.80 * alt)) / (0.06 * alt), 0, 1)
    yy = (gy[k] - 0.5).astype(int); xx = (gx[k] - 0.5).astype(int)
    ilha[yy, xx] = True
    altm[yy, xx] = (pos[:, 1] - lo[1]) / alt
    nzm[yy, xx] = nor[:, 2]
    sel = w > peso[yy, xx]
    novo[yy[sel], xx[sel]] = c[sel]; peso[yy[sel], xx[sel]] = w[sel]

# manchas que sobram nas laterais da cabeça (texels escuros isolados): troca pela mediana da vizinhança na ilha
lum = base.mean(2)
med = ndimage.median_filter(lum, size=9)
mancha = ilha & (peso < 0.5) & (lum < med - 38)
mancha = ndimage.binary_dilation(mancha, iterations=1) & ilha
if mancha.any():
    ok = ilha & ~mancha
    ii = ndimage.distance_transform_edt(~ok, return_distances=False, return_indices=True)
    base[mancha] = base[ii[0][mancha], ii[1][mancha]]
# laterais e nuca: a assadura tem pontos escuros/claros soltos; troca pela mediana larga (tira o ponto, mantém
# a cor e as mechas grandes), só dentro da cabeça e só onde a frente não manda
lisa = np.stack([ndimage.median_filter(base[:, :, c], size=11) for c in range(3)], 2)
k_lado = (ilha & (peso < 0.9))[:, :, None] * (1 - np.clip(peso, 0, 1))[:, :, None] * 0.85
base = base * (1 - k_lado) + lisa * k_lado
w3 = ndimage.gaussian_filter(peso, 1.6)[:, :, None]
saida = base * (1 - w3) + novo * w3
# mechas escuras soltas nas laterais do cabelo: a vista de frente esticada de lado e a de lado da assadura
# desenham listras; acima da orelha, onde a lateral fica bem mais escura que o cabelo visto de frente, puxa
# para a cor do cabelo (orelhas e pele são mais claras e não entram)
topo = (nzm > 0.6) & (altm > 0.965) & ilha
if topo.sum() > 50:
    H = np.median(saida[topo], axis=0)
    lado = (ilha & (nzm < 0.5) & (altm > 0.885)).astype(np.float32)
    lado = ndimage.gaussian_filter(lado, 1.5)
    escuro = np.clip(((H.mean() - 25) - saida.mean(2)) / 35.0, 0, 1) * lado
    escuro = ndimage.gaussian_filter(escuro, 1.5)[:, :, None]
    saida = saida * (1 - 0.85 * escuro) + H[None, None, :] * (0.85 * escuro)
# costura sem risco escuro: todas as ilhas da malha ganham 6 px de borda com a própria cor (o filtro da textura
# pegava o fundo escuro entre as ilhas e desenhava linhas finas no rosto)
todas = np.zeros((tam, tam), bool)
for f in Fc:
    p = PX[f]
    x0 = max(int(np.floor(p[:, 0].min())), 0); x1 = min(int(np.ceil(p[:, 0].max())), tam - 1)
    y0 = max(int(np.floor(p[:, 1].min())), 0); y1 = min(int(np.ceil(p[:, 1].max())), tam - 1)
    gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
    if abs(d) < 1e-12: continue
    l0 = ((p[1, 1] - p[2, 1]) * (gx - p[2, 0]) + (p[2, 0] - p[1, 0]) * (gy - p[2, 1])) / d
    l1 = ((p[2, 1] - p[0, 1]) * (gx - p[2, 0]) + (p[0, 0] - p[2, 0]) * (gy - p[2, 1])) / d
    k = (l0 >= 0) & (l1 >= 0) & (1 - l0 - l1 >= 0)
    todas[(gy[k] - 0.5).astype(int), (gx[k] - 0.5).astype(int)] = True
todas = ndimage.binary_erosion(todas, iterations=1)  # a borda da ilha já costuma vir misturada com o fundo
fora = ~todas
ii = ndimage.distance_transform_edt(fora, return_distances=False, return_indices=True)
saida[fora] = saida[ii[0][fora], ii[1][fora]]
Image.fromarray(np.clip(saida, 0, 255).astype(np.uint8)).save(sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith('--') else f'/tmp/rf/{chave}_cor.jpg', quality=92)
print('ok', chave, 'texels do rosto', int((peso > 0.5).sum()), 'manchas trocadas', int(mancha.sum()))
