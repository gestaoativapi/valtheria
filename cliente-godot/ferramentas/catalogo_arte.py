#!/usr/bin/env python3
"""
Catálogo de arte do Valtheria: gera, a partir de uma única fonte,
  - ferramentas/armas.json        (medidas e pegada de cada arma, usado pelo encaixe e pelo jogo)
  - ferramentas/prompts.json      (todos os pedidos de imagem, para o gerador automático)
  - ../docs/PROMPTS_GEMINI.md     (o mesmo conteúdo, para copiar e colar no Gemini)

Uso:  python3 ferramentas/catalogo_arte.py
"""
import json, os

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)

# ---------------------------------------------------------------- regras fixas
STYLE = ("Stylized semi-realistic fantasy MMORPG game art, hand-painted PBR look, crisp high detail, "
         "original design that does not copy any existing game, film, comic or franchise. "
         "Medieval fantasy with subtle modern craftsmanship. Muted realistic palette: steel, graphite, bronze, "
         "silver, aged gold, natural leather and cloth; strong colours only on small details (under 10% of the object). No neon.")
CLEAN = ("Clean reference image for image-to-3D conversion: one single subject only, centered, the whole subject fully visible "
         "with empty margin around it, orthographic camera, flat plain mid-grey background (#7F7F7F), soft even studio light "
         "from the front, no cast shadow, no floor, no text, no letters, no numbers, no logo, no watermark, no frame, no grid, "
         "no labels, no skeleton or wireframe overlay, no motion blur, no depth of field, no other objects.")
A_POSE = ("Standing in a neutral A-pose: arms straight and angled about 40 degrees down and away from the body, palms facing "
          "the thighs, hands relaxed with fingers slightly curled and separated and the thumb clearly visible (ready to grip a "
          "round handle), legs straight with feet shoulder-width apart pointing forward, head looking straight ahead, neutral "
          "calm face, mouth closed. Empty hands: no weapon, no shield, nothing held, nothing floating. No cape. Hair, sleeves "
          "and clothing must not cover the hands, the arms or the gap between the legs.")
FRONT = "Front view, full body from head to feet."

# ---------------------------------------------------------------- raças
RACES = [
    ("humano", "Humanos",
     "human man, 1.80 m tall, athletic and balanced build, short dark-brown hair, light stubble, determined eyes",
     "human woman, 1.68 m tall, athletic slender build, chestnut hair tied in a low ponytail, kind confident face"),
    ("elfo", "Elfos Brancos",
     "white elf man, 1.85 m tall, tall and slender, fair skin, long pointed ears about 14 cm, long platinum-blond hair tied low behind the neck, calm noble face",
     "white elf woman, 1.75 m tall, graceful and slender, fair skin, long pointed ears about 13 cm, long golden hair in a side braid that rests behind the shoulder, gentle face"),
    ("sombrio", "Elfos Negros",
     "dark elf man, 1.83 m tall, lean and athletic, ash-grey skin with a faint lavender tint, long pointed ears, long white hair tied high, violet eyes, sharp face",
     "dark elf woman, 1.73 m tall, lean and athletic, ash-grey skin with a faint lavender tint, long pointed ears, long white hair tied in a high ponytail, violet eyes, confident smile"),
    ("orc", "Orcs e Goblins",
     "orc man, 2.00 m tall, very broad and muscular, olive-green skin, small lower tusks, black hair in a topknot, heavy brow, strong jaw",
     "orc woman, 1.85 m tall, strong and muscular, olive-green skin, small lower tusks, black hair in two thick braids behind the shoulders, fierce friendly face"),
    ("anao", "Anões",
     "dwarf man, 1.36 m tall, stocky broad build with a slight belly, white braided beard down to the chest that does not cover the arms, bald head with short sides, strong forearms",
     "dwarf woman, 1.30 m tall, compact athletic build, cheerful round anime-style face, red hair in two braids resting behind the shoulders, sturdy legs"),
    ("beastman", "Homens-Fera",
     "beastman man with a wolf head, 1.90 m tall, muscular, grey fur, upright wolf ears, short muzzle, human-like hands with five fingers and human-like legs with flat feet, short bushy tail",
     "beastwoman with a fox head, 1.75 m tall, agile slender build, russet fur with a white chest, tall fox ears, human-like hands with five fingers and human-like legs with flat feet, fluffy tail"),
    ("draconato", "Dragonitas",
     "dragonborn man, 1.95 m tall, broad muscular build, dragon head with short snout and two backward horns, bronze scales, lighter belly scales, human-like hands with five clawed fingers, human-like legs, short thick tail, no wings",
     "dragonborn woman, 1.80 m tall, athletic build, dragon head with a slim snout and two small swept-back horns, teal scales, lighter belly scales, human-like hands with five fingers, human-like legs, short tail, no wings"),
    ("gigante", "Gigantes de Gelo (aguarda decisão)",
     "frost giant man, 2.60 m tall, massive muscular build, pale blue-grey skin, long white beard tied in two braids, white hair, frost on the shoulders",
     "frost giant woman, 2.40 m tall, tall powerful build, pale blue-grey skin, long white hair in a thick braid behind the back, calm strong face"),
]
OUTFITS = [
    ("pesada", "Armadura pesada",
     "wearing NG-grade full plate armour: breastplate, pauldrons, vambraces, articulated gauntlets, tassets, greaves and sabatons in worn dull steel with dark leather straps and a chainmail skirt split at the front and back; no helmet; joints clearly separated so the arms and legs can bend"),
    ("leve", "Armadura leve",
     "wearing NG-grade light ranger armour: fitted brown leather jerkin over a linen shirt, leather bracers, fingerless leather gloves, belt with two small pouches, fitted dark trousers, knee-high leather boots; hood down on the back"),
    ("robe", "Túnica mágica",
     "wearing NG-grade mage clothes: long robe in muted blue cloth with simple embroidered trim, the robe is split open at the front and on both sides up to the hips so each leg stays visible and separate, fitted trousers underneath, sash belt, sleeves fitted and ending at the wrist (not wide or hanging), soft boots; no hat"),
]
DWARF_DONE = {("anao", "m", "pesada"), ("anao", "f", "leve")}

