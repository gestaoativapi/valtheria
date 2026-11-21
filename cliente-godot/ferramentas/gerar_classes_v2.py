#!/usr/bin/env python3
"""Gera data/classes_v2.json: árvore de classes (base, 1ª no nv 20, 2ª no nv 40, 3ª no nv 76) das 8 raças
jogáveis, banco de habilidades ativas e passivas com níveis, tabela de evolução (up de habilidade) e a regra
de elementos. Estrutura inspirada no Lineage II Interlude (só a estrutura; nomes e conteúdo são de Valtheria).

Os ids das classes que já existem no jogo ficam iguais (personagens criados não mudam). Cada 1ª classe passa a
abrir DOIS caminhos de 2ª classe (o caminho que já existia = A, o novo = B), e cada 2ª classe tem a sua 3ª.
uso: python3 ferramentas/gerar_classes_v2.py
"""
import json, math, os

AQUI = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(AQUI, "..", "data")
W = json.load(open(os.path.join(DATA, "world.json"), encoding="utf-8"))
ANTIGAS = W["classes"]
NIVEL_RANK = [1, 20, 40, 76]

# ---------- elementos ----------
ELEM = {  # nome, nome curto nas habilidades
    "luz": ("Luz", "de Luz"), "sombra": ("Sombra", "Sombrio"), "fogo": ("Fogo", "de Chamas"), "gelo": ("Gelo", "de Geada"),
    "vento": ("Vento", "dos Ventos"), "terra": ("Terra", "de Pedra"), "raio": ("Raio", "do Trovão"), "agua": ("Água", "das Marés"),
}
# roda de vantagem: cada elemento vence o seguinte; luz e sombra se vencem uma à outra
RODA = ["fogo", "gelo", "vento", "terra", "raio", "agua"]
def vantagem(a, d):
    if a in ("luz", "sombra") and d in ("luz", "sombra") and a != d:
        return 1
    if a in RODA and d in RODA:
        i, j = RODA.index(a), RODA.index(d)
        if (i + 1) % len(RODA) == j:
            return 1
        if (j + 1) % len(RODA) == i:
            return -1
    return 0

REGRA_ELEM = {
    "vantagem": {"dano": 1.25, "critico": 0.08, "efeito": 0.10},
    "desvantagem": {"dano": 0.80, "critico": -0.04, "efeito": -0.10},
    "neutro": {"dano": 1.0, "critico": 0.0, "efeito": 0.0},
    "pvp": "contra jogador o bônus é reduzido pela resistência elemental do alvo (armadura, encanto, passivas de raça): dano_final = dano × (1 + (mult−1) × (1 − resistência))",
}

