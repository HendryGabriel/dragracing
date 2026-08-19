extends Node3D
## Prototipo de corrida. Greybox: cubos numa reta, sem arte, sem mapa, sem pecas.
## Existe para responder tres perguntas:
##   1. 20 corridas seguidas e voce ainda quer a 21a?
##   2. Da pra SENTIR a diferenca entre torque e alta rotacao em 30s?
##   3. Segurar o nitro ate quase estourar da frio na barriga?

enum State { MENU, STAGING, RACING, RESULT }

const LANE := 4.3          # afastamento lateral de cada carro
const POST_SPACING := 20.0 # m entre postes de referencia

# A camera fica A FRENTE dos carros, baixa, olhando para tras: e por isso que o
# jogador ve a FRENTE do carro, que e o angulo da arte.
#
# CAM_ANGLE e a peca critica: a arte e uma foto em 3/4, entao a PISTA tem que fugir
# na mesma diagonal. Com a camera no eixo da pista o asfalto corre reto para um ponto
# de fuga central e o carro parece atravessado nele. O angulo da camera precisa casar
# com o angulo em que a foto foi tirada.
const CAM_ANGLE_DEG := 38.0  # graus fora do eixo da pista
const CAM_SIDE := -1.0       # lado da camera (-1 = esquerda da pista)
const CAM_Y := 1.15          # altura, quase na linha dos farois
const CAM_DIST := 15.0
const CAM_DIST_MAX := 46.0      # ate onde a camera recua
const CAM_RIVAL_MARGIN := 9.0   # m que o rival mantem a frente da camera
#
# A camera e RIGIDA: sempre o mesmo deslocamento em relacao ao carro do JOGADOR,
# sem trocar de alvo e sem nunca girar. Nao e preferencia, e limite da arte -- a
# carroceria e uma foto parada, entao girar a camera obrigaria o sprite a girar
# junto para continuar encarando ela, e o carro pareceria esterçar numa reta.
# Quando o rival abre, a camera RECUA pelo proprio eixo -- muda so a distancia,
# nunca a direcao. Dollying puro nao gira nada, entao o sprite continua parado.

const ROAD_W := 7.0        # meia largura do asfalto

const CAR_PIXEL_SIZE := 0.0035  # escala da foto -> metros
const CAR_Y := 1.15             # centro do sprite para as rodas tocarem o chao

var state := State.MENU
var player := Car.new()
var rival := Car.new()
var player_profile := "Equilibrado"
var rival_profile := "Equilibrado"

var rev := 0.0             # ponteiro da largada
var revving := false
var ai_shift_point := Tuning.AI_SHIFT_POINT
var cam_dist := CAM_DIST   # recua quando o rival abre; so distancia, nunca angulo
var auto := false          # corrida automatica (checagem end-to-end)
var _shot_atras := true
var _shots: Array = []     # instantes (s) para capturar print no modo --autorace
var flash := ""            # feedback de troca
var flash_t := 0.0
var peak_heat := 0.0

var cam: Camera3D
var car_sprite: Sprite3D
var rival_sprite: Sprite3D
var player_car := "mustang 1969"
var rival_car := "golf gti"
var hud: Hud
var card_title := ""
var card_color := Color.WHITE
var card_lines: Array = []
var card_table: Array = []
var matchup := ""


# ---------------------------------------------------------------- setup

