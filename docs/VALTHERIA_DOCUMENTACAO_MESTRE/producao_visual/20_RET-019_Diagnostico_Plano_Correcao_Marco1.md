# RET-019: diagnóstico e plano de correção do primeiro marco V3

- **Resposta à:** SOL-019, de 15/11/2026
- **Branch:** `v3-prototipos`, commit de referência `943995a`
- **Situação:** só análise e planejamento. **Nenhuma correção foi feita.**
  - Nenhum arquivo da branch foi alterado.
  - Os testes de diagnóstico rodaram numa cópia temporária, fora do repositório.

---

## 1. Diagnóstico de cada problema

### 1.1 Pontas claras e barra da túnica que sobe (P1 e P2)

Fiz capturas no Godot com o material da túnica em três modos: duas faces (como está), só face externa, e lado interno pintado de magenta. Arquivo: `evidencias/ret019/antes_barra_diagnostico.jpg`.

| Causa | Evidência |
|---|---|
| **A. Pesos da barra.** Os vértices do centro da barra seguem 100% as coxas, divididos entre a esquerda e a direita, e nada da bacia. Quando uma coxa vai à frente, o centro da frente sobe e se abre. | P1: 19 vértices no centro da barra, todos só com `thigh_l`/`thigh_r`. P2: 16 vértices, mesma situação. |
| **B. Faces internas entre as pernas.** A malha auxiliar da saia do MakeHuman traz faces na região da virilha. Em pose, elas ficam abaixo da barra. São claras porque a faixa azul da barra é pintada pela altura de repouso e não as alcança. | As pontas continuam visíveis mesmo com só a face externa. Logo, são geometria real, não o avesso do tecido. |
| **C. Avesso igual ao direito.** O material tem duas faces, então o lado de dentro aparece com a cor do lado de fora. | Faixa magenta visível sob a barra e nas laterais do cinto. |

A malha em repouso está limpa. O defeito só aparece com o esqueleto em pose.

### 1.2 Túnica atravessando a calça (prioridade P2)

- **Os 11,11% são 3 vértices de 27 pares medidos.** O 4,35% do P1 é 1 vértice de 23.
  - A métrica só compara pares a menos de 5 cm em repouso.
  - Como a calça acaba 3,5 cm acima da barra, sobram poucos pares, e cada vértice pesa muito no percentual.
- **A métrica atual subestima o problema visível.** Nos golpes com avanço (Sword_Regular_B/C, OverhandThrow), a coxa sobe e atravessa a frente da saia na altura do cinto. Isso não entra no par túnica/calça. Evidência: `antes_atravessamento_P2.jpg`.
- **Causas:**
  - pesos da saia (mesma causa A do item 1.1);
  - folga pequena da saia: 8 mm na barra;
  - calça cortada logo acima da barra, o que deixa a coxa sem cobertura de tecido por baixo da saia.
- **Correção da métrica:** o novo teste vai informar número absoluto de vértices, quadro e animação. Vai incluir um teste da saia contra o volume real da coxa, com o osso da coxa como cápsula.

### 1.3 Busto do P2 marcado

- A túnica foi feita a partir da pele, empurrada para fora, e suavizada só no plano horizontal.
- Por isso ela segue a curva por baixo do busto, como uma malha justa. Não há tecido caindo do busto até a cintura.

### 1.4 Rosto

- O rosto atual é o MakeHuman neutro com a pele repintada.
- Proporções realistas, sem desenho de traço. Não lê como fantasia estilizada.

### 1.5 Medalhão da espada

- Hoje o medalhão tem 48 mm de diâmetro.
- A Árvore em relevo usa traços de 1,3 a 2,2 mm, que saltam cerca de 1,5 mm, em metal sobre metal.
- A 6 m da câmera, em 1600×900 com campo de visão de 75°, o medalhão ocupa uns 5 px e cada traço menos de 1 px.
- **Nenhum relevo geométrico desse tamanho é legível em distância de jogo.** A leitura tem de vir de forma maior e de contraste de cor.

### 1.6 Espada na cintura muito projetada

- A bainha de cintura vem da regra do jogo: lâmina na direção (0,15; −0,70; −0,70).
- Com lâmina de 0,9 m depois da empunhadura, a ponta fica **cerca de 0,63 m atrás e 0,63 m abaixo do quadril**.
- A regra foi feita para armas mais curtas. Evidência: `antes_espada.jpg`.

