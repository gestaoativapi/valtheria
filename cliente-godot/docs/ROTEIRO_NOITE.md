# Roteiro de produção — madrugada 24→25/11/2026 (autorizado por Robson às 23:57)
Trabalho livre seguindo esta linha, sem pedir autorização. Marcar [x] ao terminar cada item e anotar o resultado.

## Regras fixas (não mudam)
- Só na branch base-teste; não modificar main; sem merge e sem publicação.
- Não alterar o Supabase de produção; não acessar dados de jogadores.
- Sem Meshy, Mixamo ou serviço pago; sem consumir créditos pagos.
- Não modificar o esqueleto oficial de 65 ossos nem as 28 animações oficiais.
- Não excluir arquivos oficiais nem do PC (o que sair vai para _PARA_EXCLUIR_Valtheria_antigos).
- Cada etapa: medir (medir_atravessa / estúdio), corrigir, regressão (testes/regressao.sh) antes do commit.
- Assets só gratuitos com uso comercial; nada copiado de outros jogos.
- Quando precisar criar algo (imagem, modelo, textura, som), usar plataformas gratuitas (Gemini na conta do
  Robson, Hunyuan3D, Blender/scripts locais, pacotes CC0) e refazer quantas vezes for preciso até ficar
  definitivo: comparar com o anterior, medir e só então trocar no jogo (orientação de Robson, 25/11 00:32).

## Agenda das rodadas
00:55, 01:45, 02:30, 03:15, 04:00, 04:45, 05:30, 06:15 (rodada normal: a menção a "item 5" nessa mensagem é antiga;
seguir o roteiro), 07:00 (entrega = item 14), 10:20 (corpos novos no Hunyuan, se ainda faltarem).

## Prazo por rodada
Cada rodada (~70 min) fecha pelo menos um item ou uma parte medida dele, com commit; se um item ficar grande,
dividir em partes no Diário e seguir para o próximo na rodada seguinte.

## Linha de produção
1. [x] Pegada — resíduos: escudo x cabeça do gigante no golpe; lança correndo em combate (coxa); duas espadas
       apontando à frente (elfa/orc); arco em guarda tocando o tronco (anão/orc/gigante).
2. [x] Postura de cada raça (parado, andando, correndo, guarda): medir ângulos de tronco/cabeça/braços em todas as
       raças e gêneros; corrigir quem tomba ou fica rígido; manter o caráter de cada raça (orc pesado, elfo ereto,
       anão firme, gigante lento, fera curvada, draconato altivo, sombrio inclinado, humano neutro).
3. [ ] Correções gráficas: sola/bota clara nos corpos próprios; enquadramento dos estúdios para o gigante;
       emendas de textura; fotos do jogo (cidade, campo, combate) procurando falhas visuais e corrigindo.
4. [x] Corpos novos (quando a cota grátis do Hunyuan voltar): giganta, elfo/elfa branca, elfo/elfa negra,
       humano/humana — `ferramentas/racas/nova_raca.py`; conferir juntas, mãos, armas e vídeo.
5. [ ] Gráfico nos 4 níveis (baixo, normal, alto, ultra): fotos fixas de cidade, campo, masmorra e combate em
       cada nível; corrigir o que estiver feio (sombras, LOD, vegetação, água, céu, luz); manter 60 fps no PC e
       30 no celular (medir antes e depois).
6. [ ] Cidade e monstros: revisar a cidade (NPCs, prédios, chão, iluminação) e cada família de monstro
       (proporção, animação, pés no chão, efeitos); corrigir o que estiver ruim.
7. [ ] Encantamento: corrigir os problemas gráficos do brilho/aura de encanto em todas as armas e armaduras.
8. [ ] Equipamentos com vida: cada grau (Sem Grau, D, C, B, A, S, R) com visual próprio (cor, brilho, detalhe)
       por arma e armadura, seguindo a grade do jogo; conferir em todas as raças.
9. [ ] Skills: implantar todas as skills das classes da grade; banco de skills e banco de classes (dados
       consultáveis no jogo); caixa de skills (barra) em que o jogador escolhe o que usar ao atacar.
