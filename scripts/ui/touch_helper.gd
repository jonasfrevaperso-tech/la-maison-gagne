class_name TouchHelper
extends CanvasLayer
## Mobile uniquement : comportements tactiles valables pour tout le jeu.
## - Appui long sur un contrôle qui a une infobulle (`tooltip_text`) : la bulle s'affiche à
##   l'opposé du doigt, et se ferme au toucher suivant (il n'y a pas de survol au doigt).
## - Après un toucher, le pointeur émulé est envoyé hors de l'écran : plus de survol « collé ».
## - Listes défilantes : seuil de défilement, pour qu'un toucher sur un bouton ne fasse pas
##   défiler la liste, et défilement au doigt.

const HOLD_TIME: float = 0.45
const HOLD_SLOP: float = 24.0
const SCROLL_DEADZONE: int = 18
const BUBBLE_W: float = 620.0
const FINGER_GAP: float = 90.0
const OFFSCREEN: Vector2 = Vector2(-4000.0, -4000.0)

var _down: bool = false
var _down_at: Vector2 = Vector2.ZERO
var _held: float = 0.0
var _shown_for: Control = null
var _bubble: PanelContainer = null
var _text: RichTextLabel = null
var _park_next: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UiKit.flat(Color(Palette.INK, 0.94), Palette.GOLD, 2, 6, 18))
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	add_child(_bubble)
	_text = UiKit.rich("", UiKit.SIZE_BODY)
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(BUBBLE_W, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_text)


func _on_node_added(n: Node) -> void:
	var sc: ScrollContainer = n as ScrollContainer
	if sc != null:
		sc.scroll_deadzone = SCROLL_DEADZONE


func _input(event: InputEvent) -> void:
	var t: InputEventScreenTouch = event as InputEventScreenTouch
	if t != null and t.index == 0:
		if t.pressed:
			_down = true
			_down_at = t.position
			_held = 0.0
			if _bubble.visible:
				_hide()
		else:
			_down = false
			_park_next = true
		return
	var d: InputEventScreenDrag = event as InputEventScreenDrag
	if d != null and d.index == 0 and d.position.distance_to(_down_at) > HOLD_SLOP:
		_held = -1.0  # le doigt a glissé : pas d'appui long


func _process(delta: float) -> void:
	if _park_next:
		_park_next = false
		_park_pointer()
	if not _down or _held < 0.0:
		return
	_held += delta
	if _held >= HOLD_TIME:
		_held = -1.0
		_try_tooltip()


## Pointeur émulé hors de l'écran : les survols se terminent quand le doigt se lève.
func _park_pointer() -> void:
	var mm: InputEventMouseMotion = InputEventMouseMotion.new()
	mm.device = InputEvent.DEVICE_ID_EMULATION
	mm.position = OFFSCREEN
	mm.global_position = OFFSCREEN
	Input.parse_input_event(mm)


func _try_tooltip() -> void:
	var c: Control = get_viewport().gui_get_hovered_control()
	while c != null and c.tooltip_text == "":
		c = c.get_parent() as Control
	if c == null:
		return
	var local: Vector2 = c.get_global_transform_with_canvas().affine_inverse() * _down_at
	var tip: String = c.get_tooltip(local)
	if tip == "":
		tip = c.tooltip_text
	if tip.strip_edges() == "":
		return  # infobulle sur mesure (cartes : fiche au toucher)
	show_at(tip, _down_at)
	_shown_for = c
	Platform.haptic(15)


## Bulle d'aide à l'opposé du doigt (au-dessus s'il touche le bas de l'écran, sinon dessous),
## toujours dans la zone sûre.
func show_at(text: String, finger: Vector2) -> void:
	_text.text = text
	_bubble.visible = true
	_bubble.reset_size()
	await get_tree().process_frame
	var safe: Rect2 = Platform.safe_rect(get_viewport())
	var sz: Vector2 = _bubble.size
	var pos: Vector2 = Vector2(finger.x - sz.x * 0.5, finger.y - FINGER_GAP - sz.y)
	if pos.y < safe.position.y:
		pos.y = finger.y + FINGER_GAP
	pos.x = clampf(pos.x, safe.position.x, safe.end.x - sz.x)
	pos.y = clampf(pos.y, safe.position.y, safe.end.y - sz.y)
	_bubble.position = pos


func _hide() -> void:
	_bubble.visible = false
	_shown_for = null
