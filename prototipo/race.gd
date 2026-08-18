extends Node3D
## Prototipo de corrida. Greybox: cubos numa reta, sem arte, sem mapa, sem pecas.
## Existe para responder tres perguntas:
##   1. 20 corridas seguidas e voce ainda quer a 21a?
##   2. Da pra SENTIR a diferenca entre torque e alta rotacao em 30s?
##   3. Segurar o nitro ate quase estourar da frio na barriga?

enum State { MENU, STAGING, RACING, RESULT }

const LANE := 4.3          # afastamento lateral de cada carro
const DUAL_GAP := 14.0     # m -- ate aqui a camera enquadra os dois
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
const CAM_DIST_DUAL := 15.0
const CAM_DIST_SOLO := 14.0
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
var auto := false          # corrida automatica (checagem end-to-end)
var _shots: Array = []     # instantes (s) para capturar print no modo --autorace
var flash := ""            # feedback de troca
var flash_t := 0.0
var peak_heat := 0.0

var cam: Camera3D
var car_sprite: Sprite3D
var rival_sprite: Sprite3D
var player_car := "mustang 1969"
var rival_car := "golf gti"
var hud: Dictionary = {}


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
		_start_staging()
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

	car_sprite = _car_sprite(Color(0.62, 0.80, 1.0))
	rival_sprite = _car_sprite(Color(1.0, 0.66, 0.58))
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


## A carroceria e um sprite: a arte e foto 3/4 frontal, entao o carro sempre
## apresenta a frente para a camera (billboard travado no eixo Y, para nao deitar).
func _car_sprite(tint: Color) -> Sprite3D:
	var s := Sprite3D.new()
	s.pixel_size = CAR_PIXEL_SIZE
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.alpha_scissor_threshold = 0.35
	s.modulate = tint
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


# ---------------------------------------------------------------- hud

