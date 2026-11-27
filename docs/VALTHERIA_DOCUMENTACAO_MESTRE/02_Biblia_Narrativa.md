# VALTHERIA — A ÁRVORE DOS MIL MUNDOS
## Bíblia Narrativa Oficial · versão 1.0 (proposta para aprovação)

**Data:** 13/11/2026
**Base:** fusão de "A Era do Eclipse" (`quests.js`) com "O Pacto do Véu" (`cliente-godot/scripts/npcs.gd`), conforme as Diretrizes do Projeto e a Bíblia Narrativa enviadas pelo Robson.

### Como ler

Cada informação traz uma marca de origem:

| Marca | Significado |
|---|---|
| **[E] Existente** | Já está no projeto (o arquivo é citado). Não foi alterado, só organizado. |
| **[A] Ajustado** | Existe no projeto, mas precisou de um ajuste pequeno para as duas narrativas virarem uma só. O ajuste está explicado. |
| **[P] Proposta** | Criação nova para preencher uma lacuna. **Só vira cânone depois da aprovação do Robson.** |
| **[S] Segredo de roteiro** | Proposta que o jogador **não** deve saber no começo. Revelada aos poucos (ver capítulo 10). |

Nada aqui altera arquivos do jogo. As mudanças de texto necessárias estão listadas no capítulo 13 para aprovação.

---

## 1. Identidade narrativa

**Valtheria** é o mundo que fica no **tronco** da Árvore dos Mil Mundos, onde todos os outros mundos se tocam. **[P]**

A história combina duas ideias:

- **O Pacto do Véu:** o que mantém os mundos separados, protegidos e em ordem. É a promessa, o vínculo, a lei. **[E]** (`npcs.gd`)
- **A Era do Eclipse:** a ruptura. O tempo em que a promessa foi quebrada e a realidade começou a rachar. **[E]** (`quests.js`)

As duas não são histórias diferentes. **O Pacto criou o equilíbrio, e o Eclipse é a consequência de ele ter sido traído.** O jogador vive na Era do Eclipse, e a missão dele é descobrir por que o Pacto falhou e se ainda pode ser renovado. **[A]**

**Tema central:** povos que guerrearam por séculos precisam confiar uns nos outros de novo para salvar um mundo que só existe enquanto estão unidos. **[P]**

**Tom:** fantasia épica, mistério antigo, luz e sombra em equilíbrio. Nunca o bem contra o mal puro: Nyx, a lua escura, não é vilã. **[P]**

---

## 2. A Árvore dos Mil Mundos

### 2.1 O que já existe

- Nome do jogo, "A Árvore dos Mil Mundos". **[E]** (`data.js`, `title.js`)
- Tela de entrada da versão web: uma árvore de tronco torcido sobre uma ilha flutuante, com um coração de luz com runas e **pequenos mundos em órbita**, "cada um um pequeno mundo com anel". **[E]** (`title.js`)
- Sylvar, a cidade élfica, construída na Árvore-Mãe. **[E]** (`especial.gd`)

### 2.2 Origem e natureza — **[P]**

1. **Antes de tudo havia o Vazio:** um nada sem forma, que sussurra. **[E]** O "Vazio" já existe no jogo: Anomalias do Vazio (`dialog.js`), Vespa do Vazio, Arco do Vazio, Asas do Vazio, classes Arauto do Vazio e Caçador do Vazio. A lenda propõe que é o nada de onde a Árvore brotou.
2. **Uma semente de luz caiu no Vazio** e criou raiz. Ninguém sabe de onde ela veio; isso é mistério permanente do jogo, de propósito.
3. **A Árvore cresceu para os dois lados:**
   - **Para baixo, as raízes** guardam o que já foi: a memória e o descanso dos mortos.
   - **Para cima, a copa** sustenta o que ainda vai ser: a vida, o crescimento.
4. **Cada galho deu um fruto, e cada fruto é um mundo.** Os povos de Valtheria chamam esses mundos distantes de **estrelas**: o que se vê no céu à noite são as copas de outros mundos, vistas através do Véu.
5. **Valtheria é o mundo do tronco**, o único ligado a todos os galhos. Por isso aqui aparecem coisas de outros mundos (ver Era Neon, capítulo 9).

### 2.3 As duas luas — **[E]** e **[A]**

- **[E]** Lúmen, a lua de prata, dá vida às florestas. Nyx, a lua de ônix, guarda os sonhos dos mortos (`quests.js`).
- **[A]** As luas passam a ser **os dois olhos da Árvore**:
  - Lúmen olha para a copa (a vida).
  - Nyx olha para as raízes (a memória e a morte).
  - Enquanto as duas giram em equilíbrio, o fluxo entre vida e morte está em ordem.

### 2.4 O que protege a Árvore e o que a ameaça — **[P]**

- **Protegem:**
  - o **Véu** (capítulo 4);
  - os **guardiões** dos fragmentos, antes de serem corrompidos (capítulo 6);
  - os elfos de Sylvar, que cuidam da raiz que aflora no continente.
- **Ameaçam:**
  - o **Vazio**, que tenta voltar a ocupar o espaço da Árvore;
  - quem tenta usar o poder das luas para si (Malachar);
  - as **Fendas**, rasgos no Véu por onde outros mundos e o próprio Vazio escapam.

