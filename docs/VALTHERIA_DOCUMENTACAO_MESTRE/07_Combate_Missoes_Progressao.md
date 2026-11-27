# 07 — Combate, Classes, Missões e Progressão

**Versão examinada:**
- `world.json` (0.17.0);
- `combat.gd`;
- banco: `game.quests`, `game.classes` e funções `game_kill2`, `game_kill3`, `game_quest_done`, `game_pvp`.

**Data:** 14/11/2026
Marcas: **[F]** fato comprovado · **[P]** proposta · **[C]** confirmar.

---

## 1. Classes [F]

| Dado | Valor |
|---|---|
| Classes no total | 159 (21 de base, nível 1; 46 de 2ª, nível 20; 46 de 3ª, nível 40; 46 de 4ª, nível 76) |
| Por raça | Humanos, elfos e elfos negros 17; orcs, halflings, homens-fera, Dragonitas, sylphs, nocturnos e gigantes 14; anões 10 |
| Exclusivas de raça (`excl`) | 66 |
| Arquétipos (`arch`) | 9: tanque 21, guerreiro 22, arqueiro 15, adaga 17, mago 26, curandeiro 22, xamã 22, monge 7, artesão 7 |
| Habilidades | 18 por arquétipo, liberadas nos níveis 1, 3, 5, 8, 12, 15, 20, 24, 28, 35, 40, 44, 48, 52, 58, 66, 76, 80 (162 no total) |
| Multiplicador por rank | 1 · 1,1 · 1,25 · 1,45 |

**Achado principal [F]:** todas as classes do mesmo arquétipo têm **as mesmas 18 habilidades**. Na prática há 9 conjuntos de jogo para 159 nomes de classe. Exemplo: "Templário" (humano) e "Pele de Ferro" (homem-fera) jogam igual, mudando só os atributos da raça e o elemento. É a maior redundância do sistema.

Tipos de habilidade:

| Tipo | Quantidade |
|---|---|
| Golpe (`hit`) | 54 |
| Reforço (`buff`) | 33 |
| Enfraquecimento (`debuff`) | 25 |
| Escudo | 8 |
| Zona | 8 |
| Cura | 7 |
| Armadilha | 6 |
| Corrente (`chain`) | 6 |
| Investida (`dash`) | 5 |
| Golpes múltiplos (`multi`) | 5 |
| Teleporte curto (`blink`) | 2 |
| Provocar (`taunt`) | 1 |
| Salto (`leap`) | 1 |
| Mana | 1 |

O nativo **não trata** `blink` nem `mana` (3 habilidades sem efeito) **[F]** (`combat.gd`, contagem de tipos).

### 1.1 Proposta [P]
Não criar classes novas. Dar a cada **linha de raça** de 2ª a 4ª classe de 2 a 4 habilidades próprias, ligadas ao elemento e à história. Exemplo: Templário com "Juramento da Aurora" (luz); Pele de Ferro com "Couro de Pedra" (terra). As 18 habilidades do arquétipo continuam como base.

## 2. Combate [F]

| Item | Como funciona hoje (`combat.gd`) |
|---|---|
| Ataque básico | Automático no alvo; alcance por tipo de arma (`weapons.range`: espada 2,6 m, lança 3,4 m, arco 22 m…) |
| Dano | `atk × mult × atk / (atk + def × 0,5) × (0,92 a 1,08)`, crítico de 6% com dano ×2; acerto aplicado 0,35 s depois (`pending`) |
| Elemento | Elemento da raça entra no dano; efeito visual por elemento |
| Recarga | Por habilidade, mostrada na barra |
| Colisão | Círculos simples (`world.resolve`); sem colisão entre monstros |
| Alvo | Clique ou tecla; o mais próximo |
| Estados | Atordoar, enfraquecido, escudo, reforços com duração |
| Animação | Golpes de espada, soco e magia para todas as armas |
| Som | **Nenhum** no nativo |
| Validação | Dano calculado **no cliente**. O servidor só recebe "matei um monstro de nível N, chefe sim ou não" (`game_kill3` → `kill2`) |

