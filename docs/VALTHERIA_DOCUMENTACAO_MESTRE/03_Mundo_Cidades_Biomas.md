# VALTHERIA — Documento de Mundo, Cidades e Biomas
**Versão examinada:** cliente nativo 0.17.0 (commit `29d9507`) · **Data:** 14/11/2026 · **Arquivo do mapa:** `imagens/Valtheria_Mapa_Geral.png`

Os números abaixo foram conferidos nos arquivos atuais:
- `cliente-godot/data/world.json`
- `cliente-godot/data/mapa.json`
- `cliente-godot/data/height.bin`
- `cliente-godot/data/splat.png`
- `cliente-godot/scripts/world.gd`, `cidade.gd`, `especial.gd`, `combat.gd`, `npcs.gd`
- `quests.js`

Nenhum arquivo do jogo foi alterado. Marcas usadas: **[E]** existe no projeto · **[P]** proposta (aguarda aprovação) · **[!]** problema encontrado.

---

## 1. Conferência dos números

| Item | Diagnóstico anterior | Conferido agora | Fonte |
|---|---|---|---|
| Tamanho do mundo | cerca de 3 × 3 km | **3.000 × 3.000 m**, relevo de 1501 × 1501 pontos (2 m), de −40 a +260 m | `world.json` (`size`, `step`, `lo`, `range`) |
| Cidades | 15 | **15** (1 capital, 4 grandes, 10 médias e especiais) | `world.json` `towns`, `mapa.json` |
| Castelos | 10 | **10** | `mapa.json` `castles` |
| Vilas | 17 | **17** | `mapa.json` `villages` |
| Ruínas e pontos de interesse | 23 | **23** (3 deles também viraram castelos) | `world.json` `landmarks` |
| Pontos de caça com chefe | — | **12** (2 por cidade nas 6 cidades originais) | `towns[].spots` |
| Pontes | — | **1** (ponte de pedra, entre Pedra Alta e a Ponte de Pedra) | `world.json` `bridges` |
| Água | — | **3,9% da área**, num único corpo ligado ao mar: borda, Baía das Marés e Abissália. **Não há lagos nem rios no interior.** | cálculo sobre `height.bin` |
| Estradas de terra | — | 10,5% dos pontos do chão | canal vermelho de `splat.png` |

---

## 2. Mapa geral

Ver `imagens/Valtheria_Mapa_Geral.png`:
- cidades com a faixa de nível dos arredores;
- castelos, vilas e ruínas;
- estradas;
- limites das 6 regiões.

**Como o mundo está organizado hoje [E]:**
- **Sul:** o mundo inicial (Pradaria e Campos: Vila Aurora, Vale Dourado).
- **Centro:** Floresta (Sylvar, Clã das Presas, Umbraval) e a capital Valtheria Real.
- **Leste:** Montanha (Pedra Alta, Porto Maré-Alta).
- **Noroeste:** Terras Rubras (Cidadela Rubra, Pico do Dragão, Fortaleza Glacial).
- **Nordeste:** Terras Geladas (Bastião Celeste, Castelo Noctis).
- **Sudeste:** a Baía das Marés (Ilha de Coralis, Abissália).

As regiões são **fatias de pizza** a partir do centro: as linhas retas que aparecem no mapa. O nível dos monstros **não** depende da região; depende da **cidade mais próxima** (`combat.gd`, `_level_at`).

---

## 3. Catálogo das cidades

### 3.1 Tabela geral

As colunas vêm destas fontes:

| Coluna | Fonte |
|---|---|
| Posição e altura | `height.bin` |
| Região | `splat.png` |
| Porte e planta | `mapa.json` |
| Níveis | `world.json` |
| Missões | `quests.js`, contadas por cidade |

