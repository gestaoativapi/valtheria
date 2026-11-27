# 00 — Auditoria Geral do Projeto (Fase 0)

**Projeto:** Valtheria — A Árvore dos Mil Mundos · **Data:** 14/11/2026
**Base examinada:**
- cliente nativo Godot 4.7.2, versão 0.17.0 (commit `29d9507`, igual ao GitHub);
- cliente web Three.js r170 (congelado);
- banco Supabase `irpzdghikvoezfeodyiq`, só consultas de leitura;
- os 10 documentos desta pasta.

**Garantia:** **nenhum arquivo do projeto e nenhum dado do banco foram alterados.** Medições e pranchas foram feitas numa cópia temporária, fora do repositório.

Marcas:
- **[F]** fato comprovado, com a evidência indicada;
- **[P]** proposta;
- **[C]** precisa de confirmação.

O detalhe de cada tema está nos documentos 02 a 09. O plano de execução está no 10.

---

## 1. O que já está implementado [F]

| Sistema | Evidência |
|---|---|
| Login, criação e escolha de personagem (com o personagem visível) | `net.gd`, `ui.gd`, `game_create_char2`, `game_chars` |
| 8 raças jogáveis × 2 gêneros, pele, cabelo e barba | `world.json.races`, `character.gd` |
| 159 classes, troca de classe nos níveis 20, 40 e 76 | `world.json.classes`, `game_class_change` |
| Mundo de 3 × 3 km: 15 cidades, 17 vilas, 10 castelos, 23 ruínas, cidades especiais (árvore, caverna, ilha, fundo do mar) | `world.gd`, `cidade.gd`, `especial.gd`, `mapa.json` |
| NPCs com rotina, conversas, roupa de frio, guardas | `npcs.gd` |
| Interiores com planta | `interiores.gd` |
| Combate PvE com 18 famílias de monstros, chefes, 9 conjuntos de 18 habilidades | `combat.gd` |
| Experiência e níveis calculados no servidor | `game_kill3` |
| Inventário, equipamento, loja, venda, forja | `game_equip/unequip/use/shop_buy/npc_sell/craft` |
| Chat, presença e posição dos outros jogadores | `social.gd`, Realtime |
| Clã (criar, informações, sair, convites) | `game_clan_*` |
| Painel e comandos de GM, validados no servidor | `game_gm`, `gm_log` (154 registros) |
| Salvamento a cada 20 s | `game_save` |
| 5 níveis de qualidade gráfica | `main.gd::_set_quality` |
| Build do Windows automático | GitHub Actions → `cliente-prototipo` |
| Banco protegido: RLS nas 22 tabelas, acesso só por funções que conferem o dono | Catálogo do banco |

## 2. O que está parcialmente implementado [F]

| Sistema | O que falta |
|---|---|
| Aparência das raças | Elfo, elfo negro e homem-fera são o corpo humano; orc e gigante são humanos em escala (prancha) |
| Aparência dos equipamentos | 3 roupas por gênero; grau não muda o visual; elmo, luvas e botas invisíveis; punhos e garras sem modelo |
| Monstros | Golem, ent, esqueleto, demônio e dragão usam corpos humanos recoloridos; 15 famílias só na web |
| Animações | Arco, lança, cajado, duas mãos, nado e pulo sem clipe próprio |
| Habilidades | 64 sem efeito visual; `blink` e `mana` sem lógica |
| Ofício | Forja sim; coleta e encantamento só no servidor e na web |
| Clã | Doar, subir de nível, cargos e captura de castelo só na web |
| Teleporte | Só GM e redemoinhos |
| Nado e pisos elevados | Funcionam sem animação; não testados jogando |
| Sincronização de dados | Cliente e banco divergem em cidades (15×11) e castelos (10×3). **Correção de 14/11:** itens (332), receitas (196) e loja (47) são **iguais** nos dois; a contagem anterior usava uma estimativa do banco, não a contagem real |

## 3. O que ainda não existe [F]

| Sistema | Observação |
|---|---|
| Missões no nativo | 63 no banco e na web, nenhuma no nativo |
| Grupo (party) | Em nenhum dos clientes |
| PvP, karma e duelo no nativo | `game_pvp` existe; o nativo não usa |
| Mercado entre jogadores no nativo | `game_market_*` existem |
| Cerco de castelos | Só cenário |
| Pets, montarias e asas no nativo | 35 itens sem modelo nem lógica |
| Áudio no nativo | Nenhum som |
| Subclasse (nível 40) | Só no `DESIGN.md` |
| Raças halfling, sylph e nocturno jogáveis | 42 classes sem raça |
| Grau R (Relíquia) | Não há grau 6 |
| Testes automáticos de regressão | Nenhum |
| Carregamento por região, LOD de personagens, oclusão | — |
| Controle por toque e versão para celular do nativo | Nativo só Windows |
| Mundo compartilhado (mesmos monstros para todos) | Cada cliente gera os seus |

## 4. Sistemas com problemas [F]

