# 12 — Guia de Identidade Visual V1 e Plano da Prova de Conceito V2

**Status:** V1.1 — **aprovado com ressalvas (D36, 14/11/2026)**; esta revisão incorpora as ressalvas. Referência da prova V2; **não autoriza alterar modelos oficiais.**
**Base:**
- D31 aprovada: semi-realista estilizado;
- D32 aprovada: V2 com 1 masculino, 1 feminino, 1 armadura e 1 espada, só em ramificação de teste;
- D33 aprovada: preparar a entrada para gamepad, implementar depois do HUD.

**Data:** 14/11/2026

**Medidas atuais conferidas nos arquivos [F]:**

| Modelo | Triângulos | Ossos | Materiais |
|---|---|---|---|
| Corpo humano masculino Quaternius | 14.318 | 65 | 3 |
| Corpo humano feminino | 15.060 | 65 | 3 |
| Armadura de cavaleiro | 17.164 | — | 1 |
| Anão (Meshy) | 33.992 | 65 | 1 |
| Dragonita (Meshy) | 15.438 | 65 | 1 |

Texturas de personagem: 66 de 1024², 34 de 512² e 18 de 256².

---

## 1. Guia de identidade visual V1

### 1.1 Em uma frase
**Fantasia medieval de mundo antigo e vivo:** corpos com proporção real, rostos legíveis, materiais que mostram uso (couro gasto, aço riscado, pedra lavada pela chuva), pintados à mão sobre volumes simples, com luz quente e suave. A magia é rara, precisa e luminosa.

### 1.2 Pilares
1. **Proporção real, forma simplificada.** A anatomia é correta; os detalhes pequenos vão para a textura, não para a malha.
2. **Material antes de cor.** Uma peça se reconhece pelo material (aço, couro, linho) antes da cor.
3. **Uso e história.** Riscos, desgaste nas bordas, poeira nos pés. Nada parece novo de fábrica, exceto o que é sagrado ou mágico.
4. **Silhueta legível a 20 m.** Cada raça, classe e monstro se reconhece pela forma, sem depender da cor.
5. **Magia contida.** Brilho só onde há magia (runas, cristais, efeitos). No máximo 10% da peça tem cor forte.
6. **Unidade.** Personagem, monstro, arma, casa e chão usam a mesma paleta, a mesma densidade de detalhe e a mesma luz.

### 1.3 O que evitar
- Cel-shading com contorno preto.
- Cabeça grande e olhos de anime.
- Cores saturadas puras.
- Néon e plástico brilhante.
- Ornamento em toda superfície.
- Peças sem espessura.
- Armadura sem articulação.
- Cópia de qualquer obra existente (personagem, brasão, armadura, interface).

---

## 2. Paleta de cores oficial
Imagem: `imagens/Paleta_Oficial_V1.png`.

| Grupo | Cores (hex) | Uso |
|---|---|---|
| Identidade | Ouro do Pacto `#C9A45C` · Seiva da Árvore `#8FA85A` · Luz da Aurora `#E8D29A` · Violeta do Véu `#6B5A9E` · Carmesim do Eclipse `#7E2A33` · Noite `#14161B` | Interface, símbolos, magia da história, brasões |
| Metais | Ferro `#4A4E55` · Aço `#8A9099` · Bronze `#9C6B3C` · Prata `#C4C8CE` · Ouro envelhecido `#B08A3E` · Platina celestial `#D9DCE2` | Armas e armaduras por grau |
| Orgânicos | Couro cru `#8A6844` · Curtido `#5E4029` · Escuro `#3B2A1D` · Linho `#D6CAAE` · Lã tingida `#5D3A3A` · Madeira `#7A5534` | Roupas, cabos, correias, móveis |
| Construção | Pedra clara `#B3AC9E` · Cinza `#7F7B73` · Ardósia `#4F535A` · Tijolo `#94573F` · Telha `#7B3F2E` · Cimento antigo `#A39C8C` | Cidades e ruínas |
| Regiões | Pradaria `#7E9A4E` · Campos `#B39A55` · Montanha `#7D7A70` · Floresta `#3F5E33` · Terras Rubras `#8C4A33` · Terras Geladas `#C9D6DE` | Chão, névoa e luz ambiente de cada região |
| Elementos | Os pares de cor do `fx.gd` atual (fogo, gelo, luz, sombra, natureza, raio…) | Só em efeitos e runas |

