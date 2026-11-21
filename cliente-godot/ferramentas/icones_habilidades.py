#!/usr/bin/env python3
"""Pinta os ícones das habilidades em estilo fantasia pintada (relevo 3D, energia do elemento, moldura escura).
Cada ícone = motivo (arma, escudo, caveira, asas...) + elemento. Camadas:
  1. fundo escuro com nebulosa da cor do elemento;
  2. energia do elemento atrás (chamas, cristais, raios, redemoinho, rochas, ondas, raios de luz, fumaça);
  3. motivo em metal polido com luz de contorno da cor do elemento; partes mágicas (gemas, lâmina encantada) brilham;
  4. faíscas na frente, vinheta e moldura de bronze escuro.
uso: python3 ferramentas/icones_habilidades.py [--so=motivo_elem,...] [--folha=arquivo.png]"""
import json, math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.join(AQUI, "..")
OUT = os.path.join(RAIZ, "assets", "icones", "habilidades")
S = 256
# claro, médio, escuro
COR = {"fogo": ((255, 226, 120), (235, 90, 20), (40, 6, 2)), "gelo": ((235, 252, 255), (90, 185, 245), (5, 22, 48)),
       "vento": ((225, 255, 225), (80, 210, 140), (4, 34, 26)), "terra": ((250, 215, 140), (180, 110, 40), (30, 16, 6)),
       "raio": ((255, 252, 190), (160, 120, 255), (18, 8, 50)), "agua": ((205, 240, 255), (30, 130, 235), (3, 14, 45)),
       "luz": ((255, 250, 215), (250, 190, 60), (50, 28, 4)), "sombra": ((225, 175, 255), (130, 50, 200), (10, 3, 22))}


def P(pts, cx=128, cy=128, k=1.0, rot=0.0):
    c, s = math.cos(rot), math.sin(rot)
    return [(cx + (x * c - y * s) * k, cy + (x * s + y * c) * k) for x, y in pts]


def estrela(n, r1, r2, rot=0.0):
    return [(math.cos(rot + math.pi * i / n) * (r1 if i % 2 == 0 else r2),
             math.sin(rot + math.pi * i / n) * (r1 if i % 2 == 0 else r2)) for i in range(n * 2)]


def ruido(seed, esc=8, oit=4):
    rng = np.random.default_rng(seed)
    tot = np.zeros((S, S), np.float32)
    amp, f = 1.0, esc
    for _ in range(oit):
        g = rng.random((f + 1, f + 1)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)
        tot += np.asarray(im, np.float32) / 255 * amp
        amp *= 0.5; f *= 2
    tot -= tot.min(); tot /= max(1e-6, tot.max())
    return tot


def camada(cor, mask):
    im = Image.new("RGBA", (S, S), tuple(cor) + (0,))
    im.putalpha(mask)
    return im


# ---------------------------------------------------------------- motivos
# cada função desenha em M (metal/sólido) e A (parte mágica que brilha)
def lamina(M, A, rot=-0.785, k=1.12, cx=128, cy=128, gema=True):
    M.polygon(P([(-15, 40), (-17, -66), (0, -104), (17, -66), (15, 40)], cx, cy, k, rot), fill=255)        # lâmina
    M.line(P([(0, 34), (0, -84)], cx, cy, k, rot), fill=0, width=max(2, int(3 * k)))
    A.line(P([(-8, 30), (-9, -66)], cx, cy, k, rot), fill=255, width=max(2, int(4 * k)))                             # fio encantado
    M.polygon(P([(-50, 36), (-30, 44), (30, 44), (50, 36), (44, 56), (-44, 56)], cx, cy, k, rot), fill=255)  # guarda
    M.polygon(P([(-8, 56), (8, 56), (8, 86), (-8, 86)], cx, cy, k, rot), fill=255)                          # cabo
    M.ellipse(_bb(P([(0, 94)], cx, cy, k, rot)[0], 11 * k), fill=255)
    if gema:
        A.ellipse(_bb(P([(0, 46)], cx, cy, k, rot)[0], 8 * k), fill=255)


def _bb(c, r):
    return [c[0] - r, c[1] - r, c[0] + r, c[1] + r]


def m_espada(M, A, r):
    lamina(M, A)


