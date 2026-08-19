class_name Peca
extends RefCounted
## Uma peca equipavel. A marca e a identidade -- e ela que faz o jogador
## reconhecer a build em dois segundos, do mesmo jeito que um deus do Hades.
## A raridade so escala numeros, inclusive os negativos: uma peca Epica tem
## identidade MAIS forte, nao apenas melhor.

const SLOTS := ["motor", "transmissao", "cambio", "escape", "nitro"]
const MARCAS := ["Torque", "Alta Rotacao", "Quimica", "Confiabilidade"]
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
	},
	"transmissao": {
		"Torque":         {"gear_span": -0.07},
		"Alta Rotacao":   {"gear_span": 0.07},
		"Quimica":        {"gear_span": 0.03},
		"Confiabilidade": {"gear_span": -0.02},
	},
	"cambio": {
		"Torque":         {"janela": 0.015},
		"Alta Rotacao":   {"janela": 0.030},
		"Quimica":        {"janela": 0.010},
		"Confiabilidade": {"janela": 0.045},
	},
	"escape": {
		"Torque":         {"cool_rate": 0.030},
		"Alta Rotacao":   {"cool_rate": 0.040},
		"Quimica":        {"cool_rate": 0.060},
		"Confiabilidade": {"cool_rate": 0.040, "heat_limit": 0.040},
	},
	"nitro": {
		"Torque":         {"nitro_cap": 1.5},
		"Alta Rotacao":   {"nitro_cap": 2.0},
		"Quimica":        {"nitro_cap": 3.0, "heat_rate": 0.050},
		"Confiabilidade": {"nitro_cap": 1.0, "heat_rate": -0.040},
	},
}

## Como cada modificador aparece na ficha da peca.
const ROTULOS := {
	"banda_baixa": "baixa", "banda_media": "media", "banda_alta": "alta",
	"gear_span": "marchas", "janela": "janela de troca",
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
		p.mods[chave] = RECEITAS[slot_][marca_][chave] * k
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
		var v: float = mods[chave]
		var rotulo: String = ROTULOS.get(chave, chave)
		if chave.begins_with("banda"):
			partes.append("%+.0f %s" % [v, rotulo])
		elif chave == "gear_span":
			partes.append("%s %.0f%%" % ["encurta" if v < 0.0 else "alonga", absf(v) * 100.0])
		elif chave == "nitro_cap":
			partes.append("%+.1fs %s" % [v, rotulo])
		else:
			partes.append("%+.0f%% %s" % [v * 100.0, rotulo])
	return "   ".join(partes)
