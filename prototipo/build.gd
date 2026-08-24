class_name Build
extends RefCounted
## As pecas equipadas e como elas viram os numeros da corrida.
##
## Toda peca escreve em cima dos valores base do carro; o carro nunca le as
## constantes globais durante a corrida. E esse caminho -- peca -> numero ->
## forma da corrida -- que o pilar 1 do GDD exige: a build tem que ser SENTIDA.

var pecas: Dictionary = {}   # slot -> Peca

## Reserva. O limite e o que faz a escolha doer: com espaco infinito voce nunca
## abre mao de nada, e escolher deixa de custar.
const RESERVA_INICIAL := 2
## Cresce com os marcos da meta-progressao (GDD 3.6), ate o teto de 6.
var reserva_max := RESERVA_INICIAL
var reserva: Array = []

## Passivos (GDD 3.3): fora do inventario, dois slots, achados durante a run.
const PASSIVOS_MAX := 2
var passivos: Array = []


## Guarda o passivo. Cheio, devolve false: quem escolhe qual dos dois cai fora
## e o jogador, na tela -- nao a ordem em que os itens apareceram.
func pegar_passivo(p: Passivo) -> bool:
	if passivos.size() >= PASSIVOS_MAX:
		return false
	passivos.append(p)
	return true


func trocar_passivo(i: int, p: Passivo) -> void:
	if i >= 0 and i < passivos.size():
		passivos[i] = p


func equipar(p: Peca) -> void:
	pecas[p.slot] = p


## Equipa mandando a peca antiga para a reserva. Se a reserva estiver cheia, a
## antiga vira sucata -- e o custo real de ter so dois espacos.
## Retorna o que aconteceu com a antiga: "", "reserva" ou "sucata".
func equipar_guardando(p: Peca) -> String:
	var antiga: Peca = pecas.get(p.slot, null)
	pecas[p.slot] = p
	if antiga == null:
		return ""
	if reserva.size() < reserva_max:
		reserva.append(antiga)
		return "reserva"
	return "sucata"


## Troca a peca de reserva i com a equipada do MESMO slot. Como toda peca carrega
## seu slot, a troca nunca e ambigua e nao precisa de alvo.
func trocar_reserva(i: int) -> bool:
	if i < 0 or i >= reserva.size():
		return false
	var nova: Peca = reserva[i]
	var antiga: Peca = pecas.get(nova.slot, null)
	pecas[nova.slot] = nova
	if antiga == null:
		reserva.remove_at(i)
	else:
		reserva[i] = antiga
	return true


func aplicar(c: Car, bandas_base: Array, piso := "pista") -> void:
	c.bands = bandas_base.duplicate()
	c.gear_top = Tuning.GEAR_TOP.duplicate()
	c.janela = Tuning.PERFECT
	c.heat_limit = Tuning.HEAT_LIMIT
	c.heat_rate = Tuning.HEAT_RATE
	c.cool_rate = Tuning.COOL_RATE
	c.nitro_cap = Tuning.NITRO_CAPACITY

	for slot in pecas:
		_aplicar(c, pecas[slot].mods)

	# Limites de sanidade: uma pilha de pecas nao pode zerar uma banda nem abrir
	# a janela de troca a ponto de acertar virar automatico.
	for i in c.bands.size():
		c.bands[i] = maxf(12.0, c.bands[i])
	c.janela.x = maxf(c.janela.x, 0.74)
	c.heat_limit = clampf(c.heat_limit, 0.55, 1.05)
	c.cool_rate = maxf(c.cool_rate, 0.05)
	c.heat_rate = maxf(c.heat_rate, 0.06)
	# Piso e pneu entram por ultimo: o piso e do trecho, nao da build, e o pneu so
	# vale contra um piso concreto.
	c.piso_fases = Piso.fases(piso).duplicate()   # const e read-only; o conjunto Tracao mexe nela
	c.heat_rate += Piso.calor(piso)
	c.aderencia = Peca.aderencia(pneu_equipado(), piso)
	if formato_tanque() == "curtas":
		c.garrafa = c.nitro_cap / float(Tuning.GARRAFAS)
	var conj := marca_em_conjunto()
	if not conj.is_empty():
		_aplicar_conjunto(c, conj)
	# Passivos por ultimo: eles dobram a regra que todo o resto ja escreveu.
	for p in passivos:
		p.aplicar(c, piso)
	c.nitro = c.nitro_cap