### 2.5 O que acontece quando a Árvore perde o equilíbrio — **[P]**

| Sinal | Já aparece no jogo? |
|---|---|
| Estrelas somem do céu (mundos inteiros engolidos pelo Vazio) | **[E]** Seren do Alto Céu: "Contei as estrelas ontem. Faltavam três." (`npcs.gd`) |
| Uma raiz escura corre por baixo da floresta | **[E]** Lyria Canto-de-Orvalho (`npcs.gd`) |
| Plantas nascem cinzentas perto de lugares estranhos | **[E]** Ancião Bramble, sobre o Monólito Sussurrante (`npcs.gd`) |
| Criaturas enlouquecem durante o eclipse | **[E]** `quests.js` |
| Coisas de outros mundos e tempos aparecem em Valtheria | **[E]** Era Neon, "fenda no tempo" (`neon.js`) |
| Os mortos não descansam (criptas, esqueletos, Rei Lich) | **[E]** Ruínas e lendas (`quests.js`, ruínas do mapa) |

---

## 3. O Eclipse

### 3.1 O que já existe — **[E]** (`quests.js`)

- Há mil anos, **Malachar**, um arquimago humano que buscava a imortalidade, tentou aprisionar o poder de Nyx.
- A **Coroa Celeste**, que mantinha as luas em equilíbrio, se partiu em **seis fragmentos**. Os cronistas chamam essa noite de **Grande Silêncio**.
- Desde então, a cada século, Nyx cobre Lúmen num eclipse cada vez mais longo, e as criaturas enlouquecem.
- O **Eclipse final** se aproxima.

### 3.2 O que provocou o Eclipse — **[A]**

- **[A]** Malachar não queria só imortalidade. Ele queria **entrar em Nyx**, o olho que guarda a memória dos mortos, para nunca ser esquecido.
- **[A]** Para isso ele precisava abrir o Véu. Ele **traiu o Pacto** que o seu próprio povo tinha jurado.
- **[S]** **Malachar conseguiu, em parte.** Ele não morreu no Grande Silêncio: entrou em Nyx e ficou preso lá. **O Eclipse é Malachar puxando Nyx para cima de Lúmen**, tentando apagar a vida para que só reste a memória, a dele. Essa é a grande revelação do Ato VI (capítulo 10).

### 3.3 Consequências — **[A]**

| Consequência | Origem |
|---|---|
| A Coroa se partiu em seis fragmentos espalhados pelo continente | **[E]** |
| Cada fragmento foi engolido por uma criatura, que cresceu além da medida | **[E]** |
| O Véu enfraqueceu; surgiram as **Fendas** (Fenda Demoníaca, Fenda Astral) | **[A]** Os lugares existem no mapa; a ligação com o Véu é nova |
| Os povos se acusaram uns aos outros e entraram em séculos de guerra | **[A]** `quests.js` fala em séculos de guerra; a causa é nova |
| Os **elfos negros** foram culpados pelo rasgo no Véu e exilados para o subterrâneo | **[A]** Une Nyxara ("fomos acusados de rasgar o Véu. Não fomos nós") à descrição da raça ("exilados das cidades subterrâneas") |
| A corte de Malachar foi amaldiçoada e virou a **nobreza da Noite Eterna** (Nocturnos) | **[P]** Encaixa a raça Nocturnos, a cidade Castelo Noctis e o Castelo do Sangue Eterno |
| O **oitavo nome** do Pacto foi apagado | **[E]** Velho Tobias, em `npcs.gd`; o motivo está em 4.4 |

### 3.4 Forças que cresceram durante o Eclipse — **[P]**

- **Os Seis Guardiões Corrompidos** **[E]**, que cresceram com os fragmentos.
- **A Corte Carmesim:** os Nocturnos que ainda servem Malachar, liderados pelo **Conde Carmesim** **[E]** (chefe de lenda do Castelo do Sangue Eterno). Eles abrem Fendas para alimentar Nyx. **[S]** São eles que estão rasgando o Véu agora, e é isso que Nyxara sabe.
- **Os Cavaleiros Caídos** **[E]**, "antigos heróis de Malachar" (`quests.js`): os soldados que marcharam com ele no Grande Silêncio e não morrem.
- **O Vazio**, que entra pelas Fendas: Anomalias, Vespas do Vazio, o Monólito Sussurrante ("O Vazio sussurra seu nome", `dialog.js`). **[E]** e **[A]**

---

## 4. O Véu e o Pacto

### 4.1 O que já existe — **[E]** (`npcs.gd`)

- Sete povos juraram o **Pacto do Véu**. O Véu separa o nosso mundo das sombras.
- O Véu está rachando, e as sombras voltam pelas fendas.
- As forjas de Pedra Alta "selaram o Véu com aço e runas".
- O Pacto teria tido um **oitavo nome, apagado de propósito**.
- A primeira palavra do Pacto está guardada num **selo partido nas Ruínas de Vel'Anor**.

### 4.2 O que é o Véu — **[A]**

O Véu é **a casca da Árvore**. Ele separa:

