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
		seed_v: int, piso := "pista", pneu := "misto") -> Dictionary:
	var c := _make(bands, seed_v)
	c.piso_fases = Piso.fases(piso)
	c.heat_rate += Piso.calor(piso)
	c.aderencia = Peca.aderencia(pneu, piso)
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
func _carreira(estilo: String, seed_v: int, _ref: float) -> Dictionary:
	var carro: String = REFS["Equilibrado"]
	var g := Garagem.new()
	var b := Build.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 31
	var consertos := 0
	var apostado := 0
	while not g.acabou and g.corridas < 60:
		var c := Car.new()
		c.rng.seed = seed_v * 1000 + g.corridas
		c.set_launch(0.70)
		# A build do jogador cresce junto com o rival: sem isso a escada do rival
		# atropela em cinco corridas e a sequencia nunca chega a lugar nenhum.
		var piso: String = Piso.NOMES[rng.randi() % Piso.NOMES.size()]
		# O jogador ve o piso do trecho ANTES de correr, entao usa a reserva para
		# trocar de pneu. Sem modelar isso, a simulacao mede um jogador que ignora
		# a informacao que o jogo passa -- e subestima a sequencia.
		for i in range(b.reserva.size()):
			var pr: Peca = b.reserva[i]
			if pr.slot != "roda":
				continue
			if Peca.aderencia(pr.mods.get("pneu", "misto"), piso) 					> Peca.aderencia(b.pneu_equipado(), piso):
				b.trocar_reserva(i)
				break
		b.aplicar(c, Cars.bandas(carro), piso)
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
		# Rival de verdade, nao cronometro: mesmo carro, pericia imperfeita e nitro
		# moderado. Sem isso a taxa de vitoria vira artefato da referencia escolhida
		# e a economia nunca respira.
		var riv := Car.new()
		# O rival SOBE com a sequencia. Com rival parado, jogar seguro vence sempre e
		# forcar nunca compensa -- a escada e o que obriga a arriscar mais tarde.
		riv.bands = Cars.curva(238 + g.corridas * 3, "equilibrado")
		riv.piso_fases = Piso.fases(piso)
		riv.aderencia = Peca.aderencia("misto", piso)
		riv.rng.seed = seed_v * 7919 + g.corridas
		riv.set_launch(riv.rng.randf_range(0.58, 0.84))
		var ponto := 0.96
		while riv.finished_at < 0.0 and not riv.blown and riv.time < 120.0:
			if riv.rpm() >= ponto:
				riv.shift_up()
				ponto = 0.96 + riv.rng.randf_range(-0.10, 0.05)
			riv.nitro_on = riv.nitro > 0.0 				and riv.pos > Tuning.RACE_DISTANCE * Tuning.AI_NITRO_FROM 				and riv.heat < Tuning.AI_HEAT_TARGET
			riv.step(DT)
		var venceu := c.finished_at > 0.0 and (riv.finished_at <= 0.0
			or c.finished_at <= riv.finished_at)
		apostado += g.aposta()
		g.recolher(c, venceu, carro)
		if venceu:
			b.equipar_guardando(Peca.sortear(rng))

		# A oficina do jogador razoavel: conserta o que trava primeiro, depois o
		# que esta perto de quebrar, e so entao reabastece.
		if g.motor_quebrado and g.consertar_motor(carro):
			consertos += 1
		elif g.motor > Tuning.FAIXA_CRITICA and g.consertar_motor(carro):
			consertos += 1
		if g.cambio_quebrado and g.consertar_cambio(carro):
			consertos += 1
		g.reabastecer(c.nitro_cap)
	return {"corridas": g.corridas, "vitorias": g.vitorias, "motor": g.motor,
		"cambio": g.transmissao, "dinheiro": g.dinheiro, "consertos": consertos,
		"apostado": apostado}


