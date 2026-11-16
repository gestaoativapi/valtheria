# VALTHERIA — Padrão Técnico dos Assets (versão inicial, sujeita a validação)

Este padrão separa três coisas que não podem ser confundidas:

- **[M] Medido:** número lido de arquivo ou cena existente. É fato.
- **[I] Meta inicial de produção:** faixa para orientar quem modela. **Não é limite.**
- **[L] Limite técnico:** só será fixado depois do benchmark no notebook (D42/D44), com FPS real. Hoje está **em aberto**.

Nenhum limite de desempenho é fixado neste documento. Renderização por software não serve de referência de FPS.

---

## 1. Triângulos por categoria

| Categoria | [M] Hoje no jogo | [I] Meta inicial do protótipo | [L] Limite |
|---|---|---|---|
| Personagem jogável completo (corpo, roupa, cabelo, olhos) | 24–34 mil, 4–6 materiais | 25–35 mil em LOD0 (a V2 vestida mediu 30,9 mil) | Em aberto |
| Corpo nu (base de produção) | 14–15 mil (Quaternius); 26,8 mil (V2) | Igual à V2 | Em aberto |
| Cabelo | 0,4–3,6 mil | 1,5–5 mil | Em aberto |
| Arma de uma mão | 0,7–1,1 mil | 1,5–4 mil | Em aberto |
| Arma de duas mãos / escudo | 0,9–1,9 mil | 2–5 mil | Em aberto |
| Peça de armadura (cada uma de 4) | Não existe | 2–6 mil | Em aberto |
| Criatura comum | 1,6–4,9 mil | 5–12 mil | Em aberto |
| Criatura grande / chefe regional | Humanoide de 15–34 mil | 15–40 mil | Em aberto |
| Guardião | Não existe | 30–60 mil (um por vez na tela) | Em aberto |
| Casa de vila | 3–8 mil | 4–12 mil | Em aberto |
| Prédio grande (igreja, palácio, castelo) | Caixas geradas por código | 15–40 mil, em módulos | Em aberto |
| Árvore | 1–9 mil | 3–10 mil + LOD | Em aberto |
| Rocha | 30–300 | 300–2 mil | Em aberto |

## 2. Texturas

| Categoria | [M] Hoje | [I] Meta inicial |
|---|---|---|
| Personagem (corpo) | 1024² (cor, normal, rugosidade) | 1024² cor + 1024² normal; 2048² só para rosto em telas de seleção (opcional) |
| Roupa / armadura | 512²–1024² | 1024² por conjunto; atlas quando houver várias peças pequenas |
| Cabelo | 512² | 512²–1024² com alfa recortado (sem transparência suave) |
| Olhos | 256² | 256² por cor |
| Arma | Sem textura (cor por material) | 512² cor + normal; 1 material |
| Criatura comum | Embutida, sem textura | 1024² |
| Prédio | Cor por material | Texturas de repetição 1024² compartilhadas (pedra, madeira, telha, reboco) + atlas de detalhes |
| Terreno | 3 texturas de repetição | 6–8 camadas de repetição (com normal) |

**Formato no repositório:** PNG ou WebP sem perda para a fonte; o Godot gera a versão comprimida na importação.
**Compressão no jogo:** VRAM comprimida (S3TC/BPTC) no desktop. Para celular, ASTC (ETC2 como reserva). O suporte do ambiente de medição foi conferido (S3TC, BPTC, RGTC, ASTC aceitos); **falta conferir no notebook e num celular**.
**Mapas normais:** importar com o perfil de normal (canal verde no padrão OpenGL do Godot).

## 3. Materiais

| Regra | Motivo |
|---|---|
| Personagem: 1 material por peça (corpo, roupa, cabelo, olhos) | Cada material é uma chamada de desenho a mais por personagem |
| Arma: 1 material | Hoje as armas têm 3–5 materiais sem textura: 3–5 chamadas por arma |
| Prédio: materiais compartilhados entre prédios da mesma cidade | Permite agrupar e instanciar |
| Metal com `metallic` e rugosidade da tabela da paleta oficial | Evita aparência de plástico |
| Sem contorno preto, sem cel-shading | Direção aprovada: fantasia semi-realista estilizada |
| Emissão só em magia, encantamento, tocha, janela e runa | Evita excesso de brilho |

## 4. Escala, pivô e orientação

