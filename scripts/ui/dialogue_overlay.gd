class_name DialogueOverlay
extends Control
## Dialogue façon visual novel : portrait animé, nom, texte tapé avec « blips » synthétiques,
## choix à conséquences (effets appliqués au run, mémorisés dans le profil).

signal closed

const CHARS_PER_SEC: float = 48.0
const BLIP_EVERY: int = 2
const PANEL_H: float = 300.0
const MARGIN: float = 40.0

var dialogue: Dictionary = {}
var run: RunState = null
var db: ContentDB = null
var _lines: Array = []
var _index: int = -1
var _typed: float = 0.0
var _portrait: PortraitView = null
var _name: Label = null
var _text: RichTextLabel = null
var _choices: VBoxContainer = null
var _portrait_box: Control = null
var _blip: String = "blip_npc"
var _last_blip_char: int = 0
var _waiting_choice: bool = false


func configure(dialogue_id: String, p_run: RunState, p_db: ContentDB) -> DialogueOverlay:
	db = p_db
	run = p_run
	dialogue = db.get_entry("dialogues", dialogue_id)
	_lines = dialogue.get("lines", [])
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	var dim: ColorRect = UiKit.background(Color(0, 0, 0, 0.45))
	add_child(dim)
	var panel: PanelContainer = UiKit.panel(Palette.INK, Palette.GOLD)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -PANEL_H - MARGIN
	panel.offset_bottom = -MARGIN
	panel.offset_left = MARGIN
	panel.offset_right = -MARGIN
	add_child(panel)
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	panel.add_child(h)
	_portrait_box = Control.new()
	_portrait_box.custom_minimum_size = Vector2(PortraitView.SIZE_PX, PortraitView.SIZE_PX)
	h.add_child(_portrait_box)
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_name = UiKit.label("", UiKit.SIZE_H2, Palette.GOLD_LIGHT, "display")
	v.add_child(_name)
	_text = UiKit.rich("", UiKit.SIZE_H2 - 4)
	_text.fit_content = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	v.add_child(_choices)
	_next()


func _speaker(who: String) -> Dictionary:
	if who == "hero" and run != null:
		var c: Dictionary = db.get_entry("characters", run.character_id)
		return {
			"name_fr": c.get("name_fr", ""),
			"name_en": c.get("name_en", ""),
			"portrait": c.get("portrait", ""),
			"blip": c.get("blip", "blip_npc"),
			"color": c.get("color", "f2d27a")
		}
	if db.has_entry("creditors", who):
		var cr: Dictionary = db.get_entry("creditors", who)
		return {
			"name_fr": cr.get("name_fr", ""),
			"name_en": cr.get("name_en", ""),
			"portrait": cr.get("portrait", who),
			"blip": "blip_boss",
			"color": cr.get("color", "ff2e88")
		}
	return db.get_entry("speakers", who)


func _next() -> void:
	_index += 1
	for c: Node in _choices.get_children():
		c.queue_free()
	if _index >= _lines.size():
		_finish()
		return
	var line: Dictionary = _lines[_index]
	var spk: Dictionary = _speaker(String(line.get("who", "narrator")))
	var col: Color = Color(String(spk.get("color", "f5f0e6")))
	_name.text = Localization.t(spk, "name")
	_name.add_theme_color_override("font_color", col)
	_blip = String(spk.get("blip", "blip_npc"))
	for c2: Node in _portrait_box.get_children():
		c2.queue_free()
	_portrait = null
	if String(spk.get("portrait", "")) != "":
		_portrait = PortraitView.new().configure(String(spk["portrait"]), col)
		_portrait.talking = true
		_portrait_box.add_child(_portrait)
	var italic: bool = String(line.get("who", "")) == "narrator"
	_text.text = ("[i]%s[/i]" if italic else "%s") % Localization.t(line, "text")
	_text.visible_characters = 0
	_typed = 0.0
	_last_blip_char = 0
	_waiting_choice = false


func _process(delta: float) -> void:
	if _text == null or _text.visible_characters < 0:
		return
	var total: int = _text.get_total_character_count()
	if _text.visible_characters >= total:
		_text.visible_characters = -1
		_on_line_typed()
		return
	_typed += delta * CHARS_PER_SEC * maxf(Settings.speed(), 1.0)
	_text.visible_characters = mini(int(_typed), total)
	if _text.visible_characters - _last_blip_char >= BLIP_EVERY:
		_last_blip_char = _text.visible_characters
		AudioBus.play(_blip, 1.0, -6.0, "UI")


func _on_line_typed() -> void:
	if _portrait != null:
		_portrait.talking = false
	var line: Dictionary = _lines[_index]
	var choices: Array = line.get("choices", [])
	if choices.is_empty():
		return
	_waiting_choice = true
	for i: int in choices.size():
		var b: Button = UiKit.button(Localization.t(choices[i] as Dictionary, "text"), _choose.bind(i), Vector2(900, 50))
		_choices.add_child(b)
		if i == 0:
			b.call_deferred("grab_focus")


func _choose(i: int) -> void:
	var line: Dictionary = _lines[_index]
	var choice: Dictionary = (line.get("choices", []) as Array)[i]
	if run != null:
		var env: EffectEnv = EffectEnv.new()
		env.run = run
		env.db = db
		env.source_id = String(dialogue.get("id", ""))
		for eff: Variant in choice.get("effects", []):
			EffectRunner.run_effect(eff as Dictionary, env)
		var mem: Dictionary = run.flags.get("choices", {})
		mem["%s:%d" % [dialogue.get("id", ""), _index]] = i
		run.flags["choices"] = mem
	var camp: Dictionary = SaveSystem.profile.get("campaign", {})
	var seen: Array = camp.get("dialogues_seen", [])
	if not seen.has(String(dialogue.get("id", ""))):
		seen.append(String(dialogue.get("id", "")))
	camp["dialogues_seen"] = seen
	AudioBus.ui("click")
	_next()


func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	):
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_spin"):
		_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_finish()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if _waiting_choice:
		return
	if _text.visible_characters >= 0:
		_text.visible_characters = -1
		_on_line_typed()
		return
	_next()


func _finish() -> void:
	set_process(false)
	closed.emit()
