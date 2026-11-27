# 11 — Auditoria Visual e de Gameplay (frente ao Projeto Visual Mestre)

**Referência:** `VALTHERIA_PROJETO_VISUAL_GAMEPLAY_MASTER.md` v1.0, que define fantasia semi-realista, câmera em terceira pessoa e desenvolvimento integrado.
**Versão examinada:** cliente nativo 0.17.0 (commit `29d9507`, igual ao GitHub em 14/11/2026), web Three.js r170 e banco Supabase.
**Garantia:** nenhum arquivo do jogo foi alterado.

**Classificação usada (seção 17 do manual):**
- **EXISTENTE**
- **EXISTENTE COM PENDÊNCIAS**
- **NÃO IMPLEMENTADO**
- **PROPOSTA**
- **BLOQUEADO**
- **CONCLUÍDO E VALIDADO**

Nada recebeu a última marca: nenhum recurso foi validado contra o novo padrão ainda.

---

## 0. Conclusão principal

O jogo tem **muita estrutura funcionando**: mundo, cidades, NPCs, combate, interface e qualidade gráfica ajustável. Mas o **estilo visual de hoje não é semi-realista**:
- quase todos os personagens, monstros, construções e a vegetação vêm de pacotes **low-poly estilizados** (Quaternius, CC0);
- as cidades grandes são montadas por código, com caixas, prismas e cilindros.

Os únicos modelos mais próximos do novo padrão são os gerados no Meshy (anões e Dragonitas). **[F]**

Por isso, alcançar o padrão é sobretudo um trabalho de **troca gradual de arte em cima de sistemas que já funcionam**, não de reconstrução. A ordem importa:
1. primeiro o que o jogador vê de perto (personagem, armas, monstros);
2. depois a cidade e a natureza.

Antes de produzir, é preciso **um guia de identidade visual** (Fase 1 do manual), para que cada modelo novo siga a mesma linha.

---

## 1. Estado atual

### 1.1 Recursos gráficos