def m_machado(M, A, r):
    M.polygon(P([(-6, -90), (6, -90), (6, 95), (-6, 95)], rot=-0.6), fill=255)
    M.polygon(P([(6, -80), (60, -105), (85, -60), (80, -10), (60, 20), (6, 0)], rot=-0.6), fill=255)
    M.polygon(P([(-6, -70), (-35, -80), (-40, -40), (-6, -30)], rot=-0.6), fill=255)
    A.line(P([(62, -100), (84, -60), (78, -12), (60, 16)], rot=-0.6), fill=255, width=6)


def m_martelo(M, A, r):
    M.polygon(P([(-6, -40), (6, -40), (6, 100), (-6, 100)], rot=0.6), fill=255)
    M.polygon(P([(-70, -95), (70, -95), (76, -30), (-76, -30)], rot=0.6), fill=255)
    A.polygon(P([(-18, -80), (18, -80), (18, -45), (-18, -45)], rot=0.6), fill=255)
    A.ellipse(_bb(P([(0, 100)], rot=0.6)[0], 9), fill=255)


def m_arco(M, A, r):
    M.arc([20, 20, 236, 236], 120, 330, fill=255, width=16)
    M.line(P([(-54, 94), (90, -50)]), fill=255, width=4)
    M.line(P([(-80, 80), (75, -75)]), fill=255, width=8)          # flecha
    M.polygon(P([(75, -75), (100, -100), (92, -66), (66, -92)]), fill=255)
    A.polygon(P([(80, -80), (100, -100), (88, -74)]), fill=255)
    for i in range(3):
        A.polygon(P([(-80 + i * 10, 80 - i * 10), (-100 + i * 10, 76 - i * 10), (-84 + i * 10, 96 - i * 10)]), fill=255)


def m_alvo(M, A, r):
    for rr, w in ((92, 12), (60, 12), (28, 0)):
        (A if rr == 28 else M).ellipse(_bb((128, 128), rr), outline=None if not w else 255, fill=255 if not w else None, width=w)
    M.line(P([(-100, 0), (-40, 0)]), fill=255, width=8); M.line(P([(100, 0), (40, 0)]), fill=255, width=8)
    M.line(P([(0, -100), (0, -40)]), fill=255, width=8); M.line(P([(0, 100), (0, 40)]), fill=255, width=8)


def m_adaga(M, A, r):
    lamina(M, A, rot=-0.5, k=0.92, cx=100, cy=140)
    lamina(M, A, rot=0.5, k=0.92, cx=156, cy=140)


def m_lanca(M, A, r):
    M.polygon(P([(-5, -40), (5, -40), (5, 110), (-5, 110)], rot=-0.785), fill=255)
    M.polygon(P([(0, -110), (20, -60), (8, -38), (-8, -38), (-20, -60)], rot=-0.785), fill=255)
    A.polygon(P([(0, -100), (10, -62), (0, -46), (-10, -62)], rot=-0.785), fill=255)
    for i in range(3):
        A.line(P([(-60 - i * 20, 40 + i * 10), (-10 - i * 20, -10 + i * 10)], rot=0.0), fill=255, width=5)


def m_escudo(M, A, r):
    M.polygon(P([(-80, -90), (80, -90), (80, 0), (50, 60), (0, 100), (-50, 60), (-80, 0)]), fill=255)
    M.polygon(P([(-66, -76), (66, -76), (66, -2), (40, 50), (0, 84), (-40, 50), (-66, -2)]), fill=0)
    M.polygon(P([(-56, -66), (56, -66), (56, -4), (34, 42), (0, 72), (-34, 42), (-56, -4)]), fill=255)
    A.polygon(P(estrela(4, 42, 12)), fill=255)
    A.ellipse(_bb((128, 128), 14), fill=255)


def m_punho(M, A, r):
    M.rounded_rectangle([62, 70, 194, 168], radius=26, fill=255)
    for i in range(4):
        M.rounded_rectangle([66 + i * 32, 52, 94 + i * 32, 110], radius=13, fill=255)
        M.line([(80 + i * 32, 62), (80 + i * 32, 100)], fill=0, width=3)
    M.rounded_rectangle([86, 160, 170, 214], radius=10, fill=255)
    A.rectangle([86, 168, 170, 180], fill=255)
    for i in range(5):
        a = math.pi * (1.1 + i * 0.2)
        A.line([(128 + math.cos(a) * 100, 128 + math.sin(a) * 100), (128 + math.cos(a) * 118, 128 + math.sin(a) * 118)], fill=255, width=6)


