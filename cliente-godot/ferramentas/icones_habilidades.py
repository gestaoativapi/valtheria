#!/usr/bin/env python3
"""Pinta os ícones das habilidades (estilo fantasia com relevo 3D): um por tipo e elemento.
Fundo em degradê da cor do elemento, desenho em relevo (luz em cima, sombra embaixo) e brilho do elemento.
uso: python3 ferramentas/icones_habilidades.py  -> assets/icones/habilidades/<tipo>_<elemento>.png (96 px)"""
import json, math, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.join(AQUI, "..")
OUT = os.path.join(RAIZ, "assets", "icones", "habilidades")
S = 256
COR = {"fogo": ((255, 214, 110), (190, 50, 10), (40, 8, 2)), "gelo": ((225, 248, 255), (70, 160, 235), (8, 30, 60)),
       "vento": ((225, 255, 235), (90, 200, 150), (8, 40, 30)), "terra": ((240, 210, 150), (150, 100, 50), (35, 22, 10)),
       "raio": ((255, 250, 170), (150, 130, 255), (25, 15, 60)), "agua": ((200, 235, 255), (40, 120, 220), (5, 20, 55)),
       "luz": ((255, 248, 205), (235, 175, 60), (60, 35, 5)), "sombra": ((220, 180, 255), (110, 50, 170), (15, 5, 30))}


def P(pts, cx=128, cy=128, k=1.0):
    return [(cx + x * k, cy + y * k) for x, y in pts]


def estrela(n, r1, r2, rot=0.0):
    pts = []
    for i in range(n * 2):
        a = rot + math.pi * i / n
        r = r1 if i % 2 == 0 else r2
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