- Valtheria dos outros mil mundos;
- os vivos do Vazio;
- e a vida (Lúmen) da memória dos mortos (Nyx), para que uma não invada a outra.

Rachaduras no Véu são as **Fendas**.

### 4.3 A origem do Pacto e a Coroa Celeste — **[A]**

Esta é a peça que une as duas histórias:

- **[A]** Na **Era do Pacto**, os povos de Valtheria perceberam que o Véu enfraquecia sempre que eles guerreavam entre si. **O Véu se sustenta pela união dos povos que vivem no tronco.**
- **[A]** Os povos juraram o **Pacto do Véu** nas raízes da Árvore, onde hoje estão as **Ruínas de Vel'Anor**. **[E]** As Ruínas de Vel'Anor existem no mapa.
- **[A]** O juramento ganhou corpo na **Coroa Celeste**:
  - **[E]** forjada pelos primeiros anões e abençoada pelos elfos (`quests.js`);
  - **[A]** feita de um cristal da própria Árvore, gravado com as runas do juramento ("aço e runas", das falas de Thrain);
  - **[A]** cada povo que jurou deixou seu nome gravado num ponto da Coroa;
  - **[A]** a Coroa foi posta entre as duas luas e mantinha os olhos da Árvore em equilíbrio.
- **[A]** **A Coroa Celeste é o Pacto do Véu.** Enquanto ela estava inteira, o Véu se mantinha. Quando Malachar a partiu, o Pacto se quebrou junto, e começou a Era do Eclipse.

### 4.4 Quem jurou o Pacto

**Os sete povos — [A]**

São as raças jogáveis decididas pelo Robson:

1. humanos;
2. elfos;
3. elfos negros;
4. orcs;
5. anões;
6. homens-fera;
7. gigantes.

**O oitavo nome — [S]**

O oitavo povo foi o dos **Antigos Dragões**. Eles levaram a Coroa até o céu, entre as luas, e eram seus guardiões no alto.

Quando a Coroa se partiu, os sobreviventes culparam os dragões por não terem protegido a Coroa e **apagaram o nome deles** do Pacto. O último dos Antigos, ferido e amargo, é o **Dragão Celeste** que dorme sobre as **Ruínas de Aeternum**. **[E]** Chefe e lugar existem; Ruínas de Aeternum é ponto de caça de Bastião Celeste.

- **Ligação com as Dragonitas:** "filhos do sangue dos dragões antigos" (`data.js`) são os descendentes desse povo apagado. Isso dá à raça Dragonita (em teste) uma história forte. Se a raça sair do jogo, a história continua valendo pelos NPCs do Pico do Dragão.
- **Fala que já existe:** Kaelthar, "O Dragão Celeste não dorme mais. Quando ele voa baixo, o Véu treme", ganha sentido.

**Os outros povos — [P]**

- **Halflings, Sylphs:** chegaram ao continente depois do Pacto. Vivem nas cidades dos sete povos (Vale Dourado, Bastião Celeste).
- **Nocturnos:** nasceram da maldição do Grande Silêncio.

### 4.5 As regras do Pacto e o que acontece quando são violadas — **[A]**

| Regra | Efeito no mundo | Efeito no jogo (já existe) |
|---|---|---|
| Nenhum povo ergue arma contra outro dentro das cidades do Pacto | Cada violação abre uma pequena rachadura no Véu | **[E]** "Lei da Trégua": zona segura sem PvP (`quests.js`, zona segura do cliente) |
| Quem derrama sangue inocente carrega a marca do Véu | O Véu "reconhece" o traidor | **[E]** Karma: nome vermelho, guardas não protegem, risco de perder itens |
| As cidades do Pacto são neutras para todos os povos | Por isso elas recebem gente de todas as raças | **[E]** Visitantes de outras raças nas cidades (`npcs.gd`) |
| Duelos de honra são permitidos fora das muralhas e na arena | Não ferem o Véu, porque são combate aceito pelos dois lados | **[E]** PvP fora da cidade; **[A]** Arena dos Heróis |

O karma deixa de ser só uma regra de jogo e passa a ser **o próprio Pacto reagindo**. **[A]**

### 4.6 Os mistérios que a progressão revela — **[P]**

1. Por que o Véu está rachando agora, se a Coroa se partiu há mil anos? (A Corte Carmesim está abrindo Fendas.)
2. Quem foi o oitavo nome? (Os Antigos Dragões.)
3. Onde está Malachar? (Dentro de Nyx; ele é o Eclipse.)
4. A Coroa tinha um **sétimo pedaço**, o **Coração da Coroa**, que nunca foi encontrado. **[S]** Malachar o levou para dentro de Nyx. É o gancho para depois do Ato VI. **[E]** O item "Fragmento Estelar" já existe nos dados.
5. Para onde foram as três estrelas que sumiram? (Três mundos engolidos pelo Vazio, um deles de onde vieram os demônios.)

---

## 5. Cronologia oficial

