extends SceneTree
## Checagem headless da simulacao. Roda com:
##   godot --headless --path . --script res://sim_check.gd
##
## Nao checa "esta divertido" -- checa as tres promessas que o prototipo existe
## para testar, e que se quebradas derrubam o GDD inteiro:
##   1. a corrida dura ~30s
##   2. torque lidera cedo e alta rotacao lidera tarde (as bandas existem de fato)
##   3. o nitro muda o resultado na fase 3 (senao a fase 3 nao tem decisao)

const DT := 1.0 / 120.0

## As checagens de arquetipo precisam de tres carros REAIS de potencia parecida
## (241 a 290 cv), senao a comparacao mede cavalo em vez de formato de curva.
const REFS := {
	"Torque": "mustang 1969",
	"Equilibrado": "golf gti",
	"Alta Rotacao": "supra mk4",
}


func _make(bands: Array, seed_v: int) -> Car:
	var c := Car.new()
	c.bands = bands
	c.rng.seed = seed_v
	c.set_launch(0.70)  # largada perfeita nos dois lados
	return c


func _run(bands: Array, shift_at: float, nitro_from: float, hold_to: float,
		seed_v: int) -> Dictionary:
	var c := _make(bands, seed_v)
	var marks := {}
	var pos_at_5 := 0.0
	while c.finished_at < 0.0 and c.time < 120.0:
		if c.rpm() >= shift_at:
			c.shift_up()
		c.nitro_on = c.nitro > 0.0 and c.pos > Tuning.RACE_DISTANCE * nitro_from \
			and c.heat < hold_to
		c.step(DT)
		if not marks.has(c.gear):
			marks[c.gear] = c.time
		if pos_at_5 == 0.0 and c.time >= 5.0:
			pos_at_5 = c.pos
	return {"t": c.finished_at, "marks": marks, "blown": c.blown, "top": c.speed,
		"pos5": pos_at_5}


## Roda os dois lado a lado e acha onde a lideranca troca de mao.
func _duel(bands_a: Array, bands_b: Array) -> Dictionary:
	var a := _make(bands_a, 1)
	var b := _make(bands_b, 2)
	var max_lead := 0.0
	var max_lead_at := 0.0
	var cross := -1.0
	while a.finished_at < 0.0 and b.finished_at < 0.0 and a.time < 120.0:
		if a.rpm() >= 0.96:
			a.shift_up()
		if b.rpm() >= 0.96:
			b.shift_up()
		a.step(DT)
		b.step(DT)
		var lead := a.pos - b.pos
		if lead > max_lead:
			max_lead = lead
			max_lead_at = a.time
		if cross < 0.0 and max_lead > 0.0 and lead <= 0.0:
			cross = a.pos
	return {"max_lead": max_lead, "max_lead_at": max_lead_at, "cross": cross,
		"cross_pct": cross / Tuning.RACE_DISTANCE * 100.0,
		"lead_final": a.pos - b.pos}


## Simula uma sequencia inteira ate o motor fundir, num estilo de jogo.
## E aqui que o segundo pilar do GDD ("ganancia tem preco com memoria") vira
## numero: se o ganancioso durar o mesmo que o cauteloso, o sistema nao existe.
func _carreira(estilo: String, seed_v: int, ref: float) -> Dictionary:
	var g := Garagem.new()
	while not g.acabou and g.corridas < 60:
		var c := Car.new()
		c.bands = Cars.bandas(REFS["Equilibrado"])
		c.rng.seed = seed_v * 1000 + g.corridas
		c.set_launch(0.70)
		g.aplicar(c)
		var shift_at := 0.96
		var hold := 0.0
		match estilo:
			"cauteloso": hold = 0.75
			"ganancioso": hold = 0.95
			"seletivo": hold = 0.95 if g.corridas % 3 == 0 else 0.75
			"desleixado": shift_at = 0.70
		while c.finished_at < 0.0 and not c.blown and c.time < 120.0:
			if c.rpm() >= shift_at:
				c.shift_up()
			c.nitro_on = hold > 0.0 and c.nitro > 0.0 				and c.pos > Tuning.RACE_DISTANCE * 0.60 and c.heat < hold
			c.step(DT)
		g.recolher(c, c.finished_at > 0.0 and c.finished_at < ref)
	return {"corridas": g.corridas, "vitorias": g.vitorias, "motor": g.motor,
		"cambio": g.transmissao}


func _media(estilo: String, ref: float) -> Dictionary:
	var cs := 0.0
	var vs := 0.0
	var cambio := 0.0
	var n := 12
	for i in n:
		var r := _carreira(estilo, i + 1, ref)
		cs += r.corridas
		vs += r.vitorias
		cambio += r.cambio
	return {"corridas": cs / n, "vitorias": vs / n, "cambio": cambio / n}


