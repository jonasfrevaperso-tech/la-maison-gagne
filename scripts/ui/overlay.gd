class_name Overlay
extends Control
## Base des surcouches modales : fond assombri, panneau central animé, signal `closed`.

signal closed

const DIM: Color = Color(0.02, 0.01, 0.03, 0.78)
const DIM_OVER_BACKDROP: Color = Color(0.02, 0.01, 0.03, 0.42)
const POP_TIME: float = 0.18
## Part de la fenêtre que peut occuper un panneau.
const FIT_MARGIN: float = 0.96
## Marge intérieure des panneaux : laisse la place aux ornements art déco.
const PANEL_PAD: int = 26

var panel: PanelContainer = null
var body: VBoxContainer = null
var panel_width: float = 900.0
## B / Échap ferme la surcouche (surcouches d'information) ; sinon le retour est ignoré
## (choix obligatoires : pacte, événement, boutique).
var cancel_closes: bool = false
## Contrôles de l'écran ou de la surcouche du dessous privés de focus tant que celle-ci est
## ouverte (sinon la navigation manette « s'échappe » vers eux : voisin le plus proche à l'écran).
var _suspended: Array[Array] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	# Décor plein écran propre à la surcouche (boutique, victoire), sous le voile.
	var bd: Control = backdrop()
	if bd != null:
		add_child(bd)
		RenderQuality.cover(true)
		tree_exiting.connect(RenderQuality.cover.bind(false))
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM if bd == null else DIM_OVER_BACKDROP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = UiKit.panel(Palette.VELVET_DEEP, Palette.GOLD)
	panel.add_theme_stylebox_override("panel", UiKit.flat(Palette.VELVET_DEEP, Palette.GOLD, UiKit.BORDER, UiKit.RADIUS, PANEL_PAD))
	panel.custom_minimum_size = Vector2(panel_width, 0)
	center.add_child(panel)
	var deco: DecoFrame = DecoFrame.new()
	deco.out = float(PANEL_PAD)
	panel.add_child(deco)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	panel.add_child(body)
	build()
	_suspend_focus_below()
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
	tw.chain().tween_callback(func() -> void: panel.resized.connect(_refit))
	resized.connect(_refit)


## Le contenu a changé de taille (ou la fenêtre) : on recale l'échelle pour rester dans l'écran.
func _refit() -> void:
	if not is_inside_tree():
		return
	var fit: float = fit_scale()
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(fit, fit)


## Échelle qui fait tenir le panneau dans la fenêtre logique (petites fenêtres, grande police).
func fit_scale() -> float:
	var need: Vector2 = panel.size
	var room: Vector2 = size * FIT_MARGIN
	if need.x <= 0.0 or need.y <= 0.0:
		return 1.0
	return minf(1.0, minf(room.x / need.x, room.y / need.y))


## À surcharger : décor plein écran derrière le panneau (null : la table reste visible, voilée).
func backdrop() -> Control:
	return null


## À surcharger : remplit `body`.
func build() -> void:
	pass


func _suspend_focus_below() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	for n: Node in host.find_children("*", "Control", true, false):
		var c: Control = n as Control
		if c.focus_mode == Control.FOCUS_NONE or c == self or is_ancestor_of(c):
			continue
		_suspended.append([c, c.focus_mode])
		c.focus_mode = Control.FOCUS_NONE
	tree_exiting.connect(_restore_focus_below)


func _restore_focus_below() -> void:
	for pair: Array in _suspended:
		var o: Variant = pair[0]
		if is_instance_valid(o):
			(o as Control).focus_mode = pair[1] as Control.FocusMode
	_suspended.clear()


func close() -> void:
	AudioBus.ui("panel_close")
	closed.emit()


func heading(text: String) -> Label:
	var l: Label = UiKit.title(text, UiKit.SIZE_H1)
	body.add_child(l)
	body.add_child(UiKit.divider(minf(panel_width * 0.6, 640.0)))
	return l


func row() -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	body.add_child(h)
	return h


## Retour (B / Échap), appelé par PadNavigator.
func go_back() -> void:
	if cancel_closes:
		close()
