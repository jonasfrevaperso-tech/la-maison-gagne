class_name Overlay
extends Control
## Base des surcouches modales : fond assombri, panneau central animé, signal `closed`.

signal closed

const DIM: Color = Color(0.02, 0.01, 0.03, 0.78)
const POP_TIME: float = 0.22
## Part de la fenêtre que peut occuper un panneau.
const FIT_MARGIN: float = 0.96

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
	panel.modulate.a = 0.0
	AudioBus.ui("panel_open")
	_pop.call_deferred()


## Apparition une fois la mise en page faite (la taille réelle du panneau est connue).
func _pop() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var fit: float = fit_scale()
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.85, 0.85) * fit
	var tw: Tween = panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(fit, fit), POP_TIME / maxf(Settings.speed(), 1.0)).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.tween_property(panel, "modulate:a", 1.0, POP_TIME * 0.6)


## Échelle qui fait tenir le panneau dans la fenêtre logique (petites fenêtres, grande police).
func fit_scale() -> float:
	var need: Vector2 = panel.size
	var room: Vector2 = size * FIT_MARGIN
	if need.x <= 0.0 or need.y <= 0.0:
		return 1.0
	return minf(1.0, minf(room.x / need.x, room.y / need.y))


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
