# VALTHERIA — Inventário de Assets e Matriz de Lacunas

**Base auditada:** branch `main`, commit `29d9507` (cliente nativo 0.17.0), lida numa cópia separada (`git worktree`, só leitura). Data: 15/11/2026.
**Também considerado:** branch `v2-prova-visual` (corpos V2) e a prova de aparência V2 de 14/11 (fora do repositório).
**Método:** leitura de todos os `.glb` do cliente com um script de medição (triângulos, materiais, ossos, animações, texturas), leitura dos scripts (`character.gd`, `combat.gd`, `world.gd`, `cidade.gd`, `main.gd`, `fx.gd`, `atmos.gd`, `interiores.gd`) e dos dados (`data/world.json`, tabelas de conteúdo do banco).

**Legenda de classificação (pedida na auditoria):**
1 = existe e funciona · 2 = existe, precisa de melhoria · 3 = existe só em parte · 4 = não existe, precisa ser produzido · 5 = existe, não validado.
"Funciona" aqui quer dizer que o arquivo existe **e** o código o usa no jogo. Arquivo presente sem uso no código é marcado como 5.

---

## 1. Números gerais

| Pasta | Arquivos `.glb` | Texturas soltas | Observação |
|---|---|---|---|
| `assets/chars` | 40 | 288 (webp/jpg/png, embutidas ou separadas) | Corpos, roupas, cabelos, armas, 2 pacotes de animação |
| `assets/world` | 90 | 48 | Animais, criaturas, casas, adereços, vegetação, rochas, 3 texturas de terreno |
| `assets/armas` | 4 | 0 | Cópias de armas Quaternius com nome `_ng` |
| Shaders | 1 arquivo (`ceu.gdshader`) + 6 escritos dentro dos scripts | — | Terreno, grama, água, calçamento, céu, efeito especial |
| Scripts | 15 `.gd`, 10.265 linhas | — | Mundo, cidades e interiores são **gerados por código** |

**Origem e licença (CREDITOS.md):** personagens-base, animações, criaturas e cenário = Quaternius (CC0). Anões e Dragonita = Meshy, CC BY 4.0 (exige atribuição, já registrada).

---

## 2. Personagens

### 2.1 Corpos e roupas

| Arquivo | Triângulos | Materiais | Ossos | Texturas | Usado no código | Classe |
|---|---|---|---|---|---|---|
| `body_male` / `body_female` | 14.318 / 15.060 | 3 | 65 | 1024² + 256² (olhos) | Sim (base) | 2 |
| `body_male_{knight,noble,peasant,ranger,wizard}` | 4.674–4.708 (corpo recortado sob a roupa) | 3 | 65 | 1024² | Sim | 2 |
| `body_female_{peasant,ranger}` | 5.386 | 3 | 65 | 1024² | Sim | 2 |
| `outfit_male_knight / noble / peasant / ranger / wizard` | 17.164 / 20.129 / 12.894 / 26.982 / 14.430 | 1–2 | 65 | 512² a 1024² | Sim | 2 |
| `outfit_female_peasant / ranger` | 13.568 / 26.966 | 1–2 | 65 | 1024² | Sim | 2 |
| `body_anao_m` / `body_anao_f` (Meshy) | 33.992 / 34.000 | 1 | 65 | 1024² cor + normal | Sim | 2 |
| `body_dragonita` (Meshy) | 15.438 | 1 | 65 | 1024² | Sim | 2 |
| **V2** `v2_ligado_{masculino,feminino}` (branch de teste) | 26.756 | 1 (sem textura) | 65 | — | Só no benchmark | 5 |
| **V2 aparência** `v2a_{masculino,feminino}` (fora do repositório) | 30.894 / 30.652 (7 malhas) | 7 | 53/55 (MPFB, ainda **não** ligado aos 65 do jogo) | 1024² | Não | 5 |

**Personagem completo hoje** (corpo recortado + roupa + cabelo + sobrancelha): de cerca de 24 mil triângulos (cavaleiro) a 34 mil (patrulheiro), em 4 a 6 materiais.

### 2.2 As 8 raças jogáveis (`data/world.json → races`)