func _initialize() -> void:
	var fails := 0
	var clean := {}

	print("=== corrida limpa, sem nitro (jogo perfeito) ===")
	for name in REFS:
		var r := _run(Cars.bandas(REFS[name]), 0.96, 2.0, 0.0, 1)
		clean[name] = r
		var seq := PackedStringArray()
		for g in range(2, Tuning.GEARS + 1):
			seq.append("%da %.1f" % [g, r.marks[g]] if r.marks.has(g) else "%da --" % g)
		print("%-14s tempo %5.2fs | top %4.0f km/h | 100m em %4.0fm@5s | %s"
			% [name, r.t, r.top * 3.6, r.pos5, " | ".join(seq)])

	print("\n=== com nitro na fase 3 (segurando ate 0.95 de calor) ===")
	for name in REFS:
		var r := _run(Cars.bandas(REFS[name]), 0.96, 0.60, 0.95, 1)
		var ganho: float = clean[name].t - r.t
		print("%-14s tempo %5.2fs | ganho %+.2fs | fundiu: %s"
			% [name, r.t, ganho, r.blown])

	print("\n=== jogo ruim: troca sempre cedo (rpm 0.70), sem nitro ===")
	for name in REFS:
		var r := _run(Cars.bandas(REFS[name]), 0.70, 2.0, 0.0, 1)
		print("%-14s tempo %5.2fs | custo do erro %+.2fs" % [name, r.t, r.t - clean[name].t])

	# Panorama do elenco: com potencia de fabrica a escada e larga de proposito, e
	# so os carros do meio ficam perto dos 30s. Informativo, nao e checagem.
	print("
=== elenco, corrida limpa sem nitro ===")
	for nome in Cars.elenco():
		var rr := _run(Cars.bandas(nome), 0.96, 2.0, 0.0, 1)
		var b: Array = Cars.bandas(nome)
		print("%-20s %4d cv  tier %d  %5.2fs  top %4.0f km/h  %5.1f /%5.1f /%5.1f"
			% [nome, Cars.cavalos(nome), Cars.tier(nome), rr.t, rr.top * 3.6,
				b[0], b[1], b[2]])

	# ---------- checagem 1: janela de 30s ----------
	for name in clean:
		var t: float = clean[name].t
		if t < 27.0 or t > 33.0:
			push_error("[1] %s fora da janela de 30s: %.2fs" % [name, t])
			fails += 1

	# ---------- checagem 2b: os quatro carateres tem que EMPATAR em potencia igual --
	# o formato decide QUANDO voce ganha, nunca SE voce ganha. Se um carater for
	# sistematicamente mais rapido, escolher carro vira escolher o carater certo.
	print("
=== carateres a 300 cv (o formato nao pode decidir a corrida) ===")
	var tempos := {}
	for carater in Cars.PESOS:
		var rr := _run(Cars.curva(300, carater), 0.96, 2.0, 0.0, 1)
		tempos[carater] = rr.t
		print("%-13s %5.2fs  top %4.0f km/h" % [carater, rr.t, rr.top * 3.6])
	var spread: float = tempos.values().max() - tempos.values().min()
	print("desvio entre carateres: %.2fs" % spread)
	if spread > 0.60:
		push_error("[2b] Carater decide a corrida sozinho: %.2fs de desvio" % spread)
		fails += 1

	# ---------- checagem 2: torque lidera cedo, alta rotacao ultrapassa antes da linha ----------
	# A promessa do sistema de bandas so existe se a lideranca troca de mao DENTRO da corrida.
	var duelo := _duel(Cars.curva(300, "torque"), Cars.curva(300, "turbo"))
	print("\nduelo Torque x Alta Rotacao: vantagem maxima do torque %.0fm aos %.1fs | %s"
		% [duelo.max_lead, duelo.max_lead_at,
			"ultrapassagem em %.0fm (%.0f%% da pista)" % [duelo.cross, duelo.cross_pct]
			if duelo.cross > 0.0 else "NUNCA ultrapassa"])
	# O formato promete que o torque abre cedo e o turbo devolve no fim. Como os
	# dois EMPATAM em potencia igual (checagem 2b), a ultrapassagem cai em cima da
	# linha -- entao o que se mede nao e "onde cruzou", e QUANTO o turbo recuperou.
	var recuperou: float = 1.0 - maxf(duelo.lead_final, 0.0) / maxf(duelo.max_lead, 1.0)
	print("torque abre %.0fm aos %.1fs e o turbo recupera %.0f%% ate a linha"
		% [duelo.max_lead, duelo.max_lead_at, recuperou * 100.0])
	if duelo.max_lead < 15.0:
		push_error("[2] Torque nao abre vantagem visivel cedo (%.0fm)" % duelo.max_lead)
		fails += 1
	if recuperou < 0.75:
		push_error("[2] Turbo nao devolve no fim: recupera so %.0f%%" % (recuperou * 100.0))
		fails += 1

	# ---------- checagem 3: o nitro decide a fase 3 ----------
	var seguro := _run(Cars.bandas(REFS["Equilibrado"]), 0.96, 0.60, 0.78, 1)  # abaixo do limite
	var base: float = clean["Equilibrado"].t
	if base - seguro.t < 0.30:
		push_error("[3] Nitro sem efeito util: ganho de apenas %.2fs" % (base - seguro.t))
		fails += 1
	print("nitro conservador (calor < 0.78): ganho de %.2fs sem risco" % (base - seguro.t))

	# ---------- checagem 5: ganancia cobra ----------
	# Referencia = o tempo de quem joga seguro. A pergunta que importa nao e
	# "voce termina?", e "forcar bate quem nao forca?".
	var ref: float = seguro.t - 0.02
	print("
=== sequencias ate o motor fundir (media de 12) ===")
	var est := {}
	for estilo in ["cauteloso", "seletivo", "ganancioso", "desleixado"]:
		var m := _media(estilo, ref)
		est[estilo] = m
		print("%-12s %5.1f corridas | %5.1f vitorias | cambio %.0f%%"
			% [estilo, m.corridas, m.vitorias, m.cambio * 100])

	if est["ganancioso"].corridas >= est["cauteloso"].corridas * 0.75:
		push_error("[5] Ganancia nao cobra: ganancioso dura %.1f e cauteloso %.1f"
			% [est["ganancioso"].corridas, est["cauteloso"].corridas])
		fails += 1
	if est["ganancioso"].vitorias <= est["cauteloso"].vitorias:
		push_error("[5] Ganancia nao paga: ganancioso vence %.1f e cauteloso %.1f"
			% [est["ganancioso"].vitorias, est["cauteloso"].vitorias])
		fails += 1
	# O jeito de jogar que o GDD pressupoe -- forcar so nas corridas que importam --
	# tem que aguentar uma run inteira (~25 corridas). Se nao aguentar, forcar nunca
	# e opcao e a fase 3 vira sempre a mesma decisao.
	if est["seletivo"].corridas < 20.0:
		push_error("[5] Forcar seletivamente nao aguenta uma run: so %.1f corridas"
			% est["seletivo"].corridas)
		fails += 1
	if est["desleixado"].cambio < 0.5:
		push_error("[5] Errar troca nao gasta o cambio: so %.0f%%"
			% (est["desleixado"].cambio * 100))
		fails += 1

	# ---------- checagem 6: peca muda a FORMA da corrida ----------
	# Pilar 1 do GDD: "a build e sentida, nao lida". Duas builds sobre o MESMO
	# motor base tem que correr diferente; se so mudam o tempo final, sao enfeite.
	var bandas_base: Array = Cars.bandas(REFS["Equilibrado"])
	var formas := {}
	for marca in ["Torque", "Alta Rotacao"]:
		var b := Build.new()
		b.equipar(Peca.gerar("motor", marca, 2))
		b.equipar(Peca.gerar("transmissao", marca, 2))
		var c := Car.new()
		c.rng.seed = 7
		b.aplicar(c, bandas_base)
		c.set_launch(0.70)
		var p5 := 0.0
		while c.finished_at < 0.0 and c.time < 120.0:
			if c.rpm() >= 0.96:
				c.shift_up()
			c.step(DT)
			if p5 == 0.0 and c.time >= 5.0:
				p5 = c.pos
		formas[marca] = {"t": c.finished_at, "p5": p5, "top": c.speed}
	var dif_p5: float = formas["Torque"].p5 - formas["Alta Rotacao"].p5
	var dif_top: float = formas["Alta Rotacao"].top - formas["Torque"].top
	print("
mesmo motor base, pecas opostas: torque %+.0fm aos 5s | alta rotacao %+.0f km/h no topo"
		% [dif_p5, dif_top * 3.6])
	if dif_p5 < 8.0:
		push_error("[6] Pecas de torque nao mudam a largada: so %+.0fm aos 5s" % dif_p5)
		fails += 1
	if dif_top < 3.0:
		push_error("[6] Pecas de alta rotacao nao mudam o topo: so %+.0f km/h" % (dif_top * 3.6))
		fails += 1

	# ---------- checagem 7: inventario ----------
	# A reserva so vale alguma coisa se tiver teto: com espaco infinito o jogador
	# nunca abre mao de nada e escolher deixa de custar.
	var b := Build.new()
	var destinos := PackedStringArray()
	for i in 4:
		destinos.append(b.equipar_guardando(Peca.gerar("motor", Peca.MARCAS[i], 0)))
	print("
reserva ao trocar 4 motores seguidos: %s (teto %d)"
		% [", ".join(destinos), Build.RESERVA_MAX])
	if destinos[0] != "":
		push_error("[7] Slot vazio nao devia mandar nada para a reserva")
		fails += 1
	if b.reserva.size() > Build.RESERVA_MAX:
		push_error("[7] Reserva estourou o teto: %d" % b.reserva.size())
		fails += 1
	if destinos[3] != "sucata":
		push_error("[7] Com a reserva cheia a peca antiga tinha que virar sucata, veio \"%s\""
			% destinos[3])
		fails += 1

	# Trocar duas vezes tem que voltar ao estado original, senao a troca perde peca.
	var antes: Peca = b.pecas["motor"]
	var guardada: Peca = b.reserva[0]
	b.trocar_reserva(0)
	b.trocar_reserva(0)
	if b.pecas["motor"] != antes or b.reserva[0] != guardada:
		push_error("[7] Trocar com a reserva duas vezes nao volta ao original")
		fails += 1

	# ---------- checagem 4: a cena roda uma corrida inteira sem quebrar ----------
	fails += _scene_smoke()

	print("\n%s" % ("OK" if fails == 0 else "%d checagem(ns) falhou(ram)" % fails))
	quit(fails)


## Boota main.tscn e dirige uma corrida do inicio ao fim pelo caminho real
## (camera + HUD + fim de corrida), que a simulacao pura nao cobre.
func _scene_smoke() -> int:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	# Em --script o loop principal nao roda, entao _ready() nao dispara sozinho.
	if scene.cam == null:
		scene._ready()
	if scene.cam == null or scene.hud == null or scene.hud.font == null:
		push_error("[4] A cena nao montou mundo/HUD")
		scene.queue_free()
		return 1
	scene.menu_idx = 0
	scene._preview_menu()
	scene._start_staging()
	scene.rev = 0.70
	scene._start_race()

	var fails_local := 0
	var steps := 0
	while scene.state == 2 and steps < 6000:  # 2 = State.RACING
		if scene.player.rpm() >= 0.96:
			scene.player.shift_up()
		scene._process(DT * 2.0)
		steps += 1

	# A vitoria tem que sair do TEMPO. Ja saiu da posicao uma vez e declarou
	# vencedor quem perdeu por 0.04s, porque posicao congela na linha.
	scene.player.finished_at = 30.10
	scene.rival.finished_at = 30.06
	scene.player.blown = false
	if scene.won():
		push_error("[4] Vitoria decidida errado: rival 0.04s mais rapido e o jogador venceu")
		fails_local += 1
	scene.rival.finished_at = 30.20
	if not scene.won():
		push_error("[4] Vitoria decidida errado: jogador 0.10s mais rapido e perdeu")
		fails_local += 1

	# A camera recua pelo proprio eixo quando o rival abre. Se recuar de menos, o
	# rival passa POR TRAS dela e some do quadro justo quando voce mais precisa ver.
	var cosang: float = cos(deg_to_rad(scene.CAM_ANGLE_DEG))
	for ahead in [0.0, 6.0, 15.0, 25.0]:
		var d: float = scene.cam_distance_for(ahead)
		var frente: float = cosang * d
		if frente < ahead + 8.0:
			push_error("[4] Camera perto demais: rival %.0fm na frente, camera so %.0fm"
				% [ahead, frente])
			fails_local += 1
	if not is_equal_approx(scene.cam_distance_for(0.0), scene.CAM_DIST):
		push_error("[4] Sem rival na frente a camera deveria ficar na distancia base")
		fails_local += 1
	# A direcao nao pode depender da distancia, senao recuar giraria o sprite.
	var dir: Vector3 = scene.cam_dir()
	if not is_equal_approx(dir.length(), 1.0):
		push_error("[4] cam_dir nao e unitaria: recuar mudaria o angulo")
		fails_local += 1

	# Um nome errado em Cars.FLIP nao da erro: o carro so continua correndo de
	# costas e ninguem percebe ate ver em movimento. E nome fora do elenco vira
	# carro sem foto, que quebra na hora de carregar a textura.
	for nome in Cars.FLIP:
		if not Cars.ROSTER.has(nome):
			push_error("[4] Cars.FLIP tem \"%s\", que nao esta no elenco" % nome)
			fails_local += 1
	for nome in Cars.ROSTER:
		if not ResourceLoader.exists(Cars.DIR + nome + ".png"):
			push_error("[4] elenco tem \"%s\" sem foto em cars/" % nome)
			fails_local += 1

	var ok: bool = scene.state == 3  # 3 = State.RESULT
	print("\nsmoke da cena: estado final %s apos %.1fs simulados"
		% ["RESULT" if ok else "TRAVOU (%d)" % scene.state, steps * DT * 2.0])
	scene.queue_free()
	if not ok:
		push_error("[4] A corrida nao chegou na tela de resultado")
		fails_local += 1
	return fails_local
