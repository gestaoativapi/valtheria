# 10 — Roadmap e Controle de Execução

**Data:** 14/11/2026 · **Linha de base:** nativo 0.17.0 (`29d9507`), banco conferido nesta data.
Situações:
- **Concluída**
- **Aguardando aprovação** (pronta para começar quando o Robson aprovar)
- **Bloqueada** (depende de outra tarefa ou de algo do Robson)
- **Pendente**

---

## 1. Fases

| Fase | Nome | Situação |
|---|---|---|
| 0 | Auditoria e inventário | **Concluída** (este conjunto de documentos, sem nenhuma alteração no jogo) |
| 1 | Fundação técnica | Aguardando aprovação |
| 2 | Personagens e identidade visual | Bloqueada (D19 Gemini, D22 ordem) |
| 3 | Mundo e ambientação | Aguardando decisões D08–D14 |
| 4 | Gameplay | Bloqueada pela Fase 1 |
| 5 | Conteúdo e efeitos | Bloqueada pela Bíblia (D03–D07) |
| 6 | Testes e preparação | Os testes começam na Fase 1 e crescem a cada etapa |

## 2. Quadro de tarefas

| ID | Fase | Tarefa | Prioridade | Situação | Responsável | Dependências | Arquivos | Critério de aceitação | Testes | Evidência |
|---|---|---|---|---|---|---|---|---|---|---|
| T0.1 | 0 | Auditoria geral + 10 documentos | Crítica | Concluída | Claude | — | Pasta `VALTHERIA_DOCUMENTACAO_MESTRE` | Documentos entregues e aprovados | Revisão do Robson | `00_Auditoria_Geral.md` |
| T0.2 | 0 | Salvar a documentação no repositório (`docs/`) | Alta | Aguardando aprovação (D02) | Claude | Aprovação | `docs/VALTHERIA_DOCUMENTACAO_MESTRE/*` | Pasta no GitHub | `git log` | — |
| T1.1 | 1 | `game_save2` com teto de HP/MP e limite de velocidade | Crítica | Aguardando aprovação (D01) | Claude | D01 | Migração, `net.gd` | Valores falsos recusados | SQL + jogo | — |
| T1.2 | 1 | `game_engage` + `game_kill4` (monstro decidido no servidor) | Crítica | Aguardando aprovação | Claude | T1.1 | Migração, `combat.gd` | `p_boss`/nível do cliente sem efeito | SQL + jogo | — |
| T1.3 | 1 | Contador de abates + `game_quest_done2` | Alta | Aguardando aprovação | Claude | T1.2 | Migração | Missão de matar exige abates reais | SQL | — |
| T1.4 | 1 | Sincronizar cidades, castelos, itens, receitas e loja no banco | Alta | Aguardando aprovação | Claude | — | Migração, `ferramentas/` | Contagens iguais | Consulta de contagem | — |
| T1.5 | 1 | Reconexão do WebSocket | Média | Aguardando aprovação | Claude | — | `net.gd` | Reconecta após queda | Teste de rede | — |
| T1.6 | 1/6 | Testes de regressão no GitHub Actions | Alta | Aguardando aprovação | Claude | — | `.github/workflows`, script de teste | Build falha se houver erro | Execução no CI | — |
| T1.7 | 1 | Medição no notebook real | Alta | Bloqueada | Robson → Claude | D18 (`registro.txt`) | — | FPS por cena | Tabela `09` | — |
| T2.1 | 2 | Silhuetas: homens-fera, elfos, orcs, gigantes | Alta | Bloqueada | Robson (Gemini) → Claude (Meshy) | D19, D22 | `assets/chars`, `character.gd` | Raças distinguíveis na prancha | Prancha + jogo | — |
| T2.2 | 2 | Armadura feminina pesada + roupas de anão e Dragonita | Média | Aguardando aprovação | Claude | — | `assets/chars`, `character.gd` | Troca visual por armadura | Prancha | — |
| T2.3 | 2 | Modelos de punhos, garras, cajado e cetro | Alta | Aguardando aprovação | Claude | — | `assets/armas`, `character.gd` | 12 itens com visual | Prancha | — |
| T2.4 | 2 | Monstros com modelo próprio (golem `x_brute`, dragão, esqueleto, ent, demônio) | Alta | Aguardando aprovação | Claude | Créditos Meshy **[C]** | `combat.gd`, `assets/world` | Nenhum monstro com corpo humano recolorido | Prancha | — |
| T2.5 | 2 | Animações por tipo de arma | Média | Aguardando D29 | Claude | D29 | `assets/chars`, `character.gd` | Arco puxa a corda; lança estoca | Captura | — |
| T3.1 | 3 | M1–M7 do documento de mundo (rios, estradas, neve na Fortaleza, níveis) | Média | Aguardando D08–D14 | Claude | Decisões | `ferramentas/*.py`, `data/*`, `world.gd` | Ver `03` | Mapa + capturas | — |
| T4.1 | 4 | Missões no nativo | Alta | Bloqueada | Claude | T1.3, D28 | `quests` (novo), `ui.gd` | 63 missões jogáveis | Fluxo completo de m01 | — |
| T4.2 | 4 | Habilidades próprias por linha de raça | Média | Aguardando D27 | Claude | T1.2 | `world.json`, `combat.gd` | 2–4 habilidades por linha | Teste de combate | — |
| T4.3 | 4 | Grupo, depois PvP, depois cerco | Média | Bloqueada | Claude | T1.x | `net.gd`, `combat.gd`, `ui.gd` | — | — | — |
| T5.1 | 5 | Aplicar a Bíblia aos textos (E2) | Alta | Aguardando D03–D07 | Claude | Decisões | `npcs.gd`, `quests.js`→nativo | Uma única história | Leitura | — |
| T5.2 | 5 | Biblioteca de efeitos e as 64 habilidades sem efeito | Média | Bloqueada | Claude | T4.2 | `fx.gd` | Toda habilidade com efeito | Captura | — |
| T5.3 | 5 | Áudio | Média | Aguardando D30 | Claude | — | Novo módulo | Som em golpe, magia e ambiente | Jogo | — |
| T6.1 | 6 | Otimização (plano do `09`) | Alta | Bloqueada | Claude | T1.7 | Vários | Métricas antes e depois | Tabela `09` | — |

## 3. Modelo de relatório de cada etapa
Cada etapa termina com:
1. O que foi analisado
2. O que foi alterado
3. Arquivos modificados
4. O que foi preservado
5. Testes feitos
6. Problemas encontrados
7. Pendências
8. Próxima etapa recomendada

## 4. Controle de mudanças
Exigem aprovação antes de começar:
- qualquer migração no banco;
- troca de sistema;
- remoção de item, função ou arquivo;
- mudança visual ampla.

Correções pequenas dentro de uma etapa aprovada seguem sem nova aprovação, mas vão no relatório.

## 5. Próxima etapa recomendada
**T1.1 a T1.5 (E1, servidor)**, junto com **T1.6 (testes)**. São as únicas tarefas sem bloqueio externo e protegem todo o resto. Aguardando a resposta da **D01**.
