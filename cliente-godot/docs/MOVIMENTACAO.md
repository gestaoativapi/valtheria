# Movimentação dos personagens: como medir, calibrar e proteger

Este documento foi escrito em 26/11. Toda mudança em andar, correr, pular, pegada ou guarda de arma segue estes 4 passos.

## 1. Medir antes de mexer

Todas as medições rodam sem tela (`--headless`), em 2 a 10 segundos. Os números são os mesmos de quando rodam com imagem.

| Ferramenta | O que mede |
|---|---|
| `teste/medir_escorrega.gd` | Quanto o pé de apoio anda no chão por passo, com o corpo andando de verdade. Mede andar a 1,5 m/s, ronda a 1,35 m/s, correr a 5,2 m/s e disparar a 6,5 m/s. Com `--antigo` mede como era antes de 26/11. |
| `teste/medir_passada.gd` | A velocidade natural de cada animação (Walk, Walk_Formal, Jog_Fwd, Sprint) em cada corpo próprio. Mede com o boneco parado no lugar e o pé de apoio andando para trás. |
| `teste/medir_passada_mob.gd` | O mesmo para os bichos (lobo, aranha, lagarto, golem), com o modelo em 1 m de altura. |
| `teste/medir_atravessa.gd` | Quanto a arma, o escudo e a mão entram no corpo em cada fase: parado, andando, correndo, guarda, correndo em combate e golpe. |
| `teste/corretivo_arco.gd` | Grava a forma corretiva do ombro no tiro de arco em `data/corpos/arco_<corpo>.bin`. Refazer sempre que o corpo (`.glb`) mudar. |

## 2. Calibrar pela medida, não no olho

### Passada

A velocidade em que o pé não patina é `K × altura do quadril`. Os valores de K ficam em `PASSADA_K` (`scripts/character.gd`).

- Para calibrar, rode `medir_escorrega.gd -- --k=0.94`, depois com `--k=1.00`, depois com `--k=1.06`.
- Escolha, para cada corpo e animação, o valor com menos centímetros por passo.

### Escolha da animação

`character.mover(v, modo)` escolhe a animação pela velocidade:

| Velocidade | Animação |
|---|---|
| Andar | Walk |
| Andar, com passo curto demais para a velocidade | Walk_Formal |
| Correr | Jog_Fwd |
| Correr, com perna curta ou muito rápido | Sprint |

Cada troca tem uma folga (histerese), para a animação não ficar trocando de um lado para o outro.

### Onde usar

Toda locomoção usa `mover()`:

- jogador (`main.gd`)
- moradores, guardas e viajantes (`npcs.gd`)
- outros jogadores (`social.gd`)
- bandidos e chefes humanoides (`combat.gd`)

Os bichos usam `combat._ritmo_patas()`.

## 3. Conferir em imagem

- `teste/estudio_passada.gd`: vídeo antes/agora sobre chão quadriculado.
- `teste/estudio_postura.gd`: poses, guarda e giro.

## 4. Proteger: teste automático

`testes/regressao.sh`, passo 8 (`testes/test_movimento.sh`):

- **Pé:** falha se algum corpo patinar mais de 12 cm por passo.
- **Armas:** mede 12 corpos × 9 armas e compara com `testes/base_atravessa.json`. Falha se alguma fase piorar mais de 8 pontos percentuais.

Quando uma melhoria for conferida em imagem, grave a nova base com:

```
bash testes/test_movimento.sh <godot> --gravar
```

## Cuidados

- A medição com tela e muitos bonecos ao mesmo tempo distorce os golpes. O jogo usa o relógio real (`busy_until`), e com tela lenta o golpe termina cedo. Prefira `--headless`, ou poucos bonecos por vez.
- Nunca mexer no esqueleto oficial de 65 ossos nem nas 28 animações. As correções são de ritmo, escolha de animação, IK e posição.