func _ready() -> void:
	_build_world()
	_build_hud()
	_to_menu()
	# corrida automatica para checagem end-to-end:
	#   godot --headless --quit-after 2200 -- --autorace
	if "--autorace" in OS.get_cmdline_user_args():
		auto = true
		_shots = [1.5, 8.0, 20.0, 28.0]
		await get_tree().process_frame
		await _shot_named("menu")
		_start_staging()
		rev = 0.55
		await get_tree().process_frame
		await _shot_named("arvore")
		rev = 0.70
		_start_race()


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.04, 0.05, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.46, 0.55)
	e.ambient_light_energy = 1.1
	e.fog_enabled = true
	e.fog_light_color = Color(0.04, 0.05, 0.07)
	e.fog_density = 0.0035
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_energy = 1.1
	add_child(sun)

	var track_len := Tuning.RACE_DISTANCE + 300.0
	var mid := track_len * 0.5 - 60.0

	# Terreno largo: com a camera em 3/4 ela sai de cima do asfalto, e sem chao
	# embaixo dela a pista flutua no vazio.
	add_child(_box(Vector3(0, -0.45, mid), Vector3(90, 0.5, track_len),
		Color(0.09, 0.10, 0.12)))

	# asfalto
	add_child(_box(Vector3(0, -0.15, mid), Vector3(ROAD_W * 2.0, 0.5, track_len),
		Color(0.16, 0.17, 0.19)))

	# bordas e faixa divisoria: pintura rente ao chao, nao guia. Sao elas que
	# desenham a diagonal da pista.
	for x in [-ROAD_W, 0.0, ROAD_W]:
		var w := 0.22 if x == 0.0 else 0.40
		add_child(_box(Vector3(x, 0.11, mid), Vector3(w, 0.04, track_len),
			Color(0.58, 0.59, 0.63)))

	# postes de referencia -- a leitura de velocidade vem daqui
	var n := int(Tuning.RACE_DISTANCE / POST_SPACING) + 4
	for i in range(n):
		var z := i * POST_SPACING
		var c := Color(0.75, 0.75, 0.78) if i % 5 == 0 else Color(0.32, 0.33, 0.36)
		var h := 2.4 if i % 5 == 0 else 1.3
		add_child(_box(Vector3(-ROAD_W - 1.8, h * 0.5, z), Vector3(0.35, h, 0.35), c))
		add_child(_box(Vector3(ROAD_W + 1.8, h * 0.5, z), Vector3(0.35, h, 0.35), c))

	add_child(_box(Vector3(0, 0.02, 0), Vector3(ROAD_W * 2.0, 0.55, 1.0), Color(0.85, 0.85, 0.9)))
	add_child(_box(Vector3(0, 0.02, Tuning.RACE_DISTANCE), Vector3(ROAD_W * 2.0, 0.6, 2.0),
		Color(0.95, 0.72, 0.15)))
	for side in [-ROAD_W - 0.6, ROAD_W + 0.6]:
		add_child(_box(Vector3(side, 4.0, Tuning.RACE_DISTANCE), Vector3(0.6, 8.0, 0.6),
			Color(0.95, 0.72, 0.15)))

	var dir := cam_dir()
	var yaw := atan2(dir.x, dir.z)
	car_sprite = _car_sprite(Color(0.62, 0.80, 1.0))
	rival_sprite = _car_sprite(Color(1.0, 0.66, 0.58))
	car_sprite.rotation.y = yaw
	rival_sprite.rotation.y = yaw
	add_child(car_sprite)
	add_child(rival_sprite)

	cam = Camera3D.new()
	cam.fov = 78.0
	cam.far = 900.0
	add_child(cam)


func _box(pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	m.material_override = mat
	m.position = pos
	return m


## A carroceria e um sprite de rotacao FIXA, casada com o angulo da camera.
## Billboard faria o carro girar conforme a camera se move -- e foto nao esterça.
func _car_sprite(tint: Color) -> Sprite3D:
	var s := Sprite3D.new()
	s.pixel_size = CAR_PIXEL_SIZE
	# Sem billboard: a rotacao e fixa e casa com o angulo da camera. Billboard
	# faria cada carro girar conforme a camera se move, e foto parada nao esterça.
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.alpha_scissor_threshold = 0.35
	s.modulate = tint
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


# ---------------------------------------------------------------- hud

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)


# ---------------------------------------------------------------- fluxo

func _to_menu() -> void:
	state = State.MENU
	card_title = "ARRANCADA"
	card_color = Hud.TEXT
	card_table = []
	var i := 1
	for name in Tuning.PROFILES:
		var b: Array = Tuning.PROFILES[name]
		card_table.append(["%d" % i, name, "%.0f / %.0f / %.0f" % [b[0], b[1], b[2]],
			Cars.BY_PROFILE.get(name, "?")])
		i += 1
	card_lines = [
		"~a banda decide qual fase da corrida voce ganha",
		"~ESPACO larga e troca   ·   SHIFT nitro   ·   ESC sai",
	]


func _start_staging() -> void:
	state = State.STAGING
	rev = 0.0
	revving = false
	flash = ""
	peak_heat = 0.0

	player = Car.new()
	player.label = "Voce"
	player.bands = Tuning.PROFILES[player_profile]
	player.rng.randomize()

	var names := Tuning.PROFILES.keys()
	rival_profile = names[randi() % names.size()]
	rival = Car.new()
	rival.label = "Rival"
	rival.bands = Tuning.PROFILES[rival_profile]
	rival.rng.randomize()
	rival.set_launch(randf_range(0.58, 0.84))
	ai_shift_point = Tuning.AI_SHIFT_POINT

	player_car = Cars.BY_PROFILE.get(player_profile, Cars.ALL[0])
	rival_car = Cars.random_name(rival.rng)
	car_sprite.texture = Cars.texture(player_car)
	rival_sprite.texture = Cars.texture(rival_car)

	matchup = "%s (%s)   x   %s (%s)" % [player_profile, player_car,
		rival_profile, rival_car]