# ---------- árvore: caminho B novo de cada 1ª classe [id_2, nome_2, id_3, nome_3, arquétipo, elemento] ----------
NOVOS = {
    "hum_tq_1": ["Cavaleiro do Eclipse", "Vingador do Eclipse", "tanque", "sombra"],
    "hum_gr_1": ["Gladiador", "Duelista Lendário", "guerreiro", "fogo"],
    "hum_aq_1": ["Caçador de Tesouros", "Aventureiro das Fendas", "adaga", "vento"],
    "hum_mg_1": ["Invocador do Véu", "Senhor do Véu", "invocador", "raio"],
    "hum_cu_1": ["Profeta de Lúmen", "Hierofante de Lúmen", "xama", "luz"],
    "elf_aq_1": ["Batedor dos Ventos", "Sentinela do Luar", "arqueiro", "agua"],
    "elf_tq_1": ["Cantor de Espadas", "Musa das Lâminas", "guerreiro", "agua"],
    "elf_ad_1": ["Corredor das Planícies", "Cavaleiro do Vento", "adaga", "agua"],
    "elf_cu_1": ["Guardião da Seiva", "Coração da Árvore", "curandeiro", "agua"],
    "elf_mg_1": ["Invocador Elemental", "Mestre dos Elementos", "invocador", "agua"],
    "de_ad_1": ["Dançarino da Lua Negra", "Espectro de Nyx", "guerreiro", "raio"],
    "de_tq_1": ["Cavaleiro do Abismo", "Templário de Nyx", "tanque", "raio"],
    "de_aq_1": ["Batedor Fantasma", "Sentinela Fantasma", "arqueiro", "vento"],
    "de_mg_1": ["Cantor da Penumbra", "Tempestade Negra", "mago", "vento"],
    "de_xa_1": ["Ancião Sombrio", "Coração de Nyx", "curandeiro", "sombra"],
    "orc_gr_1": ["Senhor dos Clãs", "Rei da Horda", "guerreiro", "terra"],
    "orc_mo_1": ["Punho Ardente", "Avatar da Brasa", "monge", "fogo"],
    "orc_xa_1": ["Uivador de Guerra", "Clamor da Guerra", "xama", "fogo"],
    "orc_cu_1": ["Chamador de Espíritos", "Domador de Almas", "invocador", "sombra"],
    "dw_qe_1": ["Caçador de Recompensas", "Buscador de Fortuna", "adaga", "terra"],
    "dw_fo_1": ["Engenheiro de Guerra", "Mestre dos Autômatos", "invocador", "raio"],
    "dw_co_1": ["Explorador das Profundezas", "Senhor das Galerias", "artesao", "fogo"],
    "bst_cs_1": ["Presa Furtiva", "Sombra da Matilha", "adaga", "vento"],
    "bst_tq_1": ["Fúria Bestial", "Besta Primordial", "guerreiro", "fogo"],
    "bst_dr_1": ["Domador de Feras", "Senhor das Feras", "invocador", "terra"],
    "bst_cu_1": ["Xamã da Lua Cheia", "Olho dos Dois Luares", "curandeiro", "luz"],
    "drc_ln_1": ["Lâmina Escamada", "Asa de Guerra", "guerreiro", "raio"],
    "drc_tq_1": ["Guardião do Ninho", "Escudo do Primeiro Dragão", "tanque", "terra"],
    "drc_sp_1": ["Sacerdote da Tempestade", "Sopro do Trovão", "xama", "raio"],
    "drc_mg_1": ["Mago do Relâmpago", "Senhor dos Céus Rubros", "mago", "raio"],
    "gig_gg_1": ["Escudo da Nevasca", "Bastião Polar", "tanque", "agua"],
    "gig_gr_1": ["Lanceiro Glacial", "Ponta do Inverno", "guerreiro", "vento"],
    "gig_rn_1": ["Tecelão de Runas", "Mestre das Runas Frias", "xama", "raio"],
    "gig_cu_1": ["Cantor da Aurora", "Voz da Aurora Eterna", "curandeiro", "luz"],
}
RACAS = {"hum": "humano", "elf": "elfo", "de": "sombrio", "orc": "orc", "dw": "anao", "bst": "beastman", "drc": "draconato", "gig": "gigante"}
NOME_RACA = {"humano": "Humanos", "elfo": "Elfos Brancos", "sombrio": "Elfos Negros", "orc": "Orcs", "anao": "Anões", "beastman": "Homens-Fera", "draconato": "Dragonitas", "gigante": "Gigantes"}