| Raça | Como é montada hoje | Diferença visual real | Classe |
|---|---|---|---|
| Humanos | Corpo Quaternius + roupa por tipo de armadura | Tom de pele (5), cabelo (6), cor de cabelo | 2 |
| Elfos Brancos | **Mesmo corpo humano**, escala 1,05 | Só tom de pele e altura. **Sem orelhas pontudas** | 3 |
| Elfos Negros | Mesmo corpo humano, escala 1,03 | Pele violeta. Sem orelhas | 3 |
| Orcs | Corpo humano com ossos ajustados (`SHAPE orc:m`) | Pele verde, tronco largo. **Sem presas nem rosto próprio** | 3 |
| Anões | Modelo próprio (Meshy), corpo + roupa + cabelo numa peça | Silhueta própria, mas roupa e cabelo **não trocam** | 2 |
| Homens-fera | **Corpo humano com pele marrom/cinza** | Nenhuma cabeça animal, orelha, cauda ou pelagem | 3 |
| Dragonitas | Modelo próprio (Meshy) | Silhueta própria; sem roupa trocável | 2 |
| Gigantes de Gelo | Corpo humano ampliado 1,38× com ajuste de ossos | Pele azulada e escala | 3 |

**Achado principal:** só 2 das 8 raças têm silhueta própria. Elfos, elfos negros, orcs, homens-fera e gigantes são o humano recolorido ou esticado. Isso contraria o Guia de Identidade V1 ("cada raça tem silhueta desenhada para ela").

### 2.3 Rosto, olhos, sobrancelhas, cabelo

| Item | Situação | Classe |
|---|---|---|
| Olhos | Textura única marrom (256²); a cor do olho não é escolhida pelo jogador | 2 |
| Sobrancelhas | 2 malhas (`regular`, `female`), tingidas com a cor do cabelo | 2 |
| Cabelos | 8 malhas (buzzed, buzzedfemale, simpleparted, long, slickback, bob, buns, moustache) + barba; 6 escolhas por gênero | 2 |
| Rosto | Uma cabeça por gênero, sem variação de formato (o `look.face` do servidor guarda 0–3, mas o cliente não troca a malha) | 3 |
| Expressões faciais | Não existem | 4 |
| V2 (MakeHuman CC0) | 23 peles, 12 sobrancelhas, 4 cílios, 9 cores de olho, 9 cabelos, 20 roupas disponíveis e com licença conferida | 5 |

### 2.4 Esqueleto e animações

| Item | Situação | Classe |
|---|---|---|
| Esqueleto do jogo | 65 ossos (padrão Quaternius/UE), o mesmo em todos os corpos e roupas | 1 |
| `anims_a.glb` | 16 clipes: Dance, Death01, Hit_Chest, Idle, Idle_Talking, Interact, Jog_Fwd, PickUp_Table, Punch_Cross, Punch_Jab, Sitting_Idle, Spell_Simple_Idle, Spell_Simple_Shoot, Sprint, Sword_Attack, Walk | 1 |
| `anims_b.glb` | 12 clipes: Consume, Farm_Harvest, Idle_FoldArms, Idle_Shield, OverhandThrow, Shield_OneShot, Sword_Block, Sword_Regular_A/B/C, TreeChopping, Yes | 1 |
| Animações que faltam | Arco (puxar e soltar), cajado e magia de área, adaga dupla, espada de duas mãos, lança, esquiva, pulo, nadar, montar, cair, levantar, emotes | 4 |
| Pele (skinning) dos corpos V2 | 84/84 poses iguais ou melhores que o corpo atual (medição de 14/11) | 5 |

---

## 3. Equipamentos

| Item | Arquivos | Triângulos | Materiais | Classe |
|---|---|---|---|---|
| Espada, espadão, machado, adaga, martelo, lança, arco, escudo | `w_*.glb` (8) + cópias `armas/*_ng.glb` (4) | 715–1.945 | 3–5, **sem textura** (só cor) | 2 |
| Cetro, cajado, lança | O código usa **a mesma malha da lança** (`w_spear`) para os três, só muda o tamanho | — | — | 3 |
| Punhal, armas duplas | Reaproveitam adaga e espada | — | — | 3 |
| Encaixe na mão | `GRIP` em `character.gd`: comprimento, ponto da pegada, segunda mão, costas ou cintura, por tipo; IK do braço na guarda | — | — | 1 |
| Armaduras | **Não existem como peças.** A "armadura" escolhe uma das 7 roupas inteiras (`pesada→knight/ranger`, `leve→ranger`, `robe→wizard/peasant`) | — | — | 3 |
| Capacete, luvas, botas, capa, ombreiras | Não existem como peças trocáveis | — | — | 4 |
| Variação por grau (NG, D, C, B, A, S, R) | Só na interface (cor do nome). O modelo é o mesmo em todos os graus | — | — | 4 |
| Encantamento visual (+16) | Existe no servidor; no cliente, brilho por emissão (`fx.gd`) | — | — | 5 |

