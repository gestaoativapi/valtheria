#!/usr/bin/env python3
"""Preenche as bordas das ilhas de UV da textura de um corpo próprio (.glb).

A textura assada deixa o fundo preto entre as ilhas e um anel escuro na beira de cada ilha (onde a
projeção das vistas não alcançou). Com o filtro e os mipmaps da placa de vídeo esse preto vaza para
a malha e aparece como risco ou mancha escura nas costuras (ex.: manchas no rosto do gigante).
Aqui a beira de cada ilha (2 px) é refeita a partir do miolo e a cor é empurrada para fora da ilha
(16 px), que é o "padding" de textura usado em jogos. Não muda UV, malha nem pesos.
Uso: python3 preencher_bordas.py entrada.glb saida.glb [--anel 2] [--margem 16]
     python3 preencher_bordas.py entrada.glb saida.glb --manchas [--cabeca] [--y-min 2.2]   (pele clara: triângulos escuros isolados; só acima de y-min)
     python3 preencher_bordas.py entrada.glb saida.glb --botas   (pontos brancos nas botas)
"""
import io, json, struct, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

COMP = {5126: 'f4', 5123: 'u2', 5121: 'u1', 5125: 'u4'}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def main(src, dst, anel=2, margem=16):
    raw = open(src, 'rb').read()
    n = struct.unpack('<I', raw[12:16])[0]
    js = json.loads(raw[20:20 + n])
    b0 = 20 + n + 8
    binlen = struct.unpack('<I', raw[20 + n:24 + n])[0]
    binario = bytearray(raw[b0:b0 + binlen])

    def ler(i):
        a = js['accessors'][i]
        bv = js['bufferViews'][a['bufferView']]
        dt = np.dtype(COMP[a['componentType']]); nc = NC[a['type']]
        o = bv.get('byteOffset', 0) + a.get('byteOffset', 0); st = bv.get('byteStride', 0) or nc * dt.itemsize
        m = np.frombuffer(bytes(binario), dtype=np.uint8, count=st * a['count'], offset=o).reshape(a['count'], st)[:, :nc * dt.itemsize].copy()
        return m.view(dt).reshape(a['count'], nc)

    pr = js['meshes'][0]['primitives'][0]
    UV = ler(pr['attributes']['TEXCOORD_0']).astype(float)
    T = ler(pr['indices']).reshape(-1, 3).astype(int)
    mat = js['materials'][pr['material']]
    ii = js['textures'][mat['pbrMetallicRoughness']['baseColorTexture']['index']]['source']
    img = js['images'][ii]
    ivb = img['bufferView']
    bv = js['bufferViews'][ivb]
    im = Image.open(io.BytesIO(bytes(binario[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]))).convert('RGB')
    W, H = im.size
    mask = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(mask)
    for t in T:
        d.polygon([(UV[k, 0] * W, UV[k, 1] * H) for k in t], fill=255)
    m = np.asarray(mask) > 0
    a = np.asarray(im).astype(np.float32)
    # miolo confiável: ilha sem o anel da beira; a beira e o fundo são refeitos
    miolo = ndimage.binary_erosion(m, iterations=anel) | (m & ~ndimage.binary_erosion(m, iterations=1) & (a.mean(2) > 60))
    conhecido = miolo.copy()
    cor = np.where(conhecido[..., None], a, 0)
    alvo = ndimage.binary_dilation(m, iterations=margem)
    k = np.ones((3, 3), np.float32)
    for _ in range(anel + margem + 2):
        soma = np.stack([ndimage.convolve(cor[..., c] * conhecido, k, mode='nearest') for c in range(3)], -1)
        cont = ndimage.convolve(conhecido.astype(np.float32), k, mode='nearest')
        novo = (~conhecido) & (cont > 0) & alvo
        cor[novo] = soma[novo] / cont[novo, None]
        conhecido |= novo
    saida = np.where(conhecido[..., None], cor, a).clip(0, 255).astype(np.uint8)
    buf = io.BytesIO()
    fmt = 'PNG' if img.get('mimeType') == 'image/png' else 'JPEG'
    Image.fromarray(saida).save(buf, fmt, **({'quality': 92} if fmt == 'JPEG' else {}))
    novo_img = buf.getvalue()
    # remonta o binário com a imagem nova no lugar da antiga (as outras partes se deslocam)
    ini = bv.get('byteOffset', 0); fim = ini + bv['byteLength']
    delta = len(novo_img) - bv['byteLength']
    pad = (-delta) % 4
    binario[ini:fim] = novo_img + b'\x00' * pad
    bv['byteLength'] = len(novo_img)
    for i, v in enumerate(js['bufferViews']):
        if i != ivb and v.get('byteOffset', 0) >= fim:
            v['byteOffset'] = v.get('byteOffset', 0) + delta + pad
    js['buffers'][0]['byteLength'] = len(binario)
    jb = json.dumps(js, separators=(',', ':')).encode()
    jb += b' ' * ((-len(jb)) % 4)
    binario += b'\x00' * ((-len(binario)) % 4)
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(binario))
    out += struct.pack('<II', len(jb), 0x4E4F534A) + jb + struct.pack('<II', len(binario), 0x004E4942) + bytes(binario)
    open(dst, 'wb').write(out)
    print(f'{src}: textura {W}x{H}, ilhas {m.mean() * 100:.0f}% da imagem, beira refeita {anel} px, margem {margem} px')


