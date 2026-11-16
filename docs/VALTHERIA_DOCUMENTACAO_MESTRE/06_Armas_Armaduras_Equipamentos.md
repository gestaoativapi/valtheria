# 06 — Armas, Armaduras e Equipamentos

**Versão examinada:** `cliente-godot/data/world.json` (0.17.0) e banco `game.items/recipes/shop` · **Data:** 14/11/2026
Marcas: **[F]** fato comprovado · **[P]** proposta · **[C]** confirmar.

---

## 1. Números conferidos [F]

| Item | Diagnóstico anterior | Cliente nativo | Banco | Situação |
|---|---|---|---|---|
| Receitas | 196 | **196** | **196** | Confere (correção de 14/11: o 166 era estimativa do catálogo) |
| Itens | — | 332 | 332 | Iguais |
| Loja | — | 47 | 47 | Iguais |

Estações de receita (cliente): forja 168, refinaria 24, alquimia 4. **Nenhuma receita duplicada** (cada resultado tem uma receita). [F]

## 2. Catálogo por categoria [F]

### 2.1 Graus
NG (0), D (1), C (2), B (3), A (4), S (5). **Não há grau R** (Relíquia de temporada), embora ele esteja no padrão do projeto. **[C]**

### 2.2 Armas: 105 itens, 13 tipos

| Tipo (`kind`) | Itens | Modelo 3D no nativo | Pegada |
|---|---|---|---|
| Cajado | 12 | `w_spear` (lança usada como cajado) | Duas mãos, costas |
| Espadão | 11 | `w_claymore` | Duas mãos, costas |
| Arco | 11 | `w_bow_wooden` | Mão esquerda |
| Adaga | 11 | `w_dagger` | Uma mão |
| Espada | 10 | `w_sword` | Uma mão |
| Lança | 7 | `w_spear` | Duas mãos |
| Machado | 7 | `w_axe` | Uma mão |
| Martelo | 6 | `w_hammer_double` | Duas mãos |
| Cetro | 6 | `w_spear` encurtado | Uma mão |
| Punhal | 6 | `w_dagger` | Uma mão |
| Duplas | 6 | 2 × `w_sword` | Uma em cada mão |
| Punhos | 6 | **Nenhum** | — |
| Garras | 6 | **Nenhum** | — |

Arquivos do nativo:
- 8 modelos `w_*.glb`, Quaternius CC0;
- 4 modelos `_ng` (espadão, machado, arco, escudo), em `assets/armas`.

**Todas as armas do mesmo tipo usam o mesmo modelo, em qualquer grau.** [F] O ícone é desenhado por tipo (`icon_button.gd`), não por item. A web tem 16 ícones próprios em `assets/icons`.

### 2.3 Armaduras e roupas: 22 peitorais, 22 luvas, 22 botas, 23 elmos, 13 escudos
- Por grau: Pesada, Leve e Túnica Mágica, dos materiais Rústico → Bronze → Aço → Azurita → Rubro → Celestial.
- Peças especiais: Traje Neon Ômega, Armadura do Desbravador das Estrelas, Peitoral do Alvorecer Celestial e Couraça do Paladino Vigilante.
- **Aparência:** só o peitoral muda o corpo, em 3 roupas, e o grau não muda nada. Elmo, luvas e botas não aparecem (ver `04`, 1.4).

### 2.4 Outros
- Materiais: 4 brutos e 4 refinados por grau (48).
- Kits de coleta: 6.
- Pergaminhos de encantamento: 12.
- Poções: 3.
- Troféus: 18.
- Pets: 15. Montarias: 13. Asas: 7. **Sem modelo nem uso no nativo.**
- Especiais: Gema Arcana, Fragmento Estelar.

### 2.5 Atributos e raridade [F]
- Campos do item: `name, type, slot, kind, grade, stats, sell`. **Não há campo de raridade:** a hierarquia é só o grau.
- Exemplo (espada, `patk`): 8 → 17,6 → 28,8 → 40 → 52,8 → 70,4 por grau. A lendária da Harmonia tem 91,5. A Carmesim do Conde tem **104 + 5% de roubo de vida**, acima da lendária. **Lâmina de Plasma Ômega: 50** (grau S abaixo do S comum).
- **Erro de texto:** 27 itens usam "Rústico" com nome feminino ("Espada Rústico", "Armadura Pesada Rústico").
- 45 itens de equipamento **não têm receita**: são de chefe, de evento ou lendários. Conferir se todos estão em `boss_drops` ou na loja. **[C]**

