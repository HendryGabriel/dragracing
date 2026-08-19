# Protótipo de corrida

Greybox. Sem arte, sem mapa, sem peças, sem loja. Existe só para responder as três
perguntas do §8.3 do [GDD](../GDD.md) — se qualquer uma falhar, o design muda antes
de qualquer sistema ser construído.

1. Você joga 20 corridas seguidas e ainda quer a 21ª?
2. Dá pra **sentir** a diferença entre torque e alta rotação numa corrida de 30s?
3. Segurar o nitro até quase estourar dá frio na barriga?

## Rodar

O projeto é fixado no **Godot 4.7.1**. Abrir em outra versão reescreve
`config/features` no `project.godot` e suja o histórico. Abra a pasta `prototipo/` e dê
play, ou pela linha de comando:

```bash
godot --path prototipo
```

## Controles

| Tecla | Ação |
|---|---|
| `1` `2` `3` | escolher o motor no menu |
| `ESPAÇO` (segurar/soltar) | largada — solte com o ponteiro na faixa verde |
| `ESPAÇO` (apertar) | trocar de marcha — acerte a faixa verde do giro |
| `SHIFT` (segurar) | nitro — acelera e esquenta o motor |
| `R` | correr de novo · `M` menu · `ESC` sair |

## O que observar

- **Torque** abre vantagem na largada e é engolido no final.
- **Alta Rotação** apanha na saída e ultrapassa por volta dos 79% da pista.
- Passar de **80% de calor** entra na faixa vermelha: o dado começa a rolar. Fundiu, é DNF.
- Nitro conservador (parar antes dos 80%) rende ~0,4s **sem risco**. Ir além é aposta.

## Carros

As carrocerias ficam em [`cars/`](cars/) — 25 fotos em 3/4 frontal, brancas (tingidas
por `modulate`, então uma imagem serve para qualquer cor) e **sem rodas**.

A câmera fica **à frente dos carros olhando para trás**, que é por isso que você vê a
frente do carro: é o ângulo em que a arte foi produzida.

Ela é **rígida e presa ao jogador** — nunca gira, nunca troca de alvo, e o sprite tem
rotação fixa em vez de billboard. Foto parada não pode esterçar: se a câmera girasse, o
sprite giraria junto para encará-la e o carro pareceria fazer curva numa reta.

Quando o rival abre, ela **recua pelo próprio eixo** para mantê-lo no quadro — só
distância, nunca ângulo, então nada gira. `CAM_RIVAL_MARGIN` é a folga que o rival mantém
à frente da câmera e `CAM_DIST_MAX` é o teto do recuo; passado ele o rival sai do quadro e
a leitura fica com o indicador de gap.

`CAM_ANGLE_DEG` (38°) é a constante mais delicada do render: como a foto é 3/4, a pista
precisa fugir na mesma diagonal. Com a câmera no eixo da pista o asfalto corre reto e o
carro parece andar de lado. `CAM_SIDE = -1` põe a câmera à esquerda da pista, o que
faz a corrida correr da **direita para a esquerda**. A arte entra sem espelhamento: espelhar
inverteria emblemas, placas e decalques.

Carro novo: jogue o `.png` em `cars/` e adicione o nome (sem extensão) em
[`cars.gd`](cars.gd). A lista é explícita de propósito — varrer `res://` com `DirAccess`
se comporta diferente no editor e no build exportado.

**Confira para que lado o bico aponta.** As fotos não vêm todas do mesmo lado: 21
apontam para a direita e 4 para a esquerda (`kombi`, `civic`, `bmw m3`,
`subaru impreza`). As da esquerda entram em `Cars.FLIP` e são espelhadas em tempo de
execução, senão correm de costas. Espelhar inverte os emblemas delas — incômodo bem
menor que um carro andando de ré.

> **Falta escala por carro.** Todas as fotos têm o carro preenchendo o quadro, então
> `CAR_PIXEL_SIZE` único faz a Kombi sair do tamanho de uma Miata. Precisa de um fator
> de escala por carroceria, calibrado no olho.

