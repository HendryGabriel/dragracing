class_name Hud
extends Control
## HUD desenhado em modo imediato.
##
## Assinatura: a ARVORE DE LARGADA. As lampadas da arvore sao a linguagem visual
## de todo o painel -- largada, janela de troca e limite termico usam a mesma
## lampada, na mesma sequencia ambar -> verde -> vermelho da pista real. Nada de
## retangulo arredondado generico: os recortes sao chanfrados, como decalque e
## painel de competicao.
##
## Paleta quente de noite de autodromo. O nitro e o unico elemento frio do
## painel, de proposito: e o oposto do calor, e essa oposicao e o que o jogador
## precisa ler na fase 3.

const INK := Color(0.055, 0.048, 0.043, 0.90)
const SURFACE := Color(0.10, 0.092, 0.084, 0.92)
const EDGE := Color(0.26, 0.235, 0.205)
const TEXT := Color(0.95, 0.93, 0.89)
const DIM := Color(0.53, 0.50, 0.45)
const AMBER := Color(1.0, 0.69, 0.12)
const GREEN := Color(0.22, 0.86, 0.33)
const RED := Color(1.0, 0.25, 0.17)
const COLD := Color(0.42, 0.80, 1.0)

var st: Dictionary = {}
var font: Font


func _init() -> void:
	# A fonte nasce no construtor, nao no _ready: assim o painel nunca existe num
	# estado em que desenhar seria ilegal.
	var f := SystemFont.new()
	# Bahnschrift e o DIN 1451 que a Microsoft distribui: face de instrumento e de
	# sinalizacao viaria, nao um grotesco neutro de prateleira.
	f.font_names = PackedStringArray(["Bahnschrift", "DIN Condensed", "Segoe UI"])
	font = f
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func feed(state: Dictionary) -> void:
	st = state
	# Control dentro de CanvasLayer nao herda tamanho do pai: sem isto o painel
	# fica 0x0 e todo corpo de fonte vira zero.
	if is_inside_tree():
		size = get_viewport_rect().size
	queue_redraw()


# ---------------------------------------------------------------- primitivas

## Poligono de cantos chanfrados. E a geometria propria do painel: canto cortado
## em 45 graus, nunca raio arredondado.
func _cham(r: Rect2, cut: float) -> PackedVector2Array:
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	return PackedVector2Array([
		Vector2(x + cut, y), Vector2(x + w - cut, y),
		Vector2(x + w, y + cut), Vector2(x + w, y + h - cut),
		Vector2(x + w - cut, y + h), Vector2(x + cut, y + h),
		Vector2(x, y + h - cut), Vector2(x, y + cut),
	])


func _panel(r: Rect2, cut: float, fill: Color, line: Color) -> void:
	var p := _cham(r, cut)
	draw_colored_polygon(p, fill)
	var loop := p.duplicate()
	loop.append(p[0])
	draw_polyline(loop, line, 1.5, true)


