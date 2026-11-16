# RET-021 — Planejamento complementar das pendências do marco V3 (D58 a D63)

- **Projeto:** Valtheria — A Árvore dos Mil Mundos
- **Data:** 15/11/2026
- **Referências:** SOL-021, RET-020, PAR-021, AUT-020
- **Branch de referência:** `v3-prototipos`, commit `c9a520a`. O commit está preservado, intacto e sem nenhuma alteração local; a `main` continua em `29d9507`.
- **Situação:** só análise e planejamento. Os estudos visuais e as medições foram feitos em **cópias de trabalho fora do repositório** (`/home/claude/sol021`, `/tmp/vt3`). Nada foi gravado na branch.
- **Evidências:** `evidencias/ret021/`

---

## 1. D58 — Túnica com fendas

### 1.1 O que foi estudado

Duas variantes, geradas numa cópia do gerador com um parâmetro de estudo. Nenhuma substitui os modelos atuais.

| Variante | Desenho | Pesos |
|---|---|---|
| **L — fendas laterais** (pedida) | Abertura de cerca de 3,5 cm na costura lateral, da barra até 60% da altura da saia | Iguais aos da `c9a520a` |
| **C — fendas frente e costas** (alternativa de cavalaria) | Abertura no centro da frente e das costas, da barra até 60% da altura | Abaixo da fenda, cada metade segue 100% a sua coxa |

**Pranchas** (frente, lado, costas; atual × L × C): `d58_pranchas_3opcoes_P1.jpg` e `_P2.jpg`, mais `d58_pranchas_P1/P2.jpg` (atual × L).

**Poses de maior flexão** (Sitting, Farm_Harvest, OverhandThrow, Sword_Regular B/C, Sword_Attack, Walk, Jog): `d58_poses_P1/P2.jpg` (atual × L) e `d58_poses_3opcoes_P1/P2.jpg` (atual × L × C).

### 1.2 Resultados medidos

Saia contra o volume da coxa: mesma métrica do RET-020, 28 animações × 3 quadros.

| | Atual (c9a520a) | L — laterais | C — frente/costas |
|---|---|---|---|
| P1: quadros acima de 1% (de 84) | 14 | 14 | 14 |
| P1: pior quadro | 15,3% (OverhandThrow) | 15,5% | 14,6% (Sitting); OverhandThrow cai de 44 para 33 vértices |
| P1: deformação da túnica (p99) | 2,23 | 2,23 | **1,83** |
| P2: quadros acima de 1% (de 84) | 19 | 20 | 21 |
| P2: pior quadro | 16,2% (Sitting) | 16,2% | 16,5% |
| P2: deformação da túnica (p99) | 2,35 | 2,34 | **2,09** |

**Conclusão técnica**
- **Nenhuma das fendas resolve o atravessamento.** A coxa entra pela frente do colo da saia ao sentar ou agachar, e não pela lateral. As fendas laterais não mudam essa região.
- As fendas na frente e nas costas reduzem o estiramento da túnica em 11% a 18% e melhoram o OverhandThrow, mas não a pose sentada.
- Para chegar a até 1% nas 28 animações é preciso que a saia se mova por conta própria. Opções, todas fora do escopo atual:
  - **(a) ossos de saia:** muda o esqueleto de 65 ossos;
  - **(b) formas corretivas** acionadas pelo ângulo da coxa: blend shapes no `.glb` e um pequeno script por personagem no jogo;
  - **(c) revisar o critério,** excluindo Sitting e poses agachadas, ou aceitando até X% nelas.
  - **Recomendação:** (b), se a meta de 1% for mantida; (c), se o custo não se justificar agora.

### 1.3 Cobertura e exposição da calça

Contagem de pixels da calça visível, com a calça pintada em magenta numa renderização à parte.

| | Frente e costas | Lateral (repouso) | Lateral (poses) |
|---|---|---|---|
| L em relação à atual, P1 | 0% | +4% | 0% a +6% |
| L em relação à atual, P2 | 0% | +9% | +2% a +12% |

- A calça já cobre a coxa inteira (da `c9a520a`), então **a fenda não expõe pele nem buraco.** Só mostra um pouco mais de calça nas laterais.
- A variante C expõe a calça na frente e atrás, entre as pernas (ver as pranchas).

### 1.4 Triângulos e materiais (estimativa para a versão final)

