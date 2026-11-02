class_name ScorePanel
extends Control
## Affichage « Jetons × Mult = Score » façon calculatrice de casino.
## Les valeurs gonflent et vibrent à chaque changement ; le total compte en montant.
## Grands nombres (façon Balatro) : plus le Mult (et les Jetons) grimpe, plus sa case tremble,
## change de couleur et s'embrase — l'intensité suit le logarithme de la valeur.

const BOX_W: float = 230.0
const BOX_H: float = 92.0
const GAP: float = 54.0
const BUMP_SCALE: float = 1.25
const BUMP_TIME: float = 0.14
const SHAKE_MULT_THRESHOLD: float = 10.0
## Mult (puissance de 10) à partir duquel la case est au maximum de son effet.
const MULT_HEAT_MAX_LOG: float = 3.0
## Jetons : début et plein effet (puissances de 10).
const CHIPS_HEAT_FROM_LOG: float = 2.5
const CHIPS_HEAT_MAX_LOG: float = 6.0
const FLAME_TONGUES: int = 9
const FLAME_MAX_H: float = 64.0
const SHAKE_MAX_PX: float = 7.0
const TILT_MAX: float = 0.06

var chips: float = 0.0
var mult: float = 1.0
var total: float = 0.0
var _chips_label: Label = null
var _mult_label: Label = null
var _total_label: Label = null
var _chips_box: PanelContainer = null
var _mult_box: PanelContainer = null
var _vibrate: float = 0.0
var _mult_heat: float = 0.0
var _chips_heat: float = 0.0
var _flames: Control = null


func _ready() -> void:
	custom_minimum_size = Vector2(BOX_W * 2.0 + GAP, BOX_H * 1.9)
	_flames = Control.new()
	_flames.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flames.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flames.draw.connect(_draw_flames)
	add_child(_flames)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(row)
	_chips_box = _box(Palette.CHIPS_BLUE)
	_chips_label = _value_label()
	_chips_box.add_child(_chips_label)
	row.add_child(_chips_box)
	var x: Label = UiKit.label("×", UiKit.SIZE_H1, Palette.GOLD_LIGHT, "display")
	row.add_child(x)
	_mult_box = _box(Palette.MULT_RED)
	_mult_label = _value_label()
	_mult_box.add_child(_mult_label)
	row.add_child(_mult_box)
	_total_label = UiKit.label("0", UiKit.SIZE_H1, Palette.GOLD_LIGHT, "mono")
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_total_label.position.y = BOX_H + 8.0
	_total_label.add_theme_color_override("font_outline_color", Palette.INK)
	_total_label.add_theme_constant_override("outline_size", 8)
	add_child(_total_label)
	reset()


