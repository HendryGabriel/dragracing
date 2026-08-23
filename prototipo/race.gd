extends Node3D
## Prototipo de corrida. Sequencia de corridas com pecas e desgaste; sem mapa,
## sem loja e sem economia ainda.
## Existe para responder tres perguntas:
##   1. 20 corridas seguidas e voce ainda quer a 21a?
##   2. Da pra SENTIR a diferenca entre torque e alta rotacao em 30s?
##   3. Segurar o nitro ate quase estourar da frio na barriga?

enum State { MENU, STAGING, RACING, RESULT, OFERTA, GARAGEM, MAPA }

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
const MENU_CAM_DIST := 9.0      # vitrine: camera perto do carro
## Lente mais fechada so na vitrine. Os 78 graus da corrida sao grande-angular --
## bons para sensacao de velocidade, pessimos para retratar um carro parado.
const MENU_FOV := 46.0
const RACE_FOV := 78.0
const MENU_DESLOC_X := 1.9      # mira ao lado, para o carro cair a direita
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
var garagem := Garagem.new()
var build := Build.new()
var ofertas: Array = []
var card_w := 606.0
var card_table_w := 486.0
var card_cols: Array = [0.0, 34.0, 190.0, 344.0]
var card_head: Array = ["", "motor", "baixa / media / alta", "carro"]
var card_cols_dim: Array = [2, 3]
var garagem_aviso := ""
var menu_idx := 0
## O piso do PROXIMO trecho e sorteado na garagem, nao na largada: so assim
## escolher pneu e decisao em vez de loteria (GDD 5, "piso telegrafado no mapa").
var proximo_piso := "pista"
var piso_rng := RandomNumberGenerator.new()
var piso_pendente := true
var progresso := Progresso.new()
var mapa := Mapa.new()
var sel_no := 0
var no_tipo := "racha"      # tipo do no em que voce entrou
var rival_forcado := ""     # o no manda o rival; vazio = sorteio livre
var ofertas_pagas := false  # oficina cobra; ferro-velho e de graca porem gasto
## Chefe: melhor de 3, em tres pisos diferentes e SEM reparo entre elas (GDD 6.5).
## E aqui que tudo que a run construiu e cobrado de uma vez -- build, estado das
## pecas, escolha de pneu reserva e disciplina para nao forcar calor.
var chefe_placar := [0, 0]
var chefe_pisos: Array = []
var novidade := ""   # ultimo desbloqueio, mostrado na garagem
## Onde ficam as caixas de roda em cada foto, medidas por
## ferramentas/detectar_rodas.py. Carro sem medida simplesmente corre sem roda.
var rodas_anchors: Dictionary = {}
var rodas_player: Array = []
var rodas_rival: Array = []


# ---------------------------------------------------------------- setup

func _ready() -> void:
	progresso.carregar()
	var f := FileAccess.open("res://rodas.json", FileAccess.READ)
	if f != null:
		var lido = JSON.parse_string(f.get_as_text())
		if lido is Dictionary:
			rodas_anchors = lido
	_build_world()
	_build_hud()
	_to_menu()
	# corrida automatica para checagem end-to-end:
	#   godot --headless --quit-after 2200 -- --autorace
	if "--autorace" in OS.get_cmdline_user_args():
		auto = true
		_shots = [1.5, 8.0, 20.0, 28.0]
		# vitrine na Supra: e o carro em que o problema de roda apareceu
		menu_idx = 11
		_preview_menu()
		await get_tree().process_frame
		await _shot_named("menu")
		_to_mapa()
		await get_tree().process_frame
		await _shot_named("mapa")
		# entra no primeiro no alcancavel: a linha 0 e sempre um racha
		_entrar_no(mapa.alcancaveis()[0])
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

	rodas_player = _criar_rodas(car_sprite)
	rodas_rival = _criar_rodas(rival_sprite)

	cam = Camera3D.new()
	cam.fov = RACE_FOV
	cam.far = 900.0
	add_child(cam)