# ---------- habilidades por arquétipo ----------
# cada uma: [slot, nome (com {E} = elemento), categoria, tipo, poder base, nível máximo, recarga s, livro]
# categorias (como na janela do jogo): ativas: magia, golpe, reforco, enfraquecer, alternar ;
#                                       passivas: equipamento, habilidade, raca, oficio
BASE = {
    "combatente": [["b1", "Golpe Firme", "golpe", "ataque", 1.25, 9, 4, 0], ["b2", "Investida", "golpe", "avanco", 1.1, 5, 12, 0],
                   ["b3", "Fôlego de Batalha", "reforco", "buff", 0.12, 5, 60, 0], ["b4", "Domínio de Armas", "equipamento", "passiva", 0.04, 9, 0, 0],
                   ["b5", "Couraça Básica", "equipamento", "passiva", 0.04, 9, 0, 0]],
    "mistico": [["b1", "Projétil {E}", "magia", "ataque", 1.3, 9, 3, 0], ["b2", "Toque Curativo", "magia", "cura", 0.12, 9, 6, 0],
                ["b3", "Escudo Arcano", "reforco", "buff", 0.12, 5, 60, 0], ["b4", "Mente Clara", "habilidade", "passiva", 0.04, 9, 0, 0],
                ["b5", "Vestes do Aprendiz", "equipamento", "passiva", 0.04, 9, 0, 0]],
}
R1 = {  # 1ª classe (nv 20)
    "tanque": [["Golpe de Escudo", "golpe", "atordoar", 1.2, 15, 8, 0], ["Provocar", "enfraquecer", "provocar", 0, 3, 12, 0], ["Muralha {E}", "reforco", "buff", 0.25, 10, 45, 0],
               ["Égide", "alternar", "alternar", 0.15, 5, 2, 0], ["Domínio de Escudo", "equipamento", "passiva", 0.05, 15, 0, 0], ["Pele de Aço", "habilidade", "passiva", 0.04, 15, 0, 0]],
    "guerreiro": [["Corte Duplo", "golpe", "ataque", 1.5, 20, 6, 0], ["Giro de Lâmina", "golpe", "area", 1.2, 15, 10, 0], ["Grito de Guerra", "reforco", "buff", 0.15, 10, 60, 0],
                  ["Fúria", "alternar", "alternar", 0.15, 5, 2, 0], ["Domínio de Armas Pesadas", "equipamento", "passiva", 0.05, 15, 0, 0], ["Vigor", "habilidade", "passiva", 0.04, 15, 0, 0]],
    "arqueiro": [["Tiro Certeiro", "golpe", "ataque", 1.5, 20, 5, 0], ["Chuva de Flechas", "golpe", "area", 1.1, 15, 14, 0], ["Olho de Falcão", "reforco", "buff", 0.15, 10, 60, 0],
                 ["Passo Leve", "alternar", "alternar", 0.12, 5, 2, 0], ["Domínio do Arco", "equipamento", "passiva", 0.05, 15, 0, 0], ["Reflexos", "habilidade", "passiva", 0.04, 15, 0, 0]],
    "adaga": [["Punhalada", "golpe", "ataque", 1.6, 20, 5, 0], ["Golpe Pelas Costas", "golpe", "critico", 2.0, 15, 12, 0], ["Furtividade", "alternar", "alternar", 0.2, 5, 30, 0],
              ["Veneno {E}", "enfraquecer", "debuff", 0.3, 10, 15, 0], ["Domínio de Adagas", "equipamento", "passiva", 0.05, 15, 0, 0], ["Esquiva", "habilidade", "passiva", 0.04, 15, 0, 0]],
    "mago": [["Lança {E}", "magia", "ataque", 1.6, 25, 4, 0], ["Explosão {E}", "magia", "area", 1.25, 15, 12, 0], ["Prisão {E}", "enfraquecer", "prender", 0.3, 10, 18, 0],
             ["Concentração", "reforco", "buff", 0.15, 10, 60, 0], ["Domínio Arcano", "habilidade", "passiva", 0.05, 15, 0, 0], ["Vestes Místicas", "equipamento", "passiva", 0.04, 15, 0, 0]],
    "curandeiro": [["Cura Maior", "magia", "cura", 0.25, 25, 5, 0], ["Cura em Grupo", "magia", "cura_area", 0.15, 15, 14, 0], ["Bênção {E}", "reforco", "buff", 0.15, 10, 60, 0],
                   ["Purificar", "magia", "purificar", 0, 3, 20, 0], ["Fé", "habilidade", "passiva", 0.05, 15, 0, 0], ["Vestes Sagradas", "equipamento", "passiva", 0.04, 15, 0, 0]],
    "xama": [["Raio {E}", "magia", "ataque", 1.4, 20, 4, 0], ["Hino da Força", "reforco", "buff", 0.12, 10, 60, 0], ["Hino da Defesa", "reforco", "buff", 0.12, 10, 60, 0],
             ["Maldição da Lentidão", "enfraquecer", "debuff", 0.25, 10, 16, 0], ["Sabedoria Tribal", "habilidade", "passiva", 0.05, 15, 0, 0], ["Vestes Rituais", "equipamento", "passiva", 0.04, 15, 0, 0]],
    "monge": [["Soco Explosivo", "golpe", "ataque", 1.5, 20, 4, 0], ["Chute Giratório", "golpe", "area", 1.2, 15, 10, 0], ["Força Interior", "alternar", "alternar", 0.15, 5, 2, 0],
              ["Foco do Corpo", "reforco", "buff", 0.15, 10, 60, 0], ["Domínio dos Punhos", "equipamento", "passiva", 0.05, 15, 0, 0], ["Corpo de Pedra", "habilidade", "passiva", 0.04, 15, 0, 0]],
    "artesao": [["Martelada", "golpe", "ataque", 1.4, 20, 5, 0], ["Terremoto", "golpe", "area", 1.15, 15, 14, 0], ["Forja Rápida", "oficio", "passiva", 0.1, 10, 0, 0],
                ["Garimpo", "oficio", "passiva", 0.1, 10, 0, 0], ["Domínio de Martelos", "equipamento", "passiva", 0.05, 15, 0, 0], ["Teimosia Anã", "habilidade", "passiva", 0.04, 15, 0, 0]],
    "invocador": [["Invocar Espírito {E}", "magia", "invocar", 1.0, 15, 30, 0], ["Ordem de Ataque", "magia", "ataque", 1.3, 20, 6, 0], ["Elo Vital", "reforco", "buff", 0.15, 10, 60, 0],
                  ["Laço {E}", "enfraquecer", "prender", 0.25, 10, 18, 0], ["Afinidade Espiritual", "habilidade", "passiva", 0.05, 15, 0, 0], ["Vestes do Elo", "equipamento", "passiva", 0.04, 15, 0, 0]],
}
R2 = {  # 2ª classe (nv 40): o caminho B usa o próprio elemento e troca os nomes marcados com "|" (A|B)
    "tanque": [["Juízo {E}|Retaliação {E}", "golpe", "ataque", 1.7, 30, 8, 0], ["Corrente {E}", "enfraquecer", "puxar", 0.3, 10, 15, 0], ["Aura de Proteção|Aura Ameaçadora", "reforco", "aura", 0.15, 15, 0, 0],
               ["Bastião", "reforco", "buff", 0.4, 10, 120, 1], ["Último Recurso", "alternar", "alternar", 0.3, 5, 2, 0], ["Pesada Maestria", "equipamento", "passiva", 0.06, 30, 0, 0],
               ["Resistência {E}", "habilidade", "passiva", 0.05, 20, 0, 0], ["Vigília", "habilidade", "passiva", 0.04, 20, 0, 0]],
    "guerreiro": [["Golpe Esmagador|Lâmina Dançante", "golpe", "ataque", 1.9, 30, 6, 0], ["Tufão de Aço|Ciclone {E}", "golpe", "area", 1.4, 20, 12, 0], ["Lâmina {E}", "golpe", "elemental", 1.6, 20, 9, 0],
                  ["Sede de Combate", "reforco", "buff", 0.2, 10, 90, 1], ["Frenesi|Duelo", "alternar", "alternar", 0.25, 5, 2, 0], ["Maestria de Armas", "equipamento", "passiva", 0.06, 30, 0, 0],
                  ["Pele Curtida", "habilidade", "passiva", 0.05, 20, 0, 0], ["Instinto Assassino", "habilidade", "passiva", 0.04, 20, 0, 0]],
    "arqueiro": [["Flecha {E}", "golpe", "elemental", 1.8, 30, 6, 0], ["Tiro Duplo|Tiro Perfurante", "golpe", "ataque", 1.9, 30, 8, 0], ["Flecha Atordoante", "golpe", "atordoar", 1.2, 15, 15, 0],
                 ["Mira Mortal", "reforco", "buff", 0.25, 10, 90, 1], ["Rajada", "alternar", "alternar", 0.2, 5, 2, 0], ["Maestria do Arco", "equipamento", "passiva", 0.06, 30, 0, 0],
                 ["Olhos de Águia", "habilidade", "passiva", 0.05, 20, 0, 0], ["Corrida", "habilidade", "passiva", 0.04, 20, 0, 0]],
    "adaga": [["Golpe Fatal|Lâmina Furtiva", "golpe", "critico", 2.4, 30, 10, 0], ["Corte {E}", "golpe", "elemental", 1.8, 20, 8, 0], ["Lâmina Envenenada", "enfraquecer", "debuff", 0.35, 15, 14, 0],
              ["Sombra Veloz", "reforco", "buff", 0.25, 10, 90, 1], ["Ilusão", "alternar", "alternar", 0.2, 5, 30, 0], ["Maestria de Adagas", "equipamento", "passiva", 0.06, 30, 0, 0],
              ["Ponto Vital", "habilidade", "passiva", 0.05, 20, 0, 0], ["Silêncio", "habilidade", "passiva", 0.04, 20, 0, 0]],
    "mago": [["Tempestade {E}|Rajada {E}", "magia", "area", 1.55, 30, 14, 0], ["Lâmina Arcana {E}", "magia", "ataque", 1.9, 30, 5, 0], ["Dreno de Vida|Dreno de Mana", "magia", "dreno", 1.2, 20, 12, 0],
             ["Sono", "enfraquecer", "prender", 0.3, 10, 20, 0], ["Corrente Mágica", "alternar", "alternar", 0.2, 5, 2, 0], ["Sabedoria Arcana", "habilidade", "passiva", 0.06, 30, 0, 0],
             ["Afinidade {E}", "habilidade", "passiva", 0.06, 20, 0, 1], ["Mana Profunda", "habilidade", "passiva", 0.05, 20, 0, 0]],
    "curandeiro": [["Restauração", "magia", "cura", 0.35, 30, 6, 0], ["Ressurreição", "magia", "reviver", 0.3, 10, 120, 1], ["Escudo Sagrado {E}|Véu {E}", "reforco", "buff", 0.25, 15, 60, 0],
                   ["Remover Maldição", "magia", "purificar", 0, 5, 20, 0], ["Prece Contínua", "alternar", "alternar", 0.15, 5, 2, 0], ["Graça", "habilidade", "passiva", 0.06, 30, 0, 0],
                   ["Coração Sereno", "habilidade", "passiva", 0.05, 20, 0, 0], ["Vestes Abençoadas", "equipamento", "passiva", 0.05, 20, 0, 0]],
    "xama": [["Canto de Guerra|Canto da Vida", "reforco", "buff", 0.2, 15, 60, 0], ["Hino da Pressa", "reforco", "buff", 0.15, 10, 60, 0], ["Totem {E}", "magia", "area", 1.3, 20, 16, 0],
             ["Medo", "enfraquecer", "debuff", 0.35, 10, 20, 0], ["Maldição {E}", "enfraquecer", "debuff", 0.3, 15, 16, 0], ["Ritual Profundo", "habilidade", "passiva", 0.06, 30, 0, 0],
             ["Elo com os Ancestrais", "habilidade", "passiva", 0.05, 20, 0, 1], ["Vestes Tribais", "equipamento", "passiva", 0.05, 20, 0, 0]],
    "monge": [["Punho {E}", "golpe", "elemental", 1.8, 30, 6, 0], ["Rajada de Golpes|Golpe Único", "golpe", "ataque", 2.0, 30, 9, 0], ["Explosão de Chi", "golpe", "area", 1.45, 20, 12, 0],
              ["Totem do Urso|Totem do Lobo", "reforco", "buff", 0.25, 10, 90, 1], ["Transe", "alternar", "alternar", 0.25, 5, 2, 0], ["Maestria dos Punhos", "equipamento", "passiva", 0.06, 30, 0, 0],
              ["Ossos de Ferro", "habilidade", "passiva", 0.05, 20, 0, 0], ["Respiração", "habilidade", "passiva", 0.04, 20, 0, 0]],
    "artesao": [["Martelo {E}", "golpe", "elemental", 1.7, 30, 7, 0], ["Esmagar Armadura", "enfraquecer", "debuff", 0.3, 15, 15, 0], ["Forja Mestra|Criação de Golem", "oficio", "passiva", 0.15, 15, 0, 1],
                ["Refino Perfeito", "oficio", "passiva", 0.12, 15, 0, 0], ["Teimosia", "alternar", "alternar", 0.2, 5, 2, 0], ["Maestria de Martelos", "equipamento", "passiva", 0.06, 30, 0, 0],
                ["Pulso Firme", "habilidade", "passiva", 0.05, 20, 0, 0], ["Olho para Metais", "oficio", "passiva", 0.1, 15, 0, 0]],
    "invocador": [["Invocar Guardião {E}|Invocar Fera {E}", "magia", "invocar", 1.3, 20, 30, 1], ["Explosão do Elo", "magia", "area", 1.4, 20, 14, 0], ["Cura do Elo", "magia", "cura", 0.25, 20, 8, 0],
                  ["Fúria do Espírito", "reforco", "buff", 0.25, 10, 90, 0], ["Troca de Lugar", "magia", "avanco", 0, 5, 20, 0], ["Maestria do Elo", "habilidade", "passiva", 0.06, 30, 0, 0],
                  ["Afinidade {E}", "habilidade", "passiva", 0.06, 20, 0, 1], ["Vestes do Invocador", "equipamento", "passiva", 0.05, 20, 0, 0]],
}
R3 = {  # 3ª classe (nv 76): habilidades finais, mais fortes, todas com aprimoramento
    "tanque": [["Fortaleza Viva|Vingança do Eclipse", "reforco", "buff", 0.6, 5, 300, 1], ["Juízo Final {E}", "golpe", "area", 2.4, 15, 20, 1], ["Égide dos Reis", "reforco", "aura", 0.25, 5, 0, 1],
               ["Imortal", "habilidade", "passiva", 0.08, 10, 0, 0], ["Maestria Suprema de Escudo", "equipamento", "passiva", 0.08, 10, 0, 0]],
    "guerreiro": [["Fúria dos Titãs|Valsa das Mil Lâminas", "golpe", "ataque", 3.2, 15, 18, 1], ["Ira {E}", "golpe", "area", 2.4, 15, 20, 1], ["Grito do Herói", "reforco", "buff", 0.4, 5, 300, 1],
                  ["Sangue de Campeão", "habilidade", "passiva", 0.08, 10, 0, 0], ["Maestria Suprema de Armas", "equipamento", "passiva", 0.08, 10, 0, 0]],
    "arqueiro": [["Flecha Celeste {E}|Flecha do Luar {E}", "golpe", "ataque", 3.2, 15, 16, 1], ["Tempestade de Flechas", "golpe", "area", 2.2, 15, 22, 1], ["Olho do Destino", "reforco", "buff", 0.4, 5, 300, 1],
                 ["Precisão Absoluta", "habilidade", "passiva", 0.08, 10, 0, 0], ["Maestria Suprema do Arco", "equipamento", "passiva", 0.08, 10, 0, 0]],
    "adaga": [["Golpe do Abismo|Lâmina das Fendas", "golpe", "critico", 3.6, 15, 16, 1], ["Dança {E}", "golpe", "area", 2.2, 15, 20, 1], ["Desaparecer", "reforco", "buff", 0.5, 5, 180, 1],
              ["Mão da Morte", "habilidade", "passiva", 0.08, 10, 0, 0], ["Maestria Suprema de Adagas", "equipamento", "passiva", 0.08, 10, 0, 0]],
    "mago": [["Cataclismo {E}|Tormenta {E}", "magia", "area", 2.6, 15, 24, 1], ["Lança Primordial {E}", "magia", "ataque", 3.2, 15, 10, 1], ["Arcano Desperto", "reforco", "buff", 0.4, 5, 300, 1],
             ["Mente do Eclipse", "habilidade", "passiva", 0.08, 10, 0, 0], ["Vestes do Arquimago", "equipamento", "passiva", 0.08, 10, 0, 0]],
    "curandeiro": [["Milagre {E}", "magia", "cura_area", 0.6, 15, 30, 1], ["Ressurreição em Massa", "magia", "reviver", 0.5, 5, 600, 1], ["Santuário", "reforco", "aura", 0.3, 5, 120, 1],
                   ["Coração da Árvore Mãe", "habilidade", "passiva", 0.08, 10, 0, 0], ["Vestes do Santo", "equipamento", "passiva", 0.08, 10, 0, 0]],
    "xama": [["Canto dos Heróis|Canto da Eternidade", "reforco", "buff", 0.3, 10, 120, 1], ["Ira dos Ancestrais {E}", "magia", "area", 2.2, 15, 22, 1], ["Maldição Final", "enfraquecer", "debuff", 0.5, 10, 30, 1],
             ["Voz Ancestral", "habilidade", "passiva", 0.08, 10, 0, 0], ["Vestes do Ancião", "equipamento", "passiva", 0.08, 10, 0, 0]],
    "monge": [["Punho Divino {E}|Mil Golpes", "golpe", "ataque", 3.4, 15, 16, 1], ["Onda de Chi", "golpe", "area", 2.3, 15, 20, 1], ["Despertar Interior", "reforco", "buff", 0.45, 5, 300, 1],
              ["Corpo Inabalável", "habilidade", "passiva", 0.08, 10, 0, 0], ["Maestria Suprema dos Punhos", "equipamento", "passiva", 0.08, 10, 0, 0]],
    "artesao": [["Martelo da Montanha {E}|Fúria da Forja", "golpe", "area", 2.4, 15, 20, 1], ["Obra-Prima", "oficio", "passiva", 0.25, 10, 0, 1], ["Golem Ancestral", "magia", "invocar", 2.0, 10, 60, 1],
                ["Coração de Pedra", "habilidade", "passiva", 0.08, 10, 0, 0], ["Maestria Suprema de Martelos", "equipamento", "passiva", 0.08, 10, 0, 0]],
    "invocador": [["Avatar {E}", "magia", "invocar", 2.6, 10, 60, 1], ["Fúria do Véu {E}", "magia", "area", 2.3, 15, 22, 1], ["Elo Eterno", "reforco", "buff", 0.4, 5, 300, 1],
                  ["Alma Partilhada", "habilidade", "passiva", 0.08, 10, 0, 0], ["Vestes do Senhor do Elo", "equipamento", "passiva", 0.08, 10, 0, 0]],
}
RACIAL = {  # passivas de raça (aprendidas no nível 1, crescem até o 80)
    "humano": [["Versatilidade Humana", 0.03], ["Fé em Lúmen", 0.04]], "elfo": [["Graça Élfica", 0.04], ["Filho do Vento", 0.04]],
    "sombrio": [["Visão no Escuro", 0.04], ["Pacto com Nyx", 0.04]], "orc": [["Sangue Quente", 0.05], ["Pele Grossa", 0.04]],
    "anao": [["Ofício Anão", 0.05], ["Raiz da Montanha", 0.04]], "beastman": [["Instinto de Caça", 0.05], ["Faro", 0.04]],
    "draconato": [["Escamas", 0.05], ["Sangue de Dragão", 0.04]], "gigante": [["Corpo Colossal", 0.05], ["Frio no Sangue", 0.04]],
}


