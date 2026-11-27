# 16 — D43: preparação do projeto Supabase de testes (antes da criação)

**Data:** 14/11/2026
**Situação:** preparação concluída. **O projeto ainda NÃO foi criado** (ver item 1).
**Garantia:** a `main` não foi alterada, nada foi publicado e o banco de produção não recebeu nenhuma alteração (só consultas de leitura).

---

## 0. Correção importante de um número dos relatórios anteriores [F]

Nos documentos 00, 05 e 06 eu tinha escrito que o banco tinha **277 itens, 166 receitas e 43 itens de loja**, contra 332, 196 e 47 no cliente. **Estava errado.**

**Causa:** usei a *estimativa* de linhas do catálogo do Postgres, e não a contagem real.

**Contagem real de hoje:**

| Dado | Banco | Cliente |
|---|---|---|
| Itens | **332** | 332 |
| Receitas | **196** | 196 |
| Loja | **47** | 47 |

São iguais. As únicas diferenças reais são **cidades (11 × 15)** e **castelos (3 × 10)**. Os documentos 00, 05, 06 e o prompt do gestor já foram corrigidos.

## 1. Custo, região e plano (condição 1)

| Item | Valor |
|---|---|
| Organização | "ativaonepi-cloud's Org" (`kicakpuibskuujblrcpq`) |
| Plano | **Gratuito** (`free`) |
| Projetos hoje | 1 ("mmorpg-teste", produção). O plano gratuito permite 2 ativos |
| Nome proposto | `valtheria-testes` |
| Região proposta | **us-east-1**, a mesma da produção, para a latência do teste ser comparável. Alternativa: `sa-east-1` (São Paulo), mais perto de você |
| Custo esperado | **US$ 0** (plano gratuito) |

**Atenção:**
- A ferramenta do Supabase **não tem um passo só de orçamento**. O preço aparece na própria chamada de criação.
- Se o preço for **acima de zero**, ela para e pede confirmação, e eu trago o valor para você antes de seguir.
- Se o preço for **zero**, ela **cria na hora**.

Por isso só vou chamar a criação depois do seu "pode criar" (**D45**).

## 2. Revisão das 14 migrações (condições 2 e 3) [F]

| # | Migração | O que faz | Operações destrutivas | Ref. da produção | Contas ou personagens reais | Reaplicar? |
|---|---|---|---|---|---|---|
| 1 | `game_schema` | Esquema `game`: 18 tabelas, funções, RLS, política de leitura, gatilho de cadastro, publicação do tempo real | `drop policy if exists` e `drop trigger if exists` (só recriam); `delete` apenas **dentro** de funções | Nenhuma | Não. Os `insert`/`update` em characters estão **dentro** de funções | Sim |
| 2 | `game_seed_base` | Conteúdo base: raças, classes, itens, missões, receitas, loja, teleportes, cidades | `delete from` em tabelas de **conteúdo**, antes de inserir (vazias num projeto novo) | Nenhuma | Não | Sim |
| 3 | `valtheria_look` | Aparência na criação de personagem | Não | Nenhuma | Não | Sim |
| 4 | `valtheria_v3_rates_bossdrops` | Taxas, `boss_drops`, abates | Não | Nenhuma | Não | Sim |
| 5 | `valtheria_v4_enchant_daily` | Encantamento, diárias | Não | Nenhuma | Não | Sim |
| 6 | `v6_enchant_16` | Encantamento +16 | Não | Nenhuma | Não | Sim |
| 7 | `v7_era_neon` | Itens, drops e teleportes da Era Neon | Não | Nenhuma | Não | Sim |
| 8 | `v9_clans_castles` | Clãs e castelos | `delete` só dentro de funções | Nenhuma. Cita `service_role` só como **nome de papel** no `grant` (não é chave) | Não | Sim |
| 9 | `v11_armas_novas` | Armas novas, receitas, loja | Não | Nenhuma | Não | Sim |
| 10 | `v13_gm_edit` | Função de edição do GM | Não | Nenhuma. `service_role` só no `grant` | Não | Sim |
| 11 | `fase1_validacao_servidor` | Fase 1: funções seguras, cidades, monstros, alertas | Não | Nenhuma | Não | Sim |
| 12 | `fase1_kill4_guarda_alertas` | Ajuste do `game_kill4` | Não | Nenhuma | Não | Sim |
| 13 | `fase1_portais_save2` | Portais e `game_save2` | Não | Nenhuma | Não | Sim |
| 14 | `backup_20261114_antes_publicacao_fase1` | Cópia de jogadores da produção | — | — | **Contém dados reais de jogadores** | **NÃO** (fica de fora) |

**Conclusão:** as 13 migrações a reaplicar não destroem nada num projeto novo, não citam a produção e não criam contas nem personagens.

## 3. O que pode faltar nas migrações, e como garantir o mesmo conteúdo (condições 4, 5 e 6)

Alguns ajustes foram feitos fora do histórico de migrações (por exemplo, os **2.649 recursos de coleta** em `nodes` não aparecem em nenhuma migração). Por isso, depois de reaplicar:

