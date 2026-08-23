# Plano — o que falta do GDD

> Companheiro do [GDD](GDD.md). O GDD diz **o que o jogo é**; este arquivo diz **em que
> ordem construir o que ainda não existe, e por quê nessa ordem**.

---

## Onde estamos

O **núcleo da corrida está pronto e medido**: 30 segundos em 3 fases, largada, troca com
janela, nitro com calor e overboost, desgaste de motor e câmbio persistindo numa sequência,
peças em 5 slots com marca e raridade, inventário de reserva, elenco de 25 carros com
potência de fábrica, e HUD.

O que falta é quase tudo que transforma **uma sequência de corridas** numa **run**.

| GDD | Item | Status |
|---|---|---|
| 2.1–2.2 | 3 fases, input | pronto |
| 2.3 | Nitro e calor | pronto · **formato do tanque (1 longo × 3 curtos) falta** |
| 2.4 | Câmbio automático | **falta** |
| 2.5 | Câmera e HUD | pronto |
| 3.1 | Curva de 3 bandas | pronto |
| 3.2 | 7 slots de equipamento | **5 de 7** — faltam turbo e roda |
| 3.3 | 2 itens passivos | **falta** |
| 3.4 | Marcas | **4 de 5** (falta Tração) · **bônus de conjunto falta** |
| 3.5 | Carros | pronto · **desbloqueio falta** |
| 3.6 | Inventário | pronto (2 espaços) · **expansão 2→6 falta** |
| 4.1 | "A ação que gasta é a que pode quebrar" | pronto |
| 4.2–4.3 | Desgaste e quebra por peça | **2 de 4** — faltam turbo e pneu |
| 4.4 | Conserto e falência | **falta** |
| 5 | Pistas e piso | **falta inteiro** |
| 6.1–6.2 | Mapa e os 7 tipos de nó | **falta** |
| 6.3 | Rivais | build própria e escala prontas · **telegrafia falta** |
| 6.4 | Aposta e derrota | **falta** |
| 6.5 | Chefe em melhor de 3 | **falta** |
| 7 | Progressão entre runs | **falta** |

---

## O portão que o próprio GDD colocou

O §8.3 diz, com todas as letras, que nada disso deveria ser construído antes das três
perguntas do protótipo terem resposta **jogando**:

1. Você joga 20 corridas seguidas e ainda quer a 21ª?
2. Dá pra *sentir* a diferença entre torque e alta rotação em 30s?
3. Segurar o nitro até quase estourar dá frio na barriga?

**Toda a calibragem até aqui foi feita em headless.** Os números dizem que os sistemas se
comportam como o design pede — a ganância cobra, as bandas mudam a forma da corrida, as
peças mudam os números. Nenhum número diz se é divertido.

Se a resposta da pergunta 1 for "não", as fases 3 a 5 deste plano são meses construídos em
cima de areia. Vale meia hora jogando antes de começar a fase 1.

---

## O caminho crítico

Duas coisas destravam quase todo o resto, e nenhuma das duas é grande:

- **Dinheiro** destrava conserto (4.4), aposta (6.4) e os nós de loja e boxes (6.2).
- **Piso** destrava o pneu, a marca Tração, e é metade da informação que faz o mapa ser
  decisão em vez de menu (6.3).

Por isso as duas vêm antes do mapa, que é o item grande. Construir o mapa primeiro
significaria criar os nós agora e reformá-los duas vezes — uma para caber loja, outra para
caber piso.

```
Economia ──┐
           ├──> Mapa ──> Save e meta-progressão
Piso ──────┘
```

---

## Fase 1 — Economia e oficina ✅ FEITA

**GDD §4.4, base do §6.4.**

Hoje o desgaste é catraca de mão única: não existe conserto, e a sequência acaba quando o
motor funde. O GDD prevê outra coisa — o carro quebra, a oficina dá um orçamento, e **você
decide se afunda o dinheiro nele**. Sem dinheiro essa decisão não existe.

- Dinheiro ganho por corrida, e **aposta**: valor visível, ganhou leva, perdeu paga.
- Oficina: consertar desgaste, reabastecer nitro, comprar peça, remover peça ruim.
- Orçamento de conserto **pode passar do valor do carro** — é aí que a decisão morde.
- Fim da sequência passa a ser **falência**, não fusão.

**Por que primeiro:** é o menor pedaço que destrava mais coisa, e fecha um buraco que já
existe hoje.

**Pronto quando:** perder drena o dinheiro que consertaria o carro; a espiral de morte
existe e é legível; e o `sim_check` mostra que jogar seguro sobrevive mais tempo mas junta
menos dinheiro que forçar.

**Resultado medido** (média de 12 sequências):

| estilo | corridas | taxa de vitória | consertos | caixa por corrida |
|---|---|---|---|---|
| cauteloso | 24,7 | 57% | 0,0 | 5,8 |
| seletivo | 22,1 | 57% | 0,3 | 4,0 |
| ganancioso | 17,2 | **63%** | 1,0 | **15,2** |
| desleixado | **3,2** | 4% | 0,0 | 5,9 |