**Grupo (party):** não existe nos dois clientes. **PvP:** só na web (`game_pvp`). [F]

## 3. Inimigos [F]
Ver `04`, seção 5:
- 18 famílias no nativo e 33 na web;
- nível tirado da cidade mais próxima;
- chefe com 14× a vida.

Comportamento: agressão, perseguição e retorno ao ponto de nascimento. Não há habilidades de monstro.

## 4. Missões [F]

**63 missões no banco** (confere com o diagnóstico anterior). **Nenhuma no cliente nativo.** Na web estão em `quests.js`.

| Grupo (prefixo) | Quantidade | Objetivos | Níveis | Pré-requisito |
|---|---|---|---|---|
| Principais (`m01`–`m14`) | 14 | 7 de matar, 6 de chefe, 1 de chegar | 1–80 | Cadeia (13 com pré-requisito) |
| Secundárias e regionais (`s_`) | 23 | 8 de matar, 15 de entrega | 1–78 | Nenhum |
| Lendas (`l_`) | 8 | Chefes de lenda | 14–78 | Nenhum |
| Diárias (`d0`–`d5`) | 18 | Matar, chefe e entrega, por faixa | 1–80 | Diárias |
| Exploração | 0 (só 1 de "chegar") | — | — | — |

Recompensa: experiência × 50 e aurum × 50 no servidor, mais itens. **Falha comprovada:**
- missões de matar, de chefe e de chegar (**40 de 63**) concluem sem prova (`05`, S3);
- o texto das missões segue a "Era do Eclipse", enquanto os NPCs do nativo seguem o "Pacto do Véu" (ver `02`).

## 5. Progressão [F]
- Nível máximo 80.
- Tabela de experiência (`xpneed`) com 95 posições: nível 1 = 50; nível 20 = 66.289; nível 40 = 349.876; nível 60 = 925.834; nível 76 = 1.632.761.
- Taxa de experiência **50×** (`rate_xp`) **[C]**: é taxa de teste ou definitiva?
- Troca de classe nos níveis 20, 40 e 76.
- Atributos vêm da raça, da classe, do equipamento e do encantamento. Não há pontos de atributo distribuídos pelo jogador.
- Subclasse no nível 40: só no `DESIGN.md` (inexistente).

### 5.1 Tabela de balanceamento (monstro × jogador, `mobstats`)

| Nível | Vida do monstro | Ataque | Defesa | Experiência |
|---|---|---|---|---|
| 1 | 115 | 15 | 9,6 | 6 |
| 10 | 178 | 22,2 | 14,9 | 966 |
| 19 | 276 | 33,3 | 23,1 | 3.349 |
| 20 | **472** | 38,2 | **38,8** | 3.683 |

Salto de **+71% de vida e +68% de defesa** do nível 19 para o 20 (entrada no grau D). É proposital (grau novo), mas deve ser conferido em jogo. **[C]**

## 6. Plano de testes [P]

| Teste | Como | Situação |
|---|---|---|
| Combate individual | Captura automatizada + registro de dano por golpe | A fazer |
| Combate em grupo | Depende do sistema de grupo (inexistente) | Bloqueado |
| Latência | Medir o tempo de `rpc_call` (`game_kill3`, `game_save`) no notebook | A fazer (precisa do `registro.txt`) |
| Persistência | Sair e entrar; conferir HP, posição e inventário no banco | A fazer |
| Progressão | Script SQL simulando abates de 1 a 80 e contando o tempo | A fazer |
| Cliente × servidor | Conferir `recalc` do cliente contra `game.power` do servidor | A fazer |

## 7. Ordem recomendada
1. **E1:** validação no servidor (pré-requisito de tudo).
2. Missões no nativo (portar de `quests.js` com o texto já unificado pela Bíblia, E2).
3. Habilidades próprias por linha de raça.
4. Grupo → PvP → cerco.

## 8. Decisões
- **D26:** taxa de experiência 50× é definitiva?
- **D27:** aprovar habilidades próprias por linha de raça, em vez de classes novas.
- **D28:** portar as missões para o nativo antes ou depois da troca de texto da Bíblia (E2)?
