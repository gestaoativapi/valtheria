# 01 — Valtheria: Diretrizes Gerais do Projeto

**Projeto:** Valtheria — A Árvore dos Mil Mundos (MMORPG 3D, designs originais)
**Repositório:** `gestaoativapi/valtheria` · **Versão de referência:** cliente nativo 0.17.0 (commit `29d9507`)
**Documento:** consolida as diretrizes enviadas pelo Robson. Vale para todo o trabalho a partir de 14/11/2026.

---

## 1. Arquitetura definida

| Parte | Tecnologia | Papel |
|---|---|---|
| Cliente principal | Godot 4.7.2 + GDScript (`cliente-godot/`) | Apresentação, interface, entrada do jogador, predição visual |
| Servidor e banco | Supabase (projeto `irpzdghikvoezfeodyiq`, esquema `game`, funções `public.game_*`) | Validação, regras de integridade, persistência |
| Cliente de referência | Three.js r170 (raiz do repositório) | **Congelado e preservado.** Fonte de consulta de sistemas já feitos (missões, PvP, mercado etc.) |
| Publicação | GitHub Actions → release `cliente-prototipo` (Windows) | Build a cada push na `main` |

## 2. Regras obrigatórias

1. **Analisar antes de modificar.** Nenhuma alteração sem ler o código, os dados e o banco envolvidos.
2. **Não excluir funcionalidades** sem autorização expressa do Robson.
3. **Não reconstruir do zero.** Verificar sempre se o recurso já existe, mesmo que parcialmente, no nativo, na web ou no servidor.
4. **Etapas pequenas e documentadas.** Uma melhoria por vez, com relatório.
5. **Não inventar o estado do projeto.** Toda afirmação traz evidência: arquivo, linha, tabela, consulta ou captura de tela.
6. **Não alterar arquivos fora do escopo aprovado.**
7. **Validar cada etapa** com teste antes de publicar.
8. **Assets só livres** (CC0 ou licença com uso comercial conferida) e registrados em `CREDITOS.md`. Nada copiado de Lineage II ou de outras obras.
9. **Celular e desktop** sempre juntos; manter o jogo leve.
10. **Sem segredos no cliente:** apenas a chave pública (`anon`). Nunca chave de serviço.

## 3. Processo obrigatório por melhoria

Cada melhoria segue os passos abaixo e só começa depois de aprovada:

| Passo | Conteúdo |
|---|---|
| 1. Diagnóstico | Situação atual, com evidência |
| 2. Objetivo | O que muda para o jogador ou para o sistema |
| 3. Arquivos | Lista exata dos arquivos e funções do servidor afetados |
| 4. Impactos | O que pode quebrar: web, banco, saves, desempenho |
| 5. Plano | Passos curtos |
| 6. Critérios de aceitação | Como provar que ficou pronto |
| 7. Testes | Testes de sintaxe, testes headless, capturas, consultas ao banco |
| 8. Resultado | O que foi feito, com evidência |
| 9. Pendências | O que ficou para depois |

## 4. Prioridades

1. Personagens e raças
2. Cidades e ambientes
3. Armas
4. Natureza e biomas
5. Efeitos e animações
6. Combate e validação no servidor
7. Sincronização com o banco
8. Desempenho

> **Observação da auditoria (proposta, aguarda decisão D01):** a lista de prioridades coloca o servidor em 6º lugar. Porém a auditoria comprovou falhas de integridade no servidor (ver `05_Arquitetura_Tecnica.md`, seção 6). O `10_Roadmap_Execucao.md` também põe a fundação técnica na Fase 1. A recomendação é corrigir o servidor primeiro, porque os sistemas de raças, armas e missões vão gravar dados por essas mesmas funções.

## 5. Convenção usada em todos os documentos

| Marca | Significado |
|---|---|
| **[F]** | Fato comprovado, com a evidência indicada |
| **[P]** | Proposta. Não existe no jogo e aguarda aprovação |
| **[C]** | Precisa de confirmação do Robson ou de um teste que não pôde ser feito |

## 6. Regra final

O objetivo não é só acrescentar recursos. É construir um MMORPG integrado, consistente, estável e com identidade própria. Na dúvida, perguntar antes de alterar.
