# VALTHERIA — Plano Mestre de Produção Visual

**Direção aprovada:** fantasia semi-realista estilizada.
**Documentos ligados:**
- `VALTHERIA_INVENTARIO_ASSETS.md`: o que existe e a matriz de lacunas.
- `VALTHERIA_PIPELINE_3D.md`: como se produz.
- `VALTHERIA_PADRAO_TECNICO_ASSETS.md`: números, nomes e pastas.
- `VALTHERIA_PLANO_PROTOTIPOS.md`: o que se constrói primeiro.

Este documento junta direção de arte, criaturas, mundo, gráficos, fases, custos, riscos e decisões. Os detalhes ficam nos documentos ligados, sem repetição.

---

## 1. Direção de arte consolidada

**Em uma frase:** corpos e objetos com proporção e peso reais, superfícies pintadas (forma clara, pouco ruído fotográfico) e cor contida, com a cor forte reservada à magia e à identidade de cada povo.

| Pilar | Na prática | Como verificar |
|---|---|---|
| Proporção real | Humano de 1,80/1,68 m, cerca de 7,5 cabeças; armas no tamanho da tabela `GRIP` | Medição no Blender e no Godot |
| Silhueta por raça | Cada raça reconhecível só pelo contorno a 30 m: orelha élfica, presa e ombro orc, cabeça animal do homem-fera, largura do anão, altura do gigante | Prancha em silhueta preta |
| Superfície pintada | Texturas CC0 repintadas: menos poros e manchas, mais leitura de forma e desgaste nas bordas | Comparação lado a lado com a foto original |
| Paleta oficial | Saturação até 70% fora dos efeitos; tecidos com a cor da cultura em até 25% da roupa; metais por grau (Guia V1, §2) | Conta-gotas na prancha |
| Luz | Sol com cor por hora e região; névoa de profundidade; sem contorno preto | Mesma cena em 3 horas do dia |
| Magia com identidade | Cores dos elementos de `fx.gd`; formas de runa da Árvore | Prancha de efeitos |
| Variedade sem repetir | Um modelo com variações de material, ornamento e escala, em vez de dezenas de modelos isolados | Contagem de "pares iguais" numa cena da cidade |

**Evitar:** cel-shading, contorno preto, aspecto plástico, saturação alta, brilho excessivo, cópia de jogos existentes e roupas modernas (as roupas CC0 do MakeHuman só servem de base para remodelar).

---

## 2. Criaturas e chefes: estratégia contra a repetição

**Hoje** (inventário §4): 12 das 18 famílias são humanoides recoloridos ou outra espécie (touro como javali, dinossauro como homem-lagarto).

**Regra:** uma família = um modelo próprio + um esqueleto + 6 animações. Variações regionais vêm de material, peças e escala. Chefe = família + peças exclusivas + animação exclusiva + efeito.

| Família | Conceito (silhueta, material, comportamento) | Necessidade técnica | Prioridade |
|---|---|---|---|
| Javali / Rei Javali | Corpo baixo e pesado, cerdas, presas curvas; o Rei com placas de casca e brasas da aurora | Modelo + rig quadrúpede | 1 (P6/P8) |
| Lobo / Lobo Espectral | Já tem modelo; o espectral ganha material translúcido de névoa e olhos acesos | Só material e efeito | 2 |
| Aranha / Rainha Aracnídea | Rainha com abdômen ornamentado, coroa de quitina e teias de luz | Peças exclusivas + escala | 3 |
| Orc Bandido | Deve usar a raça orc nova (quando existir), com roupa de saqueador | Depende da raça orc | 4 |
| Golem / Golem Ancestral | Blocos de pedra com veias de metal; o Ancestral com runas da Forja | Modelo próprio + rig simples | 2 (P7) |
| Esqueleto Guerreiro | Esqueleto humano com armadura enferrujada (mesmo esqueleto de 65 ossos: usa as animações atuais) | Malha própria no esqueleto do jogo | 3 |
| Ent / Ent Milenar | Tronco com casca, galhos como braços, musgo; o Milenar com flores de luz | Modelo + rig próprio | 3 |
| Demônio / Senhor Demônio | Pele de brasa, chifres, asas rasgadas; o Senhor maior e com coroa de fogo | Modelo + rig | 4 |
| Lagarto Guerreiro | Homem-lagarto bípede (hoje é um dinossauro) | Malha própria no esqueleto do jogo | 4 |
| Dragonete / Dragão Celeste | Dragão próprio (hoje é a raça jogável Dragonita): quadrúpede alado | Modelo + rig + voo | 5 |
| Cavaleiro Caído | Armadura negra do P4 com material corroído | Reaproveita o P4 | 3 |

**Os seis guardiões dos fragmentos** (Bíblia, §6) já são os chefes do banco:
- Rei Javali (Aurora);
- Rainha Aracnídea (Tecer);
- Golem Ancestral (Forja);
- Ent Milenar (Raiz);
- Senhor Demônio (Chama);
- Dragão Celeste (Céu).

Cada um recebe a cor do seu fragmento, uma silhueta exclusiva e uma arena na sua região. **Nenhum modelo existente é substituído na `main`.**