# ---------------------------------------------------------------- armas
# len/at/two em metros para um personagem de 1,80 m; o jogo reduz no anão e aumenta no gigante.
# at  = onde a mão principal segura, medido a partir da ponta do cabo (pomo); -1 = pelo meio (arco)
# two = onde a segunda mão segura (0 = uma mão só)
WEAPONS = [
    dict(id="espada", nome="Espada (uma mão)", len=1.00, at=0.10, two=0, hand="r", rest="cintura esquerda",
         shape="one-handed arming sword: straight double-edged blade 0.78 m long and 5 cm wide with a central fuller, straight crossguard 20 cm wide, grip 15 cm long, round pommel",
         calm="embainhada na cintura, lado esquerdo, cabo à frente; mão direita solta",
         battle="mão direita fechada no cabo logo abaixo da guarda, ponta para cima e para a frente, à altura da cintura",
         attack="golpe diagonal de cima para baixo, só com a mão direita; o pulso não dobra"),
    dict(id="espadao", nome="Espadão (duas mãos)", len=1.45, at=0.30, two=0.10, hand="r", rest="costas, na diagonal",
         shape="two-handed greatsword: straight blade 1.05 m long and 6.5 cm wide, wide crossguard 32 cm, long grip 30 cm for two hands, heavy pommel",
         calm="nas costas, na diagonal, cabo acima do ombro direito",
         battle="guarda à frente do corpo: mão direita logo abaixo da guarda, mão esquerda junto ao pomo, lâmina subindo na diagonal",
         attack="golpe largo com as duas mãos, de cima para baixo"),
    dict(id="adaga", nome="Adagas", len=0.45, at=0.06, two=0, hand="r", rest="cintura esquerda",
         shape="dagger: straight double-edged blade 0.30 m, small crossguard 9 cm, grip 11 cm, small pommel",
         calm="na cintura esquerda, cabo à frente",
         battle="mão direita fechada no cabo, lâmina para a frente e um pouco para baixo",
         attack="estocada rápida para a frente"),
    dict(id="punhal", nome="Adaga (punhal curvo)", len=0.42, at=0.05, two=0, hand="r", rest="cintura esquerda",
         shape="assassin's curved dagger: slightly curved single-edged blade 0.28 m, small S-shaped guard, grip 11 cm",
         calm="na cintura esquerda",
         battle="pegada invertida opcional: lâmina saindo por baixo do punho",
         attack="corte curto de baixo para cima"),
    dict(id="duplas", nome="Espadas gêmeas", len=0.80, at=0.08, two=0, hand="r", dual=True, rest="duas na cintura, uma de cada lado",
         shape="one short sword of a matched pair (the second one is a mirror copy): straight blade 0.60 m and 4 cm wide, short guard 14 cm, grip 13 cm, small pommel",
         calm="uma em cada lado da cintura",
         battle="uma em cada mão, pontas para a frente, braços meio dobrados",
         attack="golpes alternados, direita e esquerda"),
    dict(id="machado", nome="Machado de guerra (uma mão)", len=0.95, at=0.12, two=0, hand="r", rest="cintura esquerda",
         shape="one-handed war axe: straight round wooden haft 3.4 cm thick wrapped in leather at the bottom, single crescent steel head 24 cm tall with a small back spike, iron butt cap",
         calm="preso na cintura, cabeça para baixo",
         battle="mão direita perto da ponta do cabo, cabeça do machado acima do ombro",
         attack="golpe de cima para baixo"),
    dict(id="martelo", nome="Martelo de guerra (duas mãos)", len=1.10, at=0.40, two=0.12, hand="r", rest="costas, na diagonal",
         shape="two-handed war hammer: straight round haft 3.6 cm thick and 1.0 m long with leather grip wraps, compact rectangular steel head 26 cm wide and 12 cm tall with a flat face and a short spike, metal bands near the head",
         calm="nas costas, cabeça acima do ombro direito",
         battle="guarda baixa: mão direita no meio do cabo, esquerda perto da ponta, cabeça à altura do peito, afastada do rosto",
         attack="golpe vertical com as duas mãos"),
    dict(id="lanca", nome="Lança", len=1.90, at=0.75, two=0.38, hand="r", rest="costas, na vertical",
         shape="spear: straight round wooden shaft 3.0 cm thick, steel leaf-shaped head 30 cm long, small iron ferrule at the bottom",
         calm="nas costas, quase vertical, ponta para cima",
         battle="as duas mãos no cabo, ponta para a frente na altura do peito",
         attack="estocada longa para a frente"),
    dict(id="cajado", nome="Cajado", len=1.70, at=0.75, two=0.42, hand="r", rest="costas, na vertical",
         shape="mage staff: straight round wooden shaft 3.2 cm thick, carved wooden head with metal bands holding one clear crystal, iron foot cap",
         calm="nas costas, na vertical",
         battle="em pé ao lado do corpo, mão direita na altura do peito, esquerda mais abaixo",
         attack="ponta do cajado apontada para o alvo, conjurando"),
    dict(id="cetro", nome="Cetro arcano (uma mão)", len=0.75, at=0.10, two=0, hand="r", rest="cintura esquerda",
         shape="one-handed arcane scepter: straight round metal shaft 2.8 cm thick with a leather grip 13 cm, ornate open cage head holding one crystal, small pommel",
         calm="na cintura esquerda",
         battle="mão direita, cabeça do cetro para cima e para a frente",
         attack="cetro apontado para o alvo, conjurando"),
    dict(id="arco", nome="Arco", len=1.30, at=-1, two=0, hand="l", rest="costas, na diagonal",
         shape="recurve longbow 1.30 m tall: two curved limbs of layered wood and horn, wrapped leather hand grip 12 cm in the exact middle, taut string, no arrow",
         calm="nas costas, na diagonal",
         battle="mão esquerda fechada no meio do arco, arco em pé ao lado do corpo",
         attack="braço esquerdo esticado à frente, mão direita puxa a corda até o rosto"),
    dict(id="punhos", nome="Punhos (manoplas de luta)", len=0.30, at=0.0, two=0, hand="r", dual=True, rest="nas mãos",
         shape="pair of fighting knuckle gauntlets shown as ONE right-hand gauntlet: armoured back of the hand with a steel knuckle plate, open palm side with a cross bar the fist closes around, short forearm cuff",
         calm="nas mãos (é vestido)",
         battle="punhos fechados à frente do rosto",
         attack="socos alternados"),
    dict(id="garras", nome="Garras", len=0.40, at=0.0, two=0, hand="r", dual=True, rest="nas mãos",
         shape="pair of claw weapons shown as ONE right-hand claw: forearm brace with a cross bar grip inside, three slightly curved steel blades 25 cm long coming out over the knuckles",
         calm="nas mãos (é vestido)",
         battle="braços meio dobrados, garras para a frente",
         attack="arranhões cruzados"),
    dict(id="escudo", nome="Escudo", len=0.75, at=0, two=0, hand="l", shield=True, rest="costas",
         shape="heater shield 0.75 m tall and 0.55 m wide, slightly curved, 4 cm thick rim, front face shown; a vertical grip bar and two arm straps on the back",
         calm="nas costas",
         battle="no antebraço esquerdo, mão esquerda fechada na alça",
         attack="bloqueio à frente do peito"),
    dict(id="egide", nome="Égide arcana", len=0.60, at=0, two=0, hand="l", shield=True, rest="costas",
         shape="round arcane aegis shield 0.60 m in diameter, slightly domed, metal rim, one crystal in the centre surrounded by engraved runes; grip bar on the back",
         calm="nas costas",
         battle="no antebraço esquerdo",
         attack="bloqueio à frente do peito"),
]
GRADES = [
    ("ng", "NG", "Rústico", "rough hand-forged dark iron with nicks and hammer marks, worn brown leather wrap on the grip, plain shapes, no ornaments"),
    ("d", "D", "Bronze", "iron blade or head with polished bronze fittings (guard, pommel, bands), simple engraved lines, brown leather grip"),
    ("c", "C", "Aço", "bright clean steel, crisp edges, leather grip wrapped with thin steel wire, modest ornaments on the guard or bands"),
    ("b", "B", "Azurita", "polished steel with small deep-blue azurite stone inlays and fine silver filigree, dark blue leather grip"),
    ("a", "A", "Rubro", "dark blackened steel with crimson enamel accents and one red gem, black leather grip with gold stitching"),
    ("s", "S", "Celestial", "white steel with pale-gold details, small softly glowing light-blue runes, elegant feather-like shapes on the guard or head, white leather grip"),
]
LEGENDARY = [
    ("lend_espada_harmonia", "Espada Celestial da Harmonia", "espada",
     "legendary one-handed sword, unique: white-silver blade with a thin line of soft golden light along the fuller, guard shaped like two balanced crescent moons, one round pearl-white gem in the pommel"),
    ("lend_alvorecer_celestial", "Alvorecer Celestial", "espada",
     "legendary one-handed sword, unique: pale-gold blade whose tip fades into a warm sunrise glow, guard shaped like a rising sun with short rays, warm orange gem in the centre of the guard"),
]
GRIP_RULE = ("The grip is a straight cylinder with a round cross-section {d} cm thick and {g} cm long, clearly separated from the guard and the pommel, "
             "so a closed hand can wrap fully around it. The weapon is shown standing vertically, tip or head up, grip down, side view of its widest face, perfectly straight, not tilted.")

