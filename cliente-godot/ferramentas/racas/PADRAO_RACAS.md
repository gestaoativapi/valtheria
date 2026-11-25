# Padrão Valtheria de corpo próprio por raça (24/11/2026)

Todo corpo de raça (anão, orc, gigante de gelo, elfo branco, elfo negro, humano) segue o mesmo caminho,
sem serviço pago e sem mexer no esqueleto oficial de 65 ossos nem nas 28 animações.

## 1. Conceito (Gemini, conta do Robson)
Uma conversa só para todas as raças, para manter o mesmo estilo. Primeiro pedido (prancha):

> Create an image. Original character design for a fantasy MMORPG (no existing IP). {DESCRIÇÃO}.
> Character turnaround sheet with exactly three full-body views side by side at the same scale: FRONT view,
> LEFT SIDE view facing right, BACK view. Strict A-pose: arms straight and 40 degrees away from the body,
> palms facing the thighs, fingers relaxed; legs straight, feet shoulder-width apart flat on the ground.
> Neutral expression, mouth closed. Semi-realistic stylized 3D game art, realistic proportions, PBR materials,
> soft even studio lighting, no cast shadows. Plain light grey background, nothing else in the image,
> no weapons, no shield, no cape covering the body, no text, no labels. Wide 16:9.

Raças seguintes: "new character, exact same three-view turnaround sheet format, strict A-pose, lighting,
grey background and rules as the first sheet. {DESCRIÇÃO}. No cape. Wide 16:9, no text."

Depois de cada prancha: "Now only the FRONT view of this same character, identical outfit, strict A-pose,
full body from head to feet centered, portrait 3:4, plain white background, no text."

Regras da descrição: altura em metros, pele/cabelo/olhos, roupa em cores reais (metal, couro, tecido;
cor forte só em detalhe), sem capa e sem arma (capa e arma estragam o 3D e a pele).

Arquivos: `fontes/<raca>_<m|f>_prancha.jpg` e `fontes/<raca>_<m|f>_frente.jpg`.

## 2. Malha 3D (Hunyuan3D-2.1, Hugging Face, grátis)
Envia a FRENTE em "Image Prompt" → **Gen Shape** (sem textura) → Export: Target Face Number 40000 →
Transform → Download (.glb). Salvar como `fontes/<raca>_<g>_malha.glb`.
Cota grátis: sem login acaba em ~4 malhas por dia; logado no huggingface.co a cota é maior.
Licença do Hunyuan3D: não vale na UE, Reino Unido e Coreia do Sul.

## 3. Um comando faz o resto
    python3 nova_raca.py <raca>_<g> <altura_m>     # ex.: gigante_m 2.6
- reduz para 40 mil triângulos e normaliza (frente +z, esquerda +x);
- `juntas.py`: articulações por gabarito de proporção + medida da malha (mãos, pernas, tronco); gera
  `saida/<chave>_juntas.png` para conferir; ajuste fino opcional com `--ajuste=arquivo.json`
  (`{"gab": {...}, "fixo": {"arm.lower": [x, y]}, "extra": [...]}`);
- `assar_textura.py`: UV automático (xatlas) e pintura texel a texel misturando frente, costas e lados
  da prancha pela normal, com teste de visibilidade (sem emendas no rosto); sola em couro escuro;
- `pele_automatica.mjs`: pesos por segmento de osso, suavizados; grava `assets/chars/body_<chave>.glb`.
Imprime o `hip` (altura da pelve / 0,95 m) para a tabela `OWN` do `character.gd`.

## 4. No jogo
- `OWN` em `scripts/character.gd`: altura e hip por corpo. Raças em `CORPO_PROPRIO_RACAS` usam o corpo
  próprio quando o arquivo existe; `corpos_proprios = false` volta ao V3 para comparar.
- Corpo próprio não recebe FormaRaca (deformação de roupa V3) nem os enfeites V3 (golem de gelo etc.).
- Corrida: `CORRIDA_RETA` devolve graus ao tronco na corrida para corpos largos (orc, anão, gigante).
- Orc leva o machado baixo (a ombreira de chifres atravessava o cabo no ombro).