**Regras:**
- Saturação máxima de 70% fora dos efeitos.
- Preto e branco puros só na interface.
- Cada cultura tem **uma cor de tecido própria**, e essa cor ocupa no máximo 25% da roupa:

| Cultura | Cor do tecido |
|---|---|
| Humanos | Azul-ardósia |
| Elfos | Verde-sálvia |
| Elfos negros | Violeta do Véu |
| Orcs | Ocre |
| Anões | Carmesim |
| Homens-fera | Terracota |
| Dragonitas | Bronze |
| Gigantes | Azul-gelo |

**Cores de grau** (já usadas na interface, mantidas):
- NG cinza
- D bronze
- C prata
- B azul
- A vermelho
- S violeta
- Lendário dourado

## 3. Padrão de materiais

Os materiais são uma **biblioteca única**, reaproveitada em tudo o que o jogo tiver.

| Material | Cor base | Rugosidade | Metal | Detalhe pintado |
|---|---|---|---|---|
| Ferro batido | `#4A4E55` | 0,65 | 1 | Martelado, ferrugem leve nas juntas |
| Aço | `#8A9099` | 0,40 | 1 | Riscos finos, borda mais clara |
| Bronze | `#9C6B3C` | 0,45 | 1 | Pátina verde só em fendas |
| Prata, platina | `#C4C8CE` | 0,30 | 1 | Gravação rasa |
| Ouro envelhecido | `#B08A3E` | 0,35 | 1 | Usado só em filetes e emblemas |
| Couro | `#5E4029` | 0,75 | 0 | Costuras, dobras, borda gasta |
| Tecido (linho, lã) | `#D6CAAE` / cor da cultura | 0,90 | 0 | Trama visível só de perto, barra desfiada |
| Madeira | `#7A5534` | 0,80 | 0 | Veio, nós |
| Pedra | `#7F7B73` | 0,85 | 0 | Borda lascada, musgo por região |
| Cristal e magia | Cor do elemento | 0,10 | 0 | Brilho próprio (emissão) fraco |

**Regras técnicas (padrões iniciais, sujeitos à V2):**
- Poucos materiais por peça, **sem sacrificar a qualidade nem a organização**: corpo, cabeça/rosto, olhos e cabelo podem ter materiais próprios quando isso melhora o resultado ou a troca de cor; a V2 mede o custo e define o número.
- Mapas por material: cor (com a luz suave pintada), normal e um mapa de rugosidade e metal. Sem mapa de oclusão separado: a sombra suave vai pintada na cor.
- O brilho próprio só em runas, cristais e olhos de criaturas mágicas.

## 4. Anatomia e proporções

> As medidas abaixo são **padrões iniciais**, sujeitos à validação da V2.

Referência: humano de **1,80 m**, **7,5 cabeças** de altura, no **esqueleto atual de 65 ossos** (nomes `pelvis`, `spine_01–03`, `neck_01`, `Head`, `clavicle`, `upperarm`, `lowerarm`, `hand`, dedos, `thigh`, `calf`, `foot`, `ball`).

| Medida (humano, homem / mulher) | Valor |
|---|---|
| Altura | 1,80 m / 1,68 m |
| Cabeça | 0,24 m / 0,22 m (1 : 7,5) |
| Largura dos ombros | 0,46 m / 0,39 m |
| Largura do quadril | 0,36 m / 0,38 m |
| Mão (pulso à ponta) | 0,19 m / 0,17 m |
| Altura do quadril (virilha) | 0,90 m / 0,84 m |

- **Rosto:** traços adultos, olhos em tamanho real (sem olhos grandes de anime), nariz e queixo definidos, sobrancelha marcada para ler a expressão de longe. Rostos variados por raça (seção do `04`).
- **Mãos e pés:** dedos separados até a segunda falange, para as armas encaixarem pela pegada já existente (`GRIP`).
- **Pose de produção:** pose em T, com braços a 90° e palmas para baixo. É a pose que a ferramenta `ferramentas/pele_automatica.mjs` usa para ligar ao esqueleto.
- **Outras raças** (para a expansão, não para a V2): as alturas e traços propostos no `04`, seção 2.2, partem desta mesma régua.

