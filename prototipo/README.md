# Protótipo de corrida

Greybox. Sem arte, sem mapa, sem peças, sem loja. Existe só para responder as três
perguntas do §8.3 do [GDD](../GDD.md) — se qualquer uma falhar, o design muda antes
de qualquer sistema ser construído.

1. Você joga 20 corridas seguidas e ainda quer a 21ª?
2. Dá pra **sentir** a diferença entre torque e alta rotação numa corrida de 30s?
3. Segurar o nitro até quase estourar dá frio na barriga?

## Rodar

Abra a pasta `prototipo/` no Godot 4.7.1 e dê play. Ou pela linha de comando:

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

`CAM_ANGLE_DEG` (38°) é a constante mais delicada do render: como a foto é 3/4, a pista
precisa fugir na mesma diagonal. Com a câmera no eixo da pista o asfalto corre reto e o
carro parece andar de lado. `CAM_SIDE = -1` põe a câmera à esquerda da pista, o que
faz a corrida correr da **direita para a esquerda**. A arte entra sem espelhamento: espelhar
inverteria emblemas, placas e decalques.

Carro novo: jogue o `.png` em `cars/` e adicione o nome (sem extensão) em
[`cars.gd`](cars.gd). A lista é explícita de propósito — varrer `res://` com `DirAccess`
se comporta diferente no editor e no build exportado.

> **Falta escala por carro.** Todas as fotos têm o carro preenchendo o quadro, então
> `CAR_PIXEL_SIZE` único faz a Kombi sair do tamanho de uma Miata. Precisa de um fator
> de escala por carroceria, calibrado no olho.

> **Falta a arte de roda.** As caixas de roda estão vazias nas fotos, e isso é
> intencional: Roda é um slot de equipamento e a arte entra composta por cima. Enquanto
> ela não existe, os carros correm sem roda. Precisa de PNGs de pneu/roda com o mesmo
> ângulo 3/4 e um ponto de ancoragem por carroceria.

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

## Fora do escopo (de propósito)

Desgaste de peças, quebra graduada, pisos, pneus, câmbio automático, mapa, loja,
inventário, meta-progressão. Tudo isso está desenhado no GDD e só vale construir
depois que as três perguntas acima tiverem resposta.