def desenho(d, tipo, el):
    W = 255
    if tipo in ("ataque",):
        d.polygon(P([(-10, 60), (70, -80), (80, -90), (78, -70), (10, 70)]), fill=W)          # lâmina
        d.polygon(P([(-40, 40), (30, 80), (20, 90), (-50, 50)]), fill=W)                      # guarda
        d.polygon(P([(-30, 70), (-65, 105), (-75, 95), (-40, 60)]), fill=W)                   # cabo
    elif tipo == "area":
        d.polygon(P(estrela(8, 95, 38, 0.2)), fill=W); d.ellipse([88, 88, 168, 168], fill=0)
        d.ellipse([103, 103, 153, 153], fill=W)
    elif tipo == "elemental":
        simbolo(d, el)
    elif tipo == "critico":
        for s in (-1, 1):
            d.polygon(P([(s * -70, 70), (s * 60, -70), (s * 72, -80), (s * 70, -62), (s * -55, 82)]), fill=W)
            d.polygon(P([(s * -50, 40), (s * -20, 70), (s * -28, 78), (s * -58, 48)]), fill=W)
    elif tipo == "atordoar":
        d.polygon(P([(-60, -40), (60, -40), (55, 30), (0, 85), (-55, 30)]), fill=W)
        for i, x in enumerate((-50, 0, 50)):
            d.polygon(P(estrela(5, 18, 8, -1.57), 128 + x, 50 if i != 1 else 30), fill=W)
    elif tipo == "avanco":
        for x in (-60, -10, 40):
            d.polygon(P([(x - 20, -60), (x + 30, 0), (x - 20, 60), (x - 5, 60), (x + 45, 0), (x - 5, -60)]), fill=W)
    elif tipo == "puxar":
        for i in range(3):
            y = -60 + i * 55
            d.ellipse([128 - 28, 128 + y - 30, 128 + 28, 128 + y + 30], outline=W, width=14)
    elif tipo == "provocar":  # trompa de guerra
        pts = []
        for i in range(21):
            t = i / 20
            a = math.pi * (0.95 - 0.75 * t)
            r = 70
            w = 6 + 34 * t ** 1.6
            pts.append((math.cos(a) * r - 10, math.sin(a) * -r + 40, w))
        sup = [(x - math.sin(0) * 0, y - w) for x, y, w in pts]
        inf = [(x, y + w * 0.6) for x, y, w in pts][::-1]
        d.polygon(P(sup + inf), fill=W)
        for r in (95, 115):
            d.arc([128 + 40 - r * 0.5, 128 - 60 - r * 0.5, 128 + 40 + r * 0.5, 128 - 60 + r * 0.5], -70, 10, fill=W, width=8)
    elif tipo == "aura":
        for r, w in ((95, 10), (65, 10), (35, 0)):
            if w:
                d.ellipse([128 - r, 128 - r, 128 + r, 128 + r], outline=W, width=w)
            else:
                d.ellipse([128 - r, 128 - r, 128 + r, 128 + r], fill=W)
    elif tipo == "buff":
        d.polygon(P([(0, -95), (70, -10), (25, -10), (25, 85), (-25, 85), (-25, -10), (-70, -10)]), fill=W)
        for x, y in ((-70, -70), (70, 60), (65, -75)):
            d.polygon(P(estrela(4, 16, 5), 128 + x, 128 + y), fill=W)
    elif tipo == "alternar":  # dois arcos de energia em volta de um núcleo (efeito ligado enquanto ativo)
        d.arc([38, 38, 218, 218], 200, 340, fill=W, width=18)
        d.arc([38, 38, 218, 218], 20, 160, fill=W, width=18)
        d.polygon(P([(-95, 0), (-70, -30), (-70, 30)]), fill=W)
        d.polygon(P([(95, 0), (70, -30), (70, 30)]), fill=W)
        d.ellipse([98, 98, 158, 158], fill=W)
    elif tipo == "invocar":
        d.ellipse([33, 33, 223, 223], outline=W, width=10)
        d.polygon(P(estrela(5, 92, 36, -1.57)), outline=W, width=8)
        d.ellipse([108, 108, 148, 148], fill=W)
    elif tipo in ("cura", "cura_area"):
        k = 0.8 if tipo == "cura_area" else 1.0
        d.polygon(P([(-25, -85), (25, -85), (25, -25), (85, -25), (85, 25), (25, 25), (25, 85), (-25, 85), (-25, 25), (-85, 25), (-85, -25), (-25, -25)], k=k), fill=W)
        if tipo == "cura_area":
            d.ellipse([20, 20, 236, 236], outline=W, width=10)
    elif tipo == "reviver":
        for s in (-1, 1):
            d.polygon(P([(0, 40), (s * 30, -20), (s * 95, -70), (s * 80, -30), (s * 100, -20), (s * 75, 10), (s * 85, 25), (s * 40, 40)]), fill=W)
        d.ellipse([110, 40, 146, 76], fill=W)
    elif tipo == "purificar":
        d.polygon(P([(0, -90), (55, 10), (40, 60), (0, 80), (-40, 60), (-55, 10)]), fill=W)
        d.polygon(P(estrela(4, 30, 8), 175, 60), fill=W)
    elif tipo == "dreno":
        pts = [(math.cos(t) * t * 9, math.sin(t) * t * 9) for t in [i * 0.15 for i in range(70)]]
        d.line(P(pts), fill=W, width=14, joint="curve")
    elif tipo == "prender":
        d.arc([78, 30, 178, 140], 180, 360, fill=W, width=20)
        d.rounded_rectangle([60, 95, 196, 210], radius=16, fill=W)
        d.ellipse([116, 130, 140, 154], fill=0); d.rectangle([123, 145, 133, 180], fill=0)
    elif tipo == "debuff":
        d.polygon(P([(0, 95), (70, 10), (25, 10), (25, -85), (-25, -85), (-25, 10), (-70, 10)]), fill=W)
        for x in (-70, 70):
            d.ellipse([128 + x - 10, 60, 128 + x + 10, 85], fill=W)
    elif tipo == "equipamento":
        d.polygon(P([(-10, 90), (60, -80), (72, -88), (70, -70), (2, 92)]), fill=W)
        d.polygon(P([(-70, -55), (20, -55), (15, 20), (-25, 70), (-65, 20)]), fill=W)
    elif tipo == "habilidade":
        d.polygon(P([(0, -95), (70, -20), (0, 95), (-70, -20)]), fill=W)
        d.line(P([(-70, -20), (70, -20)]), fill=0, width=6); d.line(P([(0, -95), (0, 95)]), fill=0, width=4)
    elif tipo == "raca":
        d.polygon(P([(-85, 50), (-85, -50), (-45, 0), (0, -75), (45, 0), (85, -50), (85, 50)]), fill=W)
        for x in (-85, 0, 85):
            d.ellipse([128 + x - 12, 128 - (75 if x == 0 else 50) - 24, 128 + x + 12, 128 - (75 if x == 0 else 50)], fill=W)
    elif tipo == "oficio":
        d.polygon(P([(-85, -30), (60, -30), (85, -50), (85, -10), (40, 5), (40, 30), (65, 70), (-60, 70), (-35, 30), (-35, 5), (-85, -5)]), fill=W)
    else:
        simbolo(d, el)


