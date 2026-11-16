# 15 — Relatório: V2 corpo e rig (D41), diagnóstico e benchmark (D42), plano do ambiente de testes (D40)

**Data:** 14/11/2026
**Garantia:**
- `main` intacta;
- nenhum modelo oficial nem animação oficial alterados;
- nada publicado;
- nenhum crédito Meshy usado;
- nenhuma alteração no banco de produção nesta etapa.

Marcas: **[F]** fato comprovado · **[P]** proposta · **[C]** a confirmar.

---

## Parte 1 — D41: corpos V2 ligados ao esqueleto do jogo

### 1.1 O que foi feito [F]
Ferramenta `ferramentas/v2/ligar_esqueleto.py`, rodada no ambiente isolado:

1. **Pose:**
   - percorre o esqueleto do MPFB do quadril às pontas;
   - gira cada osso para apontar na **mesma direção do osso do jogo** (pelo osso filho: braço → antebraço, coxa → canela, dedo 1 → dedo 2…);
   - a malha acompanha pelos **pesos originais do MPFB**.
2. **Esqueleto final:** usa as **rotações de repouso do próprio jogo** (de `body_male.glb` e `body_female.glb`), com as articulações na anatomia V2.
3. **Pesos:**
   - copiados do MPFB osso a osso, pelo nome;
   - os ossos que o jogo não tem (`breast_l/r` do corpo feminino) passam o peso ao pai (`spine_03`);
   - os 12 ossos de ponta foram criados sem peso, na escala do corpo.
4. **Quadril:** fator de altura do quadril para as trilhas de posição das animações. É a mesma solução que o jogo já usa nos anões (`OWN.hip`): masculino 1,0302, feminino 0,9573.

### 1.2 Compatibilidade comprovada por teste [F]

| Verificação | Masculino | Feminino |
|---|---|---|
| Ossos | 65/65, mesmos nomes e mesma hierarquia | 65/65 |
| Diferença de rotação local de repouso para o jogo | **0,000°** (medida) | **0,000°** |
| Altura final | 1,799 m | 1,682 m |
| Triângulos / vértices | 26.756 / 14.517 | 26.756 / 14.517 |
| Pesos | Até 4 ossos por vértice, soma 1 | Igual |
| As 28 animações tocam no Godot | Sim (capturas) | Sim |

### 1.3 Protocolo de deformação: 28 animações × 3 quadros = 84 poses por corpo [F]
Ferramenta `ferramentas/v2/deformacao.py`:
- aplica as animações oficiais (`anims_a`, `anims_b`, **sem alterá-las**) e calcula a malha deformada em cada pose;
- mede o estiramento de **cada aresta** em relação ao repouso;
- faz **o mesmo cálculo nos corpos atuais**, para comparar nas mesmas condições.

**Achado honesto sobre o critério:**
- O limite absoluto proposto antes (nenhuma aresta acima de 2,0×) **falha também nos corpos atuais**, que você já usa e aprova no jogo.
- Motivo: o repouso é a pose em T, e em qualquer pose com braço abaixado as arestas pequenas da axila e do ombro mudam muito.
- Por isso o critério válido é **comparativo**: a V2 precisa deformar **igual ou melhor** que o corpo atual na mesma pose.
- Usei o percentil 99 do estiramento (p99), que ignora o 1% de arestas minúsculas mais extremas, e a contagem de arestas acima de 1,6×.

| Corpo | p99 mediano V2 | p99 mediano atual | Arestas > 1,6× (mediana) V2 / atual | Poses em que a V2 é igual ou melhor |
|---|---|---|---|---|
| Masculino | **1,32** | 1,64 | **101** / 223 | **84 de 84** |
| Feminino | **1,35** | 1,47 | **105** / 133 | **84 de 84** |

Pior quadro de cada animação (p99; quanto menor, melhor):

