class_name TutorialDirector
extends Control
## Bulles d'aide contextuelles (data/events/tutorial.json) : déclenchées par des moments de jeu,
## ancrées sur l'élément concerné, non bloquantes, vues une seule fois (profil), rejouables.

signal skipped

const BUBBLE_W: float = 560.0
const TEXT_GLYPH_H: int = 28
const OFFSET: float = 18.0
## Hauteur (part de l'écran) des bulles placées dans la marge gauche (surcouches).
const SIDE_BUBBLE_Y: float = 0.3

## Fonction fournie par l'écran : nom d'ancre -> rectangle global.
var anchor_rect: Callable = Callable()
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _bubble: PanelContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.input_device_changed.connect(func(_pad: bool) -> void: _rebuild_current())


func _rebuild_current() -> void:
	if not _current.is_empty() and _bubble != null:
		_build_bubble()


## Texte de l'astuce pour le périphérique actif (variante manette ou tactile si elle existe), avec les
## jetons {action} remplacés par les invites (glyphes ou touches).
static func tip_text(entry: Dictionary) -> String:
	var lang: String = TranslationServer.get_locale().substr(0, 2)
	var raw: String = ""
	if InputGlyphs.using_pad:
		raw = String(entry.get("text_pad_" + lang, entry.get("text_pad_fr", "")))
	elif InputGlyphs.using_touch:
		raw = String(entry.get("text_touch_" + lang, entry.get("text_touch_fr", "")))
	if raw == "":
		raw = Localization.t(entry, "text")
	return InputGlyphs.expand(raw, TEXT_GLYPH_H)


## Astuce affichée : A / Entrée = compris, X / M = couper les conseils (avant le tapis).
func _input(event: InputEvent) -> void:
	if _bubble == null or _current.is_empty():
		return
	if GameInput.pressed(event, "tip_mute"):
		_skip_all()
		get_viewport().set_input_as_handled()
	elif not _current.has("until") and (GameInput.pressed(event, "ui_accept") or GameInput.pressed(event, "bet_place")):
		_close_current()
		get_viewport().set_input_as_handled()


## Une astuce à valider est ouverte : le jeu attend (mini-jeu de lancer figé).
func blocking() -> bool:
	return _bubble != null and not _current.is_empty() and not _current.has("until")


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
	var l: RichTextLabel = UiKit.rich(tip_text(_current), UiKit.SIZE_BODY - 2)
	l.custom_minimum_size = Vector2(BUBBLE_W - 30, 0)
	v.add_child(l)
	var h: HBoxContainer = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var mute: Button = UiKit.button(tr("TUTO_SKIP_ALL"), _skip_all, Vector2(220, 44))
	mute.focus_mode = Control.FOCUS_NONE
	PromptBadge.attach(mute, "tip_mute")
	h.add_child(mute)
	if not _current.has("until"):
		var ok: Button = UiKit.button(tr("BTN_UNDERSTOOD"), _close_current, Vector2(150, 44))
		ok.focus_mode = Control.FOCUS_NONE
		PromptBadge.attach(ok, "ui_accept")
		h.add_child(ok)
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
	if String(_current.get("anchor", "center")) == "center":
		# Bulle d'une surcouche (boutique, pacte) : dans la marge gauche, hors du panneau centré.
		pos = Vector2(OFFSET, vp.y * SIDE_BUBBLE_Y)
	if pos.y + sz.y > vp.y - 10.0:
		pos.y = target.position.y - sz.y - OFFSET
	pos.x = clampf(pos.x, 10.0, vp.x - sz.x - 10.0)
	pos.y = clampf(pos.y, 10.0, vp.y - sz.y - 10.0)
	_bubble.position = get_global_transform().affine_inverse() * pos


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