def manchas(src, dst, viz_min=130.0, razao=0.6, y_min=-1e9, so_cabeca=False):
    """Triângulos isolados muito escuros no meio de pele clara (vistas que não alcançaram o ponto ao assar):
    pinta o pedaço da textura com a cor média dos vizinhos da malha. Use só em corpos de pele clara."""
    raw = open(src, 'rb').read()
    n = struct.unpack('<I', raw[12:16])[0]
    js = json.loads(raw[20:20 + n]); b0 = 20 + n + 8
    binlen = struct.unpack('<I', raw[20 + n:24 + n])[0]
    binario = bytearray(raw[b0:b0 + binlen])
    def ler(i):
        a = js['accessors'][i]; bvv = js['bufferViews'][a['bufferView']]
        dt = np.dtype(COMP[a['componentType']]); nc = NC[a['type']]
        o = bvv.get('byteOffset', 0) + a.get('byteOffset', 0); st = bvv.get('byteStride', 0) or nc * dt.itemsize
        mm = np.frombuffer(bytes(binario), dtype=np.uint8, count=st * a['count'], offset=o).reshape(a['count'], st)[:, :nc * dt.itemsize].copy()
        return mm.view(dt).reshape(a['count'], nc)
    pr = js['meshes'][0]['primitives'][0]
    P = ler(pr['attributes']['POSITION']).astype(float)
    UV = ler(pr['attributes']['TEXCOORD_0']).astype(float)
    T = ler(pr['indices']).reshape(-1, 3).astype(int)
    nomes = [js['nodes'][j]['name'] for j in js['skins'][0]['joints']]
    Jw = ler(pr['attributes']['JOINTS_0']).astype(int); Ww = ler(pr['attributes']['WEIGHTS_0']).astype(float)
    cabeca = np.where(Jw == nomes.index('Head'), Ww, 0).sum(1) > 0.9
    ii = js['textures'][js['materials'][pr['material']]['pbrMetallicRoughness']['baseColorTexture']['index']]['source']
    bv = js['bufferViews'][js['images'][ii]['bufferView']]
    im = Image.open(io.BytesIO(bytes(binario[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]))).convert('RGB')
    W, H = im.size
    a = np.asarray(im).astype(np.float32)
    # cor média de cada triângulo (centro e meio das arestas)
    def amostra(u):
        x = np.clip((u[..., 0] * W).astype(int), 0, W - 1); y = np.clip((u[..., 1] * H).astype(int), 0, H - 1)
        return a[y, x]
    pts = [UV[T].mean(1)] + [(UV[T[:, i]] + UV[T[:, (i + 1) % 3]]) / 2 for i in range(3)]
    cor = np.mean([amostra(p) for p in pts], axis=0)
    lum = cor.mean(1)
    chave = np.round(P / 1e-4).astype(np.int64)
    _, solda = np.unique(chave, axis=0, return_inverse=True); solda = solda.ravel()
    from collections import defaultdict
    por_v = defaultdict(list)
    for ti, t in enumerate(T):
        for k in t:
            por_v[solda[k]].append(ti)
    img = Image.fromarray(a.astype(np.uint8)); d = ImageDraw.Draw(img)
    feitos = 0
    for ti, t in enumerate(T):
        if lum[ti] > 95 or P[t, 1].min() < y_min or (so_cabeca and not cabeca[t].all()):
            continue
        viz = set()
        for k in t:
            viz.update(por_v[solda[k]])
        viz.discard(ti)
        viz = [v for v in viz if lum[v] > 95]
        if len(viz) < 2 or np.median(lum[viz]) < viz_min:
            # mancha de mais de um triângulo: olha também os vizinhos dos vizinhos
            anel2 = set()
            for v0 in list(viz) + [ti]:
                for k in T[v0]:
                    anel2.update(por_v[solda[k]])
            anel2.discard(ti)
            viz = [v for v in anel2 if lum[v] > 95]
        if len(viz) < 2:
            continue
        lv = lum[viz]
        if np.median(lv) < viz_min or lum[ti] > razao * np.median(lv):
            continue
        c = tuple(int(x) for x in np.median(cor[viz], axis=0))
        d.polygon([(UV[k, 0] * W, UV[k, 1] * H) for k in t], fill=c, outline=c)
        feitos += 1
    # pontos escuros menores que um triângulo (dentro das ilhas da cabeça): pixel a pixel, com inpaint
    if so_cabeca:
        import cv2
        mcab = Image.new('L', (W, H), 0); dm = ImageDraw.Draw(mcab)
        for t in T:
            if cabeca[t].all():
                dm.polygon([(UV[k, 0] * W, UV[k, 1] * H) for k in t], fill=255)
        mcab = ndimage.binary_erosion(np.asarray(mcab) > 0, iterations=2)
        b = np.asarray(img).astype(np.float32)
        lp = b.mean(2)
        viz_med = ndimage.median_filter(lp, size=13)
        escuro = mcab & (lp < 70) & (viz_med > viz_min)
        escuro = ndimage.binary_dilation(escuro, iterations=1) & mcab
        if escuro.any():
            b = cv2.inpaint(b.astype(np.uint8), escuro.astype(np.uint8) * 255, 4, cv2.INPAINT_TELEA)
            img = Image.fromarray(b)
        print(f'  pontos escuros na cabeça refeitos: {int(escuro.sum())} px')
    buf = io.BytesIO(); img.save(buf, 'JPEG', quality=92); novo_img = buf.getvalue()
    ini = bv.get('byteOffset', 0); fim = ini + bv['byteLength']; delta = len(novo_img) - bv['byteLength']; pad = (-delta) % 4
    binario[ini:fim] = novo_img + b'\x00' * pad; bv['byteLength'] = len(novo_img)
    ivb = js['images'][ii]['bufferView']
    for i, v in enumerate(js['bufferViews']):
        if i != ivb and v.get('byteOffset', 0) >= fim:
            v['byteOffset'] = v.get('byteOffset', 0) + delta + pad
    js['buffers'][0]['byteLength'] = len(binario)
    jb = json.dumps(js, separators=(',', ':')).encode(); jb += b' ' * ((-len(jb)) % 4)
    binario += b'\x00' * ((-len(binario)) % 4)
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(binario))
    out += struct.pack('<II', len(jb), 0x4E4F534A) + jb + struct.pack('<II', len(binario), 0x004E4942) + bytes(binario)
    open(dst, 'wb').write(out)
    print(f'{src}: {feitos} triângulos escuros isolados repintados')