func _box(col: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.custom_minimum_size = Vector2(BOX_W, BOX_H)
	p.add_theme_stylebox_override("panel", UiKit.flat(col.darkened(0.55), col, 3, 8, 6))
	p.pivot_offset = Vector2(BOX_W, BOX_H) * 0.5
	return p


func _value_label() -> Label:
	var l: Label = UiKit.label("0", UiKit.SIZE_H1, Palette.IVORY, "mono")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func reset() -> void:
	chips = 0.0
	mult = Balance.f("score.base_mult")
	total = 0.0
	_refresh()
	_total_label.text = ""


func set_values(p_chips: float, p_mult: float) -> void:
	var chips_changed: bool = not is_equal_approx(p_chips, chips)
	var mult_changed: bool = not is_equal_approx(p_mult, mult)
	chips = p_chips
	mult = p_mult
	_refresh()
	if chips_changed:
		_bump(_chips_box)
	if mult_changed:
		_bump(_mult_box)
		_vibrate = clampf(log(maxf(mult, 1.0)) / log(SHAKE_MULT_THRESHOLD), 0.0, 1.0)
		AudioBus.set_intensity(_vibrate)
	_mult_heat = heat(mult, 0.0, MULT_HEAT_MAX_LOG)
	_chips_heat = heat(chips, CHIPS_HEAT_FROM_LOG, CHIPS_HEAT_MAX_LOG)


func show_total(value: int, duration: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_method(_set_total, total, float(value), maxf(duration, 0.01)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	total = float(value)


func _set_total(v: float) -> void:
	_total_label.text = Localization.format_number(v)


func _refresh() -> void:
	_chips_label.text = Localization.format_number(chips)
	_mult_label.text = _fmt_mult(mult)


static func _fmt_mult(m: float) -> String:
	if m >= 100.0 or is_equal_approx(m, round(m)):
		return Localization.format_number(m)
	return "%.1f" % m


func _bump(c: Control) -> void:
	var s: float = 1.0 + (BUMP_SCALE - 1.0) * JuiceProfile.intensity()
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "scale", Vector2(s, s), BUMP_TIME * 0.5)
	tw.tween_property(c, "scale", Vector2.ONE, BUMP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Intensité 0–1 selon la puissance de 10 de la valeur (de `from_log` à `max_log`).
static func heat(v: float, from_log: float, max_log: float) -> float:
	if v <= 1.0:
		return 0.0
	return clampf((log(v) / log(10.0) - from_log) / maxf(max_log - from_log, 0.01), 0.0, 1.0)


func _process(_delta: float) -> void:
	var juice: float = JuiceProfile.intensity()
	var ms: float = Time.get_ticks_msec()
	if juice > 0.0:
		var a: float = (_vibrate * 2.5 + _mult_heat * SHAKE_MAX_PX) * juice
		_mult_box.position.y = sin(ms * 0.05) * a
		_mult_box.rotation = sin(ms * 0.033) * TILT_MAX * _mult_heat * juice
		_chips_box.rotation = sin(ms * 0.041) * TILT_MAX * _chips_heat * juice
	else:
		_mult_box.position.y = 0.0
		_mult_box.rotation = 0.0
		_chips_box.rotation = 0.0
	# Couleur : ivoire → or → arc-en-ciel au sommet.
	_mult_label.add_theme_color_override("font_color", _heat_color(_mult_heat, ms))
	_chips_label.add_theme_color_override("font_color", _heat_color(_chips_heat, ms + 900.0))
	if _mult_heat > 0.0 or _chips_heat > 0.0:
		_flames.queue_redraw()


static func _heat_color(h: float, ms: float) -> Color:
	if h <= 0.0:
		return Palette.IVORY
	if h < 0.6:
		return Palette.IVORY.lerp(Palette.GOLD_LIGHT, h / 0.6)
	var hue: Color = Color.from_hsv(fmod(ms * 0.0004, 1.0), 0.55, 1.0)
	return Palette.GOLD_LIGHT.lerp(hue, (h - 0.6) / 0.4)


## Flammes au-dessus des cases (hauteur et densité selon la chaleur).
func _draw_flames() -> void:
	if JuiceProfile.intensity() <= 0.0:
		return
	var inv: Transform2D = _flames.get_global_transform().affine_inverse()
	var ms: float = Time.get_ticks_msec()
	for pair: Array in [[_mult_box, _mult_heat, Palette.MULT_RED], [_chips_box, _chips_heat, Palette.CHIPS_BLUE]]:
		var h: float = float(pair[1])
		if h <= 0.05:
			continue
		var box: Control = pair[0] as Control
		var r: Rect2 = box.get_global_rect()
		var top_left: Vector2 = inv * r.position
		var w: float = r.size.x
		for k: int in FLAME_TONGUES:
			var u: float = (float(k) + 0.5) / float(FLAME_TONGUES)
			var flick: float = 0.6 + 0.4 * sin(ms * 0.012 + float(k) * 1.7)
			var fh: float = FLAME_MAX_H * h * flick * (0.6 + 0.4 * sin(u * PI))
			var base: Vector2 = top_left + Vector2(w * u, 6.0)
			var half: float = w / float(FLAME_TONGUES) * 0.75
			var tip: Vector2 = base + Vector2(sin(ms * 0.006 + float(k)) * 8.0, -fh)
			var col: Color = (pair[2] as Color).lerp(Palette.GOLD_LIGHT, 0.35)
			_flames.draw_colored_polygon(PackedVector2Array([base - Vector2(half, 0), tip, base + Vector2(half, 0)]), Color(col, 0.55))
			var inner: Vector2 = base + (tip - base) * 0.55
			var core: PackedVector2Array = PackedVector2Array([base - Vector2(half * 0.45, 0), inner, base + Vector2(half * 0.45, 0)])
			_flames.draw_colored_polygon(core, Color(Palette.GOLD_LIGHT, 0.7))
