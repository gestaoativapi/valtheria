# 04 — Raças, Personagens e Criaturas

**Versão examinada:** nativo 0.17.0 (`29d9507`) e web congelada · **Data:** 14/11/2026
**Prancha de evidência:** `imagens/Valtheria_Racas_Criaturas_Prancha.png`. Gerada nesta sessão numa **cópia temporária** do cliente, usando o mesmo código de montagem do jogo. Mostra 8 raças × 2 gêneros na linha de cima e os monstros na de baixo.
Marcas: **[F]** fato comprovado · **[P]** proposta · **[C]** confirmar.

---

## 1. Auditoria inicial

### 1.1 Modelos 3D existentes [F]

| Grupo | Arquivos (`cliente-godot/assets/chars/`) | Origem e licença |
|---|---|---|
| Corpos-base humanos | `body_male`, `body_female` + variações com roupa: male (knight, noble, peasant, ranger, wizard), female (peasant, ranger) | Quaternius, CC0 |
| Roupas separadas | `outfit_male_{knight,noble,peasant,ranger,wizard}`, `outfit_female_{peasant,ranger}` | Quaternius, CC0 |
| Cabelos | buzzed, buzzedfemale, simpleparted, long, slickback, bob, buns, beard, moustache e 2 sobrancelhas | Quaternius, CC0 |
| Modelos próprios | `body_anao_m`, `body_anao_f`, `body_dragonita` | Meshy, CC BY 4.0, com crédito em `CREDITOS.md` |
| Animações | `anims_a.glb` (16 clipes), `anims_b.glb` (12 clipes) = **28 clipes** compartilhados | Quaternius, CC0 |
| Armas | 8 modelos `w_*.glb` + 4 `assets/armas/*_ng.glb` | Quaternius, CC0 |

Peso: `assets/chars` ocupa 38 MB, a maior parte em texturas webp de 2K.

### 1.2 Esqueleto e animação [F]
- Todos os corpos usam o **mesmo esqueleto** (nomes de osso do padrão Quaternius/UE: `thigh_l`, `spine_01`, `hand_r`…). As animações são reapontadas por nome de osso em `character.gd::_clips()`.
- Modelos próprios (anões) usam fator de quadril (`OWN.hip` = 0,624 e 0,657) para as animações não levantarem o corpo.
- Raças por escala de ossos (`SHAPE`): anão (como reserva), orc (m), gigante (m/f). **Elfo, elfo negro, homem-fera e orc feminino não têm forma própria** (só escala geral `h`/`w` de `world.json` e cor de pele).
- Clipes disponíveis: Idle, Walk, Jog, Sprint, Dance, Death, Hit_Chest, Interact, PickUp, Punch (2), Spell idle e shoot, Sword_Attack, Sword_Regular A/B/C, Sword_Block, Shield idle e golpe, OverhandThrow, Consume, Farm_Harvest, TreeChopping, Sitting, FoldArms, Talking, Yes.
- **Não existem:** atirar com arco, golpe de lança ou de cajado, golpe de duas mãos, pulo próprio, nado, montaria, voo, esquiva e queda.

### 1.3 Materiais [F]
- Pele por tinta multiplicada (`_tint`) sobre a textura base. Cabelo pela cor de `hair_colors`.
- Dragonita: cor por tinta sobre textura própria. Anões: textura própria sem troca de cor de pele.

### 1.4 Equipamento × aparência [F]
- A **armadura muda só a roupa**, por tipo, e o grau não muda nada:
  - `pesada` → knight (homem) ou **ranger (mulher)**;
  - `leve` → ranger;
  - `robe` → wizard (homem) ou **peasant (mulher)**.
- Elmo, luvas e botas **não aparecem** no corpo.
- **Anões e Dragonitas não trocam de roupa:** a armadura não altera o modelo (`character.gd` linhas 91–130).
- Arma: 11 pegadas em `GRIP`. As armas `punhos` e `garras` (12 itens) **não têm modelo nem pegada** e caem no punho vazio.

### 1.5 Web (referência) [F]
- `data.js` tem **11 raças**: as 8 do nativo mais `halfling`, `sylph` e `nocturno`, marcadas `hidden`.
- O nativo tem as 42 classes dessas 3 raças em `world.json` (`hal_*`, `syl_*`, `noc_*`), mas **não tem a raça em `races`**. As classes existem sem raça jogável.

---

