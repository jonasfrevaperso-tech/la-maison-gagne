class_name TableView
extends Control
## Tapis de roulette européen. Détecte l'emplacement visé selon la position fine :
## centre = plein, bord = cheval, coin = carré, bas de colonne = transversale/sixain.
## Clic gauche + la mise choisie (Maj : +5), clic droit −1, molette ±1.

signal spot_changed(spot_id: String, delta: int)
signal spot_hovered(spot_id: String)

const EDGE: float = 0.24
const ZERO_W_RATIO: float = 0.9
const COLUMN_W_RATIO: float = 1.0
const OUTSIDE_H_RATIO: float = 0.75
const CHIP_RADIUS_RATIO: float = 0.27
const SHIFT_AMOUNT: int = 5
const CHIP_SPRITE: String = "chip_magenta"
const CHIP_POP_TIME: float = 0.18
const FINE_X_MIN: int = -2
const FINE_X_MAX: int = 24
const FINE_Y_MAX: int = 7
const FINE_ROW_BOTTOM: int = 5
## Position du curseur « bas du tapis » au-dessus du bord (fraction de case, < EDGE).
const BOTTOM_EDGE_INSET: float = 0.06
const CHIP_POP_HEIGHT: float = 14.0
const EVEN_ORDER: Array[String] = ["low", "even", "red", "black", "odd", "high"]

var slip: BetSlip = null
var hover_spot: String = ""
var winning_numbers: Dictionary = {}
var flash_t: float = 0.0
var hide_odds: bool = false
var show_probabilities: bool = false
var wheel: WheelModel = null
var chip_value: int = 1
## Curseur manette/clavier : position fine (demi-cases) sur le tapis.
var cursor_active: bool = false
## Mise posée par un appui (A, clic) : choisie avec LB/RB (Q/W au clavier).
var bet_amount: int = 1
var _pops: Dictionary = {}  # spot_id -> temps restant de l'animation de pose
var _cx: int = 0
var _cy: int = 2

var _cw: float = 0.0
var _ch: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _zero_w: float = 0.0
var _out_h: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var cols: float = float(WheelLayout.TABLE_COLS) + ZERO_W_RATIO + COLUMN_W_RATIO
	_cw = size.x / cols
	_ch = size.y / (float(WheelLayout.TABLE_ROWS) + 2.0 * OUTSIDE_H_RATIO)
	_zero_w = _cw * ZERO_W_RATIO
	_out_h = _ch * OUTSIDE_H_RATIO
	_origin = Vector2(_zero_w, 0.0)
	queue_redraw()


func cell_rect(c: int, r: int) -> Rect2:
	return Rect2(_origin + Vector2(float(c) * _cw, float(WheelLayout.TABLE_ROWS - 1 - r) * _ch), Vector2(_cw, _ch))


func number_center(n: int) -> Vector2:
	if n == 0:
		return Vector2(_zero_w * 0.5, _ch * 1.5)
	return cell_rect(WheelLayout.table_col(n), WheelLayout.table_row(n)).get_center()


func _grid_bottom() -> float:
	return _ch * float(WheelLayout.TABLE_ROWS)


func outside_rect(spot_id: String) -> Rect2:
	var gb: float = _grid_bottom()
	if spot_id.begins_with("dozen:"):
		var d: int = int(spot_id.substr(6))
		return Rect2(_origin + Vector2(float(d * 4) * _cw, gb), Vector2(_cw * 4.0, _out_h))
	if spot_id.begins_with("column:"):
		var r: int = int(spot_id.substr(7))
		return Rect2(
			_origin + Vector2(float(WheelLayout.TABLE_COLS) * _cw, float(WheelLayout.TABLE_ROWS - 1 - r) * _ch),
			Vector2(_cw * COLUMN_W_RATIO, _ch)
		)
	var idx: int = EVEN_ORDER.find(spot_id)
	if idx >= 0:
		return Rect2(_origin + Vector2(float(idx * 2) * _cw, gb + _out_h), Vector2(_cw * 2.0, _out_h))
	return Rect2()


