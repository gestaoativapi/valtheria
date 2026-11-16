# RET-022 — Sprint de evolução V3: protótipos funcionais e validação técnica (AUT-021)

- **Projeto:** Valtheria — A Árvore dos Mil Mundos
- **Data:** 16/11/2026
- **Referências:** AUT-021, RET-021, RET-020
- **Branch:** `v3-prototipos`
  - Base: `c9a520a`
  - **Commit da sprint: `c8a1f11`**, enviado ao GitHub.
- **`main`:** continua em `29d9507`, sem merge, publicação ou integração.
- **Evidências:** `evidencias/ret022/`

Nenhum arquivo oficial foi alterado. O `git diff c9a520a c8a1f11` não toca:
- `cliente-godot/scripts/`, `cliente-godot/data/` e `cliente-godot/assets/`;
- `character.gd`, o esqueleto de 65 ossos e as 28 animações.

---

## 1. Resumo

| Item | Situação | Resultado principal |
|---|---|---|
| D58 formas corretivas | Protótipo funcional (P1 e P2) | Atravessamento saia × coxa: −55% (P1) e −58% (P2). Sentado: de 41 para 2 vértices (P1) e de 38 para 3 (P2). **Não chega a 1%** (pior quadro de cerca de 11%). |
| D59 calça e métrica | Métrica nova e variante testada | Integral 3,44 → 1,99 com a variante. Região visível: 1,59 (sem mudança). Nenhuma abertura visível nas capturas. |
| D60/D61 porte de armas | Protótipo funcional, orientado por dados | **29 de 54** configurações sem interseção crítica. 100 alternâncias mão ↔ guardada sem falha em todas as 54. |
| D62 prancha facial | Gerador corrigido na branch | Pranchas A/B corrigidas (P1 e P2), nada aplicado |
| D63 trança LOD | Protótipo funcional | Troca a 11 m (aproximando) e 13,25 m (afastando); sem piscar parado nos 12 m; nunca as duas tranças no mesmo quadro |

---

## 2. D58 — Formas corretivas da túnica

**Como funciona**
- `ferramentas/v3/corretivas_v3.py` gera 13 *blend shapes* por túnica:
  - frente 45°, 90° e 135°, trás 45°, fora 45° e dentro 25°, para cada coxa;
  - mais uma forma de combinação para as duas coxas a 90°.
- Cada forma é calculada posando a túnica com a calça de referência. Os vértices da saia a menos de 15 mm da calça são empurrados para fora; o campo é suavizado e convertido para o repouso.
- Cada forma corrige só o que as anteriores não resolveram.
- O ângulo da coxa é medido no referencial da saia (média da bacia e da `spine_01`). A diagnose mostrou que, em OverhandThrow, os vértices que atravessam seguem a `spine_01`.
- A mesma fórmula está em `corretivas_base.py` (testes) e em `testes/prototipos/corretivas_controlador.gd` (Godot). Diferença máxima entre os pesos calculados pelos dois nas poses críticas: 0,05.
- Arquivos novos: `rp_aldeao_tunica_m_corretiva.glb` e `rp_aldeao_tunica_f_corretiva.glb`. **As túnicas aprovadas não foram substituídas.**

**28 animações × 3 quadros**

| | P1 atual | P1 corretiva | P2 atual | P2 corretiva |
|---|---|---|---|---|
| Quadros acima de 1% | 14 | 9 | 19 | 10 |
| Pior quadro | 15,3% | 10,8% | 16,2% | 11,5% |
| Soma de vértices atravessando (84 quadros) | 358 | 160 | 314 | 131 |
| Sitting (vértices) | 41 | 2 | 38 | 3 |
| OverhandThrow, meio | 44 | 31 | 31 | 27 |
| Túnica × calça, pior | 12,8% | 10,6% | 3,8% | 1,9% |
| Deformação da túnica (p99) | 2,23 | 2,65 | 2,36 | 2,65 |

**Por que não chega a 1%**
- O resto está em poses compostas, como passada larga com tronco girado (OverhandThrow, golpes de espada, Farm_Harvest).
- Formas acionadas por um ângulo por coxa não cobrem essas combinações. Testei folga maior (25 mm): ganho pequeno e mais estiramento.

**Alternativas técnicas**
1. Deformação por exemplos (RBF): dezenas de poses de treino tiradas das 28 animações. Fica no mesmo `.glb` e no mesmo controlador, com mais custo de CPU.
2. Ossos de saia: exige alterar o esqueleto oficial, **depende de autorização**.

**Custo:** o estiramento da túnica sobe de 2,2–2,4 para 2,65 (p99). Nas capturas, a forma em repouso não muda.

Pranchas: `d58_corretivas_P1.jpg` e `d58_corretivas_P2.jpg` (8 poses, lado e frente).

---

## 3. D59 — Calça masculina e métrica de deformação

- `testar_calca_visivel.py` mede **as duas métricas separadamente**:
  - **integral:** todas as arestas, mantida como antes;
  - **região visível:** só arestas abaixo da barra da túnica no repouso, medida por setor de 10°.
