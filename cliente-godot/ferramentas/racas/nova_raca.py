#!/usr/bin/env python3
"""Padrão Valtheria de corpo próprio por raça (24/11/2026).
Entrada (pasta fontes/): <chave>_frente.jpg, <chave>_prancha.jpg, <chave>_malha.glb (Hunyuan3D-2.1, Gen Shape).
Saída: assets/chars/body_<chave>.glb no jogo + prévia das juntas + relatório JSON.
uso: python3 nova_raca.py <chave> <altura_m> [--ajuste=arquivo.json]
Passos: 1) reduz a malha para 40 mil triângulos e normaliza (y de -1 a 1, frente +z, esquerda +x)
        2) acha as articulações pelo gabarito de proporção + medida da malha (juntas.py)
        3) assa a textura das pranchas com UV automático (assar_textura.py)
        4) pele automática no esqueleto oficial de 65 ossos (pele_automatica.mjs), sem mudar ossos nem animações
"""
import sys, json, subprocess, os, numpy as np, trimesh
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import juntas
R = os.path.dirname(os.path.abspath(__file__)); F = os.path.join(R, 'fontes'); OUT = os.path.join(R, 'saida')
os.makedirs(OUT, exist_ok=True)
chave, altura = sys.argv[1], float(sys.argv[2])
aj = {}
for a in sys.argv[3:]:
    if a.startswith('--ajuste='): aj = json.load(open(a[9:]))
m = list(trimesh.load(f'{F}/{chave}_malha.glb').geometry.values())[0]
if len(m.faces) > 42000: m = m.simplify_quadric_decimation(face_count=40000)
# normaliza: centro x/z no meio do corpo, altura de -1 a 1
v = m.vertices.copy(); lo, hi = v.min(0), v.max(0); c = (lo + hi) / 2; e = 2.0 / (hi[1] - lo[1])
m.vertices = (v - [c[0], c[1], c[2]]) * e
dec = f'{OUT}/{chave}_dec.ply'; m.export(dec)
J = juntas.detectar(m, aj); juntas.previa(m, J, f'{OUT}/{chave}_juntas.png')
subprocess.run(['python3', f'{R}/assar_textura.py', dec, f'{F}/{chave}_frente.jpg', f'{F}/{chave}_prancha.jpg', f'{OUT}/{chave}_tex.glb'], check=True)
cfg = {'model': {'xs': J['xs'], 'k': 1, 'kz': 1, 'hs': 1, 'dy': 0}, 'src': f'{OUT}/{chave}_tex.glb', 'semWeld': True, 'height': altura,
       'y0': J['y0'], 'top': J['top'], 'tris': 40000, 'spine': J['spine'], 'headTop': J['headTop'], 'rTorso': J['rTorso'], 'rHead': J['rHead'],
       'rNeck': J['rNeck'], 'arm': J['arm'], 'leg': J['leg'], 'hip': [J['hip'][0], J['hip'][1], round(J['leg']['r'][0] * 0.8, 3)],
       'rPelvis': round(J['rTorso'] * 0.6, 3), 'shoulder': J['shoulder'], 'extra': aj.get('extra', [])}
cj = f'{OUT}/{chave}_cfg.json'; json.dump(cfg, open(cj, 'w'), indent=1)
r = subprocess.run(['node', 'pele.mjs', chave], cwd='/home/claude/gt', env={**os.environ, 'CFG_JSON': cj}, capture_output=True, text=True, check=True)
print(r.stdout.strip().splitlines()[0])
# cabeça inteira no osso Head e pescoço em rampa (sem isso o rosto estica nas animações)
corpo = f'/home/claude/valtheria/cliente-godot/assets/chars/body_{chave}.glb'
aqui = os.path.dirname(os.path.abspath(__file__))
# pesos espalhados nas dobras (cintura, virilha, ombro, joelho) e depois a cabeça inteira
subprocess.run(['python3', os.path.join(aqui, 'suavizar_pesos.py'), corpo, corpo], check=True)
subprocess.run(['python3', os.path.join(aqui, 'pesos_cabeca.py'), corpo, corpo], check=True)
# beira das ilhas de UV sem preto (riscos escuros nas costuras)
subprocess.run(['python3', os.path.join(aqui, 'preencher_bordas.py'), corpo, corpo], check=True)
# altura da pelve -> fator 'hip' das animações (pelve do esqueleto base = 0,95 m)
pel = (J['spine']['pelvis'][0] - J['y0']) * altura / (J['top'] - J['y0'])
print(json.dumps({'chave': chave, 'altura': altura, 'hip': round(pel / 0.95, 3)}))
