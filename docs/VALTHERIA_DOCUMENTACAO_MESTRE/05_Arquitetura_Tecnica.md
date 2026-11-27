# 05 — Arquitetura Técnica e Integração

**Versão examinada:** nativo 0.17.0 (`29d9507`) · Supabase `irpzdghikvoezfeodyiq` (Postgres 17) · **Data:** 14/11/2026
**Método:** leitura do código, consultas **somente de leitura** ao catálogo do banco (tabelas, RLS, funções, permissões) e leitura do código-fonte das funções do servidor.
Marcas: **[F]** fato comprovado · **[P]** proposta · **[C]** confirmar.

---

## 1. Diagrama de arquitetura [F]

```
                    ┌─────────────────────────── Supabase ───────────────────────────┐
 ┌──────────────┐   │  Auth (e-mail/senha)  ──► game.accounts (is_gm)                │
 │ Cliente Godot│──►│  REST /rest/v1/rpc/game_*  (40 funções SECURITY DEFINER)       │
 │  0.17.0      │   │        │  game.ch() confere dono do personagem                 │
 │ (Windows)    │   │        ▼                                                        │
 │              │   │  Esquema game (22 tabelas, RLS ligado, cliente sem acesso      │
 │              │◄─►│  direto)                                                        │
 │              │   │  Realtime: canal "realtime:mundo" (broadcast de posição +      │
 └──────────────┘   │  presença)                                                     │
 ┌──────────────┐   │  game.chat / game.events / game.node_state (consulta e         │
 │ Cliente web  │──►│  realtime)                                                      │
 │ Three.js r170│   └────────────────────────────────────────────────────────────────┘
 │ (congelado)  │
 └──────────────┘   Dados estáticos do cliente: cliente-godot/data/world.json (gerado
                    da web)
```

## 2. Estrutura do cliente Godot [F]

| Item | Situação |
|---|---|
| Cena | Uma só: `main.tscn` com `main.gd`. Todo o resto é criado por código |
| Autoloads | **Nenhum.** `main.gd` cria e liga os módulos |
| Módulos (linhas) | `world.gd` 1762 · `ui.gd` 1627 · `main.gd` 1216 · `npcs.gd` 1028 · `cidade.gd` 945 · `combat.gd` 769 · `interiores.gd` 542 · `character.gd` 576 · `icon_button.gd` 531 · `especial.gd` 485 · `fx.gd` 226 · `net.gd` 210 · `atmos.gd` 177 · `social.gd` 125 · `punho.gd` 46 = **10.265 linhas** |
| Dados | `data/world.json` (classes, itens, receitas, loja, monstros, raças); `height.bin`, `splat.png`, `tint.png`, `mapa.json` (gerados por `ferramentas/*.py`) |
| Recursos | `assets/chars` 38 MB · `assets/world` 20 MB · `assets/armas` 248 KB |
| Testes | Argumentos de linha de comando para capturas headless (`--play`, `--at`, `--shot`…). **Não há testes automáticos de regressão** |

### 2.1 Mapa de dependências [F]

```
main.gd ─┬─ net.gd (HTTP + WebSocket)
         ├─ world.gd ─┬─ cidade.gd, especial.gd
         │            └─ data/*.json/bin/png
         ├─ character.gd ── punho.gd, assets/chars
         ├─ combat.gd ──── character.gd, fx.gd, net.gd, world.gd
         ├─ npcs.gd ────── character.gd, world.gd
         ├─ interiores.gd ─ character.gd
         ├─ social.gd ──── net.gd (presença, chat)
         ├─ atmos.gd ───── world.gd
         └─ ui.gd ──────── icon_button.gd, character.gd, net.gd
```

## 3. Autenticação [F]
- Login por `/auth/v1/token?grant_type=password` com nome + domínio fixo (`net.gd`).
- O cliente guarda `access_token` e `refresh_token`. Ao receber 401, renova o token uma vez (`net.gd` linhas 85–89).
- A chave no cliente é a **anon** (conferida no código: `role = anon`). **Nenhuma chave de serviço no cliente.**
- Conta GM: `game.accounts.is_gm`, conferida no servidor por `gm_ok`.