func _label(size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	return l


func _rect(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	hud.root = root

	# --- barra de giro (tambem serve de ponteiro de largada) ---
	var bar_w := 620.0
	var bg := _rect(Color(0, 0, 0, 0.55))
	bg.position = Vector2(-bar_w * 0.5, -170)
	bg.size = Vector2(bar_w, 46)
	bg.anchor_left = 0.5
	bg.anchor_right = 0.5
	bg.anchor_top = 1.0
	bg.anchor_bottom = 1.0
	root.add_child(bg)
	hud.rpm_bg = bg

	hud.rpm_green = _rect(Color(0.25, 0.95, 0.4, 0.35))
	bg.add_child(hud.rpm_green)
	hud.rpm_fill = _rect(Color(0.9, 0.9, 0.95, 0.9))
	bg.add_child(hud.rpm_fill)

	hud.gear = _label(72, Color(1, 1, 1))
	hud.gear.position = Vector2(-bar_w * 0.5 - 110, -215)
	hud.gear.anchor_left = 0.5
	hud.gear.anchor_top = 1.0
	root.add_child(hud.gear)

	hud.speed = _label(38, Color(0.85, 0.9, 1.0))
	hud.speed.position = Vector2(bar_w * 0.5 + 20, -190)
	hud.speed.anchor_left = 0.5
	hud.speed.anchor_top = 1.0
	root.add_child(hud.speed)

	# --- calor ---
	hud.heat_bg = _rect(Color(0, 0, 0, 0.55))
	hud.heat_bg.position = Vector2(-360, -110)
	hud.heat_bg.size = Vector2(340, 30)
	hud.heat_bg.anchor_left = 1.0
	hud.heat_bg.anchor_right = 1.0
	hud.heat_bg.anchor_top = 1.0
	hud.heat_bg.anchor_bottom = 1.0
	root.add_child(hud.heat_bg)
	hud.heat_fill = _rect(Color(1, 0.6, 0.15))
	hud.heat_bg.add_child(hud.heat_fill)
	hud.heat_mark = _rect(Color(1, 0.2, 0.15))
	hud.heat_mark.size = Vector2(3, 30)
	hud.heat_mark.position = Vector2(340 * Tuning.HEAT_LIMIT / 1.15, 0)
	hud.heat_bg.add_child(hud.heat_mark)

	hud.heat_label = _label(20, Color(1, 0.75, 0.4))
	hud.heat_label.position = Vector2(-360, -138)
	hud.heat_label.anchor_left = 1.0
	hud.heat_label.anchor_top = 1.0
	root.add_child(hud.heat_label)

	# --- nitro ---
	hud.nitro_bg = _rect(Color(0, 0, 0, 0.55))
	hud.nitro_bg.position = Vector2(-360, -72)
	hud.nitro_bg.size = Vector2(340, 22)
	hud.nitro_bg.anchor_left = 1.0
	hud.nitro_bg.anchor_right = 1.0
	hud.nitro_bg.anchor_top = 1.0
	hud.nitro_bg.anchor_bottom = 1.0
	root.add_child(hud.nitro_bg)
	hud.nitro_fill = _rect(Color(0.3, 0.8, 1.0))
	hud.nitro_bg.add_child(hud.nitro_fill)

	# --- gap, fase, flash ---
	hud.gap = _label(46, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	hud.gap.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hud.gap.position = Vector2(-200, 24)
	hud.gap.size = Vector2(400, 60)
	root.add_child(hud.gap)

	hud.phase = _label(22, Color(0.7, 0.75, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	hud.phase.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hud.phase.position = Vector2(-250, 82)
	hud.phase.size = Vector2(500, 40)
	root.add_child(hud.phase)

	hud.flash = _label(52, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	hud.flash.set_anchors_preset(Control.PRESET_CENTER)
	hud.flash.position = Vector2(-300, -140)
	hud.flash.size = Vector2(600, 70)
	root.add_child(hud.flash)

	# --- painel de texto (menu / staging / resultado) ---
	var panel := _rect(Color(0, 0, 0, 0.78))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)
	hud.panel = panel

	hud.panel_text = _label(28, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	hud.panel_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.panel_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(hud.panel_text)


# ---------------------------------------------------------------- fluxo

func _to_menu() -> void:
	state = State.MENU
	var t := "[ PROTOTIPO DE ARRANCADA ]\n\nEscolha o motor:\n\n"
	var i := 1
	for name in Tuning.PROFILES:
		var b: Array = Tuning.PROFILES[name]
		t += "  [%d]  %-14s  baixa %3.0f / media %3.0f / alta %3.0f    %s\n" \
			% [i, name, b[0], b[1], b[2], Cars.BY_PROFILE.get(name, "?")]
		i += 1
	t += "\nbaixa = largada (1a-2a)   media = aceleracao (3a-5a)   alta = topo (6a-7a)\n"
	t += "\nESPACO segura/solta = largada e troca de marcha    SHIFT = nitro\nR = repetir    ESC = sair"
	hud.panel_text.text = t
	hud.panel.visible = true


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

	hud.panel_text.text = "%s  (%s)\nx\n%s  (%s)\n\nSEGURE ESPACO para subir o giro.\nSOLTE na faixa verde para largar." \
		% [player_profile, player_car, rival_profile, rival_car]
	hud.panel.visible = true


func _start_race() -> void:
	player.set_launch(rev)
	state = State.RACING
	hud.panel.visible = false
	_set_flash(_launch_verdict(rev))


func _launch_verdict(r: float) -> String:
	var g := Tuning.LAUNCH_GREEN
	if r >= g.x and r <= g.y:
		return "LARGADA PERFEITA"
	elif r < g.x:
		return "AFOGOU"
	return "PATINOU"


func _to_result() -> void:
	state = State.RESULT
	var venceu := player.pos >= rival.pos and not player.blown
	var t := "VOCE VENCEU" if venceu else "DERROTA"
	if player.blown:
		t = "MOTOR FUNDIDO  -  DNF"
	t += "\n\n%s (%s)  %s\n%s (%s)  %s\n" % [
		player_profile, player_car,
		("%.2fs" % player.finished_at) if player.finished_at > 0 else "---",
		rival_profile, rival_car,
		("%.2fs" % rival.finished_at) if rival.finished_at > 0 else "---"]
	t += "\ntrocas perfeitas: %d    trocas ruins: %d" % [player.perfect_shifts, player.bad_shifts]
	t += "\ncalor maximo: %.0f%%   (limite %.0f%%)" % [peak_heat * 100, Tuning.HEAT_LIMIT * 100]
	t += "\nnitro restante: %.1fs" % player.nitro
	t += "\n\nR = correr de novo    M = trocar motor    ESC = sair"
	hud.panel_text.text = t
	hud.panel.visible = true


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
	_update_hud(delta)

	# --autorace: prints em momentos-chave para conferir escala e enquadramento
	if auto and _shots.size() > 0 and state == State.RACING and player.time >= _shots[0]:
		_shots.remove_at(0)
		_screenshot()


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


func _update_camera(delta: float) -> void:
	if not cam.is_inside_tree():
		return
	var gap: float = player.pos - rival.pos
	var dual: bool = absf(gap) <= DUAL_GAP and state != State.MENU
	var dist: float = CAM_DIST_DUAL if dual else CAM_DIST_SOLO

	# A frente dos carros, olhando para tras: os carros vem em cima da camera.
	# A camera se ancora no LIDER, nunca no jogador: ancorada no jogador, um rival
	# que abre mais que a distancia da camera a ultrapassa e some do quadro.
	# Ancorada no lider, quem esta atras aparece menor e mais longe -- a propria
	# perspectiva vira leitura de quem esta ganhando.
	var anchor: float = maxf(player.pos, rival.pos)
	var target := Vector3(0.0 if dual else -LANE * 0.55, CAR_Y * 0.95, anchor)

	var ang := deg_to_rad(CAM_ANGLE_DEG)
	var want := Vector3(
		target.x + CAM_SIDE * sin(ang) * dist,
		CAM_Y,
		anchor + cos(ang) * dist)
	var k: float = 1.0 - exp(-6.0 * delta)
	cam.global_position = cam.global_position.lerp(want, k)
	cam.look_at(target)


func _update_hud(delta: float) -> void:
	var racing := state == State.RACING
	var staging := state == State.STAGING
	for key in ["gear", "speed", "heat_bg", "heat_label", "nitro_bg", "gap", "phase"]:
		hud[key].visible = racing
	hud.rpm_bg.visible = racing or staging

	# barra: giro na corrida, ponteiro de largada no staging
	if racing or staging:
		var w: float = hud.rpm_bg.size.x
		var range_max := 1.15 if racing else Tuning.LAUNCH_MAX
		var green: Vector2 = Tuning.PERFECT if racing else Tuning.LAUNCH_GREEN
		var val: float = clampf(player.rpm(), 0.0, range_max) if racing else rev
		hud.rpm_green.position = Vector2(w * green.x / range_max, 0)
		hud.rpm_green.size = Vector2(w * (green.y - green.x) / range_max, hud.rpm_bg.size.y)
		hud.rpm_fill.size = Vector2(w * val / range_max, hud.rpm_bg.size.y)
		var hot: bool = val >= green.x and val <= green.y
		hud.rpm_fill.color = Color(0.35, 1.0, 0.45, 0.95) if hot else Color(0.9, 0.9, 0.95, 0.85)

	if racing:
		hud.gear.text = str(player.gear)
		hud.speed.text = "%.0f km/h" % (player.speed * 3.6)

		var h: float = clampf(player.heat / 1.15, 0.0, 1.0)
		hud.heat_fill.size = Vector2(hud.heat_bg.size.x * h, hud.heat_bg.size.y)
		var over: bool = player.heat > Tuning.HEAT_LIMIT
		hud.heat_fill.color = Color(1.0, 0.18, 0.12) if over else Color(1.0, 0.62, 0.16)
		hud.heat_label.text = "CALOR %.0f%%%s" % [player.heat * 100,
			"   RISCO DE FUNDIR" if over else ""]
		hud.heat_label.add_theme_color_override("font_color",
			Color(1, 0.25, 0.2) if over else Color(1, 0.75, 0.4))

		hud.nitro_fill.size = Vector2(
			hud.nitro_bg.size.x * (player.nitro / Tuning.NITRO_CAPACITY), hud.nitro_bg.size.y)

		var gap: float = player.pos - rival.pos
		hud.gap.text = "%+.1f m" % gap
		hud.gap.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.5) if gap >= 0 else Color(1.0, 0.45, 0.4))

		var fase := "FASE 1  LARGADA" if player.gear <= 2 \
			else ("FASE 2  ACELERACAO" if player.gear <= 5 else "FASE 3  TOPO")
		hud.phase.text = "%s   ·   banda %s   ·   %.0f / %.0f m" \
			% [fase, player.band_name(), player.pos, Tuning.RACE_DISTANCE]

	if flash_t > 0.0:
		flash_t -= delta
		hud.flash.text = flash
		hud.flash.modulate.a = clampf(flash_t / 0.5, 0.0, 1.0)
	else:
		hud.flash.text = ""
