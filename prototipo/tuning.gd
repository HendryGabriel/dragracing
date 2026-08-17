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

## Perfis de motor: [banda baixa (1a-2a), media (3a-5a), alta (6a-7a)]
## Bandas coladas nas fases: baixa=largada, media=aceleracao, alta=topo.
const PROFILES := {
	"Torque":        [92.0, 78.0, 42.0],
	"Equilibrado":   [76.0, 76.0, 76.0],
	"Alta Rotacao":  [64.0, 76.0, 118.0],
}

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
const HEAT_RATE := 0.20              # calor/s segurando (tanque cheio = 1.20 de calor)
const COOL_RATE := 0.18              # calor/s solto
const HEAT_LIMIT := 0.80             # inicio da faixa vermelha
const HEAT_MAX := 1.15               # funde na hora
const BLOW_ROLL := 0.25              # intervalo do dado (s)
const BLOW_CHANCE := 0.45            # chance/s no topo da faixa vermelha

# ---------- Rival ----------
const AI_SHIFT_POINT := 0.95         # rpm alvo de troca
const AI_HEAT_TARGET := 0.86         # ate onde a IA deixa esquentar
const AI_NITRO_FROM := 0.62          # fracao da pista onde a IA comeca o nitro