def simbolo(d, el):
    W = 255
    if el == "fogo":
        d.polygon(P([(0, -95), (35, -40), (25, -60), (70, 10), (55, 70), (0, 92), (-55, 70), (-70, 10), (-30, -45), (-20, -10)]), fill=W)
    elif el == "gelo":
        for a in range(6):
            t = a * math.pi / 3
            d.line(P([(0, 0), (math.cos(t) * 95, math.sin(t) * 95)]), fill=W, width=14)
            for r in (45, 70):
                for s in (-0.5, 0.5):
                    d.line(P([(math.cos(t) * r, math.sin(t) * r), (math.cos(t) * r + math.cos(t + s * 2) * 25, math.sin(t) * r + math.sin(t + s * 2) * 25)]), fill=W, width=9)
    elif el == "vento":
        for i, r in enumerate((85, 60, 35)):
            d.arc([128 - r, 128 - r - 10 + i * 10, 128 + r, 128 + r - 10 + i * 10], 180, 30, fill=W, width=14)
    elif el == "terra":
        d.polygon(P([(-90, 70), (-55, -30), (-20, 10), (15, -85), (55, -10), (90, 70)]), fill=W)
    elif el == "raio":
        d.polygon(P([(20, -100), (-50, 10), (-5, 10), (-30, 100), (55, -20), (10, -20), (40, -100)]), fill=W)
    elif el == "agua":
        d.polygon(P([(0, -100), (50, -10), (60, 35), (35, 80), (0, 95), (-35, 80), (-60, 35), (-50, -10)]), fill=W)
    elif el == "luz":
        d.polygon(P(estrela(12, 100, 60)), fill=W); d.ellipse([78, 78, 178, 178], fill=W)
    else:
        d.ellipse([33, 33, 223, 223], fill=W); d.ellipse([75, 15, 255, 195], fill=0)


def pintar(tipo, el):
    c0, c1, c2 = COR[el]
    base = Image.new("RGBA", (S, S))
    # fundo: degradê radial da cor do elemento, borda escura
    for r in range(S // 2, 0, -2):
        t = r / (S / 2)
        col = tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3))
        if t < 0.35:
            col = tuple(int(c0[i] * (0.35 - t) / 0.35 + col[i] * t / 0.35) for i in range(3))
        ImageDraw.Draw(base).ellipse([S / 2 - r * 1.42, S / 2 - r * 1.42 + 18, S / 2 + r * 1.42, S / 2 + r * 1.42 + 18], fill=col + (255,))
    # desenho
    m = Image.new("L", (S, S), 0)
    desenho(ImageDraw.Draw(m), tipo, el)
    m = m.filter(ImageFilter.GaussianBlur(1.2))
    # brilho (glow) e sombra projetada
    glow = Image.new("RGBA", (S, S), c0 + (0,)); glow.putalpha(m.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.9)))
    sombra = Image.new("RGBA", (S, S), (0, 0, 0, 0)); sombra.putalpha(ImageChops.offset(m, 7, 9).filter(ImageFilter.GaussianBlur(6)).point(lambda v: int(v * 0.7)))
    base = Image.alpha_composite(base, glow)
    base = Image.alpha_composite(base, sombra)
    # relevo: preenchimento em degradê vertical (claro em cima), borda clara em cima-esquerda e escura embaixo-direita
    grad = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = y / S
        col = tuple(int(255 * (1 - t) * 0.55 + c0[i] * (0.45 + 0.1 * t) * (1 - 0.35 * t)) for i in range(3))
        gd.line([(0, y), (S, y)], fill=col + (255,))
    grad.putalpha(m)
    base = Image.alpha_composite(base, grad)
    luz = ImageChops.subtract(m, ImageChops.offset(m, 4, 4)).filter(ImageFilter.GaussianBlur(1.5))
    esc = ImageChops.subtract(m, ImageChops.offset(m, -4, -4)).filter(ImageFilter.GaussianBlur(1.5))
    lz = Image.new("RGBA", (S, S), (255, 255, 255, 0)); lz.putalpha(luz.point(lambda v: int(v * 0.85)))
    ez = Image.new("RGBA", (S, S), tuple(int(v * 0.4) for v in c2) + (0,)); ez.putalpha(esc.point(lambda v: int(v * 0.9)))
    base = Image.alpha_composite(base, lz)
    base = Image.alpha_composite(base, ez)
    # moldura arredondada com brilho no topo
    mold = Image.new("L", (S, S), 0); ImageDraw.Draw(mold).rounded_rectangle([0, 0, S - 1, S - 1], radius=40, fill=255)
    base.putalpha(mold)
    brilho = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(brilho).rounded_rectangle([10, 8, S - 11, S // 2], radius=34, fill=(255, 255, 255, 34))
    base = Image.alpha_composite(base, brilho)
    ImageDraw.Draw(base).rounded_rectangle([3, 3, S - 4, S - 4], radius=38, outline=c0 + (200,), width=5)
    return base.resize((96, 96), Image.LANCZOS)


if __name__ == "__main__":
    d = json.load(open(os.path.join(RAIZ, "data", "classes_v2.json"), encoding="utf-8"))
    chaves = sorted(set(h["icone"] for h in d["habilidades"].values()))
    os.makedirs(OUT, exist_ok=True)
    for k in chaves:
        tipo, el = k.rsplit("_", 1)
        pintar(tipo, el).save(os.path.join(OUT, k + ".png"))
    print("ícones:", len(chaves))