func _start_race() -> void:
	player.set_launch(rev)
	state = State.RACING
	_set_flash(_launch_verdict(rev))


func _launch_verdict(r: float) -> String:
	var g := Tuning.LAUNCH_GREEN
	if r >= g.x and r <= g.y:
		return "LARGADA PERFEITA"
	elif r < g.x:
		return "AFOGOU"
	return "PATINOU"


## Vitoria e por TEMPO, nunca por posicao: quem cruza primeiro congela a posicao
## em ~1500m e o outro alcanca o mesmo numero, entao comparar pos da empate falso
## -- ou pior, declara vencedor quem perdeu.
func won() -> bool:
	if player.blown:
		return false
	if player.finished_at <= 0.0:
		return false
	if rival.finished_at > 0.0:
		return player.finished_at <= rival.finished_at
	return true


func _to_result() -> void:
	state = State.RESULT
	var venceu := won()
	card_title = "VENCEU" if venceu else "DERROTA"
	card_color = Hud.GREEN if venceu else Hud.RED
	if player.blown:
		card_title = "MOTOR FUNDIDO"
		card_color = Hud.RED
	card_table = []
	card_lines = [
		"%s   %s" % [player_car,
			("%.2fs" % player.finished_at) if player.finished_at > 0 else "nao terminou"],
		"~%s   %s" % [rival_car,
			("%.2fs" % rival.finished_at) if rival.finished_at > 0 else "nao terminou"],
		"trocas perfeitas %d   ·   ruins %d" % [player.perfect_shifts, player.bad_shifts],
		"calor maximo %.0f%%   ·   limite %.0f%%" % [peak_heat * 100, Tuning.HEAT_LIMIT * 100],
		"~R corre de novo   ·   M troca de motor   ·   ESC sai",
	]
	if auto:
		_shot_named("resultado")


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	var k: InputEventKey = event

	if k.pressed and k.keycode == KEY_ESCAPE:
		get_tree().quit()
		return

	match state:
		State.MENU:
			if k.pressed:
				var names := Tuning.PROFILES.keys()
				var idx := [KEY_1, KEY_2, KEY_3].find(k.keycode)
				if idx >= 0 and idx < names.size():
					player_profile = names[idx]
					_start_staging()
		State.STAGING:
			if k.keycode == KEY_SPACE:
				if k.pressed:
					revving = true
				elif revving:
					_start_race()
		State.RACING:
			if k.pressed and k.keycode == KEY_SPACE:
				var q := player.shift_up()
				if q != "":
					_set_flash("TROCA " + q.to_upper() if q != "boa" else "boa")
		State.RESULT:
			if k.pressed and k.keycode == KEY_R:
				_start_staging()
			elif k.pressed and k.keycode == KEY_M:
				_to_menu()


func _set_flash(msg: String) -> void:
	flash = msg
	flash_t = 0.9


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	match state:
		State.STAGING:
			if revving:
				rev = minf(rev + delta * Tuning.LAUNCH_MAX / Tuning.LAUNCH_REV_TIME,
					Tuning.LAUNCH_MAX)
		State.RACING:
			_step_race(delta)

	_update_cars()
	_update_camera(delta)
	_feed_hud(delta)

	# --autorace: prints em momentos-chave para conferir escala e enquadramento
	if auto and _shots.size() > 0 and state == State.RACING and player.time >= _shots[0]:
		_shots.remove_at(0)
		_screenshot()
	# print forcado com o rival na frente: e o unico enquadramento que o recuo
	# existe para resolver, e o rival raramente ganha sozinho na corrida automatica
	if auto and _shot_atras and state == State.RACING and player.time >= 24.0:
		_shot_atras = false
		var guarda := rival.pos
		rival.pos = player.pos + 24.0
		cam_dist = cam_distance_for(24.0)
		_update_cars()
		_update_camera(0.0)
		_feed_hud(0.0)
		await _shot_named("rival_na_frente")
		rival.pos = guarda


