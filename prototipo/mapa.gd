class_name Mapa
extends RefCounted
## O mapa da run (GDD 6). Ramificado, tres atos, chefe destrancado por reputacao.
##
## O que faz o mapa ser DECISAO e nao menu: cada no diz de antemao o piso e o
## arquetipo do rival, e nunca os numeros. Voce escolhe qual confronto a sua build
## ganha melhor -- nao qual recompensa e maior.
##
## Ramo nao percorrido nao volta: no consumido some, e essa e a moeda do mapa.

const LINHAS := 7          # linhas de nos antes do chefe, por ato
const META_REPUTACAO := 10 # trava do chefe
const LINHAS_EXTRA := 3    # trecho novo quando voce chega no chefe sem reputacao
const ATOS := 3

## Pisos dominantes por ato (GDD 6.1): cada ato tem uma dupla, o que da estacao
## certa ao pneu e deixa o jogador planejar dois trechos a frente.
const PISOS_DO_ATO := [
	["cidade", "pista"],
	["lama", "deserto"],
	["pista", "cidade", "deserto", "lama"],
]

## Peso de cada tipo de no. Oficina e boxes tem presenca garantida por linha fixa,
## entao aqui entram com peso baixo -- o resto do mapa e confronto.
const PESOS := {
	"racha": 46, "marcado": 16, "ferro": 12, "evento": 12, "oficina": 8, "boxes": 6,
}

var ato := 0
var linhas: Array = []      # Array[Array[Dictionary]]
var linha_atual := -1       # -1 = ainda nao entrou no mapa
var idx_atual := -1
var reputacao := 0
var rng := RandomNumberGenerator.new()


func gerar(ato_: int, corridas: int) -> void:
	ato = ato_
	reputacao = 0
	linha_atual = -1
	idx_atual = -1
	linhas = []
	var pisos: Array = PISOS_DO_ATO[mini(ato, PISOS_DO_ATO.size() - 1)]

	for l in LINHAS:
		var quantos := 2 + (1 if rng.randf() < 0.55 else 0)
		var linha: Array = []
		for i in quantos:
			linha.append(_no(l, pisos, corridas + l))
		linhas.append(linha)

	# O chefe e uma linha so, e fica trancado ate a reputacao chegar na meta.
	linhas.append([{
		"tipo": "chefe", "piso": pisos[0], "rival": Cars.sortear(rng, corridas + 20),
		"visitado": false,
	}])


func _no(linha: int, pisos: Array, corridas: int) -> Dictionary:
	var tipo := _sortear_tipo(linha)
	return {
		"tipo": tipo,
		"piso": pisos[rng.randi() % pisos.size()],
		"rival": Cars.sortear(rng, corridas + (6 if tipo == "marcado" else 0)),
		"visitado": false,
	}


## Oficina e boxes tem linha reservada: sem uma valvula garantida antes do chefe,
## o jogador chega quebrado e a run vira frustracao (GDD 6.2).
func _sortear_tipo(linha: int) -> String:
	if linha == 0:
		return "racha"
	if linha == 3:
		return "oficina"
	if linha == LINHAS - 1:
		return "boxes"
	var total := 0
	for t in PESOS:
		total += PESOS[t]
	var r := rng.randi() % total
	for t in PESOS:
		r -= PESOS[t]
		if r < 0:
			return t
	return "racha"


## Para onde o no (l, i) leva na linha seguinte. O mapa ramifica, mas nao
## teleporta: so vizinhos. E essa funcao que desenha os ramos na tela tambem --
## sem as ligacoes visiveis, o mapa vira uma grade de pontos e a rota some.
func ligacoes(l: int, i: int) -> Array:
	var prox := l + 1
	if prox >= linhas.size():
		return []
	var destino: Array = linhas[prox]
	var centro := int(round(float(i) / maxf(linhas[l].size() - 1, 1)
		* maxf(destino.size() - 1, 1)))
	var saida: Array = []
	for j in destino.size():
		if absi(j - centro) <= 1:
			saida.append(j)
	return saida


## Nos alcancaveis a partir de onde voce esta. Da primeira vez, a linha 0 inteira.
func alcancaveis() -> Array:
	if linha_atual < 0:
		return range(linhas[0].size())
	return ligacoes(linha_atual, idx_atual)


func linha_alvo() -> int:
	return 0 if linha_atual < 0 else linha_atual + 1


func no_atual() -> Dictionary:
	if linha_atual < 0 or linha_atual >= linhas.size():
		return {}
	return linhas[linha_atual][idx_atual]


func chefe_liberado() -> bool:
	return reputacao >= META_REPUTACAO


## Entrar num no o consome. Perder nao devolve: e isso que faz a rota custar.
func entrar(idx: int) -> Dictionary:
	linha_atual = linha_alvo()
	idx_atual = idx
	var no: Dictionary = linhas[linha_atual][idx]
	no.visitado = true
	return no


func premiar(tipo: String) -> void:
	reputacao += Tuning.REPUTACAO_MARCADO if tipo == "marcado" \
		else Tuning.REPUTACAO_RACHA


## Chegou na porta do chefe sem reputacao. O GDD 6.1 chama isso de "farmar mais":
## nao e beco sem saida, e um trecho novo antes do chefe. O preco de farmar e o
## desgaste que vem junto -- e o chefe nao espera parado, porque o rival escala.
func precisa_esticar() -> bool:
	return linha_alvo() == linhas.size() - 1 and not chefe_liberado()


func esticar(corridas: int) -> void:
	var chefe: Array = linhas[linhas.size() - 1]
	var pisos: Array = PISOS_DO_ATO[mini(ato, PISOS_DO_ATO.size() - 1)]
	linhas = []
	for l in LINHAS_EXTRA:
		var quantos := 2 + (1 if rng.randf() < 0.5 else 0)
		var linha: Array = []
		for i in quantos:
			# Trecho de farm e so confronto: quem esticou precisa de reputacao,
			# nao de mais uma loja.
			linha.append({
				"tipo": "marcado" if rng.randf() < 0.35 else "racha",
				"piso": pisos[rng.randi() % pisos.size()],
				"rival": Cars.sortear(rng, corridas + 4),
				"visitado": false,
			})
		linhas.append(linha)
	linhas.append(chefe)
	linha_atual = -1
	idx_atual = -1


func acabou_o_ato() -> bool:
	return linha_atual >= linhas.size() - 1