# ---------------------------------------------------------------- monstros
MONSTERS = [
    ("javali", "Javali Selvagem", "quad", "wild boar, 0.9 m tall at the shoulder, bristly dark-brown fur, curved tusks, small eyes"),
    ("rei_javali", "Rei Javali (chefe)", "quad", "giant boar king, 2 m tall at the shoulder, scarred dark fur, huge curved tusks with metal rings, bone crown fragments on the head"),
    ("lobo", "Lobo Cinzento", "quad", "grey wolf, 0.85 m at the shoulder, lean, thick grey fur, amber eyes"),
    ("lobo_esp", "Lobo Espectral", "quad", "spectral ice wolf, translucent pale-blue fur with frost crystals, glowing ice-blue eyes"),
    ("lagarto", "Lagarto Guerreiro", "humanoid", "lizardfolk warrior, 1.9 m tall, green-yellow scales, wearing a simple leather harness, long tail, human-like hands with five clawed fingers and human-like legs"),
    ("bandido", "Orc Bandido", "humanoid", "orc bandit, 2.0 m tall, olive skin, mismatched leather and iron scraps armour, red cloth mask around the neck"),
    ("esqueleto", "Esqueleto Guerreiro", "humanoid", "skeleton warrior, 1.8 m tall, old yellowed bones, rusty helmet and broken chest plate, faint pale-green glow in the eye sockets"),
    ("demonio", "Demônio Rubro", "humanoid", "crimson demon, 2.1 m tall, red skin, black curved horns, burning orange eyes, charred armour pieces, no wings"),
    ("senhor_dem", "Senhor Demônio (chefe)", "humanoid", "demon lord, 2.6 m tall, dark red skin with glowing lava cracks, large black horns, heavy black-iron armour with spikes, no wings"),
    ("caido", "Cavaleiro Caído", "humanoid", "fallen knight, 1.9 m tall, blackened cracked plate armour, torn dark cape kept short above the knees, faint purple glow from the helmet visor"),
    ("golem", "Golem de Pedra", "humanoid", "stone golem, 2.4 m tall, body of cracked grey rock blocks with moss, amber glowing runes on the chest, thick arms, small head sunk between the shoulders, three-fingered stone hands"),
    ("golem_anc", "Golem Ancestral (chefe)", "humanoid", "ancient golem, 4.5 m tall, dark blue-grey stone with ancient carvings, crystals growing from the shoulders, bright blue runes"),
    ("ent", "Ent Corrompido", "humanoid", "corrupted tree guardian, 2.6 m tall, twisted dark trunk body with thick bark, branch arms ending in root-like hands, sparse dark leaves on the head and shoulders, sickly green glowing eyes"),
    ("ent_mil", "Ent Milenar (chefe)", "humanoid", "thousand-year tree guardian, 5 m tall, ancient trunk body covered in moss, wide leafy crown with green and gold leaves, deep green glowing eyes"),
    ("aranha", "Aranha Gigante", "spider", "giant spider, 1 m tall and 2 m wide, dark purple-black body, hairy legs, eight small red eyes"),
    ("rainha", "Rainha Aracnídea (chefe)", "spider", "spider queen, 3 m tall, purple and black armoured body with a pale violet pattern, long spiked legs"),
    ("dragonete", "Dragonete", "dragon", "young dragon, 1.6 m tall, standing on its two hind legs, copper scales, small horns, wings folded on the back, short thick tail"),
    ("dragao", "Dragão Celeste (chefe)", "dragon", "celestial dragon, 8 m long, white and gold scales, large feathered wings folded, long horns, standing on four legs"),
]
MON_POSE = {
    "humanoid": A_POSE.replace("Empty hands: no weapon, no shield, nothing held, nothing floating. No cape. ", "Empty hands, nothing held. "),
    "quad": "Standing on all four legs in a neutral pose, legs straight and clearly separated, tail straight back, mouth closed, three-quarter front view from slightly above.",
    "spider": "Standing in a neutral pose with all eight legs spread evenly and clearly separated, three-quarter front view from slightly above.",
    "dragon": "Standing in a neutral pose, legs straight and separated, wings folded close to the body, tail straight back, mouth closed, three-quarter front view.",
}

