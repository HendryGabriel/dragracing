class_name Cars
## Registro das carrocerias. No vocabulario do GDD, a carroceria E o carro.
##
## A arte e foto 3/4 frontal, branca (aceita pintura por modulate) e SEM RODAS:
## as caixas de roda estao vazias de proposito, porque Roda e um slot de
## equipamento proprio e entra como arte separada por cima.

const DIR := "res://cars/"

## Fotos que vieram do lado oposto: o bico aponta para a ESQUERDA enquanto as
## outras 21 apontam para a direita. Sem espelhar, esses carros correm de costas.
## Espelhar inverte os emblemas deles, mas emblema ao contrario passa despercebido
## e carro andando de re nao.
const FLIP := ["kombi", "civic", "bmw m3", "subaru impreza"]


## O elenco, em potencia DE FABRICA e sem modificacao. Cada carro entra com dois
## dados honestos -- cavalos originais e carater do motor -- e o resto e derivado.
## Assim ninguem precisa inventar tres numeros por carro, e a escada de forca sai
## da realidade em vez de sair do gosto de quem balanceou.
##
## "cv" e a potencia de catalogo da versao indicada no comentario. Onde o modelo
## teve varias versoes, vale a que a foto aparenta.
const ROSTER := {
	"fusca":              {"cv": 50, "carater": "torque"},        # 1600, ar
	"kombi":              {"cv": 50, "carater": "torque"},        # T2 1600
	"brasilia":           {"cv": 58, "carater": "torque"},
	"chevette":           {"cv": 73, "carater": "equilibrado"},   # 1.6
	"mx-5 miata":         {"cv": 116, "carater": "alta"},         # NA 1.6
	"Initial D carro":    {"cv": 128, "carater": "alta"},         # AE86, 4A-GE
	"civic":              {"cv": 158, "carater": "equilibrado"},  # 2.0 aspirado
	"porsche 911 1970":   {"cv": 180, "carater": "alta"},         # 911S 2.2
	"subaru impreza":     {"cv": 227, "carater": "equilibrado"},  # WRX turbo
	"golf gti":           {"cv": 241, "carater": "equilibrado"},  # Mk8
	"supra mk4":          {"cv": 276, "carater": "turbo"},        # 2JZ-GTE
	"mustang 1969":       {"cv": 290, "carater": "torque"},       # Mach 1 351
	"lancer evo x":       {"cv": 291, "carater": "equilibrado"},  # GSR
	"bmw m3":             {"cv": 333, "carater": "alta"},         # E46 S54
	"dodge charger 1970": {"cv": 375, "carater": "torque"},       # R/T 440
	"porsche 911":        {"cv": 379, "carater": "turbo"},        # 992 Carrera
	"supra mk5":          {"cv": 382, "carater": "turbo"},        # A90 3.0
	"mustang 2018":       {"cv": 460, "carater": "torque"},       # GT 5.0
	"ferrari f40":        {"cv": 471, "carater": "turbo"},
	"mustang dark horse": {"cv": 500, "carater": "torque"},
	"R35":                {"cv": 565, "carater": "equilibrado"},  # GT-R, tracao integral
	"audi r8":            {"cv": 602, "carater": "alta"},         # V10 aspirado
	"lamborguini":        {"cv": 690, "carater": "alta"},         # Aventador V12
	"mclaren senna":      {"cv": 789, "carater": "turbo"},
	"demon challenger":   {"cv": 808, "carater": "torque"},       # SRT Demon
}

## O carater decide o FORMATO da curva; a potencia decide o tamanho dela. Um V8
## grande empurra na largada e morre no topo; um turbo grande faz o contrario.
## Cada carater ganha um ganho proprio para EMPATAR em potencia igual. Nao e
## enfeite: concentrar potencia na banda alta rende menos que espalhar, porque o
## arrasto come o ganho la em cima. Sem compensar isso, escolher turbo seria
## sempre pior e o carater deixaria de ser escolha.
const PESOS := {
	"torque":      [1.31, 1.06, 0.64],
	"equilibrado": [1.00, 1.00, 1.00],
	"alta":        [0.78, 1.03, 1.30],
	"turbo":       [0.68, 1.04, 1.59],
}

## Cavalos -> altura da curva. A escala e comprimida de proposito: um Fusca de 50
## cv contra uma Senna de 789 na proporcao real seria intransitavel, e o GDD 3.5
## pede que carro fraco ainda consiga zerar "com certa dificuldade".
static func texture(car_name: String) -> Texture2D:
	return load(DIR + car_name + ".png") as Texture2D


static func _altura(cv: int) -> float:
	return 34.0 + 62.0 * pow(float(cv) / 500.0, 0.55)


## Curva de qualquer combinacao potencia + carater. Separada de bandas() porque
## as checagens precisam comparar CARATERES na mesma potencia -- se compararem
## dois carros reais, medem cavalo em vez de formato.
static func curva(cv: int, carater: String) -> Array:
	var h := _altura(cv)
	var w: Array = PESOS[carater]
	return [snappedf(h * w[0], 0.1), snappedf(h * w[1], 0.1), snappedf(h * w[2], 0.1)]


static func bandas(nome: String) -> Array:
	if not ROSTER.has(nome):
		return [70.0, 70.0, 70.0]
	return curva(int(ROSTER[nome].cv), ROSTER[nome].carater)


## Tier tambem sai da potencia de fabrica, nao de opiniao.
static func tier(nome: String) -> int:
	if not ROSTER.has(nome):
		return 1
	var cv: int = ROSTER[nome].cv
	if cv < 150:
		return 1
	elif cv < 400:
		return 2
	return 3


static func cavalos(nome: String) -> int:
	return int(ROSTER[nome].cv) if ROSTER.has(nome) else 0


## O elenco em ordem de escada: do mais fraco de fabrica ao mais forte.
static func elenco() -> Array:
	var nomes: Array = ROSTER.keys()
	nomes.sort_custom(func(a, b): return ROSTER[a].cv < ROSTER[b].cv)
	return nomes



## Rival de um tier compativel com o momento da sequencia: os primeiros nos vem
## de baixo da escada, e ela sobe junto com voce.
static func sortear(rng: RandomNumberGenerator, corridas: int) -> String:
	var teto := 1 + int(corridas / 5)
	var pool: Array = []
	for nome in ROSTER:
		if tier(nome) <= teto:
			pool.append(nome)
	if pool.is_empty():
		pool = ROSTER.keys()
	return pool[rng.randi() % pool.size()]


static func flipped(car_name: String) -> bool:
	return car_name in FLIP