### 2.6 Integração [F]

| Sistema | Situação |
|---|---|
| Inventário e slots | Sim: 6 slots (arma, armadura, elmo, luvas, botas, escudo) via `game_equip` |
| Atributos | Sim: `combat.recalc` e `game.power` no servidor |
| Animações | Parcial: só golpes de espada, soco e magia |
| Aparência | Parcial (acima) |
| Comércio | Loja de NPC sim; mercado entre jogadores só na web |
| Recompensas | `boss_drops` (62) no servidor |
| Fabricação | Forja sim (`game_craft`); coleta só na web; encantamento sem janela no nativo |
| Persistência | Sim (`game.inventory`); 55 itens fora do banco |

## 3. Padrão visual proposto [P]

| Grau | Material e acabamento | Sinal visual |
|---|---|---|
| NG Rústico | Ferro batido, madeira, couro cru | Sem ornamento |
| D Bronze | Bronze polido, couro tingido | Rebites |
| C Aço | Aço escovado | Gravação simples |
| B Azurita | Aço com inserções azuis | Runas pequenas, leve brilho |
| A Rubro | Aço escurecido com rubi | Filetes dourados |
| S Celestial | Prata e platina | Ornamento em forma de folha (Árvore), brilho suave |
| Lendário / chefe | Peça única com silhueta própria | Partícula discreta e nome em cor própria |

Regras:
- Cada tipo de arma tem **3 formas por faixa** (NG–D, C–B, A–S) mais as únicas. Isso dá cerca de 39 modelos de arma comuns mais os lendários, em vez de 105 recoloridos.
- Cada tipo de armadura tem **uma roupa por faixa e por gênero** (3 tipos × 3 faixas × 2 gêneros = 18 conjuntos), compatíveis com o esqueleto único.
- A cor forte ocupa no máximo 10% da peça. Nenhuma peça é cópia de outro jogo.
- Elmo, luvas e botas visíveis como peças presas aos ossos.

## 4. Regras de atributos e progressão [P]
- Curva por grau mantida (já é coerente nas armas comuns: cerca de +1,3× por grau).
- **Corrigir:**
  - Carmesim do Conde (104 + roubo de vida) fica acima da lendária: rebaixar para cerca de 88 ou subir as lendárias.
  - Plasma Ômega (50, grau S): decidir junto com a Era Neon (D21).
- Raridade = grau + origem (comum, de chefe, lendário), sem novo atributo.

## 5. Fabricação [P]
- Sincronizar as 196 receitas e os 332 itens no banco (E1.4).
- Levar coleta (`game_gather`) e encantamento (`game_enchant`) para o nativo; a lógica já existe no servidor.
- Corrigir os 27 nomes "Rústico" para concordarem em gênero ("Rústica" nos femininos).

## 6. Lista de recursos a criar

| Recurso | Quantidade | Prioridade |
|---|---|---|
| Modelos de punhos e garras | 2 bases | Alta (12 itens sem visual) |
| Modelo de cajado e de cetro próprios | 2 | Alta |
| Variações de forma por faixa | cerca de 39 armas | Média |
| Roupas de armadura por faixa e gênero | 18 conjuntos | Média (depende das raças) |
| Roupas para anão e Dragonita | 3 cada | Média |
| Elmo, luvas e botas visíveis | 3 tipos × 3 faixas | Baixa |
| Ícones por item, ou ao menos por tipo × faixa | cerca de 120 | Média |
| Modelos de pet e montaria no nativo | Os modelos `a_*`, `e_*` e `z_*` já baixados servem para começar | Média |

## 7. Decisões
- **D23:** criar o grau R (Relíquia) agora ou depois?
- **D24:** aprovar a correção de valores (Carmesim do Conde e Plasma Ômega).
- **D25:** aprovar "3 formas por faixa" como padrão de variedade.
