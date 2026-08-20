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
const RESERVA_MAX := 2
var reserva: Array = []


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
	if reserva.size() < RESERVA_MAX:
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


func aplicar(c: Car, bandas_base: Array) -> void:
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
	c.nitro = c.nitro_cap


func _aplicar(c: Car, mods: Dictionary) -> void:
	for chave in mods:
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
func previa(bandas_base: Array) -> Dictionary:
	var c := Car.new()
	aplicar(c, bandas_base)
	return {
		"bandas": c.bands.duplicate(),
		"heat_limit": c.heat_limit,
		"cool_rate": c.cool_rate,
		"janela": c.janela,
		"nitro_cap": c.nitro_cap,
		"gear_top": c.gear_top.duplicate(),
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