### 1.7 Achado extra: arquivos `.import` sem imagem

- O commit `943995a` tem arquivos `*_0.png.import` das texturas que o Godot extrai dos `.glb`, mas não tem os `.png`.
- O Godot recria os `.png` ao importar, então nada quebra. Mas o conjunto está inconsistente.
- Correção: acrescentar os `.png`. É só criar arquivos, nada é apagado.

---

## 2. Diferença de triângulos (item 9)

A diferença vem do **LOD automático do Godot**.
- A importação dos `.glb` usa `meshes/generate_lods=true`, padrão do projeto e já usado nos modelos atuais.
- O Godot gera versões reduzidas e escolhe uma conforme o tamanho do objeto na tela.
- Os 17,3 mil eram o LOD escolhido na captura das medidas.
- Não há geometria escondida nem descartada.
- Com o LOD automático desligado (`mesh_lod_threshold = 0`), o Godot desenha exatamente os triângulos do arquivo.

**Medição separada**, com a cena de diagnóstico `diag_tri.gd`, personagem em Idle e janela de 1600×900:

| Personagem | Arquivo | Visível a 2,5 m | a 6 m | a 15 m | a 30 m | Sombra a 2,5 m |
|---|---|---|---|---|---|---|
| Aldeão atual (m) | 19.853 | 18.197 | 11.865 | 5.811 | 3.117 | 54.591 |
| V3 P1 | 27.150 | 17.280 | 7.952 | 3.704 | 2.580 | 51.840 |
| V3 P2 | 29.236 | 20.960 | 11.910 | **8.680** | **7.410** | 62.880 |
| V3 P1 sem LOD | 27.150 | 27.150 | 27.150 | 27.150 | 27.150 | 81.450 |

**Leitura**
- **Sombra.** Com a luz do sol ligada, a passada de sombra desenha cerca de 3 vezes os triângulos visíveis (3 divisões do mapa de sombra). Quando o personagem se afasta, a sombra também usa o LOD.
- **Chamadas de desenho.**
  - Visíveis: 8 no V3 e 10 no atual.
  - Com sombra: o renderizador de compatibilidade soma as passadas de sombra nas chamadas visíveis, e o total vai a 32 no V3 e 40 no atual.
  - A 30 m o total cai para 24 e 30, porque a sombra fica com menos divisões.
- **A P2 reduz mal a distância.** A trança mantém 7,4 mil triângulos a 30 m (o P1 cai para 2,6 mil).
  - Isso explica os 24% a 30% de triângulos a mais do V3 no ensaio com 20 e 40 personagens.
  - Lá o P2 era metade do grupo.
- **Os números do relatório anterior estavam certos, mas misturavam situações.**
  - Os 27.150 e 29.236 são do arquivo.
  - Os cerca de 17,3 mil são do LOD automático a 2,5 m em vista ortográfica.
  - A partir de agora as três métricas (arquivo, visível e sombra) vêm separadas.

---

## 3. Plano de correção (para executar só depois da autorização)

### P1 e P2

| # | Correção | Como | Critério de aceite |
|---|---|---|---|
| 1 | Barra da túnica | Repartir o peso da saia por altura e lado: no centro da frente e das costas, 60 a 70% bacia e o resto coxas; nas laterais, coxa dominante. Suavizar os pesos em 3 passadas, mantendo até 4 influências. Apagar as faces internas entre as pernas. Fazer um forro interno escuro na mesma malha e no mesmo material, sem chamada de desenho extra, e deixar o material com uma face só. | Nenhuma ponta clara e nenhum avesso visível nas 28 animações, com captura frontal e lateral de cada uma |
| 2 | Atravessamento túnica/calça | Folga da barra de 8 para 15 mm e um pouco mais de abertura. Subir a calça até o quadril por baixo da saia. Aplicar a mesma repartição de pesos do item 1. | Até 1% de vértices atravessando nas 28 animações, e saia sem a coxa atravessando nos 6 piores quadros |
| 3 | Busto do P2 | Fazer o tecido cair do busto até a cintura, aproximando a frente da forma convexa do tronco. Mais 3 mm de folga no peito. A modelagem, as cores e os detalhes continuam iguais. | Perfil lateral sem a dobra por baixo do busto; cores e detalhes iguais aos da prancha aprovada |
| 4 | Rosto | Ver a seção 4. Só depois de Robson escolher o caminho. | — |
| 5 | LOD | Ver a seção 5. | — |

