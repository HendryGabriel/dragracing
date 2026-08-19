class_name Garagem
extends RefCounted
## Estado do carro ENTRE corridas. E o que transforma ganancia numa decisao de
## verdade: forcar o calor ganha a corrida de agora e cobra na de depois.
##
## Sem oficina ainda (depende de economia), entao nao ha conserto: a sequencia
## acaba quando o motor funde. O placar e quantas corridas voce venceu antes disso.

var motor := 0.0              # desgaste 0..1
var transmissao := 0.0
var corridas := 0
var vitorias := 0
var acabou := false           # motor fundido: fim da sequencia


## Estado so para leitura. Desgaste NAO reduz desempenho -- so a chance de quebrar.
static func faixa(d: float) -> String:
	if d < Tuning.FAIXA_GASTA:
		return "NOVA"
	elif d < Tuning.FAIXA_CRITICA:
		return "GASTA"
	return "CRITICA"


func aplicar(c: Car) -> void:
	c.desgaste_motor = motor
	c.desgaste_transmissao = transmissao


func recolher(c: Car, venceu: bool) -> void:
	motor = c.desgaste_motor
	transmissao = c.desgaste_transmissao
	corridas += 1
	if venceu:
		vitorias += 1
	if c.blown:
		acabou = true