10. [x] Trava de PvP: atacar jogador só com Ctrl + atalho/clique de skill (sem Ctrl, nada acontece contra jogador).
11. [x] NPC tutor que explica o jogo (primeiros passos, classes, skills, craft, PvP), na cidade inicial.
12. [ ] Enredo e missões: linha principal do primeiro arco + missões secundárias da região inicial, com
       diálogos originais e recompensas pela grade.
13. [ ] Revisão minuciosa: procurar erros e falhas (log do Godot, regressão, testes de cada sistema novo) e corrigir.
14. [x] Entrega da manhã: regressão, exe + exe de testes + APK na pasta Downloads\Valtheria-base-teste-40 com
       SHA-256 e QR; v39 para _PARA_EXCLUIR_Valtheria_antigos; vídeos de antes/depois; resumo curto para Robson.

## Diário
- 14:20 armas nas 12 combinações novas (6 raças x 2 gêneros, 11 armas) com teste/medir_atravessa.gd (o golpe do
  arqueiro agora é o tiro, como no jogo). Arco: âncora fora do rosto (meia cabeça ao lado) e pronta mais à frente
  nos corpos largos; lança e cajado com a mão mais perto do pé (por raça em GRIP_RACA); duas espadas menores nos
  gigantes. Ex.: arco tiro gigante 42%/28 cm -> 33%/7 cm; lança correndo elfo negro 51% -> 2%; duplas gigante na
  cabeça 34% -> 0. Regressão: 0 falhas. Resta: espada no golpe do elfo negro passa 3-6 cm na cabeça; mão do anão
  no peito com martelo/cajado (barba e armadura largas).
- 12:40 item 4: 7 corpos novos gerados no Hunyuan3D com a conta Hugging Face do Robson (giganta, elfo/elfa, elfo/elfa
  negros, humano/humana), pelo padrão nova_raca.py já com pesos suavizados, cabeça inteira e bordas da textura.
  Rosto assado com a vista de frente mandando (lados desalinhavam). Cabeça erguida 20° nas raças novas. Vídeo de teste
  com câmera afastada para os gigantes (--longe). Regressão: 0 falhas. Resta: manchas no rosto da humana.
- 10:30 refino dos corpos próprios (Robson: ainda com imperfeições). Medição nova teste/medir_esticar.gd (pele na
  CPU, aresta por aresta, 4 animações): vincos em cintura, virilha, ombro, joelho, pescoço. Ferramentas novas:
  suavizar_pesos.py (difusão dos pesos, dedos fixos), borda suave da cabeça no pescoço/trapézio, barba até 1,56 m,
  preencher_bordas.py (beira das ilhas de UV sem preto, manchas escuras do rosto do gigante, pontos brancos das
  botas). Pele esticando >3x: orc M 6,7%->4,2%, orc F 4,3%->1,6%, anão M 4,3%->1,7%, anã 4,8%->1,6%, gigante 4,4%->1,7%.
  Tudo ligado no nova_raca.py. Regressão: 0 falhas. Resta: virilha e axila (malha fundida em pose A).
- 09:20 cabeça dos orcs, 2ª rodada (Robson: ainda com problema): (1) bochechas, presas e barba do orc macho ainda no
  peito (rosto mais largo que o alto da cabeça) -> elipse alarga à frente e barba até 1,60 m na cabeça
  (--frente-y); (2) cabeça olhando o chão na animação dos corpos próprios -> CABECA_ERGUE (orc M -36°, F -24°,
  anão -6°, gigante -10°), conferido em foto. Rosto: distorção 0% em parado, corrida e golpe. Regressão: 0 falhas.
  Pendente: ponta da barba abaixo de 1,57 m ainda estica no golpe; manchas escuras na textura do rosto do gigante.
- 08:30 (Robson acordado) cabeça esticada dos corpos próprios: a pele deixava queixo/rosto no spine_03 e nunca usava
  o neck_01. Nova ferramenta ferramentas/racas/pesos_cabeca.py (cabeça inteira no Head pela elipse medida da cabeça,
  pescoço em rampa spine_03>neck_01>Head), aplicada a orc m/f, anão m/f e gigante m e ligada no nova_raca.py.
  Medição teste/medir_cabeca.gd (pares de pontos do rosto, pele na CPU com a pose real): orc M golpe máx 95% -> 0-27%
  (o resto é o ombro alto do orc, não o rosto); orc F 53% -> 0%; anão M 28% -> 0%; gigante 38% -> 0%. Regressão: 0 falhas.