| # | Problema | Gravidade | Documento |
|---|---|---|---|
| 1 | `game_save` aceita qualquer HP e MP e qualquer posição | **Crítica** | 05 (S1) |
| 2 | `game_kill2` aceita chefe e nível vindos do cliente | **Crítica** | 05 (S2) |
| 3 | 40 de 63 missões concluem sem prova | Alta | 05 (S3), 07 |
| 4 | Cliente e banco com dados diferentes (cidades seguras, receitas, itens) | Alta | 05 (4.3) |
| 5 | WebSocket não reconecta | Média | 05 (5) |
| 6 | 251 MB de texturas e 760–924 chamadas de desenho em qualquer ponto | Alta (celular), média (PC) | 09 |
| 7 | Classes do mesmo arquétipo jogam igual (9 conjuntos para 159 classes) | Média | 07 |
| 8 | Valores de item fora da curva (Carmesim do Conde acima das lendárias; Plasma Ômega abaixo do S) | Baixa | 06 |
| 9 | 27 nomes com "Rústico" errado | Baixa | 06 |
| 10 | Mundo: Fortaleza Glacial sem neve, 5 cidades sem estrada, sem rios nem deserto, nível de monstros alterado em volta da capital, ruína sobre Coralis | Média | 03 |
| 11 | Escala de lobo e raptor visivelmente errada na prancha | Baixa **[C]** | 04 |

## 5. Conflitos entre documentos e código

| # | Documento diz | Código ou banco mostra | Situação |
|---|---|---|---|
| C1 | Bíblia: história única (Eclipse + Pacto do Véu) | `quests.js` conta a "Era do Eclipse" e `npcs.gd` o "Pacto do Véu" | [F] conflito; resolve com D03–D07 e T5.1 |
| C2 | `DESIGN.md` e padrão de arte: homens-fera com cabeça de animal, pelagem e cauda | Homem-fera é o corpo humano | [F] |
| C3 | Padrão do projeto: raças-base incluem Halflings | Halflings não são jogáveis (`hidden` na web, ausentes no nativo) | [F]; D17 |
| C4 | Padrão do projeto: grau R (Relíquia) | Graus só de 0 a 5 | [F]; D23 |
| C5 | Padrão do projeto: subclasse a partir do nível 40 | Não existe | [F] |
| C6 | Diagnóstico anterior: 196 receitas | Cliente 196, banco 196 (**corrigido em 14/11**: o 166 era estimativa do catálogo, não contagem) | [F] |
| C7 | Diretrizes: servidor em 6º na prioridade | Roadmap: fundação técnica na Fase 1; auditoria: falhas críticas no servidor | [F]; D01 |
| C8 | Bíblia: mundo de fantasia | Web tem a "Era Neon" (7 monstros e itens de ficção científica) | [F]; D21 |
| C9 | Arquitetura: "servidor valida combate, recompensas e movimento" | Servidor confia no cliente nesses três pontos | [F] (seção 4) |
| C10 | Mundo: Fortaleza Glacial é cidade de gelo | Fica na região das Terras Rubras (sem neve) | [F] |
| C11 | Web "preservada como referência" | Web e nativo usam **o mesmo banco e as mesmas funções**: mudar uma função muda a web | [F]; por isso o plano cria funções novas (`game_save2`, `game_kill4`) |

## 6. Riscos técnicos

| Risco | Probabilidade | Impacto | Mitigação [P] |
|---|---|---|---|
| Trapaça (HP, teleporte, experiência, missões) quando houver jogadores | Alta | Alto | Fase 1 (T1.1–T1.3) |
| Quebrar a web ao mexer nas funções | Média | Alto | Funções novas em paralelo; as antigas ficam |
| Regressão sem perceber (um `main.gd` central, sem testes) | Alta | Médio | T1.6 |
| Dados divergentes cliente × banco | Já ocorre | Médio | T1.4 + script de sincronização |
| Desempenho ruim em PC fraco e celular | Média **[C]** | Alto | T1.7 e plano do `09` |
| Licença de arte (Meshy CC BY; Mixamo e outros) | Baixa | Alto | Créditos sempre em `CREDITOS.md`; só CC0 ou licença conferida |
| Créditos de geração acabarem (Meshy ≈ 41) | Alta | Médio | Usar primeiro os modelos CC0 já baixados |
| Mundo não compartilhado impede grupo, chefe de mundo e cerco | Certa | Alto | Decisão de arquitetura futura (servidor autoritativo) **[C]** |
| Vulkan e D3D12 instáveis no notebook | Comprovada antes | Médio | Manter OpenGL; aguardar `registro.txt` |

## 7. Ordem de execução recomendada [P]

1. **Fase 1, fundação (T1.1–T1.6):**
   - validação no servidor;
   - sincronização de dados;
   - reconexão;
   - testes automáticos;
   - medição real (T1.7, depende do `registro.txt`).
2. **Fase 2, personagens:**
   - armas sem modelo (T2.3) e monstros com corpo humano (T2.4), que usam os modelos já baixados;
   - depois as silhuetas das raças (T2.1), que dependem das imagens do Gemini.
3. **Fase 3, mundo:** correções M1–M7 após as decisões D08–D14.
4. **Fase 4, gameplay:** missões no nativo, habilidades por linha de raça, grupo, PvP, cerco.
5. **Fase 5, conteúdo:** texto da Bíblia, efeitos, áudio.
6. **Fase 6:** otimização com métricas antes e depois e testes integrados.

**Nada será executado antes da sua aprovação.** O primeiro passo pedido é a resposta à **D01** (começar pelo servidor) e à **D02** (salvar esta pasta no repositório).
