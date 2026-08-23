class_name Garagem
extends RefCounted
## Estado do carro ENTRE corridas: desgaste, dinheiro e nitro.
##
## E o que transforma ganancia numa decisao de verdade: forcar o calor ganha a
## corrida de agora e cobra na de depois.
##
## O fim da sequencia e FALENCIA, nao fusao (GDD 4.4). Quando uma peca quebra, a
## oficina da um orcamento e voce decide se afunda o dinheiro nela. Motor fundido
## custa MAIS que o carro vale -- e ai a decisao morde de verdade.

var motor := 0.0              # desgaste 0..1
var transmissao := 0.0
var motor_quebrado := false
var cambio_quebrado := false
var nitro := Tuning.NITRO_CAPACITY   # consumido nas corridas, reabastecido aqui

var dinheiro := Tuning.DINHEIRO_INICIAL
var corridas := 0
var vitorias := 0
var acabou := false           # sem dinheiro para consertar: fim da sequencia


## Estado so para leitura. Desgaste NAO reduz desempenho -- so a chance de quebrar.
static func faixa(d: float) -> String:
	if d < Tuning.FAIXA_GASTA:
		return "NOVA"
	elif d < Tuning.FAIXA_CRITICA:
		return "GASTA"
	return "CRITICA"


## Quanto o carro vale. Sai da potencia de fabrica, entao conserto de carro forte
## custa caro de verdade.
func valor(carro: String) -> int:
	return Tuning.VALOR_BASE + Cars.cavalos(carro) * Tuning.VALOR_POR_CV


## Orcamento do conserto. Peca quebrada custa mais que a peca gasta no limite --
## e no caso do motor, mais que o proprio carro.
func custo_motor(carro: String) -> int:
	if motor_quebrado:
		return int(valor(carro) * Tuning.CONSERTO_MOTOR_QUEBRADO)
	return int(valor(carro) * Tuning.CONSERTO_MOTOR * motor)


func custo_cambio(carro: String) -> int:
	if cambio_quebrado:
		return int(valor(carro) * Tuning.CONSERTO_CAMBIO_QUEBRADO)
	return int(valor(carro) * Tuning.CONSERTO_CAMBIO * transmissao)


func custo_nitro(cap: float) -> int:
	return int(ceil(maxf(cap - nitro, 0.0) * Tuning.CUSTO_NITRO_SEG))


## Aposta do racha. Cresce com a sequencia: perder tarde dói mais que perder cedo.
func aposta() -> int:
	return Tuning.APOSTA_BASE + corridas * Tuning.APOSTA_POR_CORRIDA


## Pago so na vitoria, por cima da aposta.
func premio() -> int:
	return Tuning.PREMIO_BASE + corridas * Tuning.PREMIO_POR_CORRIDA


func consertar_motor(carro: String) -> bool:
	var c := custo_motor(carro)
	if c <= 0 or dinheiro < c:
		return false
	dinheiro -= c
	motor = 0.0
	motor_quebrado = false
	return true


func consertar_cambio(carro: String) -> bool:
	var c := custo_cambio(carro)
	if c <= 0 or dinheiro < c:
		return false
	dinheiro -= c
	transmissao = 0.0
	cambio_quebrado = false
	return true


func reabastecer(cap: float) -> bool:
	var c := custo_nitro(cap)
	if c <= 0 or dinheiro < c:
		return false
	dinheiro -= c
	nitro = cap
	return true


## Nao se aposta o que nao se tem. Sem caixa para cobrir a aposta, nao ha racha --
## e essa a outra ponta da falencia: perder drena o dinheiro que consertaria o
## carro, e sem dinheiro nem correr da mais.
func pode_correr() -> bool:
	return dinheiro >= aposta()


## Motor quebrado trava a sequencia: ou conserta, ou acabou. E o unico bloqueio --
## cambio quebrado deixa correr, so que preso numa marcha.
func precisa_consertar() -> bool:
	return motor_quebrado


## Falencia por dois caminhos: o motor quebrou e o orcamento passou do caixa, ou
## o caixa nao cobre nem a aposta da proxima corrida.
func checar_falencia(carro: String) -> void:
	if motor_quebrado and dinheiro < custo_motor(carro):
		acabou = true
	elif not pode_correr():
		acabou = true


func aplicar(c: Car) -> void:
	c.desgaste_motor = motor
	c.desgaste_transmissao = transmissao
	c.travado = cambio_quebrado
	c.nitro = minf(nitro, c.nitro_cap)


func recolher(c: Car, venceu: bool, carro: String) -> void:
	motor = c.desgaste_motor
	transmissao = c.desgaste_transmissao
	nitro = c.nitro
	if c.blown:
		motor_quebrado = true
	if c.travado:
		cambio_quebrado = true

	dinheiro += (aposta() + premio()) if venceu else -aposta()
	dinheiro = maxi(dinheiro, 0)

	corridas += 1
	if venceu:
		vitorias += 1
	checar_falencia(carro)