| Era | Acontecimento | Origem |
|---|---|---|
| **Antes do tempo** | O Vazio. A semente cai e a Árvore cresce. Os mil mundos brotam nos galhos. | [P] |
| **Era da Raiz** | Os primeiros povos despertam no tronco: Valtheria. Lúmen e Nyx abrem os olhos. | [P] |
| **Era do Pacto** | Guerras enfraquecem o Véu. Oito povos juram o Pacto nas Ruínas de Vel'Anor. Anões forjam e elfos abençoam a Coroa Celeste. Os Antigos Dragões a levam ao céu. Fundação das **seis cidades do Pacto**: Aurora, Vale Dourado, Pedra Alta, Sylvar, Cidadela Rubra, Bastião Celeste. | [A] As seis cidades vêm de `quests.js` |
| **Há mil anos — o Grande Silêncio** | Malachar trai o Pacto e tenta entrar em Nyx. A Coroa se parte em seis fragmentos, e seis criaturas os engolem. A corte de Malachar vira a nobreza da Noite Eterna. Os Cavaleiros Caídos não morrem. | [E] e [A] |
| **Logo depois** | Os povos se acusam. Elfos negros são exilados ao subterrâneo (Umbraval). O nome dos dragões é apagado. | [A] |
| **Séculos seguintes — Era do Eclipse** | A cada século, um eclipse mais longo. Séculos de guerra entre os povos. Surgem novas cidades fora do Pacto (Clã das Presas, Umbraval, Pico do Dragão, Castelo Noctis, Fortaleza Glacial). | [E] e [A] |
| **Cerca de 60 anos atrás** | A última Fenda conhecida se fecha; "o céu ficou sem estrelas por uma semana". | [E] Velho Tobias (`npcs.gd`) |
| **Fundação de Valtheria Real** | Capital fundada no centro do continente como sede do **Conselho do Pacto**, onde as raças negociam. Primeiro rei: dinastia de Aldemar. | [P] Cidade existe; "Rei Aldemar" é figurante em `interiores.gd` |
| **Hoje (início do jogo)** | O Eclipse final se aproxima. Fendas voltam a se abrir. Humanos, elfos, elfos negros, orcs e anões juram **trégua na Vila Aurora** (o **Segundo Juramento**). O **Arauto do Eclipse** convoca aventureiros de todas as raças. | [E] `quests.js`; [A] o nome "Segundo Juramento" |
| **Durante o jogo** | Homens-fera e gigantes aderem à trégua ao longo dos Atos (capítulo 10). | [P] |

---

## 6. Os seis fragmentos e seus guardiões

**Regra comum:**
- **[E]** Cada fragmento foi engolido por uma criatura que cresceu além da medida (`quests.js`).
- **[A]** Cada fragmento guarda um **dos poderes que a Coroa equilibrava**.
- **[A]** O guardião não é mau por natureza: foi corrompido pelo poder grande demais. Vencer não é só matar; é **libertar**.

**Chefes, lugares, níveis e missões:** **[E]**, conforme `world.json`, mapa e `quests.js`.

### Fragmento 1 — **Fragmento da Aurora** (vida, renascer)

| Campo | Conteúdo |
|---|---|
| Guardião | **Rei Javali** **[E]** |
| Região | Campos do Amanhecer e Bosque dos Javalis, Vila Aurora (nível 1–19) **[E]** |
| Origem | **[P]** O primeiro brilho de Lúmen preso na Coroa. Caiu nos campos e um javali comum o engoliu; virou um colosso que não envelhece. |
| Relação | **[P]** Árvore (a força de crescer). Os campos de Aurora nunca secam; por isso a vila nasceu ali. |
| Visual | **[P]** Javali enorme, presas de marfim rachado, uma luz dourada pulsando entre as costelas; o capim floresce onde ele pisa. |
| Desafio | **[E]** Missão m03, "O Rei dos Javalis", de preferência em grupo. **[P]** Antes da luta, Irmã Elowen avisa que o fragmento "não quer ser tirado; quer ser devolvido". |
| Recompensa | **[E]** Experiência, aurum, pergaminhos e poções (m03). **[P]** O fragmento revela a primeira visão: a Coroa inteira entre duas luas. |
| Consequência | **[P]** Os campos ficam comuns (o capim deixa de crescer à noite), e o jogador entende que cada fragmento sustentava algo. |

### Fragmento 2 — **Fragmento do Tecer** (laços, o que une)

| Campo | Conteúdo |
|---|---|
| Guardião | **Rainha Aracnídea** **[E]** |
| Região | Ninho das Aranhas e Planície dos Bandidos, Vale Dourado (nível 20–39) **[E]**. **[A]** O ninho fica sob o **Forte Dourado**, o castelo do Vale Dourado; resolve a diferença "Forte Dourado / Vale Dourado". |
| Origem | **[P]** O fio do juramento que amarrava os nomes dos povos na Coroa. A rainha o engoliu e passou a tecer teias que **unem tudo o que tocam**. |
| Relação | **[A]** Pacto do Véu (é o próprio laço do juramento). |
| Visual | **[P]** Aranha imensa com teias que brilham em prata, desenhando runas; casulos com objetos de muitas épocas. |
| Desafio | **[E]** m05 e m06. **[P]** Os bandidos (orcs renegados) "servem a algo que vive sob a terra" **[E]**: a rainha os controla pelos fios. |
| Recompensa | **[E]** m06. **[P]** Segunda visão: oito nomes gravados na Coroa, um deles riscado. |
| Consequência | **[P]** Os bandidos acordam livres e confusos; alguns viram aliados (missões secundárias futuras). |

