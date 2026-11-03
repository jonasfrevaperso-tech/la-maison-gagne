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
var _custom: Control = null


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Infobulles natives : coupées sur téléphone par `gui/timers/tooltip_delay_sec.mobile` (lu au
	# démarrage ; l'émulation sur PC les garde en plus de la bulle tactile).
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
			_park_next = false
			_move_pointer(t.position)  # le survol suit le doigt (infobulles, surbrillances)
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
	_move_pointer(OFFSCREEN)


func _move_pointer(at: Vector2) -> void:
	var mm: InputEventMouseMotion = InputEventMouseMotion.new()
	mm.device = InputEvent.DEVICE_ID_EMULATION
	mm.position = at
	mm.global_position = at
	Input.parse_input_event(mm)


func _try_tooltip() -> void:
	# Premier contrôle sous le doigt qui a une infobulle (fixe ou calculée : roue, tapis…).
	var c: Control = get_viewport().gui_get_hovered_control()
	var tip: String = ""
	while c != null:
		tip = c.get_tooltip(c.get_global_transform_with_canvas().affine_inverse() * _down_at)
		if tip == "":
			tip = c.tooltip_text
		if tip != "":
			break
		c = c.get_parent() as Control
	if c == null or c is GrigriCard or c is TableView:
		return  # cartes : fiche au toucher (CardSheet) ; tapis : loupe
	# Infobulle illustrée (roue, pastilles de famille…) quand le contrôle en fournit une.
	var custom: Control = c.call("_make_custom_tooltip", tip) as Control if c.has_method("_make_custom_tooltip") else null
	if custom == null and tip.strip_edges() == "":
		return
	_set_custom(custom)
	show_at(tip if custom == null else "", _down_at)
	_shown_for = c
	Platform.haptic(15)


## Bulle d'aide à l'opposé du doigt (au-dessus s'il touche le bas de l'écran, sinon dessous),
## toujours dans la zone sûre.
func show_at(text: String, finger: Vector2) -> void:
	if text != "":
		if _custom != null:
			_set_custom(null)
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


func _set_custom(custom: Control) -> void:
	if _custom != null:
		_custom.queue_free()
	_custom = custom
	_text.visible = custom == null
	if custom != null:
		custom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bubble.add_child(custom)


func _hide() -> void:
	_bubble.visible = false
	_shown_for = null
	_set_custom(null)
