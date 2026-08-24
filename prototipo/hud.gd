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
func _micro(center: Vector2, s: String, col: Color, size_px: int,
		halign := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var spaced := ""
	for i in s.length():
		spaced += s[i]
		if i < s.length() - 1:
			spaced += " "
	_text(center, spaced, size_px, col, halign)


## Degrade chapado, sem contorno: e assim que a luz cai sobre a cena. Faixa de
## cor com borda dura viraria emenda visivel; aqui uma ponta some na outra.
func _fade(r: Rect2, de: Color, ate: Color, horizontal := false) -> void:
	var pts := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0.0),
		r.position + r.size, r.position + Vector2(0.0, r.size.y)])
	var cols: PackedColorArray
	if horizontal:
		cols = PackedColorArray([de, ate, ate, de])
	else:
		cols = PackedColorArray([de, de, ate, ate])
	draw_polygon(pts, cols)


## Tecla fisica. Nao e enfeite de icone: e o desenho do que se aperta, e por isso
## carrega o chanfro do resto do painel.
func _keycap(r: Rect2, texto: String, col: Color, size_px: int) -> void:
	draw_colored_polygon(_cham(r, r.size.y * 0.26), Color(col.r, col.g, col.b, 0.10))
	var loop := _cham(r, r.size.y * 0.26)
	loop.append(loop[0])
	draw_polyline(loop, Color(col.r, col.g, col.b, 0.75), 1.4, true)
	_text(r.position + r.size * 0.5, texto, size_px, col)


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
		6:  # MAPA
			_draw_mapa(s)
		4:  # OFERTA
			_draw_oferta(s)
		3:  # RESULT -- placar de corrida; fim de sequencia continua sendo cartao
			if not Dictionary(st.get("resultado", {})).is_empty():
				_draw_resultado(s)
			else:
				_draw_card(s)
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
	var w := 592.0 * s
	var h := 30.0 * s
	var cluster_top := size.y - 112.0 * s - 26.0 * s
	var r := Rect2(size.x * 0.5 - w * 0.5, cluster_top - h - 10.0 * s, w, h)
	_panel(r, 10.0 * s, Color(SURFACE, 0.80), Color(EDGE, 0.7))

	var bar_w := 68.0 * s
	var bar_h := 9.0 * s
	var cy := r.position.y + h * 0.5
	var pares := [
		["MOTOR", float(st.get("desg_motor", 0.0)), false],
		["CAMBIO", float(st.get("desg_cambio", 0.0)), bool(st.get("travado", false))],
		["TURBO", float(st.get("desg_turbo", 0.0)), bool(st.get("turbo_quebrado", false))],
		["PNEU", float(st.get("desg_pneu", 0.0)), bool(st.get("pneu_estourado", false))],
	]
	for i in pares.size():
		var rotulo: String = pares[i][0]
		var d: float = clampf(pares[i][1], 0.0, 1.0)
		var quebrado: bool = pares[i][2]
		var bx := r.position.x + (14.0 + i * 146.0) * s
		_micro(Vector2(bx + 26.0 * s, cy), rotulo, DIM, int(9 * s))

		var br := Rect2(bx + 56.0 * s, cy - bar_h * 0.5, bar_w, bar_h)
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
			draw_line(Vector2(br.position.x, br.position.y - 4.0 * s),
				Vector2(br.position.x + bar_w, br.position.y + bar_h + 4.0 * s), RED, 2.0, true)


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

	_text(Vector2(cx, 122.0 * s), "%s   ·   %s   ·   %.0f de %.0f m"
		% [st.phase, String(st.get("piso", "")).to_upper(), st.pos, st.dist],
		int(18 * s), DIM)
	_text(Vector2(cx, 146.0 * s), "corrida %d   ·   %d vitorias"
		% [int(st.get("corrida", 1)), int(st.get("vitorias", 0))], int(15 * s), DIM)


## A arvore de largada, a assinatura do painel: as tres ambares sobem com o giro
## e a verde acende dentro da janela -- solte nela.
func _draw_tree(s: float) -> void:
	# A arvore fica AO LADO da pista, como na largada de verdade -- no meio da
	# tela ela tapava justamente o carro que voce esta prestes a largar.
	var cx := size.x * 0.24
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
	_text(Vector2(size.x * 0.5, size.y - 56.0 * s), st.matchup, int(18 * s), DIM)


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