# ---------------------------------------------------------------- cenário
TREES = [
    ("arvore_carvalho", "Carvalho (planície)", "broad oak tree 9 m tall, thick gnarled trunk, wide dense rounded crown of individual green leaves"),
    ("arvore_pinheiro", "Pinheiro (montanha)", "tall pine tree 14 m tall, straight trunk, layered conical crown of dense dark-green needle clusters"),
    ("arvore_pinheiro_neve", "Pinheiro com neve", "snow-covered pine tree 12 m tall, conical crown of dark-green needles with snow resting on top of each branch layer"),
    ("arvore_betula", "Bétula", "birch tree 10 m tall, slender white trunk with black marks, light airy crown of small yellow-green leaves"),
    ("arvore_salgueiro", "Salgueiro (beira de rio)", "weeping willow 8 m tall, curved trunk, long hanging curtains of thin green leaves"),
    ("arvore_bordo", "Bordo de outono", "autumn maple tree 8 m tall, rounded crown of orange and red leaves"),
    ("arvore_morta", "Árvore seca (terras sombrias)", "dead twisted tree 7 m tall, dark bark, bare crooked branches, no leaves"),
    ("arvore_palmeira", "Palmeira (costa)", "coastal palm tree 9 m tall, slightly curved ringed trunk, crown of long feather-shaped fronds"),
    ("arbusto_verde", "Arbusto", "round green bush 1.2 m tall made of many individual leaves"),
    ("arbusto_flores", "Arbusto com flores", "flowering bush 1 m tall, green leaves with small white and pink flowers"),
]
TREE_RULE = ("The crown must read as real foliage: many individual leaves or needle clusters, visible leaf shapes on the silhouette edge, "
             "small gaps of background between leaf clusters, no smooth blob or geometric ball. Trunk and root flare fully visible at the base. Front view.")