## Bonus de conjunto (GDD 3.4): tres pecas da mesma marca ligam um efeito que nao
## existe de outra forma. E o que faz PERSEGUIR uma build em vez de pegar sempre o
## numero maior -- sem ele, nao ha razao nenhuma para recusar uma Epica de marca
## errada, e escolher peca vira aritmetica.
const CONJUNTO := 3

func marca_em_conjunto() -> String:
	var contagem := {}
	for slot in pecas:
		var m: String = pecas[slot].marca
		contagem[m] = int(contagem.get(m, 0)) + 1
		if contagem[m] >= CONJUNTO:
			return m
	return ""


func _aplicar_conjunto(c: Car, marca: String) -> void:
	match marca:
		"Torque":
			c.bands[0] *= 1.14          # a largada vira dominio
		"Alta Rotacao":
			c.bands[2] *= 1.14          # o topo vira dominio
		"Quimica":
			c.mult_desgaste_motor = 0.45  # forcar calor cobra menos
		"Confiabilidade":
			c.mult_desgaste_geral = 0.55  # a run inteira dura mais
		"Tracao":
			# Ignora a punicao do piso na largada: o unico jeito de correr na lama
			# como se fosse pista.
			c.piso_fases[0] = maxf(c.piso_fases[0], 1.0)


## O tipo de pneu equipado, ou o misto de fabrica quando o slot esta vazio.
func formato_tanque() -> String:
	if pecas.has("nitro"):
		return pecas["nitro"].mods.get("formato", "longo")
	return "longo"


func pneu_equipado() -> String:
	if pecas.has("roda"):
		return pecas["roda"].mods.get("pneu", "misto")
	return "misto"


func _aplicar(c: Car, mods: Dictionary) -> void:
	for chave in mods:
		if chave == "pneu" or chave == "formato":
			continue   # nao sao numeros: entram em aplicar()
		var v: float = mods[chave]
		match chave:
			"banda_baixa": c.bands[0] += v
			"banda_media": c.bands[1] += v
			"banda_alta": c.bands[2] += v
			"heat_limit": c.heat_limit += v
			"heat_rate": c.heat_rate += v
			"cool_rate": c.cool_rate += v
			"nitro_cap": c.nitro_cap += v
			"janela": c.janela.x -= v          # janela mais larga = comeca antes
			"gear_span":
				for i in c.gear_top.size():
					c.gear_top[i] *= 1.0 + v


## Tres ofertas distintas entre si: oferecer a mesma peca duas vezes desperdica
## uma escolha que so aparece depois de vencer uma corrida.
func sortear_ofertas(rng: RandomNumberGenerator, n := 3) -> Array:
	var ofertas: Array = []
	var vistos := {}
	var tentativas := 0
	while ofertas.size() < n and tentativas < 60:
		tentativas += 1
		var p := Peca.sortear(rng)
		var chave := "%s|%s" % [p.slot, p.marca]
		if vistos.has(chave):
			continue
		vistos[chave] = true
		ofertas.append(p)
	return ofertas


## Os numeros que a build produz, sem precisar de uma corrida. E o que torna a
## build VISIVEL: o jogador ve a forma do carro, nao so a lista de pecas.
func previa(bandas_base: Array, piso := "pista") -> Dictionary:
	var c := Car.new()
	aplicar(c, bandas_base, piso)
	return {
		"bandas": c.bands.duplicate(),
		"heat_limit": c.heat_limit,
		"cool_rate": c.cool_rate,
		"janela": c.janela,
		"nitro_cap": c.nitro_cap,
		"gear_top": c.gear_top.duplicate(),
		"pneu": pneu_equipado(),
		"conjunto": marca_em_conjunto(),
		"formato": formato_tanque(),
	}


## Linha por slot para a ficha do carro. Slot vazio aparece, para o jogador ver
## o que ainda falta.
func ficha() -> Array:
	var linhas: Array = []
	for slot in Peca.SLOTS:
		if pecas.has(slot):
			var p: Peca = pecas[slot]
			linhas.append([slot, "%s %s" % [p.marca, Peca.RARIDADES[p.raridade]]])
		else:
			linhas.append([slot, "-"])
	return linhas