| Área | O que existe | Estilo | Classificação |
|---|---|---|---|
| Personagens | 2 corpos-base + 7 roupas Quaternius; anão e Dragonita do Meshy; 9 cabelos; 28 animações | Low-poly estilizado (Meshy mais detalhado) | EXISTENTE COM PENDÊNCIAS |
| Raças | 8 jogáveis; só 2 com silhueta própria (ver `04` e a prancha) | — | EXISTENTE COM PENDÊNCIAS |
| Monstros | 18 famílias; 9 usam corpo humano recolorido; 6 animais e insetos Quaternius | Low-poly | EXISTENTE COM PENDÊNCIAS |
| Guardiões dos 6 fragmentos | Nenhum modelo, encontro ou efeito | — | NÃO IMPLEMENTADO |
| Armas | 8 modelos + 4 `_ng` para 105 itens de 13 tipos; punhos e garras sem modelo | Low-poly | EXISTENTE COM PENDÊNCIAS |
| Armaduras | 3 roupas por gênero; o grau não muda o visual; elmo, luvas, botas, ombreiras e capas invisíveis | Low-poly | EXISTENTE COM PENDÊNCIAS |
| Ícones | Desenhados por código por **tipo** (`icon_button.gd`), não por item; a web tem 16 ícones de imagem | Vetorial simples | EXISTENTE COM PENDÊNCIAS |
| Terreno | Mapa de altura 3 × 3 km, shader com mistura por `splat` e cor por `tint` | — | EXISTENTE |
| Vegetação e pedras | 25 modelos `n_*` + 13 `q_*` (árvores, pinheiros, arbustos, flores, cactos, pedras com neve e musgo) | Low-poly | EXISTENTE COM PENDÊNCIAS |
| Construções | 22 modelos `b_*` (casas, pousada, forja, moinho, estábulo, poço) + cidades por código (`cidade.gd`: casas geminadas, igreja, palácio, arena, porto, farol, ponte, chafariz, calçamento com shader de pedra) | Mistura de low-poly e formas geométricas | EXISTENTE COM PENDÊNCIAS |
| Masmorra e ruína | 13 peças `d_*` (colunas, tochas, baús, ossos) | Low-poly | EXISTENTE |
| Cidades especiais | Árvore-Mãe, caverna, ilha, fundo do mar (`especial.gd`) | Geométrico | EXISTENTE COM PENDÊNCIAS |
| Interiores | 7 tipos de sala com planta (`interiores.gd`) | Geométrico | EXISTENTE COM PENDÊNCIAS |
| Água | Plano de água com material próprio (`world.gd::_build_water`) | Simples | EXISTENTE COM PENDÊNCIAS |
| Céu e clima | Shader de céu, ciclo de dia e noite, chuva, neve, folhas, cinzas, vaga-lumes por região (`atmos.gd`) | — | EXISTENTE |
| Iluminação | 1 sol com sombra por nível de qualidade; luz própria em caverna, fundo do mar e interiores; janelas acesas à noite | — | EXISTENTE COM PENDÊNCIAS |
| Pós-processamento | SSAO e brilho (qualidade ≥ 2); névoa volumétrica, SDFGI e SSIL só no renderizador Forward+ (qualidade ≥ 3) | — | EXISTENTE **[C]**: no notebook o jogo roda em OpenGL, onde névoa volumétrica, SDFGI e SSIL **não funcionam** |
| Efeitos | Partículas de CPU: explosão, projétil, aura, fogo, poeira; 64 habilidades sem efeito | Simples | EXISTENTE COM PENDÊNCIAS |
| Mapa ilustrado | `Valtheria_Mapa_Geral.png` (técnico, gerado dos dados) | Técnico | EXISTENTE (técnico) · artístico NÃO IMPLEMENTADO |
| Áudio | Nenhum no nativo; a web tem `sfx.js` | — | NÃO IMPLEMENTADO |

### 1.2 Sistemas de gameplay

| Sistema | Situação | Classificação |
|---|---|---|
| Câmera em 3ª pessoa | Orbital: giro com o mouse, distância de 2,2 a 40 m na roda, suavização, câmera presa dentro de interiores. **Colide só com o chão**: atravessa paredes e árvores (`main.gd` linhas 784–796) | EXISTENTE COM PENDÊNCIAS |
| Controles | Teclado e mouse: WASD, Shift, Ctrl, Espaço, 1–9, F1–F9 (atalhos), E (entrar), V (voar, GM), I, B, C, J, K, G, Tab, F, Enter, F10, F11. **Sem controle físico e sem toque** | EXISTENTE COM PENDÊNCIAS |
| Movimento | Andar, correr, disparada, pulo, nado sem animação, pisos elevados | EXISTENTE COM PENDÊNCIAS |
| Seleção de alvo | Clique, Tab (próximo) | EXISTENTE |
| Combate | Golpe automático, 18 habilidades por arquétipo, recargas, crítico, elementos, estados; dano calculado no cliente | EXISTENTE COM PENDÊNCIAS (servidor, `05`) |
| Retorno do combate | Número de dano, partículas; **sem som e sem tremor de câmera** | EXISTENTE COM PENDÊNCIAS |
| Missões | 63 no banco, **0 no nativo** | NÃO IMPLEMENTADO (nativo) |
| Grupo, guilda, comércio | Clã parcial; loja sim; mercado e grupo não | EXISTENTE COM PENDÊNCIAS / NÃO IMPLEMENTADO |
| Chefes, eventos | Chefes por região; sem eventos | EXISTENTE COM PENDÊNCIAS |
| Multiplayer | Vê outros jogadores e chat; monstros não compartilhados. **Não deve ser declarado concluído** (regra 9.5 do manual) | EXISTENTE COM PENDÊNCIAS |
| Coleta, fabricação, encantamento | Forja sim; coleta e encantamento só na web | EXISTENTE COM PENDÊNCIAS |