## Vitrine de escolha de carro. Mesma moldura da garagem: o carro esta na CENA,
## a luz cai das bordas para ele, e o painel nao e caixa nenhuma -- e a coluna de
## texto que sobra na sombra da esquerda.
##
## O elenco tem 25 carros, entao a lista corre numa janela em volta do escolhido.
## A janela e de altura FIXA e a ficha do carro mora sempre no mesmo lugar: lista
## que cresce embaixo do item selecionado empurra o resto da tela a cada seta.
func _draw_menu(s: float) -> void:
	var W := size.x
	var H := size.y
	var mx := 56.0 * s
	var ink0 := Color(INK.r, INK.g, INK.b, 0.0)
	_fade(Rect2(0.0, 0.0, W, 210.0 * s), Color(INK.r, INK.g, INK.b, 0.92), ink0)
	_fade(Rect2(0.0, H - 300.0 * s, W, 300.0 * s), ink0,
		Color(INK.r, INK.g, INK.b, 0.92))
	_fade(Rect2(0.0, 0.0, 560.0 * s, H), Color(INK.r, INK.g, INK.b, 0.90), ink0, true)

	_text(Vector2(mx, 76.0 * s), "ARRANCADA", int(46 * s), TEXT,
		HORIZONTAL_ALIGNMENT_LEFT)

	var opcoes: Array = st.get("opcoes", [])
	var sel: int = int(st.get("sel", 0))
	var n := opcoes.size()
	var janela := 7
	var ini: int = clampi(sel - janela / 2, 0, maxi(0, n - janela))
	var fim: int = mini(n, ini + janela)

	_micro(Vector2(mx, 120.0 * s), "ELENCO", DIM, int(10 * s),
		HORIZONTAL_ALIGNMENT_LEFT)
	_text(Vector2(mx + 128.0 * s, 120.0 * s), "%d de %d" % [sel + 1, n], int(13 * s),
		DIM, HORIZONTAL_ALIGNMENT_LEFT)

	var y := 162.0 * s
	for i in range(ini, fim):
		var nome: String = opcoes[i][0]
		var ativo := i == sel
		_lamp(Vector2(mx + 7.0 * s, y), 6.0 * s, AMBER if ativo else DIM, ativo)
		_text(Vector2(mx + 26.0 * s, y), nome, int(22 * s if ativo else 18 * s),
			TEXT if ativo else DIM, HORIZONTAL_ALIGNMENT_LEFT)
		y += 32.0 * s

	# A ficha do escolhido, sempre na mesma linha da tela.
	if sel < n:
		_text(Vector2(mx, 420.0 * s), opcoes[sel][1], int(16 * s), DIM,
			HORIZONTAL_ALIGNMENT_LEFT)
		_barras_banda(mx, 452.0 * s, 168.0 * s, opcoes[sel][2], s, 13.0, 26.0, 15)

	# Cambio: travado para a run inteira, entao a escolha vive aqui, e a tecla que
	# a troca aparece como tecla.
	var auto_c := bool(st.get("cambio_auto", false))
	_keycap(Rect2(mx, 550.0 * s, 26.0 * s, 26.0 * s), "A",
		COLD if auto_c else TEXT, int(15 * s))
	_text(Vector2(mx + 38.0 * s, 563.0 * s),
		"cambio %s" % ("automatico" if auto_c else "manual"), int(17 * s),
		COLD if auto_c else TEXT, HORIZONTAL_ALIGNMENT_LEFT)

	# O proximo marco: e o que da razao para jogar de novo depois de perder.
	var marco: String = st.get("marco", "")
	if not marco.is_empty():
		_text(Vector2(mx, 600.0 * s), "a seguir: %s" % marco, int(14 * s), AMBER,
			HORIZONTAL_ALIGNMENT_LEFT)

	_keycap(Rect2(mx, 628.0 * s, 60.0 * s, 26.0 * s), "SETAS", DIM, int(12 * s))
	_text(Vector2(mx + 72.0 * s, 641.0 * s), "escolhem", int(15 * s), DIM,
		HORIZONTAL_ALIGNMENT_LEFT)
	_keycap(Rect2(mx + 168.0 * s, 628.0 * s, 80.0 * s, 26.0 * s), "ESPACO", TEXT,
		int(12 * s))
	_text(Vector2(mx + 260.0 * s, 641.0 * s), "correr", int(15 * s), TEXT,
		HORIZONTAL_ALIGNMENT_LEFT)


## Simbolo de cada tipo de no. Letra, nao icone: sao sete tipos e um alfabeto de
## sete icones desenhados a mao seria pior de ler que sete letras.
const SIMBOLO := {
	"racha": "R", "marcado": "M", "oficina": "$", "ferro": "F",
	"boxes": "B", "evento": "?", "chefe": "X",
}
const ROTULO_NO := {
	"racha": "racha", "marcado": "rival marcado", "oficina": "oficina",
	"ferro": "ferro-velho", "boxes": "boxes", "evento": "evento", "chefe": "CHEFE",
}


