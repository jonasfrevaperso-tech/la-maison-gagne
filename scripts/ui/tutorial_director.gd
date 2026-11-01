class_name TutorialDirector
extends Control
## Bulles d'aide contextuelles (data/events/tutorial.json) : déclenchées par des moments de jeu,
## ancrées sur l'élément concerné, non bloquantes, vues une seule fois (profil), rejouables.

signal skipped

const BUBBLE_W: float = 520.0
const OFFSET: float = 18.0

## Fonction fournie par l'écran : nom d'ancre -> rectangle global.
var anchor_rect: Callable = Callable()
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _bubble: PanelContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func enabled() -> bool:
	return Settings.b("game", "tutorial_tips")


static func _seen() -> Array:
	var t: Dictionary = SaveSystem.profile.get("tutorial", {})
	if not t.has("tips_seen"):
		t["tips_seen"] = []
	SaveSystem.profile["tutorial"] = t
	return t["tips_seen"]


static func reset() -> void:
	var t: Dictionary = SaveSystem.profile.get("tutorial", {})
	t["tips_seen"] = []
	t["done"] = false
	SaveSystem.profile["tutorial"] = t
	SaveSystem.save_profile()


func notify(trigger: String) -> void:
	if not enabled():
		return
	_queue = _queue.filter(func(q: Dictionary) -> bool: return String(q.get("until", "")) != trigger)
	if not _current.is_empty() and String(_current.get("until", "")) == trigger:
		_close_current()
	var seen: Array = _seen()
	var steps: Array[Dictionary] = []
	for e: Dictionary in DataRegistry.db.list("tutorial"):
		if String(e.get("trigger", "")) == trigger and not seen.has(String(e["id"])):
			var queued: bool = false
			for q: Dictionary in _queue:
				queued = queued or q["id"] == e["id"]
			if not queued and _current.get("id", "") != e["id"]:
				steps.append(e)
	steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	_queue.append_array(steps)
	if _current.is_empty():
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		return
	_current = _queue.pop_front()
	_seen().append(String(_current["id"]))
	_build_bubble()


func _build_bubble() -> void:
	if _bubble != null:
		_bubble.queue_free()
	_bubble = UiKit.panel(Palette.INK, Palette.CYAN)
	_bubble.custom_minimum_size = Vector2(BUBBLE_W, 0)
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_bubble.add_child(v)
	var l: Label = UiKit.label(Localization.t(_current, "text"), UiKit.SIZE_BODY - 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(BUBBLE_W - 30, 0)
	v.add_child(l)
	var h: HBoxContainer = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	h.add_child(UiKit.button(tr("TUTO_SKIP_ALL"), _skip_all, Vector2(200, 40)))
	if not _current.has("until"):
		h.add_child(UiKit.button(tr("BTN_UNDERSTOOD"), _close_current, Vector2(140, 40)))
	add_child(_bubble)
	_place.call_deferred()
	_bubble.modulate.a = 0.0
	_bubble.create_tween().tween_property(_bubble, "modulate:a", 1.0, 0.2)
	AudioBus.ui("panel_open")


func _place() -> void:
	if _bubble == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var target: Rect2 = Rect2(vp * 0.5, Vector2.ZERO)
	if anchor_rect.is_valid():
		target = anchor_rect.call(String(_current.get("anchor", "center")))
	var sz: Vector2 = _bubble.get_combined_minimum_size()
	var pos: Vector2 = Vector2(target.get_center().x - sz.x * 0.5, target.end.y + OFFSET)
	if pos.y + sz.y > vp.y - 10.0:
		pos.y = target.position.y - sz.y - OFFSET
	pos.x = clampf(pos.x, 10.0, vp.x - sz.x - 10.0)
	pos.y = clampf(pos.y, 10.0, vp.y - sz.y - 10.0)
	_bubble.position = pos


func _close_current() -> void:
	if _bubble != null:
		_bubble.queue_free()
		_bubble = null
	_current = {}
	SaveSystem.save_profile()
	_show_next()


func _skip_all() -> void:
	for e: Dictionary in DataRegistry.db.list("tutorial"):
		if not _seen().has(String(e["id"])):
			_seen().append(String(e["id"]))
	var t: Dictionary = SaveSystem.profile["tutorial"]
	t["done"] = true
	_queue.clear()
	_close_current()
	skipped.emit()


func _exit_tree() -> void:
	_queue.clear()