def m_mao(M, A, r):
    M.rounded_rectangle([74, 110, 182, 200], radius=30, fill=255)
    for i, (x, h) in enumerate(((78, 70), (104, 90), (130, 92), (156, 78))):
        M.rounded_rectangle([x, 200 - 90 - h, x + 22, 150], radius=11, fill=255)
    M.polygon([(74, 150), (40, 118), (34, 128), (70, 178)], fill=255)
    A.ellipse(_bb((128, 52), 26), fill=255)
    A.ellipse(_bb((128, 160), 16), fill=255)


def m_olho(M, A, r):
    M.polygon([(20, 128), (70, 70), (128, 54), (186, 70), (236, 128), (186, 186), (128, 202), (70, 186)], fill=255)
    M.ellipse(_bb((128, 128), 52), fill=0)
    A.ellipse(_bb((128, 128), 44), fill=255)
    M.ellipse([116, 92, 140, 164], fill=255)
    for i in range(8):
        a = i * math.pi / 4
        A.line([(128 + math.cos(a) * 110, 128 + math.sin(a) * 110), (128 + math.cos(a) * 124, 128 + math.sin(a) * 124)], fill=255, width=6)


def m_garra(M, A, r):
    for i in range(3):
        x = 70 + i * 55
        M.polygon([(x - 6, 30 + i * 6), (x + 26, 90), (x + 34, 200), (x + 10, 120), (x - 18, 60)], fill=255)
        A.line([(x + 4, 50 + i * 6), (x + 26, 180)], fill=255, width=5)


def m_caveira(M, A, r):
    M.ellipse([52, 34, 204, 176], fill=255)
    M.rounded_rectangle([84, 150, 172, 214], radius=14, fill=255)
    A.ellipse([76, 92, 118, 136], fill=255); A.ellipse([138, 92, 180, 136], fill=255)
    M.ellipse([76, 92, 118, 136], fill=0); M.ellipse([138, 92, 180, 136], fill=0)
    M.polygon([(128, 140), (118, 162), (138, 162)], fill=0)
    for x in range(96, 166, 14):
        M.line([(x, 182), (x, 214)], fill=0, width=4)


def m_coracao(M, A, r):
    pts = [(math.copysign(abs(math.sin(t)) ** 3, math.sin(t)) * 95,
            -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) * 6.2)
           for t in [i * math.pi / 60 for i in range(120)]]
    M.polygon(P(pts, cy=134), fill=255)
    A.polygon(P(pts, cy=128, k=0.6), fill=255)
    A.line(P([(-60, 4), (-25, 4), (-12, -30), (6, 36), (20, 4), (60, 4)], cy=134), fill=255, width=7)


def m_gota(M, A, r):
    pts = [(0, -110)] + [(math.cos(t) * 70, 30 + math.sin(t) * 70) for t in [-0.45 + i * (math.pi + 0.9) / 30 for i in range(31)]]
    M.polygon(P(pts), fill=255)
    A.polygon(P(pts, k=0.72, cy=138), fill=255)
    M.ellipse([96, 120, 118, 160], fill=0)


def m_cruz(M, A, r):
    M.polygon(P([(-22, -95), (22, -95), (22, -22), (95, -22), (95, 22), (22, 22), (22, 95), (-22, 95), (-22, 22), (-95, 22), (-95, -22), (-22, -22)]), fill=255)
    A.polygon(P([(-10, -82), (10, -82), (10, -10), (82, -10), (82, 10), (10, 10), (10, 82), (-10, 82), (-10, 10), (-82, 10), (-82, -10), (-10, -10)]), fill=255)
    M.ellipse(_bb((128, 128), 70), outline=255, width=8)


def m_lotus(M, A, r):
    for a in (-1.1, -0.55, 0, 0.55, 1.1):
        M.polygon(P([(0, 60), (-24, 0), (0, -80), (24, 0)], cy=150, rot=a), fill=255)
        A.line(P([(0, 50), (0, -60)], cy=150, rot=a), fill=255, width=5)
    A.ellipse(_bb((128, 60), 22), fill=255)


def m_asas(M, A, r):
    for s_ in (-1, 1):
        for i in range(6):
            ang = -3.05 + i * 0.25 if s_ < 0 else -0.09 - i * 0.25
            L = 72 + i * 10
            bx, by = s_ * 12, 10
            tip = (bx + math.cos(ang) * L, by + math.sin(ang) * L)
            n = (-math.sin(ang) * 13, math.cos(ang) * 13)
            M.polygon(P([(bx + n[0], by + n[1]), (tip[0] + n[0] * 0.3, tip[1] + n[1] * 0.3), tip, (bx - n[0], by - n[1])]), fill=255)
            M.line(P([(bx, by), tip]), fill=0, width=2)
    A.polygon(P([(0, -70), (18, -10), (0, 90), (-18, -10)]), fill=255)
    A.ellipse(_bb((128, 40), 15), fill=255)