### P5

| # | Correção | Como | Critério de aceite |
|---|---|---|---|
| 1 | Medalhão | Diâmetro de 48 para cerca de 64 mm, ainda dentro da guarda. Árvore em silhueta com traços de 3 a 4 mm. Leitura por contraste: Árvore em bronze claro sobre fundo escurecido. No grau S, a Árvore ganha brilho próprio. | Árvore reconhecível a 3 m e silhueta do medalhão visível a 6 m, comparando antes e depois |
| 2 | Cintura | Lâmina mais vertical, a cerca de 25° da vertical, e empunhadura à frente do quadril. O ajuste fica registrado em `espada_longa.json`. Mudar o `character.gd` exige autorização própria. | Ponta no máximo a 0,35 m atrás do quadril, sem atravessar a perna nem o chão nas 28 animações |
| 3 | Graus | Os mesmos graus D, B e S, 1 material, comprimento de 1,0 m e pegada `len 1.0 at 0.1` | Mão, costas e cintura testadas nos três graus |

### Testes depois das correções

- As 28 animações nos dois sexos: deformação, atravessamentos com a métrica nova e capturas antes/depois.
- Medidas no Godot separadas em arquivo, visível e sombra.
- Benchmark de novo, com o mesmo executável e as mesmas regras. Ele só vale quando rodado no notebook.

---

## 4. Proposta de evolução facial: fantasia semi-realista estilizada, sem anime

Toda a base é de ajustes do próprio MakeHuman (CC0) e pintura feita por nós.

| Opção | O que muda | Prós | Contras |
|---|---|---|---|
| **A. Realista pintado** | Só a pintura: sombras e luzes pintadas, lábios, olheiras e íris mais definidas | Risco mínimo, sem triângulos extras | Continua com cara de "pessoa comum" |
| **B. Fantasia estilizada (recomendada)** | Proporções levemente idealizadas: olhos uns 8% maiores, maçãs e mandíbula mais marcadas, nariz mais fino. Pintura com traço de ilustração: contorno suave nas pálpebras, íris com reflexo pintado e sobrancelhas mais cheias. Três variações de rosto por sexo. | Lê bem a distância, combina com fantasia épica e as variações servem à criação de personagem | Requer validar com Robson numa prancha só de rosto |
| C. Estilizado forte | Proporções de ilustração: olhos 15 a 20% maiores e queixo menor | Identidade forte | Fica perto do anime, que **não** está autorizado como padrão |

Entrega proposta: uma prancha de rostos com A e B lado a lado, frente e três quartos, antes de aplicar no personagem.

---

## 5. Proposta de LOD (sem substituir modelos atuais)

1. **Manter o LOD automático do Godot.** Ele já reduz o P1 de 27,1 mil para 2,6 mil triângulos a 30 m.
2. **LOD manual da trança do P2.** Uma trança simplificada para distância, com cerca de 800 triângulos, porque a automática não reduz bem.
   - Impacto estimado: o P2 cai de 7,4 mil para cerca de 3,0 mil triângulos a 30 m.
3. **Versão de multidão para mais de 25 m** (arquivos novos `*_lod_multidao.glb`).
   - Uma malha só, com 1 material e 1 textura de 512².
   - Cerca de 2,5 mil triângulos e sem sombra própria.
   - Impacto estimado em 40 personagens, metade além de 25 m:
     - chamadas de desenho caem de cerca de 1.440 para cerca de 760 (−47%);
     - triângulos caem de cerca de 1,07 milhão para cerca de 0,55 milhão (−48%).
4. **Sombra por distância.** Desligar a sombra própria do personagem além de 30 m, ou usar a malha de sombra simplificada que o importador já cria (`create_shadow_meshes`).

Os números do item 3 são **estimativas**. Eles só viram meta depois do benchmark válido no notebook. Os modelos oficiais não mudam; os LODs são arquivos novos em `assets_v3/`.

---

## 6. Fontes e manutenção (item 4 da SOL)

