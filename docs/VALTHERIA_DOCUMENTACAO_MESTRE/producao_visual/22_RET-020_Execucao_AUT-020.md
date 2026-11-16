# RET-020 — Relatório de execução da AUT-020

- **Projeto:** Valtheria — A Árvore dos Mil Mundos
- **Data:** 15/11/2026
- **Referências:** AUT-020, PAR-020, RET-019, SOL-019
- **Situação:** execução concluída dentro do escopo. **Parado, aguardando a avaliação da Coordenação Técnica e a decisão de Robson.**
- **Homologação:** este relatório não homologa os modelos e não os integra ao jogo.

---

## 1. Branch e commits

| Item | Valor |
|---|---|
| Branch | `v3-prototipos` (isolada; a `main` continua em `29d9507`) |
| Base confirmada | contém `29d9507` e o marco `943995a` (verificado com `git merge-base --is-ancestor`) |
| **Commit de segurança** | **`e481ede6cdb02149a5259f870aacee39ac41c66d`**: commit vazio e identificável, com a árvore de arquivos idêntica à de `943995a`. Foi criado e enviado ao GitHub **antes** de qualquer regravação. |
| Etiqueta local | `v3-marco1-seguranca`, apontando para o commit de segurança. O envio da etiqueta ao GitHub foi recusado pelo proxy desta sessão; o commit em si está no GitHub. |
| Teste de recuperação | `git archive` do commit de segurança comparado com `943995a`: 1.008 arquivos idênticos. Para restaurar qualquer arquivo: `git checkout e481ede -- <caminho>`. |
| **Commit da AUT-020** | **`c9a520aa6212ab1f6379f9a14ed64f2e44a76072`**, publicado no GitHub na branch `v3-prototipos` |

## 2. Arquivos criados e modificados

Todos estão em `cliente-godot/assets_v3/`, `cliente-godot/ferramentas/v3/`, `cliente-godot/testes/prototipos/` e `fontes/`. Nenhum arquivo oficial do jogo foi alterado: `assets/` e `scripts/` estão idênticos a `29d9507`, e `CREDITOS.md` não mudou nesta etapa.

**Modificados (regravados no mesmo nome, opção A):**

| Arquivo | O que mudou |
|---|---|
| `ferramentas/v3/vestir_v3.py` | Pesos da saia, forro, folga, abertura, blusado, calça até o quadril, queda do busto, LOD da trança, bake determinístico, ordem fixa, `.blend` |
| `ferramentas/v3/espada_v3.py` | Medalhão de 64 mm, Árvore em silhueta, mapa de metal e rugosidade, brilho S, bainha no `.json`, bake determinístico |
| `ferramentas/v3/testar_animacoes.py` | Contagem absoluta; saia contra o volume da coxa; fator do quadril corrigido |
| `assets_v3/personagens/rp_aldeao_tunica_{m,f}.glb`, `rp_aldeao_calca_{m,f}.glb`, `rp_botas_couro_{m,f}.glb`, `ligacao_pc_humano_{m,f}.json` | Versões corrigidas |
| `assets_v3/equipamentos/wp_espada_longa_{d,b,s}.glb`, `tx_espada_longa_*.png`, `espada_longa.json` | Versões corrigidas |
| `.import` correspondentes | Regenerados pelo Godot |

**Sem mudança de bytes** (o gerador determinístico reproduziu o marco 1): `pc_humano_{m,f}.glb`, `ca_curto_01.glb`, `ca_tranca_longa.glb`.

**Criados:**

| Arquivo | Conteúdo |
|---|---|
| `assets_v3/personagens/ca_tranca_longa_lod1.glb` | LOD manual da trança, 799 triângulos |
| `assets_v3/equipamentos/tx_espada_longa_{d,b,s}_metal.png` | Mapa de metal e rugosidade, 1 por grau |
| 20 imagens `*_0.png`, `*_1.png`… | Texturas que faltavam para os `.import` existentes |
| 4 imagens extraídas novas | Do LOD da trança e dos mapas de metal da espada, cada uma com seu `.import` |
| `ferramentas/v3/testar_bainha.py` | Teste da espada na cintura nas 28 animações |
| `ferramentas/v3/testar_animacoes_base.py` | Funções comuns dos testes |
| `ferramentas/v3/rosto_ab.py` | Gerador da prancha facial (só proposta) |
| `testes/prototipos/marco1_correcoes.gd` e `.tscn` | Cena antes × depois e medidas no Godot |
| `fontes/personagens/pc_humano_m.blend` e `pc_humano_f.blend` | Fontes editáveis, 12,1 MB e 13,0 MB, imagens embutidas |
| `fontes/v3_receita.json` | Versões, comandos e hashes das saídas |

