class_name Car
extends RefCounted
## Simulacao 1D de um carro de arrancada. Sem fisica de veiculo: posicao escalar
## numa reta, aceleracao derivada da banda de potencia da marcha atual.

var label := "Player"
var bands: Array = [70.0, 70.0, 70.0]

var pos := 0.0
var speed := 0.0
var gear := 1
var heat := 0.0
var nitro := Tuning.NITRO_CAPACITY
var nitro_on := false
var blown := false
var finished_at := -1.0
var time := 0.0

var launch_mult := 1.0
var shift_lock := 0.0
var last_shift := ""
var last_shift_at := -9.0
var perfect_shifts := 0
var bad_shifts := 0

var rng := RandomNumberGenerator.new()
var _roll_t := 0.0


func band_power() -> float:
	if gear <= 2:
		return bands[0]
	elif gear <= 5:
		return bands[1]
	return bands[2]


func band_name() -> String:
	if gear <= 2:
		return "BAIXA"
	elif gear <= 5:
		return "MEDIA"
	return "ALTA"


## 0..1 dentro da faixa da marcha; acima de 1.0 esta no corte.
func rpm() -> float:
	return speed / Tuning.GEAR_TOP[gear - 1]


func torque_shape(r: float) -> float:
	var s := 1.0 - Tuning.CURVE_WIDTH * pow(r - Tuning.PEAK_RPM, 2.0)
	s = clampf(s, 0.30, 1.0)
	if r > 1.0:
		s *= Tuning.LIMITER
	return s


## Retorna a qualidade da troca: "PERFEITA", "boa", "RUIM" ou "" se ignorada.
func shift_up() -> String:
	if gear >= Tuning.GEARS or shift_lock > 0.0 or blown or finished_at >= 0.0:
		return ""
	var r := rpm()
	if r >= Tuning.PERFECT.x and r <= Tuning.PERFECT.y:
		last_shift = "PERFEITA"
		shift_lock = Tuning.SHIFT_TIME_PERFECT
		perfect_shifts += 1
	elif r >= Tuning.GOOD.x and r <= Tuning.GOOD.y:
		last_shift = "boa"
		shift_lock = Tuning.SHIFT_TIME_GOOD
	else:
		last_shift = "RUIM"
		shift_lock = Tuning.SHIFT_TIME_BAD
		speed *= 1.0 - Tuning.BAD_SHIFT_SPEED_LOSS
		bad_shifts += 1
	gear += 1
	last_shift_at = time
	return last_shift


## rev: 0..LAUNCH_MAX, o ponto onde o jogador soltou o botao.
func set_launch(rev: float) -> void:
	var g := Tuning.LAUNCH_GREEN
	var q := 1.0
	if rev < g.x:
		q = clampf(1.0 - (g.x - rev) / 0.45, 0.0, 1.0)
	elif rev > g.y:
		q = clampf(1.0 - (rev - g.y) / 0.45, 0.0, 1.0)
	launch_mult = lerpf(Tuning.LAUNCH_WORST, Tuning.LAUNCH_BEST, q)


func step(dt: float) -> void:
	if finished_at >= 0.0:
		return
	time += dt
	if shift_lock > 0.0:
		shift_lock -= dt

	var a := 0.0
	if not blown and shift_lock <= 0.0:
		a = Tuning.K * (band_power() / 100.0) * torque_shape(rpm()) / Tuning.GEAR_TOP[gear - 1]
		if time < Tuning.LAUNCH_DURATION:
			var w := 1.0 - time / Tuning.LAUNCH_DURATION
			a *= lerpf(1.0, launch_mult, w)

	if nitro_on and nitro > 0.0 and not blown:
		a *= Tuning.NITRO_BOOST
		nitro = maxf(0.0, nitro - dt)
		heat += Tuning.HEAT_RATE * dt
	else:
		heat -= Tuning.COOL_RATE * dt
	heat = clampf(heat, 0.0, 2.0)

	# Risco termico: o dado so e rolado enquanto voce esta forcando.
	if not blown:
		if heat >= Tuning.HEAT_MAX:
			blown = true
		elif heat > Tuning.HEAT_LIMIT:
			_roll_t += dt
			while _roll_t >= Tuning.BLOW_ROLL:
				_roll_t -= Tuning.BLOW_ROLL
				var f := (heat - Tuning.HEAT_LIMIT) / (Tuning.HEAT_MAX - Tuning.HEAT_LIMIT)
				if rng.randf() < Tuning.BLOW_CHANCE * f * Tuning.BLOW_ROLL:
					blown = true
					break

	a -= Tuning.DRAG * speed * speed
	speed = maxf(0.0, speed + a * dt)
	pos += speed * dt
	if pos >= Tuning.RACE_DISTANCE:
		finished_at = time