- **A geometria se reconstrói de forma determinística.** Rodei o gerador do P1 duas vezes:
  - malhas, pesos, contagens e as texturas da calça e das botas saíram idênticas byte a byte;
  - a textura da túnica variou em **7 pixels de 1.048.576**, por ruído de processamento em paralelo no bake (o processo que grava a textura).
- **Correção prevista:** fixar uma única linha de processamento no bake. Assim a reconstrução fica idêntica byte a byte.
- **Dependências para reconstruir**, todas gratuitas e nenhuma no repositório:
  - Blender 5.3 (GPL);
  - extensão MPFB2 (GPL);
  - MakeHuman system assets (CC0).
- **Proposta:** criar `fontes/v3_receita.json` com as versões exatas e o comando de cada peça.
- **Arquivos `.blend` editáveis: recomendo guardar.**
  - Um `.blend` do P2 com as imagens externas ocupa 1,0 MB (medido).
  - Ele permite ajuste manual sem rodar o script.
  - Não cria dependência paga, porque o Blender é gratuito.
  - Os scripts continuam sendo a fonte principal; o `.blend` é para conferência e retoque.

---

## 7. Arquivos que serão criados ou modificados (após autorização)

**Ponto para decisão de Robson.** As correções regeram arquivos que eu mesmo criei em `assets_v3/`.

| Opção | Como funciona |
|---|---|
| **A (recomendada)** | Regravar os mesmos nomes na branch `v3-prototipos`. A versão anterior fica preservada no histórico (commit `943995a`). |
| B | Criar arquivos novos com sufixo `_r2` e manter os anteriores. |

Nenhum arquivo oficial do jogo é tocado em nenhuma das opções.

**Modificados** (só arquivos V3 da própria branch):
- `ferramentas/v3/vestir_v3.py`
- `espada_v3.py`
- `testar_animacoes.py`
- `ligar_pecas.py` (só a fixação do bake)
- `testes/prototipos/p1_humano.gd`
- os `.glb` e as texturas de `assets_v3/personagens` e `assets_v3/equipamentos`, se for a opção A

**Criados:**
- `ferramentas/v3/lod_v3.py`
- `testes/prototipos/diag_triangulos.gd/.tscn` e `diag_barra.gd/.tscn`
- `assets_v3/personagens/*_lod_multidao.glb` e a trança simplificada
- os `*_0.png` que faltam
- `fontes/personagens/pc_humano_m.blend` e `pc_humano_f.blend`
- `fontes/v3_receita.json`
- prancha de rostos A/B

**Acréscimo em arquivo existente:** só `CREDITOS.md`, se entrar alguma fonte nova (não está previsto).

---

## 8. Métricas e capturas "antes" (já registradas)

| Métrica | P1 | P2 |
|---|---|---|
| Atravessamento túnica/calça (pior quadro) | 1 de 23 vértices | 3 de 27 vértices |
| Quadros com atravessamento túnica/calça | 5 de 84 | 8 de 84 |
| Atravessamento túnica/corpo (pior quadro) | 2,41% | 1,98% |
| Vértices da barra só com peso de coxa | 19 de 19 | 16 de 16 |
| Ponta da espada atrás do quadril (cintura) | 0,63 m | — |
| Medalhão a 6 m | cerca de 5 px | — |

Capturas no Godot em `evidencias/ret019/`:
- `antes_barra_diagnostico.jpg`
- `antes_atravessamento_P2.jpg`
- `antes_espada.jpg`

As capturas "depois" e o teste das 28 animações vêm após a execução autorizada.

## 9. Custos e licenças

- Custo: R$ 0,00. Créditos Meshy: 0. Sem Mixamo e sem ferramenta paga.
- Licenças: as mesmas do marco. MakeHuman CC0, MPFB2 e Blender GPL usados só como ferramenta, e criação própria. Os ajustes de rosto usam os modificadores do próprio MakeHuman, também CC0.

## 10. Decisões pedidas a Robson

1. Autorizar a execução do plano (seção 3).
2. Escolher entre as opções A e B de regravação (seção 7).
3. Escolher o caminho do rosto: A, B ou nenhum por enquanto (seção 4).
4. Autorizar guardar os `.blend` em `fontes/` (seção 6).
5. Escolher o escopo de LOD: só a trança, trança e versão de multidão, ou adiar (seção 5).
