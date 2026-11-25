# Padrão Valtheria: textura "assada" a partir das pranchas (frente única + prancha frente/lado/costas).
# Gera UV automático (xatlas) e pinta cada texel misturando as vistas pela normal, com teste de visibilidade.
# uso: python3 assar_textura.py malha_dec.ply frente.jpg prancha.jpg saida.glb [--tam=2048]
import sys, numpy as np, trimesh, xatlas
from PIL import Image
from scipy import ndimage

def recorte(img, tol=60):
    a = np.asarray(img.convert('RGB')).astype(int)
    bg = np.median(np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)]), 0)
    fg = (np.abs(a - bg).sum(2) > tol) & ~(a.min(2) > 235)
    fg = ndimage.binary_opening(fg, iterations=2)
    lab, n = ndimage.label(fg)
    if n > 1:  # fica só com o maior bloco (o personagem)
        tam = ndimage.sum(fg, lab, range(1, n + 1)); fg = lab == (1 + int(np.argmax(tam)))
    ys, xs = np.where(fg)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    cor = a[y0:y1, x0:x1].astype(np.float32); m = fg[y0:y1, x0:x1]
    # tira a auréola do fundo: encolhe a máscara e preenche o fundo com a cor mais próxima do personagem
    m = ndimage.binary_erosion(m, iterations=2)
    idx = ndimage.distance_transform_edt(~m, return_distances=False, return_indices=True)
    cor = cor[idx[0], idx[1]]
    return cor, m

def rasterizar(P2, Z, faces, W, H):
    """z-buffer ortográfico: P2 em pixels (x,y), Z maior = mais perto da câmera"""
    zb = np.full((H, W), -1e9, np.float32)
    for f in faces:
        p = P2[f]; z = Z[f]
        x0 = max(int(np.floor(p[:, 0].min())), 0); x1 = min(int(np.ceil(p[:, 0].max())), W - 1)
        y0 = max(int(np.floor(p[:, 1].min())), 0); y1 = min(int(np.ceil(p[:, 1].max())), H - 1)
        if x1 < x0 or y1 < y0: continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(d) < 1e-9: continue
        l0 = ((p[1, 1] - p[2, 1]) * (gx - p[2, 0]) + (p[2, 0] - p[1, 0]) * (gy - p[2, 1])) / d
        l1 = ((p[2, 1] - p[0, 1]) * (gx - p[2, 0]) + (p[0, 0] - p[2, 0]) * (gy - p[2, 1])) / d
        l2 = 1 - l0 - l1
        dentro = (l0 >= -0.01) & (l1 >= -0.01) & (l2 >= -0.01)
        zz = l0 * z[0] + l1 * z[1] + l2 * z[2]
        sub = zb[y0:y1 + 1, x0:x1 + 1]
        np.maximum(sub, np.where(dentro, zz, -1e9), out=sub)
    return zb

