# Relatório do primeiro marco V3: P1, P2 e P5

Data: 15/11/2026. Autorização: D50 a D57.
Branch isolada: `v3-prototipos`, commit `943995a`, criada a partir da main `29d9507`. A main não foi alterada e não houve merge.
Situação: **concluído e parado, aguardando a avaliação de Robson.**

## 1. O que foi construído

| Protótipo | Conteúdo |
|---|---|
| **P1 humano masculino** | Corpo V2 de 1,80 m, rosto, pele pintada, olhos castanhos, sobrancelha, cílios, cabelo curto, túnica de linho com barra azul, punhos e gola com cordão, cinto de couro, calça com remendos no joelho, botas com tira e fivela |
| **P2 humana feminina** | Corpo de 1,68 m, olhos verdes, cabelo longo trançado, túnica verde-acinzentada, a mesma família de calça, cinto e botas |
| **P5 espada longa** | Pomo em forma de semente, cabo de couro com raízes e guarda de galhos com folhas. O medalhão tem a Árvore em relevo nas duas faces. Lâmina em losango com sulco. Três graus: D (simples), B (mais folhas) e S (folhas e runas com brilho). 1 material, 1,00 m de comprimento e guarda de 0,27 m |

Todas as peças usam o esqueleto oficial de 65 ossos, com os mesmos nomes e rotação de repouso idêntica (diferença 0,0°). Cada vértice tem até 4 influências e os pesos estão normalizados. As peças são montadas pelo mesmo método do `character.gd`. Nenhum modelo nem animação oficial foi substituído.

## 2. Os 17 critérios

| # | Critério | Resultado | Evidência |
|---|---|---|---|
| 1 | Prancha frontal | Feita (aldeão atual, P1 e P2 lado a lado) | `evidencias/marco1/folha_pranchas.jpg` |
| 2 | Prancha lateral | Feita | mesma folha |
| 3 | Prancha traseira | Feita (a trança aparece inteira) | mesma folha |
| 4 | Capturas no Godot | 78 capturas no Godot 4.7.2, renderizador de compatibilidade | `folha_*.jpg` |
| 5 | Comparação com os modelos atuais | Mostrada na prancha e com números (abaixo) | `resultado_medidas.json` |
| 6 | As 28 animações | 28 de 28 rodam nos dois sexos | `folha_anim_m.jpg`, `folha_anim_f.jpg` |
| 7 | Deformações | Estiramento p99 de 1,52 a 1,97 no V3, contra 3,07 a 3,56 na roupa atual | `anim_*.json` |
| 8 | Atravessamentos | Botas/calça 0%. Cabelo/corpo até 0,82%. Túnica/corpo até 2,41%. Túnica/calça: pior quadro 4,35% (m) e 11,11% (f) | `anim_*.json` |
| 9 | Triângulos | Arquivo: P1 27.150, P2 29.236, espada 1.772 a 1.916. Desenhados no Godot: V3 ≈17,3 mil e atual ≈18,2 mil | json |
| 10 | Materiais | V3: 8 (pele, olhos, sobrancelha, cílios, cabelo, túnica, calça, botas). Espada: 1 | — |
| 11 | Chamadas de desenho | Por personagem: atual 10, V3 8, V3 com espada 9. Com 20 personagens: atual 1.167, V3 727. Com 40: atual 2.324, V3 1.440 | medidas e benchmark |
| 12 | Memória de texturas | Acima da cena vazia: atual 48,5 MB, V3 29,4 MB, com espada +2 MB | `resultado_medidas.json` |
| 13 | Compatibilidade da espada | Funciona na mão (pegada GRIP `len 1.0 at 0.1`), nas costas e na cintura, nos três graus | `folha_espada.jpg` |
| 14 | Fontes e licenças | Ver a seção 4 | `CREDITOS.md` |
| 15 | Arquivos novos | Ver a seção 5 | — |
| 16 | Antes e depois | Prancha frontal: o aldeão atual à esquerda | `folha_pranchas.jpg` |
| 17 | Problemas conhecidos | Ver a seção 6 | — |

**Benchmark (D56).** O executável e as instruções foram entregues em `Downloads\Valtheria-V3-benchmark`. O ensaio rodado aqui usou renderização por software (llvmpipe), por isso **o FPS dele não representa desempenho real e não é apresentado**. Desse ensaio só valem as contagens, que não dependem da placa de vídeo:
- Com 20 e 40 personagens, o V3 faz cerca de 38% menos chamadas de desenho.
- Mas o V3 desenha de 24% a 30% mais triângulos (inclui a passada de sombra), porque o corpo MakeHuman é mais denso.
- Os limites de FPS e de polígonos ficam para depois do resultado do notebook.

## 3. Testes executados

- Ligação ao esqueleto: 65 ossos, diferença de rotação de repouso 0,0°, até 4 influências por vértice.
- `testar_animacoes.py`: 28 animações, 3 quadros cada. Mede o estiramento de arestas e os atravessamentos entre pares de peças, no V3 e no aldeão atual.
- Godot, modo medidas: chamadas de desenho, triângulos, objetos e memória de texturas.
- Godot, modo capturas: pranchas, rostos, as 28 animações por sexo, a espada em 5 situações nos 3 graus, e detalhe da mão.
- Benchmark: 7 cenários rodados de ponta a ponta a partir do pacote exportado (só ensaio de funcionamento). O SHA-256 do exe entregue confere com o gerado.

