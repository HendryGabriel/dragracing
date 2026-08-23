class_name Peca
extends RefCounted
## Uma peca equipavel. A marca e a identidade -- e ela que faz o jogador
## reconhecer a build em dois segundos, do mesmo jeito que um deus do Hades.
## A raridade so escala numeros, inclusive os negativos: uma peca Epica tem
## identidade MAIS forte, nao apenas melhor.

const SLOTS := ["motor", "turbo", "transmissao", "cambio", "escape", "nitro", "roda"]
const MARCAS := ["Torque", "Alta Rotacao", "Quimica", "Confiabilidade", "Tracao"]
const RARIDADES := ["Comum", "Rara", "Epica"]
const ESCALA := [1.0, 1.6, 2.3]

## O que cada marca faz em cada slot. Toda peca do jogo sai daqui, escalada
## pela raridade -- e o catalogo inteiro cabe numa tela, que e o ponto.
const RECEITAS := {
	"motor": {
		"Torque":         {"banda_baixa": 14.0, "banda_alta": -7.0},
		"Alta Rotacao":   {"banda_alta": 16.0, "banda_baixa": -7.0},
		"Quimica":        {"banda_media": 9.0, "heat_limit": -0.05},
		"Confiabilidade": {"banda_media": 5.0, "heat_limit": 0.06},
		"Tracao":         {"banda_baixa": 9.0, "banda_media": 3.0},
	},
	# Turbo desloca a curva para a DIREITA: tira de baixo e poe em cima, e esquenta.
	# E o slot que mais muda a fase 3, e o unico que gasta so por voce segurar boost.
	"turbo": {
		"Torque":         {"banda_alta": 10.0, "banda_baixa": -4.0, "heat_rate": 0.012},
		"Alta Rotacao":   {"banda_alta": 18.0, "banda_baixa": -9.0, "heat_rate": 0.022},
		"Quimica":        {"banda_alta": 22.0, "banda_baixa": -11.0, "heat_rate": 0.038},
		"Confiabilidade": {"banda_alta": 9.0, "banda_baixa": -3.0, "heat_rate": 0.004},
		"Tracao":         {"banda_alta": 8.0, "banda_media": 5.0, "heat_rate": 0.014},
	},
	"transmissao": {
		"Torque":         {"gear_span": -0.07},
		"Alta Rotacao":   {"gear_span": 0.07},
		"Quimica":        {"gear_span": 0.03},
		"Confiabilidade": {"gear_span": -0.02},
		"Tracao":         {"gear_span": -0.05},
	},
	"cambio": {
		"Torque":         {"janela": 0.015},
		"Alta Rotacao":   {"janela": 0.030},
		"Quimica":        {"janela": 0.010},
		"Confiabilidade": {"janela": 0.045},
		"Tracao":         {"janela": 0.020},
	},
	"escape": {
		"Torque":         {"cool_rate": 0.030},
		"Alta Rotacao":   {"cool_rate": 0.040},
		"Quimica":        {"cool_rate": 0.060},
		"Confiabilidade": {"cool_rate": 0.040, "heat_limit": 0.040},
		"Tracao":         {"cool_rate": 0.035},
	},
	"nitro": {
		"Torque":         {"nitro_cap": 1.5},
		"Alta Rotacao":   {"nitro_cap": 2.0},
		"Quimica":        {"nitro_cap": 3.0, "heat_rate": 0.050},
		"Confiabilidade": {"nitro_cap": 1.0, "heat_rate": -0.040},
		"Tracao":         {"nitro_cap": 1.2},
	},
	# Roda e a unica peca cujo efeito depende do PISO: e um perfil, nao um numero.
	# Nao existe "o melhor pneu" -- existe o pneu certo para o proximo trecho.
	"roda": {
		"Torque":         {"pneu": "arrancada"},
		"Alta Rotacao":   {"pneu": "slick"},
		"Quimica":        {"pneu": "misto"},
		"Confiabilidade": {"pneu": "misto"},
		"Tracao":         {"pneu": "cravado"},
	},
}

## Aderencia de cada pneu por piso. Aplicada so na banda BAIXA: e a largada que o
## pneu decide (GDD 2.1, fase 1 = banda baixa + pneu + piso).
const PNEUS := {
	"slick":     {"pista": 1.16, "cidade": 1.04, "deserto": 0.88, "lama": 0.62},
	"arrancada": {"pista": 1.12, "cidade": 1.08, "deserto": 0.92, "lama": 0.70},
	"misto":     {"pista": 0.98, "cidade": 0.99, "deserto": 0.99, "lama": 0.94},
	"cravado":   {"pista": 0.86, "cidade": 0.90, "deserto": 1.06, "lama": 1.20},
}


## Quanto o pneu agarra neste piso. 1.0 e neutro; abaixo disso ele esta errado
## para o trecho, e alem de perder largada o pneu se gasta mais rapido.
static func aderencia(pneu: String, piso: String) -> float:
	if not PNEUS.has(pneu):
		return 1.0
	return PNEUS[pneu].get(piso, 1.0)

## Como cada modificador aparece na ficha da peca.
const ROTULOS := {
	"banda_baixa": "baixa", "banda_media": "media", "banda_alta": "alta",
	"gear_span": "marchas", "janela": "janela de troca", "pneu": "pneu",
	"cool_rate": "resfriamento", "heat_limit": "limite termico",
	"heat_rate": "aquecimento", "nitro_cap": "tanque",
}

var slot := "motor"
var marca := "Torque"
var raridade := 0
var mods: Dictionary = {}


static func gerar(slot_: String, marca_: String, raridade_: int) -> Peca:
	var p := Peca.new()
	p.slot = slot_
	p.marca = marca_
	p.raridade = raridade_
	var k: float = ESCALA[raridade_]
	for chave in RECEITAS[slot_][marca_]:
		var v = RECEITAS[slot_][marca_][chave]
		# Tipo de pneu nao escala com raridade: raridade escala NUMERO, e "cravado"
		# nao tem versao epica -- o que muda e o resto da peca.
		p.mods[chave] = v if v is String else v * k
	return p


static func sortear(rng: RandomNumberGenerator) -> Peca:
	# Epica e rara de proposito: se peca boa cai toda hora, escolher nao pesa.
	var r := rng.randf()
	var raridade_ := 0
	if r > 0.88:
		raridade_ = 2
	elif r > 0.55:
		raridade_ = 1
	return gerar(SLOTS[rng.randi() % SLOTS.size()],
		MARCAS[rng.randi() % MARCAS.size()], raridade_)


func nome() -> String:
	return "%s %s" % [slot.capitalize(), marca]


## Ficha curta, ja com sinal: e assim que o jogador compara duas ofertas.
func resumo() -> String:
	var partes := PackedStringArray()
	for chave in mods:
		var v = mods[chave]
		var rotulo: String = ROTULOS.get(chave, chave)
		if chave == "pneu":
			partes.append("pneu %s" % v)
			continue
		if chave.begins_with("banda"):
			partes.append("%+.0f %s" % [v, rotulo])
		elif chave == "gear_span":
			partes.append("%s %.0f%%" % ["encurta" if v < 0.0 else "alonga", absf(v) * 100.0])
		elif chave == "nitro_cap":
			partes.append("%+.1fs %s" % [v, rotulo])
		else:
			partes.append("%+.0f%% %s" % [v * 100.0, rotulo])
	return "   ".join(partes)