### 1.3 Interface

| Tela | Situação |
|---|---|
| Login, criação e seleção de personagem (com o personagem visível) | EXISTENTE |
| HUD | Barras de vida, mana, CP e experiência; alvo; efeitos; barra de atalhos; chat; painéis móveis e escala da interface. **Sem retrato, sem minimapa, sem rastreador de missão, sem quadro de grupo** |
| Janelas | `bolsa` (inventário com boneco e encaixes), `loja`, `oficio` (forja), `classe`, `cla`, `acoes`, `gm`. **Sem mapa-múndi, missões, habilidades, configurações** (a qualidade é trocada por tecla) |
| Inventário | Grade com ícone, grau e detalhe; **sem filtro, busca, comparação de atributos nem peso** |
| Identidade | Fonte Cinzel, painéis escuros translúcidos, ícones vetoriais próprios. É uma base coerente com "fantasia medieval discreta" |

---

## 2. Recursos aproveitáveis (manter e evoluir)

| Recurso | Por que manter |
|---|---|
| **Esqueleto único e as 28 animações** | Todos os corpos novos devem usar o mesmo esqueleto, e as animações continuam valendo |
| **Sistema de montagem do personagem** (`character.gd`: pele, cabelo, roupa, pegada de arma por osso) | Recebe modelos novos sem mudar a lógica |
| **Anão e Dragonita (Meshy)** | Os mais próximos do padrão semi-realista; servem de referência de detalhe |
| **Terreno, mapa de altura e ferramentas** (`ferramentas/*.py`) | Base do mapa; só melhoram as texturas |
| **Geração das cidades** (`cidade.gd`, `world.gd`) | Ruas, quarteirões, muralhas e NPCs ficam; os módulos geométricos são trocados aos poucos por peças modeladas (biblioteca modular, 4.3 do manual) |
| **Rotina dos NPCs, interiores, zonas de luz, clima, ciclo de dia** | Prontos; só precisam de arte e som |
| **5 níveis de qualidade** | Já preparados para placa forte e fraca |
| **Interface** (painéis móveis, Cinzel, boneco de equipamento) | Base da biblioteca de componentes |
| **90 modelos do nativo + cerca de 90 só na web** (incluindo `x_brute` para golem, `a_horse`/`a_stag` para montarias, `e_frog`/`e_rat`/`e_wasp`/`e_snake` para monstros pequenos) | Uso imediato sem custo, enquanto a arte nova é feita |
| **Servidor e banco** | Modelo de segurança correto; só precisa endurecer as funções (`05`) |

## 3. Recursos que precisam de melhorias

| Recurso | Melhoria para o padrão semi-realista | Tamanho |
|---|---|---|
| Corpos humanos e raças | Corpos semi-realistas no mesmo esqueleto; rosto definido; silhuetas de elfo, elfo negro, homem-fera, orc e gigante | Grande |
| Roupas e armaduras | Conjuntos por tipo e faixa de grau e por gênero; elmo, luvas, botas, ombreiras e capas visíveis | Grande |
| Armas | Formas por faixa de grau; punhos, garras, cajado e cetro próprios | Médio |
| Monstros com corpo humano | Golem, esqueleto, ent, demônio, dragão | Médio |
| Vegetação | Árvores e plantas com casca, folhas e variação; folhagem que balança com o vento (shader) | Médio |
| Construções | Biblioteca modular (paredes, telhados, portas, janelas, colunas, torres) por cultura: humana, élfica, anã, militar, rural | Grande |
| Terreno | Texturas de chão em alta, com mapa normal por bioma | Pequeno |
| Água | Ondas, reflexo, espuma na margem | Pequeno |
| Câmera | Colisão com paredes e árvores; aproximação suave em espaços fechados | Pequeno |
| Ícones | Um por item ou por tipo × faixa, em imagem | Médio |
| Efeitos | Biblioteca por elemento (preparação, projétil, impacto, estado) | Médio |
| Iluminação por região | Paleta e névoa próprias por bioma (hoje existem para caverna, fundo do mar e interior) | Pequeno |
| HUD e inventário | Retrato, minimapa, rastreador de missão, filtros e comparação | Médio |