## As rodas sao FILHAS da carroceria: assim herdam posicao e rotacao de graca, e
## so preciso do deslocamento medido na foto. Roda e um slot de equipamento, entao
## a arte nunca e assada dentro da carroceria -- ela entra por cima, aqui.
func _criar_rodas(corpo: Sprite3D) -> Array:
	var lista: Array = []
	for i in 2:
		var r := Sprite3D.new()
		r.texture = load("res://roda.png")
		r.pixel_size = 1.0 / 256.0   # textura de 256px vira 1m; a escala faz o resto
		r.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		r.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		r.alpha_scissor_threshold = 0.35
		r.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		r.visible = false
		corpo.add_child(r)
		lista.append(r)
	return lista


## Posiciona as duas rodas de um carro a partir das medidas da foto.
func _por_rodas(corpo: Sprite3D, rodas: Array, nome: String) -> void:
	var med: Array = rodas_anchors.get(nome, [])
	if med.size() < 2 or corpo.texture == null:
		for r in rodas:
			r.visible = false
		return
	var tw := float(corpo.texture.get_width())
	var th := float(corpo.texture.get_height())
	for i in 2:
		var a: Dictionary = med[i]
		# Carroceria espelhada move a caixa de roda junto: sem isto a roda do carro
		# espelhado fica do lado errado.
		var cx: float = 1.0 - float(a.cx) if corpo.flip_h else float(a.cx)
		var r: Sprite3D = rodas[i]
		r.position = Vector3((cx - 0.5) * tw * CAR_PIXEL_SIZE,
			(0.5 - float(a.cy)) * th * CAR_PIXEL_SIZE, 0.04)
		r.scale = Vector3(2.0 * float(a.rx) * tw * CAR_PIXEL_SIZE,
			2.0 * float(a.ry) * th * CAR_PIXEL_SIZE, 1.0)
		r.modulate = corpo.modulate
		r.visible = true


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

## Layout do cartao. A tela de oferta precisa de colunas mais largas que o menu,
## entao cada tela declara o seu em vez de tudo caber num tamanho so.
func _card_padrao() -> void:
	card_w = 606.0
	card_table_w = 486.0
	card_cols = [0.0, 34.0, 190.0, 344.0]
	card_head = ["", "motor", "baixa / media / alta", "carro"]
	card_cols_dim = [2, 3]


## Recompensa da vitoria: tres pecas, escolhe uma. E a primeira decisao de
## verdade entre corridas -- ate aqui a sequencia era so apertar R.
func _to_oferta() -> void:
	state = State.OFERTA
	ofertas = build.sortear_ofertas(player.rng, 3)
	# Colunas largas o bastante para o nome mais longo do catalogo. Coluna
	# "equipada" saiu: quase sempre vazia no comeco e espremia as duas que importam.
	card_w = 800.0
	card_table_w = 664.0
	card_cols = [0.0, 26.0, 350.0]
	card_head = ["", "peca", "efeito"]
	card_cols_dim = []
	card_title = "PECA CONQUISTADA"
	card_color = Hud.GREEN
	card_table = []
	for i in ofertas.size():
		var p: Peca = ofertas[i]
		card_table.append(["%d" % (i + 1),
			"%s %s" % [p.nome(), Peca.RARIDADES[p.raridade]], p.resumo()])
	var equipadas := PackedStringArray()
	for linha in build.ficha():
		if linha[1] != "-":
			equipadas.append("%s %s" % [linha[0], linha[1]])
	card_lines = [
		"~equipado: %s" % ("nada ainda" if equipadas.is_empty() else "   ·   ".join(equipadas)),
		"~a antiga vai para a reserva; com a reserva cheia, vira sucata",
	]
	if auto:
		await _shot_named("oferta")
		_to_garagem(_aviso_troca(build.equipar_guardando(ofertas[0])))


## O mapa: onde a rota vira decisao. Entrar num no o consome.
func _to_mapa() -> void:
	state = State.MAPA
	if mapa.linhas.is_empty():
		mapa.gerar(0, garagem.corridas)
	if mapa.precisa_esticar():
		mapa.esticar(garagem.corridas)
	var alc := mapa.alcancaveis()
	if alc.is_empty():
		# Fim do ato: proximo ato, mapa novo.
		mapa.gerar(mini(mapa.ato + 1, Mapa.ATOS - 1), garagem.corridas)
		alc = mapa.alcancaveis()
	sel_no = clampi(sel_no, 0, maxi(alc.size() - 1, 0))