def m_nota(M, A, r):
    M.ellipse([50, 150, 110, 200], fill=255); M.ellipse([140, 130, 200, 180], fill=255)
    M.rectangle([98, 50, 110, 176], fill=255); M.rectangle([188, 30, 200, 156], fill=255)
    M.polygon([(98, 50), (200, 30), (200, 56), (98, 76)], fill=255)
    for i in range(4):
        A.arc(_bb((128, 128), 70 + i * 14), 200, 250, fill=255, width=4)


def m_trompa(M, A, r):
    pts_s, pts_i = [], []
    for i in range(25):
        t = i / 24
        a = math.pi * (1.0 - 0.8 * t)
        x, y = math.cos(a) * 80 - 10, -math.sin(a) * 60 + 50
        w = 6 + 36 * t ** 1.8
        pts_s.append((x, y - w)); pts_i.append((x, y + w * 0.7))
    M.polygon(P(pts_s + pts_i[::-1]), fill=255)
    for i in range(3):
        M.line(P([pts_s[6 + i * 6], pts_i[6 + i * 6]]), fill=0, width=4)
    for rr in (40, 62, 84):
        A.arc([128 + 50 - rr, 128 - 70 - rr, 128 + 50 + rr, 128 - 70 + rr], -80, 20, fill=255, width=7)


def m_corrente(M, A, r):
    for i in range(4):
        cx, cy = 60 + i * 46, 60 + i * 46
        if i % 2 == 0:
            M.ellipse([cx - 36, cy - 22, cx + 36, cy + 22], outline=255, width=12)
        else:
            M.ellipse([cx - 22, cy - 36, cx + 22, cy + 36], outline=255, width=12)
    A.line([(40, 40), (216, 216)], fill=255, width=4)


def m_totem(M, A, r):
    M.rounded_rectangle([96, 30, 160, 220], radius=10, fill=255)
    M.polygon([(96, 70), (40, 50), (60, 90), (96, 96)], fill=255); M.polygon([(160, 70), (216, 50), (196, 90), (160, 96)], fill=255)
    A.ellipse([106, 54, 122, 70], fill=255); A.ellipse([134, 54, 150, 70], fill=255)
    M.rectangle([104, 90, 152, 100], fill=0); M.rectangle([104, 140, 152, 150], fill=0)
    A.polygon([(128, 160), (142, 190), (128, 210), (114, 190)], fill=255)


def m_golem(M, A, r):
    M.polygon([(84, 40), (172, 40), (186, 96), (70, 96)], fill=255)
    M.polygon([(56, 104), (200, 104), (186, 190), (70, 190)], fill=255)
    M.polygon([(30, 110), (56, 104), (60, 200), (24, 190)], fill=255); M.polygon([(226, 110), (200, 104), (196, 200), (232, 190)], fill=255)
    A.rectangle([100, 62, 120, 74], fill=255); A.rectangle([136, 62, 156, 74], fill=255)
    A.polygon(P(estrela(5, 28, 12, -1.57), 128, 146), fill=255)
    M.line([(110, 116), (96, 140), (112, 170)], fill=0, width=4)


def m_livro(M, A, r):
    M.polygon([(20, 70), (124, 90), (124, 220), (20, 196)], fill=255); M.polygon([(236, 70), (132, 90), (132, 220), (236, 196)], fill=255)
    for i in range(4):
        M.line([(34, 104 + i * 22), (110, 118 + i * 22)], fill=0, width=3); M.line([(146, 118 + i * 22), (222, 104 + i * 22)], fill=0, width=3)
    A.polygon(P(estrela(4, 44, 10), 128, 52), fill=255)


def m_armas(M, A, r):
    lamina(M, A, rot=-0.785, k=1.05, gema=False)
    lamina(M, A, rot=0.785, k=1.05, gema=False)
    A.ellipse(_bb((128, 128), 16), fill=255)


def m_manto(M, A, r):
    M.polygon([(96, 34), (160, 34), (196, 70), (212, 220), (44, 220), (60, 70)], fill=255)
    M.polygon([(110, 34), (146, 34), (128, 80)], fill=0)
    A.rectangle([120, 90, 136, 220], fill=255)
    A.polygon([(60, 210), (196, 210), (200, 222), (56, 222)], fill=255)
    M.polygon([(60, 70), (24, 96), (40, 150), (64, 120)], fill=255); M.polygon([(196, 70), (232, 96), (216, 150), (192, 120)], fill=255)


