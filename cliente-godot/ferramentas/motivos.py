"""Escolhe o desenho (motivo) do ícone de cada habilidade pelo nome e pelo tipo.
Usado pelo gerador de classes (campo "icone" = <motivo>_<elemento>) e pelo pintor de ícones."""

PALAVRA = {
    "espada": "Lâmina Golpe Corte Duelo Último Mil Juízo",
    "machado": "Fúria Ira Esmagar Frenesi",
    "martelo": "Martelo Martelada Forja Refino Obra-Prima Criação Ofício",
    "arco": "Flecha Tiro Chuva",
    "alvo": "Mira Precisão Ponto",
    "adaga": "Punhalada Furtividade Desaparecer Sombra",
    "lanca": "Lança Investida",
    "escudo": "Escudo Égide Bastião Muralha Fortaleza Couraça Resistência Pesada Vigília",
    "punho": "Punho Soco Chute Força Teimosia Corpo",
    "mao": "Mão Toque Dreno Pulso Sede",
    "olho": "Olho Olhos Visão Concentração Foco Mente",
    "garra": "Instinto Faro",
    "caveira": "Maldição Medo Ossos Pacto Imortal",
    "coracao": "Coração Vigor Fôlego",
    "gota": "Sangue Veneno Mana",
    "cruz": "Cura Restauração Purificar Remover",
    "lotus": "Graça Bênção Milagre",
    "asas": "Ressurreição Avatar Despertar Alma",
    "nota": "Hino Canto Voz Valsa Dança",
    "trompa": "Grito Provocar",
    "corrente": "Corrente Elo Prisão",
    "totem": "Totem Ritual",
    "golem": "Golem Invocar",
    "livro": "Sabedoria Arcano",
    "armas": "Maestria Versatilidade",
    "manto": "Vestes",
    "escamas": "Pele Escamas",
    "coroa": "Domínio",
    "orbe": "Explosão Projétil Rajada Raio",
    "tornado": "Ciclone Tufão Tempestade Tormenta Giro",
    "meteoro": "Cataclismo Terremoto Onda",
    "cupula": "Santuário Aura Véu",
    "prece": "Prece Fé",
    "lua": "Sono Transe Silêncio",
    "mascara": "Ilusão Troca",
    "bota": "Corrida Passo Esquiva Reflexos Respiração",
    "gema": "Afinidade Garimpo",
    "raiz": "Raiz Filho",
    "espinhos": "Retaliação Vingança",
}
POR_PALAVRA = {p: m for m, ps in PALAVRA.items() for p in ps.split()}

POR_TIPO = {"ataque": "espada", "area": "orbe", "elemental": "orbe", "critico": "adaga", "atordoar": "martelo",
            "avanco": "lanca", "puxar": "corrente", "provocar": "trompa", "aura": "cupula", "buff": "coroa",
            "alternar": "tornado", "invocar": "golem", "cura": "cruz", "cura_area": "lotus", "reviver": "asas",
            "purificar": "cruz", "dreno": "mao", "prender": "corrente", "debuff": "caveira", "passiva": "gema"}

POR_ARQ = {"arqueiro": "arco", "adaga": "adaga", "monge": "punho", "artesao": "martelo", "tanque": "escudo",
           "mago": "orbe", "curandeiro": "cruz", "xama": "totem", "invocador": "golem", "guerreiro": "espada"}


def motivo(nome, tipo, arq=""):
    p = nome.split()[0] if nome else ""
    if p in POR_PALAVRA:
        m = POR_PALAVRA[p]
        if m == "espada" and arq in ("arqueiro",) and tipo in ("ataque", "critico"):
            return "arco"
        if m == "espada" and arq == "monge":
            return "punho"
        if m == "espada" and arq == "adaga":
            return "adaga"
        if m == "espada" and arq in ("mago", "xama", "curandeiro", "invocador"):
            return "orbe"
        return m
    if tipo == "ataque" and arq in POR_ARQ:
        return POR_ARQ[arq]
    return POR_TIPO.get(tipo, "gema")