## Entrar num no. O tipo decide o que acontece; o piso e o rival ja vem dele, e e
## por isso que o mapa consegue telegrafar o confronto antes da escolha.
func _entrar_no(pos: int) -> void:
	var no := mapa.entrar(pos)
	no_tipo = no.tipo
	proximo_piso = no.piso
	rival_forcado = no.rival
	match no_tipo:
		"racha", "marcado":
			_start_staging()
		"chefe":
			chefe_placar = [0, 0]
			chefe_pisos = Piso.NOMES.duplicate()
			chefe_pisos.shuffle()
			chefe_pisos.resize(3)
			proximo_piso = chefe_pisos[0]
			_start_staging()
		"oficina":
			ofertas_pagas = true
			_to_oferta()
		"ferro":
			ofertas_pagas = false
			_to_oferta()
		"boxes":
			_boxes()
		_:
			_evento()


## Boxes: a valvula gratuita do GDD 6.2. Conserta de graca o que estiver pior --
## sem ela o jogador nunca gasta com conserto (dinheiro tambem compra build) e
## chega no chefe destrocado.
## Fim do confronto do chefe. Vencer fecha o ato; perder custa a reputacao
## acumulada e devolve voce ao mapa -- o no continua la, mas voce precisa correr
## mais nos para reabrir o desafio, e os nos sao finitos.
func _novidades(lista: Array) -> void:
	for n in lista:
		novidade = n


func _fechar_chefe() -> void:
	if chefe_placar[0] >= 2:
		_novidades(progresso.registrar("chefe"))
		if mapa.ato + 1 >= Mapa.ATOS:
			card_title = "RUN VENCIDA"
			card_color = Hud.GREEN
			card_lines = [
				"%d vitorias em %d corridas" % [garagem.vitorias, garagem.corridas],
				"~M comeca outra run   ·   ESC sai",
			]
			garagem.acabou = true
			_novidades(progresso.registrar("run_vencida"))
			_novidades(progresso.registrar("run"))
			state = State.RESULT
			return
		mapa.gerar(mapa.ato + 1, garagem.corridas)
		_novidades(progresso.marcar_recorde("ato", mapa.ato + 1))
		_to_garagem("ato vencido; o proximo comeca agora")
	else:
		mapa.reputacao = 0
		mapa.linha_atual = mapa.linhas.size() - 2
		_to_garagem("chefe venceu; a reputacao zerou e o desafio fechou")


func _boxes() -> void:
	var aviso := "boxes: nada para consertar"
	if garagem.motor_quebrado or garagem.motor >= garagem.transmissao:
		if garagem.motor > 0.0 or garagem.motor_quebrado:
			garagem.motor = 0.0
			garagem.motor_quebrado = false
			aviso = "boxes: motor recuperado de graca"
	elif garagem.transmissao > 0.0 or garagem.cambio_quebrado:
		garagem.transmissao = 0.0
		garagem.cambio_quebrado = false
		aviso = "boxes: cambio recuperado de graca"
	garagem.nitro = Tuning.NITRO_CAPACITY
	_to_garagem(aviso)


## Evento: texto e escolha com risco. Barato de produzir e e onde entra
## personalidade -- por ora, uma aposta seca.
func _evento() -> void:
	var ganho := int(garagem.aposta() * 1.5)
	if mapa.rng.randf() < 0.55:
		garagem.dinheiro += ganho
		_to_garagem("evento: racha clandestino rendeu %d" % ganho)
	else:
		garagem.dinheiro = maxi(0, garagem.dinheiro - ganho / 2)
		garagem.motor = minf(1.0, garagem.motor + 0.10)
		_to_garagem("evento: a policia apareceu; %d e um susto no motor" % (ganho / 2))


## A garagem e onde a build fica legivel, e o unico lugar em que a reserva serve
## para alguma coisa. Passa por ela toda corrida, de proposito: o GDD pede que a
## build seja sentida, e para isso ela precisa estar na frente do jogador.
## Peca da oficina tem preco; a do ferro-velho e de graca, mas vem gasta.
func _descricao_no(tipo: String) -> String:
	match tipo:
		"oficina": return "tres pecas a venda; o caixa decide"
		"ferro": return "peca de graca, ja desgastada"
		"boxes": return "conserto gratuito do que estiver pior"
		_: return "texto e escolha com risco"


func _preco(p: Peca) -> int:
	return 60 + p.raridade * 70 + garagem.corridas * 4


