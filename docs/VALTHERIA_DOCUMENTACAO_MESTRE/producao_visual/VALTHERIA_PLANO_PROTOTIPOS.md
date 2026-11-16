# VALTHERIA — Plano de Protótipos

Os protótipos estão em ordem de importância. Os primeiros validam vários sistemas ao mesmo tempo.
O tempo é estimado em **sessões de trabalho do Claude** (uma sessão = uma rodada longa como as dos últimos dias), mais o tempo de avaliação do Robson. **Nada começa sem autorização expressa.**

Todos ficam isolados na branch `v3-prototipos` (a criar a partir da `main`) e em `assets_v3/`. Nenhum substitui arquivo oficial.

---

## Conjunto de referência (Etapa 1)

A orientação do Robson é validar primeiro um conjunto pequeno: masculino, feminino, equipamento, criatura e cenário. Os protótipos P1–P6 e P9 formam esse conjunto.

### P1 — Humano masculino completo
| Campo | Conteúdo |
|---|---|
| Objetivo | Provar a cadeia inteira: corpo V2 + rosto + pele + olhos + sobrancelha + cabelo + **roupa de fantasia** ligados aos 65 ossos e rodando as 28 animações no Godot |
| Recursos | Blender, MPFB2, MakeHuman CC0, Krita; nenhum crédito |
| Arquivos novos | `assets_v3/personagens/pc_humano_m.glb`, `rp_aldeao_tunica_m.glb`, `rp_aldeao_calca_m.glb`, `rp_botas_couro_m.glb`, `ca_curto_01.glb`; `ferramentas/v3/ligar_pecas.py` (versão do `ligar_esqueleto.py` para várias malhas e texturas); `testes/prototipos/p1_humano.tscn`; `fontes/personagens/pc_humano_m.blend` |
| Dependências | V2 (feita); decisão D50 (roupas: repintar CC0) |
| Tempo | 2–3 sessões |
| Riscos | Roupa atravessar o corpo em poses extremas; texturas CC0 com aparência fotográfica demais |
| Testes | Prancha frente/lado/costas; 28 animações com a métrica de deformação; triângulos, materiais e chamadas de desenho |
| Aprovação | Nenhuma animação pior que o corpo atual; sem atravessamento visível em parado, andar, correr e atacar; aprovação visual do Robson |
| Reutilização | Base de todas as raças humanoides |

### P2 — Humana feminina completa
Igual ao P1, com o corpo feminino, o cabelo longo trançado e a roupa feminina. Roda junto com o P1, porque divide a ferramenta. **Tempo:** +1 sessão.

### P3 — Conjunto de roupas
| Campo | Conteúdo |
|---|---|
| Objetivo | 3 conjuntos iniciais por gênero (aldeão, aventureiro de couro, aprendiz de magia), na cor de cultura humana (azul-ardósia até 25%) |
| Recursos | Malhas CC0 remodeladas + pintura própria |
| Arquivos novos | `rp_aldeao_*`, `rp_aventureiro_*`, `rp_aprendiz_*` (m/f) |
| Dependências | P1/P2 |
| Tempo | 2 sessões |
| Riscos | Repetição entre conjuntos; peso de 3 materiais por personagem |
| Aprovação | Silhuetas distinguíveis a 20 m; até 3 materiais por personagem vestido |
| Reutilização | Roupa inicial de todas as raças (por ajuste de forma) |

### P4 — Uma armadura
| Campo | Conteúdo |
|---|---|
| Objetivo | Armadura de placas em 4 peças (peito, braços, pernas, elmo) com **3 graus visuais** (D ferro, B aço azulado com ornamento, S platina com runas) sobre o mesmo modelo |
| Recursos | Modelagem própria no Blender; nenhum crédito |
| Arquivos novos | `assets_v3/equipamentos/ar_placas_{peito,bracos,pernas,elmo}_m.glb` + materiais por grau |
| Dependências | P1 |
| Tempo | 2–3 sessões |
| Riscos | Placas rígidas deformando nos ombros e no quadril; custo de triângulos |
| Aprovação | Sem quebra de placa nas 28 animações; diferença de grau visível a 10 m |
| Reutilização | Modelo de armadura pesada para todas as raças; padrão de graus para os 332 itens |

### P5 — Uma espada
| Campo | Conteúdo |
|---|---|
| Objetivo | Espada longa com identidade de Valtheria (guarda com motivo da Árvore), 1 material, 3 graus por material e ornamento |
| Arquivos novos | `wp_espada_longa_{d,b,s}.glb` |
| Dependências | Nenhuma (pode começar junto com o P1) |
| Tempo | 1 sessão |
| Aprovação | Encaixe correto pela tabela `GRIP` na mão, nas costas e na cintura, nas 8 raças |
| Reutilização | Referência para machado, lança, cajado e adaga |

