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


## Cartao de menu / resultado. Hierarquia por escala e cor, sem enfeite.
## Linha comecando com "~" e secundaria.
func _draw_card(s: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.026, 0.022, 0.84))

	var lines: Array = st.get("lines", [])
	var table: Array = st.get("table", [])
	var w := 606.0 * s
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
	var tw := 486.0
	var x0 := size.x * 0.5 - tw * 0.5 * s
	if not table.is_empty():
		var cols := [0.0, 34.0, 190.0, 344.0]
		var head := ["", "motor", "baixa / media / alta", "carro"]
		for c in 4:
			if not String(head[c]).is_empty():
				_text(Vector2(x0 + cols[c] * s, y), head[c], int(15 * s), DIM,
					HORIZONTAL_ALIGNMENT_LEFT)
		y += line_h
		for row in table:
			for c in 4:
				var col := TEXT if c <= 1 else DIM
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
