# Valtheria V3 — teste da espada guardada na cintura (AUT-020 4.2), sem Godot e sem alterar character.gd.
# Reproduz a regra de bainha de cintura do jogo (osso pelvis, cabo deslocado e lâmina numa direção fixa no espaço
# do modelo), com a direção e o deslocamento lidos de espada_longa.json -> "bainha_cintura", e mede em todas as
# 28 animações oficiais (9 quadros cada):
#  - ângulo da lâmina com a vertical e posição da ponta em relação ao quadril (no repouso);
#  - altura mínima da lâmina em relação ao chão (y = 0);
#  - distância mínima da lâmina às coxas e canelas (cápsulas thigh->calf e calf->foot).
# Uso: python testar_bainha.py <saida.json> <anims_a.glb> <anims_b.glb> <corpo.glb> <altura_m> <espada_longa.json> [regra=jogo|v3]
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from testar_animacoes_base import Esqueleto, canais_animacao, amostra_pose
SAIDA, AA, AB, CORPO, ALTURA, CFG = sys.argv[1:7]
REGRA = sys.argv[7] if len(sys.argv) > 7 else "v3"
ALTURA = float(ALTURA); k = ALTURA / 1.8

cfg = json.load(open(CFG))
bainha = cfg["bainha_cintura"] if isinstance(cfg, dict) else None
if REGRA == "jogo" or bainha is None:   # regra atual do jogo (character.gd), para comparação
    lam = np.array([0.15, -0.7, -0.7]); desl = np.array([0.2, 0.04, 0.05])
else:
    lam = np.array(bainha["direcao_lamina"], float); desl = np.array(bainha["deslocamento_cabo"], float)
lam = lam / np.linalg.norm(lam)
COMP, PEGA = 1.0, 0.1            # GRIP espada: len 1.0, at 0.1 (a pegada fica a 0,1 m do fim do cabo)
RAIO_LAMINA = 0.026              # meia largura da lâmina junto à guarda

esq = Esqueleto(CORPO)
G0 = esq.globais({})
pel0 = G0["pelvis"]
cabo_mod = pel0[:3, 3] + desl * k                    # ponto de pegada no espaço do modelo (repouso)
pts_mod = np.array([cabo_mod + lam * t for t in np.linspace(-PEGA, COMP - PEGA, 12)])   # do pomo à ponta
ponta_mod = pts_mod[-1]
ang = float(np.degrees(np.arccos(abs(lam[1]))))
atras = float(pel0[2, 3] - ponta_mod[2])             # +Z é a frente; positivo = ponta atrás do quadril
cabo_frente = float(cabo_mod[2] - pel0[2, 3])

def capsulas(G):
    caps = []
    for s in "lr":
        caps.append((G[f"thigh_{s}"][:3, 3], G[f"calf_{s}"][:3, 3], 0.085 * k, f"coxa_{s}"))
        caps.append((G[f"calf_{s}"][:3, 3], G[f"foot_{s}"][:3, 3], 0.060 * k, f"canela_{s}"))
    return caps
def dist_seg(P, a, b):
    ab = b - a; t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1); return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)

res = []
for af in (AA, AB):
    for nome, canais, dur in canais_animacao(af):
        pior_chao, pior_perna, onde = 9.0, 9.0, ""
        for t in np.linspace(0, dur, 9):
            G = esq.globais(amostra_pose(canais, t, esq))
            M = G["pelvis"] @ np.linalg.inv(pel0)        # o suporte segue o osso pelvis
            P = (M[:3, :3] @ pts_mod.T).T + M[:3, 3]
            pior_chao = min(pior_chao, float(P[:, 1].min()))
            for a, b, r, n in capsulas(G):
                d = float((dist_seg(P[3:], a, b) - r - RAIO_LAMINA).min())   # só a lâmina (sem o cabo)
                if d < pior_perna: pior_perna, onde = d, n
        res.append({"anim": nome, "chao_min_m": round(pior_chao, 3), "folga_perna_min_m": round(pior_perna, 3), "perna": onde})
saida = {"regra": REGRA, "angulo_vertical_graus": round(ang, 1), "ponta_atras_quadril_m": round(atras, 3),
         "cabo_a_frente_do_quadril_m": round(cabo_frente, 3),
         "atravessa_chao": [r["anim"] for r in res if r["chao_min_m"] < 0.0],
         "atravessa_perna": [r["anim"] for r in res if r["folga_perna_min_m"] < 0.0], "animacoes": res}
json.dump(saida, open(SAIDA, "w"), ensure_ascii=False, indent=1)
print(json.dumps({k: v for k, v in saida.items() if k != "animacoes"}, ensure_ascii=False))