- A variante sem a faixa central (|x| < 4 cm, 10 cm de altura) entrou na branch como **arquivo novo de estudo**: `rp_aldeao_calca_m_sem_entrepernas.glb`.
  - A flag `V3_CALCA_ENTREPERNAS` fica desligada por padrão. A reconstrução padrão de P1 continua byte a byte igual à da `c9a520a`.

| Calça | p99 integral (pior) | Quadros > 2,0 | p99 região visível | Bordas abertas (total / na região visível) |
|---|---|---|---|---|
| P1 atual | 3,44 (Farm_Harvest) | 19 | 1,59 | 92 / 48 |
| P1 sem entrepernas | 1,99 | 0 | 1,59 | 108 / 48 |
| P2 atual | 2,21 | 2 | 1,66 | 88 / 40 |

**Leitura dos números**
- O estiramento de 3,44 fica todo fora da região visível.
- A variante acrescenta 16 bordas abertas, todas sob a saia no repouso.
- Nas capturas de baixo (8 poses, com a túnica corretiva) não aparece abertura. Ver `d59_calca_vista_baixa.jpg`.

**Limitação:** a câmera baixa está a 0,75 m abaixo da linha do quadril. Um ângulo rente ao chão não foi testado.

**Interação com o D58:** a variante não muda o resultado saia × coxa (a métrica usa a calça de referência posada).

---

## 4. D60/D61 — Porte de armas

**Dados e controlador**
- Tabela: `assets_v3/equipamentos/porte_armas.json`.
  - Pontos de porte.
  - Precedência **item > tipo > comprimento** (acima de 0,85 m vai nas costas).
  - Troca de ponto com escudo.
  - Estados:
    - **combate:** arma na mão;
    - **trabalho:** arma longa oculta;
    - **morte:** arma solta no chão;
    - **sentado:** arma longa da cintura vai para as costas.
- Controlador isolado: `testes/prototipos/porte_armas.gd`. Usa o personagem oficial sem alterá-lo: a arma guardada só troca de pai, e na mão segue `set_battle(true)` oficial.
- A espada longa (P5) usa o modelo V3. Sem escudo vai para as costas; com escudo, para a cintura. O ponto da cintura foi ajustado a partir da `bainha_cintura` do `espada_longa.json`.

**Como foi testado**
- Matriz: 12 armas × humano, anão e gigante × com/sem escudo nas armas de uma mão = **54 configurações**.
- Arma guardada nas 28 animações, 5 quadros cada.
- Medido contra chão, pernas, tronco, cabeça, braços e caixa do escudo. Interseção crítica: mais de 1,5 cm.
- Os pontos de cintura e o de costas com escudo foram ajustados por varredura automática.

**Resultados**
- 29 de 54 configurações aprovadas.
- 100 alternâncias mão ↔ guardada com 0 falhas nas 54.
- Escudo: nenhuma interseção com a arma guardada, depois da troca para a cintura.

**Reprovadas e causas**

| Grupo | Causa | Saída possível |
|---|---|---|
| Adaga, punhal, cetro (humano e gigante) | Mão encosta na arma na caminhada (2–5 cm) | Ponto 3–4 cm mais para trás, ou por raça |
| Machado e espada com escudo na cintura (anão e gigante) | Arma escalada pela raça chega ao chão ou ao banco ao sentar | Regra por raça: anão e gigante com arma ≥ 0,85 m vão nas costas |
| Espada oficial + escudo (anão e gigante) | Cintura chega ao chão; costas batem no escudo (a guarda toca o escudo até 0,42 m atrás) | Mudar a posição do escudo nas costas exige alterar `character.gd`, **depende de autorização** |
| Arco e martelo nas costas | Braços em Dance e Consume; arco na morte | Ajuste fino do ponto das costas por tipo |

Além disso, a regra de porte para todos os NPCs não foi implementada, como pede a AUT-021.

Evidências: `matriz_porte.json`, `d60_porte_repouso.jpg` e `d60_porte_estados.jpg`.
- Capturas: repouso, caminhada, corrida, morte e combate.
- A pose sentada só tem medição: a animação tem outro nome e as capturas a pularam.

---

## 5. D62 — Prancha facial

- `ferramentas/v3/rosto_ab.py` corrigido na branch:
  - íris sem aumento de contraste;
  - sobrancelhas e cílios sem sombra projetada;
  - sombra macia;
  - borda dos lábios suavizada.
- Pranchas `d62_prancha_facial_AB_P1.jpg` e `_P2.jpg`:
  - opção A e as 3 variações da B;
  - frente e três quartos;
  - mesma luz, câmera e escala para todas.
- Nada foi aplicado a P1 ou P2. Sem opção C.

---

## 6. D63 — Trança LOD

- Cena `testes/prototipos/tranca_lod.tscn`.
- Mecanismo: `visibility_range` sem fade. Trança completa até 12 m; LOD a partir de 12 m; margem de 1 m como histerese.

**Comportamento da troca**

