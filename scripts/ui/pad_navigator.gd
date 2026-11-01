class_name PadNavigator
extends Node
## Navigation manette commune à tous les écrans :
## - garde du focus : en mode manette, un contrôle est toujours sélectionné dans la zone active
##   (surcouche la plus haute, sinon l'écran) — sauf sur le tapis, piloté par son curseur ;
## - B (ui_cancel) non consommé → `go_back()` de l'écran ;
## - LB / RB → onglet précédent / suivant du TabContainer de la zone active ;
## - stick droit → défilement de la zone défilante sélectionnée (ou de la première visible) ;
## - toutes les zones défilantes suivent le focus ;
## - curseur de la souris masqué en mode manette.

const SCROLL_SPEED: float = 1400.0
const TIP_W: float = 460.0
const TIP_GAP: float = 10.0
const FRAME_GROW: float = 6.0
const FRAME_W: float = 3.0
const STICK_DEADZONE: float = 0.25

## Renvoie la zone active (Control) : fournie par Main.
var active_root: Callable = Callable()
## Calque (CanvasLayer de Main) où dessiner le cadre de sélection.
var frame_layer: CanvasLayer = null
var _tip: Control = null
var _frame: Control = null


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	if frame_layer != null:
		_frame = Control.new()
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.draw.connect(_draw_frame)
		frame_layer.add_child(_frame)
	EventBus.input_device_changed.connect(_on_device_changed)
	EventBus.settings_changed.connect(_on_settings_changed)
	if InputGlyphs.apply_mode():
		EventBus.input_device_changed.emit.call_deferred(InputGlyphs.using_pad)
	_on_device_changed(InputGlyphs.using_pad)


func _on_settings_changed() -> void:
	if InputGlyphs.apply_mode():
		EventBus.input_device_changed.emit(InputGlyphs.using_pad)


func _on_device_changed(pad: bool) -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if pad else Input.MOUSE_MODE_VISIBLE
	if pad:
		ensure_focus.call_deferred()


func _on_node_added(n: Node) -> void:
	if n is ScrollContainer:
		(n as ScrollContainer).follow_focus = true


func _process(delta: float) -> void:
	if not InputGlyphs.using_pad:
		return
	var v: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(v) > STICK_DEADZONE:
		var sc: ScrollContainer = _scroll_target()
		if sc != null:
			sc.scroll_vertical += int(v * SCROLL_SPEED * delta)
	ensure_focus()
	if _frame != null:
		_frame.queue_redraw()


## Cadre cyan autour des éléments sélectionnés qui n'ont pas de style de focus propre.
func _draw_frame() -> void:
	if not InputGlyphs.using_pad:
		return
	var f: Control = get_viewport().gui_get_focus_owner()
	if f == null or not f.is_visible_in_tree() or f is BaseButton or f is GrigriCard or f is LineEdit or f is TextEdit or f is Range:
		return
	var r: Rect2 = f.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, f.size)
	_frame.draw_rect(r.grow(FRAME_GROW), Palette.CYAN, false, FRAME_W)


## Infobulle au focus (manette) pour tout contrôle qui porte une infobulle texte.
func _on_focus_changed(c: Control) -> void:
	if _tip != null and is_instance_valid(_tip):
		_tip.queue_free()
	_tip = null
	if not InputGlyphs.using_pad or c == null or c is GrigriCard or c.tooltip_text.strip_edges() == "":
		return
	var panel: PanelContainer = UiKit.panel(Palette.INK, Palette.CYAN)
	panel.top_level = true
	panel.z_index = 60
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = UiKit.label(c.tooltip_text, UiKit.SIZE_SMALL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TIP_W, 0)
	panel.add_child(l)
	c.add_child(panel)
	_tip = panel
	_place_tip.call_deferred(c, panel)


func _place_tip(c: Control, panel: Control) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(c):
		return
	var r: Rect2 = UiLayout.canvas_rect(c)
	var sz: Vector2 = panel.get_combined_minimum_size()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var pos: Vector2 = Vector2(r.get_center().x - sz.x * 0.5, r.end.y + TIP_GAP)
	if pos.y + sz.y > vp.y:
		pos.y = r.position.y - sz.y - TIP_GAP
	pos.x = clampf(pos.x, 8.0, vp.x - sz.x - 8.0)
	panel.position = pos