## 4. Banco de dados [F]

### 4.1 Tabelas (esquema `game`, 22)

| Grupo | Tabelas | Linhas (estimativa do catálogo) |
|---|---|---|
| Conteúdo | `races`, `classes` (159), `items` (332), `recipes` (196), `shop` (47) — contagem real em 14/11, `quests` (63), `boss_drops` (62), `nodes` (2.649), `towns`, `teleports`, `castles` | — |
| Jogadores | `accounts`, `characters` (3), `inventory` (105) | 2 usuários em `auth.users` |
| Social | `clans`, `clan_members`, `clan_invites`, `chat`, `events` | — |
| Estado do mundo | `node_state`, `market` | — |
| Auditoria | `gm_log` (154) | — |

Relações (chaves estrangeiras):
- `accounts → auth.users`;
- `characters → accounts, classes`;
- `inventory → characters, items`;
- `recipes, shop, market, boss_drops → items`;
- `clans, clan_members, clan_invites → characters, clans`;
- `castles → clans`;
- `node_state → nodes`.

### 4.2 RLS e privilégios
- **RLS ligado nas 22 tabelas.** Só 3 têm política: `chat`, `events` e `node_state` (leitura para o realtime). As outras não têm política, ou seja, o cliente **não lê nem escreve direto**. Tudo passa pelas funções. Modelo correto.
- As 40 funções `public.game_*` são `SECURITY DEFINER`, **não executáveis por `anon`** (só usuário logado), e usam `game.ch(p_char)`, que confere se o personagem é do usuário.
- Há 3 permissões de tabela do esquema `game` para `anon` ou `authenticated` **[C]** (detalhar na etapa E1).

### 4.3 Divergência entre cliente e banco

| Dado | `world.json` (nativo) | Banco | Efeito |
|---|---|---|---|
| Itens | 332 | 332 | Iguais (**correção de 14/11**: o 277 era estimativa do catálogo) |
| Receitas | 196 | 196 | Iguais (correção de 14/11) |
| Loja | 47 | 47 | Iguais (correção de 14/11) |
| Cidades | 15 | 11 | `in_safe` do servidor não conhece 4 cidades: PvP liberado lá **[C]** |
| Castelos | 10 | 3 | Cerco só possível em 3 |

## 5. Sincronização [F]

| Dado | Persistente? | Como sincroniza | Autoridade hoje |
|---|---|---|---|
| Posição | Sim, em `characters.x/z` | `game_save` a cada 20 s e ao sair; broadcast a cada 0,2 s (só para ver os outros) | **Cliente** |
| HP e MP | Sim | `game_save` | **Cliente** (sem teto) |
| Experiência e nível | Sim | `game_kill3` (`kill2`) por monstro morto | Servidor calcula, **cliente informa o monstro** |
| Inventário e equipamento | Sim | `game_equip`, `unequip`, `use`, `craft`, `shop_buy`, `npc_sell` | Servidor |
| Aurum | Sim | Idem | Servidor |
| Missões | Sim, em `characters.quests` | `game_quest_done` (só web) | Servidor confere pré-requisito e itens, **não confere monstros mortos** |
| Classe | Sim | `game_class_change` | Servidor |
| Monstros e NPCs | **Não** (cada cliente gera os seus) | — | Cliente (mundo não compartilhado) |
| Recursos de coleta | Sim, em `node_state` | `game_gather` (só web) | Servidor (distância de 6 m e 60 m da posição salva) |
| Chat | Sim | `game_chat` + consulta | Servidor |
| Outros jogadores | Não | Broadcast + presença | — |

**Reconexão:**
- O WebSocket fechado **não reconecta**: `rt_join` só é chamado ao entrar no jogo (`main.gd:408`). Se cair, o jogador deixa de ver os outros até sair e entrar de novo.
- O HTTP renova o token uma vez.
- Não há fila de repetição para chamadas que falham.