| Trajeto | Resultado |
|---|---|
| Aproximando (30 → 5 m, passo de 0,25 m) | Uma troca, a 11,0 m |
| Afastando (5 → 30 m) | Uma troca, a 13,25 m |
| Parado em 12 m (120 quadros) | Nenhuma troca |
| Oscilando 11,5 ↔ 12,5 m | Nenhuma troca |
| Quadros com as duas tranças visíveis | 0 |

**Sombra:** os triângulos de sombra são iguais aos da cena só com a malha escolhida (5, 15 e 30 m). A sombra segue a troca.

O contador de sombra por quadro dos trajetos foi descartado como prova: a sombra conta cada cascata.

| Distância | Malha | Triângulos visíveis | Triângulos de sombra | Chamadas de desenho |
|---|---|---|---|---|
| 5 m | completa | 22.684 | 22.690 | 21 |
| 15 m | LOD | 7.495 (12.214 com a completa) | 14.482 (23.920 com a completa) | 28 |
| 30 m | LOD | 4.395 (9.114 com a completa) | 4.401 (9.120 com a completa) | 21 |

Diferença visual (RET-021): 2% a 3% dos pixels do personagem. Capturas: `d63_tranca_troca.jpg`.

---

## 7. Reconstrução determinística

| Saída | Duas reconstruções (sementes diferentes) | SHA-256 (início) |
|---|---|---|
| `rp_aldeao_tunica_m_corretiva.glb` | Iguais | `c0389de68ff2245d` |
| `rp_aldeao_tunica_f_corretiva.glb` | Iguais | `102e47c5655cc336` |
| `rp_aldeao_calca_m_sem_entrepernas.glb` (vestir + ligar) | Iguais | `741a7fcc59e9e26b` |
| Reconstrução padrão de P1 com o gerador alterado | Igual aos arquivos da `c9a520a` | — |

Os hashes completos estão em `fontes/v3_receita.json`.

---

## 8. Desempenho

Medido no renderizador de software, 3 s por cenário. **Só triângulos, chamadas de desenho e memória são válidos aqui; o FPS dessa máquina não é referência.**

| Cenário | Personagens | Chamadas de desenho | Triângulos | Memória de vídeo |
|---|---|---|---|---|
| V3 (c9a520a) | 20 | 727 | 605.528 | 134,9 MB |
| V3 da sprint | 20 | 727 | 416.857 (−31%) | 146,9 MB |
| V3 (c9a520a) | 40 | 1.441 | 1.158.313 | 145,3 MB |
| V3 da sprint | 40 | 1.441 | 781.030 (−33%) | 161,9 MB |

- "V3 da sprint" = túnicas corretivas + controlador + troca da trança.
- **A memória sobe 12–16 MB** com as formas corretivas (dados de *blend shape*).
- O custo de CPU do controlador e das formas só aparece no FPS e no 1% baixo do notebook.
- Pronto para teste: `Valtheria-V3-benchmark-sprint.exe`, com os cenários antigos mais "v3s" 1/20/40. Não publicado.

---

## 9. Arquivos

**Alterados**
- `ferramentas/v3/rosto_ab.py`
- `ferramentas/v3/testar_animacoes.py`
- `ferramentas/v3/vestir_v3.py` (flag desligada por padrão)
- `testes/prototipos/benchmark_v3.gd`
- `fontes/v3_receita.json`

**Criados**
- `ferramentas/v3/`:
  - `corretivas_v3.py`
  - `corretivas_base.py`
  - `testar_calca_visivel.py`
- `testes/prototipos/`:
  - `corretivas_controlador.gd`
  - `corretivas_teste.gd` e `.tscn`
  - `porte_armas.gd`
  - `porte_armas_teste.gd` e `.tscn`
  - `tranca_lod.gd` e `.tscn`
  - os `.uid` correspondentes
- `assets_v3/equipamentos/porte_armas.json`
- `assets_v3/personagens/`:
  - `rp_aldeao_tunica_m_corretiva.glb` e `rp_aldeao_tunica_f_corretiva.glb`
  - `rp_aldeao_calca_m_sem_entrepernas.glb`
  - `.import` e texturas extraídas desses três arquivos

## 10. Falhas, limitações e itens que exigem nova autorização

1. **D58:** a meta de 1% não foi atingida (≈11%). Próximo passo técnico: formas por exemplos (RBF). Ossos de saia exigem alterar o esqueleto oficial (**autorização**).
2. **D60:** 25 de 54 configurações ainda têm interseção crítica.
   - Espada oficial + escudo em anão e gigante só se resolve mudando a posição do escudo nas costas no `character.gd` (**autorização**).
   - O resto se ajusta nos dados (regra por raça e pontos por tipo).
3. **D59:** a validação visual não incluiu câmera rente ao chão.
4. **Desempenho:** FPS e 1% baixo dependem do notebook.
5. A integração ao cliente oficial (formas corretivas, porte e LOD no `character.gd`) **não foi feita e depende de autorização**.

**Execução encerrada. Aguardando a avaliação técnica e a homologação de Robson.**