func _media(estilo: String, ref: float) -> Dictionary:
	var cs := 0.0
	var vs := 0.0
	var cambio := 0.0
	var caixa := 0.0
	var cons := 0.0
	var apost := 0.0
	var n := 12
	for i in n:
		var r := _carreira(estilo, i + 1, ref)
		cs += r.corridas
		vs += r.vitorias
		cambio += r.cambio
		caixa += r.dinheiro
		cons += r.consertos
		apost += r.apostado
	return {"corridas": cs / n, "vitorias": vs / n, "cambio": cambio / n,
		"dinheiro": caixa / n, "consertos": cons / n, "apostado": apost / n}


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
		print("%-12s %5.1f corridas | %5.1f vitorias | %4.1f consertos | caixa final %4.0f"
			% [estilo, m.corridas, m.vitorias, m.consertos, m.dinheiro])

	if est["ganancioso"].corridas >= est["cauteloso"].corridas * 0.75:
		push_error("[5] Ganancia nao cobra: ganancioso dura %.1f e cauteloso %.1f"
			% [est["ganancioso"].corridas, est["cauteloso"].corridas])
		fails += 1
	# Comparar vitorias ABSOLUTAS premia quem corre mais vezes. O que importa e a
	# taxa: forcar tem que fazer voce ganhar mais das corridas que disputa.
	var taxa_gan: float = est["ganancioso"].vitorias / maxf(est["ganancioso"].corridas, 1.0)
	var taxa_cau: float = est["cauteloso"].vitorias / maxf(est["cauteloso"].corridas, 1.0)
	print("taxa de vitoria: ganancioso %.0f%%   cauteloso %.0f%%"
		% [taxa_gan * 100, taxa_cau * 100])
	if taxa_gan <= taxa_cau:
		push_error("[5] Ganancia nao paga: ganancioso vence %.0f%% e cauteloso %.0f%%"
			% [taxa_gan * 100, taxa_cau * 100])
		fails += 1
	# O jeito de jogar que o GDD pressupoe -- forcar so nas corridas que importam --
	# tem que aguentar uma run inteira (~25 corridas). Se nao aguentar, forcar nunca
	# e opcao e a fase 3 vira sempre a mesma decisao.
	if est["seletivo"].corridas < 20.0:
		push_error("[5] Forcar seletivamente nao aguenta uma run: so %.1f corridas"
			% est["seletivo"].corridas)
		fails += 1
	# A economia so existe se a oficina for usada. Quem visita a oficina e quem
	# forca: o cauteloso nunca quebra nada, entao a checagem tem que olhar para o
	# ganancioso, nao para a media.
	if est["ganancioso"].consertos < 0.4:
		push_error("[5] Nem o ganancioso conserta: a oficina nao entrou no loop")
		fails += 1

	# A troca economica: forcar VENCE MAIS e DURA MENOS -- e so isso. Nao existe
	# "forcar tambem rende mais dinheiro": a aposta cresce com a sequencia, entao
	# quem dura mais joga por fichas maiores, e nenhuma medida de caixa (final,
	# por corrida ou por aposta) separa competencia de longevidade. O que esta
	# checado aqui e o contrario: forcar NAO pode render mais por aposta, senao
	# forcar seria almoco gratis -- mais vitorias e mais caixa pelo mesmo risco.
	var rende_gan: float = (est["ganancioso"].dinheiro - Tuning.DINHEIRO_INICIAL) 		/ maxf(est["ganancioso"].apostado, 1.0)
	var rende_cau: float = (est["cauteloso"].dinheiro - Tuning.DINHEIRO_INICIAL) 		/ maxf(est["cauteloso"].apostado, 1.0)
	print("retorno sobre o apostado: ganancioso %+.0f%%   cauteloso %+.0f%%"
		% [rende_gan * 100.0, rende_cau * 100.0])
	if rende_gan > rende_cau:
		push_error("[5] Forcar e almoco gratis: rende %+.0f%% contra %+.0f%% do cauteloso"
			% [rende_gan * 100.0, rende_cau * 100.0])
		fails += 1
	# E o outro lado: nenhum estilo pode virar maquina de dinheiro, ou a oficina
	# deixa de ser decisao e a run vira passeio.
	if rende_cau > 0.35:
		push_error("[5] Economia estourada: o cauteloso rende %+.0f%% por aposta"
			% (rende_cau * 100.0))
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
		% [", ".join(destinos), b.reserva_max])
	if destinos[0] != "":
		push_error("[7] Slot vazio nao devia mandar nada para a reserva")
		fails += 1
	if b.reserva.size() > b.reserva_max:
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

	# ---------- checagem 8: piso muda QUEM ganha, nao so o relogio ----------
	# A promessa do GDD 5 e que lama pune torque e premia alta rotacao. Se os dois
	# perderem o mesmo tanto, piso e textura, nao decisao.
	print("
=== piso: posicao aos 5s (largada), pneu misto ===")
	var p5 := {}
	for carater in ["torque", "alta"]:
		var linha := PackedStringArray()
		p5[carater] = {}
		for piso in Piso.NOMES:
			var rr := _run(Cars.curva(300, carater), 0.96, 2.0, 0.0, 1, piso)
			p5[carater][piso] = rr.pos5
			linha.append("%s %.0fm" % [piso, rr.pos5])
		print("%-8s %s" % [carater, " | ".join(linha)])
	var perda_torque: float = p5["torque"]["pista"] - p5["torque"]["lama"]
	var perda_alta: float = p5["alta"]["pista"] - p5["alta"]["lama"]
	print("lama custa %.0fm ao torque e %.0fm a alta rotacao" % [perda_torque, perda_alta])
	if perda_torque <= perda_alta:
		push_error("[8] Lama nao pune torque mais que alta rotacao: %.0fm x %.0fm"
			% [perda_torque, perda_alta])
		fails += 1

	# ---------- checagem 9: pneu certo x errado ----------
	# Nao existe "o melhor pneu": cada um tem um piso onde ganha e outro onde perde.
	print("
=== pneu na lama e na pista, posicao aos 5s ===")
	var melhor := {}
	for pneu in Peca.PNEUS:
		var linha2 := PackedStringArray()
		for piso in ["pista", "lama"]:
			var rr := _run(Cars.curva(300, "equilibrado"), 0.96, 2.0, 0.0, 1, piso, pneu)
			melhor[pneu + "|" + piso] = rr.pos5
			linha2.append("%s %.0fm" % [piso, rr.pos5])
		print("%-10s %s" % [pneu, " | ".join(linha2)])
	if melhor["cravado|lama"] <= melhor["slick|lama"]:
		push_error("[9] Pneu cravado nao ganha na lama")
		fails += 1
	if melhor["slick|pista"] <= melhor["cravado|pista"]:
		push_error("[9] Slick nao ganha na pista")
		fails += 1

	# ---------- checagem 10: turbo muda a fase 3 ----------
	var sem := Build.new()
	var com := Build.new()
	com.equipar(Peca.gerar("turbo", "Quimica", 2))
	var base_b: Array = Cars.bandas(REFS["Equilibrado"])
	var c_sem := Car.new()
	sem.aplicar(c_sem, base_b)
	var c_com := Car.new()
	com.aplicar(c_com, base_b)
	print("
turbo epico: banda alta %.0f -> %.0f   |   baixa %.0f -> %.0f"
		% [c_sem.bands[2], c_com.bands[2], c_sem.bands[0], c_com.bands[0]])
	if c_com.bands[2] - c_sem.bands[2] < 12.0:
		push_error("[10] Turbo nao muda a fase 3: alta so subiu %.0f"
			% (c_com.bands[2] - c_sem.bands[2]))
		fails += 1
	if c_com.bands[0] >= c_sem.bands[0]:
		push_error("[10] Turbo nao cobra na largada: baixa nao caiu")
		fails += 1

	# ---------- checagem 11: o mapa e atravessavel e o chefe e trancado ----------
	# Mapa sem caminho ate o chefe e run sem fim; chefe destrancado de graca apaga a
	# decisao de "desafiar agora ou farmar mais" (GDD 6.1).
	var m := Mapa.new()
	m.rng.seed = 4242
	var sem_saida := 0
	var min_rota := 999
	var max_rota := 0
	for tentativa in 40:
		m.gerar(tentativa % Mapa.ATOS, tentativa)
		# Toda linha precisa alcancar a seguinte, senao a run trava no meio.
		for l in m.linhas.size() - 1:
			for i in m.linhas[l].size():
				if m.ligacoes(l, i).is_empty():
					sem_saida += 1
		# Percorre uma rota qualquer e conta a reputacao maxima possivel.
		var rep := 0
		m.linha_atual = -1
		while true:
			var alc := m.alcancaveis()
			if alc.is_empty():
				break
			var no := m.entrar(alc[alc.size() - 1])
			if no.tipo == "marcado":
				rep += Tuning.REPUTACAO_MARCADO
			elif no.tipo == "racha":
				rep += Tuning.REPUTACAO_RACHA
		min_rota = mini(min_rota, rep)
		max_rota = maxi(max_rota, rep)
	print("
mapa: reputacao de uma rota vai de %d a %d (meta %d)"
		% [min_rota, max_rota, Mapa.META_REPUTACAO])
	if sem_saida > 0:
		push_error("[11] %d nos sem saida: a run trava no meio do mapa" % sem_saida)
		fails += 1
	# Se a pior rota ja destranca o chefe, a reputacao nao e trava nenhuma. Se nem a
	# melhor destranca, o chefe e inalcancavel.
	if min_rota >= Mapa.META_REPUTACAO:
		push_error("[11] Reputacao nao trava nada: ate a pior rota chega a %d" % min_rota)
		fails += 1
	if max_rota < Mapa.META_REPUTACAO:
		push_error("[11] Chefe inalcancavel: a melhor rota so junta %d" % max_rota)
		fails += 1

	# Chegar no chefe trancado nao pode ser beco sem saida: o ato estica.
	m.gerar(0, 0)
	m.linha_atual = m.linhas.size() - 2
	m.idx_atual = 0
	m.reputacao = 0
	if not m.precisa_esticar():
		push_error("[11] Chefe trancado na porta e nao pede trecho novo: run travada")
		fails += 1
	var linhas_antes := m.linhas.size()
	m.esticar(0)
	if m.linha_atual != -1 or m.linhas.size() < 2:
		push_error("[11] Esticar o ato nao devolveu um trecho jogavel")
		fails += 1
	print("esticar: %d linhas viram %d, e o chefe continua no fim" % [linhas_antes, m.linhas.size()])

	# ---------- checagem 12: meta-progressao ----------
	# Roguelike onde derrota rende zero faz o jogador desistir na 4a run, entao o
	# que se checa aqui e que PERDER tambem abre coisa, e que o save sobrevive.
	var pr := Progresso.new()
	pr.arquivo = "user://progresso_teste.json"
	var iniciais := pr.liberados.size()
	for nome in pr.liberados:
		if Cars.tier(nome) > 1:
			push_error("[12] Elenco inicial tem carro de tier %d: a escada nasce plana"
				% Cars.tier(nome))
			fails += 1
			break
	# Terminar uma run PERDENDO ja e um marco.
	var abriu := pr.registrar("run")
	print("
meta: elenco comeca com %d carros; perder uma run abriu %d coisa(s)"
		% [iniciais, abriu.size()])
	if abriu.is_empty():
		push_error("[12] Perder uma run nao rende nada")
		fails += 1
	# Marco nao pode pagar duas vezes.
	if not pr.registrar("run").is_empty():
		push_error("[12] O mesmo marco pagou duas vezes")
		fails += 1
	# Reserva tem teto.
	for i in 30:
		pr.registrar("fundir")
		pr.marcar_recorde("ato", 3)
		pr.marcar_recorde("corridas_run", 25)
	if pr.reservas > Progresso.RESERVA_TETO:
		push_error("[12] Reserva passou do teto: %d" % pr.reservas)
		fails += 1
	# Ida e volta pelo disco.
	pr.salvar()
	var pr2 := Progresso.new()
	pr2.arquivo = pr.arquivo
	pr2.carregar()
	if pr2.liberados.size() != pr.liberados.size() or pr2.reservas != pr.reservas:
		push_error("[12] O save nao volta igual: %d/%d carros, %d/%d reservas"
			% [pr2.liberados.size(), pr.liberados.size(), pr2.reservas, pr.reservas])
		fails += 1
	print("meta: apos os marcos, %d carros e %d reservas; save volta igual"
		% [pr.liberados.size(), pr.reservas])

	# ---------- checagem 13: cambio, conjunto e formato do tanque ----------
	# As tres escolhas de build da fase 5 tem que APARECER no numero, senao sao
	# texto de menu. Cada uma paga um preco e ganha uma coisa.

	# Automatico: troca sempre "boa", nunca "perfeita", e por isso nunca mói a
	# transmissao (GDD 2.4). Manual mal jogado mói.
	var bandas_p: Array = Cars.bandas("golf gti")
	var auto_c := _make(bandas_p, 7)
	auto_c.cambio_auto = true
	while auto_c.finished_at < 0.0 and auto_c.time < 120.0:
		if auto_c.rpm() >= Tuning.AI_SHIFT_POINT:
			auto_c.shift_up()
		auto_c.step(DT)
	var man_c := _make(bandas_p, 7)
	while man_c.finished_at < 0.0 and man_c.time < 120.0:
		if man_c.rpm() >= 0.72:   # troca cedo demais: erro de piloto
			man_c.shift_up()
		man_c.step(DT)
	if auto_c.desgaste_transmissao > 0.0:
		push_error("[13] Automatico gastou transmissao: %.2f" % auto_c.desgaste_transmissao)
		fails += 1
	if man_c.desgaste_transmissao <= 0.0:
		push_error("[13] Manual errado nao gastou transmissao: o risco sumiu")
		fails += 1
	if auto_c.finished_at >= man_c.finished_at:
		push_error("[13] Manual mal jogado bateu o automatico: nao ha piso a proteger")
		fails += 1
	var perf := _run(bandas_p, 0.96, 0.55, 0.999, 7)
	if perf.t >= auto_c.finished_at:
		push_error("[13] Manual perfeito nao bate o automatico: o teto sumiu")
		fails += 1
	print("
cambio: automatico %.2fs sem gastar transmissao; manual perfeito %.2fs, manual ruim %.2fs (%.0f%% de transmissao)"
		% [auto_c.finished_at, perf.t, man_c.finished_at,
			man_c.desgaste_transmissao * 100.0])

	# Conjunto: 3 pecas da mesma marca mudam a corrida (GDD 3.4).
	var b_solto := Build.new()
	var b_conj := Build.new()
	for slot in ["motor", "turbo", "escape"]:
		b_conj.equipar(Peca.gerar(slot, "Alta Rotacao", 0))
		b_solto.equipar(Peca.gerar(slot, "Alta Rotacao", 0))
	if b_conj.marca_em_conjunto() != "Alta Rotacao":
		push_error("[13] Tres pecas da mesma marca nao formaram conjunto")
		fails += 1
	# O mesmo, com uma peca trocada de marca: nao pode dar conjunto.
	b_solto.equipar(Peca.gerar("escape", "Torque", 0))
	if not b_solto.marca_em_conjunto().is_empty():
		push_error("[13] Conjunto ativou com marcas misturadas")
		fails += 1
	var c_conj := Car.new()
	var c_solto := Car.new()
	b_conj.aplicar(c_conj, bandas_p)
	b_solto.aplicar(c_solto, bandas_p)
	if c_conj.bands[2] <= c_solto.bands[2]:
		push_error("[13] Conjunto Alta Rotacao nao empurrou a banda alta")
		fails += 1
	print("conjunto: 3x Alta Rotacao levam a banda alta de %.0f para %.0f"
		% [c_solto.bands[2], c_conj.bands[2]])

	# Tanque: o formato nao muda o empurrao, muda ate onde da para mergulhar
	# (GDD 2.3). Com o tanque longo o boost e continuo, o calor sobe sem parar e
	# o overboost fica ao alcance -- junto com o dado de fundir. As tres garrafas
	# cortam sozinhas: o pico para num teto proprio e o motor sofre menos.
	var mergulho := {}
	for formato in ["longo", "curtas"]:
		var c := _make(bandas_p, 3)
		if formato == "curtas":
			c.garrafa = c.nitro_cap / float(Tuning.GARRAFAS)
		while c.finished_at < 0.0 and c.time < 120.0:
			if c.rpm() >= Tuning.AI_SHIFT_POINT:
				c.shift_up()
			# Mergulho deliberado: fundo na faixa vermelha, parando antes de fundir.
			c.nitro_on = c.nitro > 0.0 and c.pos > Tuning.RACE_DISTANCE * 0.55 				and c.heat < Tuning.HEAT_MAX - 0.01
			c.step(DT)
		mergulho[formato] = c
	var lg: Car = mergulho["longo"]
	var ct: Car = mergulho["curtas"]
	if lg.finished_at >= ct.finished_at:
		push_error("[13] Tanque longo nao tem teto proprio: o formato nao e escolha")
		fails += 1
	if ct.heat_pico >= lg.heat_pico:
		push_error("[13] As garrafas nao seguram o pico: %.0f%% contra %.0f%%"
			% [ct.heat_pico * 100.0, lg.heat_pico * 100.0])
		fails += 1
	if ct.desgaste_motor >= lg.desgaste_motor:
		push_error("[13] As garrafas nao poupam o motor: o formato so tem custo")
		fails += 1
	print("tanque no mergulho: longo %.2fs, pico %.0f%%, motor %.0f%%; 3 curtas %.2fs, pico %.0f%%, motor %.0f%%"
		% [lg.finished_at, lg.heat_pico * 100.0, lg.desgaste_motor * 100.0,
			ct.finished_at, ct.heat_pico * 100.0, ct.desgaste_motor * 100.0])

	# Passivo raro tem que DOBRAR REGRA, nao dar mais um percentual (GDD 3.3).
	var b_pas := Build.new()
	for id in ["coletor", "comando", "radiador"]:
		if b_pas.pegar_passivo(Passivo.por_id(id)):
			pass
	if b_pas.passivos.size() != Build.PASSIVOS_MAX:
		push_error("[13] Os passivos nao respeitam os dois slots: %d guardados"
			% b_pas.passivos.size())
		fails += 1

	# Nitro gelado: os primeiros segundos de boost saem sem calor nenhum.
	var frio := _make(bandas_p, 5)
	Passivo.por_id("nitro_frio").aplicar(frio, "pista")
	for i_ in int(Passivo.NITRO_FRIO / DT) - 1:
		frio.nitro_on = true
		frio.step(DT)
	if frio.heat > 0.0:
		push_error("[13] Nitro gelado esquentou: %.0f%%" % (frio.heat * 100.0))
		fails += 1
	for i_ in 10:
		frio.step(DT)
	if frio.heat <= 0.0:
		push_error("[13] Nitro gelado nunca acaba: a regra virou permanente")
		fails += 1

	# Cambio perdoador: engole UM erro por corrida, e so um.
	var perd := _make(bandas_p, 5)
	Passivo.por_id("perdao").aplicar(perd, "pista")
	perd.shift_up()   # rpm baixo na largada = troca ruim
	if perd.desgaste_transmissao > 0.0:
		push_error("[13] O perdao nao cobriu o primeiro erro")
		fails += 1
	perd.shift_lock = 0.0
	perd.shift_up()
	if perd.desgaste_transmissao <= 0.0:
		push_error("[13] O perdao cobriu o segundo erro tambem: virou imunidade")
		fails += 1

	# Cravos escondidos: a lama larga como asfalto -- e so na lama.
	var b_cravo := Build.new()
	b_cravo.pegar_passivo(Passivo.por_id("cravos"))
	var na_lama := Car.new()
	b_cravo.aplicar(na_lama, bandas_p, "lama")
	if na_lama.piso_fases[0] < 1.0:
		push_error("[13] Cravos nao salvaram a largada na lama: %.2f" % na_lama.piso_fases[0])
		fails += 1
	var no_deserto := Car.new()
	b_cravo.aplicar(no_deserto, bandas_p, "deserto")
	if no_deserto.piso_fases[0] >= 1.0:
		push_error("[13] Cravos consertaram um piso que nao e lama: a regra vazou")
		fails += 1
	print("passivos: 2 slots; nitro gelado dura %.0fs; perdao cobre 1 erro; cravos so valem na lama"
		% Passivo.NITRO_FRIO)

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
