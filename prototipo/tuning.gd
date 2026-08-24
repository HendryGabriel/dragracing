class_name Tuning
## Todos os numeros do prototipo vivem aqui. Edite, salve, rode de novo.

# ---------- Corrida ----------
const RACE_DISTANCE := 1500.0        # m
const GEARS := 7
## Velocidade (m/s) em que cada marcha atinge o corte de giro.
## A 7a e uma overdrive longa de proposito: o carro NUNCA bate no corte nela.
## O teto da fase 3 e o arrasto, nao o limitador -- so assim o nitro tem o que empurrar.
const GEAR_TOP := [14.0, 25.0, 36.0, 47.0, 58.0, 72.0, 100.0]

# ---------- Motor ----------
const K := 200.0                     # ganho global de aceleracao
const DRAG := 0.00020                # arrasto ~ v^2 (define o teto da fase 3)
const PEAK_RPM := 0.72               # onde o torque e maximo (0..1 da faixa da marcha)
const CURVE_WIDTH := 2.2             # quanto mais alto, mais estreita a curva
const LIMITER := 0.20                # multiplicador acima do corte

# ---------- Troca de marcha ----------
const PERFECT := Vector2(0.90, 1.02) # janela verde
const GOOD := Vector2(0.78, 1.10)
const SHIFT_TIME_PERFECT := 0.07
const SHIFT_TIME_GOOD := 0.16
const SHIFT_TIME_BAD := 0.32
const BAD_SHIFT_SPEED_LOSS := 0.04   # perde 4% da velocidade

# ---------- Largada ----------
const LAUNCH_REV_TIME := 2.2         # s para o ponteiro ir de 0 ao maximo
const LAUNCH_MAX := 1.3
const LAUNCH_GREEN := Vector2(0.62, 0.80)
const LAUNCH_BEST := 1.28
const LAUNCH_WORST := 0.62
const LAUNCH_DURATION := 3.0         # s de influencia da largada

# ---------- Nitro / calor ----------
const NITRO_CAPACITY := 6.0          # segundos de tanque
const NITRO_BOOST := 1.75
## Acima do limite termico o nitro empurra MAIS. Sem isto, a faixa vermelha e so
## risco sem premio e ninguem entra nela por vontade propria -- o que mata a
## decisao central da fase 3.
const OVERBOOST := 0.40
## Tanque dividido: o mesmo nitro em tres garrafas. Nao muda o empurrao -- muda
## QUANDO voce pode dar. Cada acionamento vale uma garrafa, e a proxima so depois
## de soltar, o que impede o mergulho unico no overboost.
const GARRAFAS := 3
## Tempo morto entre uma garrafa e a proxima. E o preco do formato: o empurrao
## vem em tres pedacos, com dois buracos no meio -- e o motor esfria neles.
const GARRAFA_TROCA := 0.5
const HEAT_RATE := 0.20              # calor/s segurando (tanque cheio = 1.20 de calor)
const COOL_RATE := 0.18              # calor/s solto
const HEAT_LIMIT := 0.80             # inicio da faixa vermelha
const HEAT_MAX := 1.15               # funde na hora
const BLOW_ROLL := 0.25              # intervalo do dado (s)
const BLOW_CHANCE := 0.08            # chance/s no topo da faixa vermelha

# ---------- Desgaste (GDD 4) ----------
# Regra unica: a acao que gasta e a acao que pode quebrar. Nenhuma peca perde
# desempenho por estar gasta -- o que sobe e a chance de estourar, e o dado so e
# rolado no momento do estresse. Jogar limpo quase nao gasta.

## Motor: gasta enquanto voce mantem o calor acima do limite.
const MOTOR_WEAR := 0.014             # desgaste/s acima da faixa vermelha
## Multiplicador de risco por estado: motor novo e bem mais seguro que gasto.
const MOTOR_RISK_NOVO := 0.10
const MOTOR_RISK_GASTO := 4.00

## Transmissao: gasta a cada troca ERRADA, e so pode quebrar nesse instante.
const TRANS_WEAR := 0.07             # desgaste por troca ruim
const TRANS_BREAK := 0.40            # chance de quebrar na troca ruim, x desgaste

## Turbo: gasta pelo TEMPO em boost sustentado, e so pode quebrar enquanto voce
## esta segurando. Quebrado, a banda alta some -- a fase 3 morre.
const TURBO_WEAR := 0.030            # desgaste/s de boost
const TURBO_BREAK := 0.10            # chance/s no boost, x desgaste
const TURBO_QUEBRADO := 0.35         # o que sobra da banda alta

## Pneu: gasta por PISO ERRADO, e so na largada, que e onde ele decide. Estourado,
## derrapa e custa velocidade -- da para terminar, e as vezes ate ganhar.
const PNEU_WEAR := 0.55              # desgaste/s de largada com pneu errado
const PNEU_BREAK := 0.45             # chance/s na largada, x desgaste x erro
const PNEU_ESTOURO_PERDA := 0.42     # fracao da velocidade perdida na derrapada

## Faixas de estado, so para leitura -- nao mudam desempenho.
const FAIXA_GASTA := 0.34
const FAIXA_CRITICA := 0.70

# ---------- Economia (GDD 4.4 e 6.4) ----------
# Sem dinheiro nao existe conserto, e sem conserto o desgaste vira catraca de mao
# unica. E o dinheiro que transforma "o carro quebrou" em decisao: a oficina da um
# orcamento e voce escolhe se afunda a grana nele.
const DINHEIRO_INICIAL := 260

## Valor do carro, base do orcamento de conserto. Sai da potencia de fabrica.
const VALOR_BASE := 180
const VALOR_POR_CV := 2

## Fracao do valor do carro que custa cada conserto.
const CONSERTO_MOTOR := 0.55           # x desgaste, quando so gasto
const CONSERTO_CAMBIO := 0.30
## Peca QUEBRADA custa mais que gasta -- e motor fundido custa mais que o carro
## inteiro vale. E esse numero que faz a decisao doer.
const CONSERTO_MOTOR_QUEBRADO := 1.15
const CONSERTO_CAMBIO_QUEBRADO := 0.45
const CUSTO_NITRO_SEG := 6             # por segundo de tanque faltando

## Aposta do racha. Cresce com a sequencia: perder tarde dói mais que perder cedo.
const APOSTA_BASE := 70
const APOSTA_POR_CORRIDA := 11

## Premio, pago so na vitoria e por cima da aposta (GDD 6.2: o no de racha da
## dinheiro, nao so a aposta de volta). Sem ele a aposta e um jogo de soma zero e
## a sequencia morre de inanicao em meia duzia de corridas, sem nunca chegar perto
## de uma quebra.
const PREMIO_BASE := 45
const PREMIO_POR_CORRIDA := 8

# ---------- Mapa (GDD 6) ----------
## Reputacao por vitoria. Rival marcado paga muito mais: e o no que voce NAO
## precisa pegar, e e onde as runs boas e as mortas se separam.
const REPUTACAO_RACHA := 2
const REPUTACAO_MARCADO := 5
## Aposta do rival marcado, alta de proposito.
const APOSTA_MARCADO := 2.2

# ---------- Rival ----------
const AI_SHIFT_POINT := 0.95         # rpm alvo de troca
const AI_HEAT_TARGET := 0.86         # ate onde a IA deixa esquentar
const AI_NITRO_FROM := 0.62          # fracao da pista onde a IA comeca o nitro
