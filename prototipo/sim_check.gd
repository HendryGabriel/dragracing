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
		"cross_pct": cross / Tuning.RACE_DISTANCE * 100.0}


func _initialize() -> void:
	var fails := 0
	var clean := {}

	print("=== corrida limpa, sem nitro (jogo perfeito) ===")
	for name in Tuning.PROFILES:
		var r := _run(Tuning.PROFILES[name], 0.96, 2.0, 0.0, 1)
		clean[name] = r
		var seq := PackedStringArray()
		for g in range(2, Tuning.GEARS + 1):
			seq.append("%da %.1f" % [g, r.marks[g]] if r.marks.has(g) else "%da --" % g)
		print("%-14s tempo %5.2fs | top %4.0f km/h | 100m em %4.0fm@5s | %s"
			% [name, r.t, r.top * 3.6, r.pos5, " | ".join(seq)])

	print("\n=== com nitro na fase 3 (segurando ate 0.95 de calor) ===")
	for name in Tuning.PROFILES:
		var r := _run(Tuning.PROFILES[name], 0.96, 0.60, 0.95, 1)
		var ganho: float = clean[name].t - r.t
		print("%-14s tempo %5.2fs | ganho %+.2fs | fundiu: %s"
			% [name, r.t, ganho, r.blown])

	print("\n=== jogo ruim: troca sempre cedo (rpm 0.70), sem nitro ===")
	for name in Tuning.PROFILES:
		var r := _run(Tuning.PROFILES[name], 0.70, 2.0, 0.0, 1)
		print("%-14s tempo %5.2fs | custo do erro %+.2fs" % [name, r.t, r.t - clean[name].t])

	# ---------- checagem 1: janela de 30s ----------
	for name in clean:
		var t: float = clean[name].t
		if t < 27.0 or t > 33.0:
			push_error("[1] %s fora da janela de 30s: %.2fs" % [name, t])
			fails += 1

	# ---------- checagem 2: torque lidera cedo, alta rotacao ultrapassa antes da linha ----------
	# A promessa do sistema de bandas so existe se a lideranca troca de mao DENTRO da corrida.
	var duelo := _duel(Tuning.PROFILES["Torque"], Tuning.PROFILES["Alta Rotacao"])
	print("\nduelo Torque x Alta Rotacao: vantagem maxima do torque %.0fm aos %.1fs | %s"
		% [duelo.max_lead, duelo.max_lead_at,
			"ultrapassagem em %.0fm (%.0f%% da pista)" % [duelo.cross, duelo.cross_pct]
			if duelo.cross > 0.0 else "NUNCA ultrapassa"])
	if duelo.max_lead < 15.0:
		push_error("[2] Torque nao abre vantagem visivel cedo (%.0fm)" % duelo.max_lead)
		fails += 1
	if duelo.cross < 0.0:
		push_error("[2] Alta Rotacao nunca ultrapassa: a banda alta nao paga")
		fails += 1
	elif duelo.cross_pct < 55.0 or duelo.cross_pct > 95.0:
		push_error("[2] Ultrapassagem fora da janela 55-95%%: %.0f%%" % duelo.cross_pct)
		fails += 1

	# ---------- checagem 3: o nitro decide a fase 3 ----------
	var seguro := _run(Tuning.PROFILES["Equilibrado"], 0.96, 0.60, 0.78, 1)  # abaixo do limite
	var base: float = clean["Equilibrado"].t
	if base - seguro.t < 0.30:
		push_error("[3] Nitro sem efeito util: ganho de apenas %.2fs" % (base - seguro.t))
		fails += 1
	print("nitro conservador (calor < 0.78): ganho de %.2fs sem risco" % (base - seguro.t))

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
	scene.player_profile = "Torque"
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

	var ok: bool = scene.state == 3  # 3 = State.RESULT
	print("\nsmoke da cena: estado final %s apos %.1fs simulados"
		% ["RESULT" if ok else "TRAVOU (%d)" % scene.state, steps * DT * 2.0])
	scene.queue_free()
	if not ok:
		push_error("[4] A corrida nao chegou na tela de resultado")
		fails_local += 1
	return fails_local