## 5. Padrão de iluminação

| Situação | Luz principal | Ambiente | Névoa | Observação |
|---|---|---|---|---|
| Dia | Sol branco-quente (5.500 K), sombra suave | Céu azul-claro, fraco | Leve, cor do horizonte | Contraste moderado; nada estoura no branco |
| Amanhecer e entardecer | Sol baixo âmbar (3.500 K) | Lilás no lado da sombra | Dourada | O momento "cinematográfico" do mundo |
| Noite | Lua azul fria, fraca | Azul-escuro | Azulada | Janelas, tochas e fogueiras quentes fazem o contraste |
| Interior | Luz quente das janelas e velas | Âmbar | — | Já existe; manter |
| Caverna e subterrâneo | Cristais e tochas | Violeta-escuro | Densa | Já existe (Umbraval) |
| Regiões | Tom do ambiente e da névoa pela cor da região (paleta) | — | — | Terras Rubras avermelhadas; Geladas azuladas e mais densas |

**Limites:**
- Uma luz direcional com sombra.
- Luzes pontuais só fixas (tochas e lareiras próximas), sem criar ou remover durante o jogo.
- Efeitos de luz avançados (SDFGI, névoa volumétrica) ficam só no nível de qualidade alto, **se** o notebook rodar no renderizador que os aceita.
- O visual precisa ficar bom **sem** eles. Item a confirmar na medição real.

## 6. Padrão de texturas

| Item | Celular / qualidade baixa | PC / qualidade média e alta |
|---|---|---|
| Personagem jogável (corpo + roupa) | 1024² | 2048² (só no alto) — **padrão inicial** |
| Arma, escudo | 512² | 1024² |
| Monstro comum | 1024² | 1024² |
| Chefe e guardião | 1024² | 2048² |
| Construção modular | Atlas compartilhado de 2048² por cultura | Igual |
| Vegetação | Atlas compartilhado de 1024² | Igual |

**Compressão no Godot 4.7 por tipo de textura** (opções de importação de cada imagem; valor inicial, a confirmar na V2):

| Tipo de textura | Modo de compressão (Import → Compress → Mode) | Opções obrigatórias | Desktop (formato resultante) | Celular (futuro) |
|---|---|---|---|---|
| Cor base (albedo), sRGB | **VRAM Compressed** | `mipmaps/generate` ligado · `compress/high_quality` desligado no padrão, **ligado** só no personagem jogável | S3TC/BPTC → **DXT1** sem transparência, **DXT5/BC3** com transparência; **BC7** com alta qualidade | ETC2 / ASTC |
| Mapa normal | **VRAM Compressed** | `compress/normal_map = Enable` (o Godot passa a usar **RGTC/BC5**, dois canais) · `mipmaps/generate` ligado | BC5 | ETC2 RG / ASTC |
| Rugosidade + metal (ORM), dados lineares | **VRAM Compressed** | `compress/channel_pack = Optimized` · usada no material como dado linear (sem sRGB) · `mipmaps/generate` ligado | DXT1/BC1 | ETC2 |
| Máscaras de cor (pele, tecido da cultura) | **VRAM Compressed** | `compress/channel_pack = Optimized` · dado linear | BC1/BC4 | ETC2 |
| Cabelo e folhagem com recorte (alpha) | **VRAM Compressed** | `mipmaps/generate` ligado · alpha preservado | DXT5/BC3 ou BC7 | ETC2 RGBA |
| Interface, ícones, fontes | **Lossless** | `mipmaps/generate` desligado | PNG sem perda | Igual |
| Céu e pós-processamento HDR | **VRAM Compressed** | `compress/hdr_compression` conforme a placa | BPTC (BC6H) | ASTC HDR |
| Texturas pequenas de efeito (≤ 128²) | **Lossless** ou **VRAM Uncompressed** | — | Sem compressão | Igual |

Regras:
- Nunca usar **Lossy** (WebP com perda) em mapas normais e de dados: estraga a iluminação.
- O arquivo-fonte pode continuar em WebP ou PNG no projeto; o que vale para a memória de vídeo é o modo de importação acima.
- A V2 mede a memória com e sem essas opções (seção 8) e o resultado pode mudar esta tabela.

