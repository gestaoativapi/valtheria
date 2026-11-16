# Benchmark do primeiro marco V3 no notebook de Robson (D56)

- **Data:** 15/11/2026
- **Executável:** `benchmark_v3 1.0`
- **Máquina:**
  - processador Intel Core i5-13420H, 12 núcleos;
  - **vídeo integrado Intel UHD Graphics**, Vulkan 1.4;
  - Windows 10.0.26300.
- **Configuração:** renderizador Forward+ (o mesmo do cliente oficial), janela de 1600×900, vsync desligado, sombras ligadas, 15 s por cenário.
- **Renderização por software:** não.
- **Evidências:** `evidencias/marco1/benchmark_rodadas/` (rodada1 a rodada4, em `.csv` e `.json`).

## Rodadas

| Rodada | Situação |
|---|---|
| 1 (Robson, 15h16) | **Inválida.** Duas instâncias do benchmark rodaram ao mesmo tempo, disputando a placa de vídeo: as duas janelas estavam abertas e mostravam resultados diferentes. Fica registrada só como histórico. |
| 2, 3 e 4 (Claude, 15h50 a 15h58) | Válidas. Rodadas no notebook pelo uso do computador, uma de cada vez, com a janela anterior fechada antes de abrir a próxima. Variação entre rodadas abaixo de 5%. |

## Resultado: média das rodadas 2, 3 e 4

| Cenário | FPS médio (mín.–máx.) | FPS 1% baixo | Quadro p99 (ms) | Chamadas de desenho | Triângulos | Memória de vídeo (MB) |
|---|---|---|---|---|---|---|
| Vazio | 114,7 (111,9–116,5) | 71,6 | 13,0 | 7 | 215 | 175,5 |
| Atual, 1 personagem | 114,6 (114,1–114,9) | 73,9 | 12,7 | 67 | 26.363 | 257,1 |
| Atual, 20 | 83,5 (80,9–85,2) | 48,2 | 19,8 | 793 | 453.804 | 320,2 |
| Atual, 40 | 55,6 (55,1–56,1) | 31,2 | 30,4 | 1.557 | 832.188 | 326,6 |
| V3, 1 personagem | 114,2 (112,9–115,2) | 73,2 | 12,8 | 46 | 18.627 | 224,3 |
| **V3, 20** | **90,6 (89,3–91,6)** | **61,2** | **15,6** | 717 | 560.463 | 272,0 |
| **V3, 40** | **65,3 (64,0–66,9)** | **38,4** | **25,0** | 1.413 | 1.073.262 | 278,9 |

## Leitura

- **Com 1 personagem há empate (cerca de 114 FPS).** A cena vazia dá o mesmo valor, então nesse caso o limite é o custo-base do motor, não o personagem.
- **Com 20 personagens o V3 é 8,5% mais rápido.** Os quadros mais lentos melhoram 27% (1% baixo de 61,2 contra 48,2). O p99 cai de 19,8 ms para 15,6 ms.
- **Com 40 personagens o V3 é 17% mais rápido** (65,3 contra 55,6 FPS) e o 1% baixo melhora 23%.
  - **O V3 fica acima de 60 FPS com 40 personagens no vídeo integrado.** O atual não chega.
- **O V3 desenha cerca de 29% mais triângulos e ainda assim é mais rápido.**
  - O gargalo nesta máquina não é a quantidade de triângulos.
  - Provavelmente pesam mais o número de malhas animadas e de chamadas de desenho por personagem: o V3 tem 8 malhas, o atual 10. **Isto é hipótese, não medição.**
- **Memória de vídeo:** o V3 usa cerca de 48 MB a menos que o atual.

## Limitações

- A coluna "memória total" não vale. O monitor de memória do motor não funciona no executável de versão final. Usar só a memória de vídeo.
- Não foi possível confirmar se o notebook estava na tomada nem em qual modo de energia. As três rodadas foram feitas nas mesmas condições.
- O cenário é sintético: um grupo de personagens, chão e sol com sombras. Uma cidade com cenário vai custar mais.

## Recomendação

- Os dados já sustentam que o V3 **não piora** o desempenho e tende a melhorar com multidões.
- Metas definitivas de FPS e polígonos devem esperar um teste com cenário real (cidade). Esse teste pode entrar no benchmark 1.1, junto com a correção da memória, se for autorizado.