- O estudo apenas remove faces: −14 a −16 triângulos.
- Uma versão final teria cortes limpos com acabamento:
  - faixa da barra seguindo a borda da fenda;
  - forro na abertura;
  - eventual ilhós ou pesponto pintado.
- Estimativa: **+120 a +250 triângulos por túnica** (cerca de +2% a +4%). **Continua 1 material** e as mesmas 8 chamadas de desenho por personagem; textura igual, só repintada na região.

### 1.5 Plano de teste das 28 animações (para a execução, se autorizada)

1. Gerar P1 e P2 com fendas, com duas reconstruções e hashes idênticos.
2. Teste completo com as métricas atuais:
   - saia × coxa, com contagem absoluta por animação e quadro;
   - túnica × corpo;
   - deformação p99.
3. Exposição da calça (pixels de calça) em frente, lado e costas, no repouso e nas 9 poses do estudo.
4. Capturas antes × depois no Godot das 28 animações e dos 6 piores quadros.
5. Critério de aceite: o que Robson definir em D58. O ideal é registrar a nova meta junto com a opção (a), (b) ou (c) acima.

---

## 2. D59 — Calça masculina (virilha)

### 2.1 Diagnóstico

O pior quadro é o meio do Farm_Harvest, com p99 de 3,44.

- **Onde estão os vértices:** as arestas no 1% superior envolvem **55 vértices, todos no entrepernas:**
  - |x| < 6 cm do centro;
  - altura de 0,87 a 0,95 m, ou seja, 3 a 11 cm abaixo da articulação do quadril (0,98 m).
- **Pesos desses vértices:** mistura de bacia e coxa. 35 deles têm mais de 20% de peso na bacia e mais de 20% numa coxa. As combinações mais comuns são bacia + coxa direita (26) e bacia + coxa esquerda (25).
- **Por que estica:** quando a coxa gira de 60° a 90° (agachar, sentar, avançar), a ponte de malha entre a bacia e a coxa estica. É o efeito clássico do *skinning* linear na virilha.
- **Por que antes não acontecia:** no marco 1 a calça acabava 3,5 cm acima da barra, então não existia essa região.
- **Animações e quadros que concentram a deformação:** 19 de 84 quadros com p99 acima de 2,0.

| Animação | p99 |
|---|---|
| Farm_Harvest, meio | 3,44 |
| Sword_Regular_B, fim / meio | 2,91 / 2,90 |
| Sword_Attack, meio | 2,89 |
| Sword_Regular_C, início | 2,87 |
| Sitting_Idle | 2,76 |

- **P2:** o mesmo padrão, mas mais brando: p99 de 2,21 e 2 quadros acima de 2,0.

### 2.2 Ajustes testados (estudo, fora do repositório)

| Variante | p99 pior | Quadros > 2,0 | Efeito colateral |
|---|---|---|---|
| Atual (calça até o quadril) | 3,44 | 19 | — |
| Suavizar pesos, 5 passadas (raio 8 cm) | 3,48 | 20 | Nenhum ganho |
| Suavizar pesos, 10 passadas (raio 10 cm) | 3,37 | 19 | Nenhum ganho |
| Topo da calça 8 cm abaixo do quadril | 3,29 | 15 | Pouco ganho |
| Topo da calça 12 cm abaixo do quadril | 1,59 | 0 | Coxa alta sem tecido (risco de vão sob a saia) |
| Sem o entrepernas (\|x\| < 4 cm, 10 cm de altura) | 1,98 | 0 | Abre uma faixa estreita entre as pernas |
| Sem o entrepernas (\|x\| < 6 cm, 12 cm de altura) | 1,63 | 0 | **Borda visível** em poses de pernas abertas (`d59_calca_entrepernas.jpg`, Sword_Attack de frente) |

### 2.3 Recomendação e impactos

**Suavizar pesos não resolve.** O estiramento é geométrico.

**Recomendação em duas partes:**

1. **Medir a deformação só na região visível.**
   - O entrepernas fica sob a saia em quase todas as vistas.
   - Proposta: excluir do p99 os vértices cobertos pela saia em mais de 90% dos quadros.
   - É um ajuste no teste, não no modelo.
2. **Se for preciso reduzir a deformação no próprio modelo:**
   - testar a variante **"sem entrepernas \|x\| < 4 cm"** (p99 1,98; nenhum quadro acima de 2,0), com validação visual nas mesmas poses;
   - se a borda aparecer, usar formas corretivas na virilha, junto com o item 1.2(b).