def nome_elem(t, e):
    return t.replace("{E}", ELEM[e][1]).replace("  ", " ").strip()


def niveis(l0, nmax, lfim):
    """nível de personagem para cada nível da habilidade (1..nmax)."""
    if nmax <= 1:
        return [l0]
    passo = max(1.0, (lfim - l0) / (nmax - 1))
    out = []
    for i in range(nmax):
        out.append(min(lfim, int(round(l0 + passo * i))))
    for i in range(1, len(out)):  # nunca repete nível (no máximo 2 por nível de personagem)
        if out[i] < out[i - 1]:
            out[i] = out[i - 1]
    return out


def custo_ph(lv_char, rank, passiva):
    """pontos de habilidade (PH, ganhos caçando) para aprender um nível."""
    base = 35 * (lv_char ** 1.55) * (1 + 0.15 * rank)
    return int(round(base * (0.8 if passiva else 1.0), -1))


def habilidade(sid, nome, cat, tipo, poder, nmax, rec, livro, elem, rank, l0, lfim):
    passiva = tipo == "passiva" or cat in ("equipamento", "habilidade", "raca", "oficio")
    lv = niveis(l0, nmax, lfim)
    tabela = []
    for i, lc in enumerate(lv):
        n = i + 1
        tabela.append({
            "nivel": n, "nivel_personagem": lc, "ph": custo_ph(lc, rank, passiva), "aurum": int(round(custo_ph(lc, rank, passiva) * 0.6, -1)),
            "poder": round(poder * (1 + (0.045 if passiva else 0.06) * (n - 1)), 3),
            "mana": 0 if passiva else int(round((6 + 4 * rank + rec * 0.4) * (1 + 0.05 * (n - 1)))),
        })
    h = {"id": sid, "nome": nome, "categoria": cat, "tipo": tipo, "ativa": not passiva, "elemento": elem if ("{E}" in "") else elem,
         "rank": rank, "nivel_max": nmax, "recarga": rec, "livro": bool(livro), "tabela": tabela}
    if rank == 3 and not passiva:
        h["aprimoramento"] = {"max": 15, "ramos": {"poder": "+1,5% de poder por nível", "custo": "−1,2% de mana por nível", "efeito": "+1% de chance/duração do efeito por nível"},
                              "chance": [max(30, 82 - 4 * (k - 1)) for k in range(1, 16)], "falha": "volta ao nível máximo normal, sem aprimoramento"}
    return h


