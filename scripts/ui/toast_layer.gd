class_name ToastLayer
extends Control
## Messages courts (succès, erreurs, infos) et sous-titres des sons importants.

const TOAST_TIME: float = 2.6
const MARGIN: float = 24.0
const WIDTH: float = 460.0

var _box: VBoxContainer = null
var _subtitle: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_box.position = Vector2(-WIDTH - MARGIN, MARGIN)
	_box.custom_minimum_size = Vector2(WIDTH, 0.0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_subtitle = Label.new()
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.position.y = -MARGIN * 3.0
	_subtitle.add_theme_color_override("font_color", Palette.IVORY)
	_subtitle.add_theme_color_override("font_outline_color", Palette.INK)
	_subtitle.add_theme_constant_override("outline_size", 8)
	add_child(_subtitle)
	EventBus.toast.connect(_on_toast)
	EventBus.subtitle.connect(_on_subtitle)


func _on_toast(text: String, kind: StringName) -> void:
	var panel: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Palette.VELVET_DEEP
	sb.border_color = Palette.DANGER if kind == &"error" else (Palette.EMERALD if kind == &"success" else Palette.GOLD)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Palette.IVORY)
	panel.add_child(l)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(panel)
	panel.modulate.a = 0.0
	var tw: Tween = panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_interval(TOAST_TIME)
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(panel.queue_free)


func _on_subtitle(text: String) -> void:
	if not Settings.b("access", "subtitles"):
		return
	_subtitle.text = "[%s]" % text
	_subtitle.modulate.a = 1.0
	var tw: Tween = _subtitle.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_subtitle, "modulate:a", 0.0, 0.4)