def m_escamas(M, A, r):
    for j in range(4):
        for i in range(4):
            x = 50 + i * 52 + (26 if j % 2 else 0); y = 50 + j * 44
            M.pieslice([x - 30, y - 30, x + 30, y + 30], 0, 180, fill=255)
            A.arc([x - 22, y - 22, x + 22, y + 22], 20, 160, fill=255, width=4)


def m_coroa(M, A, r):
    M.polygon([(30, 190), (30, 80), (80, 130), (128, 50), (176, 130), (226, 80), (226, 190)], fill=255)
    M.rectangle([30, 170, 226, 206], fill=255)
    for x, y in ((30, 80), (128, 50), (226, 80)):
        A.ellipse(_bb((x, y), 14), fill=255)
    for x in (70, 128, 186):
        A.ellipse(_bb((x, 188), 9), fill=255)


def m_orbe(M, A, r):
    A.ellipse(_bb((128, 128), 70), fill=255)
    M.arc(_bb((128, 128), 86), 200, 340, fill=255, width=10)
    M.arc(_bb((128, 128), 86), 20, 160, fill=255, width=10)
    for i in range(6):
        a = i * math.pi / 3 + 0.3
        M.polygon(P([(math.cos(a) * 96, math.sin(a) * 96), (math.cos(a + 0.12) * 120, math.sin(a + 0.12) * 120), (math.cos(a + 0.2) * 96, math.sin(a + 0.2) * 96)]), fill=255)


def m_tornado(M, A, r):
    for i in range(9):
        y = 40 + i * 20; w = 100 - i * 9
        (A if i % 2 else M).arc([128 - w + (i % 3) * 6, y - 14, 128 + w + (i % 3) * 6, y + 14], 0, 300, fill=255, width=9)


def m_meteoro(M, A, r):
    M.ellipse(_bb((160, 160), 50), fill=255)
    for i in range(5):
        A.line([(160 - 30 + i * 12, 160 - 40 + i * 6), (40 + i * 18, 40 + i * 6)], fill=255, width=12 - i)
    M.line([(140, 150), (170, 180)], fill=0, width=5); M.line([(165, 140), (150, 175)], fill=0, width=4)


def m_cupula(M, A, r):
    M.arc([30, 40, 226, 236], 180, 360, fill=255, width=14)
    M.rectangle([20, 136, 236, 156], fill=255)
    A.chord([46, 56, 210, 220], 180, 360, fill=255)
    for x in (70, 128, 186):
        M.line([(x, 70 if x == 128 else 82), (x, 136)], fill=255, width=6)


def m_prece(M, A, r):
    for s in (-1, 1):
        M.polygon(P([(s * 4, 90), (s * 4, -70), (s * 18, -90), (s * 40, -40), (s * 46, 40), (s * 30, 96)]), fill=255)
        M.polygon(P([(s * 40, 96), (s * 70, 120), (s * 4, 120), (s * 4, 96)]), fill=255)
    for i in range(7):
        a = -math.pi / 2 + (i - 3) * 0.32
        A.line([(128 + math.cos(a) * 92, 128 + math.sin(a) * 92), (128 + math.cos(a) * 120, 128 + math.sin(a) * 120)], fill=255, width=6)


def m_lua(M, A, r):
    M.ellipse(_bb((120, 128), 92), fill=255); M.ellipse(_bb((160, 104), 82), fill=0)
    for x, y, k in ((170, 150, 14), (204, 96, 10), (186, 196, 8)):
        A.polygon(P(estrela(4, k * 1.8, k * 0.4), x, y), fill=255)


def m_mascara(M, A, r):
    M.polygon([(40, 60), (216, 60), (206, 150), (170, 200), (128, 214), (86, 200), (50, 150)], fill=255)
    M.polygon([(66, 98), (112, 92), (108, 120), (70, 122)], fill=0); M.polygon([(190, 98), (144, 92), (148, 120), (186, 122)], fill=0)
    A.polygon([(70, 100), (108, 96), (106, 116), (74, 118)], fill=255); A.polygon([(186, 100), (148, 96), (150, 116), (182, 118)], fill=255)
    M.arc([96, 150, 160, 186], 200, 340, fill=0, width=5)
    A.line([(128, 60), (128, 214)], fill=255, width=4)