- 06:25 item 14: entrega v40 em Downloads\Valtheria-base-teste-40 (exe, exe de testes com chave pública anon,
  APK, SHA256 conferido no PC, QR, vídeo antes/depois); v39 movida para _PARA_EXCLUIR_Valtheria_antigos.
- 05:40 item 3 (parte 2): fogo refeito (línguas em gota, miolo amarelo + borda laranja + brasa na base; antes era
  uma bola branca) — estúdio teste/estudio_fogo.gd. Nascer no centro exato de obstáculo (chafariz da capital) agora
  empurra para fora. Minimapa desenha a planta real da cidade (prédios e obstáculos da colisão) sobre a imagem do
  mundo. Conferido em foto: chão calçado até a muralha + telhados; capital nasce fora do chafariz. Regressão: 0 falhas.
  Falta do item 3: colunas de prata de Umbraval no ultra (foto no PC).
- 04:50 itens 10 e 11: trava de PvP (jogador só é atacado com Ctrl + skill ou Ctrl + clique; sem Ctrl aparece
  aviso). Guia de Valtheria na praça de cada cidade: quadro com 6 assuntos (primeiros passos, combate, PvP,
  classes, graus/encanto, missões), texto também no bate-papo. Regressão: 0 falhas.
- 03:40 item 5 (parte 1): fotos do jogo no PC do Robson (placa de vídeo; o servidor sem placa leva >10 min por
  foto) em Downloads\Valtheria-fotos-madrugada. ULTRA estourava em branco (SDFGI em mundo aberto): desligado,
  SSIL suave no lugar; neblina volumétrica 0,006 -> 0,0025 (alto/ultra cinza). Achados para as próximas rodadas:
  minimapa da cidade é um quadrado verde (sem ruas/prédios), chama da fogueira chapada e forte, colunas de
  Umbraval brancas demais no ultra, ponto de teste nasce em cima da fonte/fogueira. Hunyuan: cota ainda esgotada.
- 03:10 item 7 (parte 1): estrela de encanto com teste de profundidade (atravessava rosto e corpo), anéis de
  rastro (+13/+16) na escala do corpo, casca de aura menor em cabeça grossa (martelo). Estúdio aceita nível de
  encanto (6º campo da lista). Martelo do anão em guarda: mudar a guarda piorou cajado/lança -> mantido (mão
  encosta 1-2 cm na armadura). Fotos do mundo por qualidade: o jogo completo leva >10 min para carregar no
  servidor sem placa; próxima rodada faz uma qualidade por vez.
- 02:30 item 2 (parte 2): espada parada com a ponta para baixo e à frente (antes apontava reta como lança);
  corpos próprios com 55% da pose da raça (a malha já vem curvada): escudo x cabeça do gigante 39->1%,
  espada do orc no golpe 23->2%; espada fora de combate sem nenhum toque em 6 corpos. Martelo do anão: mão
  esquerda no peito em guarda (32%, 2,3 cm) — próximo ajuste.
- 01:00 item 1: duas espadas fora de combate com as lâminas para baixo em todas as raças (punho até 60°;
  medido: fora de combate limpo; golpe toca a cabeça 18-20% no orc/gigante, até 3,6 cm). Lança: testei pegar mais
  atrás (humano 31->11%), mas o gigante piorou (3->87%); voltei ao original. Escudo do gigante: a 'cabeça'
  medida inclui a barba longa (raio 26 cm); fica para o item 6. Arco em guarda: 8-13% tronco, aceito.
- 01:40 item 3 (parte 1): solas dos corpos próprios sem manchas brancas (faixa da sola em couro escuro +
  limpeza do branco do fundo nos orcs).
- 00:30 item 2 (parte 1): postura medida em 17 corpos (teste/medir_postura.gd). Corrida: goblin 48→32°, sombrio 33→21°,
  fera 38→28°, draconato 29→25° (CORRIDA_RETA_V3); elfo em combate deixou de recuar (−3,6→−0,3°); cabeça de
  orc/anão/gigante um pouco mais erguida na guarda. Falta: cabeça dos corpos próprios ainda muito à frente na guarda.
