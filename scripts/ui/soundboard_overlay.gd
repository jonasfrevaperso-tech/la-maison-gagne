class_name SoundboardOverlay
extends Overlay
## Table d'écoute (Options > Audio) : chaque effet sonore, joué au volume du jeu, peut être
## marqué « bien » ou « à revoir ». Les avis vont dans user://audio_review.json, que
## `tools/audio_mix.py` affiche pour guider le remplacement des sons.

const REVIEW_FILE: String = "audio_review.json"
const LIST_SIZE: Vector2 = Vector2(900, 560)
const ROW_LABEL_W: float = 330.0

var _review: Dictionary = {}
var _rows: Dictionary[String, Array] = {}


func build() -> void:
	cancel_closes = true
	panel_width = 980.0
	heading(tr("SOUNDBOARD_TITLE"))
	var intro: Label = UiKit.label(tr("SOUNDBOARD_INTRO"), UiKit.SIZE_SMALL, Palette.SMOKE)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(LIST_SIZE.x, 0)
	body.add_child(intro)
	_review = _load()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var first: Button = null
	for sid: String in AudioBus.sfx_ids():
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var l: Label = UiKit.label(sid, UiKit.SIZE_BODY, Palette.IVORY, "mono")
		l.custom_minimum_size = Vector2(ROW_LABEL_W, 0)
		h.add_child(l)
		var play: Button = UiKit.button(tr("SOUNDBOARD_PLAY"), AudioBus.play.bind(sid), Vector2(130, 40))
		h.add_child(play)
		if first == null:
			first = play
		var good: Button = UiKit.button(tr("SOUNDBOARD_GOOD"), _mark.bind(sid, "good"), Vector2(150, 40))
		var bad: Button = UiKit.button(tr("SOUNDBOARD_BAD"), _mark.bind(sid, "bad"), Vector2(170, 40))
		h.add_child(good)
		h.add_child(bad)
		_rows[sid] = [good, bad]
		_paint(sid)
		list.add_child(h)
	var r: HBoxContainer = row()
	r.add_child(UiKit.button(tr("MENU_BACK"), close))
	if first != null:
		first.call_deferred("grab_focus")
	closed.connect(queue_free)


func _mark(sid: String, verdict: String) -> void:
	if String(_review.get(sid, "")) == verdict:
		_review.erase(sid)
	else:
		_review[sid] = verdict
	_paint(sid)
	_save()


func _paint(sid: String) -> void:
	var v: String = String(_review.get(sid, ""))
	var buttons: Array = _rows[sid]
	(buttons[0] as Button).modulate = Palette.EMERALD if v == "good" else Color.WHITE
	(buttons[1] as Button).modulate = Palette.DANGER if v == "bad" else Color.WHITE


static func path() -> String:
	return DevMode.save_dir() + REVIEW_FILE


func _load() -> Dictionary:
	var parsed: Variant = SaveSystem.parse_quiet(FileAccess.get_file_as_string(path())) if FileAccess.file_exists(path()) else null
	return parsed as Dictionary if parsed is Dictionary else {}


func _save() -> void:
	SaveSystem.write_atomic(path(), _review)