## 4. Recursos ainda inexistentes

- Guardiões dos 6 fragmentos (modelo, arena, efeitos, som).
- Mapa-múndi e mapa regional dentro do jogo, com descoberta de áreas.
- Mapa artístico ilustrado.
- Áudio completo: ambiente, combate, música, interface.
- Animações de arco, lança, cajado, duas mãos, esquiva, queda, nado e montaria.
- Pets e montarias visíveis.
- Missões no nativo e o rastreador na tela.
- Grupo, guilda completa, mercado, PvP e cerco no nativo.
- Controle físico (gamepad).
- Biomas de **deserto** e **vulcão** de fato. Os nomes existem no mapa, mas não a paisagem. **Rios e lagos** também faltam (ver `03`).
- Tela de configurações.
- Guia de identidade visual (paleta, materiais, modelagem, iluminação, interface): é a **Fase 1 do manual**.

## 5. Dependências técnicas

```
Guia de identidade visual (paleta, materiais, escala, contagem de polígonos)
  ├─► Corpos semi-realistas no esqueleto atual ─► Roupas e armaduras ─► Ícones
  │                                        └─► Animações novas (arco, lança…)
  ├─► Armas ─► Ícones
  ├─► Monstros e guardiões ─► Efeitos de chefe
  └─► Biblioteca modular de construções ─► Cidades por cultura

Servidor endurecido (E1) ─► Missões no nativo ─► Rastreador no HUD
                       └─► Grupo ─► PvP ─► Cerco

Medição real no notebook (registro.txt) ─► Limites de polígonos e texturas do guia
Bíblia aprovada (D03–D07) ─► Guardiões e fragmentos
```

Pontos críticos:
1. **Orçamento de desempenho antes da arte.** Modelos semi-realistas pesam mais. Hoje o jogo já usa 251 MB de texturas e 760–924 chamadas de desenho (`09`). Sem medir o notebook (D18), não dá para fixar o limite de polígonos do guia.
2. **Mesmo esqueleto.** Todo corpo novo precisa usar os ossos atuais, ou as 28 animações e a pegada de armas deixam de funcionar.
3. **Renderizador.** Se o jogo roda em OpenGL no seu notebook, os efeitos de luz mais bonitos (SDFGI, névoa volumétrica) ficam fora. Isso define até onde o "cinematográfico" pode ir. **[C]**
4. **Licenças.** Meshy gratuito = CC BY 4.0 (crédito obrigatório). Pacotes CC0 só com a licença conferida. Imagens do Gemini são **referência**, não modelo (regra 15 do manual).
5. **Créditos de geração.** Meshy com cerca de 41 créditos: dá para poucos modelos. Priorizar os que o jogador vê sempre.

## 6. Prioridades

| Ordem | O quê | Por quê |
|---|---|---|
| 1 | **Servidor (E1)** + testes automáticos | Protege os dados antes de crescer o conteúdo; independe da arte |
| 2 | **Guia de identidade visual** (Fase 1 do manual) + medição no notebook | Sem ele, cada modelo novo sai num estilo diferente |
| 3 | **Personagem jogável** (corpo semi-realista nas 8 raças + roupas por tipo) | É o que o jogador vê o tempo todo |
| 4 | **Armas** e **monstros com corpo humano** | Grande ganho visual com pouco risco; os monstros usam o que já temos |
| 5 | **Câmera** (colisão) + **HUD** (retrato, minimapa, missões) | Jogabilidade em 3ª pessoa conforme o manual |
| 6 | **Missões no nativo** | Dá propósito à exploração |
| 7 | Vegetação, terreno, água, iluminação por bioma | Ambientação |
| 8 | Construções modulares por cultura | O maior volume de arte; vem depois do guia e dos personagens |
| 9 | Guardiões, efeitos, áudio | Dependem da Bíblia e da biblioteca de efeitos |
| 10 | Otimização com métricas antes e depois | Contínua, a cada etapa |

