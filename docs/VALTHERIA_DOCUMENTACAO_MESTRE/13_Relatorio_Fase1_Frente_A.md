# 13 — Relatório da Fase 1 (Frente A): pacote de evidências para a decisão D37

**Situação:** implementado e testado **fora do jogo oficial**. **Não publicado** (D37 não autorizada). Nada na `main` mudou.
**Data:** 14/11/2026

---

## 1. Implementação identificada por commit

| Item | Valor |
|---|---|
| Ramificação | `fase1-servidor` (o jogo oficial continua na `main`, commit `29d9507`) |
| Commits | `6527cc7` — validação no servidor, reconexão e testes · `2eb7665` — teste de reconexão, procedimento de reversão e executável de teste |
| Migrações no Supabase | `fase1_validacao_servidor`, `fase1_kill4_guarda_alertas`, `fase1_portais_save2`, `backup_20261114_antes_publicacao_fase1` |
| Cópia do SQL aplicado | `cliente-godot/servidor/fase1_validacao.sql` |

**Comparação oficial × teste** (`git diff --stat main..fase1-servidor`):

| Arquivo | Mudança |
|---|---|
| `scripts/net.gd` | `save()` chama `game_save2`; reconexão do WebSocket (`ws_want`, `ws_retry`, `ws_backoff`, `_rt_open`) |
| `scripts/main.gd` | `_save_now`: dentro de prédio salva a porta; corrige a posição quando o servidor recusa |
| `scripts/combat.gd` | `_reward`: chama `game_kill4` (família, posição e ponto de chefe) em vez de `game_kill3` (nível e chefe) |
| `testes/regressao.sh`, `testes/test_reconexao.gd` | Novos (testes) |
| `servidor/*.sql` | Novos (registro, teste e reversão) |
| `.github/workflows/testes.yml` | Novo (testes e executável de teste; **não publica release**) |

| Comportamento | Oficial (`main`) | Teste (`fase1-servidor`) |
|---|---|---|
| Vida e mana salvas | Qualquer valor ≥ 0 | Até o máximo real do personagem (+15% de folga) |
| Posição salva | Qualquer ponto | Recusa deslocamento acima de 14 m/s + 40 m; redemoinhos liberados; GM livre |
| Salvar dentro de prédio | Grava a sala (fora do mapa) → volta no canto do mapa | Grava a porta do prédio |
| Abate | Cliente informa nível e se é chefe | Servidor decide nível, chefe e região pela posição |
| Chefe | Sem controle de volta | Só no ponto de caça; 5 min para voltar |
| Missão de matar (funções novas) | Concluída sem prova | Exige abates registrados (`game_quest_accept` + `game_quest_done2`) |
| Queda do tempo real | Não volta | Volta sozinho: 2, 4, 8, 16 e 30 s |
| Suspeitas | Não registradas | Tabela `game.alertas` |

## 2. Testes automatizados aprovados

GitHub Actions, workflow **"Testes do cliente nativo"**:
- run `43593908350` (commit `6527cc7`): **sucesso**;
- run `43599086457` (commit `2eb7665`): **sucesso** nos dois trabalhos, `testes` e `versao-de-teste`.

| Suíte | O que verifica | Resultado |
|---|---|---|
| Sintaxe | Os 15 scripts compilam | 15/15 |
| Entrada no mundo | Jogo abre sem erro em 6 pontos (capital, Aurora, Sylvar, Umbraval, Abissália, campo) | 6/6 |
| Reconexão | Tentativas em 0, 2, 6, 14, 30 e 60 s (esperas 2, 4, 8, 16, 30 s); ao sair do jogo não reconecta | Passou |

## 3. Validação das funções de segurança no servidor

Feita como usuário real sem GM (personagem de teste "Leon"), **dentro de uma transação desfeita no fim**. Script em `servidor/teste_fase1.sql`.

| # | Caso | Esperado | Resultado |
|---|---|---|---|
| 1 | Salvar com vida 999.999 | Limitar ao máximo | Vida gravada = 148 ✔ |
| 2 | Salvar a 2,3 km em 20 s | Recusar | `ok: false, motivo: movimento` ✔ |
| 3 | Redemoinho Abissália → Porto | Aceitar | `ok: true` ✔ |
| 4 | Lobo na pradaria | Aceitar; nível pelo servidor | Nível 6 ✔ |
| 5 | Dragão na pradaria | Recusar | "Este monstro não vive nesta região" ✔ |
| 6 | Chefe fora do ponto | Recusar | "Chefe fora do seu ponto de caça" ✔ |
| 7 | Abate a 500 m do jogador | Recusar | "Posição fora de sincronia" ✔ |
| 8 | Chefe no ponto certo | Aceitar; nível do ponto | Nível 10 ✔ |
| 9 | Mesmo chefe logo depois | Recusar | "Este chefe ainda não voltou" ✔ |
| 10 | Missão m01 sem abates | Recusar | "Faltam 5 de 5" ✔ |
| 11 | Suspeitas gravadas | 4 alertas | movimento, familia_fora, chefe_sem_ponto, abate_longe ✔ |