**Diferença em relação a `943995a`:** 74 arquivos (`git diff --stat 943995a c9a520a`): 29 alterados e 45 novos.

## 3. Correções executadas e evidências antes × depois

As evidências estão em `evidencias/ret020/`. Todas as capturas são do Godot 4.7.2.

### 3.1 Barra das túnicas (3.1)

**Causa confirmada:** havia uma troca brusca de peso entre a coxa esquerda e a direita no centro da barra. As faces que atravessavam o centro esticavam em pose e apareciam como pontas claras. O RET-019 supunha faces internas entre as pernas, mas a medição mostrou que **não havia nenhuma** (zero faces voltadas para dentro). A causa real era o estiramento.

O que foi feito:
- A parte das coxas no peso da saia passou a ser repartida em gradiente pelo centro (±5 cm), sem troca brusca.
- A saia segue as coxas em até 95% na barra, e a parte da bacia é mantida perto do cinto.
- Os pesos foram suavizados em 3 passadas, com até 4 influências por vértice, normalizadas.
- Forro interno escuro na mesma malha e no mesmo material (saia, gola e punhos): 1.058 triângulos no P1 e 1.036 no P2, sem chamada de desenho extra.
- Material com uma face só.

**Resultado:** nenhuma ponta clara e nenhum avesso visível nas capturas de frente, lado e de baixo dos dois personagens (`01_barra_antes_depois.jpg`). As 28 animações estão em `05_` e `06_`. **Aprovado.**

### 3.2 Atravessamentos (3.2)

O que foi feito:
- Folga da barra de 8 para 15 mm, crescendo da cintura até a barra.
- Abertura da saia aumentada: largura de +10% para +13% e profundidade de +24% para +28%.
- Tecido blusado na frente, sob o cinto: até +15 mm.
- Calça até o quadril.
- Pesos ajustados conforme o item 3.1.

**Métrica nova:** conta, em número absoluto, os vértices da face externa da saia que entram mais de 3 mm na coxa vestida. A coxa é a superfície da calça posada na mesma animação e no mesmo quadro. São 28 animações × 3 quadros = 84 quadros por personagem.

| | P1 antes | P1 depois | P2 antes | P2 depois |
|---|---|---|---|---|
| Vértices de saia testados | 280 | 287 | 225 | 234 |
| Quadros acima de 1% (de 84) | 16 | **14** | 83 | **19** |
| Animações sem nenhum quadro acima de 1% (de 28) | 18 | 18 | 0 | 17 |
| Pior quadro | OverhandThrow, 50 vértices (17,9%) | OverhandThrow, 44 (15,3%) | Sitting, 45 (20,0%) | Sitting, 38 (16,2%) |
| Túnica × corpo, pior quadro | 12 de 497 | 17 de 977* | 10 de 504 | 18 de 968* |

\* O número de pares dobrou porque o forro entrou no teste.

As animações que ainda passam de 1% são: Sitting, Farm_Harvest, OverhandThrow, Sword_Regular A/B/C, Sword_Attack, Sword_Block, Jog e Sprint. O P2 também falha em Walk (1 quadro).

**Resultado: REPROVADO no critério de até 1% nas 28 animações.**
- **Ganho no P2:** os quadros com problema caíram de 83 para 19.
- **Ganho no P1:** foi pequeno.
- **Os seis piores quadros continuam mostrando a coxa através da saia** (`03_seis_piores_P1.jpg`, `04_seis_piores_P2.jpg`). Nesses quadros a coxa sobe 60° a 90° (sentado, agachado, avanço), e uma saia presa só à bacia e às coxas não acompanha o movimento.
- Testei 5 combinações de pesos e folgas; nenhuma passou de cerca de 15% no pior quadro.
- **A solução técnica exige algo fora desta autorização** (ver a seção 10).

