class_name ActTitle
extends Control
## Carte de titre d'acte animée (rayons art déco, lettres qui tombent, fermeture auto).

signal closed

const HOLD: float = 2.2
const ACT_KEYS: Array[String] = ["ACT_1_TITLE", "ACT_2_TITLE", "ACT_3_TITLE"]

var act: int = 1
var _done: bool = false


func configure(p_act: int) -> ActTitle:
	act = p_act
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	var bg: DecoBackground = DecoBackground.new()
	bg.origin_ratio = Vector2(0.5, 0.5)
	add_child(bg)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	var num: Label = UiKit.title(tr("ACT_NUMBER") % ["I", "II", "III"][clampi(act - 1, 0, 2)], UiKit.SIZE_H1)
	num.add_theme_color_override("font_color", Palette.MAGENTA)
	v.add_child(num)
	var t: Label = UiKit.title(tr(ACT_KEYS[clampi(act - 1, 0, 2)]), UiKit.SIZE_TITLE)
	v.add_child(t)
	var sub: Label = UiKit.label(tr(ACT_KEYS[clampi(act - 1, 0, 2)] + "_SUB"), UiKit.SIZE_H2, Palette.IVORY, "display")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	for i: int in v.get_child_count():
		var c: Control = v.get_child(i) as Control
		c.modulate.a = 0.0
		var tw: Tween = c.create_tween()
		tw.tween_interval(0.25 * float(i) / maxf(Settings.speed(), 1.0))
		tw.tween_property(c, "modulate:a", 1.0, 0.4)
	AudioBus.play("boss_enter" if act == 3 else "deadline_won")
	var timer: SceneTreeTimer = get_tree().create_timer(HOLD / maxf(Settings.speed(), 1.0))
	timer.timeout.connect(_finish)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if GameInput.pressed(event, "ui_accept") or GameInput.pressed(event, "ui_spin"):
		_finish()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if _done:
		return
	_done = true
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(closed.emit)
