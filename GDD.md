# GDD — Drag Racing Roguelike

> Documento vivo. Toda decisão aqui foi fechada em sessão de design; o que ainda não foi decidido está na seção **Pendências**.
> Engine: **Godot 4.7.1** · Plataforma alvo: **PC / Steam** (teclado + controle)

---

## 1. Conceito

Roguelike de arrancada. O jogador monta um carro peça por peça ao longo de uma run, escolhendo rota num mapa ramificado estilo Slay the Spire, e prova a build em corridas de linha reta de ~30 segundos. As peças se desgastam pelo jeito como você dirige, e o carro pode literalmente quebrar no meio da run. A run termina quando você derrota o chefe do ato final — ou quando o carro quebra e você não tem dinheiro para consertar.

**Pilares:**
1. **A build é sentida, não lida.** Um motor de torque e um de alta rotação produzem corridas visivelmente diferentes, não tooltips diferentes.
2. **Ganância tem preço com memória.** Forçar o carro ganha a corrida de agora e cobra na corrida de depois.
3. **Um botão, muitas decisões.** Profundidade vem da build e do timing, não da quantidade de inputs.

---

## 2. A corrida

### 2.1 Formato

Duração alvo: **~30 segundos**, linha reta, **dois carros em paralelo** (sem vácuo/aerodinâmica entre eles).

A corrida é dividida em **3 fases**, e cada fase testa uma coisa diferente:

| Fase | Tempo | O que acontece | O que decide |
|---|---|---|---|
| **1 — Largada** | 0–4s | Skill-check de RPM e tração. Bog vs. wheelspin. | Banda **baixa** do motor + pneu + piso |
| **2 — Aceleração** | 4–20s | 6–7 trocas de marcha. Janela de acerto encolhe conforme sobe. | Banda **média** + transmissão + caixa de câmbio |
| **3 — Topo** | 20–30s | Sem mais trocas. Só decisão térmica: quanto de nitro você aguenta segurar. | Banda **alta** + nitro + escape + motor (teto térmico) |

Essa divisão é o esqueleto de balanceamento do jogo inteiro: **toda peça declara em qual fase ela atua**.

### 2.2 Input do jogador

Um input principal: **troca de marcha no tempo certo** (janela verde no medidor de RPM). Mais a largada, que é um skill-check de RPM inicial. Mais o nitro, que é um botão de segurar.

Nada além disso. Em 30 segundos o jogador consegue prestar atenção em uma coisa bem feita.

### 2.3 Nitro e calor

O nitro **não** é um empurrão de clique. É um recurso contínuo com risco:

- Você **segura** o botão → ganha aceleração → **o motor esquenta**.
- Soltou → esfria (taxa definida pelo **escape**).
- Passou do teto térmico (definido pelo **motor**) → risco de fundir (ver §4).

**O nitro não é exclusivo da fase 3.** Nada impede queimar na largada ou no meio da corrida — só que aí você chega no topo com o motor quente. A decisão está distribuída pelos 30 segundos, sem botão novo.

**Formato do tanque é escolha de build** (definido pela peça de nitro equipada):
- **1 tanque longo** — aposta única, o calor acumula sem alívio. Pico alto, risco alto.
- **3 garrafas curtas** — janelas táticas, o motor esfria entre elas. Pico menor, risco controlado.

### 2.4 Câmbio manual vs. automático

**Escolhido antes da run**, vale para a run inteira.

| Modo | Teto | Risco |
|---|---|---|
| **Manual** | Alto (acerta janelas perfeitas) | Erro de troca desgasta e pode quebrar a transmissão |
| **Automático** | Menor (nunca erra, nunca acerta a janela perfeita) | **Zero desgaste de transmissão** |

Automático é acessibilidade real: o jogador casual joga a run inteira nele e funciona.

> **Nota de balanceamento:** como a escolha é travada antes da run, quem escolheu manual e chega com a transmissão em estado Crítico não tem válvula de escape. Compensar com janela perfeita mais generosa no manual, e permitir troca de modo na **Oficina** para evitar que a run vire sentença.

### 2.5 Câmera e HUD