A métrica antiga (pares túnica/calça) não é usada como prova. Ela também mudou de base, porque a calça agora sobe sob a saia: P1 passou de 2 de 46 vértices para 47 de 367 no pior quadro; P2, de 3 de 27 para 14 de 368.

### 3.3 Túnica feminina (3.3)

O que foi feito:
- O tecido agora cai em linha reta do ponto mais saliente do busto até a cintura.
- +3 mm no peito, sumindo para os lados e para a cintura.
- Suavização sem degraus.
- Cores, detalhes e identidade da peça mantidos.

**Resultado:** o perfil lateral não tem mais a dobra marcada sob o busto (`02_busto_antes_depois.jpg`). **Aprovado.**

### 3.4 Evolução facial (3.4)

A prancha está em `11_prancha_facial_AB_P1.jpg` e `11_prancha_facial_AB_P2.jpg`: frente e três quartos de cada opção.

| Opção | O que é |
|---|---|
| Atual | Rosto do marco 1, para comparação |
| **A** — realista pintado | Mesma forma; só pintura: pálpebras, olheiras suaves, lábios, rubor e íris mais definida |
| **B** — fantasia semi-realista estilizada | Ajustes de forma com os alvos CC0 do MakeHuman/MPFB2 e pintura de ilustração, em 3 variações por sexo: P1 herói, veterano e jovem; P2 nobre, guerreira e jovem |

- **Sem opção C e sem estética anime.** Os olhos ficam em tamanho real. O alvo de aumento dos olhos foi descartado porque o olho do MakeHuman fica escuro dentro da órbita aumentada; a abertura vem das pálpebras.
- **Nada foi aplicado aos modelos:** `pc_humano_m.glb` e `pc_humano_f.glb` não mudaram nenhum byte.
- Defeitos da renderização da prancha (não dos modelos): o contorno do lábio aparece pontilhado, e a íris fica mais escura nas opções A e B por causa do contraste aplicado ao olho. Os dois seriam refeitos na aplicação da opção escolhida.
- **A evolução facial está interrompida, aguardando a escolha de Robson.**

## 4. Espada P5

### 4.1 Medalhão

O que foi feito:
- Medalhão de 48 para 64 mm, dentro da guarda.
- Árvore em silhueta: copa de 3 lóbulos, tronco de 5 mm e raízes de 3 mm, com relevo de cerca de 2 mm.
- Fundo de esmalte escuro e fosco, sem metal; Árvore em bronze polido.
- No grau S, a Árvore tem brilho próprio em ouro.
- Mapa de metal e rugosidade por região. Ganho colateral: o cabo de couro deixou de parecer metal.

**Resultado** (`09_medalhao_antes_depois.jpg`, recortes ampliados dos pixels reais em 1600×900, campo de visão de 40°):
- **A 3 m:** a Árvore é reconhecível no grau S, que brilha. No grau B a silhueta de copa e tronco é legível, sem detalhe fino.
- **A 6 m:** o disco escuro do medalhão se destaca na guarda nos dois graus; antes ele se confundia com a guarda.
- **Aprovado,** com a ressalva de que no grau B a 3 m a leitura é por silhueta.

### 4.2 Bainha (somente por `espada_longa.json`)

A configuração nova fica em `"bainha_cintura"`:
- `direcao_lamina` [0,1174; −0,8829; −0,4546];
- `deslocamento_cabo` [0,28; 0,06; 0,10] (em metros, para 1,80 m de altura).

O `character.gd` e as regras globais **não foram alterados**. A cena de teste lê o `.json`.

| Medida (nas 28 animações, 9 quadros cada) | Regra atual do jogo | V3 P1 | V3 P2 |
|---|---|---|---|
| Ângulo com a vertical | 45,6° | 28,0° | 28,0° |
| Ponta atrás do quadril (repouso) | 0,58 m | **0,31 m** | **0,32 m** |
| Empunhadura à frente do quadril | 0,05 m | 0,10 m | 0,09 m |
| Animações em que atravessa a perna | 12 (P1) / 4 (P2) | 4 | 2 |
| Animações em que atravessa o chão | 5 | 9 | 8 |