## 2. Raças — situação e ficha

Leitura da prancha: humano, elfo e elfo negro são **o mesmo corpo**, com tons de pele próximos. O homem-fera é um **humano** (sem cabeça de fera, pelagem nem cauda). O orc é um humano verde maior. O gigante é um humano grande. Anão e Dragonita são os únicos com silhueta própria. **[F]**

| Raça (id) | Jogável | Modelo | Silhueta própria | Elemento | Classes | Situação visual |
|---|---|---|---|---|---|---|
| Humanos (`humano`) | Sim | Base Quaternius | Referência | Luz | 17 | Aceitável; base de todas as outras |
| Elfos Brancos (`elfo`) | Sim | Base humana | **Não** (sem orelha, sem proporção) | Vento | 17 | **Redundante** com humano |
| Elfos Negros (`sombrio`) | Sim | Base humana, pele lilás | **Não** | Sombra | 17 | **Redundante** |
| Orcs e Goblins (`orc`) | Sim | Base humana ×1,1, pele verde | Parcial (m) | Fogo | 14 | Sem presas, sem rosto próprio; "goblin" não existe |
| Anões (`anao`) | Sim | Meshy próprio | **Sim** | Terra | 10 | Bom; sem troca de roupa |
| Homens-Fera (`beastman`) | Sim | Base humana | **Não** | Terra | 14 | **Contradiz o `DESIGN.md`** (cabeça animal, pelagem, cauda) |
| Dragonitas (`draconato`) | Sim | Meshy próprio | **Sim** | Fogo | 14 | Bom; sem roupa; "em teste" na bíblia |
| Gigantes de Gelo (`gigante`) | Sim | Base humana ×1,3–1,38 | Parcial | Gelo | 14 | Escala certa, rosto humano |
| Halflings | Não (só web oculta) | — | — | Natureza | 14 | Só dados |
| Sylphs | Não (só web oculta) | — | — | Raio | 14 | Só dados |
| Nocturnos | Não (só web oculta) | — | — | Sombra | 14 | Só dados |

### 2.1 Ficha-padrão de raça [P]
Cada raça deve ter um documento com os campos abaixo, preenchido a partir da Bíblia (`02`, seção 7):

1. História e origem (papel no Pacto)
2. Cultura e cidade
3. Silhueta e proporções, com medidas em metros (altura, ombro, cabeça)
4. Rosto: orelhas, olhos, presas, focinho
5. Pele, cabelo e detalhes: tatuagem, escama, pelagem
6. Vestimenta tradicional por tipo de armadura
7. Animação característica: postura parada e corrida
8. Ligação com a narrativa

### 2.2 Proposta de silhuetas (ideias para as pranchas; nada aprovado) [P]

| Raça | Altura (m, homem/mulher) | Traço que a separa do humano |
|---|---|---|
| Humanos | 1,78 / 1,66 | Referência |
| Elfos Brancos | 1,86 / 1,76 | Orelhas longas, pescoço e membros longos, ombro estreito, olhos amendoados |
| Elfos Negros | 1,80 / 1,70 | Orelhas longas voltadas para trás, cabelo claro, marcas faciais, postura baixa |
| Orcs | 1,95 / 1,82 | Presas inferiores, mandíbula larga, ombro alto, mãos grandes, pele verde-oliva |
| Goblins (opção do mesmo povo) | 1,30 / 1,25 | Orelhas largas, nariz longo, corpo magro |
| Anões | 1,36 / 1,30 | Já existe |
| Homens-Fera | 1,88 / 1,78 | Cabeça de lobo ou felino, pelagem, garras, cauda, perna digitígrada |
| Dragonitas | 1,85 / 1,75 | Já existe |
| Gigantes de Gelo | 2,45 / 2,30 | Pele azulada com rachaduras de gelo, barba de gelo, ombros enormes |

**Regra:** não criar raça nova enquanto elfos, elfos negros e homens-fera forem cópias do humano.

---

## 3. Personagens jogáveis