func _to_oferta_aviso(texto: String) -> void:
	card_lines = ["~" + texto]
	state = State.OFERTA


func _aviso_troca(destino: String) -> String:
	match destino:
		"reserva": return "a peca antiga foi para a reserva"
		"sucata": return "reserva cheia: a peca antiga virou sucata"
		_: return ""


func _to_garagem(aviso: String) -> void:
	state = State.GARAGEM
	garagem_aviso = novidade if not novidade.is_empty() else aviso
	novidade = ""
	# O trecho seguinte so e sorteado uma vez; reentrar na garagem (trocar peca,
	# consertar) nao pode re-sortear, senao o jogador escolhe pneu contra um piso
	# que muda debaixo dele.
	if piso_pendente:
		proximo_piso = Piso.sortear(piso_rng)
		piso_pendente = false
	if auto:
		_shot_named("garagem")


## O menu e uma VITRINE, nao uma tabela: o jogador escolhe o carro que vai levar
## uma sequencia inteira, entao o carro precisa estar na tela. As bandas usam as
## mesmas barras da garagem -- uma linguagem so, aprendida uma vez.
func _to_menu() -> void:
	state = State.MENU
	garagem = Garagem.new()
	build = Build.new()
	build.reserva_max = progresso.reservas
	piso_rng.randomize()
	mapa = Mapa.new()
	mapa.rng.randomize()
	proximo_piso = Piso.sortear(piso_rng)
	player = Car.new()
	rival = Car.new()
	_preview_menu()


func _preview_menu() -> void:
	var nomes := progresso.liberados
	menu_idx = wrapi(menu_idx, 0, maxi(nomes.size(), 1))
	player_car = nomes[menu_idx]
	car_sprite.texture = Cars.texture(player_car)
	car_sprite.flip_h = Cars.flipped(player_car)
	# Sem tingir: na vitrine e o carro, nao o "seu carro" contra o do rival.
	car_sprite.modulate = Color(1, 1, 1)
	rival_sprite.visible = false
	_por_rodas(car_sprite, rodas_player, player_car)