---

## 3. Produção do mundo

| Ambiente | O que já existe | Evolução proposta |
|---|---|---|
| Florestas e campos | Terreno, grama, 30 plantas | Árvores em 3 tamanhos com LOD; 6–8 camadas de terreno; flores e arbustos por região |
| Montanhas | Relevo do `height.bin` | Rochas grandes modulares; textura de rocha com normal |
| Desertos / vulcânico | Tinta por região | Kit de rochas vermelhas, cinzas e lava (Cidadela Rubra) |
| Gelo | Rochas e arbusto com neve | Kit de gelo; neve no terreno por altura |
| Cidades | Caixas geradas por `cidade.gd` | **Módulos em grade de 2 m** trocando as caixas, mantendo o desenho das ruas e quarteirões |
| Vilas | 12 prédios Quaternius | Kit modular por cultura |
| Portos | Cais e farol de caixas | Módulos de madeira e pedra |
| Castelos | Caixas | Muralha e torre modulares (os 3 castelos do banco) |
| Masmorras, cavernas, ruínas | Adereços soltos | Kit de corredor/sala modular; uma masmorra-modelo |
| Rios e lagos | Shader de água | Margem com transição úmida; espuma na borda |
| Áreas mágicas e regiões dos guardiões | Não existem | Uma arena por guardião, com luz e efeitos próprios |

**Reutilização sem repetição:** mesmos módulos com materiais diferentes por cultura, tinta de vértice, decalques de sujeira e musgo, e rotação e escala aleatórias na dispersão.

---

## 4. Avaliação técnica do Godot (resumo)

| Ponto | Situação | Recomendação |
|---|---|---|
| Renderizador Forward+ e 5 níveis gráficos | Bom e completo (FSR, MSAA, sombra, SSAO, brilho, névoa, SDFGI) | Manter; acrescentar LOD e distância de desenho por nível |
| Sombra dobra os triângulos | Medido (317 → 705 mil) | Malhas de sombra simplificadas; sombra só até a distância do nível |
| Mundo inteiro carregado | Nós iguais em todas as cenas (doc 09) | Carregar por região (fase 8) |
| Sem oclusão | Confirmado | `OccluderInstance3D` nas muralhas e prédios grandes |
| Sem LOD nos modelos | Confirmado | LOD automático na importação + conferência |
| Armas com 3–5 materiais | Medido | 1 material por arma (−2 a −4 chamadas por personagem armado) |
| Compressão para celular | Não validado | Teste ASTC num celular antes da fase 8 |

---

## 5. Benchmark e níveis gráficos

**Plano no notebook real** (a ferramenta `testes/benchmark.gd` já existe na branch `v2-prova-visual`):

| Cena | Variantes |
|---|---|
| Campo aberto | 20 e 40 personagens: atuais × V3 completos (corpo + roupa + armadura + arma) |
| Capital | Mesmo, dentro da cidade, com vegetação e luz da tarde |
| Efeitos | 10 magias simultâneas |
| Níveis | Mínima, Baixa, Média, Alta e Ultra |

**Medir:** FPS médio, 1% baixos, tempo de quadro, chamadas de desenho, triângulos, memória de vídeo, memória total, tempo de carregamento e estabilidade (10 minutos sem travar).
**Regra:** resultado de renderização por software **não** é usado como FPS.

**Níveis gráficos sem perder a identidade:** o que cai nos níveis baixos é distância, densidade e resolução. **Nunca** cai a silhueta, a paleta ou a textura de cor dos personagens.

| Nível | Personagens | Mundo | Efeitos |
|---|---|---|---|
| Mínima | LOD1 a partir de 10 m, sombra só do sol perto | Vegetação a 40%, sem grama distante | Partículas a 40% |
| Baixa | LOD1 a partir de 20 m | Vegetação a 60% | 60% |
| Média | LOD1 a partir de 35 m | 80%, SSAO | 80% |
| Alta | LOD1 a partir de 50 m | 100%, névoa volumétrica | 100% |
| Ultra | LOD1 a partir de 70 m | 100%, SDFGI | 100% |

As distâncias acima são **metas iniciais** e serão ajustadas pelo benchmark.

---

## 6. Fases, entregas e critérios