| Animação | V2 M p99 | Atual M p99 | V2 F p99 | Atual F p99 | Resultado |
|---|---|---|---|---|---|
| Consume | 1.35 | 1.69 | 1.37 | 1.50 | Passou |
| Dance_Loop | 1.35 | 1.67 | 1.36 | 1.47 | Passou |
| Death01 | 1.44 | 1.62 | 1.45 | 1.49 | Passou |
| Farm_Harvest | 1.48 | 1.87 | 1.45 | 1.71 | Passou |
| Hit_Chest | 1.31 | 1.64 | 1.33 | 1.48 | Passou |
| Idle_FoldArms_Loop | 1.37 | 1.69 | 1.36 | 1.51 | Passou |
| Idle_Loop | 1.30 | 1.62 | 1.32 | 1.47 | Passou |
| Idle_Shield_Loop | 1.32 | 1.65 | 1.34 | 1.48 | Passou |
| Idle_Talking_Loop | 1.25 | 1.41 | 1.29 | 1.37 | Passou |
| Interact | 1.32 | 1.66 | 1.35 | 1.49 | Passou |
| Jog_Fwd_Loop | 1.39 | 1.69 | 1.41 | 1.54 | Passou |
| OverhandThrow | 1.37 | 1.65 | 1.40 | 1.47 | Passou |
| PickUp_Table | 1.33 | 1.66 | 1.36 | 1.48 | Passou |
| Punch_Cross | 1.39 | 1.76 | 1.40 | 1.58 | Passou |
| Punch_Jab | 1.36 | 1.76 | 1.38 | 1.58 | Passou |
| Shield_OneShot | 1.35 | 1.69 | 1.35 | 1.50 | Passou |
| Sitting_Idle_Loop | 1.32 | 1.53 | 1.35 | 1.53 | Passou |
| Spell_Simple_Idle_Loop | 1.29 | 1.40 | 1.30 | 1.38 | Passou |
| Spell_Simple_Shoot | 1.30 | 1.42 | 1.31 | 1.38 | Passou |
| Sprint_Loop | 1.40 | 1.68 | 1.42 | 1.52 | Passou |
| Sword_Attack | 1.46 | 1.75 | 1.49 | 1.59 | Passou |
| Sword_Block | 1.34 | 1.64 | 1.36 | 1.49 | Passou |
| Sword_Regular_A | 1.53 | 1.75 | 1.55 | 1.64 | Passou |
| Sword_Regular_B | 1.50 | 1.75 | 1.53 | 1.63 | Passou |
| Sword_Regular_C | 1.48 | 1.65 | 1.50 | 1.57 | Passou |
| TreeChopping_Loop | 1.38 | 1.75 | 1.39 | 1.55 | Passou |
| Walk_Loop | 1.30 | 1.57 | 1.33 | 1.44 | Passou |
| Yes | 1.34 | 1.70 | 1.36 | 1.54 | Passou |

### 1.4 Capturas comparativas [F]
`imagens/V2_Animacoes_Comparacao.png`: Idle, Jog, Sword Attack, Sword Regular B, Spell, Punch, Sitting e Death, com os corpos V2 nas animações oficiais.

**Limitação da captura:** os personagens atuais aparecem parados em Idle nessas imagens. A cena isolada não conseguiu travar o personagem atual no mesmo quadro, porque o sistema de animação dele assume o controle. A comparação **numérica** das 84 poses (1.3) foi feita nos dois corpos nas mesmas condições.

### 1.5 O que ainda falta para avaliar o visual da V2
- **Pele pintada, olhos, sobrancelhas e cabelo.** Hoje é a malha nua com cor única.
- **Armadura e espada** (Meshy só com custo apresentado e autorização sua).
- **Pontos para conferir a olho na prancha:**
  - mãos, porque o fechar dos dedos é desenhado para outra mão;
  - pés no chão durante a corrida.

**Situação da D41:** compatibilidade **aprovada pelos testes**. A avaliação visual final depende das texturas.

---

## Parte 2 — D42: diagnóstico de vídeo e benchmark (só no executável de teste) [F]

| Item | Valor |
|---|---|
| Ramificação | `v2-prova-visual`, commit `8151fbf` (não é a `main`) |
| Arquivos novos | `testes/benchmark.gd` e `.tscn`; `windows/Diagnostico de video (teste).bat`; `windows/Medir desempenho (teste).bat` |
| Arquivo alterado | `scripts/main.gd`: **só** um desvio no início, ativo apenas com `--benchmark` ou `--diagnostico-video`. Sem esses argumentos, o jogo é o mesmo |
| Testes automáticos | Workflow de testes **aprovado** (run `43602954807`); executável de teste "Valtheria-TESTE-v2-prova-visual" disponível em Actions → Artifacts |

**O diagnóstico grava:**
- versão do Godot e sistema;
- renderizador e driver;
- GPU, fabricante, versão da API e tipo de GPU;
- resolução;
- **formatos de compressão aceitos** (S3TC, BPTC, RGTC, ETC, ETC2, ASTC).

**O benchmark:**
- 20 personagens numa grade fixa de 5 × 4;
- câmera em volta fixa de 30 s (raio 9 m, altura 3 m);
- 10 s de aquecimento e 3 rodadas, com cada rodada e a mediana salvas em JSON;
- mede FPS médio, 1% baixo, tempo de quadro, chamadas de desenho, triângulos e memória de vídeo, texturas e estática;
- variantes separadas:
  - corpo atual;
  - **corpo V2**;
  - atual com armadura;
  - atual completo (armadura e espada).
- **V2 com armadura e espada entra quando essas peças existirem.**

**Rodada curta aqui** (renderização por software, só para provar que funciona; **o FPS não vale**):

| Variante (20 personagens) | Chamadas de desenho | Triângulos | Memória de texturas |
|---|---|---|---|
| Corpo atual (com a roupa base, cabelo e olhos) | 1.150 | 1,62 mi | 108 MB |
| Corpo V2 (malha nua, sem textura) | 101 | 0,44 mi | 35 MB |
| Atual com armadura | 1.396 | 1,65 mi | 129 MB |
| Atual com armadura e espada | 1.867 | 1,72 mi | 129 MB |

