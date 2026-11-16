# 14 — V2: avaliação dos corpos MPFB2 (D38) e condições do teste online (D39)

**Data:** 14/11/2026
**Garantia:** nada foi incorporado ao jogo. Nenhum arquivo oficial nem a `main` foram alterados. Nenhum crédito Meshy foi usado.

---

## Parte 1 — D38: corpos masculino e feminino gerados com MPFB2

### 1.1 Ambiente isolado [F]

| Item | Valor |
|---|---|
| Pasta | `/home/claude/v2` (ambiente de trabalho do Claude, **fora** do repositório Valtheria) |
| Dependências | Ambiente Python próprio (`v2/venv`); nada foi instalado no projeto do jogo nem no sistema |
| Blender | Pacote `bpy` **5.3.0** (Blender como módulo Python), sem interface |
| MPFB2 | **2.0.18**, código-fonte do GitHub `makehumancommunity/mpfb2`, commit `9de0707f` (12/11/2026), instalado como extensão só nessa pasta (`BLENDER_USER_RESOURCES=v2/bl_user`) |
| Pacotes extras | **Nenhum.** Só os recursos que vêm junto com o MPFB2. O pacote de "system assets" (olhos, sobrancelhas, cabelos, roupas, peles) **não** foi baixado |
| Scripts | `v2/gerar_corpos.py` (gera e exporta) e `v2/comparar_esqueleto.py` (compara os esqueletos) |

### 1.2 Licenças, cada parte separada [F]

| Parte | Licença | Onde foi conferida | Vai para o jogo? |
|---|---|---|---|
| Código do MPFB2 | **GPL-3.0-or-later** | `LICENSE.CODE.md` e `blender_manifest.toml` | **Não**: é só ferramenta |
| Recursos do MPFB2 (malha base, alvos, esqueletos, pesos, texturas) | **CC0 1.0** | `LICENSE.ASSETS.md` e `LICENSE.md`, seção C | Sim, se aprovado |
| Arquivos gerados (exportações, renderizações) | Do usuário, sem reivindicação da equipe MakeHuman: "as assets have been released under CC0, there is no limitation" | `LICENSE.md`, seção D | Sim, se aprovado |
| Blender (`bpy`) | **GPL-3.0** | Metadados do pacote | **Não**: é só ferramenta |
| System assets (cabelos, olhos, peles) | **Não verificada.** Não usada | — | — |

Não presumi que nada fosse CC0 sem ler: o texto de cada licença está nos arquivos citados.

### 1.3 O que foi gerado [F]
Arquivos em `v2/saida/` (não estão no repositório):

| Corpo | Altura | Vértices | Triângulos | Ossos | Esqueleto MPFB | Arquivo |
|---|---|---|---|---|---|---|
| Masculino | **1,802 m** (alvo 1,80) | 13.380 | 26.756 | 53 | `game_engine` | `v2_corpo_masculino.glb` (912 KB) |
| Feminino | **1,679 m** (alvo 1,68) | 13.380 | 26.756 | 55 | `game_engine_with_breast` | `v2_corpo_feminino.glb` (911 KB) |
| *Atual masculino (referência)* | ~1,80 m | — | 14.318 | 65 | Quaternius | `body_male.glb` |

Parâmetros do MPFB:
- **Masculino:** gênero 1,0, músculo 0,65, proporções 0,8, peso 0,5.
- **Feminino:** gênero 0, músculo 0,5, proporções 0,8.
- A altura foi ajustada automaticamente até o alvo.

### 1.4 Comparação visual dentro do Godot
Imagem: `imagens/V2_Corpos_MPFB_Comparacao.png`, com frente e lado. Foi feita numa **cópia temporária** do cliente, fora do repositório.

**Leitura honesta:**
- **Proporção e anatomia:** realistas e adultas, como pede o guia. A diferença para o corpo atual, que tem cabeça maior e formas mais simples, é clara.
- **Ainda não é um personagem:** é só a **malha nua**, sem pele pintada, olhos, sobrancelhas, cabelo nem roupa. A cor clara na imagem é um material provisório. Para avaliar rosto e acabamento faltam texturas (B3).
- **Pose:** a malha vem em "pose A" (braços a cerca de 45°). O corpo atual aparece em pose de descanso animada.
- **Triângulos:** 26,7 mil, cerca de **1,8 vez** o corpo atual (14,3 mil). Isso está dentro da faixa de partida do guia (20 a 35 mil), mas só a medição real diz se cabe.