func _shot_named(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://tela_%s.png" % nome)
	print("tela_%s.png" % nome)


func _screenshot() -> void:
	var idx := 4 - _shots.size()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot_%d.png" % idx)
	print("shot_%d.png  t=%.1fs  gap=%.1fm" % [idx, player.time, player.pos - rival.pos])


func _step_race(delta: float) -> void:
	if auto and player.rpm() >= 0.96:
		player.shift_up()
	player.nitro_on = Input.is_physical_key_pressed(KEY_SHIFT) \
		or (auto and player.pos > Tuning.RACE_DISTANCE * 0.6 and player.heat < 0.75)
	_drive_ai()
	player.step(delta)
	rival.step(delta)
	peak_heat = maxf(peak_heat, player.heat)

	if player.blown:
		_set_flash("FUNDIU")
		_to_result()
	elif player.finished_at > 0.0 or rival.finished_at > 0.0:
		# deixa o outro cruzar para registrar o tempo, mas no maximo 1.5s
		if player.finished_at > 0.0 and (rival.finished_at > 0.0
				or player.time - player.finished_at > 1.5):
			_to_result()
		elif rival.finished_at > 0.0 and rival.time - rival.finished_at > 1.5:
			_to_result()


func _drive_ai() -> void:
	if rival.rpm() >= ai_shift_point:
		rival.shift_up()
		# pericia imperfeita: o ponto de troca varia a cada marcha
		ai_shift_point = Tuning.AI_SHIFT_POINT + randf_range(-0.10, 0.05)
	rival.nitro_on = rival.nitro > 0.0 \
		and rival.pos > Tuning.RACE_DISTANCE * Tuning.AI_NITRO_FROM \
		and rival.heat < Tuning.AI_HEAT_TARGET


func _update_cars() -> void:
	car_sprite.position = Vector3(-LANE, CAR_Y, player.pos)
	rival_sprite.position = Vector3(LANE, CAR_Y, rival.pos)


## Direcao unitaria da camera em relacao ao carro do jogador. E UNITARIA de
## proposito: recuar vira multiplicar por um escalar, e multiplicar um vetor por
## escalar nao muda direcao nenhuma -- nem o azimute, nem a inclinacao. E isso
## que garante que recuar a camera nao gira o sprite.
static func cam_dir() -> Vector3:
	var ang := deg_to_rad(CAM_ANGLE_DEG)
	return Vector3(CAM_SIDE * sin(ang), (CAM_Y - CAR_Y * 0.95) / CAM_DIST,
		cos(ang)).normalized()


## Distancia da camera dada a vantagem do rival (positiva = rival na frente).
## Precisa ser longa o bastante para o rival caber no quadro com folga, senao ele
## passa POR TRAS da camera e some.
static func cam_distance_for(ahead: float) -> float:
	if ahead <= 0.0:
		return CAM_DIST
	var por_z := (ahead + CAM_RIVAL_MARGIN) / cos(deg_to_rad(CAM_ANGLE_DEG))
	return clampf(por_z, CAM_DIST, CAM_DIST_MAX)


func _update_camera(delta: float) -> void:
	if not cam.is_inside_tree():
		return
	var alvo_dist := cam_distance_for(rival.pos - player.pos)
	cam_dist = lerpf(cam_dist, alvo_dist, 1.0 - exp(-3.0 * delta))

	# Alvo e camera transladam juntos e a camera so desliza pelo proprio eixo:
	# a direcao de visada e identica em qualquer distancia.
	var target := Vector3(-LANE, CAR_Y * 0.95, player.pos)
	cam.global_position = target + cam_dir() * cam_dist
	cam.look_at(target)


func _feed_hud(delta: float) -> void:
	if flash_t > 0.0:
		flash_t -= delta

	var d := {
		"state": int(state),
		"flash": flash,
		"flash_a": clampf(flash_t / 0.5, 0.0, 1.0),
		"t": Time.get_ticks_msec() / 1000.0,
	}
	match state:
		State.RACING:
			d.merge({
				"gear": player.gear,
				"rpm": player.rpm(),
				"speed": player.speed * 3.6,
				"heat": player.heat,
				"heat_limit": Tuning.HEAT_LIMIT,
				"over": player.heat > Tuning.HEAT_LIMIT,
				"nitro": player.nitro / Tuning.NITRO_CAPACITY,
				"gap": player.pos - rival.pos,
				"pos": player.pos,
				"dist": Tuning.RACE_DISTANCE,
				"phase": _phase_name(),
				"perfect_lo": Tuning.PERFECT.x,
				"perfect_hi": Tuning.PERFECT.y,
			})
		State.STAGING:
			d.merge({
				"rev": rev,
				"launch_lo": Tuning.LAUNCH_GREEN.x,
				"launch_hi": Tuning.LAUNCH_GREEN.y,
				"matchup": matchup,
			})
		_:
			d.merge({"title": card_title, "title_color": card_color,
				"lines": card_lines, "table": card_table})
	hud.feed(d)


func _phase_name() -> String:
	if player.gear <= 2:
		return "FASE 1  LARGADA"
	elif player.gear <= 5:
		return "FASE 2  ACELERACAO"
	return "FASE 3  TOPO"