## 7. Plano de execução

Seguindo as fases do manual (seção 16) e o `10_Roadmap_Execucao.md`:

| Etapa | Entrega | Altera o jogo? | Aprovação |
|---|---|---|---|
| **V0** | Esta auditoria | Não | Concluída |
| **V1 — Guia de identidade visual** | Paleta por região, biblioteca de materiais (ferro, aço, prata, ouro, madeira, couro, pedra, cristal, tecido), padrão de modelagem (altura, polígonos, texturas, esqueleto), padrão de luz, padrão da interface | Não (documento + pranchas) | D31, D32 |
| **V2 — Prova de conceito** | **1 personagem** (humano, homem e mulher) semi-realista no esqueleto atual, com 1 armadura e 1 espada, lado a lado com o atual, **medido** (polígonos, texturas, chamadas de desenho) | Só numa ramificação de teste | Você aprova o visual e o custo |
| **V3 — Personagens** | 8 raças × 2 gêneros; roupas por tipo; animações novas | Sim, por etapas | Por raça |
| **V4 — Equipamentos** | Armas por faixa; ícones | Sim | Por tipo |
| **V5 — Criaturas e guardiões** | Monstros + 6 guardiões | Sim | Depende da Bíblia |
| **V6 — Gameplay e interface** | Câmera, HUD, mapa-múndi, missões, inventário | Sim | Por tela |
| **V7 — Mundo** | Vegetação, terreno, água, iluminação por bioma, rios e lagos, construções modulares | Sim | Por região |
| **V8 — Efeitos, áudio, otimização** | Biblioteca de efeitos, som, métricas antes e depois | Sim | Por etapa |

Cada etapa segue o fluxo A–G do manual (análise → referência → especificação → produção → integração → validação → documentação) e o modelo de relatório do `10`.

**O ponto de decisão mais importante é a V2:** um único personagem semi-realista medido no jogo real mostra, antes de produzir em quantidade, se o estilo cabe no desempenho do notebook.

---

## 8. Conflitos com documentos anteriores

| # | Conflito | Situação |
|---|---|---|
| CV1 | O padrão de arte anterior do projeto dizia "anime semi-realista, cel-shading". O manual novo diz "fantasia semi-realista, iluminação cinematográfica" | Precisa de decisão (D31) |
| CV2 | Assets atuais low-poly (Quaternius) × padrão semi-realista | Troca gradual (V3–V7); os atuais ficam até haver substituto testado |
| CV3 | Manual 13.3 sugere a pasta `assets/characters/…`; o projeto usa `assets/chars`, `assets/armas`, `assets/world` | Proposta: manter as pastas atuais e criar subpastas novas só para recursos novos, sem mover os existentes |
| CV4 | Manual 3.4 lista deserto e vulcão; o mapa tem só os nomes | Já registrado em `03` (M1–M7) |

## 9. Decisões novas
- **D31:** estilo oficial. Opções:
  - (a) fantasia semi-realista "pura", com textura PBR e luz realista;
  - (b) semi-realista **estilizado**, com proporção real, rosto definido, textura pintada e sombreamento suave. É o caminho mais leve e combina com o que o Meshy já gera.
  - Recomendo (b), validado na V2.
- **D32:** aprovar a etapa V2 (um personagem de prova, medido) antes de produzir em quantidade.
- **D33:** gamepad entra no plano agora ou depois do HUD?