- **Ponta, ângulo e empunhadura: aprovados.**
- **"Sem atravessar perna ou chão nas 28 animações": REPROVADO.**
  - Com a lâmina quase vertical, a ponta desce mais e toca o chão em Sitting, Death01 e nos golpes agachados.
  - Ao ar livre (parado, andando, correndo), a P2 passa, mas no Jog a folga mínima até o chão é de só 0,1 cm. O P1 toca o chão no Jog: a ponta chega 1 cm abaixo do chão no ponto mais baixo da passada. Folga até a perna: 4,9 a 9,4 cm.
  - A maioria das falhas restantes acontece em animações de combate (Sword_*, OverhandThrow). Nelas, pelo próprio jogo, a espada está na mão, não na cintura.
- Fiz uma busca em 54 combinações de ângulo e deslocamento. Nenhuma combinação fixa evita o chão e a perna em todas as 28 animações com uma lâmina de 1 m. Ver a seção 10.
- Ângulo: 28° em vez de cerca de 25°, porque 25° levava a mais falhas de perna.

### 4.3 Preservação

- Graus D, B e S mantidos.
- Comprimento de 1,001 m e largura da guarda de 0,273 m mantidos.
- Um material.
- Pegada `len 1.0 at 0.1` mantida.
- Mão, costas e cintura testadas nos três graus (`07_espada_3graus_3posicoes.jpg`).
- Triângulos: D 2.048, B 2.080, S 2.192 (antes 1.772, 1.804 e 1.916; +276 da Árvore e do medalhão).

## 5. LOD da trança

- LOD manual gerado por decimação no próprio gerador: **799 triângulos**, contra 5.518 da trança completa (−85,5%).
- O LOD automático do Godot continua ativo.
- No Godot, campo de visão de 40°, P2 com sombra:

| Distância | P2 com trança completa (visível) | P2 com trança LOD (visível) |
|---|---|---|
| 2,5 m | 30.774 | 26.055 |
| 6 m | 18.726 | 14.007 |
| 15 m | 12.212 | 7.493 (−39%) |
| 30 m | 9.112 | 4.393 (−52%) |

- Aparência: a silhueta é igual a 5, 15 e 30 m (`10_tranca_lod_distancias.jpg`).
- O ponto de troca entre as duas tranças (sugerido: 12 a 15 m) depende de integração. Não está implementado; é só proposta.
- Nada da versão de multidão foi criado.

## 6. Geometria, sombra, chamadas de desenho e texturas (Godot, final)

Medido com campo de visão de 40° em 1600×900, Idle, LOD automático ligado. **Visível e sombra são medidos separadamente.**

| Personagem | Arquivo | Visível 2,5 / 6 / 15 / 30 m | Sombra 2,5 / 6 / 15 / 30 m | Chamadas (sem sombra) | Texturas |
|---|---|---|---|---|---|
| Aldeão oficial (m) | 19.853 | 18.485 / 14.277 / 7.939 / 5.811 | 18.485 / 25.966 / 15.878 / 5.811 | 10 | 48,5 MB |
| P1 antes | 27.150 | 26.870 / 13.364 / 6.752 / 3.704 | 26.870 / 24.328 / 13.504 / 3.704 | 8 | 29,4 MB |
| **P1 depois** | 28.896 | 28.616 / 15.110 / 7.626 / 4.140 | 28.616 / 29.132 / 15.252 / 4.140 | **8** | **29,4 MB** |
| P2 antes | 29.236 | 29.052 / 17.004 / 11.350 / 8.680 | 29.052 / 31.704 / 22.700 / 8.680 | 8 | 29,4 MB |
| **P2 depois** | 30.958 | 30.774 / 18.726 / 12.212 / 9.112 | 30.774 / 36.428 / 24.424 / 9.112 | **8** | **29,4 MB** |
| P2 depois com trança LOD | 26.239 | 26.055 / 14.007 / 7.493 / 4.393 | 26.055 / 26.990 / 14.986 / 4.393 | 8 | 29,4 MB |