def main():
    a = sys.argv[1:]; tam = 2048
    for x in a:
        if x.startswith('--tam='): tam = int(x[6:])
    a = [x for x in a if not x.startswith('--')]
    m = trimesh.load(a[0]); F = Image.open(a[1]); S = Image.open(a[2]); saida = a[3]
    v = m.vertices.astype(np.float64); fc = m.faces; vn = m.vertex_normals
    lo, hi = v.min(0), v.max(0)
    # vistas: (imagem, eixo horizontal, sinal, eixo de profundidade, sinal, normal da câmera)
    W3 = S.width // 3
    fr_c, fr_m = recorte(F)
    lado_c, lado_m = recorte(S.crop((W3, 0, 2 * W3, S.height)))
    cos_c, cos_m = recorte(S.crop((2 * W3, 0, 3 * W3, S.height)))
    vistas = [  # cor, máscara, eixo u (componente, sinal), eixo de profundidade (componente, sinal)
        ('frente', fr_c, fr_m, (0, +1), (2, +1)),
        ('costas', cos_c, cos_m, (0, -1), (2, -1)),
        ('esq', lado_c, lado_m, (2, +1), (0, +1)),          # lado esquerdo do personagem (+x), frente à direita da imagem
        ('dir', lado_c[:, ::-1], lado_m[:, ::-1], (2, -1), (0, -1)),  # lado direito: espelho do esquerdo
    ]
    prep = []
    for nome, cor, msk, (ui, us), (zi, zs) in vistas:
        H, W = msk.shape
        u = (v[:, ui] - lo[ui]) / (hi[ui] - lo[ui]); u = u if us > 0 else 1 - u
        t = (hi[1] - v[:, 1]) / (hi[1] - lo[1])
        P2 = np.stack([u * (W - 1), t * (H - 1)], 1)
        Z = v[:, zi] * zs
        zb = rasterizar(P2, Z, fc, W, H)
        nd = np.zeros(3); nd[zi] = zs
        prep.append((nome, cor, msk, P2, Z, zb, nd, ui, us, zi, zs, W, H))
    # UV automático
    vmap, idx, uvs = xatlas.parametrize(v.astype(np.float32), fc.astype(np.uint32))
    V = v[vmap]; N = vn[vmap]; T = uvs
    tex = np.zeros((tam, tam, 3), np.float32); wsum = np.zeros((tam, tam), np.float32)
    PX = T * (tam - 1); PX[:, 1] = (tam - 1) - PX[:, 1]
    for f in idx:
        p = PX[f]
        x0 = max(int(np.floor(p[:, 0].min())) - 1, 0); x1 = min(int(np.ceil(p[:, 0].max())) + 1, tam - 1)
        y0 = max(int(np.floor(p[:, 1].min())) - 1, 0); y1 = min(int(np.ceil(p[:, 1].max())) + 1, tam - 1)
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(d) < 1e-12: continue
        l0 = ((p[1, 1] - p[2, 1]) * (gx - p[2, 0]) + (p[2, 0] - p[1, 0]) * (gy - p[2, 1])) / d
        l1 = ((p[2, 1] - p[0, 1]) * (gx - p[2, 0]) + (p[0, 0] - p[2, 0]) * (gy - p[2, 1])) / d
        l2 = 1 - l0 - l1
        k = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        if not k.any(): continue
        L = np.stack([l0[k], l1[k], l2[k]], 1)
        pos = L @ V[f]; nor = L @ N[f]; nor /= np.linalg.norm(nor, axis=1, keepdims=True) + 1e-9
        cor = np.zeros((len(pos), 3)); ws = np.zeros(len(pos))
        for nome, ci, msk, P2, Z, zb, nd, ui, us, zi, zs, W, H in prep:
            w = np.clip(nor @ nd, 0, 1) ** 3
            if nome in ('esq', 'dir'): w = w * 0.6  # lados valem menos (pose da prancha difere um pouco)
            # rosto: a vista de frente manda (os lados da prancha desalinham e jogavam cabelo e sombra nas bochechas)
            cab = pos[:, 1] > lo[1] + 0.86 * (hi[1] - lo[1])
            if nome in ('esq', 'dir'): w = np.where(cab & (nor[:, 2] > 0.0), w * 0.15, w)
            u = (pos[:, ui] - lo[ui]) / (hi[ui] - lo[ui]); u = u if us > 0 else 1 - u
            t = (hi[1] - pos[:, 1]) / (hi[1] - lo[1])
            px = np.clip((u * (W - 1)).astype(int), 0, W - 1); py = np.clip((t * (H - 1)).astype(int), 0, H - 1)
            tol = np.where(cab, 0.06, 0.03) * (hi[1] - lo[1])  # rosto: nariz e sobrancelha não escondem o próprio rosto
            vis = (pos[:, zi] * zs) >= zb[py, px] - tol
            w = w * vis
            cor += ci[py, px] * w[:, None]; ws += w
        sola = (nor[:, 1] < -0.35) | ((pos[:, 1] < lo[1] + 0.022 * (hi[1] - lo[1])) | ((pos[:, 1] < lo[1] + 0.05 * (hi[1] - lo[1])) & (nor[:, 2] < 0.3)))  # fundo e borda da sola  # sola/fundo: nenhuma vista mostra; cor de couro escuro
        if sola.any(): cor[sola] = np.array([58, 48, 42]) * 1.0; ws[sola] = 1.0
        yy = (gy[k] - 0.5).astype(int); xx = (gx[k] - 0.5).astype(int)
        tex[yy, xx] = cor; wsum[yy, xx] = ws
    ok = wsum > 1e-4
    tex[ok] /= wsum[ok][:, None]
    # texels sem cor (escondidos em todas as vistas) e fora das ilhas: cor do vizinho mais próximo
    ii = ndimage.distance_transform_edt(~ok, return_distances=False, return_indices=True)
    tex = tex[ii[0], ii[1]]
    if '--sem-branco' in sys.argv:  # restos do fundo branco da foto (ponta das botas): troca pela cor vizinha
        br = (tex.min(2) > 228) & ((tex.max(2) - tex.min(2)) < 18)
        br = ndimage.binary_dilation(br, iterations=2)
        if br.any():
            jj = ndimage.distance_transform_edt(br, return_distances=False, return_indices=True)
            tex = tex[jj[0], jj[1]]
    img = Image.fromarray(np.clip(tex, 0, 255).astype(np.uint8))
    mat = trimesh.visual.material.PBRMaterial(baseColorTexture=img, roughnessFactor=0.85, metallicFactor=0)
    out = trimesh.Trimesh(V, idx, visual=trimesh.visual.TextureVisuals(uv=T, material=mat), process=False)
    out.vertex_normals = N
    out.export(saida)
    img.save(saida.replace('.glb', '_tex.jpg'), quality=90)
    print('ok', saida, len(V), 'vértices', 'cobertura', round(float(ok.mean()), 3))

main()