> **Falta a arte de roda.** As caixas de roda estão vazias nas fotos, e isso é
> intencional: Roda é um slot de equipamento e a arte entra composta por cima. Enquanto
> ela não existe, os carros correm sem roda. Precisa de PNGs de pneu/roda com o mesmo
> ângulo 3/4 e um ponto de ancoragem por carroceria.

## Interface

O HUD vive em [`hud.gd`](hud.gd), desenhado em modo imediato (`_draw`), alimentado por
`race.gd` a cada quadro via `feed()`. Não há árvore de nós de UI: um `Control` só.

A assinatura é a **árvore de largada**. A mesma lâmpada aparece nos três momentos de
timing do jogo — árvore na largada, régua de giro na corrida, e a régua inteira acende
verde dentro da janela de troca. Paleta quente, recortes chanfrados, e o nitro como
único elemento frio (o oposto do calor). Fonte: Bahnschrift, via `SystemFont`.

## Ajustar

Todos os números vivem em [`tuning.gd`](tuning.gd). Edite, salve, rode de novo.
Os mais sensíveis:

| Constante | Efeito |
|---|---|
| `K` / `DRAG` | duração da corrida e teto de velocidade da fase 3 |
| `GEAR_TOP` | onde cada marcha corta. A 7ª é overdrive longa de propósito: o carro **nunca** bate no corte nela, senão o nitro não teria o que empurrar |
| `PROFILES` | as três curvas de banda. Mexer aqui muda quem lidera cada fase |
| `HEAT_RATE` / `BLOW_CHANCE` | quão assustadora é a fase 3 |

## Checagem

```bash
godot --headless --path prototipo --script res://sim_check.gd
```

Valida quatro coisas e sai com código de erro se alguma quebrar:

1. a corrida dura entre 27s e 33s nos três perfis;
2. o torque abre vantagem visível cedo **e** a alta rotação ultrapassa entre 55% e 95%
   da pista — se a liderança não trocar de mão, o sistema de bandas não existe de fato;
3. o nitro conservador rende ganho mensurável — se não render, a fase 3 não tem decisão;
4. a cena roda uma corrida inteira até a tela de resultado sem quebrar.

Corrida real end-to-end, sem interação:

```bash
godot --headless --path prototipo --quit-after 2400 -- --autorace
```

## Sequência de corridas (§4 do GDD)

As corridas encadeiam e o desgaste **persiste**: forçar o calor ganha a corrida de agora e
cobra na de depois. Motor gasta acima do limite térmico; câmbio gasta a cada troca errada.
Nenhum dos dois perde desempenho ao gastar — o que sobe é a chance de estourar, e o dado só
é rolado no momento do estresse. Quem joga limpo nunca quebra nada.

Sem oficina ainda (depende de economia), então não há conserto: a sequência acaba quando o
motor funde, e o placar é quantas corridas você venceu antes disso.

`sim_check` simula sequências inteiras por estilo de jogo, que é como as constantes de
desgaste foram calibradas:

| estilo | corridas até fundir | vitórias |
|---|---|---|
| cauteloso (nunca passa do limite) | nunca funde | 0 |
| **seletivo** (força 1 em 3) | **~28** | **~9** |
| ganancioso (força sempre) | ~8 | ~7 |
| desleixado (erra trocas) | nunca funde | 0, câmbio a 100% |

Seguro sobrevive e não vence; ganancioso vence quase tudo e morre cedo; forçar
seletivamente aguenta uma run inteira. É esse o formato que o §4 do GDD pede.

## Fora do escopo (de propósito)

Turbo e pneu (dependem de pisos e de peças), pisos, câmbio automático, mapa, loja,
inventário, meta-progressão, economia e conserto. Tudo isso está desenhado no GDD e só vale
construir depois que as três perguntas do §8.3 tiverem resposta jogando.
