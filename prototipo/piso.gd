class_name Piso
extends RefCounted
## Os pisos (GDD 5). Piso NAO e um multiplicador global de aderencia: e um perfil
## sobre as TRES FASES mais o calor.
##
## Multiplicador unico daria quatro texturas diferentes e uma decisao so ("pegue o
## pneu de maior numero"). Perfil por fase faz cada piso premiar uma build
## diferente -- e e isso que transforma escolher rota em decisao.

const NOMES := ["pista", "cidade", "deserto", "lama"]

## fases: multiplicador de [baixa, media, alta].
## calor: somado a taxa de aquecimento; encolhe a margem termica sem tocar no
## resto, que e exatamente o que o deserto faz no GDD.
const PISOS := {
	"pista":   {"fases": [1.00, 1.00, 1.00], "calor": 0.000,
		"desc": "preparada; a build pura brilha e o rival nao tem desculpa"},
	"cidade":  {"fases": [1.00, 0.94, 0.94], "calor": 0.010,
		"desc": "asfalto irregular; largada boa, perda constante depois"},
	"deserto": {"fases": [0.94, 0.98, 1.00], "calor": 0.055,
		"desc": "calor ambiente alto; a margem termica encolhe"},
	"lama":    {"fases": [0.60, 0.95, 1.00], "calor": 0.000,
		"desc": "largada arrasada; premia alta rotacao, pune torque"},
}


static func fases(piso: String) -> Array:
	return PISOS[piso].fases if PISOS.has(piso) else [1.0, 1.0, 1.0]


static func calor(piso: String) -> float:
	return PISOS[piso].calor if PISOS.has(piso) else 0.0


static func descricao(piso: String) -> String:
	return PISOS[piso].desc if PISOS.has(piso) else ""


static func sortear(rng: RandomNumberGenerator) -> String:
	return NOMES[rng.randi() % NOMES.size()]