**Esta tabela não compara qualidade:** a V2 ainda não tem roupa, cabelo, olhos nem texturas. Por isso gasta menos. A comparação válida é a do notebook, com a V2 completa.

O diagnóstico deste ambiente confirmou que a medição lê corretamente:
- Mesa llvmpipe com OpenGL 4.5;
- S3TC, BPTC, RGTC e ASTC aceitos; ETC e ETC2 não.

**No seu notebook:**
1. Baixe o executável de teste.
2. Rode `Diagnostico de video (teste).bat` e depois `Medir desempenho (teste).bat` (cerca de 8 minutos).
3. Me envie `diagnostico_video.txt` e `benchmark.txt`.

---

## Parte 3 — D40: plano do ambiente de testes Supabase (Opção B) — **não criado ainda**

### 3.1 Disponibilidade [F]
- A organização "ativaonepi-cloud's Org" está no **plano gratuito** e tem **1 projeto** hoje (`mmorpg-teste`).
- O plano gratuito permite **2 projetos ativos**, então um segundo é possível com custo **zero** **[C]**: a ferramenta do Supabase mostra o preço antes de criar e só cria com o seu aceite.
- **Limitação:** no plano gratuito, um projeto **parado por 7 dias sem uso é pausado**. Basta reativá-lo no painel.

### 3.2 O que será copiado para o projeto de testes [F]

| Item | Quantidade | Origem |
|---|---|---|
| Migrações | **14** (de `20261111005944` até `backup_20261114…`) | Histórico do Supabase. Todas têm o SQL guardado e podem ser reaplicadas em ordem |
| Tabelas do esquema `game` | 26 de jogo (as 22 originais + `cidades`, `mob_fams`, `alertas`, `portais`). As 3 de backup **não** são copiadas | Migrações |
| Funções | 44 `public.game_*` + 18 do esquema `game` | Migrações |
| RLS | Ligado em todas; políticas de leitura `chat_read`, `node_read`, `ev_read` | Migrações |
| Gatilho de cadastro | `on_auth_user_created_game` em `auth.users` | Migrações |
| Tempo real | Publicação de `game.chat`, `game.events`, `game.node_state` | Migrações |
| Dados de conteúdo | Raças, classes, itens, receitas, loja, missões, recursos, cidades, monstros, portais | Migrações (as que inserem dados) **[C]**: conferir se todos os dados foram inseridos por migração. Senão, copio só as tabelas de conteúdo, por SQL de leitura |
| **Contas e personagens reais** | **Nenhum** | Não são copiados. O teste usa contas criadas no próprio ambiente de testes |

### 3.3 Configuração do executável de teste
1. O projeto de testes tem **outro endereço e outra chave pública**.
2. No GitHub, o trabalho "versão de teste" passa a **trocar** em `net.gd` o endereço e a chave de produção pelos do projeto de testes, só no executável de teste.
3. O jogo de teste mostra **"AMBIENTE DE TESTES"** na tela de entrada.

### 3.4 Comprovação de que o teste não acessa a produção
1. **Antes de gerar o executável**, o GitHub procura no código final o identificador de produção (`irpzdghikvoezfeodyiq`). Se encontrar, **o executável não é gerado**.
2. **Ao abrir**, o jogo de teste confere que o endereço não é o de produção, senão fecha com aviso.
3. **Prova cruzada:** depois do teste, mostro que **nenhuma linha** mudou no banco de produção:
   - contagem e impressão digital das tabelas `characters`, `inventory` e `alertas`, antes e depois;
   - os registros de acesso do projeto de produção sem chamadas vindas do teste.

### 3.5 Restauração e limpeza do ambiente de testes
- Antes de cada teste, uma cópia das tabelas de jogadores **do projeto de testes**.
- **Restaurar:** recarregar a cópia (só no projeto de testes).
- **Limpar:** apagar o projeto de testes inteiro no painel do Supabase. Isso não afeta a produção. Faço **só com a sua autorização expressa**.

### 3.6 Se a Opção B não for viável
Volto a apresentar a Opção A para aprovação específica, com os cuidados que você listou:
- conta comum e personagem descartável;
- backup individual;
- lista de registros afetados;
- restauração só com a sua autorização.

---

## Pendências
1. **D43:** criar o projeto Supabase de testes (custo zero a confirmar na tela do Supabase).
2. Benchmark e diagnóstico no notebook, com os dois arquivos `.txt`.
3. V2:
   - pele, olhos e cabelo, para a avaliação visual;
   - armadura e espada (Meshy, depende de orçamento e autorização).
4. D39 e D37 continuam aguardando.

## Riscos identificados
- **Peso do corpo V2 completo:** a malha nua já tem 1,8 vez os triângulos da atual. Com roupa e cabelo pode passar do limite do notebook. Isso só se sabe medindo lá.
- **Mãos:** o MPFB tem dedos mais longos que o modelo atual. A pegada das armas (`GRIP`) precisa ser conferida quando a espada existir.
- **Projeto gratuito de testes:** pausa sozinho depois de 7 dias sem uso.