def m_bota(M, A, r):
    M.polygon([(92, 40), (150, 40), (152, 150), (206, 176), (214, 212), (84, 212), (90, 150)], fill=255)
    M.line([(92, 70), (150, 70)], fill=0, width=4); M.line([(88, 196), (212, 196)], fill=0, width=4)
    for i in range(4):
        A.polygon([(150, 70 + i * 16), (222 - i * 10, 30 + i * 20), (228 - i * 10, 46 + i * 20), (152, 92 + i * 16)], fill=255)
    for i in range(3):
        A.line([(16, 90 + i * 40), (70, 90 + i * 40)], fill=255, width=7)


def m_gema(M, A, r):
    A.polygon(P([(0, -95), (75, -30), (0, 100), (-75, -30)]), fill=255)
    M.polygon(P([(0, -95), (75, -30), (0, 100), (-75, -30)]), outline=255, width=8)
    M.line(P([(-75, -30), (75, -30)]), fill=255, width=6)
    M.line(P([(-35, -30), (0, -95), (35, -30), (0, 100), (-35, -30)]), fill=255, width=4)


def m_raiz(M, A, r):
    M.polygon([(116, 20), (140, 20), (146, 130), (110, 130)], fill=255)
    for a in (-1.0, -0.5, 0.0, 0.5, 1.0):
        M.line([(128, 126), (128 + math.sin(a) * 100, 126 + math.cos(a) * 100)], fill=255, width=12)
    for x, y in ((80, 50), (176, 46), (60, 90), (196, 92)):
        A.ellipse([x - 22, y - 12, x + 22, y + 12], fill=255)
    M.line([(128, 60), (80, 50)], fill=255, width=6); M.line([(128, 60), (176, 46)], fill=255, width=6)


def m_espinhos(M, A, r):
    m_escudo(M, A, r)
    for i in range(8):
        a = i * math.pi / 4
        M.polygon(P([(math.cos(a - 0.12) * 96, math.sin(a - 0.12) * 96), (math.cos(a) * 126, math.sin(a) * 126), (math.cos(a + 0.12) * 96, math.sin(a + 0.12) * 96)]), fill=255)


MOTIVOS = {k[2:]: v for k, v in globals().items() if k.startswith("m_")}