## Champs de texte à la manette : A ouvre le clavier à l'écran, la croix quitte le champ
## (sinon elle déplacerait seulement le curseur de saisie).
func _input(event: InputEvent) -> void:
	if not InputGlyphs.using_pad:
		return
	var f: Control = get_viewport().gui_get_focus_owner()
	if not (f is LineEdit or f is TextEdit):
		return
	if f is LineEdit and not (f as LineEdit).editable:
		return
	if event.is_action_pressed("ui_accept"):
		open_keyboard(f)
		get_viewport().set_input_as_handled()
		return
	var sides: Dictionary[String, Side] = {"ui_up": SIDE_TOP, "ui_down": SIDE_BOTTOM, "ui_left": SIDE_LEFT, "ui_right": SIDE_RIGHT}
	for a: String in sides.keys():
		if event.is_action_pressed(a):
			var n: Control = f.find_valid_focus_neighbor(sides[a])
			if n != null:
				n.grab_focus()
			get_viewport().set_input_as_handled()
			return


func open_keyboard(field: Control) -> void:
	var root: Control = _root()
	var vk: VirtualKeyboard = VirtualKeyboard.new().configure(field)
	vk.uppercase_only = field.has_meta("osk_upper")
	(root if root != null else field.get_tree().root).add_child(vk)


func _unhandled_input(event: InputEvent) -> void:
	if not InputGlyphs.using_pad and not (event is InputEventKey):
		return
	var root: Control = _root()
	if root == null:
		return
	if event.is_action_pressed("bet_cycle_prev") or event.is_action_pressed("bet_cycle_next"):
		var tabs: TabContainer = _find(root, "TabContainer") as TabContainer
		if tabs != null and tabs.is_visible_in_tree():
			var d: int = -1 if event.is_action_pressed("bet_cycle_prev") else 1
			tabs.current_tab = posmod(tabs.current_tab + d, tabs.get_tab_count())
			AudioBus.ui("click")
			var first: Control = first_focusable(tabs.get_current_tab_control())
			if first != null:
				first.grab_focus()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if root.has_method("go_back"):
			root.call("go_back")
			get_viewport().set_input_as_handled()


## En mode manette, redonne le focus à la zone active si personne ne l'a.
func ensure_focus() -> void:
	if not InputGlyphs.using_pad:
		return
	var root: Control = _root()
	if root == null or (root.has_method("wants_pad_focus") and not bool(root.call("wants_pad_focus"))):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var stale: bool = focused is BaseButton and (focused as BaseButton).disabled
	if focused != null and focused.is_visible_in_tree() and root.is_ancestor_of(focused) and not stale:
		return
	var first: Control = first_focusable(root)
	if first != null:
		first.grab_focus()


func _root() -> Control:
	return active_root.call() as Control if active_root.is_valid() else null


func _scroll_target() -> ScrollContainer:
	var f: Control = get_viewport().gui_get_focus_owner()
	var n: Node = f
	while n != null:
		if n is ScrollContainer:
			return n as ScrollContainer
		n = n.get_parent()
	var root: Control = _root()
	return _find(root, "ScrollContainer") as ScrollContainer if root != null else null


static func _find(root: Node, cls: String) -> Node:
	for c: Node in root.find_children("*", cls, true, false):
		if (c as CanvasItem).is_visible_in_tree():
			return c
	return null


## Premier contrôle sélectionnable (visible, actif) sous `root`, en ordre d'arbre.
static func first_focusable(root: Node) -> Control:
	if root == null:
		return null
	for c: Node in root.find_children("*", "Control", true, false):
		var ctl: Control = c as Control
		if ctl.focus_mode != Control.FOCUS_ALL or not ctl.is_visible_in_tree():
			continue
		if ctl is BaseButton and (ctl as BaseButton).disabled:
			continue
		return ctl
	return null