**Câmera de perseguição dinâmica em 3ª pessoa** — baixa, quase na altura dos faróis, posicionada **à frente dos carros e olhando para trás**. Tomada clássica de transmissão de arrancada: os carros vêm em cima da câmera, e o jogador vê a **frente** do carro — que é o ângulo em que a arte de carroceria é produzida (§3.5).

**A câmera é rígida e presa ao carro do jogador.** Mesmo deslocamento, mesmo ângulo, o tempo todo: ela avança com o jogador e nunca gira nem troca de alvo. Isso **não é preferência de enquadramento, é limite imposto pela arte** — a carroceria é uma foto parada. Qualquer giro da câmera obrigaria o sprite a girar junto para continuar encarando ela, e o carro pareceria esterçar no meio de uma reta. Pela mesma razão o sprite não é *billboard*: a rotação dele é fixa e casada com o ângulo da câmera.

**Quando o rival abre, a câmera recua pelo próprio eixo.** Ela desliza para trás na mesma direção, o bastante para o rival continuar cabendo no quadro. Isso é *dolly* puro: multiplicar um vetor unitário por um escalar não muda direção nenhuma — nem azimute, nem inclinação — então o sprite continua parado. É a única forma de reenquadrar sem reintroduzir o giro.

O recuo tem teto. Passado ele, o rival sai do quadro mesmo, e a leitura de posição fica por conta do **indicador de gap** — que é exatamente a razão de ele existir e estar sempre visível. O teto existe porque, sem ele, uma vantagem grande do rival encolheria os dois carros até virarem pontos.

**O ângulo da câmera é ditado pela arte, não pelo gosto.** A carroceria é uma foto em 3/4, então a **pista tem que fugir na mesma diagonal**. Com a câmera alinhada ao eixo da pista, o asfalto corre reto para um ponto de fuga central enquanto o carro está virado 38° — e o carro parece atravessado na pista, andando de lado. A câmera precisa ficar deslocada do eixo no mesmo ângulo em que a foto foi tirada (~38°), e é esse deslocamento que faz o asfalto correr na diagonal.

**Sentido da corrida: da direita para a esquerda.** A câmera fica do lado esquerdo da pista (`CAM_SIDE = -1`), o que põe o fim da pista à direita do quadro e traz os carros em direção à esquerda. A arte entra **sem espelhamento** — espelhar inverteria emblemas, placas e decalques, e um jogo cujo público inclui gente que conhece carro nota isso na hora.

Isso amarra duas coisas que não podem ser mexidas isoladamente: **ângulo da foto = ângulo da câmera**. Trocar o fornecedor de arte por fotos em outro ângulo obriga a mexer na câmera junto.

**Indicador de gap sempre visível no HUD.** Com a câmera presa ao jogador, ele é a única fonte confiável de posição quando o rival está fora do quadro — o jogador nunca pode ter dúvida sobre quem está ganhando — a decisão de queimar nitro nos últimos 5 segundos depende exatamente dessa informação.

**Medidor de RPM / janela de troca:** HUD fixo e grande. Não pode ser instrumento no painel — a câmera é externa e móvel, painel não seria legível.

**A árvore de largada é a linguagem visual do HUD.** Largada, janela de troca e limite térmico usam a **mesma lâmpada**, na mesma sequência âmbar → verde → vermelho da pista real. Na largada ela é a árvore literal; na corrida vira a régua de giro, e quando o giro entra na janela a régua inteira acende verde — o sinal de trocar precisa ser legível pela visão periférica, porque o jogador está olhando o rival, não o mostrador. Uma linguagem só, aprendida uma vez, usada nos três momentos em que o jogo cobra timing.

Decorre daí o resto: paleta quente de autódromo à noite, recortes chanfrados (não cantos arredondados de kit de UI), e **o nitro como o único elemento frio do painel** — é o oposto do calor, e é essa oposição que o jogador precisa ler na fase 3. As cores de sinal são saturadas de propósito: são aviso, não enfeite.

Tipografia: **Bahnschrift** (o DIN 1451 que acompanha o Windows), face de instrumento e sinalização viária. Caixa alta espaçada fica reservada só a rótulo de mostrador; o resto é caixa normal, para não virar um único traje aplicado a todo texto pequeno.