| Item | Padrão |
|---|---|
| Unidade | 1 unidade = 1 metro |
| Referência humana | Humano masculino 1,80 m; feminino 1,68 m (corpos V2) |
| Pivô de personagem e criatura | No chão, entre os pés |
| Pivô de arma | Na ponta do cabo, eixo do cabo em +Y (compatível com `GRIP` de `character.gd`) |
| Pivô de prédio | No chão, centro da base; porta voltada para −Z |
| Frente do personagem | −Z no Godot (+Y no Blender antes da conversão); exportação glTF com Y para cima |
| Escala no arquivo | Escala aplicada (1,1,1), rotação aplicada |

## 5. Nomenclatura

Formato: `categoria_nome_variante[_lodN].glb`, em minúsculas, sem acento, com `_`.

| Prefixo | Uso | Exemplo |
|---|---|---|
| `pc_` | Corpo de personagem jogável | `pc_humano_m.glb` |
| `rp_` | Roupa | `rp_aldeao_tunica_m.glb` |
| `ar_` | Peça de armadura | `ar_ferro_peito_m.glb` |
| `ca_` | Cabelo | `ca_trancado_longo.glb` |
| `wp_` | Arma | `wp_espada_longa_d.glb` (grau no fim) |
| `cr_` | Criatura | `cr_javali.glb` |
| `ch_` | Chefe ou guardião | `ch_guardiao_brasa.glb` |
| `ed_` | Edificação ou módulo | `ed_muralha_reta_4m.glb` |
| `ad_` | Adereço | `ad_barril_carvalho.glb` |
| `ve_` | Vegetação | `ve_carvalho_grande_lod1.glb` |
| `tx_` | Textura de repetição | `tx_pedra_calcaria_cor.png` |

Os arquivos existentes **não são renomeados**. O padrão vale só para os novos.

## 6. LOD

| Categoria | Níveis | Regra inicial |
|---|---|---|
| Personagem | LOD0 completo; LOD1 cerca de 50%; LOD2 cerca de 20% | Gerado no Godot (importador gera LOD automático) e conferido; manual só se o automático deformar |
| Criatura | Igual ao personagem | — |
| Prédio | LOD0 e LOD1; impostor plano para os mais distantes, se necessário | — |
| Vegetação | LOD0, LOD1 e impostor | Árvores são o maior número de objetos |

A distância de troca de LOD entra nos 5 níveis gráficos existentes (`main.gd → _set_quality`).

## 7. Colisões

| Categoria | Padrão |
|---|---|
| Personagem e criatura | Cápsula (a lógica de combate já usa distância e raio) |
| Prédio | Caixas simples por parede/telhado, nunca a malha visual |
| Adereço | Caixa ou cilindro; adereço pequeno sem colisão |
| Terreno | Altura do `height.bin` (já usado) |

## 8. Rig e skinning

| Regra | Detalhe |
|---|---|
| Esqueleto de personagem | Sempre os **65 ossos do jogo**, com as mesmas rotações de repouso (verificado na V2: diferença de 0°) |
| Animações | As 28 oficiais (`anims_a`, `anims_b`) **não são alteradas**. Animação nova entra em arquivo novo (`anims_c.glb` e seguintes) |
| Influências | Até 4 ossos por vértice (limite do glTF/Godot) |
| Roupas e armaduras | Pesos copiados do corpo (transferência) e conferidos nas 28 animações com a métrica de deformação da V2 |
| Ossos ausentes no jogo (ex.: `breast_l`) | Peso vai para o osso pai (método validado na V2) |
| Criaturas | Esqueleto próprio por família; animações próprias por família |

## 9. Exportação

| Item | Padrão |
|---|---|
| Formato | glTF binário (`.glb`), texturas embutidas ou ao lado |
| Animação no arquivo do modelo | Não (animações em arquivos separados, como hoje) |
| Arquivo-fonte | `.blend` guardado fora do pacote do jogo (pasta `fontes/`, ver §10) |
| Licença | Registrada no `CREDITOS.md` antes de entrar em qualquer branch |

## 10. Organização de diretórios (só para arquivos novos)

```
cliente-godot/
  assets/            (existente, não muda)
  assets_v3/         (novo, só em branch de teste)
    personagens/  equipamentos/  criaturas/  ambientes/  texturas/  materiais/
  ferramentas/v3/    (scripts de geração, medição e conversão)
  testes/prototipos/ (cenas de comparação e benchmark)
fontes/              (fora do pacote exportado: .blend, PSD/Krita, referências)
  personagens/  equipamentos/  criaturas/  ambientes/
docs/producao_visual/ (estes documentos)
```

`assets_v3/` e `fontes/` ficam na branch de protótipo até aprovação. O `export_presets.cfg` não inclui `fontes/`.
