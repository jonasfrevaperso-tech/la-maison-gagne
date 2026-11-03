class_name CardSheet
extends CanvasLayer
## Tactile : fiche d'une carte (grigri, Fortune, contrat, case) ouverte d'un toucher. Elle
## remplace le survol (description), le double-clic (action principale : acheter, vendre,
## utiliser, prendre), le clic droit (verrouiller) et le glisser au doigt (◀ ▶ pour déplacer).
## Un toucher hors de la fiche la ferme. Une seule fiche à la fois.

const GAP: float = 16.0
const ARROW_BTN: Vector2 = Vector2(110, 100)
const ACTION_BTN: Vector2 = Vector2(240, 100)
const SHADE: Color = Color(0.0, 0.0, 0.0, 0.35)

static var _current: CardSheet = null

var _card: GrigriCard = null
var _box: VBoxContainer = null


## Ouvre la fiche de `card` (ferme la précédente).
static func open(card: GrigriCard) -> CardSheet:
	close_current()
	var sheet: CardSheet = CardSheet.new()
	sheet._card = card
	card.get_tree().root.add_child(sheet)
	_current = sheet
	return sheet


static func close_current() -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = null


static func is_open() -> bool:
	return _current != null and is_instance_valid(_current)


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.theme()
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(_on_shade_input)
	root.add_child(shade)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.flat(Color(Palette.INK, 0.96), Palette.GOLD, 2, 8, 16))
	root.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	panel.add_child(_box)
	var tip: Control = CardTooltip.build(_card.kind, _card.entry_id, _card.edition, _card.counter, _card.price)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(tip)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	_build_actions(row)
	if row.get_child_count() == 0:
		row.queue_free()
	_card.tree_exiting.connect(queue_free)
	AudioBus.ui("panel_open")
	Platform.haptic(10)
	_place.call_deferred(panel)


func _build_actions(row: HBoxContainer) -> void:
	var c: GrigriCard = _card
	var movable: bool = c.kind == "grigri" and c.draggable and c.move_requested.get_connections().size() > 0
	if movable:
		row.add_child(_btn("◀", _move.bind(-1), ARROW_BTN))
	if c.kind == "grigri" and c.lock_toggled.get_connections().size() > 0:
		row.add_child(_btn(tr("CARD_UNLOCK") if c.locked else tr("CARD_LOCK"), _lock, ACTION_BTN))
	if c.action_text != "" and not c.disabled_look and c.activated.get_connections().size() > 0:
		var main: Button = _btn(c.action_text, _activate, ACTION_BTN)
		row.add_child(main)
	if movable:
		row.add_child(_btn("▶", _move.bind(1), ARROW_BTN))


func _btn(text: String, cb: Callable, sz: Vector2) -> Button:
	return UiKit.button(text, cb, sz)


## Au-dessus de la carte si la place le permet, sinon dessous ; toujours dans la zone sûre.
func _place(panel: PanelContainer) -> void:
	if not is_instance_valid(_card):
		return
	panel.reset_size()
	var vp: Viewport = get_viewport()
	var safe: Rect2 = Platform.safe_rect(vp)
	# Rectangle de la carte dans le repère de la fenêtre (celui de la couche de la fiche).
	var me: Rect2 = _card.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _card.size)
	var sz: Vector2 = panel.size
	var pos: Vector2 = Vector2(me.get_center().x - sz.x * 0.5, me.position.y - sz.y - GAP)
	if pos.y < safe.position.y:
		pos.y = me.end.y + GAP
	if pos.y + sz.y > safe.end.y:
		pos.y = safe.end.y - sz.y
	pos.x = clampf(pos.x, safe.position.x, maxf(safe.position.x, safe.end.x - sz.x))
	pos.y = maxf(pos.y, safe.position.y)
	panel.position = pos


func _on_shade_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed:
		close_current()


func _activate() -> void:
	var c: GrigriCard = _card
	close_current()
	if is_instance_valid(c):
		c.activated.emit(c)


func _lock() -> void:
	var c: GrigriCard = _card
	close_current()
	if is_instance_valid(c):
		c.lock_toggled.emit(c)


func _move(direction: int) -> void:
	var c: GrigriCard = _card
	close_current()
	if is_instance_valid(c):
		c.move_requested.emit(c, direction)