**Contagem de triângulos:** a pedido seu, **não é fixada agora**. A V2 mede e propõe o limite. Faixa de partida apenas para orientar a produção, sujeita à medição:

| Personagem | Faixa de partida |
|---|---|
| Corpo com roupa | 20 a 35 mil triângulos |
| Arma | 1,5 a 4 mil triângulos |

## 7. Especificação dos personagens da V2

| Item | Especificação |
|---|---|
| Quem | **Humano masculino** e **humana feminina**: são a base de 3 das 8 raças e a referência de proporção |
| Corpo | Proporções da seção 4; pose em T; 65 ossos atuais; 2 tons de pele e 1 cabelo cada para testar a troca de cor que o jogo já faz |
| Rosto | Adulto, traços definidos, olhos de tamanho real; sobrancelha separada para a cor do cabelo |
| Armadura (1) | **Armadura leve de couro e aço, grau C**: gibão de couro curtido, peitoral e ombreiras de aço, braçadeiras, cinto, botas. Tecido azul-ardósia (cultura humana) em no máximo 25% da peça. Peça separada do corpo, como o sistema atual exige (`outfit`), nas versões masculina e feminina |
| Espada (1) | **Espada longa de aço, grau C**: lâmina de 0,85 m, guarda reta com ponteiras de bronze, punho de couro, pomo com a folha da Árvore em relevo raso. Pegada `espada` atual |
| Integração | Mesmo sistema de montagem (`character.gd`): corpo + roupa + cabelo + arma no osso `hand_r`. Nenhum código oficial muda: os arquivos novos entram numa ramificação de teste e a escolha é feita por um argumento de teste (`--v2`) |
| Comparação | Prancha lado a lado (atual × V2, frente, lado, costas) **e capturas dentro do Godot**: parado, correndo, golpe de espada, magia, sentado, na luz de dia, entardecer e noite |

### 7.1 Caminho de produção (custo mínimo)

1. **Conceito 2D:** prancha frente, lado e costas de cada personagem, com o JSON de medidas (prompt pronto, no padrão do `catalogo_arte.py`). Pode ser do Gemini do seu parceiro (D19) ou gerada aqui.
2. **Modelo 3D:**
   - **Opção A (recomendada):** corpo base de fonte livre CC0 com proporção realista e esqueleto no padrão de nomes que o jogo já usa (a confirmar a ferramenta exata no início da V2; licença conferida antes). Meshy **só** para armadura e espada: 2 gerações.
   - **Opção B:** tudo no Meshy (corpo masculino, feminino, armadura, espada): cerca de 4 gerações.

   **Créditos Meshy:** restam cerca de 41 **[C]**. Antes de gastar, eu confiro o custo exato de cada geração e peço sua confirmação.
3. **Ligação ao esqueleto:** `ferramentas/pele_automatica.mjs` (a mesma usada nos anões), com redução de triângulos.
4. **Texturas:** ajuste de cor para a paleta oficial e compressão.
5. **Godot:** cena de teste e capturas.

## 8. Plano de medição de desempenho

**Onde:**
1. Neste ambiente de trabalho: números que não dependem da placa (triângulos, chamadas, memória).
2. **No seu notebook**, com o `registro.txt`: o FPS e o tempo de quadro reais. **Sem essa medição, a V2 não é aprovada para expansão.**

| Métrica | Como | Atual × V2 |
|---|---|---|
| Triângulos por personagem | Leitura do arquivo `.glb` | 14–15 mil (atual) |
| Materiais por personagem | Idem | 3 (atual) |
| Texturas: quantidade, resolução, memória em vídeo | Monitor `RENDER_TEXTURE_MEM_USED` antes e depois de carregar | 251 MB na capital (atual, cena inteira) |
| Chamadas de desenho | Monitor do Godot com 1 personagem e com **20 personagens V2** na praça da capital | 774 (capital, sem sombra) |
| Memória total | `MEMORY_STATIC` e memória de vídeo | 153 MB / 289 MB |
| Animações | As 28 animações tocadas uma a uma; captura de 6 delas | Todas funcionam no atual |
| Armadura e espada | Encaixe nos 2 gêneros, em 4 animações de golpe | — |
| FPS real | Notebook, qualidades 0 e 2, praça da capital com 20 personagens V2 | **Falta medir** |