### Fragmento 3 — **Fragmento da Forja** (forma, firmeza)

| Campo | Conteúdo |
|---|---|
| Guardião | **Golem Ancestral** **[E]** |
| Região | Pedreira dos Golens, Pedra Alta (nível 40–51) **[E]** |
| Origem | **[P]** A runa-mestra que os anões gravaram para dar forma à Coroa. Caiu na pedreira e deu vida às pedras: os golens. |
| Relação | **[A]** Pacto (as runas). Liga-se às falas de Thrain ("selaram o Véu com aço e runas") e de Brunna ("as runas da cripta estão apagando"). |
| Visual | **[P]** Colosso de pedra antiga com runas acesas em linhas, uma fornalha no peito onde brilha o fragmento. |
| Desafio | **[E]** m07 e m08 ("carrega o terceiro fragmento no peito"). |
| Recompensa | **[E]** Gemas (m08). **[P]** Os anões confirmam que **só eles podem reforjar a Coroa**, mas precisam de todas as peças e do Coração. |
| Consequência | **[P]** Os golens menores param; as runas da cripta voltam a brilhar por um tempo. |

### Fragmento 4 — **Fragmento da Raiz** (memória da Árvore)

| Campo | Conteúdo |
|---|---|
| Guardião | **Ent Milenar** **[E]** |
| Região | Coração da Mata e Vale Espectral, Sylvar (nível 52–60) **[E]** |
| Origem | **[P]** A lasca de cristal da própria Árvore usada na Coroa. Voltou para "casa": caiu na raiz que aflora em Sylvar, e a árvore mais velha do mundo a absorveu. |
| Relação | **[A]** A Árvore, diretamente. A raiz escura de Lyria é a corrupção subindo pela raiz até o Ent. |
| Visual | **[P]** Árvore viva gigante, apodrecida por dentro (`quests.js`: "apodreceu por dentro"), com veios escuros e um ponto de luz verde no tronco. |
| Desafio | **[E]** m09 e m10. **[P]** Os lobos espectrais são almas que a raiz corrompida não deixou descansar. |
| Recompensa | **[E]** m10. **[P]** Terceira visão: a Árvore inteira, com estrelas nos galhos, e três galhos secos (as três estrelas que sumiram). |
| Consequência | **[P]** Sylvar sabe agora que a corrupção vem de baixo, das raízes, e que alguém a alimenta. |

### Fragmento 5 — **Fragmento da Chama** (passagem, portas)

| Campo | Conteúdo |
|---|---|
| Guardião | **Senhor Demônio** **[E]** |
| Região | Deserto Escarlate e Fenda Demoníaca, Cidadela Rubra (nível 61–75) **[E]** |
| Origem | **[P]** A chama que selava as portas entre os mundos. O Senhor Demônio veio de um dos três mundos engolidos pelo Vazio, entrou por uma Fenda e roubou o fragmento para **manter a porta aberta** (`quests.js`: "usa o quinto fragmento para manter o portal aberto"). |
| Relação | **[A]** O Véu (as Fendas). Os orcs da Cidadela Rubra são os guardiões das Fendas desde o Pacto. |
| Visual | **[P]** Demônio de pele de brasa e chifres partidos, cercado por pedaços flutuantes de um mundo queimado. |
| Desafio | **[E]** m11 e m12. **[P]** Shara Olho-Rubro: "O Véu daqui é fino como pele" **[E]**. |
| Recompensa | **[E]** m12 (inclui um Fragmento Estelar). **[P]** Quarta visão: Nocturnos abrindo uma Fenda num ritual. |
| Consequência | **[P]** A Fenda Demoníaca se fecha; mas a Corte Carmesim aparece em outros lugares. Os orcs entram de vez na trégua. |

### Fragmento 6 — **Fragmento do Céu** (equilíbrio das luas)

| Campo | Conteúdo |
|---|---|
| Guardião | **Dragão Celeste** **[E]** |
| Região | Ninho dos Dragões e Ruínas de Aeternum, Bastião Celeste (nível 76–80) **[E]** |
| Origem | **[S]** O centro da Coroa, o ponto que ficava entre as luas. O último dos Antigos Dragões o segurou na queda e nunca mais soltou. Ele não está corrompido como os outros: está **ferido e ressentido** por ter tido o nome apagado. |
| Relação | Coroa, Pacto, luas e o oitavo nome. |
| Visual | **[P]** Dragão de escamas cor de céu ao entardecer, cicatrizes em forma de runas apagadas no peito, o fragmento brilhando como uma pequena lua. |
| Desafio | **[E]** m13 (Cavaleiros Caídos) e m14 (o Dragão). **[P]** A luta pode terminar de dois jeitos (escolha do grupo, capítulo 10): vencer à força ou **devolver o nome dele ao Pacto**. |
| Recompensa | **[E]** m14 (Fragmentos Estelares, gemas). **[P]** Revelação final (capítulo 10). |
| Consequência | **[P]** Os seis fragmentos estão reunidos, mas a Coroa não se reacende: falta o Coração. Gancho para a temporada seguinte. |