## Point d'ancrage des jetons d'un emplacement.
func spot_anchor(spot_id: String) -> Vector2:
	var spot: BetSpot = BetCatalog.get_spot(spot_id)
	if spot == null:
		return Vector2.ZERO
	if spot.outside:
		return outside_rect(spot_id).get_center()
	match spot.kind:
		&"street":
			var c: int = int(spot_id.substr(7))
			var rr: Rect2 = cell_rect(c, 0)
			return Vector2(rr.get_center().x, rr.end.y)
		&"six_line":
			var c2: int = int(spot_id.substr(9))
			var r2: Rect2 = cell_rect(c2, 0)
			return Vector2(r2.end.x, r2.end.y)
	var sum: Vector2 = Vector2.ZERO
	for n: int in spot.numbers:
		sum += number_center(n)
	return sum / float(spot.numbers.size())


func spot_at(p: Vector2) -> String:
	var gb: float = _grid_bottom()
	if p.x < _zero_w and p.y < gb:
		return "straight:0"
	if p.y >= gb:
		for d: int in 3:
			if outside_rect("dozen:%d" % d).has_point(p):
				return "dozen:%d" % d
		for k: String in EVEN_ORDER:
			if outside_rect(k).has_point(p):
				return k
		return ""
	var gx: float = (p.x - _origin.x) / _cw
	if gx >= float(WheelLayout.TABLE_COLS):
		for r: int in 3:
			if outside_rect("column:%d" % r).has_point(p):
				return "column:%d" % r
		return ""
	var c: int = clampi(int(gx), 0, WheelLayout.TABLE_COLS - 1)
	var r_vis: int = clampi(int(p.y / _ch), 0, WheelLayout.TABLE_ROWS - 1)
	var r: int = WheelLayout.TABLE_ROWS - 1 - r_vis
	var fx: float = gx - float(c)
	var fy_up: float = 1.0 - (p.y / _ch - float(r_vis))
	var left: bool = fx < EDGE
	var right: bool = fx > 1.0 - EDGE
	var bottom: bool = fy_up < EDGE
	var top: bool = fy_up > 1.0 - EDGE
	var n: int = WheelLayout.number_on_table(c, r)
	if bottom and r == 0:
		if left and c == 0:
			return "corner:0"  # « premiers quatre » : 0-1-2-3
		if left and c > 0:
			return "six_line:%d" % (c - 1)
		if right and c < WheelLayout.TABLE_COLS - 1:
			return "six_line:%d" % c
		return "street:%d" % c
	var dc: int = -1 if left else (1 if right else 0)
	var dr: int = -1 if bottom else (1 if top else 0)
	if dc != 0 and dr != 0:
		var c0: int = mini(c, c + dc)
		var r0: int = mini(r, r + dr)
		if c0 >= 0 and c0 + 1 < WheelLayout.TABLE_COLS and r0 >= 0 and r0 + 1 < WheelLayout.TABLE_ROWS:
			return "corner:%d" % WheelLayout.number_on_table(c0, r0)
	if dc != 0:
		if c == 0 and dc < 0:
			return "split:0-%d" % n
		var c2: int = c + dc
		if c2 >= 0 and c2 < WheelLayout.TABLE_COLS:
			var m: int = WheelLayout.number_on_table(c2, r)
			return "split:%d-%d" % [mini(n, m), maxi(n, m)]
	if dr != 0:
		var r2: int = r + dr
		if r2 >= 0 and r2 < WheelLayout.TABLE_ROWS:
			var m2: int = WheelLayout.number_on_table(c, r2)
			return "split:%d-%d" % [mini(n, m2), maxi(n, m2)]
	return "straight:%d" % n


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var s: String = spot_at((event as InputEventMouseMotion).position)
		if s != hover_spot:
			hover_spot = s
			spot_hovered.emit(s)
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if not mb.pressed:
			return
		var spot: String = spot_at(mb.position)
		if spot == "":
			return
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				spot_changed.emit(spot, SHIFT_AMOUNT if mb.shift_pressed else bet_amount)
			MOUSE_BUTTON_RIGHT:
				spot_changed.emit(spot, -1)
			MOUSE_BUTTON_WHEEL_UP:
				spot_changed.emit(spot, 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				spot_changed.emit(spot, -1)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover_spot = ""
		spot_hovered.emit("")
		queue_redraw()


func _process(delta: float) -> void:
	if flash_t > 0.0:
		flash_t = maxf(flash_t - delta, 0.0)
		queue_redraw()
	if not _pops.is_empty():
		for k: Variant in _pops.keys():
			_pops[k] = float(_pops[k]) - delta
			if float(_pops[k]) <= 0.0:
				_pops.erase(k)
		queue_redraw()


# --------------------------------------------------------------------------- curseur manette
# Grille fine (demi-cases) : sur les numéros, une position paire est un centre de case (plein),
# une position impaire un bord (cheval) et la rencontre de deux bords un coin (carré).
# fx : -2 = zéro, -1 = bord du zéro, 0..23 = numéros, 24 = colonnes 2:1.
# fy : 0..4 = rangées de numéros, 5 = bas du tapis (transversale, sixain),
#      6 = douzaines, 7 = chances simples.


func move_cursor(dx: int, dy: int) -> void:
	var was: bool = cursor_active
	cursor_active = true
	if not was:
		_update_cursor()
		return
	var before: String = cursor_spot()
	var fx: int = _cx
	var fy: int = _cy
	# Avance jusqu'à un emplacement différent (zéro, colonnes et chances couvrent plusieurs pas).
	for _i: int in FINE_X_MAX - FINE_X_MIN + 1:
		fx += dx
		fy += dy
		if fy < 0 or fy > FINE_Y_MAX or fx < FINE_X_MIN or fx > FINE_X_MAX:
			return
		var cx: int = _clamp_x(fx, fy)
		var spot: String = _fine_spot(cx, fy)
		if spot != "" and spot != before:
			_cx = cx
			_cy = fy
			_update_cursor()
			return
		if dx == 0 and cx != fx:
			fx = cx


## Bornes horizontales selon la rangée (pas de zéro ni de colonnes hors des numéros).
func _clamp_x(fx: int, fy: int) -> int:
	if fy == FINE_ROW_BOTTOM:
		return clampi(fx, -1, FINE_X_MAX - 2)  # -1 : premiers quatre (0-1-2-3)
	if fy > FINE_ROW_BOTTOM:
		return clampi(fx, 0, FINE_X_MAX - 2)
	return fx


func cursor_spot() -> String:
	return _fine_spot(_clamp_x(_cx, _cy), _cy)


## Point du tapis correspondant à une position fine : même détection que la souris.
func fine_point(fx: int, fy: int) -> Vector2:
	var x: float
	if fx <= FINE_X_MIN:
		x = _zero_w * 0.5
	elif fx == FINE_X_MIN + 1:
		x = _origin.x + _cw * BOTTOM_EDGE_INSET  # bord du zéro, côté numéros
	elif fx >= FINE_X_MAX:
		x = _origin.x + (float(WheelLayout.TABLE_COLS) + COLUMN_W_RATIO * 0.5) * _cw
	else:
		x = _origin.x + float(fx + 1) * 0.5 * _cw
	var y: float
	if fy < FINE_ROW_BOTTOM:
		y = float(fy + 1) * 0.5 * _ch
	elif fy == FINE_ROW_BOTTOM:
		y = _grid_bottom() - _ch * BOTTOM_EDGE_INSET
	elif fy == FINE_ROW_BOTTOM + 1:
		y = _grid_bottom() + _out_h * 0.5
	else:
		y = _grid_bottom() + _out_h * 1.5
	return Vector2(x, y)


func _fine_spot(fx: int, fy: int) -> String:
	if _cw <= 0.0:
		return "straight:0"
	var spot: String = spot_at(fine_point(fx, fy))
	return spot


func _update_cursor() -> void:
	hover_spot = cursor_spot()
	spot_hovered.emit(hover_spot)
	queue_redraw()


func pop_chip(spot_id: String) -> void:
	_pops[spot_id] = CHIP_POP_TIME


func flash_winners(numbers: Array[int]) -> void:
	winning_numbers.clear()
	for n: int in numbers:
		winning_numbers[n] = true
	flash_t = 1.6


func _get_tooltip(at_position: Vector2) -> String:
	var s: String = spot_at(at_position)
	if s == "":
		return ""
	return BetInfo.describe(s, hide_odds, wheel, chip_value, int(slip.chips.get(s, 0)) if slip != null else 0)


## Infobulle illustrée (BetCard) à la place du texte brut.
func _make_custom_tooltip(_for_text: String) -> Object:
	var s: String = spot_at(get_local_mouse_position())
	if s == "":
		return null
	return BetCard.build(s, hide_odds, wheel, chip_value, int(slip.chips.get(s, 0)) if slip != null else 0)


## Position du curseur manette (coordonnées locales).
func cursor_point() -> Vector2:
	return fine_point(_cx, _cy)


# --------------------------------------------------------------------------- dessin


func _draw() -> void:
	draw_rect(Rect2(Vector2(-12, -12), size + Vector2(24, 24)), Palette.GOLD_DARK)
	draw_rect(Rect2(Vector2(-8, -8), size + Vector2(16, 16)), Palette.FELT)
	var hover_nums: Dictionary = {}
	var hspot: BetSpot = BetCatalog.get_spot(hover_spot) if hover_spot != "" else null
	if hspot != null:
		for n: int in hspot.numbers:
			hover_nums[n] = true
	var f: Font = UiKit.font("display")
	var fs: int = int(_ch * 0.36)
	# Zéro
	var zr: Rect2 = Rect2(Vector2.ZERO, Vector2(_zero_w, _grid_bottom()))
	_cell(zr, Palette.ZERO_GREEN, hover_nums.has(0), winning_numbers.has(0))
	_text_center(f, "0", zr.get_center(), fs, Palette.IVORY)
	for c: int in WheelLayout.TABLE_COLS:
		for r: int in WheelLayout.TABLE_ROWS:
			var n: int = WheelLayout.number_on_table(c, r)
			var rect: Rect2 = cell_rect(c, r)
			_cell(rect, Palette.FELT, hover_nums.has(n), winning_numbers.has(n))
			var oval: Color = Palette.pocket_color(WheelLayout.color_of(n))
			draw_circle(rect.get_center(), minf(_cw, _ch) * 0.36, oval)
			_text_center(f, str(n), rect.get_center(), fs, Palette.IVORY)
	for r: int in 3:
		var cr: Rect2 = outside_rect("column:%d" % r)
		_cell(cr, Palette.FELT, hover_spot == "column:%d" % r, false)
		_text_center(f, "2:1", cr.get_center(), int(fs * 0.8), Palette.GOLD_LIGHT)
	var dozen_labels: Array[String] = ["1–12", "13–24", "25–36"]
	for d: int in 3:
		var dr: Rect2 = outside_rect("dozen:%d" % d)
		_cell(dr, Palette.FELT, hover_spot == "dozen:%d" % d, false)
		_text_center(f, dozen_labels[d], dr.get_center(), int(fs * 0.8), Palette.GOLD_LIGHT)
	for k: String in EVEN_ORDER:
		var er: Rect2 = outside_rect(k)
		_cell(er, Palette.FELT, hover_spot == k, false)
		if k == "red" or k == "black":
			var dc: Color = Palette.pocket_color(StringName(k))
			var cc: Vector2 = er.get_center()
			var w: float = er.size.x * 0.22
			var h: float = er.size.y * 0.32
			draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -h), cc + Vector2(w, 0), cc + Vector2(0, h), cc + Vector2(-w, 0)]), dc)
		else:
			_text_center(f, tr("BET_" + k.to_upper()), er.get_center(), UiKit.fs(int(fs * 0.62)), Palette.IVORY)
		if slip != null and slip.banned_spots.has(k):
			draw_line(er.position, er.end, Palette.DANGER, 4.0)
			draw_line(Vector2(er.position.x, er.end.y), Vector2(er.end.x, er.position.y), Palette.DANGER, 4.0)
	if slip != null:
		for spot_id: String in slip.order:
			var pop: float = float(_pops.get(spot_id, 0.0)) / CHIP_POP_TIME
			var lift: float = sin(pop * PI) * CHIP_POP_HEIGHT * JuiceProfile.intensity()
			_draw_chip(spot_anchor(spot_id) - Vector2(0, lift), int(slip.chips[spot_id]))
	if cursor_active and hover_spot != "":
		var cp: Vector2 = spot_anchor(hover_spot)
		draw_arc(cp, minf(_cw, _ch) * 0.42, 0.0, TAU, 32, Palette.CYAN, 4.0, true)
	if hover_spot != "" and bet_amount > 1:
		var mf: Font = UiKit.font("mono")
		var mfs: int = UiKit.fs(int(minf(_cw, _ch) * 0.3))
		var at: Vector2 = spot_anchor(hover_spot) + Vector2(minf(_cw, _ch) * 0.3, -minf(_cw, _ch) * 0.3)
		var txt: String = "×%d" % bet_amount
		var tw: Vector2 = mf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs)
		draw_rect(Rect2(at - Vector2(4, tw.y * 0.8), tw + Vector2(8, 4)), Palette.INK)
		draw_string(mf, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, Palette.CYAN)
	if hover_spot != "" and slip != null and slip.check(hover_spot) == BetSlip.PlaceResult.OK:
		var ghost: Color = Palette.GOLD_LIGHT
		ghost.a = 0.35
		draw_circle(spot_anchor(hover_spot), minf(_cw, _ch) * CHIP_RADIUS_RATIO, ghost)