- O aumento de cerca de 1,7 mil triângulos por personagem vem do forro (cerca de 1,05 mil) e da calça mais alta (cerca de 0,8 mil).
- Chamadas de desenho e memória de texturas não mudaram.
- Com sombra, o renderizador de compatibilidade soma as passadas de sombra às chamadas visíveis: 16 a 24 por personagem V3 e 20 a 30 no aldeão oficial.
- A espada S acrescenta 1 chamada de desenho e uma textura de 512² a mais (mapa de metal).
- **Não há FPS neste relatório.** O executável e as instruções do benchmark (`Downloads\Valtheria-V3-benchmark`) estão preservados. Uma nova medição de FPS depende de Robson rodar no notebook.

## 7. Deformação nas 28 animações (estiramento de arestas, p99 do pior quadro)

| Peça | P1 antes | P1 depois | P2 antes | P2 depois |
|---|---|---|---|---|
| Corpo | 1,52 | 1,52 | 1,55 | 1,55 |
| Túnica | 1,75 | 2,23 | 1,97 | 2,35 |
| Calça | 1,58 | 3,44 | 1,68 | 2,21 |
| Botas | 1,52 | 1,52 | 1,38 | 1,38 |
| Cabelo | 1,68 | 1,68 | 1,71 | 1,71 |

- **Ainda abaixo da roupa oficial atual:** 3,56 no P1 e 3,07 no P2.
- **A calça do P1 piorou.** O valor de 3,44 vem da parte nova da calça sob a saia, na virilha, que estica em Sitting e Farm_Harvest. Ela fica coberta pela saia, mas aparece como problema remanescente (seção 10).
- **A túnica também esticou mais,** porque a saia agora acompanha as coxas.

**Correção de método:** o fator de translação do quadril usado nos testes foi alinhado à regra do jogo para humanos (`hip = 1.0`). O fator antigo deslocava o personagem inteiro de forma rígida. Isso não muda deformação nem atravessamento entre peças, mas era necessário para medir a espada contra o chão.

## 8. Reconstrução determinística

- O bake agora usa uma única linha de processamento.
- Listas que antes vinham de conjuntos (ordem variável) agora têm ordem fixa.
- Os pesos são processados em ordem alfabética.

**Teste:** duas reconstruções completas e independentes, com sementes de hash do Python diferentes: `vestir_v3.py` P1 e P2, `espada_v3.py` e `ligar_pecas.py`.

**Resultado: 34 de 34 arquivos idênticos byte a byte,** incluindo malhas, pesos, UVs, texturas e `.glb`. A tabela de hashes está em `evidencias/ret020/comparacao_hashes.json`. Os `.glb` gravados no repositório são idênticos aos da reconstrução.

| Peça | SHA-256 (16 primeiros dígitos) |
|---|---|
| rp_aldeao_tunica_m.glb | 11dd30deace9c03c |
| rp_aldeao_tunica_f.glb | 0a72ce80e1070ddf |
| ca_tranca_longa_lod1.glb | 5d132c93442af027 |
| wp_espada_longa_s.glb | fc771c02953f40a5 |

**Versões registradas em `fontes/v3_receita.json`:**
- Blender 5.3.0 (build 02f0899d78e3);
- MPFB2 2.0.18;
- MakeHuman system assets: `makehuman_system_assets_cc0.zip`, SHA-256 b542127a…0107;
- numpy 2.5.4;
- Godot 4.7.2.

Os `.blend` guardam as imagens embutidas, mas **não substituem os scripts como fonte principal.**

## 9. Licenças, créditos e custo

| Material | Licença |
|---|---|
| Corpo, olhos, cabelos e trança (inclusive o LOD, derivado da trança) | MakeHuman system assets, CC0 |
| Alvos faciais usados só na prancha | MPFB2, ativos CC0 (`LICENSE.ASSETS.md`) |
| Roupas, forro, espada, medalhão e texturas | Criação própria por script |
| Blender e MPFB2 | GPL, usados só como ferramentas |

- **`CREDITOS.md` não foi alterado,** porque nenhuma fonte nova entrou nos arquivos do jogo. Se a opção facial B for aplicada, os alvos do MPFB2 (CC0) serão registrados nesse momento.
- **Custo efetivo: R$ 0,00.** Meshy: 0 créditos. Mixamo: não usado. Nenhuma ferramenta ou serviço contratado.

## 10. Problemas remanescentes e propostas (não executadas; precisam de autorização)