**Achado:** o banco tem 332 itens, mas o jogo mostra 8 malhas de arma e 7 roupas. A repetição visual de equipamentos é a maior de todo o projeto.

---

## 4. Criaturas e chefes

**18 famílias no banco (`game.mob_fams`)** e **o que o cliente desenha para cada uma** (`combat.gd`):

| Família | Modelo usado | Reaproveitamento | Classe |
|---|---|---|---|
| Javali, Rei Javali | `a_bull` (touro) escalado | Animal de outra espécie | 3 |
| Lobo, Lobo Espectral | `m_wolf` | Mesmo modelo, só cor | 2 |
| Aranha, Rainha Aracnídea | `e_spider` | Mesmo modelo, escala | 2 |
| Lagarto Guerreiro | `z_raptor` | Dinossauro no lugar de homem-lagarto | 3 |
| Orc Bandido, Esqueleto, Demônio, Senhor Demônio, Cavaleiro Caído | **Personagem jogável recolorido** (`Character.create`) | Humanoides iguais aos jogadores | 3 |
| Golem, Golem Ancestral | Gigante cinza com armadura pesada | Humanoide recolorido | 3 |
| Ent, Ent Milenar | Gigante verde com armadura leve | Humanoide recolorido | 3 |
| Dragonete, Dragão Celeste | Corpo do Dragonita (raça jogável) | Raça jogável usada como chefe | 3 |
| Guardiões dos 6 fragmentos | Não têm modelo próprio | — | 4 |

**Modelos de bicho existentes mas não usados em combate:** `e_frog`, `e_rat`, `e_snake`, `e_wasp` (Quaternius, com animação). Classe 5.
**Animais de cenário/montaria:** alpaca, touro, cervo, burro, raposa, cavalo (2), husky, shiba, veado — 10 modelos, 12–13 animações cada. Classe 1.

---

## 5. Mundo e ambientes

| Item | Situação | Classe |
|---|---|---|
| Terreno | 3.000 × 3.000 m, grade de 2 m (1.501²), relevo de −40 a +260 m (`height.bin`), mistura de 3 texturas (grama, terra, rocha) por `splat.png` + tinta por região | 1 |
| Grama | Shader próprio + MultiMesh, com distância de desenho | 1 |
| Água | Shader próprio (ondas por mapa normal, profundidade pelo relevo) | 2 |
| Céu, dia e noite | `ceu.gdshader` + `atmos.gd` (hora do dia, cor do sol, névoa) | 2 |
| Clima e partículas ambientais | CPUParticles (chuva, neve, faíscas) em `fx.gd`/`atmos.gd` | 3 |
| Árvores e plantas | 30 modelos, contando tocos e troncos (pinheiro, comum, retorcida, morta, bétula, salgueiro, cacto, cogumelo, flores, arbustos). Duas árvores estilizadas (`tree_light`, `tree_spiral`) usam textura-paleta de 32² | 2 |
| Rochas | 9 modelos; a rocha grande usa textura-paleta de 32² (quase sem detalhe) | 2 |
| Casas e prédios de vila | 12 modelos Quaternius (casas 1–4, estalagem, ferreiro, moinho, serraria, estábulo, campanário, poço, mercado) | 2 |
| **Cidades grandes** (capital e 4 cidades) | **Geradas por código com caixas, prismas e cilindros** (`cidade.gd`, 945 linhas): ruas, quarteirões, igreja, arena, palácio, porto, farol, ponte | 3 |
| Interiores | Gerados por código com caixas (`interiores.gd`) | 3 |
| Masmorras, cavernas, ruínas | Adereços soltos (colunas, ossos, tochas, baú, entrada) | 3 |
| Regiões climáticas (deserto, vulcânica, gelo, floresta) | Tinta do terreno e escolha de vegetação por região | 3 |
| Regiões dos guardiões | Não existem como áreas próprias | 4 |