| Cidade | Posição (x, z) | Região onde está | Altura | Porte / planta | Povo | Níveis | Missões existentes | Ligação por estrada |
|---|---|---|---|---|---|---|---|---|
| Valtheria Real | 1500, 1985 | Floresta | 8 m | Capital · grade | Todos | 1–30 | 0 | Rede principal, Sylvar |
| Vila Aurora | 1500, 2550 | Pradaria | 6 m | Média · radial | Humanos | 1–19 | 4 principais + 3 secundárias | Rede principal, Porto |
| Vale Dourado | 650, 2050 | Campos | 6 m | Grande · grade (mercado de grãos) | Halflings → humanos | 20–39 | 4 + 3 | Rede principal |
| Pedra Alta | 2350, 1950 | Montanha | 6 m | Média · terraços | Anões | 40–51 | 2 + 3 | Rede principal |
| Sylvar | 1500, 1450 | Floresta | 6 m | Média · Árvore-Mãe | Elfos | 52–60 | 2 + 2 | Rede principal |
| Cidadela Rubra | 650, 800 | Terras Rubras | 6 m | Grande · grade (arena de guerra) | Orcs | 61–75 | 2 + 2 | Rede principal |
| Bastião Celeste | 2350, 650 | Terras Geladas | **128 m** (montanha) | Média · espiral | Sylphs → elfos | 76–80 | 1 + 2 | **[!] Estrada só na cidade, cortada na encosta** |
| Clã das Presas | 1000, 1500 | Floresta | 6 m | Média · acampamento | Homens-fera | 20–39 | 0 + 2 | Rede principal |
| Umbraval | 2150, 1300 | Floresta | 6 m | Média · caverna | Elfos negros | 52–60 | 0 + 2 | **[!] Estradas internas sem ligação de fora** |
| Pico do Dragão | 1450, 420 | Terras Rubras / Geladas | **168 m** (montanha) | Média · encosta | Dragonitas | 61–75 | 0 + 2 | **[!] Sem estrada** |
| Castelo Noctis | 2720, 1150 | Terras Geladas | 6 m | Grande · grade (catedral) | Nocturnos → elfos negros | 76–80 | 0 + 1 | Rede principal |
| Fortaleza Glacial | 330, 330 | **Terras Rubras [!]** | 6 m | Média · salão | Gigantes | 76–80 | 0 + 1 | Rede principal |
| Porto Maré-Alta | 2390, 2440 | Montanha (praia) | 6 m | Grande · grade + cais | Humanos | 40–51 | 0 | Estrada até Aurora; ligação fraca com Pedra Alta |
| Ilha de Coralis | 2560, 2790 | Montanha (ilha) | 4 m | Ilha | Halflings → humanos | 40–51 | 0 | Só nadando ou por redemoinho |
| Abissália | 2290, 2800 | Pradaria (fundo do mar) | −34 m | Submarina | Elfos | **1–19 [!]** | 0 | Só por redemoinho |

### 3.2 Ficha de cada cidade

**Legenda das marcações:**
- **Arquitetura e serviços:** [E] (`world.gd`, `cidade.gd`, `especial.gd`, `npcs.gd`).
- **História:** [P], tirada da Bíblia Narrativa v1.0.
- **Paleta:** materiais usados hoje no código, com uma proposta de direção.

**Serviços comuns a todas [E]:**
- Mercador (loja), Ferreiro (ofício), Mestre do Clã, Mestre de Classes, Estalajadeiro.
- Guardas nos portões e personagens de história.
- 46 a 74 moradores com rotina, viajantes nas estradas e animais.
- Portas com interior (taverna e ferraria), zona segura, postes de luz e janelas acesas.

#### Valtheria Real — capital
- **História [P]:**
  - Fundada depois do Grande Silêncio como sede neutra do Conselho do Pacto.
  - A Arena dos Heróis dá o título de Campeão do Pacto, que **não muda a história**.
- **Bioma:** Floresta (borda sul), área plana de 225 m.
- **Arquitetura [E]:**
  - Grade de ruas retas; avenida central de 16 m e ruas de 8 m.
  - Quarteirões de casas de 3–4 andares com térreo de pedra e andares de cimento com vigas.
  - Telhados vermelhos, azuis e de ardósia; muralha quadrada de 200 m.
- **Paleta [P]:** creme e cinza-claro, telhado azul-real, detalhes dourados no palácio.
- **Público [E]:**
  - Palácio Real (cúpula dourada), Catedral da Aurora, Arena dos Heróis (coliseu de 40 m).
  - Jardim Real, Jardim Central e outros dois jardins; praça com chafariz e 4 estátuas de herói; Grande Mercado.
- **Serviços próprios [E]:**
  - Loja de Lendários e Itens Únicos, Forja Lendária, Quartel dos Cavaleiros e campo de treino.
  - Taverna, ferraria, estábulo; 12 cavaleiros de ronda; mais de 74 moradores de várias raças.