1. **Funções:** comparo a impressão digital das **62 funções** (`game.*` e `public.game_*`) entre produção e testes. Se alguma for diferente, copio a definição atual da produção.
2. **Tabelas e colunas:** comparo coluna por coluna as 26 tabelas de jogo.
3. **Conteúdo:** copio da produção, **só por leitura**, as tabelas de conteúdo e confiro a contagem:

| Tabela | Linhas na produção | Copiar? |
|---|---|---|
| races | 21 | Sim |
| classes | 159 | Sim |
| items | 332 | Sim |
| recipes | 196 | Sim |
| shop | 47 | Sim |
| quests | 63 | Sim |
| boss_drops | 81 | Sim |
| nodes | 2.649 | Sim |
| towns | 11 | Sim |
| teleports | 47 | Sim |
| castles | 3 | Sim, **sem dono** (coluna `owner` vazia, porque os clãs são de jogadores) |
| cidades, mob_fams, portais | 15, 18, 2 | Sim |
| **accounts, characters, inventory, market, chat, events, gm_log, clans, clan_members, clan_invites, node_state, alertas, bkp_*** | — | **NÃO** (dados de jogadores) |

4. **Contas no projeto de testes:** você cria pela tela de cadastro do próprio jogo de teste. Se quiser uma conta GM de teste, eu marco `is_gm` **só no projeto de testes**, com a sua autorização.

## 4. Trava contra a produção (condições 7, 8, 9 e 10) — pronta e testada [F]

Ramificação `fase1-servidor`, commit `44c29bd`.

| Proteção | Como funciona | Teste |
|---|---|---|
| Só chave pública | O executável recebe só a chave **anon** do projeto de testes. Nenhuma chave `service_role` ou administrativa entra no jogo ou no repositório | Revisão do código |
| Executável de teste só com o projeto de testes | O GitHub só gera o executável se existir `teste/ambiente_teste.env` com o endereço de testes. Ele troca `URL`, `KEY` e `AMBIENTE` **só no executável de teste** | Sem o arquivo, o executável não é gerado |
| Bloqueio no GitHub | Se o endereço ou a chave forem os da produção, o GitHub **para com erro** | Regra no workflow |
| Bloqueio no próprio jogo | Se `AMBIENTE = "testes"` e o endereço ou a chave forem os da produção, o jogo mostra um aviso e **fecha** | **Testado:** forcei a produção e apareceu "Executável de TESTE apontando para a PRODUÇÃO: abertura bloqueada" |
| Faixa na tela | "AMBIENTE DE TESTES — servidor de testes (não é o jogo oficial)" no alto de todas as telas | **Testado:** `imagens/Ambiente_de_Testes_Faixa.png` |
| Jogo oficial | Na `main` nada muda. O valor padrão é `AMBIENTE = "producao"` e a faixa não aparece | Testes automáticos passaram |

**Aviso importante:** o executável de teste gerado **antes** desta trava ("Valtheria-TESTE-fase1-servidor", de 14/11 às 10h18) **aponta para a produção**. **Não use.** Ele expira sozinho em 14 dias. Apagá-lo antes depende da sua autorização (**D46**).

## 5. Depois da criação: validações previstas (com evidência)
1. **Isolamento:** endereço e chave do projeto de testes ≠ produção. Contagem e impressão digital de `characters`, `inventory`, `alertas` e `gm_log` da **produção** antes e depois de todos os testes: **sem mudança**.
2. **Paridade:** 62 funções iguais e conteúdo com as mesmas contagens da seção 3.
3. **Cadastro e login** no jogo de teste.
4. **Personagem:** criar, salvar, sair e voltar.
5. **Inventário, experiência e recompensas:** loja, forja, abates.
6. **Segurança da Fase 1:** os 11 casos, agora pelo jogo real, com uma conta comum.
7. **Reconexão:** queda de rede de 20 s.
8. **Conteúdo e missões:** dados conferidos. A janela de missões ainda não existe no jogo novo (etapa T4.1); as missões são testadas pelas funções do servidor.
9. **Benchmark no notebook** (D44).

## 6. Benchmark: 40 personagens (pedido da D42) [F]
- Ramificação `v2-prova-visual`, commit `229fe0a`. Acrescentei duas variantes **diagnósticas** com 40 personagens: atual completo e corpo V2. Não há meta de FPS para elas.
- Teste curto aqui: funciona. Com 40 atuais completos, foram cerca de 3.578 chamadas de desenho por quadro, contra 1.868 com 20.
- **Regra registrada:** a malha V2 nua **não serve** como prova de otimização. A comparação final será entre personagens **completos** e no notebook.

## Decisões novas
- **D45:** "pode criar" o projeto `valtheria-testes`, plano gratuito, região **us-east-1** (ou sa-east-1). Se o Supabase mostrar custo acima de zero, eu paro e trago o valor.
- **D46:** apagar o executável de teste antigo, que aponta para a produção, ou deixar expirar em 14 dias.