1. **A coxa atravessa a saia em poses de flexão forte** (sentar, agachar, avançar), em 14 quadros do P1 e 19 do P2. A causa é estrutural: só bacia e coxas movem a saia. Opções:
   - (a) acrescentar ossos de saia ao esqueleto. Isso altera os 65 ossos e **não está autorizado**;
   - (b) mudar o modelo para uma túnica com fendas laterais, ou mais curta;
   - (c) aceitar o limite e usar, no jogo, uma pose de sentar menos aberta.
   - Recomendo (b), que não mexe no esqueleto.
2. **Espada na cintura toca o chão em Sitting, Death01, nos golpes agachados e (P1) no Jog.** Opções:
   - (a) guardar automaticamente nas costas quando o personagem senta ou morre. Exige mudança no `character.gd`, **não autorizada**;
   - (b) bainha de cintura só para armas de até cerca de 0,8 m e a espada longa sempre nas costas, configurável por arma.
   - Recomendo (b).
3. **A calça do P1 estica na virilha** (p99 3,44). Fica sob a saia; pode ser suavizada com o mesmo método de pesos.
4. **O medalhão no grau B a 3 m lê só como silhueta.** Melhoraria com o brilho também no B, mas isso diferencia menos os graus. Decisão de arte.
5. **Prancha facial:** o lábio aparece pontilhado e a íris escura nas opções A e B (só na renderização da prancha); a escolha A, B1, B2 ou B3 é pendente.
6. **O ponto de troca da trança LOD** depende de integração; não foi implementado.
7. **A etiqueta `v3-marco1-seguranca` não foi publicada no GitHub** (bloqueio do proxy). O commit de segurança está publicado.

## 11. Testes aprovados, reprovados e pendentes

| # | Teste | Resultado |
|---|---|---|
| 1 | 28 animações em P1 e P2 | Executado; todas rodam (`05_`, `06_`) |
| 2 | Deformações | Medido; abaixo da roupa oficial, com piora na calça do P1 (item 10.3) |
| 3 | Saia × volume da coxa | **Reprovado** no critério de 1% (P1: 14 de 84 quadros; P2: 19 de 84) |
| 4 | Espada, 3 graus × 3 posições | Funciona nas 3 posições; **cintura reprovada** quanto a chão e perna em parte das animações |
| 5 | Triângulos de arquivo, visível e sombra | Medido (seção 6) |
| 6 | Chamadas de desenho e memória de texturas | Medido; sem mudança (8 chamadas; 29,4 MB) |
| 7 | Antes × depois | Capturas 01 a 11 |
| 8 | Reconstrução determinística | **Aprovado** (34 de 34 idênticos) |
| 9 | LOD da trança em distâncias | **Aprovado** (−39% a 15 m; −52% a 30 m; mesma silhueta) |
| 10 | Regressão nos modelos e animações oficiais | **Aprovado**: `assets/` e `scripts/` idênticos a `29d9507`; deformação do aldeão oficial igual (corpo 29,36 e 44,19; roupa 3,56 e 3,07) |
| — | Barra sem pontas claras e sem avesso | **Aprovado** |
| — | Busto do P2 | **Aprovado** |
| — | Medalhão a 3 e 6 m | **Aprovado** (com a ressalva do grau B) |
| — | Benchmark de FPS | **Pendente:** Robson roda no notebook com o executável preservado |

## 12. Declaração

Declaro que, nesta execução:
- não houve alteração na `main`, merge, publicação de versão, integração oficial, nem substituição de modelos ou animações oficiais;
- não houve alteração no `character.gd`, no sistema global de equipamentos ou no de renderização;
- não foram produzidos P3, P4, P6, P8 ou P9, nem a versão de multidão;
- a opção facial B não foi aplicada;
- não houve uso de Meshy (nem créditos), de Mixamo ou de ferramenta paga;
- não houve acesso ao Supabase de produção nem a dados de jogadores;
- não há credenciais em nenhum arquivo;
- não houve exclusão, movimentação ou renomeação de arquivos fora do escopo V3.

**Nenhuma restrição da AUT-020 foi violada.**

## 13. Commit da AUT-020

- **Histórico da branch:** `943995a` (marco 1) → `e481ede` (segurança) → **`c9a520a`** (AUT-020).
- **A `main` continua em `29d9507`.**