**Prova de que nada real mudou:** depois do teste, o personagem Leon continua com nível 1, na mesma posição e sem abates; `game.alertas` tem 0 linhas reais.

## 4. Salvamento, reconexão e integridade

| Teste | Situação |
|---|---|
| Salvamento no servidor (vida, mana, posição, redemoinhos) | ✔ Tabela da seção 3 |
| Reconexão (lógica de tentativas) | ✔ Teste automático da seção 2 |
| Integridade: tabelas novas com RLS ligado, sem acesso direto do cliente | ✔ `cidades`, `mob_fams`, `alertas`, `portais` |
| Integridade: funções novas não executáveis sem login | ✔ Revogadas de `anon`; só `authenticated` |
| **Teste online com o jogo de verdade** (entrar, lutar, chefe, entrar em prédio e sair do jogo, redemoinho, queda de internet) | **⏳ Pendente: precisa de você.** Eu não entro com a sua conta e daqui não alcanço o servidor pelo jogo. Roteiro na seção 9 |

## 5. A versão web continua funcional

- As **28 funções** que a web usa existem e são executáveis por usuário logado. A impressão digital (md5) do código de cada uma foi registrada em 14/11, para comparar depois.
- **Nenhuma foi alterada:** as 4 migrações só **criam** coisas novas, conferível no SQL salvo.
- `game_kill4` **chama** a `game_kill3` original, sem mudá-la.
- **Diferença visível para a web:** `game_state` agora devolve 4 campos a mais no personagem (`pos_at`, `kills`, `boss_cd`, `qbase`), porque são colunas novas. A web ignora campos que não usa **[C]**: confirmar abrindo a web uma vez.
- O jogo web em si **não foi aberto nem testado no navegador** (precisa de login).

## 6. Backup e procedimento de reversão

- **Backup** (14/11/2026, antes de qualquer publicação), conferido linha a linha em contagem:

  | Tabela | Linhas |
  |---|---|
  | `game.bkp_20261114_characters` | 3 |
  | `game.bkp_20261114_inventory` | 105 |
  | `game.bkp_20261114_accounts` | 2 |

- **Reversão do servidor:** `servidor/reverter_fase1.sql` (**não executado**). Remove só as funções novas; as antigas nunca foram tocadas.
- **Reversão do jogo:** como nada foi para a `main`, basta não juntar. Depois de publicado, seria um `git revert` do commit de junção, que gera de novo o zip anterior.

## 7. Executável de teste (sem tocar no oficial)

O GitHub gerou **"Valtheria-TESTE-fase1-servidor"** (149 MB), disponível por 14 dias em:
GitHub → repositório → **Actions** → run "Fase 1: teste de reconexão…" → **Artifacts**.
É o jogo da ramificação de teste. O `Valtheria-Windows.zip` oficial **não mudou**.

## 8. Pendências

1. Teste online com o seu personagem (seção 9).
2. Abrir a versão web uma vez para confirmar o item 5.
3. Medição real no notebook (`registro.txt`, D18).
4. Missões no jogo novo (`game_quest_accept`/`done2` prontas, mas o jogo novo ainda não tem a janela de missões: etapa T4.1).
5. D35 adiada, como você decidiu.

## 9. Roteiro do teste online (você, com o executável de TESTE)

1. Entre com um personagem comum, **não GM**: o GM passa direto pelas travas.
2. Mate 3 monstros perto de uma cidade. A experiência e os itens devem chegar normalmente.
3. Vá a um ponto de caça e derrote o chefe. Tente de novo antes de 5 minutos: deve aparecer "Este chefe ainda não voltou".
4. Entre numa taverna, espere 25 segundos e feche o jogo. Ao entrar de novo, o personagem deve estar **na porta da taverna**, não no canto do mapa.
5. No Porto Maré-Alta, use o redemoinho para Abissália e espere 25 s. Não deve aparecer "Posição corrigida pelo servidor".
6. Com o jogo aberto, desligue o Wi-Fi por 20 s e ligue de novo. Os outros jogadores devem voltar a aparecer sozinhos em até 30 s.
7. Me conte o resultado, ou marque na Central de Decisões, na D37.