## O mapa da run. Cada coluna e uma linha do mapa, da largada (esquerda) ao chefe
## (direita). O que esta em jogo aqui nao e "qual recompensa e maior", e "qual
## confronto a minha build ganha melhor" -- por isso o no diz piso e rival antes.
##
## Sem caixa: a rota ocupa a tela inteira, do jeito que mapa de rua ocupa. Ficha
## do no na esquerda, teclas na direita -- a mesma divisao da garagem, para a mao
## do jogador nao precisar reaprender onde as coisas ficam.
func _draw_mapa(s: float) -> void:
	var W := size.x
	var H := size.y
	var mx := 56.0 * s
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK.r, INK.g, INK.b, 0.91))
	var ink0 := Color(INK.r, INK.g, INK.b, 0.0)
	_fade(Rect2(0.0, 0.0, W, 190.0 * s), Color(INK.r, INK.g, INK.b, 0.70), ink0)
	_fade(Rect2(0.0, H - 260.0 * s, W, 260.0 * s), ink0,
		Color(INK.r, INK.g, INK.b, 0.80))

	_text(Vector2(mx, 66.0 * s), "ATO %d" % int(st.get("ato", 1)), int(38 * s), TEXT,
		HORIZONTAL_ALIGNMENT_LEFT)

	# Reputacao: a trava do chefe, e a razao de o rival marcado existir.
	var rep: int = int(st.get("reputacao", 0))
	var meta: int = int(st.get("meta_rep", 12))
	var f: float = clampf(float(rep) / maxf(float(meta), 1.0), 0.0, 1.0)
	var num := "%d/%d" % [rep, meta]
	var num_w := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * s)).x
	_text(Vector2(W - mx, 66.0 * s), num, int(20 * s), TEXT,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var br := Rect2(W - mx - num_w - 216.0 * s, 59.0 * s, 200.0 * s, 12.0 * s)
	draw_colored_polygon(_cham(br, 4.0 * s), Color(0.0, 0.0, 0.0, 0.45))
	if f > 0.001:
		draw_colored_polygon(_cham(Rect2(br.position,
			Vector2(br.size.x * f, br.size.y)), 4.0 * s), GREEN if f >= 1.0 else AMBER)
	_micro(Vector2(br.position.x - 16.0 * s, 66.0 * s), "REPUTACAO", DIM, int(10 * s),
		HORIZONTAL_ALIGNMENT_RIGHT)

	var linhas: Array = st.get("linhas", [])
	var alc: Array = st.get("alcancaveis", [])
	var alvo: int = int(st.get("linha_alvo", 0))
	var sel: int = int(st.get("sel_no", 0))
	var lin_at: int = int(st.get("linha_atual", -1))
	var idx_at: int = int(st.get("idx_atual", -1))

	# A ultima coluna cai exatamente na margem direita: rota que sobra espaco de
	# um lado so parece torta.
	var x0 := mx + 34.0 * s
	var col_w := (W - 2.0 * (mx + 34.0 * s)) / maxf(float(linhas.size() - 1), 1.0)
	var cy := H * 0.44
	var passo := 66.0 * s

	# Ligacoes primeiro, para os nos ficarem por cima delas.
	var ligs: Array = st.get("ligacoes", [])
	for e in ligs:
		var ax := x0 + col_w * int(e[0])
		var ay := cy + (int(e[1]) - (int(e[2]) - 1) * 0.5) * passo
		var bx2 := x0 + col_w * (int(e[0]) + 1)
		var by2 := cy + (int(e[3]) - (int(e[4]) - 1) * 0.5) * passo
		var viva: bool = bool(e[5])
		draw_line(Vector2(ax, ay), Vector2(bx2, by2),
			Color(AMBER, 0.55) if viva else Color(EDGE, 0.50),
			2.0 if viva else 1.0, true)

	for l in linhas.size():
		var col: Array = linhas[l]
		var cx := x0 + col_w * l
		for i in col.size():
			var no: Dictionary = col[i]
			var y := cy + (i - (col.size() - 1) * 0.5) * passo
			var eh_alvo := l == alvo and (i in alc)
			var eh_sel := eh_alvo and i == sel
			var eh_atual := l == lin_at and i == idx_at

			var cor := DIM
			if no.tipo == "chefe":
				cor = RED
			elif eh_alvo:
				cor = AMBER
			if eh_atual:
				cor = TEXT

			var raio := (18.0 if eh_sel else 14.0) * s
			_lamp(Vector2(cx, y), raio, cor, eh_alvo or eh_atual or bool(no.visitado))
			_text(Vector2(cx, y), SIMBOLO.get(no.tipo, "?"), int(15 * s),
				INK if (eh_alvo or eh_atual) else DIM)
			if eh_sel:
				draw_arc(Vector2(cx, y), raio + 8.0 * s, 0, TAU, 40, TEXT, 2.0, true)

	# Ficha do no escolhido: piso e rival, nunca os numeros. Fica na esquerda, na
	# mesma coluna do titulo -- e a continuacao da leitura, nao um rodape.
	var ficha: Array = st.get("ficha_no", [])
	var fy := H - 168.0 * s
	for k in ficha.size():
		var txt: String = ficha[k]
		var cor2 := TEXT
		var corpo := 24
		if txt.begins_with("~"):
			txt = txt.substr(1)
			cor2 = DIM
			corpo = 16
		_text(Vector2(mx, fy), txt, int(corpo * s), cor2, HORIZONTAL_ALIGNMENT_LEFT)
		fy += 28.0 * s

	# Teclas na direita, na mesma altura da ficha.
	var ky := H - 96.0 * s
	var kx := W - mx
	_text(Vector2(kx, ky), "garagem", int(15 * s), DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_keycap(Rect2(kx - 96.0 * s, ky - 13.0 * s, 26.0 * s, 26.0 * s), "G", DIM,
		int(14 * s))
	_text(Vector2(kx - 116.0 * s, ky), "entra", int(15 * s), TEXT,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_keycap(Rect2(kx - 282.0 * s, ky - 13.0 * s, 80.0 * s, 26.0 * s), "ESPACO", TEXT,
		int(12 * s))
	_text(Vector2(kx - 302.0 * s, ky), "escolhem", int(15 * s), DIM,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_keycap(Rect2(kx - 442.0 * s, ky - 13.0 * s, 60.0 * s, 26.0 * s), "SETAS", DIM,
		int(12 * s))


## A garagem. E TELA DE JOGO, nao formulario: o carro fica no meio do quadro,
## aceso, e o painel se abre em volta dele -- instrumento a esquerda, destino a
## direita, e as sete baias de peca numa bandeja embaixo, como o rack de
## ferramenta que fica na parede de qualquer oficina.
##
## A luz cai das bordas para o centro. As bordas escurecem em degrade, nunca em
## faixa com borda: o carro e a coisa mais clara da tela porque a run inteira
## gira em volta dele, e nenhum painel tapa isso.
func _draw_garagem(s: float) -> void:
	var W := size.x
	var H := size.y
	var mx := 56.0 * s

	# --- moldura de luz -------------------------------------------------------
	var ink0 := Color(INK.r, INK.g, INK.b, 0.0)
	_fade(Rect2(0.0, 0.0, W, 232.0 * s), Color(INK.r, INK.g, INK.b, 0.93), ink0)
	_fade(Rect2(0.0, H - 330.0 * s, W, 330.0 * s), ink0,
		Color(INK.r, INK.g, INK.b, 0.95))
	_fade(Rect2(0.0, 0.0, 430.0 * s, H), Color(INK.r, INK.g, INK.b, 0.80), ink0, true)
	_fade(Rect2(W - 430.0 * s, 0.0, 430.0 * s, H), ink0,
		Color(INK.r, INK.g, INK.b, 0.80), true)

	# --- cabecalho: o carro tem nome, e e ele que manda na tela ---------------
	_text(Vector2(mx, 62.0 * s), String(st.get("carro", "")).to_upper(),
		int(44 * s), TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_text(Vector2(mx, 98.0 * s), st.get("ficha", ""), int(16 * s), DIM,
		HORIZONTAL_ALIGNMENT_LEFT)
	# O aviso mora no cabecalho, embaixo da ficha: e a ultima coisa que aconteceu
	# com este carro. No meio da tela ele batia no proprio carro.
	var aviso: String = st.get("aviso", "")
	if not aviso.is_empty():
		_text(Vector2(mx, 128.0 * s), aviso, int(16 * s),
			RED if aviso.contains("sucata") else AMBER, HORIZONTAL_ALIGNMENT_LEFT)

	var caixa := "%d" % int(st.get("dinheiro", 0))
	var caixa_w := font.get_string_size(caixa, HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(32 * s)).x
	_text(Vector2(W - mx, 64.0 * s), caixa, int(32 * s), TEXT,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_micro(Vector2(W - mx - caixa_w - 18.0 * s, 64.0 * s), "CAIXA", DIM,
		int(10 * s), HORIZONTAL_ALIGNMENT_RIGHT)

	# --- coluna esquerda: a forma do carro ------------------------------------
	var y := 176.0 * s
	_micro(Vector2(mx, y), "FORMA DO CARRO", DIM, int(10 * s),
		HORIZONTAL_ALIGNMENT_LEFT)
	y += 28.0 * s
	y = _barras_banda(mx, y, 186.0 * s, st.get("bandas", [70.0, 70.0, 70.0]), s, 14.0, 27.0)

	y += 8.0 * s
	var janela: Vector2 = st.get("janela", Vector2(0.9, 1.02))
	var detalhes := [
		"limite termico   %.0f%%" % (float(st.get("heat_limit", 0.8)) * 100.0),
		"janela de troca   %.0f%%" % ((janela.y - janela.x) * 100.0),
		"tanque   %.1fs em %s" % [float(st.get("nitro_cap", 6.0)),
			"uma vez" if st.get("formato", "longo") == "longo" else "tres garrafas"],
	]
	for d in detalhes:
		_text(Vector2(mx, y), d, int(15 * s), DIM, HORIZONTAL_ALIGNMENT_LEFT)
		y += 21.0 * s
	var conj: String = st.get("conjunto", "")
	if not conj.is_empty():
		# O conjunto e o unico numero da coluna que o jogador CONQUISTOU: acende.
		_text(Vector2(mx, y), "conjunto %s ativo" % conj.to_lower(), int(15 * s),
			AMBER, HORIZONTAL_ALIGNMENT_LEFT)
		y += 21.0 * s

	# A reserva fica com a build, nao com o destino: e peca guardada, e peca e
	# assunto desta coluna.
	y += 18.0 * s
	_micro(Vector2(mx, y), "RESERVA", DIM, int(10 * s), HORIZONTAL_ALIGNMENT_LEFT)
	var reserva: Array = st.get("reserva", [])
	if not reserva.is_empty():
		# A dica mora ao lado do que ela troca, nunca perdida num rodape.
		_text(Vector2(mx + 96.0 * s, y), "1 / 2 troca", int(12 * s), Color(TEXT, 0.55),
			HORIZONTAL_ALIGNMENT_LEFT)
	y += 26.0 * s
	for i in 2:
		var cheia: bool = i < reserva.size()
		_lamp(Vector2(mx + 6.0 * s, y), 5.0 * s, TEXT if cheia else DIM, cheia)
		_text(Vector2(mx + 22.0 * s, y), "%d  %s" % [i + 1,
			reserva[i][0] if cheia else "vazia"], int(15 * s),
			TEXT if cheia else DIM, HORIZONTAL_ALIGNMENT_LEFT)
		y += 23.0 * s

	# --- coluna direita: para onde voce vai, e o que carrega junto -------------
	var rx := W - mx
	y = 176.0 * s
	_micro(Vector2(rx, y), "PROXIMO TRECHO", DIM, int(10 * s),
		HORIZONTAL_ALIGNMENT_RIGHT)
	y += 34.0 * s
	var ader: float = float(st.get("aderencia", 1.0))
	var cor_p := TEXT
	if ader < 0.92:
		cor_p = RED
	elif ader < 0.99:
		cor_p = AMBER
	elif ader > 1.02:
		cor_p = GREEN
	_text(Vector2(rx, y), String(st.get("piso", "")).to_upper(), int(26 * s), cor_p,
		HORIZONTAL_ALIGNMENT_RIGHT)
	y += 25.0 * s
	_text(Vector2(rx, y), "pneu %s   %+.0f%%" % [st.get("pneu", "misto"),
		(ader - 1.0) * 100.0], int(15 * s), DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	y += 21.0 * s
	_text(Vector2(rx, y), String(st.get("piso_desc", "")), int(12 * s), DIM,
		HORIZONTAL_ALIGNMENT_RIGHT)

	y += 40.0 * s
	_micro(Vector2(rx, y), "PASSIVOS", DIM, int(10 * s), HORIZONTAL_ALIGNMENT_RIGHT)
	y += 30.0 * s
	var passivos: Array = st.get("passivos", [])
	for i in 2:
		var tem: bool = i < passivos.size()
		# Raro e frio, comum e da cor da tela: a cor diz a raridade sem escrever.
		var cor := (COLD if tem and bool(passivos[i][2]) else (TEXT if tem else DIM))
		_lamp(Vector2(rx - 6.0 * s, y), 5.0 * s, cor, tem)
		_text(Vector2(rx - 22.0 * s, y), passivos[i][0] if tem else "slot vazio",
			int(17 * s), cor, HORIZONTAL_ALIGNMENT_RIGHT)
		if tem:
			_text(Vector2(rx - 22.0 * s, y + 18.0 * s), passivos[i][1], int(12 * s),
				DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 42.0 * s

	# --- bandeja das pecas ----------------------------------------------------
	var bandeja := Rect2(mx * 0.72, H - 254.0 * s, W - mx * 1.44, 228.0 * s)
	_panel(bandeja, 18.0 * s, Color(INK.r, INK.g, INK.b, 0.88), Color(EDGE, 0.55))

	var dentro := bandeja.grow(-20.0 * s)
	var vao := 12.0 * s
	var bw := (dentro.size.x - vao * 6.0) / 7.0
	var bh := 118.0 * s
	var equipadas: Array = st.get("equipadas", [])
	for i in equipadas.size():
		_baia(Rect2(dentro.position.x + (bw + vao) * i, dentro.position.y, bw, bh),
			equipadas[i], s)

	_acoes(Rect2(dentro.position.x, dentro.position.y + bh + 24.0 * s,
		dentro.size.x, 46.0 * s), s)


## Uma baia do rack. Vazia e um encaixe escuro com o nome do slot; cheia mostra a
## marca, a raridade em lampadas da arvore e o que a peca faz -- nessa ordem,
## porque e nessa ordem que a peca e escolhida.
func _baia(r: Rect2, linha: Array, s: float) -> void:
	var slot: String = linha[0]
	var marca: String = linha[1]
	var raridade: int = linha[2]
	var efeito: String = linha[3]
	var vazio := marca.is_empty()

	draw_colored_polygon(_cham(r, 9.0 * s),
		Color(0.0, 0.0, 0.0, 0.30 if vazio else 0.42))
	var loop := _cham(r, 9.0 * s)
	loop.append(loop[0])
	draw_polyline(loop, Color(EDGE, 0.20 if vazio else 0.70), 1.4, true)

	var cx := r.position.x + r.size.x * 0.5
	_micro(Vector2(cx, r.position.y + 17.0 * s), slot.to_upper(), DIM, int(9 * s))

	if vazio:
		# Encaixe vago: o recorte interno mostra que ali CABE peca.
		var vaga := Rect2(r.position.x + 16.0 * s, r.position.y + 34.0 * s,
			r.size.x - 32.0 * s, r.size.y - 52.0 * s)
		var vl := _cham(vaga, 7.0 * s)
		vl.append(vl[0])
		draw_polyline(vl, Color(EDGE, 0.16), 1.2, true)
		_text(Vector2(cx, vaga.position.y + vaga.size.y * 0.5), "sem peca",
			int(13 * s), Color(DIM, 0.7))
		return

	_text(Vector2(cx, r.position.y + 44.0 * s), marca, int(17 * s), TEXT)
	# Raridade nas lampadas da arvore: uma, duas, tres. Mesma lingua do giro.
	for i in 3:
		var acesa: bool = i <= raridade
		_lamp(Vector2(cx + (i - 1) * 11.0 * s, r.position.y + 66.0 * s), 3.4 * s,
			AMBER if acesa else DIM, acesa)
	var linhas := efeito.split("   ", false)
	var ey := r.position.y + 88.0 * s
	for i in mini(linhas.size(), 2):
		_text(Vector2(cx, ey), linhas[i], int(12 * s), DIM)
		ey += 15.0 * s


## A faixa de acao. Cada tecla de conserto carrega a CONDICAO da peca que ela
## conserta: o preco sozinho nao diz se vale a pena, o desgaste diz.
func _acoes(r: Rect2, s: float) -> void:
	var itens: Array = st.get("oficina", [])
	var x := r.position.x
	var cy := r.position.y + 16.0 * s
	for it in itens:
		var tecla: String = it[0]
		var rotulo: String = it[1]
		var custo: int = it[2]
		var pode: bool = it[3]
		var urgente: bool = it[4]
		var gasto: float = float(it[5])

		var cor := DIM
		if urgente:
			cor = RED
		elif custo <= 0:
			cor = DIM
		elif pode:
			cor = TEXT
		else:
			cor = Color(RED, 0.60)   # ha orcamento, o caixa e que nao cobre

		_keycap(Rect2(x, cy - 13.0 * s, 26.0 * s, 26.0 * s), tecla, cor, int(15 * s))
		var tx := x + 36.0 * s
		_text(Vector2(tx, cy - 7.0 * s), "%s   %s" % [rotulo,
			("fundido" if urgente else ("ok" if custo <= 0 else str(custo)))],
			int(15 * s), cor, HORIZONTAL_ALIGNMENT_LEFT)
		# Desgaste enche na direcao do perigo, igual a barra de calor. O nitro nao
		# e dano: a barra dele e o tanque, e tanque cheio e frio, nunca vermelho.
		var br := Rect2(tx, cy + 6.0 * s, 96.0 * s, 4.0 * s)
		draw_rect(br, Color(0.0, 0.0, 0.0, 0.45))
		var cheio := clampf(gasto, 0.0, 1.0)
		if cheio > 0.001:
			var cor_b := COLD if tecla == "N" else (RED if cheio > 0.66
				else (AMBER if cheio > 0.33 else Color(TEXT, 0.75)))
			draw_rect(Rect2(br.position, Vector2(br.size.x * cheio, br.size.y)), cor_b)
		x += 190.0 * s

	# A acao principal fica sozinha na ponta direita: so existe uma pergunta por
	# vez na garagem.
	var travado: bool = bool(st.get("precisa_consertar", false))
	var oferta: Array = st.get("passivo_oferta", [])
	var dx := r.position.x + r.size.x
	if travado:
		_text(Vector2(dx, cy), "motor fundido: conserte para continuar", int(16 * s),
			RED, HORIZONTAL_ALIGNMENT_RIGHT)
	elif not oferta.is_empty():
		_text(Vector2(dx, cy - 8.0 * s), "%s: %s" % [oferta[0], oferta[1]],
			int(15 * s), COLD if bool(oferta[2]) else TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		_text(Vector2(dx, cy + 12.0 * s), "1 ou 2 troca   ·   0 deixa na rua",
			int(13 * s), DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		var w_txt := font.get_string_size("correr", HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(17 * s)).x
		_text(Vector2(dx, cy), "correr", int(17 * s), TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		_keycap(Rect2(dx - w_txt - 92.0 * s, cy - 13.0 * s, 80.0 * s, 26.0 * s),
			"ESPACO", TEXT, int(13 * s))



## A vitrine de pecas. Tres baias grandes, do mesmo desenho do rack da garagem:
## escolher peca e tirar peca da prateleira, e a peca escolhida vai ocupar
## exatamente uma daquelas baias -- a tela mostra isso antes de acontecer.
##
## O preco vem junto. Comprar sem ver o preco nao e decisao, e susto.
func _draw_oferta(s: float) -> void:
	var W := size.x
	var H := size.y
	var mx := 56.0 * s
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK.r, INK.g, INK.b, 0.88))
	var ink0 := Color(INK.r, INK.g, INK.b, 0.0)
	_fade(Rect2(0.0, 0.0, W, 230.0 * s), Color(INK.r, INK.g, INK.b, 0.60), ink0)
	_fade(Rect2(0.0, H - 250.0 * s, W, 250.0 * s), ink0,
		Color(INK.r, INK.g, INK.b, 0.70))

	var paga: bool = bool(st.get("paga", false))
	_text(Vector2(mx, 88.0 * s), String(st.get("titulo", "")), int(46 * s),
		AMBER if paga else GREEN, HORIZONTAL_ALIGNMENT_LEFT)
	var sub := "a antiga vai para a reserva; com a reserva cheia, vira sucata"
	if bool(st.get("ferro", false)):
		sub = "peca de graca, e ja vem gasta"
	elif paga:
		sub = "o caixa decide: peca comprada sai do dinheiro do conserto"
	_text(Vector2(mx, 128.0 * s), sub, int(17 * s), DIM, HORIZONTAL_ALIGNMENT_LEFT)

	if paga:
		var caixa := "%d" % int(st.get("dinheiro", 0))
		var cw := font.get_string_size(caixa, HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(32 * s)).x
		_text(Vector2(W - mx, 90.0 * s), caixa, int(32 * s), TEXT,
			HORIZONTAL_ALIGNMENT_RIGHT)
		_micro(Vector2(W - mx - cw - 18.0 * s, 90.0 * s), "CAIXA", DIM, int(10 * s),
			HORIZONTAL_ALIGNMENT_RIGHT)

	var itens: Array = st.get("oferta", [])
	var n: int = maxi(itens.size(), 1)
	var vao := 26.0 * s
	var bw: float = minf(348.0 * s, (W - 2.0 * mx - vao * (n - 1)) / float(n))
	var bh := 230.0 * s
	var x0 := W * 0.5 - (bw * n + vao * (n - 1)) * 0.5
	var by := 244.0 * s
	for i in itens.size():
		_baia_oferta(Rect2(x0 + (bw + vao) * i, by, bw, bh), itens[i], s)

	# O que ja esta no carro, para a troca nao ser as cegas.
	_text(Vector2(mx, by + bh + 46.0 * s), "equipado: %s" % st.get("equipado", ""),
		int(15 * s), DIM, HORIZONTAL_ALIGNMENT_LEFT)
	var aviso: String = st.get("oferta_aviso", "")
	if not aviso.is_empty():
		_text(Vector2(mx, by + bh + 72.0 * s), aviso, int(16 * s), RED,
			HORIZONTAL_ALIGNMENT_LEFT)


func _baia_oferta(r: Rect2, item: Array, s: float) -> void:
	var tecla: int = int(item[0])
	var slot: String = item[1]
	var marca: String = item[2]
	var raridade: int = int(item[3])
	var efeito: String = item[4]
	var preco: int = int(item[5])
	var pode: bool = bool(item[6])
	var no_lugar: String = item[7]

	draw_colored_polygon(_cham(r, 12.0 * s), Color(0.0, 0.0, 0.0, 0.42))
	var loop := _cham(r, 12.0 * s)
	loop.append(loop[0])
	draw_polyline(loop, Color(EDGE, 0.70 if pode else 0.30), 1.5, true)

	var cx := r.position.x + r.size.x * 0.5
	_keycap(Rect2(r.position.x + 18.0 * s, r.position.y + 18.0 * s, 26.0 * s,
		26.0 * s), str(tecla), TEXT if pode else Color(RED, 0.6), int(15 * s))
	_micro(Vector2(cx, r.position.y + 31.0 * s), slot.to_upper(), DIM, int(10 * s))

	_text(Vector2(cx, r.position.y + 82.0 * s), marca, int(24 * s),
		TEXT if pode else Color(TEXT, 0.45))
	for i in 3:
		var acesa: bool = i <= raridade
		_lamp(Vector2(cx + (i - 1) * 13.0 * s, r.position.y + 106.0 * s), 4.0 * s,
			AMBER if acesa else DIM, acesa)

	var linhas := efeito.split("   ", false)
	var ey := r.position.y + 128.0 * s
	# Duas linhas de efeito, nunca tres: a terceira encostava no que a peca
	# substitui, e texto espremido contra texto e o pior jeito de comparar peca.
	for i in mini(linhas.size(), 2):
		_text(Vector2(cx, ey), linhas[i], int(15 * s), DIM)
		ey += 21.0 * s

	if not no_lugar.is_empty():
		_text(Vector2(cx, r.position.y + r.size.y - 54.0 * s),
			"no lugar de %s" % no_lugar, int(13 * s), Color(AMBER, 0.75))

	if preco > 0:
		_text(Vector2(cx, r.position.y + r.size.y - 26.0 * s), "%d" % preco,
			int(26 * s), TEXT if pode else RED)
	else:
		_text(Vector2(cx, r.position.y + r.size.y - 26.0 * s), "de graca",
			int(17 * s), DIM)


## Fim de corrida. Nao e cartao: e o momento em que a corrida acabou, e ele se
## le em tres tempos -- o veredito, por quanto foi, e o que a corrida custou ao
## carro. A mesma moldura do resto do jogo, a mesma divisao (leitura na esquerda,
## teclas na direita).
func _draw_resultado(s: float) -> void:
	var W := size.x
	var H := size.y
	var mx := 56.0 * s
	var res: Dictionary = st.get("resultado", {})
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK.r, INK.g, INK.b, 0.88))
	var ink0 := Color(INK.r, INK.g, INK.b, 0.0)
	_fade(Rect2(0.0, 0.0, W, 240.0 * s), Color(INK.r, INK.g, INK.b, 0.60), ink0)
	_fade(Rect2(0.0, H - 260.0 * s, W, 260.0 * s), ink0,
		Color(INK.r, INK.g, INK.b, 0.70))

	var cor: Color = res.get("cor", TEXT)
	_text(Vector2(mx, 108.0 * s), String(res.get("veredito", "")), int(76 * s), cor,
		HORIZONTAL_ALIGNMENT_LEFT)

	var margem: float = float(res.get("margem", 0.0))
	var sub := "nao terminou"
	if margem > 0.0:
		sub = "por %.2fs" % margem
	if bool(res.get("fundiu", false)):
		sub = "o motor nao voltou inteiro"
	elif bool(res.get("travou", false)):
		sub = "o cambio travou no meio da corrida"
	_text(Vector2(mx, 152.0 * s), sub, int(20 * s), DIM, HORIZONTAL_ALIGNMENT_LEFT)

	# --- o duelo: duas linhas, tempo grande, vencedor aceso ---
	var y := 286.0 * s
	var venceu: bool = bool(res.get("venceu", false))
	for lado in ["eu", "rival"]:
		var d: Array = res.get(lado, ["", 0, 0.0])
		var meu: bool = lado == "eu"
		var ganhou: bool = meu == venceu
		var c := TEXT if ganhou else DIM
		_lamp(Vector2(mx + 7.0 * s, y), 6.0 * s, GREEN if ganhou else DIM, ganhou)
		_text(Vector2(mx + 26.0 * s, y), String(d[0]), int(26 * s), c,
			HORIZONTAL_ALIGNMENT_LEFT)
		_text(Vector2(mx + 26.0 * s, y + 22.0 * s), "%d cv" % int(d[1]), int(14 * s),
			DIM, HORIZONTAL_ALIGNMENT_LEFT)
		var t := float(d[2])
		_text(Vector2(mx + 470.0 * s, y), ("%.2fs" % t) if t > 0.0 else "--",
			int(34 * s), c, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 70.0 * s

	# --- a margem: e o que fica na cabeca depois de uma arrancada ---
	# Duas lampadas numa regua de 1.5s. Corrida de arrancada se lembra pela
	# distancia na linha, nao pelo cronometro de cada um.
	if margem > 0.0:
		_micro(Vector2(mx, 406.0 * s), "MARGEM", DIM, int(10 * s),
			HORIZONTAL_ALIGNMENT_LEFT)
		var rr := Rect2(mx + 8.0 * s, 438.0 * s, 300.0 * s, 3.0 * s)
		draw_rect(rr, Color(EDGE, 0.55))
		var frac := clampf(margem / 1.0, 0.06, 1.0)
		_lamp(Vector2(rr.position.x, rr.position.y + 1.5 * s), 6.0 * s, GREEN, true)
		_lamp(Vector2(rr.position.x + rr.size.x * frac, rr.position.y + 1.5 * s),
			6.0 * s, RED if margem > 0.6 else AMBER, true)

	# --- o que a corrida custou ao carro ---
	var rx := W - mx
	var ry := 286.0 * s
	for par in [["motor", float(res.get("motor", 0.0))],
			["cambio", float(res.get("cambio", 0.0))]]:
		var nome: String = par[0]
		var v: float = clampf(par[1], 0.0, 1.0)
		_text(Vector2(rx, ry), nome, int(17 * s), DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		var br := Rect2(rx - 300.0 * s, ry - 6.0 * s, 210.0 * s, 12.0 * s)
		draw_colored_polygon(_cham(br, 4.0 * s), Color(0.0, 0.0, 0.0, 0.45))
		if v > 0.001:
			draw_colored_polygon(_cham(Rect2(br.position,
				Vector2(br.size.x * v, br.size.y)), 4.0 * s),
				RED if v > 0.66 else (AMBER if v > 0.33 else Color(TEXT, 0.8)))
		_text(Vector2(rx - 320.0 * s, ry), "%.0f%%" % (v * 100.0), int(15 * s), DIM,
			HORIZONTAL_ALIGNMENT_RIGHT)
		ry += 34.0 * s

	ry += 10.0 * s
	_text(Vector2(rx, ry), "trocas ruins   %d" % int(res.get("trocas_ruins", 0)),
		int(15 * s), DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	ry += 24.0 * s
	var calor: float = float(res.get("calor", 0.0))
	_text(Vector2(rx, ry), "calor maximo   %.0f%%" % (calor * 100.0), int(15 * s),
		RED if calor > 0.95 else DIM, HORIZONTAL_ALIGNMENT_RIGHT)

	# --- o dinheiro, e o que fazer agora ---
	var by := H - 168.0 * s
	var sinal := "+" if venceu else "-"
	_text(Vector2(mx, by), "%s%d" % [sinal, int(res.get("aposta", 0))], int(30 * s),
		GREEN if venceu else RED, HORIZONTAL_ALIGNMENT_LEFT)
	_micro(Vector2(mx, by + 26.0 * s), "APOSTA", DIM, int(10 * s),
		HORIZONTAL_ALIGNMENT_LEFT)
	_text(Vector2(mx + 150.0 * s, by), "%d" % int(res.get("caixa", 0)), int(30 * s),
		TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_micro(Vector2(mx + 150.0 * s, by + 26.0 * s), "CAIXA", DIM, int(10 * s),
		HORIZONTAL_ALIGNMENT_LEFT)
	_text(Vector2(mx + 320.0 * s, by), "corrida %d   ·   %d vitorias"
		% [int(res.get("corrida", 0)), int(res.get("vitorias", 0))], int(15 * s), DIM,
		HORIZONTAL_ALIGNMENT_LEFT)

	var ky := H - 156.0 * s
	_text(Vector2(rx, ky), "continua", int(16 * s), TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_keycap(Rect2(rx - 122.0 * s, ky - 13.0 * s, 26.0 * s, 26.0 * s), "R", TEXT,
		int(15 * s))
	_text(Vector2(rx, ky + 34.0 * s), "recomeca a sequencia", int(13 * s), DIM,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_keycap(Rect2(rx - 178.0 * s, ky + 21.0 * s, 26.0 * s, 26.0 * s), "M", DIM,
		int(13 * s))


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