- **Economia [P]:** comércio de alto valor (lendários, encantamento, leilão).
- **Missões:** nenhuma **[!]**.
- **Ligações:** estradas para Aurora (sul) e Sylvar (norte); avenidas leste e oeste sem estrada até Dourado e Pedra Alta **[!]**.

#### Vila Aurora — cidade inicial
- **História [E]:** sede da trégua (Segundo Juramento); Arauto do Eclipse. Personagens: Irmã Elowen, Capitão Doran Vel, Velho Tobias.
- **Bioma:** Pradaria.
- **Arquitetura [E]:** dois anéis de casas (modelos Quaternius), torre do sino, moinho, praça e ruas de pedra até os portões, muralha redonda.
- **Paleta [P]:** madeira clara, pedra cinza, telhado azul.
- **Pontos próximos [E]:** Campos do Amanhecer, Bosque dos Javalis, Campina Velha, Castelo dos Corvos, Ruínas de Vel'Anor.
- **Missões [E]:** m01–m04, s_aur1–3, lenda do Rei Corvo e lenda das Ruínas.

#### Vale Dourado — cidade grande
- **História [E]:** Mira Pés-Ligeiros e Ancião Bramble (trigo cinzento perto do Monólito).
- **Bioma:** Campos.
- **Arquitetura [E]:** grade de cidade grande com Grande Mercado de Grãos, moinhos, igreja, jardins e muralha quadrada. **[!]** A antiga planta de "campos" (casinhas e plantações) foi substituída quando a cidade virou grande; a identidade rural ficou só nos moinhos.
- **Paleta [P]:** trigo dourado, madeira, telhado vermelho.
- **Pontos próximos:** Planície dos Bandidos, Ninho das Aranhas, Forte dos Saqueadores, Brejo das Almas, Trigal, Vau das Presas.
- **Missões [E]:** m04–m07, s_dou1–3, lenda de Grak.

#### Pedra Alta
- **História [E]:** Thrain Martelo-Fundo e Brunna Cinzel; forja da Coroa.
- **Bioma:** Montanha.
- **Arquitetura [E]:** muralha quadrada, três terraços de casas, bairro das forjas com caldeirões, salão de pedra.
- **Paleta [P]:** pedra escura, cobre, brasas.
- **Pontos próximos:** Pedreira dos Golens, Cripta Esquecida, Mina Funda, Ponte de Pedra, Cripta dos Reis.
- **Missões [E]:** m07–m09, s_ped1–3, lenda do Rei Lich.

#### Sylvar — Árvore-Mãe
- **História [E]:** Aelar Folha-Prata e Lyria Canto-de-Orvalho.
- **Bioma:** Floresta.
- **Arquitetura [E]:**
  - Árvore de 84 m com raízes em arco, 3 plataformas com casas e rampa em espiral.
  - Lago de luz, cristais, árvores luminosas, casas no chão entre as raízes.
- **Paleta [P]:** casca marrom, folhagem verde-esmeralda, luz verde-água.
- **Pontos próximos:** Coração da Mata, Vale Espectral, Clareira de Lys, Templo da Lua Partida.
- **Missões [E]:** m09–m11, s_syl1–2, lenda da Sacerdotisa da Lua.

#### Cidadela Rubra — cidade grande
- **História [E]:** Grukk Dente-de-Ferro e Shara Olho-Rubro.
- **Bioma:** Terras Rubras.
- **Arquitetura [E]:** grade com a Arena de Guerra, quartel e igreja. **[!]** A antiga planta de "fortaleza" (quartéis em fileira, braseiros) foi substituída pela grade.
- **Paleta [P]:** pedra vermelha, ferro escuro, fogo.
- **Pontos próximos:** Deserto Escarlate, Fenda Demoníaca, Acampamento das Cinzas, Posto da Fronteira, Castelo Rubro, Pântano da Hidra.
- **Missões [E]:** m11–m13, s_rub1–2, lenda da Hidra.