## Texto centrado de verdade: usa ascent/descent reais, nao meia altura chutada.
func _text(center: Vector2, s: String, size_px: int, col: Color,
		halign := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var x := center.x
	if halign == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif halign == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	var baseline := center.y + (font.get_ascent(size_px) - font.get_descent(size_px)) * 0.5
	draw_string(font, Vector2(x, baseline), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


## Rotulo de mostrador: caixa alta espacada, pequena. Tratamento reservado SO
## para rotulo de instrumento -- o resto do painel usa caixa normal.
func _micro(center: Vector2, s: String, col: Color, size_px: int) -> void:
	var spaced := ""
	for i in s.length():
		spaced += s[i]
		if i < s.length() - 1:
			spaced += " "
	_text(center, spaced, size_px, col)


## A lampada da arvore. Apagada e um anel; acesa e um disco com o anel por cima.
func _lamp(c: Vector2, radius: float, col: Color, lit: bool) -> void:
	if lit:
		draw_circle(c, radius, col)
		draw_arc(c, radius, 0, TAU, 32, col.lightened(0.35), 1.6, true)
	else:
		draw_circle(c, radius, Color(col.r, col.g, col.b, 0.09))
		draw_arc(c, radius, 0, TAU, 32, Color(col.r, col.g, col.b, 0.30), 1.4, true)


# ---------------------------------------------------------------- desenho

func _draw() -> void:
	if st.is_empty() or font == null:
		return
	var s: float = maxf(size.y / 720.0, 0.35)

	match int(st.get("state", 0)):
		2:  # RACING
			_draw_gap(s)
			_draw_estado(s)
			_draw_cluster(s)
			_draw_flash(s)
		1:  # STAGING
			_draw_tree(s)
			_draw_flash(s)
		5:  # GARAGEM
			_draw_garagem(s)
		0:  # MENU
			_draw_menu(s)
		_:
			_draw_card(s)


## Cluster inferior: marcha | faixa de lampadas | velocidade, numa peca so.
func _draw_cluster(s: float) -> void:
	var w := 764.0 * s
	var h := 112.0 * s
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y - h - 26.0 * s, w, h)
	_panel(r, 16.0 * s, SURFACE, EDGE)

	var gear_cx := r.position.x + 80.0 * s
	var speed_cx := r.position.x + w - 80.0 * s
	var label_y := r.position.y + 24.0 * s
	var value_y := r.position.y + 68.0 * s

	_micro(Vector2(gear_cx, label_y), "MARCHA", DIM, int(11 * s))
	_text(Vector2(gear_cx, value_y), str(st.gear), int(58 * s), TEXT)

	_micro(Vector2(speed_cx, label_y), "KM/H", DIM, int(11 * s))
	_text(Vector2(speed_cx, value_y), "%.0f" % st.speed, int(48 * s), TEXT)

	for dx in [160.0, w - 160.0]:
		var lx: float = r.position.x + dx * s
		draw_line(Vector2(lx, r.position.y + 20.0 * s),
			Vector2(lx, r.position.y + h - 20.0 * s), Color(EDGE, 0.6), 1.0, true)

	var inner_x := r.position.x + 186.0 * s
	var inner_w := w - 372.0 * s
	_draw_lamps(Rect2(inner_x, r.position.y + 22.0 * s, inner_w, 26.0 * s), s)
	_draw_gauges(Rect2(inner_x, r.position.y + 66.0 * s, inner_w, 26.0 * s), s)


## Estado das pecas. Enche na direcao do perigo, igual a barra de calor -- e o
## mesmo idioma: quanto mais cheia, maior a chance de quebrar. Desgaste NAO tira
## desempenho, entao a barra e aviso, nunca penalidade ja aplicada.
func _draw_estado(s: float) -> void:
	var w := 420.0 * s
	var h := 30.0 * s
	var cluster_top := size.y - 112.0 * s - 26.0 * s
	var r := Rect2(size.x * 0.5 - w * 0.5, cluster_top - h - 10.0 * s, w, h)
	_panel(r, 10.0 * s, Color(SURFACE, 0.80), Color(EDGE, 0.7))

	var bar_w := 110.0 * s
	var bar_h := 9.0 * s
	var cy := r.position.y + h * 0.5
	var pares := [
		["MOTOR", float(st.get("desg_motor", 0.0)), false],
		["CAMBIO", float(st.get("desg_cambio", 0.0)), bool(st.get("travado", false))],
	]
	for i in pares.size():
		var rotulo: String = pares[i][0]
		var d: float = clampf(pares[i][1], 0.0, 1.0)
		var quebrado: bool = pares[i][2]
		var bx := r.position.x + (16.0 + i * 216.0) * s
		_micro(Vector2(bx + 28.0 * s, cy), rotulo, DIM, int(10 * s))

		var br := Rect2(bx + 62.0 * s, cy - bar_h * 0.5, bar_w, bar_h)
		draw_colored_polygon(_cham(br, 3.0 * s), Color(0.0, 0.0, 0.0, 0.40))
		var col := TEXT
		if quebrado or d >= 0.70:
			col = RED
		elif d >= 0.34:
			col = AMBER
		var f := 1.0 if quebrado else d
		if f > 0.001:
			draw_colored_polygon(_cham(
				Rect2(br.position, Vector2(maxf(bar_w * f, 6.0 * s), bar_h)), 3.0 * s), col)
		if quebrado:
			_text(Vector2(br.position.x + bar_w + 30.0 * s, cy), "QUEBRADO", int(13 * s), RED)


## Faixa de giro em lampadas: ambar subindo, verde na janela de troca, vermelho
## depois do corte. Mesma sequencia da arvore de largada.
func _draw_lamps(r: Rect2, s: float) -> void:
	var n := 17
	var rpm: float = clampf(st.rpm, 0.0, 1.15)
	var g0: float = st.perfect_lo
	var g1: float = st.perfect_hi
	var rad := 8.0 * s
	var step := r.size.x / float(n - 1)
	var cy := r.position.y + r.size.y * 0.5
	var in_window: bool = rpm >= g0 and rpm <= g1

	for i in n:
		var v := (float(i) / float(n - 1)) * 1.15
		var col := AMBER
		if v > g1:
			col = RED
		elif v >= g0:
			col = GREEN
		var lit := rpm >= v
		# na janela perfeita a faixa acesa inteira vira verde: o sinal de trocar
		# agora tem que ser impossivel de perder pela visao periferica.
		if in_window and lit:
			col = GREEN
		_lamp(Vector2(r.position.x + i * step, cy), rad, col, lit)


func _draw_gauges(r: Rect2, s: float) -> void:
	var bar_h := 12.0 * s
	var half := r.size.x * 0.5 - 16.0 * s
	var bar_y := r.position.y + 12.0 * s

	var heat_r := Rect2(r.position.x, bar_y, half, bar_h)
	var nit_r := Rect2(r.position.x + r.size.x - half, bar_y, half, bar_h)

	_micro(Vector2(heat_r.position.x + half * 0.5, r.position.y - 1.0 * s),
		"CALOR", DIM, int(10 * s))
	_micro(Vector2(nit_r.position.x + half * 0.5, r.position.y - 1.0 * s),
		"NITRO", DIM, int(10 * s))

	draw_colored_polygon(_cham(heat_r, 4.0 * s), Color(0.0, 0.0, 0.0, 0.38))
	var hf: float = clampf(st.heat / 1.15, 0.0, 1.0)
	var hcol := AMBER
	if st.over:
		# pulsa somente quando ha risco real de fundir: e informacao, nao enfeite
		hcol = RED.lerp(TEXT, 0.20 + 0.20 * sin(float(st.t) * 12.0))
	if hf > 0.001:
		draw_colored_polygon(_cham(
			Rect2(heat_r.position, Vector2(maxf(half * hf, 9.0 * s), bar_h)), 4.0 * s), hcol)
	var lim_x := heat_r.position.x + half * (float(st.heat_limit) / 1.15)
	draw_line(Vector2(lim_x, heat_r.position.y - 4.0 * s),
		Vector2(lim_x, heat_r.position.y + bar_h + 4.0 * s), RED, 2.0, true)

	draw_colored_polygon(_cham(nit_r, 4.0 * s), Color(0.0, 0.0, 0.0, 0.38))
	var nf: float = clampf(st.nitro, 0.0, 1.0)
	if nf > 0.001:
		draw_colored_polygon(_cham(
			Rect2(nit_r.position, Vector2(maxf(half * nf, 9.0 * s), bar_h)), 4.0 * s),
			Color(COLD, 0.62))


## Leitura de posicao: numero para a precisao, trilho para a visao periferica.
func _draw_gap(s: float) -> void:
	var gap: float = st.gap
	var cx := size.x * 0.5
	var col := GREEN if gap >= 0.0 else RED
	_text(Vector2(cx, 48.0 * s), "%+.1f m" % gap, int(42 * s), col)

	var rail_w := 380.0 * s
	var y := 92.0 * s
	draw_line(Vector2(cx - rail_w * 0.5, y), Vector2(cx + rail_w * 0.5, y),
		Color(EDGE, 0.9), 2.0, true)
	draw_line(Vector2(cx, y - 7.0 * s), Vector2(cx, y + 7.0 * s), Color(EDGE, 0.9), 2.0, true)

	var k: float = clampf(gap / 60.0, -1.0, 1.0)
	_lamp(Vector2(cx - k * rail_w * 0.5, y), 5.0 * s, DIM, true)
	_lamp(Vector2(cx + k * rail_w * 0.5, y), 7.5 * s, col, true)

	_text(Vector2(cx, 122.0 * s),
		"%s   ·   %.0f de %.0f m" % [st.phase, st.pos, st.dist], int(18 * s), DIM)
	_text(Vector2(cx, 146.0 * s), "corrida %d   ·   %d vitorias"
		% [int(st.get("corrida", 1)), int(st.get("vitorias", 0))], int(15 * s), DIM)


## A arvore de largada, a assinatura do painel: as tres ambares sobem com o giro
## e a verde acende dentro da janela -- solte nela.
func _draw_tree(s: float) -> void:
	var cx := size.x * 0.5
	var w := 96.0 * s
	var h := 292.0 * s
	var r := Rect2(cx - w * 0.5, size.y * 0.44 - h * 0.5, w, h)
	_panel(r, 14.0 * s, Color(INK, 0.62), Color(EDGE, 0.85))

	var rev: float = st.rev
	var lo: float = st.launch_lo
	var hi: float = st.launch_hi
	var rad := 17.0 * s
	var top := r.position.y + 54.0 * s
	var gap_y := 50.0 * s

	for i in 2:
		_lamp(Vector2(cx - 18.0 * s + i * 36.0 * s, r.position.y + 22.0 * s),
			5.0 * s, TEXT, true)

	for i in 3:
		var limiar := lo * (float(i) + 1.0) / 3.0
		_lamp(Vector2(cx, top + i * gap_y), rad, AMBER, rev >= limiar)

	_lamp(Vector2(cx, top + 3 * gap_y), rad, GREEN, rev >= lo and rev <= hi)
	_lamp(Vector2(cx, top + 4 * gap_y), rad * 0.6, RED, rev > hi)

	var dica := "SEGURE"
	var dcol := DIM
	if rev >= lo and rev <= hi:
		dica = "SOLTE"
		dcol = GREEN
	elif rev > hi:
		dica = "PASSOU DO PONTO"
		dcol = RED
	_text(Vector2(cx, r.position.y + h + 34.0 * s), dica, int(24 * s), dcol)
	_text(Vector2(cx, r.position.y + h + 64.0 * s), st.matchup, int(18 * s), DIM)


func _draw_flash(s: float) -> void:
	var a: float = st.flash_a
	var f: String = st.flash
	if a <= 0.001 or f.is_empty():
		return
	var col := TEXT
	if f.contains("PERFEITA"):
		col = GREEN
	elif f.contains("RUIM") or f.contains("FUNDIU") or f.contains("PASSOU"):
		col = RED
	elif f.contains("AFOGOU") or f.contains("PATINOU"):
		col = AMBER
	_text(Vector2(size.x * 0.5, size.y * 0.5 - 124.0 * s), f, int(44 * s), Color(col, a))


## As tres bandas como barras. E a forma do carro: torque desenha uma escada
## descendo, alta rotacao a mesma escada subindo. Usada no menu E na garagem, de
## proposito -- uma linguagem so, aprendida uma vez.
func _barras_banda(x: float, y: float, w: float, bandas: Array, s: float,
		altura := 14.0, passo := 30.0, corpo := 17) -> float:
	var nomes := ["baixa", "media", "alta"]
	for i in 3:
		var v: float = clampf(float(bandas[i]) / 130.0, 0.0, 1.0)
		_text(Vector2(x, y), nomes[i], int(corpo * 0.88), DIM, HORIZONTAL_ALIGNMENT_LEFT)
		var br := Rect2(x + 58.0 * s, y - altura * 0.5 * s, w, altura * s)
		draw_colored_polygon(_cham(br, 4.0 * s), Color(0.0, 0.0, 0.0, 0.40))
		draw_colored_polygon(_cham(
			Rect2(br.position, Vector2(maxf(w * v, 6.0 * s), altura * s)), 4.0 * s), TEXT)
		_text(Vector2(x + 58.0 * s + w + 32.0 * s, y), "%.0f" % bandas[i], int(corpo), TEXT)
		y += passo * s
	return y


## Vitrine de escolha de carro. O carro esta na CENA, atras deste painel -- e por
## isso que aqui nao ha escurecimento de tela cheia: escurecer tudo esconderia
## justamente o que o jogador esta escolhendo.
##
## O elenco tem 25 carros, entao a lista corre numa janela em volta do escolhido:
## mostrar os 25 de uma vez daria uma parede de nomes em corpo minusculo.
func _draw_menu(s: float) -> void:
	var w := 470.0 * s
	var h := 462.0 * s
	var r := Rect2(64.0 * s, size.y * 0.5 - h * 0.5 + 18.0 * s, w, h)
	_panel(r, 20.0 * s, Color(INK, 1.0), EDGE)  # opaco: poste atras vazava

	_text(Vector2(r.position.x + 30.0 * s, r.position.y - 42.0 * s), "ARRANCADA",
		int(44 * s), TEXT, HORIZONTAL_ALIGNMENT_LEFT)

	var opcoes: Array = st.get("opcoes", [])
	var sel: int = int(st.get("sel", 0))
	var n := opcoes.size()
	var janela := 7
	var ini: int = clampi(sel - janela / 2, 0, maxi(0, n - janela))
	var fim: int = mini(n, ini + janela)

	var lx := r.position.x + 32.0 * s
	_micro(Vector2(lx + 44.0 * s, r.position.y + 34.0 * s), "ELENCO", DIM, int(11 * s))
	_text(Vector2(r.position.x + w - 32.0 * s, r.position.y + 34.0 * s),
		"%d de %d" % [sel + 1, n], int(14 * s), DIM, HORIZONTAL_ALIGNMENT_RIGHT)

	var y := r.position.y + 68.0 * s
	for i in range(ini, fim):
		var nome: String = opcoes[i][0]
		var ficha: String = opcoes[i][1]
		var bandas: Array = opcoes[i][2]
		var ativo := i == sel

		_lamp(Vector2(lx, y), 7.0 * s, AMBER if ativo else DIM, ativo)
		_text(Vector2(lx + 22.0 * s, y), nome, int(23 * s if ativo else 19 * s),
			TEXT if ativo else DIM, HORIZONTAL_ALIGNMENT_LEFT)
		if ativo:
			_text(Vector2(lx + 22.0 * s, y + 21.0 * s), ficha, int(15 * s), DIM,
				HORIZONTAL_ALIGNMENT_LEFT)
			_barras_banda(lx + 22.0 * s, y + 50.0 * s, 150.0 * s, bandas, s,
				11.0, 23.0, 14)
			y += 126.0 * s
		else:
			y += 34.0 * s

	_text(Vector2(lx, r.position.y + h - 26.0 * s),
		"setas escolhem   ·   ESPACO confirma", int(17 * s), DIM,
		HORIZONTAL_ALIGNMENT_LEFT)


## A garagem. Nao e uma lista de pecas: o que precisa ser lido aqui e a FORMA do
## carro -- tres barras de banda em que um motor de torque desenha uma escada
## descendo e um de alta rotacao a mesma escada subindo. A lista e o detalhe.
func _draw_garagem(s: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.026, 0.022, 0.86))
	var w := 960.0 * s
	var h := 452.0 * s
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y * 0.5 - h * 0.5, w, h)
	_panel(r, 22.0 * s, SURFACE, EDGE)

	_text(Vector2(size.x * 0.5, r.position.y + 44.0 * s), "GARAGEM", int(32 * s), TEXT)

	# ---- coluna esquerda: os cinco slots ----
	var lx := r.position.x + 46.0 * s
	var y := r.position.y + 96.0 * s
	_micro(Vector2(lx + 44.0 * s, y), "EQUIPADO", DIM, int(11 * s))
	y += 30.0 * s
	for linha in st.get("equipadas", []):
		var slot: String = linha[0]
		var texto: String = linha[1]
		var efeito: String = linha[2]
		var vazio := texto == "-"
		_text(Vector2(lx, y), slot, int(17 * s), DIM, HORIZONTAL_ALIGNMENT_LEFT)
		_text(Vector2(lx + 126.0 * s, y), "vazio" if vazio else texto, int(19 * s),
			DIM if vazio else TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		if not vazio:
			_text(Vector2(lx + 126.0 * s, y + 21.0 * s), efeito, int(15 * s), DIM,
				HORIZONTAL_ALIGNMENT_LEFT)
		y += 46.0 * s

	# ---- coluna direita: a forma do carro ----
	var rx := r.position.x + 600.0 * s
	var by := r.position.y + 96.0 * s
	_micro(Vector2(rx + 52.0 * s, by), "FORMA DO CARRO", DIM, int(11 * s))
	by += 34.0 * s
	by = _barras_banda(rx, by, 210.0 * s, st.get("bandas", [70.0, 70.0, 70.0]), s)

	by += 12.0 * s
	var janela: Vector2 = st.get("janela", Vector2(0.9, 1.02))
	var detalhes := [
		"limite termico   %.0f%%" % (float(st.get("heat_limit", 0.8)) * 100.0),
		"janela de troca   %.0f%%" % ((janela.y - janela.x) * 100.0),
		"tanque de nitro   %.1fs" % float(st.get("nitro_cap", 6.0)),
	]
	for d in detalhes:
		_text(Vector2(rx, by), d, int(15 * s), DIM, HORIZONTAL_ALIGNMENT_LEFT)
		by += 22.0 * s

	# ---- reserva ----
	by += 14.0 * s
	_micro(Vector2(rx + 40.0 * s, by), "RESERVA", DIM, int(11 * s))
	by += 28.0 * s
	var reserva: Array = st.get("reserva", [])
	for i in 2:
		var cheia: bool = i < reserva.size()
		_lamp(Vector2(rx + 8.0 * s, by), 6.0 * s, TEXT if cheia else DIM, cheia)
		var rot := "%d  %s" % [i + 1, reserva[i][0] if cheia else "vazia"]
		_text(Vector2(rx + 26.0 * s, by), rot, int(17 * s),
			TEXT if cheia else DIM, HORIZONTAL_ALIGNMENT_LEFT)
		by += 26.0 * s

	# O aviso conta o que aconteceu com a peca substituida. Sem ele o jogador perde
	# uma peca para a sucata sem nunca ficar sabendo.
	var aviso: String = st.get("aviso", "")
	if not aviso.is_empty():
		var cor := RED if aviso.contains("sucata") else AMBER
		_text(Vector2(size.x * 0.5, r.position.y + h - 62.0 * s), aviso, int(17 * s), cor)

	_text(Vector2(size.x * 0.5, r.position.y + h - 32.0 * s),
		"1 / 2 troca com a reserva   ·   ESPACO corre", int(18 * s), DIM)


## Cartao de menu / resultado. Hierarquia por escala e cor, sem enfeite.
## Linha comecando com "~" e secundaria.
func _draw_card(s: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.026, 0.022, 0.84))

	var lines: Array = st.get("lines", [])
	var table: Array = st.get("table", [])
	var w: float = float(st.get("card_w", 606.0)) * s
	var line_h := 31.0 * s
	var h := (116.0 * s) + (lines.size() + table.size()) * line_h
	if not table.is_empty():
		h += line_h  # cabecalho da tabela
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y * 0.5 - h * 0.5, w, h)
	_panel(r, 20.0 * s, SURFACE, EDGE)

	# Hierarquia por escala e espaco, sem regua decorativa sob o titulo.
	_text(Vector2(size.x * 0.5, r.position.y + 48.0 * s), st.get("title", ""),
		int(34 * s), st.get("title_color", TEXT))

	var y := r.position.y + 100.0 * s

	# Tabela de motores: comparacao precisa cair em colunas, nunca centralizada
	# linha a linha, senao os numeros de banda nao alinham entre si.
	# O bloco da tabela e centrado como UNIDADE: colunas fixas dentro de um cartao
	# centrado deixariam vao grande de um lado so.
	var tw: float = float(st.get("table_w", 486.0))
	var x0 := size.x * 0.5 - tw * 0.5 * s
	if not table.is_empty():
		var cols: Array = st.get("cols", [0.0, 34.0, 190.0, 344.0])
		var apagadas: Array = st.get("cols_dim", [2, 3])
		var head: Array = st.get("head", ["", "motor", "baixa / media / alta", "carro"])
		for c in cols.size():
			if not String(head[c]).is_empty():
				_text(Vector2(x0 + cols[c] * s, y), head[c], int(15 * s), DIM,
					HORIZONTAL_ALIGNMENT_LEFT)
		y += line_h
		for row in table:
			for c in cols.size():
				# Coluna apagada e contexto; a coluna que o jogador COMPARA fica legivel.
				var col := DIM if c in apagadas else TEXT
				_text(Vector2(x0 + cols[c] * s, y), row[c], int(20 * s), col,
					HORIZONTAL_ALIGNMENT_LEFT)
			y += line_h

	# Com tabela na tela, as linhas de apoio seguem a MESMA borda esquerda dela:
	# centralizar por cima de um bloco alinhado cria dois eixos no mesmo cartao.
	var has_table := not table.is_empty()
	for l in lines:
		var txt: String = l
		var col2 := TEXT
		if txt.begins_with("~"):
			txt = txt.substr(1)
			col2 = DIM
		if has_table:
			_text(Vector2(x0, y), txt, int(19 * s), col2, HORIZONTAL_ALIGNMENT_LEFT)
		else:
			_text(Vector2(size.x * 0.5, y), txt, int(20 * s), col2)
		y += line_h