---

## 3. Carro e equipamentos

### 3.1 Modelo de potência — curva de 3 bandas

Todo motor tem **três valores**, não um:

```
Baixa (marchas 1–2)  ·  Média (marchas 3–5)  ·  Alta (marchas 6–7)
```

Exemplos:
- V8 de torque: `95 / 75 / 45` — atropela na largada, é engolido no final.
- Aspirado de alto giro: `40 / 70 / 95` — apanha na largada, voa no topo.

As bandas são **coladas nas fases** (baixa = fase 1, média = fase 2, alta = fase 3).

### 3.2 Slots de equipamento (7)

| Slot | Função mecânica | Desgasta? |
|---|---|---|
| **Motor** | Curva de 3 bandas + teto térmico | Sim |
| **Turbo** | Desloca a curva para a direita, adiciona lag, gera mais calor | Sim |
| **Escape** | Taxa de dissipação de calor | Não |
| **Nitro** | Capacidade do tanque + formato (1 longo / 3 curtos) | Consumido |
| **Transmissão** | Número de marchas + espaçamento (curta = mais trocas, mais tempo na banda alta) | Sim |
| **Caixa de Câmbio** | Tamanho da janela verde + velocidade da troca | Não |
| **Roda / Pneu** | Perfil de aderência por piso | Sim |

**Transmissão ≠ Caixa de Câmbio.** Transmissão define *quantas trocas e quando*. Câmbio define *quão fácil é acertar cada uma*.

### 3.3 Itens passivos (2 slots)

Fora do inventário, **não desgastam**, sempre ativos, **encontrados durante a run**.

| Raridade | Tipo de efeito | Exemplo |
|---|---|---|
| **Comum** | Percentual | +10% de torque na banda baixa; −8% de geração de calor |
| **Raro** | Dobra de regra | "Os primeiros 4s de nitro não geram calor"; "A janela verde da 1ª troca é o dobro"; "Errar uma troca não desgasta a transmissão (1× por corrida)"; "Largada na lama conta como asfalto" |

**Frequência:** ~4–5 aparições por run (chefe de ato garante 1; resto vem de baús e eventos). Com só 2 slots, isso gera 2–3 decisões de "qual eu abro mão?" por run.

### 3.4 Marcas (a camada "Hades")

Peça não é só número — ela **pertence a uma marca**, e a marca é o arquétipo. É o que faz o jogador reconhecer a build em 2 segundos.

| Marca | Identidade |
|---|---|
| **Torque** | Banda baixa forte, largada monstruosa, morre na fase 3 |
| **Alta Rotação** | Banda alta forte, largada ruim, atropela no final |
| **Química (Nitro)** | Tanque maior, gera mais calor — empurra pro all-in térmico |
| **Confiabilidade** | Números medianos, desgaste muito mais lento — "chega inteiro no chefe" |
| **Tração** | Perfis de pneu e resposta a piso — ignora o mapa telegrafado |

**Raridade:** Comum / Rara / Épica — escala só os números.
**Bônus de conjunto:** 3 peças da mesma marca ligam um efeito que não existe de outra forma.
> Ex. *Química ×3*: "segurar nitro no limite não desgasta o motor por 5s".

### 3.5 Carros

**Carroceria = o carro.** É a escolha de pré-run e define os stats base (curva de bandas inicial).
**Aerofólio = puramente visual.**

**Formato da arte:** foto em 3/4 frontal **e sempre do mesmo lado do carro** — misturar fotos tiradas do lado oposto faz uns carros correrem de costas, e o jogo passa a precisar espelhar caso a caso (o que inverte emblemas). Fundo transparente, carro **branco** (a pintura entra por tingimento, então uma imagem serve para todas as cores) e **sem rodas** — as caixas de roda ficam vazias de propósito. Roda é um slot de equipamento (§3.2), e sua arte é composta por cima da carroceria. Isso é o que permite trocar de pneu e o jogador **ver** a troca.

Os carros formam uma **escada de poder pura** (estilo Need for Speed): Tier 1 é claramente mais fraco que Tier 3. Carros novos são desbloqueados vencendo runs.