## 6. Riscos de segurança comprovados [F]

| # | Risco | Evidência | Gravidade |
|---|---|---|---|
| S1 | `game_save` aceita **qualquer HP e MP** (só exige ≥ 0) e posição em qualquer ponto do mapa | Código da função: `hp = greatest(0, p_hp)` | **Crítica** |
| S2 | `game_kill2` aceita `p_boss` e o nível do monstro vindos do cliente (trava de 0,7 s e nível no máximo +12) | Auditoria anterior + `game_kill3` chama `kill2` | **Crítica** |
| S3 | `game_quest_done` conclui missões de matar e de chegar **sem prova** (só `turnin` confere itens) | Código da função | **Alta** (40 de 63 missões) |
| S4 | `game_pvp` recebe o multiplicador `p_mult` do cliente (limitado de 0,5 a 5) | Código da função | Média |
| S5 | Posição não validada contra velocidade: teleporte por `game_save` | S1 | Alta |
| S6 | Sem proteção contra chamada repetida por chave de idempotência; só travas de tempo (`last_gather`, `last_pvp`) | Código | Média |
| S7 | Cidades novas fora do banco (zona segura) | 4.3 | Média |

## 7. Responsabilidades-alvo [P]

| Camada | Faz | Não faz |
|---|---|---|
| Cliente | Desenho, interface, entrada, predição de movimento e do golpe, efeitos | Decidir dano final, experiência, drop, HP salvo |
| Servidor (funções) | Validar movimento por velocidade máxima e tempo, combate por sessão de alvo, recompensas, inventário, missões e transações | Desenho |
| Banco | Guardar estado com RLS e restrições (`check`) | Lógica de cliente |

## 8. Plano de integração (etapa E1) [P]

Cada item preserva as funções antigas, para a web continuar funcionando, e cria versões novas que o Godot passa a usar:

| Passo | Mudança | Critério de aceitação | Teste |
|---|---|---|---|
| E1.1 | `game_save2`: limita HP/MP ao máximo de `game.power(c)`; rejeita deslocamento acima de velocidade × tempo desde o último save (+ margem) | HP falso volta ao máximo; teleporte falso é recusado | Chamadas SQL com valores falsos; jogo salva normalmente |
| E1.2 | `game_engage` + `game_kill4`: o servidor sorteia o monstro e o nível pela posição e guarda o "alvo engajado". A morte só vale para o alvo engajado e depois do tempo mínimo de luta | `p_boss` e nível do cliente deixam de ter efeito | Matar monstro normal e chefe; tentar falsificar |
| E1.3 | Contador de abates no servidor (`characters.kills`) e `game_quest_done2` que confere o contador | Missão de matar só conclui com abates reais | Missões m01 e s_ |
| E1.4 | Sincronizar `towns` (15), `castles` (10), `items` e `recipes` do `world.json` para o banco por migração | Contagens iguais nos dois lados | Consulta de contagem; forja das 30 receitas novas |
| E1.5 | Reconexão do WebSocket com espera crescente | Ao derrubar a rede, os outros jogadores voltam a aparecer | Teste desligando a rede |

**Arquivos:**
- `cliente-godot/scripts/net.gd`, `combat.gd`, `main.gd`;
- migrações novas no Supabase;
- `ferramentas/` (script de sincronização de dados).

**Não altera:** web, tabelas existentes (só acrescenta colunas), saves atuais.

## 9. Riscos técnicos gerais
1. **Duas fontes de dados** (`world.json` e banco) sem processo de sincronização.
2. **Um único `main.gd`** coordena tudo e não há testes automáticos: uma mudança pode quebrar sistemas distantes.
3. **Mundo não compartilhado:** cada jogador vê monstros diferentes. Grupo, PvE em grupo e chefes de mundo exigem autoridade no servidor (Edge Function ou servidor dedicado) **[C]**: decisão de arquitetura futura.
4. **Vulkan e D3D12 instáveis** no notebook de teste (registro anterior). `registro.txt` pendente (D18).