---

## 6. Interface

| Item | Situação | Classe |
|---|---|---|
| HUD, barras, chat, painéis móveis | `ui.gd` (1.627 linhas), botões com ícone desenhado por código (`icon_button.gd`) | 1 |
| Inventário, loja, craft, missões | Existem | 1 |
| Mapa e minimapa | Existem (`mapa.json`) | 2 |
| Ícones de itens | Desenhados por código (formas), não ilustrações | 3 |
| Fonte | Cinzel (título) | 1 |
| Configuração gráfica | 5 níveis (Mínima a Ultra) | 1 |
| Seleção e interação | Contorno/realce simples | 2 |

---

## 7. Tecnologia gráfica

| Item | Situação real no código | Classe |
|---|---|---|
| Renderizador | Forward+ (Vulkan; DirectX 12 e modo compatibilidade por `.bat`) | 1 |
| Níveis de qualidade | 5 níveis: escala de resolução 0,6–1,0 com FSR 1, MSAA 0–4×, sombra 1024–8192 com 2 ou 4 divisões e distância 40–220 m, SSAO a partir do Médio, brilho a partir do Médio, névoa volumétrica no Alto, SDFGI só no Ultra | 1 |
| Materiais | 35 usos de `StandardMaterial3D`; 6 shaders próprios | 2 |
| Iluminação | 1 sol direcional, 7 luzes omni, emissão em 47 lugares; tonemap Filmic | 2 |
| Reflexos | Sem SSR, sem sondas de reflexo | 4 |
| Oclusão | Sem `OccluderInstance3D` (oclusão de muralhas não implementada) | 4 |
| LOD | Sem LOD próprio nos modelos; só distância de desenho (`visibility_range`, 40 usos) | 3 |
| Instâncias | MultiMesh em 22 lugares (vegetação, calçamento, casas de quarteirão) | 1 |
| Partículas | CPUParticles3D (23 usos), funcionam em todos os modos | 1 |
| Compressão de texturas | Padrão do Godot (VRAM comprimida no desktop); sem ASTC/ETC2 conferido para celular | 5 |
| Memória e chamadas medidas (Q0, capital) | 774 chamadas, 317 mil triângulos, 289 MB de vídeo (medição sem placa; **o FPS não vale**) | 5 |
| Sombra | Ligar a sombra dobra os triângulos (317 → 705 mil) | 2 |

---

## 8. Matriz de lacunas (resumo)

| Área | 1 Funciona | 2 Melhorar | 3 Parcial | 4 Produzir | 5 Não validado |
|---|---|---|---|---|---|
| Personagens | esqueleto 65, 28 animações | corpos, roupas, cabelos, olhos | 5 das 8 raças, rosto | expressões, animações de arma | V2 corpo e aparência |
| Equipamentos | encaixe na mão | 8 armas | armaduras = roupas inteiras; cajado/cetro = lança | capacete, luvas, botas, capa, ombreira; graus visuais | brilho de encanto |
| Criaturas | animais de cenário | lobo, aranha | 12 das 18 famílias são humanoides recoloridos ou outra espécie | 6 guardiões, homem-lagarto, javali, golem, ent, demônio, dragão | sapo, rato, cobra, vespa |
| Mundo | terreno, grama, instâncias | água, céu, árvores, rochas, casas de vila | cidades e interiores de caixas, masmorras, clima | regiões dos guardiões | — |
| Interface | HUD, inventário, níveis gráficos | mapa, seleção | ícones por código | ilustrações de ícone | — |
| Gráficos | renderizador, 5 níveis, MultiMesh, partículas | materiais, luz, sombra | LOD | oclusão, reflexos | compressão para celular, FPS real |

**Lacunas que mais pesam na qualidade percebida, em ordem:**
1. Raças sem silhueta própria (5 de 8).
2. Armaduras e armas iguais em todos os graus (332 itens, 15 malhas).
3. Monstros humanoides recoloridos (12 de 18 famílias).
4. Cidades de caixas.
5. Falta de medição real no notebook para fixar limites.
