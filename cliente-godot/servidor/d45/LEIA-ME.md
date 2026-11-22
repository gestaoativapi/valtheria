# D45 — Projeto de testes (valtheria-testes)

- Projeto: `mxhhqxvrryvqcsvokyla`, região us-east-1, plano gratuito, organização própria `valtheria-testes` (conta ativaonepi, sem membros da conta gestaoativapi).
- Montagem (14/11/2026):
  1. 13 migrações do histórico da produção, na ordem (sem `backup_20261114_antes_publicacao_fase1`), aplicadas com `session_replication_role = replica` porque a v11 depende de itens que a produção recebeu fora das migrações.
  2. Conteúdo copiado da produção: races, classes, items, recipes, shop, quests, boss_drops, mob_fams, towns, teleports, cidades, portais, nodes, castles (castles sem dono). Nenhuma conta, personagem, inventário, chat, clã, mercado, log ou backup.
  3. `05_ajuste_funcoes.sql`: `game.need` e `game.plvl` iguais às da produção (search_path fixo, alterado na produção fora das migrações).
  4. Função `signup` (Edge Function) igual à da produção, verify_jwt desligado; "Confirm email" desligado como na produção.
- Paridade: `03_impressao_digital.sql` roda nos dois bancos e precisa dar o mesmo resultado (26 tabelas, conteúdo com hash igual, 62 funções iguais, 3 políticas, RLS em 26 tabelas, gatilho on_auth_user_created_game, publicação chat/events/node_state, 17 chaves estrangeiras sem órfãos).
- Funcionamento e isolamento: `teste/homologacao_servidor.sh` (roda no GitHub Actions, job homologacao-servidor).

## Fase 3 (21/11/2026) — habilidades com PH, troca de classe A/B e grupo no servidor
- Arquivos: `servidor/fase3_habilidades_grupo.sql`, `fase3_dados_classes.sql`, `fase3_dados_habilidades.sql`; desfazer: `fase3_reverter.sql`.
- Só no projeto de testes. Tabelas novas: classes_v2, skills_v2, parties, party_members, party_invites; colunas novas em characters: ph, skills.
- Funções: game_skill_learn, game_class_change2, game_party_invite/answer/leave/kick/loot/info, game_kill5 (chama game_kill4 e soma PH; em grupo divide experiência e PH pelo nível, aurum em partes iguais e itens em rodízio).
- Conferido com dois personagens criados dentro de uma transação desfeita no fim (nada ficou gravado).
- Executável de testes: `TESTE_ANON_KEY=<anon do projeto de testes> bash ferramentas/exportar_teste.sh` (cópia do projeto em /tmp, trava contra a produção).
