# Valtheria V3 — D58 (AUT-021): acionamento das formas corretivas da túnica pelo ângulo da coxa.
# A MESMA fórmula está no controlador de teste do Godot (testes/prototipos/corretivas_controlador.gd).
# Ângulos no referencial da bacia (pelvis), relativos ao repouso:
#   flexao > 0: coxa à frente; flexao < 0: coxa para trás; abducao > 0: coxa para fora; abducao < 0: para dentro.
import numpy as np

LIMITE = 1.3   # extrapolação máxima além do ângulo de construção
LADOS = (("l", 1.0), ("r", -1.0))
# nome -> {lado: (flexao, abducao)} da pose de construção (o lado que não aparece fica em repouso)
CONSTRUCAO = {}
for s, _ in LADOS:
    CONSTRUCAO[f"corr_coxa_{s}_frente45"] = {s: (45, 0)}
    CONSTRUCAO[f"corr_coxa_{s}_frente90"] = {s: (90, 0)}
    CONSTRUCAO[f"corr_coxa_{s}_frente135"] = {s: (135, 0)}
    CONSTRUCAO[f"corr_coxa_{s}_tras45"] = {s: (-45, 0)}
    CONSTRUCAO[f"corr_coxa_{s}_fora45"] = {s: (0, 45)}
    CONSTRUCAO[f"corr_coxa_{s}_dentro25"] = {s: (0, -25)}
CONSTRUCAO["corr_coxas_ambas90"] = {"l": (90, 0), "r": (90, 0)}   # forma de combinação (as duas coxas à frente)
FORMAS = list(CONSTRUCAO.keys())   # ordem de construção: individuais primeiro, combinação por último

def _eixos(G0):
    R = G0["pelvis"][:3, :3]
    return R.T @ np.array([0.0, 0.0, 1.0]), R.T @ np.array([0.0, 1.0, 0.0]), R.T @ np.array([1.0, 0.0, 0.0])

import os
ALFA = float(os.environ.get("V3_CORR_ALFA", "0.5"))   # referencial da saia: mistura bacia (0) -> spine_01 (1)

def quadro_saia(G, G0):
    """orientação média da saia: mistura da bacia com a spine_01 (a spine_01 levada à convenção da bacia pelo repouso)"""
    Rrel = G0["pelvis"][:3, :3].T @ G0["spine_01"][:3, :3]
    M = (1 - ALFA) * G["pelvis"][:3, :3] + ALFA * G["spine_01"][:3, :3] @ Rrel.T
    u, _, vt = np.linalg.svd(M); return u @ vt

def direcao(G, s, G0):
    Rp = quadro_saia(G, G0)
    d = G[f"calf_{s}"][:3, 3] - G[f"thigh_{s}"][:3, 3]
    return Rp.T @ (d / np.linalg.norm(d))

def angulos(G, G0):
    """{lado: (flexao_graus, abducao_graus)}"""
    F, U, L = _eixos(G0); out = {}
    for s, sinal in LADOS:
        def ang(Gx):
            d = direcao(Gx, s, G0)
            return np.degrees(np.arctan2(d @ F, -(d @ U))), np.degrees(np.arcsin(np.clip(sinal * (d @ L), -1.0, 1.0)))
        f, a = ang(G); f0, a0 = ang(G0)
        out[s] = (f - f0, a - a0)
    return out

def _tenda(x, a, b, c):
    return float(np.clip((x - a) / (b - a), 0, 1) - np.clip((x - b) / (c - b), 0, 1))

def pesos(G, G0):
    w = {}; ang = angulos(G, G0)
    for s, (f, a) in ang.items():
        w[f"corr_coxa_{s}_frente45"] = _tenda(f, 0, 45, 90)
        w[f"corr_coxa_{s}_frente90"] = _tenda(f, 45, 90, 135)
        w[f"corr_coxa_{s}_frente135"] = float(np.clip((f - 90) / 45, 0, LIMITE))
        w[f"corr_coxa_{s}_tras45"] = float(np.clip(-f / 45, 0, LIMITE))
        w[f"corr_coxa_{s}_fora45"] = float(np.clip(a / 45, 0, LIMITE))
        w[f"corr_coxa_{s}_dentro25"] = float(np.clip(-a / 25, 0, LIMITE))
    w["corr_coxas_ambas90"] = float(np.clip(min(ang["l"][0], ang["r"][0]) / 90, 0, LIMITE))
    return w

# ---- AUT-022: deformação por exemplos (RBF) ----
def rbf_features(G, G0):
    """direção das duas coxas no referencial da saia, relativa ao repouso (6 valores)"""
    out = []
    for s, _ in LADOS:
        out += list(direcao(G, s, G0) - direcao(G0, s, G0))
    return np.array(out)

def rbf_pesos(G, G0, modelo):
    """pesos das formas rbf_xx para esta pose: soma de gaussianas sobre as poses de treino"""
    f = rbf_features(G, G0); C = np.array(modelo["centros"]); W = np.array(modelo["pesos"])
    phi = np.exp(-(np.linalg.norm(C - f, axis=1) / modelo["sigma"]) ** 2)
    return dict(zip(modelo["formas"], (phi @ W).tolist()))

# ---- AUT-023: ativação condicional do RBF (mesma regra no controlador do Godot) ----
RBF_LIMIAR = {"flexao_max": 45.0, "flexao_min": -35.0, "abducao_abs": 25.0}   # AUT-023: mesma qualidade, RBF ativo em ~30% dos quadros de teste
if os.environ.get("V3_RBF_LIMIAR"):   # estudo: "flexao_max,flexao_min,abducao_abs"
    _v = [float(x) for x in os.environ["V3_RBF_LIMIAR"].split(",")]
    RBF_LIMIAR = {"flexao_max": _v[0], "flexao_min": _v[1], "abducao_abs": _v[2]}
def rbf_ativo(G, G0):
    """o RBF só é avaliado quando alguma coxa sai da faixa comum (andar, correr, parado)"""
    for f, a in angulos(G, G0).values():
        if f > RBF_LIMIAR["flexao_max"] or f < RBF_LIMIAR["flexao_min"] or abs(a) > RBF_LIMIAR["abducao_abs"]:
            return True
    return False