#### Bastião Celeste
- **História [E]:** Seren do Alto Céu.
- **Bioma:** Terras Geladas, topo de montanha a 128 m.
- **Arquitetura [E]:** casas em espiral, torre central, muralha hexagonal.
- **Pontos próximos:** Ninho dos Dragões, Ruínas de Aeternum, Pouso das Nuvens, Castelo Celeste.
- **Missões [E]:** m14, s_cel1–2.

#### Clã das Presas
- **História [E]:** Ruk Garra-Cinza.
- **Bioma:** Floresta.
- **Arquitetura [E]:** paliçada de madeira, cabanas em círculo, totens, fogueiras.
- **Missões [E]:** s_pre1–2.

#### Umbraval — cidade subterrânea
- **História [E]:** Nyxara.
- **Bioma:** dentro de montanha oca, no limite entre Floresta e Terras Geladas.
- **Arquitetura [E]:** casas em meia-lua, obelisco, domo de pedra com estalactites e cristais roxos e azuis, luz própria.
- **Missões [E]:** s_umb1–2.
- **Problemas:** **[!]** o teto ainda lê como céu noturno; **[!]** a entrada (desfiladeiros) não tem estrada vinda de fora.

#### Pico do Dragão
- **História [E]:** Kaelthar Escama-de-Bronze.
- **Bioma:** topo de montanha nevada a 168 m.
- **Arquitetura [E]:** rua comprida com casas dos dois lados e santuário no fim.
- **Missões [E]:** s_pic1–2.
- **Problemas:** **[!]** não há estrada nem trilha subindo a montanha; **[!]** o relevo ficou ondulado.

#### Castelo Noctis — cidade grande
- **Bioma:** Terras Geladas.
- **Arquitetura [E]:** grade com a Catedral Sombria e o Palacete dos Nobres. **[!]** A planta gótica antiga foi substituída.
- **Pontos próximos:** Castelo do Sangue Eterno, Vigia do Corvo.
- **Missões [E]:** s_noc1, lenda do Conde Carmesim.

#### Fortaleza Glacial
- **Bioma:** **[!] Terras Rubras** no mapa de regiões. A cidade dos gigantes de gelo fica na região vermelha, por isso **não neva** lá (a neve depende da região).
- **Arquitetura [E]:** poucas casas grandes, grande salão, muralha redonda; moradores com roupa de frio.
- **Pontos próximos:** Trono do Inverno, Castelo do Trono do Inverno, Aldeia da Geada.
- **Missões [E]:** s_gla1, lenda do Wyrm do Inverno.

#### Porto Maré-Alta — cidade grande
- **Bioma:** praia da Baía das Marés.
- **Arquitetura [E]:** grade, mercado do porto, 2 cais com barcos, farol, redemoinho para Abissália.
- **Missões:** nenhuma **[!]**.

#### Ilha de Coralis
- **Bioma:** ilha de areia e grama.
- **Arquitetura [E]:** anel de casas, chafariz, cais, farol, redemoinho.
- **Problemas:** **[!]** a ruína "Ruínas do Comboio" está posicionada em cima da ilha.

#### Abissália
- **Bioma:** fundo da baía (−34 m), dentro de uma bolha de ar.
- **Arquitetura [E]:** casas de mármore, Templo das Marés, corais e algas.
- **Problemas:** **[!]** faixa de nível 1–19, copiada da cidade vizinha por engano; **[!]** a bolha quase não aparece.

---

## 4. Catálogo dos biomas

### 4.1 As seis regiões [E]

Fontes: `splat.png` (canal alfa) e `world.gd` (`TREES`, `DENSITY`, `SMALL`).

| Região | Área de terra | Altura média / máxima | Árvores (densidade por bloco de 100 m) | Plantas e chão | Clima e atmosfera |
|---|---|---|---|---|---|
| Pradaria | 12,2% | 26 / 154 m | Árvore comum 1 e 2, árvore torcida (40) | Pedras, arbustos, samambaias, flores, cogumelos, plantas grandes, frutinhas, tocos e troncos com musgo | Folhas no vento, vaga-lumes à noite |
| Campos | 18,0% | 40 / 196 m | Árvore comum 1 e 2, torcida (32) | Igual à Pradaria | Folhas douradas no vento, vaga-lumes |
| Montanha | 15,8% | 25 / 178 m | Pinheiros 1 e 3, árvore comum 3 (34) | Pedras médias e grandes, pedras com musgo, tocos | Poeira cinza no vento |
| Floresta | 12,6% | 34 / 178 m | Árvore comum 1 e 3, torcida (66) + árvores luminosas raras | Igual à Pradaria + plantas grandes | Folhas, vaga-lumes |
| Terras Rubras | 21,2% | 39 / 184 m | Árvores mortas 1 e 2, torcida (16) | Pedras, ossos, tocos, cogumelos | Brasas no vento |
| Terras Geladas | 20,1% | 38 / 188 m | Pinheiros 1 e 2 (26) | Pedras com neve, arbustos com neve | Neve caindo, névoa mais densa |