WALLS = [
    ("muro_reto", "Muro reto (peça que se repete)", "straight city wall segment exactly 6 m long, 7 m tall and 1.6 m thick, grey cut-stone blocks, walkway with crenellations (merlons) on top, both ends cut perfectly flat and vertical so identical segments join seamlessly side by side, stone foundation 1 m deep below the ground line"),
    ("muro_torre", "Torre", "round wall tower 4 m in diameter and 10 m tall, grey cut stone, crenellated top with a conical slate roof, two small arrow slits, two flat 1.6 m wide openings on opposite sides where wall segments connect"),
    ("muro_portao", "Portão", "city gatehouse 8 m wide and 9 m tall, grey cut stone, arched gate opening 4 m wide and 5 m tall with heavy wooden doors reinforced with iron, crenellated top, both side ends cut flat to join the wall segments"),
    ("muro_canto", "Canto", "square corner tower 3.5 m wide and 9 m tall, grey cut stone, crenellated top, two flat openings at 90 degrees where wall segments connect"),
    ("ponte_pedra", "Ponte de pedra", "stone arch bridge 12 m long and 4 m wide, one wide arch, low parapets on both sides, flat road surface"),
]
LIGHTS = [
    ("poste_lampiao", "Poste com lampião (estrada e cidade)", "street lamp post 3.2 m tall, black wrought iron, square glass lantern on top with a bright warm-yellow flame inside"),
    ("tocha_parede", "Tocha de parede", "wall torch in an iron sconce, wooden torch 50 cm with a bright warm-orange flame"),
    ("lanterna_pendurada", "Lanterna pendurada", "hanging iron lantern 40 cm tall with a hook, glass panes, bright warm-yellow glow inside"),
    ("braseiro", "Braseiro", "standing iron brazier 1.1 m tall on three legs, bowl filled with glowing coals and bright flames"),
    ("fogueira", "Fogueira", "campfire 1.2 m wide, ring of stones, crossed logs, bright flames"),
]
LIGHT_RULE = "Paint every flame, glow and lit glass area in bright saturated warm yellow-orange so it can be turned into a light-emitting material; the metal and wood parts stay unlit and neutral."
SKIES = [
    ("ceu_dia", "Céu de dia", "clear daytime sky, soft blue gradient, a few scattered cumulus clouds near the horizon, sun high"),
    ("ceu_tarde", "Pôr do sol", "sunset sky, warm orange and pink near the horizon fading to deep blue above, scattered clouds lit from below"),
    ("ceu_noite", "Noite com lua e estrelas", "clear night sky, deep navy blue, thousands of small stars of varying brightness, a faint band of the milky way crossing the sky, one large full moon with visible craters and a soft halo, slightly lighter near the horizon"),
    ("ceu_nublado", "Nublado / chuva", "overcast stormy sky, layered grey clouds, darker towards the top"),
]
SKY_RULE = ("Seamless 360-degree equirectangular sky panorama in 2:1 format, horizon exactly at the vertical middle, the left and right edges join without a seam, "
            "sky only: no ground, no mountains, no trees, no buildings, no text.")
TEXTURES = [
    ("tex_grama", "Grama", "short dense grass with a few tiny clovers"),
    ("tex_terra", "Terra", "dry packed dirt with small pebbles"),
    ("tex_estrada", "Estrada de pedra", "worn cobblestone road, rounded grey stones with dirt in the gaps"),
    ("tex_rocha", "Rocha", "rough grey mountain rock surface with cracks"),
    ("tex_neve", "Neve", "fresh packed snow with soft footprints-free surface and tiny ice sparkles"),
    ("tex_areia", "Areia", "fine beach sand with tiny ripples"),
    ("tex_floresta", "Chão de floresta", "forest floor with fallen leaves, small twigs and moss"),
    ("tex_lama", "Lama", "wet dark mud with small puddles"),
]
TEX_RULE = ("Seamless tileable square texture, perfectly top-down, flat even light with no shadows and no highlights (albedo only), "
            "the four edges tile with no visible seam, no text, realistic scale of about 2 m by 2 m.")


