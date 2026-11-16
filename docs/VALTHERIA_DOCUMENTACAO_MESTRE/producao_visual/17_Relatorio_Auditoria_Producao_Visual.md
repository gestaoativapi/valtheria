# 17 — Relatório da Auditoria de Produção Visual, Protótipos 3D e Evolução Gráfica

**Data:** 15/11/2026 · **Base:** `main` 29d9507 (v0.17.0), lida numa cópia separada, sem alteração.
**Etapa:** auditoria, planejamento e especificação. **Nenhum protótipo foi construído** nesta etapa (exceção já relatada antes: a prova de aparência V2 de 14/11, feita pela D49, fora do repositório).

---

## Resumo executivo

**O que já está pronto**
- Esqueleto único de 65 ossos e 28 animações, usados por todos os corpos, roupas e cabelos.
- Encaixe de armas por tipo (tabela `GRIP`, IK do braço, armas nas costas e na cintura).
- Terreno de 3 × 3 km com relevo, mistura de texturas, grama instanciada, água e céu com ciclo de dia.
- 5 níveis gráficos completos (FSR, MSAA, sombra, SSAO, brilho, névoa volumétrica, SDFGI).
- Corpos V2 (MPFB2) ligados ao esqueleto do jogo, com pele igual ou melhor nas 84 poses medidas.
- Pacote MakeHuman CC0 baixado e conferido (94 itens CC0), com a primeira prova de pele, olhos, sobrancelhas, cabelo e roupa sobre a V2.

**O que precisa melhorar**
- Corpos, roupas, cabelos e olhos atuais: estilo simples, só 6 cabelos e 1 cor de olho.
- Armas: 8 malhas sem textura, com 3 a 5 materiais cada.
- Árvores, rochas e casas de vila; água e iluminação; mapa.

**O que precisa ser construído**
1. **Silhueta própria para 5 das 8 raças:** elfo, elfo negro, orc, homem-fera e gigante hoje são o humano recolorido ou esticado.
2. **Armaduras em peças com graus visuais:** a armadura hoje é uma das 7 roupas inteiras, a mesma para os 332 itens.
3. **Monstros com modelo próprio:** 12 das 18 famílias são humanoides recoloridos ou outra espécie (touro como javali, dinossauro como homem-lagarto).
4. **Cidades e interiores modulares:** hoje são caixas geradas por código.
5. Oclusão, LOD e carregamento por região.
6. Animações de arco, cajado, lança, adaga dupla, esquiva e pulo.
7. Os 6 guardiões com identidade própria.

**O que deve ser priorizado**
- O conjunto de referência pedido pelo Robson:
  - **humano masculino e feminino completos** com roupa de fantasia (P1/P2);
  - **espada** (P5);
  - **armadura em 3 graus** (P4);
  - **javali** (P6), que vira o **Rei Javali**, primeiro guardião (P8);
  - **clareira** de cenário (P9).
- Logo depois do P1/P2: **benchmark no notebook** para fixar os limites.

**Maiores riscos**
- Peso do personagem completo no notebook: ainda não medido com FPS real.
- Mistura de estilos entre origens (Quaternius, Meshy, MPFB, modelagem própria).
- Roupa e placa atravessando o corpo nas animações.
- Custo de produção das raças não humanas (homem-fera).
- Mundo inteiro carregado de uma vez.

**Decisões que dependem do Robson:** lista na §14.

---

## 1. Diagnóstico atual
O cliente funciona e tem uma base técnica sólida (esqueleto único, encaixe de armas, terreno, 5 níveis gráficos). A qualidade percebida é limitada por **repetição**:
- 8 raças sobre 3 corpos;
- 332 itens sobre 15 malhas (8 armas e 7 roupas);
- 18 famílias de monstros sobre 4 modelos de bicho e o próprio personagem;
- cidades feitas de caixas.

A direção "fantasia semi-realista estilizada" pede o contrário: menos modelos isolados e mais **variação controlada** sobre bases bem feitas.

## 2. Inventário de assets
Ver `VALTHERIA_INVENTARIO_ASSETS.md`: 134 modelos `.glb` medidos um a um, com triângulos, materiais, ossos, animações e texturas. Os dados brutos estão em `evidencias/inventario_glb_main_29d9507.json`.

## 3. Matriz de lacunas
Ver `VALTHERIA_INVENTARIO_ASSETS.md`, §8. Cada item foi classificado de 1 a 5, sem confundir "arquivo existe" com "funciona no jogo".

## 4. Avaliação técnica do Godot
Ver `VALTHERIA_PLANO_MESTRE_PRODUCAO_VISUAL.md`, §4. Em resumo:
- o renderizador e os níveis gráficos estão bons;
- faltam LOD, oclusão e carregamento por região;
- a sombra dobra os triângulos;
- as armas gastam materiais demais.

## 5. Direção de arte consolidada
Ver o Plano Mestre, §1. Ela segue a paleta e as regras do Guia de Identidade V1 (doc 12) e acrescenta: superfície pintada, silhueta por raça e variação por material, ornamento e escala.

