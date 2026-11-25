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
2. [ ] Postura de cada raça (parado, andando, correndo, guarda): medir ângulos de tronco/cabeça/braços em todas as
       raças e gêneros; corrigir quem tomba ou fica rígido; manter o caráter de cada raça (orc pesado, elfo ereto,
       anão firme, gigante lento, fera curvada, draconato altivo, sombrio inclinado, humano neutro).
3. [ ] Correções gráficas: sola/bota clara nos corpos próprios; enquadramento dos estúdios para o gigante;
       emendas de textura; fotos do jogo (cidade, campo, combate) procurando falhas visuais e corrigindo.
4. [ ] Corpos novos (quando a cota grátis do Hunyuan voltar): giganta, elfo/elfa branca, elfo/elfa negra,
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
10. [ ] Trava de PvP: atacar jogador só com Ctrl + atalho/clique de skill (sem Ctrl, nada acontece contra jogador).
11. [ ] NPC tutor que explica o jogo (primeiros passos, classes, skills, craft, PvP), na cidade inicial.
12. [ ] Enredo e missões: linha principal do primeiro arco + missões secundárias da região inicial, com
       diálogos originais e recompensas pela grade.
13. [ ] Revisão minuciosa: procurar erros e falhas (log do Godot, regressão, testes de cada sistema novo) e corrigir.
14. [ ] Entrega da manhã: regressão, exe + exe de testes + APK na pasta Downloads\Valtheria-base-teste-40 com
       SHA-256 e QR; v39 para _PARA_EXCLUIR_Valtheria_antigos; vídeos de antes/depois; resumo curto para Robson.

## Diário
- 01:00 item 1: duas espadas fora de combate com as lâminas para baixo em todas as raças (punho até 60°;
  medido: fora de combate limpo; golpe toca a cabeça 18-20% no orc/gigante, até 3,6 cm). Lança: testei pegar mais
  atrás (humano 31->11%), mas o gigante piorou (3->87%); voltei ao original. Escudo do gigante: a 'cabeça'
  medida inclui a barba longa (raio 26 cm); fica para o item 6. Arco em guarda: 8-13% tronco, aceito.
- 01:40 item 3 (parte 1): solas dos corpos próprios sem manchas brancas (faixa da sola em couro escuro +
  limpeza do branco do fundo nos orcs).
- 00:30 item 2 (parte 1): postura medida em 17 corpos (teste/medir_postura.gd). Corrida: goblin 48→32°, sombrio 33→21°,
  fera 38→28°, draconato 29→25° (CORRIDA_RETA_V3); elfo em combate deixou de recuar (−3,6→−0,3°); cabeça de
  orc/anão/gigante um pouco mais erguida na guarda. Falta: cabeça dos corpos próprios ainda muito à frente na guarda.