def weapon_prompt(w, grade_desc, nome):
    if w.get("shield"):
        body = f"Fantasy {w['shape']}. Material and finish: {grade_desc}. Front view, perfectly upright, not tilted."
    elif w["id"] in ("punhos", "garras"):
        body = (f"Fantasy {w['shape']}. Material and finish: {grade_desc}. Shown on its own, empty (no hand inside), "
                "back of the hand facing the camera, fingers direction pointing up.")
    elif w["id"] == "arco":
        body = (f"Fantasy {w['shape']}. Material and finish: {grade_desc}. The hand grip in the middle is a straight wrapped section 12 cm long and 3.5 cm thick. "
                "Shown standing vertically, front view with the string on the right side, perfectly straight, not tilted.")
    else:
        grip_cm = 30 if w["two"] else (11 if w["len"] < 0.5 else 15)
        thick = 3.6 if w["id"] in ("martelo", "machado") else (3.0 if w["id"] in ("lanca",) else 3.2)
        body = f"Fantasy {w['shape']}, total length {w['len']:.2f} m. Material and finish: {grade_desc}. " + GRIP_RULE.format(d=thick, g=grip_cm)
    return f"{body} {STYLE} {CLEAN}"


def build():
    items = []  # cada pedido: id, grupo, titulo, arquivo, aspect, prompt
    # personagens
    for rid, rname, male, female in RACES:
        for g, desc in (("m", male), ("f", female)):
            for oid, oname, odesc in OUTFITS:
                done = (rid, g, oid) in DWARF_DONE
                items.append(dict(grupo="1. Raças e trajes", id=f"{rid}_{g}_{oid}",
                                  titulo=f"{rname} — {'masculino' if g == 'm' else 'feminino'} — {oname}" + ("  (JÁ FEITO, pular)" if done else ""),
                                  arquivo=f"raca_{rid}_{g}_{oid}.png", aspect="3:4",
                                  prompt=f"Full-body 3D game character model reference: {desc}, {odesc}. {A_POSE} {FRONT} {STYLE} {CLEAN}"))
    # armas
    for w in WEAPONS:
        for gid, gl, gname, gdesc in GRADES:
            items.append(dict(grupo="2. Armas e escudos", id=f"{w['id']}_{gid}", titulo=f"{w['nome']} — grau {gl} ({gname})",
                              arquivo=f"arma_{w['id']}_{gid}.png", aspect="9:16" if w["len"] >= 0.7 and not w.get("shield") else "1:1",
                              prompt=weapon_prompt(w, gdesc, w["nome"])))
    for lid, lname, kind, ldesc in LEGENDARY:
        w = next(x for x in WEAPONS if x["id"] == kind)
        items.append(dict(grupo="2. Armas e escudos", id=lid, titulo=f"{lname} — grau SS (lendária)", arquivo=f"arma_{lid}.png", aspect="9:16",
                          prompt=f"Fantasy {ldesc}, total length {w['len']:.2f} m, blade 0.78 m, guard 22 cm. " + GRIP_RULE.format(d=3.2, g=15) + f" {STYLE} {CLEAN}"))
    # pranchas de pegada
    for w in WEAPONS:
        items.append(dict(grupo="3. Pranchas de pegada (referência para o encaixe)", id=f"pegada_{w['id']}", titulo=f"Pegada — {w['nome']}",
                          arquivo=f"pegada_{w['id']}.png", aspect="16:9",
                          prompt=(f"Weapon handling reference sheet for a fantasy game animator. A plain neutral grey artist mannequin (no face, no clothes, realistic adult proportions, 1.80 m) "
                                  f"with a simple {w['shape'].split(':')[0]} ({w['len']:.2f} m). Four panels in one row, same scale, side three-quarter view, plain light grey background: "
                                  f"panel 1 calm mode — weapon resting: {w['calm']}; "
                                  f"panel 2 battle stance — {w['battle']}; "
                                  f"panel 3 attack wind-up; panel 4 attack follow-through — {w['attack']}. "
                                  "In every panel where the weapon is held, the hand is fully closed around the grip: all four fingers wrapped around it, the thumb closing over the fingers, "
                                  "the wrist straight, no gap between palm and grip, the weapon never passing through the body. Clean line art with soft grey shading, no text, no numbers, no labels.")))
    # monstros
    for mid, mname, kind, desc in MONSTERS:
        items.append(dict(grupo="4. Monstros", id=mid, titulo=mname, arquivo=f"monstro_{mid}.png", aspect="1:1" if kind != "humanoid" else "3:4",
                          prompt=f"Full-body 3D game creature model reference: {desc}. {MON_POSE[kind]} {STYLE} {CLEAN}"))
    # cenário
    for tid, tname, desc in TREES:
        items.append(dict(grupo="5. Árvores e plantas", id=tid, titulo=tname, arquivo=f"{tid}.png", aspect="3:4",
                          prompt=f"Single game-ready {desc}. {TREE_RULE} {STYLE} {CLEAN}"))
    for wid, wname, desc in WALLS:
        items.append(dict(grupo="6. Muralha da cidade (kit que encaixa)", id=wid, titulo=wname, arquivo=f"{wid}.png", aspect="4:3",
                          prompt=f"Single modular game environment piece: {desc}. Three-quarter front view from slightly above so the top and one end are visible. {STYLE} {CLEAN}"))
    for lid, lname, desc in LIGHTS:
        items.append(dict(grupo="7. Luzes da noite", id=lid, titulo=lname, arquivo=f"{lid}.png", aspect="3:4",
                          prompt=f"Single game prop: {desc}. {LIGHT_RULE} Front view. {STYLE} {CLEAN}"))
    for sid, sname, desc in SKIES:
        items.append(dict(grupo="8. Céus (lua, estrelas, profundidade)", id=sid, titulo=sname, arquivo=f"{sid}.png", aspect="2:1",
                          prompt=f"{desc}. {SKY_RULE} Painterly realistic game sky, high resolution."))
    for tid, tname, desc in TEXTURES:
        items.append(dict(grupo="9. Texturas do chão", id=tid, titulo=tname, arquivo=f"{tid}.png", aspect="1:1",
                          prompt=f"{desc}. {TEX_RULE} Realistic hand-painted game texture."))
    return items