Resultado: tabela atual × V2 + capturas + o limite de triângulos e de textura **proposto** para a expansão.

### 8.1 Método da medição de referência (para a comparação ser válida)

Os números "atuais" deste guia e do `09` foram medidos assim, e **a V2 repete exatamente o mesmo método**:

| Item | Valor |
|---|---|
| Versão do jogo | Cliente nativo 0.17.0, commit `29d9507` (cópia temporária, fora do repositório) |
| Máquina | Contêiner sem placa de vídeo; OpenGL 3.3 por software (Mesa llvmpipe) dentro de xvfb |
| Godot | 4.7.2, `--rendering-driver opengl3` (renderizador de compatibilidade), janela 1280×720 |
| Argumentos | `--play --at=X,Z --lite=Q --shot=arquivo.png` (`Q` = nível de qualidade; 0 = sem sombra, 1 = com sombra) |
| Cenas | Capital `1500,1985` · Vila Aurora `1500,2550` · Campo `1250,2250` (câmera padrão, distância 7,5 m, sem clima forçado) |
| Momento | No quadro em que a captura é salva (depois de o mundo carregar em volta do jogador) |
| Leitura | Monitores do Godot: `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, `OBJECT_NODE_COUNT`, `MEMORY_STATIC`, `RENDER_VIDEO_MEM_USED`, `RENDER_TEXTURE_MEM_USED` |
| Observações | As chamadas de desenho incluem as passadas de sombra quando a sombra está ligada. **FPS não é válido** nesse ambiente. Uma única leitura por cena; a V2 fará 3 leituras por cena e usará a mediana |

A V2 também guarda, junto da tabela, o comando exato e o commit usado, e a mesma medição é repetida **no notebook** (com o `registro.txt`), onde o FPS passa a valer.

### 8.2 Teste de compatibilidade do esqueleto (corpo por corpo)

Ter os mesmos nomes de osso não garante deformação correta. Cada corpo V2 (masculino e feminino) passa por:

1. **Nomes e hierarquia:** os 65 ossos com o mesmo nome e o mesmo pai do esqueleto atual (lista gerada por script e comparada).
2. **Pose de repouso:** orientação de cada osso igual à do esqueleto atual (diferença máxima de 1°), senão as 28 animações giram errado.
3. **Escala e pivô:** altura em metros, pés no chão (`y = 0`), frente para +Z como os corpos atuais.
4. **Pesos:** cada vértice com no máximo 4 ossos, soma 1; nenhum vértice preso a osso de ponta (`*_leaf`).
5. **28 animações × 3 quadros cada** (início, meio, fim): captura automática de frente e de lado.
6. **Medida automática de deformação:** para cada quadro, o maior estiramento de aresta da malha em relação ao repouso; acima de 1,6× marca a região (ombro, cotovelo, quadril, joelho, punho) para revisão a olho.
7. **Armadura e espada:** a armadura usa os mesmos pesos do corpo; checagem de pele atravessando a armadura nos 3 quadros das animações de golpe e de corrida; espada no osso `hand_r` com a pegada atual.
8. **Resultado:** prancha com as capturas + tabela por animação (passou / revisar).

## 9. Arquivos que serão criados

**Todos novos, numa ramificação de teste `v2-prova-visual`; nenhum arquivo existente é alterado ou removido.**

| Arquivo | O que é |
|---|---|
| `cliente-godot/assets/chars_v2/body_v2_male.glb`, `body_v2_female.glb` | Corpos V2 |
| `cliente-godot/assets/chars_v2/outfit_v2_leve_c_male.glb`, `..._female.glb` | Armadura V2 |
| `cliente-godot/assets/armas_v2/espada_c_v2.glb` | Espada V2 |
| `cliente-godot/assets/chars_v2/*.webp` | Texturas |
| `cliente-godot/scripts/v2_teste.gd` | Cena de teste lado a lado (só com o argumento `--v2`) |
| `cliente-godot/ferramentas/medir_v2.gd` | Script que gera a tabela de medição |
| `docs/v2/V2_Relatorio.md` + `docs/v2/capturas/*.png` | Relatório com tabela e capturas |
| `CREDITOS.md` | **Só uma linha a mais** com a origem e a licença dos modelos novos |

## 10. Critérios de aprovação

**Do guia (agora):**
- [ ] Paleta aprovada
- [ ] Materiais aprovados
- [ ] Proporções aprovadas
- [ ] Luz aprovada
- [ ] Texturas aprovadas
- [ ] Especificação da V2 aprovada
- [ ] Opção A ou B de produção escolhida (D34)

**Da V2 (depois):**
1. **Visual:**
   - Lado a lado com o atual, você reconhece o novo padrão.
   - Rosto legível a 5 m; silhueta legível a 20 m.
   - Sem aparência de desenho animado.
2. **Técnico:**
   - Liga ao esqueleto de 65 ossos sem deformação visível nas 28 animações (ombro, cotovelo, quadril, joelho).
   - Armadura e espada encaixam nos 2 gêneros.
   - Troca de pele e cabelo funciona.
3. **Desempenho:** no notebook, com 20 personagens V2 na praça, a queda de FPS fica dentro do limite que você aprovar depois de ver a medição (proposta: até 15% em relação aos atuais).
4. **Integridade:**
   - Nenhum arquivo oficial alterado (prova: `git diff main` só mostra arquivos novos e a linha do `CREDITOS.md`).
   - Jogo oficial idêntico sem `--v2`.
5. **Registro:** relatório no modelo das Diretrizes.

---

## 11. Duas frentes de trabalho

### Frente A — Fundação técnica (aprovada pela D01)

| Etapa | Entrega | Depende de | Aceitação |
|---|---|---|---|
| A1 | `game_save2`: limite de HP/MP e de velocidade; e correção do salvamento dentro de prédios, que hoje grava a posição do interior | — | Valores falsos recusados; saves normais passam |
| A2 | `game_kill4`: nível, chefe e família decididos pelo servidor | Cidades e monstros no banco (A4) | `p_boss` e nível vindos do cliente sem efeito |
| A3 | Contador de abates + `game_quest_done2` | A2 | Missão de matar exige abates reais |
| A4 | Banco com 15 cidades (porte, faixa, pontos de chefe) e as famílias de monstros | — | Contagens iguais ao cliente |
| A5 | Reconexão do WebSocket | — | Volta sozinho após queda |
| A6 | Testes automáticos (sintaxe, entrada no jogo, chamadas falsas ao servidor) no GitHub Actions | — | Build falha se um teste falhar |
| A7 | Medição no notebook | `registro.txt` (D18) | Tabela de FPS por cena |

**Regras da frente A:**
- As funções antigas continuam existindo para a versão web.
- Só o jogo novo passa a usar as novas.
- Fechar as antigas é a decisão D35 (a versão web pararia de dar recompensas).

### Frente B — Evolução visual

| Etapa | Entrega | Depende de | Aceitação |
|---|---|---|---|
| B1 | **Este guia** | — | Seus critérios da seção 10 |
| B2 | Prancha 2D dos personagens V2 | B1, D34 | Você aprova a prancha |
| B3 | V2 dentro do Godot + medição | B2, A7 para o FPS | Seção 10, critérios da V2 |
| B4 | Expansão para as 8 raças | B3 aprovada | Raça por raça |
| B5 | Armas e armaduras | B3 | Por tipo |
| B6 | Criaturas | B3 | Por família |
| B7 | Ambientes | B3 | Por região |
| B8 | Interface (HUD com retrato, minimapa, missões; entrada preparada para gamepad, D33) e efeitos | — | Por tela |

As frentes andam em paralelo. A Frente A não toca arquivos de arte; a Frente B não toca o servidor.

## 12. Decisões novas
- **D34:** produção da V2. Opção A (corpo livre CC0 + Meshy só para armadura e espada, cerca de 2 gerações) ou Opção B (tudo no Meshy, cerca de 4). Recomendo a **A**.
- **D35:** **adiada** (decisão do Robson): só será tratada depois de provar que o jogo novo substitui toda a versão web sem perda de progresso ou recompensas.