Em todas as regiões há capim instanciado perto do jogador e chuva de tempos em tempos (exceto na neve).

### 4.2 Ambientes especiais [E]

| Ambiente | Onde | O que tem |
|---|---|---|
| Montanhas altas nevadas | Pico do Dragão, Bastião Celeste | Encosta de pedra cinza, topo branco |
| Praia e mar | Baía das Marés | Faixa de areia, fundo de areia escura, água com profundidade; o jogador nada na água funda |
| Fundo do mar | Abissália | Névoa azul, corais, algas, luzes azuis |
| Caverna | Umbraval | Domo de pedra, estalactites, cristais, luz roxa, névoa |
| Árvore gigante | Sylvar | Copa, plataformas, brilhos no ar |
| Interiores | 7 tipos de sala | Luz quente própria |

### 4.3 O que falta nos biomas

**[!] Lacunas:**
- **Água no interior:** não há rios nem lagos. Pântanos (Pântano da Hidra, Charco de Mûrgal, Brejo das Almas, Lodaçal Antigo, Pântano do Véu) existem só como ruínas, sem água nem vegetação de brejo.
- **Deserto:** "Deserto Escarlate" é só o nome de um ponto de caça; não há areia, dunas nem cactos (o modelo `q_cactus_1` existe e não é usado).
- **Transições:** as regiões se encontram em **linhas retas** (fatias de pizza); não há mistura gradual de vegetação.
- **Manchas de neve fora do lugar:** no sudoeste (Campos) e no centro há manchas brancas de picos altos; a neve visual não segue a região de clima.
- **Interação:** nada se quebra, se colhe ou se mexe no cenário nativo. A coleta (`game_gather`, 2.649 pontos no banco) existe só na web.

---

## 5. Pontos de interesse

### 5.1 Ruínas e locais (23) [E]

| Local | Tipo | Perto de | Chefe de lenda (web) | No nativo |
|---|---|---|---|---|
| Castelo dos Corvos | Castelo antigo → castelo de cerco | Aurora | Rei Corvo | Castelo; sem chefe |
| Ruínas de Vel'Anor | Ruína | Aurora | Guardião das Ruínas | Ruína + 6 guardiões |
| Forte dos Saqueadores | Forte | Vale Dourado | Grak | Ruína + guardiões |
| Cripta dos Reis | Cripta | Pedra Alta | Rei Lich Morthas | Ruína + guardiões |
| Templo da Lua Partida | Templo | Sylvar/Umbraval | Sacerdotisa da Lua | Ruína + guardiões |
| Pântano da Hidra | Pântano | Rubra/Presas | Hidra | Ruína (sem água) |
| Castelo do Sangue Eterno | Castelo antigo → castelo de cerco | Noctis | Conde Carmesim | Castelo; sem chefe |
| Trono do Inverno | Castelo antigo → castelo de cerco | Glacial | Wyrm do Inverno | Castelo; sem chefe |
| Charco de Mûrgal, Brejo das Almas, Lodaçal Antigo, Pântano do Véu | Pântanos | vários | Matriarca do Pântano | Ruína (sem água) |
| Cripta dos Esquecidos, Necrópole de Varn, Túmulos do Rei Cego, Mausoléu Partido | Tumbas | vários | — | Ruína + guardiões |
| Caravana Destroçada, Ruínas do Comboio, Destroços do Cerco | Destroços | vários | — | Ruína + guardiões (**[!]** Ruínas do Comboio está na Ilha de Coralis) |
| Monólito Sussurrante, Círculo de Pedras Vivas, Fenda Astral | Lugares estranhos (Vazio) | vários | Vespa do Vazio | Ruína + guardiões |
| Era Neon — Distrito Ômega | Fenda no tempo | entre Sylvar e Pedra Alta | Mecha Ômega | **Sem conteúdo** |