## 6. Pipeline de produção
Ver `VALTHERIA_PIPELINE_3D.md`, com:
- 16 ferramentas e fontes avaliadas (licença, custo, créditos, uso comercial, atribuição);
- os 14 passos do personagem;
- os pipelines de equipamento, criatura e ambiente;
- a ordem das raças.

## 7. Plano dos protótipos
Ver `VALTHERIA_PLANO_PROTOTIPOS.md`: 10 protótipos com objetivo, recursos, arquivos, dependências, tempo, riscos, testes, critério e reutilização.

## 8. Cronograma por fases
Ver o Plano Mestre, §6: fases 0 a 8, com entregas, dependências e critérios de conclusão.

## 9. Estimativa de recursos e custos
Ver o Plano Mestre, §7.
- **Toda a Etapa 1 pode ser feita com R$ 0:** programas livres e recursos CC0.
- O Meshy fica como opção para criaturas, cabeças de raça e guardiões, com orçamento por protótipo. Plano grátis: 100 créditos por mês, saída CC BY 4.0. Pro: a partir de US$ 20 por mês.
- **Nenhum crédito foi usado.**

## 10. Riscos técnicos e artísticos
Ver o Plano Mestre, §8.

## 11. Critérios de aprovação
Ver o Plano Mestre, §9, que vale para qualquer protótipo.

## 12. Recomendações de prioridade
Ver o Plano Mestre, §10.

## 13. Estrutura proposta de diretórios
Ver `VALTHERIA_PADRAO_TECNICO_ASSETS.md`, §10:
- arquivos novos só em `assets_v3/`, `ferramentas/v3/`, `testes/prototipos/` e `fontes/`;
- nada existente é renomeado ou movido.

## 14. Decisões que dependem do Robson

| # | Decisão | Opções | Recomendação |
|---|---|---|---|
| D50 | Roupas da V2 | (a) Remodelar e repintar as malhas CC0 como roupas de fantasia; (b) usar as modernas só como teste técnico | (a) |
| D51 | Iniciar a Etapa 1 de protótipos (P1, P2, P5, P3, P4, P6, P9) na branch `v3-prototipos` | Autorizar / ajustar a ordem / não agora | Autorizar |
| D52 | Javali do P6 | (a) Modelagem própria, 0 créditos; (b) Meshy, cerca de 50–60 créditos do plano grátis, saída CC BY 4.0 | (a); o (b) só se o (a) não atingir a qualidade |
| D53 | Primeiro guardião | Rei Javali (reaproveita o P6) ou outro | Rei Javali |
| D54 | Texturas CC0 de cenário | Autorizar o download de texturas do Poly Haven/ambientCG para o P9, cada uma registrada | Autorizar |
| D55 | Ordem das raças depois do humano | Elfos → Orc → Homem-fera → Gigante → Anão/Dragonita, ou outra | A ordem proposta |
| D56 | Benchmark no notebook | Data para rodar o P1/P2 + 40 personagens no seu notebook | Logo após o P1/P2 |
| D57 | Animações novas (arco, cajado, lança, esquiva) | Fontes CC0 + retarget, ou Mixamo (termos da Adobe) | CC0 primeiro |

As decisões já em curso não mudam: D39 (homologação online) aguarda a sessão de jogo do Robson; D37 (publicação) continua **não autorizado**.

---

## Evidências da auditoria

| Evidência | Arquivo |
|---|---|
| Medição de todos os `.glb` da `main` | `evidencias/inventario_glb_main_29d9507.json` e o script `evidencias/medir_glb.py` |
| Leitura do código (montagem de raças, mapeamento de monstros, cidades, níveis gráficos) | Citada por arquivo e trecho no inventário (§2.2, §4, §5, §7) |
| Linha de base de cena (chamadas, triângulos, memória) | Doc 09, §1 (medição anterior, sem FPS) |
| Prancha de raças e criaturas atuais | `../imagens/Valtheria_Racas_Criaturas_Prancha.png` |
| Licença do pacote MakeHuman (94 itens CC0) | `evidencias/makehuman_system_assets_LICENCA.txt` |
| Prova de aparência V2 (14/11) | `evidencias/V2_aparencia_prancha_v1.jpg` |
| Preços e licenças do Meshy | Documentação oficial do Meshy, consultada em 15/11/2026 |

**Lacunas registradas, em vez de inventadas:**
- FPS real: depende do notebook.
- Compressão em celular: não testada.
- Tempo real de produção por sessão: estimado, a medir na Etapa 1.

---

## Proposta de execução da primeira etapa

Detalhada em `VALTHERIA_PLANO_PROTOTIPOS.md`, seção final:
- **Branch:** `v3-prototipos`, criada a partir da `main`.
- **Ferramentas:** Blender 5.3, MPFB2, MakeHuman CC0, Godot 4.7.2, Krita e texturas CC0.
- **Ordem:** P1+P2 (com P5) → P3 → P4 → P6 → P9.
- **Estimativa:** 12 a 15 sessões, R$ 0 e nenhum crédito.

**A construção só começa com a autorização expressa do Robson (D51).**