def gerar():
    classes, skills, por_classe = {}, {}, {}
    for pre, raca in RACAS.items():
        el_raca = W["race_elem"][raca]
        for cid, c in ANTIGAS.items():
            if cid.split("_")[0] != pre:
                continue
            classes[cid] = {"nome": c["name"], "rank": c["rank"], "pai": c["parent"], "arquetipo": c["arch"], "raca": raca,
                            "elemento": el_raca, "nivel": NIVEL_RANK[c["rank"]], "caminho": "A", "exclusiva": c.get("excl", False)}
        for cid in list(classes):
            c = classes[cid]
            if c["raca"] != raca or c["rank"] != 1 or cid not in NOVOS:
                continue
            n2, n3, arq, el = NOVOS[cid]
            b2, b3 = cid[:-2] + "_2b", cid[:-2] + "_3b"
            classes[b2] = {"nome": n2, "rank": 2, "pai": cid, "arquetipo": arq, "raca": raca, "elemento": el, "nivel": 40, "caminho": "B", "exclusiva": c["exclusiva"]}
            classes[b3] = {"nome": n3, "rank": 3, "pai": b2, "arquetipo": arq, "raca": raca, "elemento": el, "nivel": 76, "caminho": "B", "exclusiva": c["exclusiva"]}
    # habilidades
    for cid, c in classes.items():
        raca, r, arq, el = c["raca"], c["rank"], c["arquetipo"], c["elemento"]
        lista = []
        if r == 0:
            tipo_base = "mistico" if arq in ("mago", "xama", "curandeiro") else "combatente"
            for slot, nm, cat, tp, pw, nmax, rec, lb in BASE[tipo_base]:
                sid = f"{cid}_{slot}"
                skills[sid] = habilidade(sid, nome_elem(nm, el), cat, tp, pw, nmax, rec, lb, el, 0, 1 + (int(slot[1]) - 1) * 3, 39)
                lista.append(sid)
            for k, (nm, pw) in enumerate(RACIAL[raca]):
                sid = f"{cid}_raca{k + 1}"
                skills[sid] = habilidade(sid, nm, "raca", "passiva", pw, 16, 0, 0, el, 0, 1 + k * 4, 80)
                lista.append(sid)
        else:
            tab = {1: R1, 2: R2, 3: R3}[r][arq if arq in R1 else "guerreiro"]
            lfim = {1: 74, 2: 79, 3: 80}[r]  # habilidades da 1ª continuam subindo durante a 2ª classe
            for k, (nm, cat, tp, pw, nmax, rec, lb) in enumerate(tab):
                if r == 3:  # finais: poucos níveis (76 a 80); o resto vem do aprimoramento +1 a +15
                    nmax = 3 if cat not in ("habilidade", "equipamento", "oficio") else 5
                a, _, b = nm.partition("|")
                nome = nome_elem(b if (b and c["caminho"] == "B") else a, el)
                sid = f"{cid}_s{k + 1}"
                l0 = NIVEL_RANK[r] + min(k * 2, 12 if r < 3 else 3)
                skills[sid] = habilidade(sid, nome, cat, tp, pw, nmax, rec, lb, el, r, l0, lfim)
                lista.append(sid)
        por_classe[cid] = lista
    return {"versao": 1, "niveis_classe": NIVEL_RANK, "elementos": {k: v[0] for k, v in ELEM.items()}, "roda_elemental": RODA,
            "regra_elemental": REGRA_ELEM, "vantagem": {a: {d: vantagem(a, d) for d in ELEM} for a in ELEM},
            "racas": {p: {"id": r, "nome": NOME_RACA[r], "elemento": W["race_elem"][r]} for p, r in RACAS.items()},
            "classes": classes, "habilidades": skills, "habilidades_da_classe": por_classe,
            "pontos_habilidade": "PH: ganhos ao derrotar monstros (independente da experiência), proporcionais ao nível do monstro; usados para aprender e subir habilidades",
            "categorias": {"ativas": ["magia", "golpe", "reforco", "enfraquecer", "alternar"], "passivas": ["equipamento", "habilidade", "raca", "oficio"]}}


if __name__ == "__main__":
    d = gerar()
    json.dump(d, open(os.path.join(DATA, "classes_v2.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    finais = [c for c in d["classes"].values() if c["rank"] == 3]
    print("classes:", len(d["classes"]), "finais:", len(finais), "habilidades:", len(d["habilidades"]))