Carros fracos continuam capazes de zerar o jogo com uma boa run e boas peças — é desafio auto-imposto, sem recompensa extra. Sem dificuldade adaptativa: **a força dos rivais é fixa por ato, nunca escala com o seu carro.**

**Protótipo/lançamento inicial:** 3 carros (torque / alta rotação / sucata), expandindo para 5–6.

### 3.6 Inventário

- **2 slots de reserva** no início.
- **Máximo de 6**, expandido permanentemente ao completar desafios.
- **Troca livre em qualquer nó do mapa.** Nunca dentro da corrida.
- **Peça de Ferro-velho vem já desgastada** — estado Gasta ou Crítica desde a primeira corrida. Potência total, risco alto. É a tentação: o motor épico que pode fundir a qualquer momento.
- Peça substituída que não cabe no inventário vira **sucata** por uma grana pequena.

O limite de inventário é o que faz o sistema de piso existir: carregar um pneu reserva custa metade da sua capacidade.

---

## 4. Desgaste e quebra

### 4.1 Regra única

> **A ação que gasta é a ação que pode quebrar.**

A peça **funciona sempre a 100%**. O desgaste não reduz performance — ele aumenta a **chance de estourar**. E o dado só é rolado **no momento do estresse**, nunca no início da corrida.

Consequência: um carro sucateado ainda pode chegar ao chefe **se você dirigir com cirurgia**. O desgaste é uma algema de estilo de jogo, não uma punição aleatória.

### 4.2 Fonte de desgaste por peça

| Peça | Desgasta quando... | Pode quebrar quando... |
|---|---|---|
| **Transmissão** | Você erra a janela de troca | No momento do erro de troca |
| **Motor** | Você ultrapassa a faixa térmica | Enquanto está acima do teto térmico |
| **Turbo** | Tempo total em boost sustentado | Durante boost prolongado |
| **Pneu** | Piso errado para o perfil do pneu | Na largada e em piso hostil |
| **Nitro** | Não desgasta — é **consumido** | — (reabastece na Oficina) |

**Não desgastam:** escape, caixa de câmbio, aerofólio, carroceria, itens passivos.

### 4.3 O que acontece ao estourar

| Peça | Consequência |
|---|---|
| **Motor** | **Funde.** DNF, perde a corrida. Única morte súbita do jogo. |
| **Transmissão** | Trava na marcha atual até o fim. Ainda dá pra terminar — e ganhar, se estava na frente. |
| **Turbo** | Perde a banda alta. A fase 3 morre. Ganha se já tinha aberto vantagem. |
| **Pneu** | Derrapagem, perde ~2s. Recuperável se estava dominando. |
| **Nitro** | Não quebra, só acaba. |

Só o motor encerra a corrida. Os outros três transformam a corrida em "sobrevive até a linha", que é mais memorável que uma tela de derrota.

### 4.4 Quebra e falência

Peça Quebrada precisa de conserto na **Oficina**. O orçamento pode custar **mais que o valor do carro** — e aí a decisão é do jogador: afunda o dinheiro ou não.

**A run acaba quando:**
1. O chefe do ato final é derrotado (**vitória**), ou
2. O carro quebra e você **não tem dinheiro para consertar** (**falência**).

---

## 5. Pistas e piso

Cada piso tem um **perfil sobre as 3 fases + calor** — não é um multiplicador global.

| Piso | Efeito | Quem se dá bem |
|---|---|---|
| **Lama** | Fase 1 arrasada (patina feio), fases 2–3 quase normais | Build de alta rotação; pune torque |
| **Deserto** | Fases normais, mas **calor ambiente alto** — margem térmica encolhe | Escape/motor resistente; pune all-in em nitro |
| **Cidade / asfalto irregular** | Largada boa, perda constante pequena nas fases 2–3 | Torque + câmbio curto |
| **Pista preparada** | Neutro/ideal | A build "pura" — e o rival também não tem desculpa |

**O pneu é um perfil espelhado**, não um número: pneu de lama é ótimo na lama e ruim no asfalto; slick é o inverso; misto é medíocre em tudo. Não existe "o melhor pneu".