**Impacto nos movimentos e nos atravessamentos:**
- Remover a faixa não limita nenhum movimento (é só malha).
- Os atravessamentos saia × coxa não pioram.
- O risco é a borda da calça aparecer de baixo nas poses de pernas muito abertas. Por isso a validação visual é obrigatória.

---

## 3. D60 e D61 — Arquitetura de transporte de armas

### 3.1 Situação atual (lida em `scripts/character.gd`, sem alteração)

- A tabela `GRIP` define a pegada por tipo de arma (`file`, `len`, `at`, `two`, `dual`, `hand`) e um `back` opcional.
- A `espada` (1,0 m) não tem `back`, então vai para a **cintura**. `espadao`, `martelo`, `cajado`, `lanca` e `arco` vão para as **costas**.
- `_make_sheath(back, small)` monta o ponto de transporte com direção e deslocamento fixos no código. Há um caso especial para `adaga` e `punhal` (`small`).
- `set_battle(on)` troca a arma de pai de forma instantânea (mão ↔ bainha). Ele é chamado por:
  - `main.gd` (5 pontos);
  - `npcs.gd` (cidade e estrada: arma guardada);
  - `interiores.gd`.
- O escudo nas costas (`shield_back`) usa o osso `spine_03` com deslocamento −0,20 m. É o **mesmo osso das armas nas costas,** e a regra atual não trata o conflito.

### 3.2 Estrutura de dados proposta

Um bloco `"porte"` por tipo de arma, com padrão geral e possibilidade de o item sobrescrever. **A precedência é: item → tipo → regra por comprimento.**

```json
// dados de equipamento (nova tabela de dados, ex.: data/porte_armas.json — arquivo oficial novo)
{
  "regra_padrao": { "costas_se_comprimento_m_maior_que": 0.85, "cintura_se_menor_ou_igual": true },
  "pontos": {
    "costas_diagonal": { "osso": "spine_03", "direcao_lamina": [-0.42, -0.9, 0.0], "deslocamento_cabo": [0.2, 0.2, -0.17] },
    "cintura_esq":     { "osso": "pelvis",   "direcao_lamina": [0.15, -0.7, -0.7], "deslocamento_cabo": [0.2, 0.04, 0.05] },
    "cintura_curta":   { "osso": "pelvis",   "direcao_lamina": [0.1, -0.95, -0.3], "deslocamento_cabo": [0.2, 0.04, 0.05] },
    "costas_com_escudo": { "osso": "spine_03", "direcao_lamina": [-0.30, -0.95, 0.0], "deslocamento_cabo": [0.24, 0.22, -0.24] }
  },
  "tipos": {
    "espada":  { "porte": "costas_diagonal", "porte_com_escudo": "costas_com_escudo" },
    "adaga":   { "porte": "cintura_curta" },
    "punhal":  { "porte": "cintura_curta" },
    "machado": { "porte": "cintura_esq" }
  }
}
```

- **Relação com `espada_longa.json`:** o bloco `"bainha_cintura"` criado na AUT-020 vira um `"porte"` do item, por exemplo:

  ```json
  "porte": {"ponto": "costas_diagonal"}
  ```

  ou um ponto próprio, como o `cintura` testado de 28°, para itens específicos. O campo `"pegada"` existente continua sendo a pegada GRIP do item.
- **Compatibilidade com GRIP:**
  - `len`, `at`, `two`, `dual` e `hand` continuam iguais.
  - O `back` atual vira só um atalho: `back: true` equivale a `porte: "costas_diagonal"`.
  - A pegada na mão (`_hand_grip`, `_place`) **não muda.** O ponto de transporte usa o mesmo nó da arma e o mesmo ponto de pegada `at`, como hoje.
  - Os valores de deslocamento continuam relativos a 1,80 m (multiplicados por `altura/1,8`), igual ao código atual.

### 3.3 Regras de saque e recolhimento

| Situação | Regra proposta |
|---|---|
| Entrar em combate | `set_battle(true)` passa da bainha para a mão (como hoje). Com arma nas costas, dá para acrescentar um atraso de cerca de 0,25 s para sincronizar com um futuro gesto de saque; sem animação nova, a troca continua instantânea. |
| Sair de combate, cidade, estrada, interiores | `set_battle(false)` passa para o ponto de porte do item (como hoje). |
| Sentar, montar, morrer (Sitting, Death) | Arma na **cintura** passa temporariamente para as costas, se o item permitir. Arma já nas costas: nada muda. |
| Escudo + arma longa | Usa `porte_com_escudo`; o escudo fica no centro das costas e a lâmina na diagonal, mais afastada. |
| Duas armas (`dual`) | A arma principal segue a regra; a secundária fica escondida (como hoje) ou em `cintura_esq`, se for curta. |