def weapons_json():
    out = {}
    for w in WEAPONS:
        out[w["id"]] = {k: w[k] for k in ("nome", "len", "at", "two", "hand", "rest", "calm", "battle", "attack")}
        out[w["id"]]["dual"] = bool(w.get("dual"))
        out[w["id"]]["shield"] = bool(w.get("shield"))
    return out


EXTRA = '## Opção: gerar tudo de uma vez pela API (para quem tem chave do Gemini)\n\nEm vez de copiar e colar, o script `cliente-godot/ferramentas/gerar_imagens_gemini.py` faz os mesmos pedidos em lote e salva com os nomes certos:\n\n```\npip install google-genai pillow\nset GEMINI_API_KEY=sua-chave        (Windows; no Linux/Mac: export GEMINI_API_KEY=sua-chave)\npython gerar_imagens_gemini.py --listar\npython gerar_imagens_gemini.py --grupo 1 --vistas      (raças, com lado e costas)\npython gerar_imagens_gemini.py --grupo 2 --so-ng       (armas grau NG)\npython gerar_imagens_gemini.py --grupo 4 --vistas      (monstros)\n```\n\nO que já foi gerado é pulado, então dá para parar e continuar. Esse script não foi testado com uma chave real; se a API recusar o nome do modelo, use `--modelo` com o nome que o Google AI Studio mostrar.\n\n## Depois das imagens (parte do Claude)\n\n1. Cada imagem vira modelo 3D no Meshy (Imagem para 3D, Meshy 6 Lite, com textura, licença CC BY 4.0).\n2. Raças: o script `pele_automatica.mjs` liga o modelo ao esqueleto do jogo (as animações passam a funcionar).\n3. Armas: o script `encaixe_armas.mjs` põe o ponto da mão, a direção da lâmina e o tamanho em metros, conforme a tabela de medidas acima. O jogo carrega de `assets/armas/<id>.glb` e fecha os dedos no cabo.\n4. Monstros, árvores, muralha, luzes, céus e texturas entram no jogo na rodada de correções.\n\n'


TURN = ("Now show this exact same character (same face, body, outfit, colours and proportions) from the {v} view, same A-pose, "
        "same plain mid-grey background, same lighting, full body, no text.")