---

## 7. Povos

Os atributos e elementos são **[E]** (`world.json`). Cultura, história e papel no Pacto são **[P]**, exceto onde está marcado.

| Povo | Elemento **[E]** | Terra **[E]** | Papel no Pacto | Parte da história do povo (**[P]**, exigência do `DESIGN.md`) |
|---|---|---|---|---|
| **Humanos** | Luz | Vila Aurora; fundaram Valtheria Real | Signatários. **[E]** Malachar era humano. | **"A Vergonha de Malachar":** os humanos descobrem que a dinastia de Aldemar descende da corte que **não** seguiu Malachar, e carregam a missão de reparar a traição. |
| **Elfos** | Vento | Sylvar (Árvore-Mãe) | **[E]** Abençoaram a Coroa. Guardiões da raiz. | **"A Raiz que Escurece":** os elfos sentem a Árvore adoecer e percebem que a corrupção vem das raízes, não do céu. |
| **Elfos Negros** | Sombra | Umbraval (subterrâneo) | Signatários. **[A]** Acusados injustamente do rasgo e exilados. | **"O Nome dos Culpados":** Nyxara guarda a prova de que foi a Corte Carmesim. Os elfos negros buscam limpar o nome do povo; a confiança dos outros povos é a recompensa. |
| **Orcs** | Fogo | Cidadela Rubra | Guardiões das Fendas | **"O Muro de Fogo":** os orcs contêm as Fendas há séculos sem reconhecimento, e decidem se continuam sozinhos ou entram na trégua. |
| **Anões** | Terra | Pedra Alta | **[E]** Forjaram a Coroa. **[E]** Únicos capazes de reforjá-la. | **"A Última Forja":** recuperam as técnicas da runa-mestra para reforjar a Coroa. |
| **Homens-fera** | Terra | Clã das Presas | Signatários. **[E]** "Sentem o cheiro das sombras antes de qualquer um" (Ruk Garra-Cinza). | **"Os Ritos de Nyx":** os homens-fera honram Nyx como mãe dos ancestrais e são os primeiros a perceber que **Nyx não é inimiga**: está sendo puxada. |
| **Gigantes de Gelo** | Gelo | Fortaleza Glacial | Signatários. Guardam o norte, onde as raízes congeladas afloram. | **"O Trono do Inverno":** o Wyrm do Inverno **[E]** dorme sobre uma raiz da Árvore; os gigantes decidem se o acordam para lutar contra o Eclipse. |
| **Dragonitas** *(em teste)* | Fogo | Pico do Dragão | **[S]** Descendentes do oitavo povo apagado | **"O Nome Apagado":** reconquistar o lugar dos dragões no Pacto. |
| Halflings *(não jogáveis)* | Natureza | Vale Dourado | Chegaram depois do Pacto | Moradores e mercadores; Mira Pés-Ligeiros **[E]** leva notícias entre as cidades. |
| Sylphs *(não jogáveis)* | Raio | Bastião Celeste | Espíritos do vento que vivem perto do céu | Seren **[E]** é a vigia das estrelas. |
| Nocturnos *(não jogáveis)* | Sombra | Castelo Noctis | **[P]** A corte amaldiçoada de Malachar | Parte deles se arrependeu e vive em Castelo Noctis; a outra parte é a Corte Carmesim. **[E]** Os nocturnos querem destruir os selos dos Caídos (missão s_noc1). |

---

## 8. Personagens importantes

### 8.1 Grandes figuras

| Nome | Raça | Papel | Origem |
|---|---|---|---|
| **Malachar** | Humano | Arquimago que partiu a Coroa. **[S]** Vive dentro de Nyx; é o Eclipse. | [E] e [S] |
| **Conde Carmesim** | Nocturno | Senhor do Castelo do Sangue Eterno, líder da Corte Carmesim. **[E]** "Nunca perdeu um duelo." | [E] e [P] |
| **Dragão Celeste** | Antigo Dragão | Último do oitavo povo, guardião do Fragmento do Céu | [E] e [S] |
| **Arauto do Eclipse** | Humano | Convoca os heróis na Vila Aurora; voz do Segundo Juramento | [E] |
| **Rei Aldemar** | Humano | Rei de Valtheria Real e presidente do Conselho do Pacto | [P] (figurante em `interiores.gd`) |

### 8.2 Personagens de história nas cidades

As falas existentes estão em `npcs.gd`.