| Requisito | Situação | Evidência |
|---|---|---|
| Personalização visual | **Parcial:** pele (4–6 tons por raça), 6 cabelos, cores de cabelo, barba. Sem rosto, olhos, marcas nem altura | `ui.gd::_build_create`, `world.json.hair_*` |
| Armadura × modelo | **Parcial:** 3 roupas por gênero; mulher sem armadura pesada própria; anão e Dragonita sem troca | 1.4 |
| Arma × modelo | **Parcial:** 8 modelos para 13 tipos; `punhos` e `garras` sem modelo | `GRIP` |
| Animações de movimento | Sim: andar, correr, disparada, parado, sentar | 1.2 |
| Animações de combate | **Parcial:** só espada, soco, magia e escudo; arco, lança, cajado e duas mãos usam golpe de espada | 1.2 |
| Leitura a distância | Fraca: raças parecidas e roupas com as mesmas cores (laranja, verde) | Prancha |
| Proporções | Corretas no humano (1,80 m); anão e Dragonita conferidos | `OWN`, `SHAPE` |

---

## 4. NPCs

**[F]** `npcs.gd`:
- 10 funções de trabalho (`JOBS`: mercado, forja, campo, pousada, estábulo, praça, igreja, jardim, treino, cais);
- 10 papéis da capital (`CAPITAL_ROLES`);
- 15 personagens de história com falas;
- roupa de frio nas cidades frias;
- guardas e cavaleiros de ronda.

A função do NPC aparece **só pela armadura** (pesada, leve ou robe) e pela arma. Ferreiro, mercador, sacerdote e líder usam as mesmas 3 roupas.

**Proposta de identificação por função [P]:**

| Função | Sinal visual |
|---|---|
| Comerciante | Avental e bolsa, cor da guilda local |
| Ferreiro | Avental de couro, braços à mostra, martelo |
| Guarda | Tabardo com o brasão da cidade, lança |
| Cavaleiro real | Armadura de placas com capa da capital |
| Sacerdote | Túnica branca e dourada com o símbolo da Árvore |
| Líder ou mestre | Capa longa e ornamento de ombro |
| Personagem de missão | Marca flutuante (! ou ?) e nome em cor própria |

Isso pede **3 a 5 roupas novas** de NPC (avental, tabardo, túnica, capa), que servem a todas as raças humanoides.

---

## 5. Criaturas e monstros

### 5.1 Catálogo atual [F]

O nativo tem 18 famílias, em 6 faixas de região (`world.json.mobs`). A web tem mais 15.

| Faixa | Família (id) | Tipo | Chefe | Elemento | Modelo usado no nativo | Problema |
|---|---|---|---|---|---|---|
| 0 | Javali Selvagem (`javali`) | Fera | — | Terra | `a_bull` (touro) | É um touro, não um javali |
| 0 | Lobo Cinzento (`lobo`) | Fera | — | Vento | `m_wolf` | Escala muito pequena na prancha **[C]** |
| 0 | Rei Javali (`rei_javali`) | Fera | Sim | Terra | `a_bull` ×2,2 | Touro grande |
| 1 | Orc Bandido (`bandido`) | Humanoide | — | Fogo | Personagem orc | Aceitável |
| 1 | Aranha Gigante (`aranha`) | Inseto | — | Natureza | `e_spider` | Bom |
| 1 | Rainha Aracnídea (`rainha`) | Inseto | Sim | Natureza | `e_spider` ×2,4 | Aranha maior |
| 2 | Golem de Pedra (`golem`) | Construto | — | Terra | **Gigante humano cinza** | Não parece golem |
| 2 | Esqueleto Guerreiro (`esqueleto`) | Morto-vivo | — | Sombra | **Humano de pele bege** | Não parece esqueleto |
| 2 | Golem Ancestral (`golem_anc`) | Construto | Sim | Terra | Gigante humano | Idem |
| 3 | Ent Corrompido (`ent`) | Planta | — | Natureza | **Gigante humano verde** | Não parece árvore |
| 3 | Lobo Espectral (`lobo_esp`) | Espírito | — | Gelo | `m_wolf` | Sem efeito espectral |
| 3 | Ent Milenar (`ent_mil`) | Planta | Sim | Natureza | Gigante humano verde | Idem |
| 4 | Demônio Rubro (`demonio`) | Demônio | — | Fogo | **Humano vermelho** | Sem chifres, asas nem cauda |
| 4 | Lagarto Guerreiro (`lagarto`) | Réptil | — | Água | `z_raptor` | Raptor muito grande na prancha **[C]** |
| 4 | Senhor Demônio (`senhor_dem`) | Demônio | Sim | Fogo | Humano vermelho ×2,4 | Idem |
| 5 | Dragonete (`dragonete`) | Dragão | — | Raio | **Corpo de Dragonita** | Não é dragão |
| 5 | Cavaleiro Caído (`caido`) | Morto-vivo | — | Sombra | Humano cinza | Aceitável com elmo e efeito |
| 5 | Dragão Celeste (`dragao`) | Dragão | Sim | Fogo | Corpo de Dragonita ×2,8 | **Chefe final sem modelo de dragão** |