def manchas_claras(src, dst, y_frac=0.15):
    """Pontos brancos nas botas (resto do fundo branco das pranchas que a projeção pegou na sola/ponta do pé):
    na região dos pés, pixels muito claros cercados de couro escuro são refeitos por inpaint."""
    import cv2
    raw = open(src, 'rb').read()
    n = struct.unpack('<I', raw[12:16])[0]
    js = json.loads(raw[20:20 + n]); b0 = 20 + n + 8
    binlen = struct.unpack('<I', raw[20 + n:24 + n])[0]
    binario = bytearray(raw[b0:b0 + binlen])
    def ler(i):
        a = js['accessors'][i]; bvv = js['bufferViews'][a['bufferView']]
        dt = np.dtype(COMP[a['componentType']]); nc = NC[a['type']]
        o = bvv.get('byteOffset', 0) + a.get('byteOffset', 0); st = bvv.get('byteStride', 0) or nc * dt.itemsize
        mm = np.frombuffer(bytes(binario), dtype=np.uint8, count=st * a['count'], offset=o).reshape(a['count'], st)[:, :nc * dt.itemsize].copy()
        return mm.view(dt).reshape(a['count'], nc)
    pr = js['meshes'][0]['primitives'][0]
    P = ler(pr['attributes']['POSITION']).astype(float)
    UV = ler(pr['attributes']['TEXCOORD_0']).astype(float)
    T = ler(pr['indices']).reshape(-1, 3).astype(int)
    ii = js['textures'][js['materials'][pr['material']]['pbrMetallicRoughness']['baseColorTexture']['index']]['source']
    ivb = js['images'][ii]['bufferView']; bv = js['bufferViews'][ivb]
    im = Image.open(io.BytesIO(bytes(binario[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]))).convert('RGB')
    W, H = im.size
    y0 = P[:, 1].min(); h = P[:, 1].max() - y0
    mp = Image.new('L', (W, H), 0); d = ImageDraw.Draw(mp)
    for t in T:
        if P[t, 1].max() < y0 + y_frac * h:
            d.polygon([(UV[k, 0] * W, UV[k, 1] * H) for k in t], fill=255)
    mp = np.asarray(mp) > 0
    b = np.asarray(im).astype(np.float32); lp = b.mean(2)
    viz = ndimage.median_filter(np.where(mp, lp, 90), size=41)  # mediana larga: a mancha pode ter vários px
    claro = mp & (lp > 165) & (viz < 135)
    claro = ndimage.binary_dilation(claro, iterations=2) & ndimage.binary_dilation(mp, iterations=2)
    if claro.any():
        b = cv2.inpaint(b.astype(np.uint8), claro.astype(np.uint8) * 255, 5, cv2.INPAINT_TELEA)
    buf = io.BytesIO(); Image.fromarray(b.astype(np.uint8)).save(buf, 'JPEG', quality=92); novo_img = buf.getvalue()
    ini = bv.get('byteOffset', 0); fim = ini + bv['byteLength']; delta = len(novo_img) - bv['byteLength']; pad = (-delta) % 4
    binario[ini:fim] = novo_img + b'\x00' * pad; bv['byteLength'] = len(novo_img)
    for i, v in enumerate(js['bufferViews']):
        if i != ivb and v.get('byteOffset', 0) >= fim:
            v['byteOffset'] = v.get('byteOffset', 0) + delta + pad
    js['buffers'][0]['byteLength'] = len(binario)
    jb = json.dumps(js, separators=(',', ':')).encode(); jb += b' ' * ((-len(jb)) % 4)
    binario += b'\x00' * ((-len(binario)) % 4)
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(binario))
    out += struct.pack('<II', len(jb), 0x4E4F534A) + jb + struct.pack('<II', len(binario), 0x004E4942) + bytes(binario)
    open(dst, 'wb').write(out)
    print(f'{src}: pontos claros nas botas refeitos: {int(claro.sum())} px')


if __name__ == '__main__':
    args = sys.argv[1:]
    if '--botas' in args:
        manchas_claras(args[0], args[1])
    elif '--manchas' in args:
        manchas(args[0], args[1], y_min=float(args[args.index('--y-min') + 1]) if '--y-min' in args else -1e9, so_cabeca='--cabeca' in args, viz_min=float(args[args.index('--viz-min') + 1]) if '--viz-min' in args else 130.0)
    else:
        anel = int(args[args.index('--anel') + 1]) if '--anel' in args else 2
        margem = int(args[args.index('--margem') + 1]) if '--margem' in args else 16
        main(args[0], args[1], anel, margem)