### 1.5 Compatibilidade com o esqueleto de 65 ossos [F]
Saída do script `comparar_esqueleto.py`:

| Verificação | Resultado |
|---|---|
| Nomes | **53 dos 65 ossos iguais**, depois de ignorar maiúsculas (`Root`/`root`, `head`/`Head`) |
| Faltam | Os 12 ossos de ponta (`*_04_leaf_*`, `ball_leaf_*`). São pontas sem peso, fáceis de acrescentar |
| Hierarquia (quem é pai de quem) | **Igual** nos 53 |
| **Orientação de repouso** | **Diferente em 52 dos 53** (dedos e pés acima de 80°, clavículas 91°) |

**Conclusão:** ter os mesmos nomes **não basta**. As 28 animações do jogo guardam rotações relativas à pose de repouso do esqueleto atual. Ligado direto, o corpo V2 ficaria torto em todas as animações. Por isso o corpo **não pode** ser usado como está.

**Como resolver** (é a etapa B3, que precisa da sua aprovação, D41):
1. No Blender isolado, posar o corpo MPFB para que cada osso aponte na mesma direção do osso do jogo: braços em T, dedos e pés alinhados.
2. Fixar essa pose como forma da malha.
3. Ligar a malha ao **esqueleto do próprio jogo** (as orientações do `body_male.glb`, com as articulações movidas para a anatomia V2).
4. Copiar os **pesos de skinning do MPFB** osso a osso, pelo nome: são pesos feitos à mão pela equipe MakeHuman, melhores que pesos automáticos.
5. Acrescentar os 12 ossos de ponta sem peso.
6. Rodar o teste de deformação nas 28 animações (seção 3.2).

---

## Parte 2 — D39: condições do teste online (respostas diretas)

| Pergunta | Resposta |
|---|---|
| 1. Qual Supabase o executável de teste usa? | **O de produção** (`irpzdghikvoezfeodyiq`, nome "mmorpg-teste"). É o **único projeto** da sua conta; **não existe ambiente de testes separado** hoje |
| 2. O personagem do teste sofre alteração permanente? | **Sim.** Experiência, itens, aurum, posição e abates do personagem usado são gravados de verdade |
| 3. Dá para preservar ou restaurar? | **Sim, por personagem.** Antes do teste eu tiro uma cópia daquele personagem e do inventário dele, e depois restauro se você pedir. Já existe a cópia geral de 14/11 (`game.bkp_20261114_*`) |
| 4. As migrações estão isoladas do oficial? | **Não em banco separado.** Estão no banco oficial, mas são **aditivas**: só o executável de teste chama as funções novas. O jogo oficial e a web usam as funções antigas, que não mudaram (impressão digital registrada no doc 13) |
| 5. Há recuperação se algo der errado? | Sim: (a) restaurar o personagem pela cópia; (b) `servidor/reverter_fase1.sql` remove as funções novas; (c) o jogo oficial não muda, porque o teste é outro executável |

**Ponto importante:** a sua conta é **GM**. Personagens de conta GM **passam direto** pelas travas novas, então não servem para testar a proteção.

### Duas formas de fazer o teste (decisão D40)

| Opção | Como | Isolamento | Esforço |
|---|---|---|---|
| **A (recomendada agora)** | Você cria **uma conta nova, comum**, pela tela de cadastro do próprio jogo, e um personagem novo, sem progresso nenhum. Eu tiro a cópia dele antes e o restauro ou apago depois | Os dados de teste ficam no banco oficial, mas num personagem descartável. Nenhum personagem importante é tocado | Baixo |
| **B (isolamento total)** | Criar um **segundo projeto Supabase só para testes**: o plano gratuito permite 2 projetos **[C]**, a confirmar antes. Copiar para ele o esquema e as funções e gerar um executável de teste apontando para lá | Total | Médio: cópia do esquema e um executável a mais |

### Roteiro do teste (com a Opção A) — resultados esperados e pontos de verificação

Antes de começar: você me avisa o nome do personagem de teste e eu registro a cópia dele.