**Só na web (15):** Rei Corvo, Guardião das Ruínas, Grak o Saqueador, Rei Lich Morthas, Sacerdotisa da Lua Partida, Hidra do Pântano, Conde Carmesim, Wyrm do Inverno e 7 da Era Neon (drones e mechas). A Era Neon tem tema de ficção científica: **[C]** confirmar se continua no jogo (conflita com a Bíblia).

**Modelos CC0 já baixados e sem uso no nativo:** `x_brute` (golem na web), `z_trex`, `z_apato`, `e_frog`, `e_rat`, `e_wasp`, `e_snake`, animais de montaria (`a_horse`, `a_stag`…). Eles estão em `assets/world` da web e alguns no nativo. **Usar o que já existe antes de gerar modelos novos.** [F]

### 5.2 Comportamento atual [F]
Em `combat.gd`, cada monstro:
- ataca de perto ou de longe pelo papel (`guerreiro` ou `mago`);
- pode ser agressivo ou não (`aggro`);
- passeia em volta do ponto onde nasceu e volta para ele;
- tem chefe com 14× a vida, 1,8× o ataque e 12× a experiência;
- tem o nível tirado da cidade mais próxima (`_level_at`);
- não nasce dentro das cidades.

Não há habilidades de monstro, fuga, grupo nem patrulha.

### 5.3 Ficha-padrão de criatura [P]
Campos: nome, classificação, região, origem na história, modelo e silhueta, animações (parado, andar, correr, atacar, morrer, reagir ao golpe), comportamento, 1 a 3 habilidades, faixa de nível, recompensas (`boss_drops`, troféus) e missões ligadas.

### 5.4 Correções prioritárias de criaturas [P]
1. Golens → `x_brute` (já baixado, CC0; é o mesmo da web).
2. Dragão Celeste e Dragonete → modelo de dragão. Opções: Meshy com os créditos restantes ou pacote CC0. **[C]**
3. Esqueleto → modelo de esqueleto CC0 (pacote Quaternius ou KayKit de esqueletos, licença a conferir).
4. Ent → árvore animada (Meshy ou CC0).
5. Demônio → chifres, cauda e asas como peças presas ao corpo humano, enquanto não há modelo próprio.
6. Javali → modelo de javali (o touro serve até lá).
7. Conferir em jogo as escalas do lobo e do raptor. **[C]**

---

## 6. Qualidade visual — padrão [P]
- Altura de referência de 1,80 m; medidas em metros em todas as pranchas.
- Até 15 mil triângulos por personagem jogável e até 8 mil por monstro comum. Textura 1K no celular e 2K no desktop.
- Paleta de metal e couro natural, com cor forte só nos detalhes (regra do `designer-jogos-arte`).
- Pipeline:
  1. prancha 2D (Gemini, D19);
  2. Meshy;
  3. ligação ao esqueleto do jogo;
  4. teste nas 8 raças;
  5. registro em `CREDITOS.md`.

---

## 7. O que existe, o que corrigir, o que criar

| Existe e serve | Corrigir | Criar |
|---|---|---|
| Esqueleto único, 28 clipes, anão, Dragonita, pegada de 11 armas, NPCs com rotina, roupa de frio | Armadura feminina pesada; anão e Dragonita sem troca de roupa; escala de lobo e raptor **[C]**; golem, ent, esqueleto, demônio e dragão com corpo humano | Silhuetas de elfo, elfo negro, homem-fera, orc e gigante; roupas de NPC; animações de arco, lança, cajado, duas mãos e nado; dragão; 15 famílias da web no nativo |

## 8. Decisões necessárias
- **D17:** halfling, sylph e nocturno ficam só como NPC ou viram jogáveis?
- **D20:** orcs e goblins continuam um só povo (goblin como variação) ou se separam?
- **D21:** a Era Neon (7 monstros de ficção científica) continua?
- **D22:** ordem das silhuetas novas. Proposta: homens-fera → elfos → orcs → gigantes.
- **D19:** imagens do Gemini (ação sua).