### 3.4 Impactos

- **Animações:** nenhuma das 28 muda. O teste da espada longa nas costas precisa ser repetido para colisão com braços e tronco.
- **Equipamentos:**
  - a `espada` passa da cintura para as costas, o que muda o visual de todos os personagens com espada;
  - `adaga` e `punhal` mantêm a cintura;
  - `machado` (0,95 m) precisa de decisão: costas pela regra padrão ou cintura por exceção.
- **NPCs:** os NPCs de ronda com espada (cavaleiros e soldados) mudariam o visual. É preciso conferir as cenas de cidade.

### 3.5 Arquivos oficiais que precisariam ser alterados (com autorização futura)

| Arquivo | Alteração |
|---|---|
| `cliente-godot/scripts/character.gd` | `_weapon()` lê o porte; `_make_sheath()` passa a ser movido a dados; regra temporária ao sentar e morrer; caso do escudo |
| `cliente-godot/data/porte_armas.json` (novo) | Tabela de pontos e tipos |
| `cliente-godot/scripts/main.gd` | Só se houver regras novas de sentar ou montar ligadas a eventos (hoje não é necessário) |
| `assets_v3/equipamentos/espada_longa.json` (V3, não oficial) | Trocar `bainha_cintura` por `porte` |

Não é necessário mexer em `npcs.gd`, `interiores.gd`, Supabase nem servidor: o porte é só apresentação no cliente.

### 3.6 Testes e prevenção de regressões

1. **Ferramenta:** estender `testar_bainha.py` para qualquer ponto de porte (costas e cintura) e para cada tipo de arma da tabela. Mede chão, pernas, tronco e braços nas 28 animações.
2. **Matriz:** todos os tipos de GRIP × {humano, anão, gigante} × {com e sem escudo} × {mão, porte}. Fazer capturas automáticas no Godot.
3. **Regressão:** cena de comparação com os tipos que **não** devem mudar (`espadao`, `martelo`, `cajado`, `lanca`, `arco`), com diferença zero de posição.
4. **Fluxo:** testar `set_battle` em combate, cidade, interior, sentar e morrer; 100 alternâncias sem perder a arma.
5. **Hash da tabela de dados** no relatório e um teste automático no fluxo de trabalho atual.

---

## 4. D62 — Prancha facial A/B corrigida

Arquivos: `d62_prancha_facial_AB_P1.jpg` e `_P2.jpg`. Detalhe antes × depois: `d62_detalhe_correcao.jpg`.

| Defeito (RET-020) | Causa | Correção |
|---|---|---|
| Íris escura | Aumento de contraste no material do olho escurecia a íris e alargava a pupila | Contraste removido; só +25% de saturação e +8% de brilho na opção B |
| Lábio e rosto pontilhados | Sombra serrilhada das sobrancelhas e dos cílios (transparência pontilhada) e sombra dura do sol | Sobrancelhas e cílios não projetam sombra; sol com sombra macia de 6°; 64 amostras; borda da máscara do lábio mais suave |

- Mantidos: opção A (realista pintado), opção B (fantasia semi-realista) com 3 variações por sexo (P1 herói, veterano e jovem; P2 nobre, guerreira e jovem), frente e três quartos.
- Sem anime e sem opção C. **Nada foi aplicado aos modelos P1 e P2.**
- O gerador corrigido está só na cópia de trabalho. O `rosto_ab.py` da branch continua na versão da `c9a520a`.

---

## 5. D63 — LOD da trança (protótipo experimental)

Medidas no Godot, campo de visão de 40°, janela de 1600×900, P2 com sombra (dados do RET-020 e análise nova).

| Distância | Altura do personagem na tela | Triângulos visíveis (completa → LOD) | Diferença visual (pixels do personagem) |
|---|---|---|---|
| 5 m | cerca de 415 px | 30.774 → 26.055 (−15%) | 2,2% (só na trança) |
| 15 m | cerca de 138 px | 12.212 → 7.493 (−39%) | 3,0% |
| 30 m | cerca de 69 px | 9.112 → 4.393 (−52%) | 2,8% |

