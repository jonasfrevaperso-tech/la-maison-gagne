class_name ScorePanel
extends Control
## Affichage « Jetons × Mult = Score » façon calculatrice de casino.
## Les valeurs gonflent et vibrent à chaque changement ; le total compte en montant.

const BOX_W: float = 230.0
const BOX_H: float = 92.0
const GAP: float = 54.0
const BUMP_SCALE: float = 1.25
const BUMP_TIME: float = 0.14
const SHAKE_MULT_THRESHOLD: float = 10.0

var chips: float = 0.0
var mult: float = 1.0
var total: float = 0.0
var _chips_label: Label = null
var _mult_label: Label = null
var _total_label: Label = null
var _chips_box: PanelContainer = null
var _mult_box: PanelContainer = null
var _vibrate: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(BOX_W * 2.0 + GAP, BOX_H * 1.9)
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


func _process(_delta: float) -> void:
	if _vibrate > 0.0 and JuiceProfile.intensity() > 0.0:
		var a: float = _vibrate * 2.5 * JuiceProfile.intensity()
		_mult_box.position.y = sin(Time.get_ticks_msec() * 0.05) * a
	else:
		_mult_box.position.y = 0.0