# ---------------------------------------------------------------- energia do elemento
def energia(el, rng):
    """máscara (L) da energia atrás do motivo"""
    m = Image.new("L", (S, S), 0); d = ImageDraw.Draw(m)
    if el == "fogo":
        n = ruido(rng.integers(1 << 30), 6, 4)
        yy = np.linspace(1.0, 0.0, S)[:, None]
        xx = 1 - np.abs(np.linspace(-1, 1, S))[None, :] ** 1.6
        f = np.clip((n * 1.3 - (1 - yy) * 0.9) * xx * 1.6 + yy * 0.25, 0, 1)
        return Image.fromarray((f * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))
    if el == "gelo":
        for _ in range(14):
            a = rng.random() * math.tau; L = 70 + rng.random() * 60; w = 0.08 + rng.random() * 0.08
            d.polygon(P([(0, 0), (math.cos(a - w) * L * 0.7, math.sin(a - w) * L * 0.7), (math.cos(a) * L, math.sin(a) * L), (math.cos(a + w) * L * 0.7, math.sin(a + w) * L * 0.7)]), fill=int(120 + rng.random() * 135))
        return m.filter(ImageFilter.GaussianBlur(1.5))
    if el == "vento":
        for i in range(7):
            r0 = 20 + i * 15
            d.arc(_bb((128, 128), r0), int(rng.random() * 360), int(rng.random() * 360) + 200, fill=200, width=8)
        return m.filter(ImageFilter.GaussianBlur(3)).rotate(rng.random() * 360)
    if el == "terra":
        for _ in range(9):
            x, y, r = 40 + rng.random() * 176, 120 + rng.random() * 120, 14 + rng.random() * 26
            d.polygon(P(estrela(3 + int(rng.random() * 3), r, r * 0.75, rng.random() * 6), x, y), fill=180)
        n = ruido(rng.integers(1 << 30), 10, 3)
        f = np.asarray(m, np.float32) / 255 + np.clip(n - 0.55, 0, 1) * 1.2 * np.linspace(0, 1, S)[:, None]
        return Image.fromarray((np.clip(f, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1))
    if el == "raio":
        def raio(x0, y0, x1, y1, w, prof):
            if prof <= 0 or w < 1:
                d.line([(x0, y0), (x1, y1)], fill=255, width=max(1, int(w))); return
            mx, my = (x0 + x1) / 2 + (rng.random() - 0.5) * 50 * prof / 5, (y0 + y1) / 2 + (rng.random() - 0.5) * 50 * prof / 5
            raio(x0, y0, mx, my, w, prof - 1); raio(mx, my, x1, y1, w, prof - 1)
            if rng.random() < 0.35:
                raio(mx, my, mx + (rng.random() - 0.5) * 120, my + rng.random() * 90, w * 0.5, prof - 2)
        for _ in range(3):
            raio(rng.random() * S, 0, rng.random() * S, S, 5, 5)
        return m.filter(ImageFilter.GaussianBlur(1.2))
    if el == "agua":
        for i in range(6):
            y = 150 + i * 18
            pts = [(x, y + math.sin(x / 22 + i) * 10) for x in range(0, S + 8, 8)]
            d.line(pts, fill=150 + i * 15, width=7)
        for _ in range(12):
            x, y, r = rng.random() * S, rng.random() * 150, 3 + rng.random() * 9
            d.ellipse(_bb((x, y), r), outline=200, width=2)
        return m.filter(ImageFilter.GaussianBlur(1.5))
    if el == "luz":
        for i in range(18):
            a = i * math.tau / 18 + rng.random() * 0.1
            w = 0.04 + (i % 2) * 0.05
            d.polygon(P([(0, 0), (math.cos(a - w) * 190, math.sin(a - w) * 190), (math.cos(a + w) * 190, math.sin(a + w) * 190)]), fill=110 + (i % 3) * 50)
        return m.filter(ImageFilter.GaussianBlur(4))
    # sombra: fumaça
    n = ruido(rng.integers(1 << 30), 5, 5)
    yy = np.linspace(0.2, 1.0, S)[:, None]
    f = np.clip((n - 0.38) * 2.2 * yy, 0, 1)
    return Image.fromarray((f * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))


def faiscas(el, rng):
    m = Image.new("L", (S, S), 0); d = ImageDraw.Draw(m)
    for _ in range(16):
        x, y = rng.random() * S, rng.random() * S
        r = 1.5 + rng.random() * 3.5
        if el in ("luz", "gelo", "raio"):
            d.polygon(P(estrela(4, r * 2.6, r * 0.5), x, y), fill=255)
        else:
            d.ellipse(_bb((x, y), r), fill=int(150 + rng.random() * 105))
    return m.filter(ImageFilter.GaussianBlur(0.8))


# ---------------------------------------------------------------- pintura
def pintar(chave):
    mot, el = chave.rsplit("_", 1)
    c0, c1, c2 = COR[el]
    rng = np.random.default_rng(abs(hash(chave)) % (1 << 31))
    # 1. fundo
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    dist = np.sqrt((xx - 128) ** 2 + (yy - 118) ** 2) / 181
    neb = ruido(rng.integers(1 << 30), 4, 4)
    t = np.clip(dist * 1.05 - neb * 0.25, 0, 1)[..., None]
    fundo = np.array(c1, np.float32) * (1 - t) * 0.55 + np.array(c2, np.float32) * t
    base = Image.fromarray(np.clip(fundo, 0, 255).astype(np.uint8)).convert("RGBA")
    # 2. energia
    en = energia(el, rng)
    base = Image.alpha_composite(base, camada(c1, en.point(lambda v: int(v * 0.85))))
    base = Image.alpha_composite(base, camada(c0, en.filter(ImageFilter.GaussianBlur(1)).point(lambda v: max(0, v - 140) * 2)))
    # 3. motivo
    mm = Image.new("L", (S, S), 0); ma = Image.new("L", (S, S), 0)
    MOTIVOS.get(mot, m_gema)(ImageDraw.Draw(mm), ImageDraw.Draw(ma), rng)
    sol = ImageChops.lighter(mm, ma).filter(ImageFilter.GaussianBlur(0.8))
    # sombra e halo
    base = Image.alpha_composite(base, camada((0, 0, 0), ImageChops.offset(sol, 6, 8).filter(ImageFilter.GaussianBlur(7)).point(lambda v: int(v * 0.8))))
    base = Image.alpha_composite(base, camada(c0, sol.filter(ImageFilter.GaussianBlur(12)).point(lambda v: int(v * 0.75))))
    # metal: degradê diagonal aço + reflexo do elemento embaixo
    g = (xx + yy) / (2 * S)
    stripe = np.exp(-((g - 0.42) ** 2) / 0.004) * 0.5
    aco = np.array((196, 200, 212), np.float32)
    band = 0.5 + 0.5 * np.sin((xx - yy) / 26.0)
    metal = aco[None, None] * (1.1 - g[..., None] * 1.05) * (0.8 + 0.2 * band[..., None]) + np.array(c1, np.float32)[None, None] * (g[..., None] * 0.6) + stripe[..., None] * 230
    metal_im = Image.fromarray(np.clip(metal, 0, 255).astype(np.uint8)).convert("RGBA")
    mm_b = mm.filter(ImageFilter.GaussianBlur(0.8))
    metal_im.putalpha(mm_b)
    base = Image.alpha_composite(base, metal_im)
    # relevo do metal
    luz = ImageChops.subtract(mm_b, ImageChops.offset(mm_b, 3, 3)).filter(ImageFilter.GaussianBlur(1))
    esc = ImageChops.subtract(mm_b, ImageChops.offset(mm_b, -3, -3)).filter(ImageFilter.GaussianBlur(1))
    base = Image.alpha_composite(base, camada((255, 255, 255), luz.point(lambda v: int(v * 0.9))))
    base = Image.alpha_composite(base, camada(tuple(int(v * 0.5) for v in c2), esc))
    borda = ImageChops.subtract(mm_b.filter(ImageFilter.MaxFilter(5)), mm_b)
    base = Image.alpha_composite(base, camada(c1, borda.point(lambda v: int(v * 0.7))))
    # partes mágicas
    ma_b = ma.filter(ImageFilter.GaussianBlur(1))
    base = Image.alpha_composite(base, camada(c1, ma_b.filter(ImageFilter.GaussianBlur(6))))
    dentro = np.asarray(ma.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.GaussianBlur(9)), np.float32)[..., None] / 255
    cor_n = np.array(c1, np.float32) * (1 - dentro) + np.array(c0, np.float32) * dentro
    cor_n *= (1.15 - yy[..., None] / S * 0.45)
    nuc = Image.fromarray(np.clip(cor_n, 0, 255).astype(np.uint8)).convert("RGBA")
    nuc.putalpha(ma_b)
    base = Image.alpha_composite(base, nuc)
    base = Image.alpha_composite(base, camada((255, 255, 255), ma.filter(ImageFilter.MinFilter(13)).filter(ImageFilter.GaussianBlur(5)).point(lambda v: int(v * 0.55))))
    # 4. faíscas, vinheta e moldura
    fa = faiscas(el, rng)
    base = Image.alpha_composite(base, camada(c0, fa))
    vin = Image.fromarray(np.clip((dist - 0.55) * 1.6, 0, 0.75).__mul__(255).astype(np.uint8))
    base = Image.alpha_composite(base, camada((0, 0, 0), vin))
    fr = ImageDraw.Draw(base)
    fr.rectangle([0, 0, S - 1, S - 1], outline=(18, 12, 8, 255), width=10)
    fr.rectangle([8, 8, S - 9, S - 9], outline=(120, 92, 54, 255), width=4)
    fr.line([(12, 12), (S - 13, 12)], fill=(222, 190, 130, 255), width=2)
    fr.line([(12, 12), (12, S - 13)], fill=(190, 156, 100, 255), width=2)
    fr.rectangle([12, 12, S - 13, S - 13], outline=(0, 0, 0, 160), width=2)
    return base.convert("RGB").resize((96, 96), Image.LANCZOS)


def chaves_dados():
    d = json.load(open(os.path.join(RAIZ, "data", "classes_v2.json"), encoding="utf-8"))
    ks = set(h["icone"] for h in d["habilidades"].values())
    for h in d.get("passivas_equipamento", {}).values():
        ks.add(h["icone"])
    return sorted(ks)


if __name__ == "__main__":
    args = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    ks = args["so"].split(",") if "so" in args else chaves_dados()
    os.makedirs(OUT, exist_ok=True)
    ims = []
    for k in ks:
        im = pintar(k)
        if "folha" not in args or "so" not in args:
            im.save(os.path.join(OUT, k + ".png"), optimize=True)
        ims.append(im)
    if "folha" in args:
        col = 12; lin = (len(ims) + col - 1) // col
        f = Image.new("RGB", (col * 100, lin * 100), (14, 12, 10))
        for i, im in enumerate(ims):
            f.paste(im, ((i % col) * 100 + 2, (i // col) * 100 + 2))
        f.save(args["folha"])
    print("ícones:", len(ims))