**O piso de cada nó é telegrafado no mapa.** Sem isso, o pneu-perfil vira loteria em vez de planejamento.

Escolher errado custa duas vezes: **perde performance E queima o pneu.**

---

## 6. Estrutura da run

### 6.1 Mapa

- **3 atos.** ~8–10 nós por ato. **~25–30 corridas por run, ~30–40 minutos.**
- Mapa **ramificado** (estilo Slay the Spire) — você escolhe a rota.
- Cada ato tem uma **dupla de pisos dominante**: ato 1 cidade/asfalto · ato 2 lama/deserto · ato 3 pista/misto. Isso dá ao pneu-perfil uma estação certa e permite planejar dois trechos à frente.
- **O nó do chefe fica trancado até Reputação ≥ X.** Cada vitória dá reputação (corrida difícil dá mais). O gate abre por volta do nó 6.
- Liberado o chefe, você escolhe: **desafiar agora** ou **continuar correndo** por mais loot e dinheiro, pagando em desgaste. Farmar mais é literalmente apostar a run.
- **Nó consumido não repete.** Perdeu, seguiu.

### 6.2 Tipos de nó (7)

| Nó | O que dá |
|---|---|
| **Racha comum** | Dinheiro + reputação + escolha de peça |
| **Rival marcado (elite)** | Rival mais forte, piso hostil, aposta alta. Muito mais reputação, peça de raridade melhor. Opcional — é onde as runs boas e as mortas se separam. |
| **Oficina (loja)** | Gasta dinheiro: comprar peça, **consertar desgaste**, reabastecer nitro, remover peça ruim, trocar modo de câmbio |
| **Ferro-velho / Baú** | Peça grátis (às vezes Épica), **já desgastada** |
| **Boxes (descanso)** | Grátis, escolha **uma**: reparar desgaste **ou** melhorar uma peça **ou** trocar o pneu para o próximo trecho |
| **Evento** | Texto + escolha com risco (mecânico suspeito, racha clandestino apostando peça, polícia) |
| **Chefe** | Trancado por Reputação |

> **Boxes é obrigatório antes do nó de chefe.** Se todo conserto custasse dinheiro, o jogador nunca consertaria (dinheiro também compra build), chegaria no ato 3 com tudo em Crítico e a run viraria frustração pura. Boxes é a válvula gratuita — mesma função da Fogueira no Slay the Spire.

### 6.3 Rivais

O rival **usa o mesmo modelo que o jogador**: curva de 3 bandas, nitro com calor, pneu com perfil, e um **nível de perícia** (com que precisão acerta as janelas de troca, quando queima nitro).

- **Build e modelo de carro são aleatórios por nó.**
- **Escalam pelo índice do nó**, gradualmente — nunca pela força do jogador.
- **Sem IA elástica.** Se o jogador passou 25 corridas montando uma build, a build tem que pagar.
- **O chefe é pré-estabelecido** e autoral: build épica coerente + perícia quase perfeita.

**Telegrafia no mapa:** o nó mostra **arquétipo, pneu e piso** — ex. *"Rival: alta rotação · pneu de rua · piso lama"*. Os números exatos ficam escondidos. Você sabe o **formato** do confronto, não o resultado.

Isso é o que dá função ao mapa ramificado: escolher entre dois nós é escolher **qual confronto a sua build atual ganha melhor**.

### 6.4 Aposta e derrota

- **Todo racha tem valor apostado.** Ganhou, leva; perdeu, paga. A aposta é visível e escala com a dificuldade do nó.
- **Rival marcado aposta peça** — você põe uma peça na mesa. Perdeu, ela vai embora.
- Perder **não dá reputação** e **consome o nó**.
- **Perder não desgasta a mais que ganhar.** O desgaste já vem das suas próprias ações; empilhar punição sobre punição não acrescenta decisão.

A espiral existe e é legível: perder drena o dinheiro que consertaria o carro, e o carro pior perde mais. Mas o jogador vê ela chegando com tempo de reagir — vender peça, pular nó, ir pro chefe mais cedo.

