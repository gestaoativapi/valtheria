# 08 — Magias, Efeitos Visuais e Animações

**Versão examinada:** `fx.gd`, `combat.gd`, `character.gd`, `atmos.gd`, `world.json.arch` (0.17.0) · **Data:** 14/11/2026
Marcas: **[F]** fato comprovado · **[P]** proposta · **[C]** confirmar.

---

## 1. Efeitos existentes [F]

| Função (`fx.gd`, 226 linhas) | O que faz | Onde é usada |
|---|---|---|
| `colors(elem)` | Par de cores por elemento | Todos os efeitos |
| `emitter(...)` | Cria `CPUParticles3D` com material aditivo ou normal | Base |
| `fire(size, smoke)` | Fogo com fumaça | Fogueiras, tochas |
| `burst(pos, elem, size)` | Explosão de partículas no impacto | Golpes e habilidades |
| `bolt(from, to, elem)` | Projétil entre dois pontos | Magias e arco |
| `aura(target, elem, s)` | Brilho em volta do personagem | Reforços |
| `dust()` | Poeira | Passos e ambiente |

Outros:
- `atmos.gd`: céu (`ceu.gdshader`), névoa, luz por zona, janelas acesas à noite.
- `especial.gd`: redemoinhos de portal, bolha submarina.
- 23 pontos do código criam partículas, **todas de CPU** (`CPUParticles3D`).

## 2. Ligação com as habilidades [F]
- 162 habilidades; o campo `fx` define o efeito:

| `fx` | Habilidades |
|---|---|
| Sem efeito (`""`) | **64** |
| `holy` | 20 |
| `fire` | 15 |
| `dark` | 14 |
| `arcane` | 9 |
| `spirit` | 8 |
| `ice` | 7 |
| `earth` | 6 |
| `nature` | 6 |
| `wind` | 5 |
| `poison` | 5 |
| `blood` | 3 |

- Hoje todas as habilidades usam os mesmos 3 formatos (explosão, projétil, aura), mudando só a cor. Não há efeito de **ativação** separado do de **impacto**, nem decalque no chão para zona ou armadilha.
- `blink` e `mana` não têm efeito nem lógica no nativo.

## 3. Animações [F]
28 clipes compartilhados (lista em `04`, 1.2).

| Ação | Situação |
|---|---|
| Andar, correr, disparada, parado | Sim |
| Pulo | Sem clipe próprio (o corpo sobe com o clipe de corrida) **[C]** |
| Nado | Não (flutua) |
| Ataque espada e uma mão | Sim (Sword_Attack, Regular A/B/C) |
| Duas mãos, lança, cajado, arco | **Não**: usam golpe de espada; o arco não puxa a corda |
| Defesa | Sword_Block, Shield |
| Magia | Spell_Simple (idle e shoot) para todas |
| Coleta, fabricação | Farm_Harvest, TreeChopping, PickUp, Interact (usadas por NPCs) |
| Reação ao golpe, morte | Hit_Chest, Death01 |
| Montaria, voo | Não |

Transições: `AnimationPlayer.play(n, 0.2)` com mistura de 0,2 s. Não há máquina de estados (`AnimationTree`).

## 4. Desempenho dos efeitos [F/C]
- Partículas de CPU: baratas em quantidade baixa; não há limite global de efeitos simultâneos. **[C]** Medir com 10 monstros e habilidades em área.
- Sem bloom configurado por nível de qualidade **[C]** (confirmar em `world.gd`/`atmos.gd` na etapa de efeitos).

## 5. Padrão proposto por habilidade [P]

| Etapa | Duração | Exemplo (fogo) |
|---|---|---|
| Preparação | 0,2–0,6 s | Brasa nas mãos + círculo no chão |
| Execução | Clipe da arma ou de magia | Spell_Shoot ou golpe |
| Projétil ou percurso | Pelo alcance | Bola de fogo com rastro |
| Impacto | 0,3 s | Explosão + faísca + luz curta (sem `OmniLight` nova; usar emissivo) |
| Estado | Duração do efeito | Chama pequena no alvo |
| Retorno ao jogador | — | Número de dano, tremor leve da câmera no crítico, som |

**Biblioteca por elemento** (11 elementos do jogo): luz, vento, sombra, fogo, terra, natureza, raio, gelo, água, mais arcano e sangue. Cada um tem cor, forma de partícula, textura de rastro e som próprios.

**Eventos especiais** (ligados à Bíblia, `02`):
- portal das Fendas;
- fragmento brilhando ao ser coletado;
- aparição de guardião;
- subida de nível e troca de classe (coluna de luz curta);
- evolução de pet.

## 6. Limites de desempenho [P]
- No máximo 2.000 partículas vivas no total no desktop e 600 no celular.
- Emissores somem fora da tela e além de 40 m.
- Nível de qualidade baixo: metade das partículas e sem rastro.
- Nenhum efeito permanente além de fogueiras, tochas e portais (e esses com distância de desenho).

## 7. Plano de integração [P]
1. Criar `fx_lib` (dados de efeito por `fx`) sem mudar `combat.gd` além da chamada.
2. Preencher as 64 habilidades sem efeito.
3. Implementar `blink` e `mana`.
4. Pacote de animações por tipo de arma (CC0, licença conferida; ou Mixamo **[C]**, que tem licença própria a verificar).
5. Som: o nativo não tem nenhum; usar sons livres (CC0) e o `sfx.js` da web como lista de referência.

## 8. Decisões
- **D29:** fonte das animações novas: pacote CC0 (recomendado) ou outra fonte com licença conferida.
- **D30:** áudio entra junto com os efeitos ou em etapa própria?