## 4. Licenças verificadas

- **MakeHuman system assets: CC0 1.0.** Corpo, olhos, sobrancelhas, cílios e cabelos. Evidência: `fontes/makehuman_system_assets_LICENCA.txt`.
- **MPFB2: GPL 3.0.** Usado só como ferramenta no Blender; nenhum código dele entra no jogo.
- **Túnica, calça, botas, espada e texturas: criação própria** por script.
- **Animações:** as 28 oficiais já existentes (Quaternius, CC0), sem alteração.
- Tudo foi registrado em `CREDITOS.md`. Meshy, Mixamo e ferramentas pagas não foram usados.

## 5. Arquivos novos (74, todos na branch `v3-prototipos`)

- `cliente-godot/assets_v3/personagens/`:
  - `pc_humano_m.glb` e `pc_humano_f.glb`
  - `rp_aldeao_tunica_{m,f}`, `rp_aldeao_calca_{m,f}` e `rp_botas_couro_{m,f}`
  - `ca_curto_01` e `ca_tranca_longa`
  - `ligacao_*.json`
- `cliente-godot/assets_v3/equipamentos/`: `wp_espada_longa_{d,b,s}.glb`, texturas `tx_*` e `espada_longa.json`.
- `cliente-godot/ferramentas/v3/`: `vestir_v3.py`, `ligar_pecas.py`, `espada_v3.py`, `testar_animacoes.py`, `prancha.py` e `gltf_io.py`.
- `cliente-godot/testes/prototipos/`: `p1_humano.gd/.tscn`, `benchmark_v3.gd/.tscn` e `LEIA-ME_BENCHMARK.txt`.
- `fontes/`: `personagens/texturas/pele_humano_{m,f}.png` e `makehuman_system_assets_LICENCA.txt`.
- Arquivos `.import` gerados pelo Godot para os itens de `assets_v3`.
- Arquivo existente alterado: só `CREDITOS.md`, com 6 linhas acrescentadas no fim.

## 6. Problemas conhecidos

1. **Pontas claras na barra da túnica, no centro da frente, com o personagem em pose.** Aparece no Godot com Idle, nos dois sexos. A malha em repouso está limpa. A causa provável é o peso da saia, herdado das coxas, que levanta o centro da frente. Correção prevista: suavizar os pesos da barra ou cortar a faixa entre as pernas.
2. **Túnica atravessa a calça no P2:** até 11% dos vértices externos da barra, só em Jog, Sprint, Sword_Regular e Sitting. No P1 o máximo é 4,35%.
3. **O busto do P2 fica muito marcado na túnica.** Falta folga no tecido.
4. **Os rostos são neutros e pouco estilizados**, ainda longe do anime semi-realista da direção de arte.
5. **O relevo da Árvore no medalhão da espada quase não aparece** na distância normal de jogo.
6. **A espada na cintura fica muito projetada para trás** em poses de guarda. A bainha usa a mesma regra do jogo, ainda sem ajuste para lâmina de 1 m.
7. **O corpo V3 é mais denso que o atual** (cerca de 15,7 mil triângulos só no corpo). Para multidões precisará de LOD próprio, a confirmar no benchmark real.
8. **Os fontes `.blend` não foram salvos.** Os scripts em `ferramentas/v3` geram tudo de novo de forma idêntica.

## 7. Animações CC0 (D57, só pesquisa)

- **Quaternius Universal Animation Library 1 e 2.**
  - Licença CC0. A UAL 2 saiu em janeiro de 2026 com mais de 130 animações, e a versão gratuita traz cerca de 70% delas.
  - Usam o mesmo rig das 28 animações oficiais, então a compatibilidade é direta.
  - Cobrem combos corpo a corpo, locomoção, parkour e pulo.
  - As páginas não dizem se há arco, lança, cajado, adagas duplas ou esquiva. A lista quadro a quadro está no visualizador do site, que precisa de aprovação para ser aberto. Fica pendente.
- **Kevin Iglesias, Human Archer Animations FREE:** tem animações de arco, mas a licença não é CC0. Conferir antes de qualquer uso.
- **Mixamo (Adobe):**
  - Uso comercial gratuito e sem royalties, inclusive em jogos.
  - É proibido redistribuir os arquivos brutos ou revendê-los como asset.
  - Ponto de atenção: o jogo empacota as animações dentro do executável, o que é permitido. Mas o repositório é público, então colocar os FBX/GLB do Mixamo no Git seria redistribuição.
  - Recomendação: não usar Mixamo enquanto o repositório for público.

## 8. Custo efetivo

R$ 0,00. Créditos Meshy usados: 0. Nada foi comprado.

## 9. Próximo marco recomendado

1. Robson roda o benchmark no notebook e envia o `.csv`.
2. Correções no P1/P2: barra da túnica, folga no busto, rosto estilizado e LOD do corpo.
3. Baixar a UAL 2 (CC0) e listar as animações de arco, lança, cajado, adagas, esquiva e pulo, com teste no rig.
4. Só depois: P3, P4, P6 e P9, conforme a autorização.
