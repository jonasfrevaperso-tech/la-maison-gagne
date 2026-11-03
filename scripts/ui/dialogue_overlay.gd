class_name DialogueOverlay
extends Control
## Dialogue façon visual novel : portrait animé, nom, texte tapé avec « blips » synthétiques,
## choix à conséquences (effets appliqués au run, mémorisés dans le profil).

signal closed

const CHARS_PER_SEC: float = 30.0
const BLIP_EVERY: int = 2
## Respiration après la ponctuation (secondes) et fondu d'entrée du panneau et des portraits.
const PUNCT_PAUSE: float = 0.22
const COMMA_PAUSE: float = 0.09
const LINE_FADE: float = 0.35
const PANEL_H: float = 300.0
const MARGIN: float = 40.0

## Hauteur minimale de la zone de texte (trois lignes) : le panneau ne saute pas d'une réplique à l'autre.
const TEXT_MIN_H: float = 120.0

var dialogue: Dictionary = {}
var run: RunState = null
var db: ContentDB = null
var _lines: Array = []
var _index: int = -1
var _typed: float = 0.0
var _pause: float = 0.0
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
	_lines = personalize(dialogue.get("lines", []) as Array, run.character_id if run != null else "")
	return self


## Dialogue déjà vu sur ce profil (scènes « une seule fois » : boutique, machine à sous, pacte).
static func seen(dialogue_id: String) -> bool:
	return ((SaveSystem.profile.get("campaign", {}) as Dictionary).get("dialogues_seen", []) as Array).has(dialogue_id)


static func _mark_seen(dialogue_id: String) -> void:
	var camp: Dictionary = SaveSystem.profile.get("campaign", {})
	var seen_ids: Array = camp.get("dialogues_seen", [])
	if not seen_ids.has(dialogue_id):
		seen_ids.append(dialogue_id)
	camp["dialogues_seen"] = seen_ids
	SaveSystem.profile["campaign"] = camp


## Répliques propres au personnage joué : `heroes` restreint une réplique à certains
## personnages, `by_hero` remplace son texte (et éventuellement son locuteur) selon le personnage.
static func personalize(lines: Array, hero: String) -> Array:
	var out: Array = []
	for ln: Variant in lines:
		var line: Dictionary = (ln as Dictionary).duplicate()
		if line.has("heroes") and not (line["heroes"] as Array).has(hero):
			continue
		var by: Dictionary = line.get("by_hero", {})
		if by.has(hero):
			line.merge(by[hero] as Dictionary, true)
		out.append(line)
	return out


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	var dim: ColorRect = UiKit.background(Color(0, 0, 0, 0.45))
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel: PanelContainer = UiKit.panel(Palette.INK, Palette.GOLD)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -PANEL_H - MARGIN
	panel.offset_bottom = -MARGIN
	panel.offset_left = MARGIN
	panel.offset_right = -MARGIN
	# Les choix agrandissent le panneau vers le haut (jamais hors de l'écran ni sur le texte).
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Un clic / toucher sur la boîte de texte fait avancer (seuls les boutons de choix l'arrêtent).
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(0, TEXT_MIN_H)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_pause = 0.0
	_last_blip_char = 0
	_text.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_text, "modulate:a", 1.0, LINE_FADE)
	if _portrait != null:
		_portrait.modulate.a = 0.0
		tw.tween_property(_portrait, "modulate:a", 1.0, LINE_FADE)
	_waiting_choice = false


func _process(delta: float) -> void:
	if _text == null or _text.visible_characters < 0:
		return
	var total: int = _text.get_total_character_count()
	if _text.visible_characters >= total:
		_text.visible_characters = -1
		_on_line_typed()
		return
	if _pause > 0.0:
		_pause -= delta * maxf(Settings.speed(), 1.0)
		return
	_typed += delta * CHARS_PER_SEC * maxf(Settings.speed(), 1.0)
	var shown: int = mini(int(_typed), total)
	if shown > _text.visible_characters and shown < total:
		var ch: String = _text.get_parsed_text().substr(shown - 1, 1)
		if ch in [".", "!", "?", "…", ":"]:
			_pause = PUNCT_PAUSE
		elif ch in [",", ";"]:
			_pause = COMMA_PAUSE
	_text.visible_characters = shown
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
		if not _choice_available(choices[i] as Dictionary):
			continue
		var b: Button = UiKit.button(Localization.t(choices[i] as Dictionary, "text"), _choose.bind(i), Vector2(900, 50))
		_choices.add_child(b)
		if _choices.get_child_count() == 1:
			b.call_deferred("grab_focus")


func _choice_available(choice: Dictionary) -> bool:
	if run == null or not choice.has("if"):
		return true
	var env: EffectEnv = EffectEnv.new()
	env.run = run
	env.db = db
	return EffectRunner.check_all(choice["if"] as Array, env)


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
	_mark_seen(String(dialogue.get("id", "")))
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
	if GameInput.pressed(event, "ui_accept") or GameInput.pressed(event, "ui_spin"):
		_advance()
		get_viewport().set_input_as_handled()
	elif GameInput.pressed(event, "ui_cancel"):
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
	_mark_seen(String(dialogue.get("id", "")))
	closed.emit()
