class_name Overlay
extends Control
## Base des surcouches modales : fond assombri, panneau central animé, signal `closed`.

signal closed

const DIM: Color = Color(0.02, 0.01, 0.03, 0.78)
const POP_TIME: float = 0.22

var panel: PanelContainer = null
var body: VBoxContainer = null
var panel_width: float = 900.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = UiKit.panel(Palette.VELVET_DEEP, Palette.GOLD)
	panel.custom_minimum_size = Vector2(panel_width, 0)
	center.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	panel.add_child(body)
	build()
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tw: Tween = panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, POP_TIME / maxf(Settings.speed(), 1.0)).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.tween_property(panel, "modulate:a", 1.0, POP_TIME * 0.6)
	AudioBus.ui("panel_open")


## À surcharger : remplit `body`.
func build() -> void:
	pass


func close() -> void:
	AudioBus.ui("panel_close")
	closed.emit()


func heading(text: String) -> Label:
	var l: Label = UiKit.title(text, UiKit.SIZE_H1)
	body.add_child(l)
	return l


func row() -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	body.add_child(h)
	return h