| Fase | Entregas | Depende de | Concluída quando |
|---|---|---|---|
| **0 — Auditoria e preparação** | Estes 6 documentos; branch `v3-prototipos`; ferramenta de medição | — | Robson aprovar o plano |
| **1 — Identidade visual e padrões** | Prancha de estilo (pele, tecido, metal, pedra, madeira) com texturas CC0 repintadas; paleta aplicada; padrão técnico revisado | Fase 0 | Prancha aprovada |
| **2 — Personagens** | P1, P2, P3; depois as raças na ordem do pipeline (§2.1) | Fase 1 | 28 animações sem regressão; benchmark no notebook dentro do limite fixado |
| **3 — Equipamentos** | P4, P5; padrão de graus; depois as famílias de arma | Fase 2 (P1) | Encaixe nas 8 raças; graus distinguíveis a 10 m |
| **4 — Criaturas e chefes** | P6, P7, P8; depois as famílias da tabela §2 | Pipeline de criatura | 6 animações por família; silhueta a 30 m |
| **5 — Ambientes** | P9, P10; kits por cultura; arenas dos guardiões | Fase 1 | Antes/depois aprovado com chamadas de desenho iguais ou menores |
| **6 — Efeitos e iluminação** | Perfis de luz por região; magias com identidade | Fases 2–5 | Prancha de efeitos aprovada |
| **7 — Interface** | Ícones ilustrados dos itens (começando pelos protótipos) | Fase 3 | Ícones legíveis a 48 px |
| **8 — Otimização e integração** | LOD, oclusão, carregamento por região, compressão para celular; **integração na `main` só com autorização** | Todas | Benchmark aprovado nos 5 níveis |

**Cronograma** (em sessões de trabalho, mais o tempo de avaliação do Robson):

| Fase | Sessões estimadas |
|---|---|
| 0 | Esta entrega |
| 1 | 1–2 |
| 2 (só P1–P3) | 5–6 |
| 3 (P4–P5) | 3–4 |
| 4 (P6–P8) | 7–8 (javali 2, golem 2–3, Rei Javali 3) |
| 5 (P9–P10) | 5–7 |
| Raças 2 a 6, famílias e kits | Planejar depois da Etapa 1, com o ritmo medido |

---

## 7. Recursos e custos

| Item | Custo | Observação |
|---|---|---|
| Blender, Godot, MPFB2, Krita, Material Maker, Instant Meshes | R$ 0 | Programas livres |
| MakeHuman CC0, Quaternius CC0, Poly Haven CC0, ambientCG CC0 | R$ 0 | Licença conferida item a item no `CREDITOS.md` |
| Meshy (opcional) | Plano grátis: 100 créditos/mês, saída CC BY 4.0 (com atribuição). Pro: a partir de US$ 20/mês, 1.000 créditos, saída privada | Só para criaturas, cabeças de raça e guardiões; orçamento por protótipo no pipeline (§1). **Nenhum uso sem autorização** |
| Notebook do Robson | — | Necessário para o benchmark real |

**Onde vale pagar, se um dia for preciso:** o Meshy Pro, só se o volume de criaturas e guardiões ultrapassar o plano grátis, e para não depender de atribuição CC BY. Nada mais é necessário para esta etapa.

---

## 8. Riscos

| Risco | Tipo | Efeito | Mitigação |
|---|---|---|---|
| Personagem completo pesado demais para o notebook | Técnico | FPS baixo com 40 personagens | Benchmark antes de expandir; LOD; materiais mínimos |
| Roupa ou armadura atravessando o corpo | Técnico | Visual quebrado em animação | Máscara de corpo sob a roupa (já feito na V2); teste nas 28 animações |
| Placas rígidas deformando | Técnico | Armadura "derretendo" no ombro | Placas presas a um osso só + juntas de couro |
| Texturas CC0 com aspecto fotográfico | Artístico | Mistura de estilos | Repintura e prancha de estilo na fase 1 |
| Mistura de origens (Quaternius, Meshy, MPFB, própria) | Artístico | Jogo sem identidade | Toda peça nova passa pela prancha de estilo; material e paleta únicos |
| Raças não humanas com custo alto (homem-fera) | Custo/prazo | Atraso | Ordem de produção (§2.1 do pipeline); Meshy opcional |
| Licença mal conferida | Legal | Asset retirado depois | Licença registrada antes de qualquer commit |
| Mundo inteiro carregado | Técnico | Memória e tempo de carga crescem com assets melhores | Carregamento por região na fase 8 |
| Animações novas (arco, cajado, lança) | Técnico | Combate visualmente limitado | Arquivo `anims_c.glb` com retarget; nunca alterar as 28 oficiais |

---

## 9. Critérios de aprovação (para qualquer protótipo)

1. Licença conferida e registrada.
2. Escala e pivô no padrão.
3. Prancha frente/lado/costas aprovada pelo Robson.
4. Nenhuma das 28 animações pior que o modelo atual (métrica de deformação).
5. Triângulos, materiais e chamadas de desenho medidos e dentro da meta inicial, ou com a diferença justificada.
6. Benchmark no notebook (quando o protótipo afetar personagens ou cidades).
7. Nada na `main`; nenhum arquivo oficial substituído.

---

## 10. Recomendações de prioridade

1. **Humano masculino e feminino completos (P1/P2) com roupa de fantasia:** destrava todo o resto.
2. **Espada (P5)** junto, porque é barata e valida o padrão de graus.
3. **Benchmark no notebook** assim que P1/P2 existirem: só então fixar os limites.
4. **Armadura (P4):** resolve a maior repetição do jogo (332 itens, 15 malhas).
5. **Javali e Rei Javali (P6/P8):** primeira família própria e primeiro guardião, com uma só base.
6. **Clareira (P9)** e depois o quarteirão da capital (P10).
7. Só depois: raças 2 a 6, demais famílias e kits de cidade.