func _cell(rect: Rect2, col: Color, hovered: bool, winning: bool) -> void:
	var c: Color = col
	if hovered:
		c = c.lightened(0.18)
	if winning and flash_t > 0.0:
		c = c.lerp(Palette.GOLD_LIGHT, 0.5 * clampf(flash_t, 0.0, 1.0) * (0.6 + 0.4 * sin(flash_t * 20.0)))
	draw_rect(rect, c)
	draw_rect(rect, Palette.GOLD, false, 2.0)


func _text_center(f: Font, t: String, c: Vector2, fs: int, col: Color) -> void:
	var sz: Vector2 = f.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(f, c + Vector2(-sz.x * 0.5, sz.y * 0.32), t, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)


func _draw_chip(p: Vector2, count: int) -> void:
	var rad: float = minf(_cw, _ch) * CHIP_RADIUS_RATIO
	var stack: int = mini(count, 5)
	var tex: Texture2D = IconLibrary.sprite(CHIP_SPRITE)
	for k: int in stack:
		var o: Vector2 = Vector2(0, -float(k) * 3.0)
		draw_circle(p + o + Vector2(2, 3), rad, Color(0, 0, 0, 0.45))
		if tex != null:
			draw_texture_rect(tex, Rect2(p + o - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false)
		else:
			draw_circle(p + o, rad, Palette.MAGENTA)
			draw_arc(p + o, rad * 0.72, 0.0, TAU, 24, Palette.IVORY, 2.0, true)
	var f: Font = UiKit.font("mono")
	var fs: int = UiKit.fs(int(rad))
	var t: String = str(count)
	var sz: Vector2 = f.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var top: Vector2 = p + Vector2(0, -float(stack - 1) * 3.0)
	draw_string(f, top + Vector2(-sz.x * 0.5, sz.y * 0.3), t, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Palette.IVORY)