| Nome | Cidade | Papel na fusão **[P]** |
|---|---|---|
| Irmã Elowen | Aurora | Guardiã do Santuário. Guarda a pista da primeira palavra do Pacto (Vel'Anor). |
| Capitão Doran Vel | Aurora | Primeiro mentor de combate; teme o Castelo dos Corvos. |
| Velho Tobias | Aurora | Cronista. Dá a pista do oitavo nome. |
| Mira Pés-Ligeiros | Vale Dourado | Mensageira entre as cidades; liga os Atos. |
| Ancião Bramble | Vale Dourado | Primeira testemunha da corrupção (trigo cinzento). |
| Thrain Martelo-Fundo | Pedra Alta | Mestre das forjas; guardião do segredo da reforja. |
| Brunna Cinzel | Pedra Alta | Percebe que alguém "bebe" o poder das runas: pista da Corte Carmesim. |
| Aelar Folha-Prata | Sylvar | Sentinela; a Árvore lhe disse a palavra "fenda". |
| Lyria Canto-de-Orvalho | Sylvar | Curandeira; segue a raiz escura. |
| Grukk Dente-de-Ferro | Cidadela Rubra | Chefe de guerra; decide a entrada dos orcs na trégua. |
| Shara Olho-Rubro | Cidadela Rubra | Xamã; conhece o Véu fino das terras rubras. |
| Seren do Alto Céu | Bastião Celeste | Conta as estrelas que somem. |
| Ruk Garra-Cinza | Clã das Presas | Rastreador das sombras. |
| Nyxara | Umbraval | Guarda o nome dos verdadeiros culpados. |
| Kaelthar Escama-de-Bronze | Pico do Dragão | Guardião do Pico; o primeiro a dizer que o Dragão acordou. |

Fichas completas (aparência, classe, equipamento) ficam para a próxima etapa, junto com a arte. **[P]**

---

## 9. Regiões e lugares na mitologia

Os lugares são **[E]** (mapa); o papel na mitologia é **[P]**.

| Lugar | Significado |
|---|---|
| **Ruínas de Vel'Anor** | Onde o Pacto foi jurado, sobre uma raiz da Árvore. Selo partido com a primeira palavra. |
| **Valtheria Real** | Capital neutra, sede do Conselho do Pacto. A **Arena dos Heróis** é onde se disputa o título de **Campeão do Pacto**: duelo aceito pelos dois lados não fere o Véu. O título é de honra e **não altera a história**, como manda o `DESIGN.md`. |
| **Fenda Demoníaca / Fenda Astral** | Rasgos no Véu |
| **Monólito Sussurrante** | Lugar onde o Vazio fala |
| **Templo da Lua Partida** | Antigo templo de Nyx; a Sacerdotisa da Lua **[E]** canta para Nyx sem saber que Malachar está lá dentro |
| **Castelo do Sangue Eterno** | Corte Carmesim. **[E]** "Está acordando" (Grukk). |
| **Castelo dos Corvos** | Rei Corvo **[E]**: um nobre que fugiu de Malachar e foi amaldiçoado mesmo assim |
| **Trono do Inverno** | Raiz congelada; Wyrm do Inverno **[E]** |
| **Umbraval** | Cidade do exílio dos elfos negros, dentro da montanha |
| **Sylvar** | Árvore-Mãe: o ponto onde a Árvore dos Mil Mundos toca o continente |
| **Abissália** | **[P]** Cidade que afundou no Grande Silêncio e sobreviveu numa bolha de ar criada pelos elfos |
| **Era Neon — Distrito Ômega** | **[A]** Já é "distrito futurista que atravessou uma fenda no tempo" (`neon.js`). Passa a ser **a primeira prova de que os mil mundos existem**: um pedaço de outro galho da Árvore que caiu em Valtheria. Mecha Ômega e drones são de lá. |

---

## 10. Como o jogador descobre a verdade (progressão)

As missões principais **[E]** (m01 a m14) continuam iguais. O que muda é **o que cada uma revela**. Princípio: a informação vem do mundo (visões ao tocar o fragmento, falas, ruínas, itens), não de longos diálogos.

| Ato | Nível | Cidade | Missões **[E]** | O jogador acredita que… | O jogador descobre **[P]** |
|---|---|---|---|---|---|
| I — O Despertar | 1–19 | Aurora | m01–m03 | Criaturas enlouqueceram por causa do eclipse | Os fragmentos sustentam coisas; a Coroa tinha laços com os povos |
| II — Os Fios | 20–39 | Vale Dourado | m04–m06 | Bandidos são só bandidos | Oito nomes na Coroa, um riscado |
| III — A Forja | 40–51 | Pedra Alta | m07–m08 | Os anões podem consertar tudo | Falta uma peça: o Coração da Coroa |
| IV — A Raiz | 52–60 | Sylvar | m09–m10 | O mal vem do céu (Nyx) | O mal sobe pelas raízes, e alguém alimenta a corrupção |
| V — As Fendas | 61–75 | Cidadela Rubra | m11–m12 | Os demônios são o inimigo | A Corte Carmesim abre as Fendas; os elfos negros eram inocentes |
| VI — O Céu | 76–80 | Bastião Celeste | m13–m14 | O Dragão é o último inimigo | O oitavo nome era o dos dragões; **Malachar está dentro de Nyx** |
| Temporadas | 80+ | Capital e Fendas | (futuras) | — | Buscar o Coração da Coroa dentro de Nyx; os mil mundos pelas Fendas |

**Escolhas que importam — [P]:**

1. **Final do Ato VI:** vencer o Dragão Celeste à força, ou devolver o nome dos dragões ao Pacto. O segundo caminho dá um aliado e uma recompensa diferente, sem ser mais forte (respeita o equilíbrio).
2. **Ato V:** defender os elfos negros no Conselho do Pacto ou ficar em silêncio. Muda as falas e uma missão secundária em Umbraval.
3. **Cada povo** tem a sua parte (capítulo 7), mas todas convergem para os mesmos seis fragmentos, como pede o `DESIGN.md`.

---

## 11. Sistema de magia (dentro da história) — **[P]**

- **Duas fontes:**
  - **Seiva:** o que vem de Lúmen e da copa. Alimenta luz, natureza, cura e vento.
  - **Sonho:** o que vem de Nyx e das raízes. Alimenta sombra, ilusão e espírito.
- **Os elementos são galhos da Árvore** e combinam as duas fontes.
  - **[E]** Os elementos dos dados: luz, vento, sombra, fogo, terra, natureza, raio e gelo.
  - **[E]** Classes ligadas à água já existem: Mago das Águas, Mestre das Marés.
- **O custo:** magia demais num lugar só afina o Véu. Explica por que magos poderosos atraem criaturas.
- **Relação com o jogo:** a afinidade elemental por raça **[E]** e o pedido do `DESIGN.md` de que "o ambiente aumenta ou reduz atributos" (lugares de Seiva ou de Sonho) podem usar esta regra.

---

## 12. Equipamentos especiais

| Item | História |
|---|---|
| **Fragmento Estelar** **[E]** | Lasca de luz que se desprende dos fragmentos ao serem libertados. Material das armas finais. |
| **Gema Arcana** **[E]** | Seiva cristalizada da Árvore. |
| **Set Desbravador das Estrelas** **[E]** | **[A]** "Forjado com minério estelar" **[E]**: minério caído de um mundo engolido (uma das três estrelas). |
| **Set e espada Alvorecer Celestial** **[E]** | **[A]** "Usado pelos primeiros guardiões da aurora" **[E]**: a guarda que vigiava a Coroa na Era do Pacto. |
| **Set Paladino Vigilante** **[E]** | **[P]** Armadura dos patrulheiros do Segundo Juramento. |
| **Espada Celestial da Harmonia** **[E]** | **[P]** Forjada pelos anões depois do Grande Silêncio com a esperança de um dia reunir os povos. |
| **Equipamentos da Era Neon** **[E]** | **[A]** Tecnologia de outro galho da Árvore. |

Regra para os próximos itens únicos **[P]**: todo item lendário deve contar **de que mundo, era ou povo veio**, em uma frase.

---

## 13. Alterações de texto necessárias (aguardam aprovação)

Nenhuma destas mudanças foi feita.

| # | Arquivo | Mudança |
|---|---|---|
| 1 | `quests.js` (`LORE`) | Reescrever os 6 capítulos para a versão fundida: Pacto → Coroa → Grande Silêncio → Eclipse → Segundo Juramento. O título passa a "Valtheria — A Árvore dos Mil Mundos". |
| 2 | `quests.js` m04 | "Rumo ao Forte Dourado" passa a citar o Vale Dourado e o Forte como castelo do Vale. |
| 3 | `npcs.gd` (`STORY`) | Manter todas as falas. Acrescentar 1 ou 2 falas por personagem com as pistas do capítulo 10, por Ato. |
| 4 | Cliente nativo | Criar a janela "Crônicas de Valtheria" (a web já tem a aba "História", `pLore`). |
| 5 | Banco (`game.quests`) | Atualizar os textos das missões m01–m14 com as revelações de cada Ato. |
| 6 | `docs/` | Salvar esta bíblia como `docs/BIBLIA_NARRATIVA.md`, fonte oficial. |

---

## 14. Rastreabilidade

| Elemento | Fonte no projeto |
|---|---|
| Lúmen, Nyx, Coroa Celeste, Malachar, Grande Silêncio, seis fragmentos e guardiões, Arauto, Lei da Trégua, 14 missões | `quests.js` |
| Pacto do Véu, sete povos, oitavo nome, Vel'Anor, aço e runas, estrelas faltando, raiz escura, acusação dos elfos negros, Dragão acordado | `cliente-godot/scripts/npcs.gd` |
| Árvore dos Mil Mundos, mundos em órbita | `data.js`, `title.js` |
| Vazio, Anomalias | `dialog.js`, `data.js` |
| Era Neon (fenda no tempo) | `neon.js`, `data.js` |
| Raças, elementos, descrições | `data.js`, `cliente-godot/data/world.json` |
| Lugares, cidades, castelos | `world.json`, `mapa.json` |
| Regras de projeto (história por raça, mundo aberto separado) | `cliente-godot/DESIGN.md` |

---

## 15. Decisões pendentes do Robson

1. **Aprovar ou ajustar os segredos de roteiro:**
   - Malachar está dentro de Nyx.
   - O oitavo nome é o dos Antigos Dragões.
   - A Corte Carmesim abre as Fendas.
   - O Coração da Coroa.
2. **Dragonitas:** manter a raça, já que a história agora dá a ela um papel central? Se a raça sair, o papel fica com os NPCs.
3. **Nomes novos:** Era da Raiz, Era do Pacto, Segundo Juramento, Seiva e Sonho, Campeão do Pacto, Conselho do Pacto, Corte Carmesim, nomes dos fragmentos.
4. **As duas escolhas** do capítulo 10.
5. Autorização para as alterações do capítulo 13.