Forçar rende 2,6× mais por corrida e vence mais; jogar seguro dura 40% mais corridas; errar
troca leva à falência em três. A falência tem duas portas: motor fundido com orçamento
acima do caixa, ou caixa que não cobre nem a aposta da próxima corrida.

Duas coisas que a medição corrigiu no caminho:
- **Dinheiro não tinha piso.** Quem perdia tudo continuava correndo com caixa zero, para
  sempre. Não se aposta o que não se tem — sem caixa, não há racha.
- **A aposta sozinha é soma zero** e matava a sequência de inanição em meia dúzia de
  corridas. O nó de racha paga um **prêmio** por cima da aposta, como o §6.2 já previa.

---

## Fase 2 — Piso, pneu e turbo

**GDD §5, resto do §3.2, resto do §4.2–4.3.**

Completa a corrida e os 7 slots. Depois disto nenhuma peça do GDD fica sem função.

- **4 pisos** como perfil sobre as 3 fases + calor (não como multiplicador global):
  lama arrasa a fase 1, deserto encolhe a margem térmica, cidade pune as fases 2–3,
  pista é neutra.
- **Pneu** como perfil espelhado, não número: pneu de lama é ótimo na lama e ruim no
  asfalto. Não existe "o melhor pneu".
- **Marca Tração** (a 5ª), que só faz sentido com piso.
- **Turbo**: desloca a curva para a direita, adiciona lag e gera mais calor.
- Desgaste e quebra dos dois: turbo por boost sustentado (perde a banda alta), pneu por
  piso errado (derrapada, ~2s).

**Por que aqui:** o mapa telegrafa o piso de cada nó. Nó que já nasce sabendo de piso custa
menos que nó reformado depois.

**Pronto quando:** o `sim_check` mede que o pneu certo muda a fase 1 de forma sentida, que
o turbo muda a fase 3, e que **nenhum piso é dominante** — se um piso for sempre o melhor,
a escolha de rota nasce morta.

**Risco de arte:** hoje existe **uma** roda genérica. Pneu como slot visível pede arte por
tipo, e cinco carros ainda não têm âncora medida.

---

## Fase 3 — O mapa

**GDD §6 inteiro.** É a espinha, e é o item grande.

- Mapa ramificado, 3 atos, ~8–10 nós por ato.
- Os **7 tipos de nó**: racha comum, rival marcado, oficina, ferro-velho, boxes, evento,
  chefe.
- **Reputação** destrancando o chefe por volta do nó 6, e a decisão de desafiar agora ou
  farmar mais.
- **Telegrafia**: arquétipo do rival, pneu dele e piso do nó, visíveis antes de escolher.
  Números escondidos.
- **Aposta** por nó; nó consumido ao perder.
- **Chefe em melhor de 3**, pisos diferentes, sem reparo entre as corridas.

**Pronto quando:** dá pra jogar uma run inteira do menu ao chefe, e o `sim_check` consegue
simular runs mostrando que **a rota importa** — que escolher os nós certos para a sua build
vence mais que escolher os nós de maior recompensa.

---

## Fase 4 — Save e meta-progressão

**GDD §7, mais o desbloqueio do §3.5 e a expansão do §3.6.**

Precisa da fase 3: sem run, não existe "fim de run" para render progresso.

- Persistência em disco.
- Desbloqueio de acervo: peças, passivos, eventos e carros novos entrando no pool.
- Escada de carros destravando por vitórias.
- Inventário de 2 → 6 por desafios.
- **Derrota também rende progresso**, atrelada a marcos.

**Pronto quando:** fechar o jogo e reabrir mantém o que foi conquistado, e perder uma run
ainda deixa alguma coisa para trás.

---

## Fase 5 — Profundidade

Tudo aqui é opcional para o loop existir, e todo item fica melhor quando já há uma run para
atravessá-lo.

- **Bônus de conjunto** (§3.4) — 3 peças da mesma marca. É o que faz perseguir uma build
  em vez de pegar sempre o número maior. Hoje não há razão para recusar uma Épica de marca
  errada, e isso é um buraco real no sistema de peças.
- **2 itens passivos** (§3.3), comuns percentuais e raros dobrando regra.
- **Formato do tanque de nitro** (§2.3) — 1 longo × 3 curtos.
- **Câmbio automático** (§2.4).

**Exceção de ordem:** o câmbio automático é acessibilidade, não profundidade. Se você quiser
pôr alguém de fora para jogar antes da fase 3, ele sobe para a fase 1 — sem ele, quem não
acerta troca de marcha não consegue avaliar mais nada do jogo.

---

## Dívida que não está no GDD

Coisas que o protótipo acumulou e que não somem sozinhas:

- **Cinco carros sem âncora de roda** — `dodge charger 1970`, `Initial D carro`,
  `lancer evo x`, `mclaren senna`, `mustang dark horse`. Correm sem roda.
- **Escala por carro** — todas as fotos têm o carro preenchendo o quadro, então a Kombi
  sai do tamanho de uma Miata.
- **Potências conferidas de memória** — as versões assumidas estão comentadas no `ROSTER`,
  mas merecem uma conferida de quem conhece os carros.
- **`race.gd` passou de 700 linhas** e concentra estado, fluxo, câmera e mundo. A fase 3
  vai dobrar isso. Vale separar antes, não depois.