func _start_staging() -> void:
	state = State.STAGING
	piso_pendente = true   # o proximo trecho volta a ser sorteado na garagem
	rev = 0.0
	revving = false
	flash = ""
	peak_heat = 0.0

	player = Car.new()
	player.label = "Voce"
	player.rng.randomize()
	build.aplicar(player, Cars.bandas(player_car), proximo_piso)
	garagem.aplicar(player)   # depois da build: o nitro guardado vence o tanque cheio

	rival = Car.new()
	rival.label = "Rival"
	rival.rng.randomize()
	# O rival tambem corre com pecas, e ganha mais a cada corrida: sem isso a
	# sequencia fica mais facil justo quando a sua build fica melhor.
	var rb := Build.new()
	for i in mini(Peca.SLOTS.size(), 1 + garagem.corridas / 2):
		rb.equipar(Peca.sortear(rival.rng))
	# O rival corre no mesmo piso, com pneu proprio: as vezes o piso pune ele mais
	# que voce, e e essa leitura que o mapa vai telegrafar.
	rb.aplicar(rival, Cars.bandas(rival_car), proximo_piso)
	rival.set_launch(randf_range(0.58, 0.84))
	ai_shift_point = Tuning.AI_SHIFT_POINT

	car_sprite.modulate = Color(0.62, 0.80, 1.0)
	rival_sprite.visible = true
	rival_car = rival_forcado if not rival_forcado.is_empty() 		else Cars.sortear(rival.rng, garagem.corridas)
	if auto:
		# rival fixo numa foto espelhada: assim o print de checagem sempre exercita
		# o caminho do flip, em vez de depender do sorteio
		rival_car = Cars.FLIP[0]
	car_sprite.texture = Cars.texture(player_car)
	rival_sprite.texture = Cars.texture(rival_car)
	# Algumas fotos vieram do lado oposto e precisam ser espelhadas para o carro
	# apontar no sentido da corrida.
	car_sprite.flip_h = Cars.flipped(player_car)
	rival_sprite.flip_h = Cars.flipped(rival_car)
	_por_rodas(car_sprite, rodas_player, player_car)
	_por_rodas(rival_sprite, rodas_rival, rival_car)

	matchup = "%s  %d cv   x   %s  %d cv          piso: %s" % [
		player_car, Cars.cavalos(player_car), rival_car, Cars.cavalos(rival_car),
		proximo_piso]


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
	garagem.recolher(player, venceu, player_car)
	if venceu:
		mapa.premiar(no_tipo)
	if no_tipo == "chefe":
		chefe_placar[0 if venceu else 1] += 1
	# Marcos sao registrados na hora: a run pode acabar de repente, e progresso
	# perdido por timing seria a pior forma de "derrota nao rende nada".
	if venceu and no_tipo == "marcado":
		_novidades(progresso.registrar("marcado"))
	if player.blown:
		_novidades(progresso.registrar("fundir"))
	_novidades(progresso.marcar_recorde("corridas_run", garagem.corridas))
	if garagem.acabou:
		_novidades(progresso.registrar("run"))

	_card_padrao()
	card_title = "VENCEU" if venceu else "DERROTA"
	if no_tipo == "chefe" and not garagem.acabou:
		card_title = "CHEFE  %d x %d" % [chefe_placar[0], chefe_placar[1]]
		card_color = Hud.GREEN if venceu else Hud.RED
	card_color = Hud.GREEN if venceu else Hud.RED
	if player.travado:
		card_title = "CAMBIO QUEBRADO"
		card_color = Hud.AMBER
	if player.blown:
		card_title = "MOTOR FUNDIDO"
		card_color = Hud.RED

	card_table = []
	card_lines = [
		"%s  %d cv   %s" % [player_car, Cars.cavalos(player_car),
			("%.2fs" % player.finished_at) if player.finished_at > 0 else "nao terminou"],
		"~%s  %d cv   %s" % [rival_car, Cars.cavalos(rival_car),
			("%.2fs" % rival.finished_at) if rival.finished_at > 0 else "nao terminou"],
		"motor %s %.0f%%   ·   cambio %s %.0f%%" % [
			Garagem.faixa(garagem.motor), garagem.motor * 100,
			Garagem.faixa(garagem.transmissao), garagem.transmissao * 100],
		"~trocas ruins %d   ·   calor maximo %.0f%%" % [player.bad_shifts, peak_heat * 100],
		"aposta %s%d   ·   caixa %d" % ["+" if venceu else "-", garagem.aposta(),
			garagem.dinheiro],
	]

	if garagem.acabou:
		# Falencia, nao fusao: o motor quebrou e o orcamento passou do caixa.
		card_title = "FALENCIA"
		card_color = Hud.RED
		card_lines = [
			"o motor fundiu na corrida %d" % garagem.corridas,
			"orcamento %d   ·   caixa %d" % [garagem.custo_motor(player_car),
				garagem.dinheiro],
			"%d vitorias em %d corridas" % [garagem.vitorias, garagem.corridas],
			"~M comeca outra sequencia   ·   ESC sai",
		]
	else:
		card_lines.append("~corrida %d   ·   %d vitorias" % [garagem.corridas, garagem.vitorias])
		card_lines.append("~R continua   ·   M recomeca   ·   ESC sai")

	if auto:
		await _shot_named("resultado")
		if won() and not garagem.acabou:
			_to_oferta()


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
				if k.keycode == KEY_DOWN or k.keycode == KEY_RIGHT:
					menu_idx += 1
					_preview_menu()
				elif k.keycode == KEY_UP or k.keycode == KEY_LEFT:
					menu_idx -= 1
					_preview_menu()
				elif k.keycode == KEY_SPACE or k.keycode == KEY_ENTER:
					_to_mapa()
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
		State.MAPA:
			if k.pressed:
				var alc := mapa.alcancaveis()
				if k.keycode == KEY_DOWN or k.keycode == KEY_RIGHT:
					sel_no = wrapi(sel_no + 1, 0, maxi(alc.size(), 1))
				elif k.keycode == KEY_UP or k.keycode == KEY_LEFT:
					sel_no = wrapi(sel_no - 1, 0, maxi(alc.size(), 1))
				elif k.keycode == KEY_G:
					_to_garagem("")
				elif k.keycode == KEY_SPACE and sel_no < alc.size():
					var alvo: int = alc[sel_no]
					var no: Dictionary = mapa.linhas[mapa.linha_alvo()][alvo]
					if no.tipo != "chefe" or mapa.chefe_liberado():
						_entrar_no(alvo)
		State.GARAGEM:
			if k.pressed:
				if k.keycode == KEY_SPACE and not garagem.precisa_consertar():
					_to_mapa()
				elif k.keycode == KEY_M:
					_to_garagem("" if garagem.consertar_motor(player_car)
						else "dinheiro nao chega para o motor")
				elif k.keycode == KEY_C:
					_to_garagem("" if garagem.consertar_cambio(player_car)
						else "dinheiro nao chega para o cambio")
				elif k.keycode == KEY_N:
					_to_garagem("" if garagem.reabastecer(player.nitro_cap)
						else "dinheiro nao chega para o nitro")
				else:
					var ri := [KEY_1, KEY_2].find(k.keycode)
					if ri >= 0 and build.trocar_reserva(ri):
						_to_garagem("")
		State.OFERTA:
			if k.pressed:
				var idx := [KEY_1, KEY_2, KEY_3].find(k.keycode)
				if idx >= 0 and idx < ofertas.size():
					var p: Peca = ofertas[idx]
					if ofertas_pagas:
						var preco := _preco(p)
						if garagem.dinheiro < preco:
							_to_oferta_aviso("caixa nao cobre essa peca")
							return
						garagem.dinheiro -= preco
					if no_tipo == "ferro":
						# GDD 3.6: peca de ferro-velho vem JA desgastada. E a
						# tentacao: o motor dos sonhos que pode fundir a qualquer
						# momento.
						match p.slot:
							"motor": garagem.motor = maxf(garagem.motor, 0.55)
							"transmissao": garagem.transmissao = maxf(garagem.transmissao, 0.55)
					_to_garagem(_aviso_troca(build.equipar_guardando(p)))
		State.RESULT:
			if k.pressed and k.keycode == KEY_R and not garagem.acabou:
				if no_tipo == "chefe" and maxi(chefe_placar[0], chefe_placar[1]) < 2:
					# Sem oficina e sem garagem entre as corridas do chefe: o carro
					# tem que AGUENTAR as tres, e e isso que cobra o desgaste.
					proximo_piso = chefe_pisos[chefe_placar[0] + chefe_placar[1]]
					_start_staging()
				elif no_tipo == "chefe":
					_fechar_chefe()
				elif won():
					_to_oferta()
				else:
					_to_garagem("")
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
		or (auto and player.pos > Tuning.RACE_DISTANCE * 0.6 and player.heat < 0.95)
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
	# Na vitrine a camera chega perto e mira ao lado do carro, para ele cair a
	# direita do quadro e sobrar a esquerda para o painel. So distancia e alvo
	# mudam -- a direcao continua a mesma, entao o sprite continua sem girar.
	if state == State.MENU:
		cam.fov = MENU_FOV
		cam_dist = lerpf(cam_dist, MENU_CAM_DIST, 1.0 - exp(-6.0 * delta))
		var alvo := Vector3(-LANE - MENU_DESLOC_X, CAR_Y * 0.95, 0.0)
		cam.global_position = alvo + cam_dir() * cam_dist
		cam.look_at(alvo)
		return

	cam.fov = RACE_FOV
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
				"piso": proximo_piso,
				"pneu_estourado": player.pneu_estourado,
				"desg_turbo": player.desgaste_turbo,
				"desg_pneu": player.desgaste_pneu,
				"turbo_quebrado": player.turbo_quebrado,
				"perfect_lo": Tuning.PERFECT.x,
				"perfect_hi": Tuning.PERFECT.y,
				"desg_motor": player.desgaste_motor,
				"desg_cambio": player.desgaste_transmissao,
				"travado": player.travado,
				"corrida": garagem.corridas + 1,
				"vitorias": garagem.vitorias,
			})
		State.STAGING:
			d.merge({
				"rev": rev,
				"launch_lo": Tuning.LAUNCH_GREEN.x,
				"launch_hi": Tuning.LAUNCH_GREEN.y,
				"matchup": matchup,
			})
		State.MAPA:
			var alc := mapa.alcancaveis()
			var ficha: Array = []
			if sel_no < alc.size():
				var no: Dictionary = mapa.linhas[mapa.linha_alvo()][alc[sel_no]]
				var rot: String = Hud.ROTULO_NO.get(no.tipo, no.tipo)
				if no.tipo in ["racha", "marcado", "chefe"]:
					ficha = [
						"%s   ·   piso %s" % [rot.to_upper(), String(no.piso).to_upper()],
						"~rival: %s, %s" % [no.rival,
							Cars.ROSTER[no.rival].carater if Cars.ROSTER.has(no.rival) else "?"],
						"~%s" % Piso.descricao(no.piso),
					]
					if no.tipo == "chefe" and not mapa.chefe_liberado():
						ficha.append("trancado: reputacao %d de %d"
							% [mapa.reputacao, Mapa.META_REPUTACAO])
				else:
					ficha = [rot.to_upper(), "~" + _descricao_no(no.tipo)]
			# As ligacoes vao prontas para o HUD: ele desenha, nao calcula rota.
			var ligs: Array = []
			for l in mapa.linhas.size() - 1:
				for i in mapa.linhas[l].size():
					for j in mapa.ligacoes(l, i):
						var viva: bool = (l == mapa.linha_atual and i == mapa.idx_atual) 							or (l == 0 and mapa.linha_atual < 0)
						ligs.append([l, i, mapa.linhas[l].size(), j,
							mapa.linhas[l + 1].size(), viva])
			d.merge({
				"ligacoes": ligs,
				"ato": mapa.ato + 1, "linhas": mapa.linhas,
				"alcancaveis": alc, "linha_alvo": mapa.linha_alvo(),
				"linha_atual": mapa.linha_atual, "idx_atual": mapa.idx_atual,
				"sel_no": sel_no, "reputacao": mapa.reputacao,
				"meta_rep": Mapa.META_REPUTACAO, "ficha_no": ficha,
			})
		State.MENU:
			var lista: Array = progresso.liberados
			var opcoes: Array = []
			for nome in lista:
				opcoes.append([nome, "%d cv   ·   tier %d"
					% [Cars.cavalos(nome), Cars.tier(nome)], Cars.bandas(nome)])
			d.merge({"opcoes": opcoes, "sel": menu_idx,
				"marco": progresso.proximo_marco()})
		State.GARAGEM:
			var pv: Dictionary = build.previa(Cars.bandas(player_car), proximo_piso)
			var eq: Array = []
			for slot in Peca.SLOTS:
				if build.pecas.has(slot):
					var p: Peca = build.pecas[slot]
					eq.append([slot, "%s %s" % [p.marca, Peca.RARIDADES[p.raridade]], p.resumo()])
				else:
					eq.append([slot, "-", ""])
			var res: Array = []
			for p in build.reserva:
				res.append(["%s %s" % [p.nome(), Peca.RARIDADES[p.raridade]], p.resumo()])
			var cm := garagem.custo_motor(player_car)
			var cc := garagem.custo_cambio(player_car)
			var cn := garagem.custo_nitro(player.nitro_cap)
			d.merge({
				"dinheiro": garagem.dinheiro,
				"precisa_consertar": garagem.precisa_consertar(),
				"oficina": [
					["M", "motor", cm, garagem.dinheiro >= cm, garagem.motor_quebrado],
					["C", "cambio", cc, garagem.dinheiro >= cc, garagem.cambio_quebrado],
					["N", "nitro", cn, garagem.dinheiro >= cn, false],
				],
			})
			d.merge({
				"piso": proximo_piso,
				"piso_desc": Piso.descricao(proximo_piso),
				"pneu": pv.get("pneu", "misto"),
				"aderencia": Peca.aderencia(pv.get("pneu", "misto"), proximo_piso),
			})
			d.merge({"equipadas": eq, "reserva": res, "aviso": garagem_aviso,
				"bandas": pv.bandas, "heat_limit": pv.heat_limit, "janela": pv.janela,
				"nitro_cap": pv.nitro_cap})
		_:
			d.merge({"title": card_title, "title_color": card_color,
				"lines": card_lines, "table": card_table, "card_w": card_w,
				"table_w": card_table_w, "cols": card_cols, "head": card_head, "cols_dim": card_cols_dim})
	hud.feed(d)


func _phase_name() -> String:
	if player.gear <= 2:
		return "FASE 1  LARGADA"
	elif player.gear <= 5:
		return "FASE 2  ACELERACAO"
	return "FASE 3  TOPO"
