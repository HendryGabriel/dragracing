class_name Passivo
extends RefCounted
## Item passivo (GDD 3.3). Fora do inventario, nunca desgasta, sempre ativo.
##
## Comum e percentual: mexe num numero que a build ja tinha. Raro DOBRA UMA REGRA
## -- e por isso que so cabem dois. Se coubessem quatro, o raro viraria mais um
## bonus somado; com dois slots, pegar um raro e sempre abrir mao de outra coisa.

const CATALOGO := [
	# --- comuns: percentuais ---
	{"id": "coletor", "nome": "Coletor curto", "raro": false,
		"desc": "+10% de forca na banda baixa"},
	{"id": "comando", "nome": "Comando bravo", "raro": false,
		"desc": "+10% de forca na banda alta"},
	{"id": "radiador", "nome": "Radiador maior", "raro": false,
		"desc": "-8% de geracao de calor"},
	{"id": "ventoinha", "nome": "Ventoinha extra", "raro": false,
		"desc": "+15% de resfriamento"},
	{"id": "garrafao", "nome": "Garrafao reserva", "raro": false,
		"desc": "+1.2s de nitro"},
	# --- raros: dobram uma regra ---
	{"id": "nitro_frio", "nome": "Nitro gelado", "raro": true,
		"desc": "os primeiros 4s de nitro nao geram calor"},
	{"id": "primeira_janela", "nome": "Marcha curta", "raro": true,
		"desc": "a janela verde da 1a troca e o dobro"},
	{"id": "perdao", "nome": "Cambio perdoador", "raro": true,
		"desc": "errar uma troca por corrida nao desgasta a transmissao"},
	{"id": "cravos", "nome": "Cravos escondidos", "raro": true,
		"desc": "largada na lama conta como asfalto"},
]

const NITRO_FRIO := 4.0

var id := ""
var nome := ""
var desc := ""
var raro := false


static func _do(d: Dictionary) -> Passivo:
	var p := Passivo.new()
	p.id = d.id
	p.nome = d.nome
	p.desc = d.desc
	p.raro = d.raro
	return p


## Raro e minoria de proposito: dobra de regra que cai toda hora deixa de dobrar
## regra nenhuma -- vira a regra.
static func sortear(rng: RandomNumberGenerator) -> Passivo:
	var quer_raro := rng.randf() < 0.30
	var pool: Array = []
	for d in CATALOGO:
		if d.raro == quer_raro:
			pool.append(d)
	return _do(pool[rng.randi() % pool.size()])


static func por_id(id_: String) -> Passivo:
	for d in CATALOGO:
		if d.id == id_:
			return _do(d)
	return null


func aplicar(c: Car, piso: String) -> void:
	match id:
		"coletor": c.bands[0] *= 1.10
		"comando": c.bands[2] *= 1.10
		"radiador": c.heat_rate *= 0.92
		"ventoinha": c.cool_rate *= 1.15
		"garrafao": c.nitro_cap += 1.2
		"nitro_frio": c.nitro_frio = NITRO_FRIO
		"primeira_janela": c.janela.x -= (c.janela.y - c.janela.x)
		"perdao": c.perdao_troca = true
		"cravos":
			if piso == "lama":
				c.piso_fases[0] = maxf(c.piso_fases[0], 1.0)
