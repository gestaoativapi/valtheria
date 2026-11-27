# 09 — Desempenho, Qualidade e Otimização

**Versão examinada:** nativo 0.17.0 (`29d9507`) · **Data:** 14/11/2026
**Ambiente da medição:** contêiner sem placa de vídeo (renderização por software, OpenGL 3 via xvfb), 1280×720, numa **cópia temporária** do cliente. A única mudança na cópia foi uma linha que imprime os monitores do Godot (`Performance`). O repositório não foi alterado.
Marcas: **[F]** fato comprovado · **[P]** proposta · **[C]** confirmar.

> **Limite desta medição:** o **FPS não é confiável** sem placa de vídeo, por isso não é apresentado. Os números abaixo (chamadas de desenho, triângulos, objetos, memória) dependem da cena, não da placa, e servem de linha de base para comparação. O FPS real depende do `registro.txt` e de uma medição no notebook (D18).

---

## 1. Linha de base medida [F]

| Cena (`--at`) | Qualidade | Chamadas de desenho | Triângulos | Objetos desenhados | Nós | Memória estática | Vídeo usado | Texturas |
|---|---|---|---|---|---|---|---|---|
| Capital (1500, 1985) | 0 (sem sombra) | 774 | 317 mil | 3.918 | 3.375 | 153 MB | 289 MB | 251 MB |
| Vila Aurora (1500, 2550) | 0 | 924 | 352 mil | 4.065 | 3.375 | 153 MB | 289 MB | 251 MB |
| Campo aberto (1250, 2250) | 0 | 760 | 323 mil | 3.914 | 3.444 | 155 MB | 292 MB | 252 MB |
| Capital | 1 (com sombra) | 897 | **705 mil** | 4.041 | 3.282 | 154 MB | 289 MB | 251 MB |

Captura da cena da capital: `imagens/Medicao_Capital.png`.

## 2. Gargalos identificados [F → análise]

| # | Achado | Evidência | Impacto |
|---|---|---|---|
| G1 | **Texturas: 251 MB** já na entrada | Monitor `RENDER_TEXTURE_MEM_USED` | Alto para placa integrada e celular (alvo ≤ 128 MB) |
| G2 | **760–924 chamadas de desenho** em qualquer ponto | Monitor | Alto para celular (alvo ≤ 300) e médio para PC fraco (≤ 600) |
| G3 | Ligar a sombra **dobra os triângulos** (317 mil → 705 mil): a sombra desenha a cena de novo | Q0 × Q1 | Médio |
| G4 | O número de nós e de objetos quase não muda entre capital e campo: **o mundo inteiro fica carregado**, sem carregar por região | Nós ≈ 3,3–3,4 mil em todos | Médio |
| G5 | `assets/chars` tem 38 MB de texturas webp 2K (pele, cabelo e roupa por variação de corpo) | Tamanho em disco | Causa provável de G1 **[C]** |
| G6 | Partículas todas de CPU, sem limite global | `08`, seção 4 | Baixo hoje; cresce com efeitos |
| G7 | Rede: posição a cada 0,2 s por broadcast, `game_save` a cada 20 s, chat por consulta periódica | `social.gd`, `main.gd` | Baixo; sem reconexão (`05`, 5) |

Técnicas que **já existem** [F]:
- MultiMesh por material nas cidades (`cidade.gd`);
- instâncias de vegetação;
- distância de sombra por nível de qualidade;
- 5 níveis de qualidade (`main.gd::_set_quality`) com resolução reduzida, FSR e MSAA.

Técnicas **ausentes** [F]:
- LOD de malha nos personagens e NPCs;
- oclusão (`OccluderInstance3D`);
- carregamento por região;
- compressão de textura para celular.

## 3. Plano de otimização priorizado [P]

| Prioridade | Ação | Critério de melhoria (medido antes e depois na mesma cena) |
|---|---|---|
| 1 | Medir no notebook real (FPS, tempo de quadro) com o `registro.txt` | Linha de base com placa de vídeo |
| 2 | Reduzir texturas de personagem: 1K + compressão VRAM (importação `vram_compressed`) | Texturas ≤ 140 MB na capital |
| 3 | Juntar materiais iguais e ampliar MultiMesh nas vilas e nos NPCs distantes (impostor ou NPC simplificado além de 40 m) | Chamadas de desenho −30% |
| 4 | Distância de desenho por nível de qualidade para NPCs, adereços e vegetação | Objetos −25% no nível 0 |
| 5 | Oclusão nas muralhas e prédios grandes das 5 cidades grandes | Triângulos −20% dentro das cidades |
| 6 | Carregamento por região (células de 500 m) | Nós −40% no campo |
| 7 | Limite global de partículas | ≤ 2.000 no desktop |
| 8 | Reconexão do WebSocket e fila de repetição (com E1.5) | Volta sozinho após queda |

**Regra:** nenhuma otimização é declarada pronta sem a tabela da seção 1 refeita, mostrando a melhoria.

## 4. Testes de regressão [P]
Hoje **não existem**. Proposta mínima:

1. **Sintaxe:** `godot --headless --check-only` em todos os scripts.
2. **Entrada:** `--play` em 6 pontos fixos (capital, Aurora, Sylvar, Umbraval, Abissália, campo). Falha se houver `SCRIPT ERROR`.
3. **Capturas de referência:** 6 imagens comparadas com as da versão anterior; a diferença é revisada a olho.
4. **Monitores:** a tabela da seção 1 gerada em cada versão e guardada em `docs/medicoes/`.
5. **Servidor:** script SQL que chama as funções com valores válidos e falsos (`05`, E1) e confere as recusas.
6. Tudo rodando no GitHub Actions antes de publicar a release.

## 5. Problemas conhecidos

| ID | Problema | Situação |
|---|---|---|
| K1 | Vulkan e D3D12 instáveis no notebook de teste (o jogo usa OpenGL) | Aguardando `registro.txt` (D18) |
| K2 | FPS real não medido | Aguardando D18 |
| K3 | WebSocket sem reconexão | Comprovado |
| K4 | Escala de lobo e raptor a conferir | `04`, 5.4 |
| K5 | Cerca de 100 NPCs na capital sem medição de custo de CPU | A medir com placa de vídeo |