def markdown(items):
    L = []
    a = L.append
    a("# Valtheria — pedidos de imagem para o Gemini\n")
    a("Arquivo gerado por `cliente-godot/ferramentas/catalogo_arte.py`. Não edite à mão: mude o script e rode de novo.\n")
    a("## Como usar\n")
    a("1. Use o Gemini pago com o modelo de imagem de maior qualidade (Nano Banana Pro). Uma conversa nova para cada personagem, arma ou monstro.")
    a("2. Copie o texto do bloco **Prompt** inteiro, sem cortar. Ele já traz as regras de fundo, luz, pose e medidas.")
    a("3. Formato: use a proporção indicada em cada item (ex.: 3:4). Resolução: a maior disponível (2K ou 4K).")
    a("4. **Personagens:** depois da imagem de frente, na mesma conversa, peça as vistas de lado e de costas com os textos da seção *Vistas extras*. O Meshy aceita até 4 imagens do mesmo personagem e o modelo 3D sai muito melhor.")
    a("5. Salve cada imagem com o nome indicado em **Arquivo** (ex.: `raca_humano_m_pesada.png`). As vistas extras levam `_lado` e `_costas` no fim.")
    a("6. Confira a imagem antes de salvar (lista na seção *Conferência*). Se falhar em algum ponto, peça no mesmo chat: *\"Refaça corrigindo: …\"*.")
    a("7. Junte tudo numa pasta `Valtheria-imagens`, compacte em .zip e envie ao Robson. Ele me passa e eu faço o 3D, o encaixe e coloco no jogo.\n")
    a("**Por que tudo isso:** o Meshy transforma a imagem em 3D. Fundo liso, luz igual, pose A e mãos vazias fazem o modelo sair limpo, com braços e pernas separados para o esqueleto. "
      "As armas saem separadas do corpo para poder trocar de equipamento e de grau, e com cabo reto e medido para a mão fechar em volta dele.\n")
    a("**Ordem sugerida:** raças (seção 1) → armas grau NG (seção 2, só os `_ng` primeiro) → pranchas de pegada (3) → monstros (4) → árvores (5) → muralha (6) → luzes (7) → céus (8) → texturas (9) → demais graus de arma.\n")
    a(EXTRA)
    a("## Conferência antes de salvar\n")
    a("- Fundo cinza liso, sem chão, sem sombra, sem texto, sem marca d'água visível.")
    a("- Personagem: corpo inteiro, pose A, mãos vazias e com dedos visíveis, nada cobrindo braços e o espaço entre as pernas, sem capa.")
    a("- Arma: inteira, de pé, reta, cabo cilíndrico separado da guarda e do pomo. Uma arma só por imagem.")
    a("- Árvore: folhas desenhadas uma a uma nas bordas, nada de bola lisa; tronco e base visíveis.")
    a("- Muralha: as pontas das peças retas e lisas (precisam encaixar umas nas outras).")
    a("- Céu: formato 2:1, sem chão, as bordas esquerda e direita combinam.\n")
    a("## Vistas extras (só personagens e monstros humanoides)\n")
    a("Na mesma conversa, depois da imagem de frente:\n")
    a("```\n" + TURN.format(v="left side (profile, facing left)") + "\n```")
    a("```\n" + TURN.format(v="back") + "\n```\n")
    a("## O que estes pedidos corrigem no jogo\n")
    a("| Problema visto | O que resolve | Quem faz |")
    a("|---|---|---|")
    a("| Árvores sem folhas, com cara de polígono | Seção 5 (árvores com folhas desenhadas) + folhas com transparência e distância de desenho no jogo | Imagens: criador · Código: Claude |")
    a("| Personagem e monstros sem pisar no chão | Modelos novos com pés planos e medidas certas + ajuste dos pés no terreno no jogo | Imagens: criador · Código: Claude |")
    a("| Muros desencaixados | Seção 6 (kit modular com medidas fixas) + encaixe por grade seguindo o terreno | Imagens: criador · Código: Claude |")
    a("| Noite sem luz nas estradas e cidades | Seção 7 (postes, tochas, lanternas) + luzes acesas à noite no jogo | Imagens: criador · Código: Claude |")
    a("| Sem lua, estrelas e sensação de distância | Seção 8 (céus) + névoa de distância e luz da lua no jogo | Imagens: criador · Código: Claude |")
    a("| Arma não segura firme na mão | Seções 2 e 3 (cabo reto e medido, pranchas de pegada) + dedos fechando no cabo e encaixe automático | Imagens: criador · Código: Claude (já começou) |")
    a("| Chão repetido e sem profundidade | Seção 9 (texturas que se repetem sem emenda) | Imagens: criador · Código: Claude |\n")
    a("## Medidas e pegada das armas\n")
    a("Valem para um personagem de 1,80 m; o jogo diminui no anão e aumenta no gigante. *Mão principal* = a partir da ponta do cabo.\n")
    a("| Arma | Comprimento | Mão principal | Segunda mão | Fora de combate | Em combate |")
    a("|---|---|---|---|---|---|")
    for w in WEAPONS:
        at = "no meio" if w["at"] < 0 else ("vestido" if w["id"] in ("punhos", "garras") else ("alça (antebraço)" if w.get("shield") else f"{w['at']:.2f} m"))
        two = f"{w['two']:.2f} m" if w["two"] else ("outra mão (par)" if w.get("dual") else "—")
        a(f"| {w['nome']} | {w['len']:.2f} m | {at} | {two} | {w['calm']} | {w['battle']} |")
    a("")
    grp = None
    for it in items:
        if it["grupo"] != grp:
            grp = it["grupo"]
            n = sum(1 for x in items if x["grupo"] == grp)
            a(f"## {grp}  ({n} pedidos)\n")
            if grp.startswith("2."):
                a("Graus: NG Rústico · D Bronze · C Aço · B Azurita · A Rubro · S Celestial · SS Lendária. O formato da arma é o mesmo em todos os graus; muda o material e os enfeites.\n")
            if grp.startswith("3."):
                a("Essas pranchas não viram 3D: servem de referência para eu ajustar a mão e a postura de cada arma no jogo.\n")
            if grp.startswith("4."):
                a("Monstros de quatro patas, aranhas e dragões precisam de esqueleto próprio: o modelo entra agora e a animação vem depois.\n")
        a(f"### {it['titulo']}")
        a(f"- **Arquivo:** `{it['arquivo']}`  ·  **Formato:** {it['aspect']}")
        a("```")
        a(it["prompt"])
        a("```\n")
    return "\n".join(L)


if __name__ == "__main__":
    items = build()
    with open(os.path.join(AQUI, "armas.json"), "w", encoding="utf-8") as f:
        json.dump(weapons_json(), f, ensure_ascii=False, indent=1)
    with open(os.path.join(AQUI, "prompts.json"), "w", encoding="utf-8") as f:
        json.dump({"turnaround": [TURN.format(v="left side (profile, facing left)"), TURN.format(v="back")], "items": items}, f, ensure_ascii=False, indent=1)
    docs = os.path.join(os.path.dirname(RAIZ), "docs")
    os.makedirs(docs, exist_ok=True)
    with open(os.path.join(docs, "PROMPTS_GEMINI.md"), "w", encoding="utf-8") as f:
        f.write(markdown(items))
    from collections import Counter
    print(len(items), "pedidos", dict(Counter(i["grupo"] for i in items)))