### 5.2 Pontos de caça com chefe (12) [E]

| Cidade | Pontos de caça |
|---|---|
| Aurora | Campos do Amanhecer, Bosque dos Javalis |
| Vale Dourado | Planície dos Bandidos, Ninho das Aranhas |
| Pedra Alta | Pedreira dos Golens, Cripta Esquecida |
| Sylvar | Coração da Mata, Vale Espectral |
| Cidadela Rubra | Deserto Escarlate, Fenda Demoníaca |
| Bastião Celeste | Ninho dos Dragões, Ruínas de Aeternum |

As **9 cidades restantes não têm ponto de caça**. **[!]**

### 5.3 Castelos (10) e vilas (17) [E]

As listas e posições estão em `mapa.json` e no mapa geral. Problemas encontrados:
- **Sem estrada a menos de 80 m:**
  - castelos: Castelo Celeste e Castelo do Sangue Eterno **[!]**;
  - vilas: Campina Velha, Trigal, Clareira de Lys e Pouso da Estrada Real **[!]**.
- **Desenhados duas vezes no mapa:** Castelo dos Corvos e Trono do Inverno aparecem como castelo **e** como ponto de interesse.

---

## 6. Conexões, áreas vazias e dependências

### 6.1 Estradas

Cálculo sobre `splat.png`:
- **Rede principal:** Aurora, Valtheria Real, Vale Dourado, Pedra Alta, Sylvar, Clã das Presas, Cidadela Rubra, Fortaleza Glacial e Castelo Noctis.
- **Fora da rede principal:**
  - Porto: só a estrada até Aurora;
  - Bastião Celeste e Umbraval: estradas que não chegam à rede;
  - Pico do Dragão, Coralis e Abissália: nenhuma estrada.
- **Causas:**
  - a pintura de pedra das montanhas novas e do anel de Umbraval **apagou** as estradas antigas que subiam até lá;
  - as estradas da capital para leste e oeste não foram feitas.

### 6.2 Áreas vazias

Pedaços de 300 m a mais de 330 m de qualquer cidade, vila, castelo, ruína ou ponto de caça. São 8, todos na **borda do mapa**:

| Lado | Áreas (x, z) |
|---|---|
| Sudoeste | 150,2550 · 150,2850 · 450,2850 · 750,2850 |
| Norte | 750,150 · 1050,150 · 2550,150 · 2850,150 |

O miolo do mapa não tem buracos grandes; a borda tem.

### 6.3 Dependências com missões e monstros [E]

- **Níveis de monstro:**
  - Os monstros nascem pela **cidade mais próxima**: família pela "faixa" da cidade e nível entre o mínimo e o máximo dela, crescendo com a distância (`combat.gd`).
  - Por isso, **quando uma cidade nova entra, a área em volta muda de nível**:
    - a capital (1–30, faixa 0) passou a mandar na região entre Aurora e Sylvar, que antes era de Sylvar (52–60);
    - Abissália (1–19) e Coralis (40–51) mandam numa parte da baía.
  - **[!]** Isso precisa ser revisto.
- **Missões:**
  - As 63 missões estão ligadas às 11 cidades antigas (`quests.js`).
  - As 4 cidades novas (capital, porto, ilha e Abissália) não têm missão.
  - O cliente nativo ainda não tem sistema de missões.
- **Servidor:** `game.towns` (11 cidades), `game.teleports` e `game.nodes` (pontos de coleta) foram feitos para o mapa antigo **[!]**.

---

## 7. Melhorias visuais