| # | Ação | Resultado esperado no jogo | Ponto de verificação (eu confiro no banco) |
|---|---|---|---|
| 1 | Entrar com o personagem novo, perto de Vila Aurora | Entra normalmente | `pos_at` passa a ter data a cada salvamento (20 s) |
| 2 | Matar 3 javalis ou lobos | Experiência e itens aparecem como sempre | `kills` = 3 da família; nível subindo |
| 3 | Ir ao "Campos do Amanhecer" e vencer o Rei Javali | "+XP" grande e mensagem de chefe | `boss_cd` com o ponto e a hora |
| 4 | Esperar o chefe voltar antes de 5 min e vencê-lo de novo | Mensagem "Este chefe ainda não voltou" e sem recompensa | Nada novo em `kills` para o chefe |
| 5 | Entrar na taverna de Aurora, esperar 25 s, fechar o jogo e abrir de novo | Volta **na porta da taverna** | `x, z` iguais à porta (não o canto 5,5) |
| 6 | Ir ao Porto Maré-Alta, usar o redemoinho, esperar 25 s | **Não** aparece "Posição corrigida pelo servidor" | Posição em Abissália aceita; nenhum alerta "movimento" |
| 7 | Desligar o Wi-Fi 20 s e ligar de novo | Outros jogadores (ou o seu outro personagem logado) voltam em até 30 s | — (lado do jogo) |
| 8 | No fim | — | `game.alertas` sem alertas falsos; personagem restaurado ou apagado, como você decidir |

---

## Parte 3 — Esclarecimentos técnicos pedidos

### 3.1 Skinning independente da armadura
- A armadura é **uma malha separada** do corpo, ligada ao **mesmo esqueleto de 65 ossos**. É assim que as roupas atuais já funcionam (`outfit_*`).
- **Partes rígidas** (placas de peito e ombreiras, braçadeiras, caneleiras): peso 100% em **um único osso** cada, para que o metal não entorte.
- **Partes macias** (gibão de couro, tecido, cinto): pesos **transferidos da superfície do corpo V2** mais próxima, usando a transferência de pesos do Blender, depois limpos (máximo de 4 ossos por vértice, soma 1).
- **Folga:** a armadura fica de 4 a 8 mm acima da pele. Onde a armadura cobre, a pele do corpo é escondida por uma máscara, para não atravessar.
- **Teste:** os mesmos passos do protocolo 8.2 do guia, aplicados à armadura vestida.

### 3.2 Avaliação das deformações nas 28 animações
1. Um script toca **as 28 animações** no Godot, numa cena de teste isolada.
2. Em cada animação, mede **3 quadros** (início, meio, fim): **84 poses por corpo**.
3. Em cada pose, calcula o **estiramento de cada aresta** da malha em relação ao repouso. Acima de **1,6×** marca a região (ombro, cotovelo, quadril, joelho, punho, dedos).
4. Também mede **intersecções** de braço com tronco e de perna com perna.
5. Gera uma **prancha de capturas** de frente e de lado das poses marcadas, além de uma tabela por animação (passou / revisar).
6. O mesmo é feito com a armadura vestida.
7. Critério: **zero** regiões acima de 2,0× e no máximo 5% de poses marcadas, todas revisadas a olho por você.

### 3.3 Formatos de compressão que o notebook realmente aceita
- O executável de teste ganha um **diagnóstico de vídeo**: ao iniciar, grava no `registro.txt`:
  - o renderizador em uso;
  - a placa de vídeo e o driver;
  - os formatos comprimidos aceitos (`RenderingServer`: S3TC/BPTC, ETC2, ASTC).
- Só o executável de teste ganha isso; o oficial não muda.
- Com essa resposta, a tabela de compressão do guia é fechada com **o que a sua placa suporta**, e não com suposições.

### 3.4 Comparação de desempenho repetível
O executável de teste ganha um **modo de medição** (`--benchmark`):
1. Mesma versão, mesma resolução (1280×720) e mesmo nível de qualidade.
2. Câmera em **caminho fixo** de 30 s na praça da capital, com 20 personagens parados em posições fixas: primeiro os atuais, depois os V2.
3. **10 s de aquecimento** sem medir.
4. **3 rodadas**, com a **mediana** guardada: FPS médio, 1% dos piores quadros, tempo de quadro, chamadas de desenho, triângulos e memória de vídeo e de textura.
5. Resultado salvo num arquivo de texto, junto com o commit e a placa de vídeo.
6. Roda aqui (sem FPS) e no notebook (com FPS). Só valem comparações feitas na mesma máquina.

---

## Decisões novas
- **D40:** forma do teste online. **A**: conta comum descartável no banco oficial, com cópia e restauração (recomendada). **B**: segundo projeto Supabase só para testes.
- **D41:** aprovar a B3 (ligar o corpo V2 ao esqueleto do jogo, seção 1.5) e o teste de deformação nas 28 animações. Continua isolado e fora do jogo.
- **D42:** incluir no executável **de teste** o diagnóstico de vídeo (3.3) e o modo de medição (3.4). O oficial não muda.
