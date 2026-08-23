class_name Progresso
extends RefCounted
## O que sobrevive ao fim da run (GDD 7).
##
## Só desbloqueio de acervo, nunca poder permanente comprável. A escada de carros
## já é a progressão de força; empilhar upgrades permanentes em cima significaria
## duas escadas subindo juntas, e o rival do ato 1 teria que ser facil para o
## carro fraco sem espelho e ainda relevante para o forte com espelho cheio --
## dificuldade adaptativa por acidente, que o GDD 3.5 rejeita.
##
## Derrota tambem rende: os marcos sao atrelados ao que voce FEZ, nao ao que voce
## venceu. Roguelike onde derrota rende zero faz o jogador desistir na 4a run.

const ARQUIVO := "user://progresso.json"

## Onde este progresso mora. E variavel, e nao constante, para a checagem poder
## escrever num arquivo proprio: teste que grava no save do jogador destroi
## progresso real, e foi exatamente o que aconteceu na primeira rodada.
var arquivo := ARQUIVO

## Cada marco desbloqueia uma coisa. "carro" abre o proximo da escada; "reserva"
## abre um espaco de inventario, ate o teto do GDD 3.6.
const MARCOS := [
	{"id": "primeira_run", "desc": "termine uma run", "premio": "carro"},
	{"id": "marcado", "desc": "vença um rival marcado", "premio": "carro"},
	{"id": "ato2", "desc": "chegue ao ato 2", "premio": "reserva"},
	{"id": "fundir3", "desc": "funda 3 motores", "premio": "carro"},
	{"id": "corridas20", "desc": "corra 20 vezes numa run só", "premio": "reserva"},
	{"id": "chefe", "desc": "derrote um chefe", "premio": "carro"},
	{"id": "ato3", "desc": "chegue ao ato 3", "premio": "reserva"},
	{"id": "run_vencida", "desc": "vença uma run", "premio": "carro"},
	{"id": "fundir10", "desc": "funda 10 motores", "premio": "reserva"},
]

const RESERVA_TETO := 6

var liberados: Array = []      # carros disponiveis
var reservas := 2
var feitos: Array = []         # ids de marcos ja batidos
var contadores: Dictionary = {}
var novidades: Array = []      # o que acabou de abrir, para a tela mostrar


func _init() -> void:
	liberados = _iniciais()


## O elenco comeca no degrau de baixo: tier 1 inteiro. E a escada do GDD 3.5 --
## carro forte se conquista, nao se escolhe na primeira tela.
static func _iniciais() -> Array:
	var lista: Array = []
	for nome in Cars.elenco():
		if Cars.tier(nome) <= 1:
			lista.append(nome)
	return lista


func liberado(carro: String) -> bool:
	return carro in liberados


func _proximo_carro() -> String:
	for nome in Cars.elenco():
		if not (nome in liberados):
			return nome
	return ""


## Conta um evento e devolve o que abriu por causa dele. Marcos sao checados na
## hora, nao no fim: a run pode acabar de repente, e progresso perdido por
## timing seria a pior forma de nao render nada.
func registrar(evento: String, quanto := 1) -> Array:
	contadores[evento] = int(contadores.get(evento, 0)) + quanto
	novidades = []
	for m in MARCOS:
		if m.id in feitos:
			continue
		if not _bateu(m.id):
			continue
		feitos.append(m.id)
		if m.premio == "carro":
			var c := _proximo_carro()
			if not c.is_empty():
				liberados.append(c)
				novidades.append("carro novo: %s (%d cv)" % [c, Cars.cavalos(c)])
		else:
			if reservas < RESERVA_TETO:
				reservas += 1
				novidades.append("inventario: %d espaços de reserva" % reservas)
	if not novidades.is_empty():
		salvar()
	return novidades


func _bateu(id: String) -> bool:
	var c := contadores
	match id:
		"primeira_run": return int(c.get("run", 0)) >= 1
		"marcado": return int(c.get("marcado", 0)) >= 1
		"ato2": return int(c.get("ato", 0)) >= 2
		"ato3": return int(c.get("ato", 0)) >= 3
		"fundir3": return int(c.get("fundir", 0)) >= 3
		"fundir10": return int(c.get("fundir", 0)) >= 10
		"corridas20": return int(c.get("corridas_run", 0)) >= 20
		"chefe": return int(c.get("chefe", 0)) >= 1
		"run_vencida": return int(c.get("run_vencida", 0)) >= 1
	return false


## "ato" e "corridas_run" sao marcas de recorde, nao somas: chegar ao ato 2 duas
## vezes nao e chegar ao ato 4.
func marcar_recorde(evento: String, valor: int) -> Array:
	if int(contadores.get(evento, 0)) >= valor:
		return []
	contadores[evento] = valor - 1
	return registrar(evento, 1)


func salvar() -> void:
	var f := FileAccess.open(arquivo, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"liberados": liberados, "reservas": reservas,
		"feitos": feitos, "contadores": contadores,
	}, "\t"))


func carregar() -> void:
	if not FileAccess.file_exists(arquivo):
		return
	var f := FileAccess.open(arquivo, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return
	liberados = d.get("liberados", _iniciais())
	reservas = int(d.get("reservas", 2))
	feitos = d.get("feitos", [])
	contadores = d.get("contadores", {})
	# Carro que saiu do elenco (arte removida) nao pode travar o save.
	var validos: Array = []
	for nome in liberados:
		if Cars.ROSTER.has(nome):
			validos.append(nome)
	liberados = validos if not validos.is_empty() else _iniciais()


## Proximo marco ainda em aberto, para a tela dizer o que perseguir.
func proximo_marco() -> String:
	for m in MARCOS:
		if not (m.id in feitos):
			return m.desc
	return "tudo desbloqueado"
