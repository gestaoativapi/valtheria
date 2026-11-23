# Animações extras (Universal Animation Library 1 e 2)

- Autor: Quaternius — licença **CC0** (domínio público, uso comercial livre).
  Página oficial: https://quaternius.com/packs/universalanimationlibrary.html e .../universalanimationlibrary2.html
- Versão usada: **Standard** gratuita. Arquivos obtidos do espelho CC0 `series-ai/jam-ready-assets` (GitHub):
  - UAL1_Standard.glb — sha256 69591853d817488edaa8fd9bf8fc1d821eaeaf789f8627b3cd23b41c4ed67997
  - UAL2_Standard.glb — sha256 8cee20ab1bc55130092447e810e26df22dd2803eccc54f52137a7d54d7ab88a8
- O rig é o mesmo do jogo (65 ossos do "universal humanoid rig"); não há retargeting.
- `extrair.gd` (rodar num projeto Godot vazio com os dois .glb) gera `assets/chars/anims_c.res` só com os clipes escolhidos.
  O jogo carrega esse arquivo em `character.gd::_clips()` **depois** das 28 oficiais e nunca substitui um nome já existente.

## Clipes incluídos (20)
UAL1: Roll, Hit_Head, Sword_Idle, Walk_Formal, Jump_Start, Jump, Jump_Land, Spell_Simple_Enter, Spell_Simple_Exit, Crouch_Idle, Crouch_Fwd
UAL2: Hit_Knockback, Sword_Heavy_Combo, Sword_Regular_Combo, Sword_Dash, Shield_Dash, Melee_Hook, Idle_Shield_Break, Sword_Regular_A_Rec, Sword_Regular_B_Rec

## Em uso (etapa humano + elfo)
- Walk_Formal: passada do elfo (8% mais rápida no ciclo).
- Sword_Idle: postura de guarda em combate, arma de uma mão sem escudo.
- Hit_Head / Hit_Chest: reação do jogador ao levar golpe.
- Sword_Dash / Shield_Dash: golpe de habilidade corpo a corpo alternado com Sword_Attack.
- Melee_Hook + Punch_Cross: habilidade sem arma.
- Hit_Knockback é uma queda completa (derrubada): reservado para efeito de atordoamento/derrubada, não para golpe comum.