### P6 — Uma criatura comum: **javali**
| Campo | Conteúdo |
|---|---|
| Objetivo | Substituir, **só no protótipo**, o touro usado como javali por um javali próprio, com 6 animações |
| Recursos | Modelagem própria ou Meshy (orçamento: 50–60 créditos, cabe no plano grátis, **só com autorização**) |
| Arquivos novos | `cr_javali.glb`, `cr_javali_anims.glb` |
| Dependências | Nenhuma |
| Tempo | 2 sessões |
| Riscos | Animação de quadrúpede é a parte mais trabalhosa |
| Aprovação | Silhueta reconhecível a 30 m; 6 animações sem quebra |
| Reutilização | Base do Rei Javali (guardião do Fragmento da Aurora, protótipo P8) |

### P9 — Pequena área de cenário
| Campo | Conteúdo |
|---|---|
| Objetivo | Uma clareira de 60 × 60 m perto da Vila Aurora: terreno com 6 camadas, 3 árvores com LOD, rochas novas, uma casa modular e iluminação ajustada |
| Recursos | Texturas CC0 (Poly Haven/ambientCG), modelagem própria |
| Arquivos novos | `ve_carvalho_{p,m,g}.glb`, `ad_rocha_*`, `ed_casa_modular_*`, `tx_*`; cena `testes/prototipos/p9_clareira.tscn` |
| Dependências | Nenhuma |
| Tempo | 2–3 sessões |
| Aprovação | Antes/depois na mesma câmera; chamadas de desenho e triângulos medidos; aprovação visual |
| Reutilização | Kit de natureza para todas as regiões |

---

## Etapa 2 (depois que o conjunto de referência for aprovado)

| # | Protótipo | Objetivo | Tempo | Dependências | Créditos |
|---|---|---|---|---|---|
| P7 | Monstro de maior porte: **Golem de Pedra** | Primeira família não humanoide grande; substitui o "gigante cinza" só no protótipo | 2–3 sessões | P6 (pipeline de criatura) | Opcional: 50–85 |
| P8 | Um guardião: **Rei Javali** (Fragmento da Aurora) | Identidade própria sobre a base do javali do P6: escala 2,5×, presas e placas de casca, brasas de aurora, 2 animações exclusivas. É o primeiro guardião que o jogador encontra (nível 1–19) e reaproveita o P6 | 3 sessões | P6 | Opcional: 50–80 |
| P10 | Ambiente de cidade | Um quarteirão da capital trocando as caixas de `cidade.gd` por módulos, sem mudar o desenho da cidade | 3–4 sessões | P9 (kit modular), P1 (escala) | 0 |

---

## Proposta de execução da Etapa 1 (aguarda autorização)

**Branch:** `v3-prototipos`, criada a partir da `main` (29d9507). A `main` não muda.

**Ferramentas:** Blender 5.3 (bpy), MPFB2 2.0.18, MakeHuman system assets CC0 (já baixados e conferidos), Godot 4.7.2, Krita (pintura) e texturas CC0 do Poly Haven/ambientCG (download só com autorização, cada uma registrada).

**Arquivos novos da Etapa 1:**

```
cliente-godot/assets_v3/personagens/   pc_humano_m.glb, pc_humano_f.glb, ca_curto_01.glb, ca_tranca_longa.glb
cliente-godot/assets_v3/personagens/   rp_aldeao_{tunica,calca}_{m,f}.glb, rp_botas_couro_{m,f}.glb
cliente-godot/assets_v3/personagens/   rp_aventureiro_*_{m,f}.glb, rp_aprendiz_*_{m,f}.glb
cliente-godot/assets_v3/equipamentos/  ar_placas_{peito,bracos,pernas,elmo}_m.glb, wp_espada_longa_{d,b,s}.glb
cliente-godot/assets_v3/criaturas/     cr_javali.glb, cr_javali_anims.glb
cliente-godot/assets_v3/ambientes/     ve_carvalho_{p,m,g}.glb, ad_rocha_{01..04}.glb, ed_casa_modular_*.glb
cliente-godot/assets_v3/texturas/      tx_*.png (CC0, com fonte registrada)
cliente-godot/ferramentas/v3/          ligar_pecas.py, medir_assets.py, prancha.py
cliente-godot/testes/prototipos/       p1_humano.tscn, p9_clareira.tscn, comparar.tscn
fontes/                                .blend e pinturas de cada asset
CREDITOS.md                            uma linha nova por fonte usada
```

**Ordem:** P1+P2 (com P5 em paralelo) → P3 → P4 → P6 → P9. Cada passo termina com prancha, medição e relatório. O seguinte só começa com o "aprovado" do Robson.

**Estimativa total da Etapa 1:** 12 a 15 sessões, sem custo de ferramenta e sem créditos (se o javali for modelado à mão).
