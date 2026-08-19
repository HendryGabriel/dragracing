class_name Cars
## Registro das carrocerias. No vocabulario do GDD, a carroceria E o carro.
##
## A arte e foto 3/4 frontal, branca (aceita pintura por modulate) e SEM RODAS:
## as caixas de roda estao vazias de proposito, porque Roda e um slot de
## equipamento proprio e entra como arte separada por cima.

const DIR := "res://cars/"

## Lista explicita em vez de varrer o diretorio: DirAccess sobre res:// se comporta
## diferente no editor e no build exportado.
const ALL := [
	"Initial D carro", "R35", "audi r8", "bmw m3", "brasilia", "chevette",
	"civic", "demon challenger", "dodge charger 1970", "ferrari f40", "fusca",
	"golf gti", "kombi", "lamborguini", "lancer evo x", "mclaren senna",
	"mustang 1969", "mustang 2018", "mustang dark horse", "mx-5 miata",
	"porsche 911 1970", "porsche 911", "subaru impreza", "supra mk4", "supra mk5",
]

## Fotos que vieram do lado oposto: o bico aponta para a ESQUERDA enquanto as
## outras 21 apontam para a direita. Sem espelhar, esses carros correm de costas.
## Espelhar inverte os emblemas deles, mas emblema ao contrario passa despercebido
## e carro andando de re nao.
const FLIP := ["kombi", "civic", "bmw m3", "subaru impreza"]


## Carro de cada perfil de motor do prototipo.
const BY_PROFILE := {
	"Torque": "mustang 1969",
	"Equilibrado": "golf gti",
	"Alta Rotacao": "supra mk4",
}


static func texture(car_name: String) -> Texture2D:
	return load(DIR + car_name + ".png") as Texture2D


static func random_name(rng: RandomNumberGenerator) -> String:
	return ALL[rng.randi() % ALL.size()]


static func flipped(car_name: String) -> bool:
	return car_name in FLIP