### 6.5 O chefe

**Melhor de 3 corridas, em 3 pisos diferentes, sem reparo entre elas.**

É onde tudo que a run construiu é cobrado de uma vez: build, estado das peças, escolha de pneu reserva, e disciplina para não forçar calor. Peça em Crítico vira roleta a cada corrida.

**Se perder:** você perde a reputação acumulada, mas o nó continua lá. Pode tentar de novo — só que precisa correr mais nós para reabrir o desafio, e os nós são finitos.

> **O mapa é o cronômetro.** Falhar duas vezes no chefe normalmente encerra a run por exaustão, sem precisar de nenhuma regra extra de game over.

---

## 7. Progressão entre runs

**Só desbloqueio de acervo. Sem poder permanente comprável.**

| O que desbloqueia | Como |
|---|---|
| **Carros novos** (escada de poder) | Vencer runs |
| **Peças, passivos e eventos novos no pool** (variedade) | Marcos ao longo das runs |
| **Slots de inventário** (2 → 6) | Desafios específicos |

A promessa é limpa: **carro novo = mais força. Runs jogadas = mais possibilidades.**

**Run perdida também dá progresso.** Desbloqueios atrelados a marcos — "chegue ao ato 2", "funda 3 motores", "vença um marcado com o pneu errado" — não só a vitórias. Roguelike onde derrota rende zero faz o jogador desistir na 4ª run.

> Não existe upgrade permanente de stats (tipo Espelho do Hades). O carro já é a escada de poder; duas escadas subindo juntas tornariam o balanceamento dos rivais impossível e produziriam dificuldade adaptativa por acidente.

---

## 8. Escopo e produção

### 8.1 Constatação técnica

**O jogo não precisa de física de veículo.** A corrida é unidimensional — uma posição escalar avançando numa reta, com aceleração derivada da banda de potência. Sem curva, sem colisão, sem suspensão. A física inteira cabe em ~200 linhas.

Em volume de código, o jogo é: **mapa, inventário, loja, ficha de peça, tooltip, tela de resultado, meta-progressão.** É um jogo de UI com 30 segundos de corrida no meio.

### 8.2 Risco principal

**Modelos de carro**, não código. O ecossistema 3D do Godot é magro em assets de veículo. Decidir **antes da primeira linha de arte**: comprar assets (Sketchfab / CGTrader / Kenney) ou assumir estilo low-poly/estilizado.

### 8.3 Primeiro milestone — protótipo só de corrida

Cubos cinzas numa reta. 1 carro, 1 rival, as 3 fases, troca manual com janela verde, nitro com calor. **Sem mapa, sem loja, sem peças** — só valores editáveis num arquivo.

**As três perguntas que o protótipo responde:**
1. Você joga 20 corridas seguidas e ainda quer jogar a 21ª?
2. **Expondo os 3 perfis de motor como seletor:** você *sente* a diferença entre torque e alta rotação numa corrida de 30s?
3. Segurar o nitro até quase estourar dá frio na barriga?

Se **(2)** falhar, todo o sistema de bandas, marcas, builds e loot desaba junto — melhor descobrir na semana 2 do que no mês 6.
Se **(3)** falhar, a fase 3 precisa de outra ideia antes de construir 25 nós em volta dela.

---

## 9. Pendências

Coisas ainda não decididas, em ordem aproximada de urgência:

- **Números de tudo.** Curvas de banda, taxas de calor, tempos de fase, custo de conserto, valor de aposta, reputação por nó. Sai do protótipo, não da mesa.
- **Número exato de marchas** (6 ou 7) e como a transmissão altera isso.
- **Estados de desgaste:** quantas faixas (Nova / Gasta / Crítica) e qual a curva de chance de quebra em cada uma.
- **Estilo de arte** e decisão de comprar vs. modelar assets.
- **Conteúdo dos eventos** — escrever depois que o núcleo estiver validado.
- **Áudio.** Som de motor por banda é provavelmente o feedback mais importante do jogo depois do HUD; merece seção própria quando o protótipo existir.
- **Chefes:** identidade, build e apresentação de cada um dos 3.
- **Nome do jogo.**