- **Ponto de troca proposto: 12 m.** A trança completa usa `visibility_range_end` = 12 m e a LOD usa `visibility_range_begin` = 12 m, com margem de 1 m (`visibility_range_*_margin`) para não piscar quando o personagem fica parado perto da distância de troca.
  - Nessa distância o personagem tem uns 170 px de altura e a trança menos de 40 px. A diferença de 2% a 3% dos pixels não é perceptível em jogo.
  - Mecanismo do Godot: `visibility_range_begin` e `visibility_range_end` nas duas malhas de cabelo, sem fade.
  - Com fade ligado, as duas desenhariam ao mesmo tempo durante a transição: +1 chamada de desenho temporária.
- **Chamadas de desenho:** sem mudança (uma malha de cabelo por vez; 8 por personagem).
- **Triângulos:** cerca de 4,7 mil a menos por P2 além de 12 m, inclusive na sombra, onde o ganho é parecido.
- **Dependências para integração:**
  1. `character.gd` carregar a peça LOD junto com o cabelo e configurar o alcance de visibilidade;
  2. convenção de nome `ca_*_lod1.glb`;
  3. decidir se outras peças grandes ganham LOD manual (fora do escopo; a multidão continua adiada);
  4. o benchmark no notebook de Robson continua sendo a única medida válida de FPS.

**Não implementado:** ponto de troca, LOD de multidão e mudanças de sombra.

---

## 6. Dependências, riscos e arquivos afetados (se as propostas forem autorizadas)

| Decisão | Arquivos V3 (branch) | Arquivos oficiais | Riscos |
|---|---|---|---|
| D58 fendas | `vestir_v3.py`, túnicas `.glb` e `.import`, receita | nenhum | Não resolve o critério de 1% sozinha; o acabamento da fenda exige cuidado com o forro |
| D58 formas corretivas | `vestir_v3.py`, `ligar_pecas.py` (exportar blend shapes) | `character.gd` (acionar as formas pelo ângulo da coxa) | Custo de CPU por personagem; testar com 40 personagens no notebook |
| D59 | `vestir_v3.py`, `testar_animacoes.py` (métrica da região visível) | nenhum | Borda visível; validação obrigatória |
| D60/D61 | `espada_longa.json` | `character.gd`, `data/porte_armas.json` (novo) | Muda o visual de todos os personagens e NPCs com espada; conflito com escudo nas costas |
| D62 | `rosto_ab.py` (só se Robson aprovar a correção na branch) | nenhum até a escolha do rosto | Nenhum (prancha) |
| D63 | nenhum novo (o LOD já existe) | `character.gd` | Piscada na troca, se não houver histerese |

---

## 7. Estimativa de esforço e custo

Esforço em horas de trabalho do Claude, incluindo testes e relatório.

| Item | Esforço |
|---|---|
| D58 fendas, versão final com acabamento + testes | 3 a 4 h |
| D58 formas corretivas (opção b) | 8 a 12 h (inclui integração em `character.gd`, se autorizada) |
| D59 métrica da região visível + variante sem entrepernas | 2 a 3 h |
| D60/D61 transporte de armas (código, dados, matriz de testes) | 6 a 10 h |
| D62 aplicação de uma opção facial escolhida em P1 e P2 | 4 a 6 h |
| D63 integração do LOD da trança | 2 a 3 h |

**Custo financeiro: R$ 0,00.** Ferramentas livres (Blender, MPFB2 e Godot) e materiais CC0 ou próprios. Sem Meshy, sem Mixamo e sem contratação.

---

## 8. Declaração

Declaro que **nenhuma implementação foi realizada** nesta SOL-021:
- nenhum arquivo da branch `v3-prototipos` foi alterado: o commit `c9a520a` está preservado e o repositório local está sem alterações;
- não houve nenhum commit, merge ou publicação;
- a `main` continua em `29d9507`;
- não houve alteração em `character.gd` nem em qualquer arquivo oficial;
- não houve uso de Meshy, Mixamo ou ferramenta paga;
- não houve acesso ao Supabase;
- não foram produzidos P3, P4, P6, P8 ou P9, nem a versão de multidão;
- nenhuma opção facial foi aplicada.

Todos os estudos foram feitos em cópias de trabalho fora do repositório.

**Aguardando a avaliação da Coordenação Técnica e a decisão de Robson sobre D58 a D63.**