| # | Melhoria | Arquivos e recursos afetados | Prioridade |
|---|---|---|---|
| V1 | Modelos de construção para casas de cidade, igreja, palácio, arena, salões e castelos, no lugar das caixas | `cidade.gd`, `world.gd` (`_build_castle`), novos GLB em `assets/world/` | Alta |
| V2 | Corrigir a região de clima da Fortaleza Glacial (pintar Terras Geladas em volta) | `ferramentas/relevo_cidades.py` → `splat.png`, `tint.png` | Alta |
| V3 | Estradas subindo o Pico e o Bastião (trilha em zigue-zague com calçamento) e ligando Umbraval, a capital (leste e oeste), o porto, castelos e vilas isolados | `relevo_cidades.py` (estradas no `splat`), `cidade.gd` (calçamento) | Alta |
| V4 | Teto de Umbraval mais legível (textura e luz) e bolha de Abissália visível | `especial.gd`, `atmos.gd` | Média |
| V5 | Transições suaves entre regiões (borda com ruído e mistura de vegetação) | `splat.png` (gerado), `world.gd` (`_vegetation`) | Média |
| V6 | Pântanos com água rasa, junco e névoa; um ou dois rios ligando montanhas ao mar | `relevo_cidades.py`, `world.gd` (água), novos modelos de planta | Média |
| V7 | Deserto Escarlate como bioma (areia, dunas, cactos `q_cactus_1`, rochas vermelhas) | `relevo_cidades.py`, `world.gd` (`SMALL`, `TREES`) | Média |
| V8 | Montanha do Pico menos ondulada | `relevo_cidades.py` (`mountain`) | Baixa |
| V9 | Devolver identidade às cidades grandes que perderam a planta antiga: bairro rural no Dourado, quartéis no Rubra, bairro gótico no Noctis | `cidade.gd` (`build_big`, temas) | Média |

---

## 8. Plano de expansão sem perda do conteúdo atual

Regras:
- nenhuma cidade, castelo, vila ou ruína é removida;
- cada etapa diz os arquivos afetados;
- cada etapa é testada com fotos antes de seguir.

| Etapa | O que fazer | Arquivos | Critério de aceitação |
|---|---|---|---|
| **M1 — Correções de dados** | Abissália com nível coerente; mover "Ruínas do Comboio" para fora da ilha; remover a duplicação castelo/ponto de interesse só no desenho; revisar a faixa de monstros em volta da capital e da baía | `relevo_cidades.py`, `world.json`, `combat.gd` (regra de nível perto de cidades de nível baixo) | Fotos e leitura dos dados sem incoerências; nenhum lugar a menos |
| **M2 — Estradas e acessos** | Estradas para todas as cidades, castelos e vilas; trilhas nas montanhas; entrada de Umbraval | `relevo_cidades.py`, `cidade.gd` | Toda cidade e todo castelo ligados à rede principal (verificado por cálculo, como no item 6.1) |
| **M3 — Clima e regiões** | Fortaleza Glacial com neve; transições suaves; deserto; pântanos com água | `relevo_cidades.py`, `world.gd`, `atmos.gd` | Neve em Glacial; nenhuma linha reta visível entre regiões |
| **M4 — Exploração** | Pontos de caça e coleta nas 9 cidades sem ponto; segredos nas 8 áreas vazias da borda (ruína pequena, vista, baú, chefe raro); chefes de lenda no nativo | `world.json` (`spots`, `landmarks`), `combat.gd` | Cada cidade com ao menos 1 ponto de caça; cada área vazia com um motivo para ir |
| **M5 — Sincronizar o servidor** | Cidades, castelos, teleportes e pontos de coleta no banco a partir do `world.json` | Migração Supabase (`game.towns`, `game.castles`, `game.teleports`, `game.nodes`) | Contagens iguais entre o cliente e o banco |
| **M6 — Arte das construções** | Modelos de construção (V1) a partir do pipeline Gemini → Meshy | `assets/world/`, `cidade.gd` | Capital e cidades grandes sem prédios de caixa |
| **M7 — Masmorras** | Interiores de cripta, templo e caverna nas ruínas principais | `interiores.gd`, `world.gd` | Ao menos 3 masmorras com sala, chefe e saída |

---

## 9. Decisões pendentes do Robson

1. **Porte das 10 cidades médias e especiais:** continuam médias, ou alguma vira pequena?
2. **Cidades grandes:** recuperar a identidade antiga em bairros (V9), ou manter a grade igual para as quatro?
3. **Nível em volta da capital e da baía:** a capital passa a ser zona inicial (1–30) ou continua mandando os monstros do entorno como Sylvar?
4. **Abissália:** qual faixa de nível? Sugestão: 40–51, como o porto e a ilha.
5. **Rios e lagos:** aprovar a criação (V6)? Isso muda o relevo em várias regiões.
6. **Ordem das etapas M1 a M7.**
