class_name NoteOverlay
extends Overlay
## Note de test (F8 ou menu pause) : humeur, commentaire libre, capture de l'écran.
## Enregistrée localement par Telemetry (même hors consentement de télémétrie : c'est un
## geste volontaire du joueur), à côté du run en cours.

const MOODS: Array[String] = ["great", "good", "meh", "bad", "bug"]
const MOOD_COLORS: Array[Color] = [Palette.EMERALD, Palette.CYAN, Palette.GOLD_LIGHT, Palette.MAGENTA, Palette.DANGER]
const TEXT_SIZE: Vector2 = Vector2(760, 150)

var _shot: Image = null
var _screen: String = ""
var _mood: String = "meh"
var _mood_buttons: Array[Button] = []
var _text: TextEdit = null
var _attach: CheckBox = null


func configure(shot: Image, screen: String) -> NoteOverlay:
	_shot = shot
	_screen = screen
	panel_width = 820.0
	return self


func build() -> void:
	cancel_closes = true
	heading(tr("NOTE_TITLE"))
	var intro: Label = UiKit.label(tr("NOTE_INTRO"), UiKit.SIZE_SMALL, Palette.SMOKE)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(TEXT_SIZE.x, 0)
	body.add_child(intro)
	var moods: HBoxContainer = row()
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in MOODS.size():
		var b: Button = UiKit.button(tr("NOTE_MOOD_" + MOODS[i].to_upper()), _set_mood.bind(MOODS[i]), Vector2(140, 48))
		b.toggle_mode = true
		b.button_group = group
		b.add_theme_color_override("font_pressed_color", MOOD_COLORS[i])
		b.button_pressed = MOODS[i] == _mood
		moods.add_child(b)
		_mood_buttons.append(b)
	_text = TextEdit.new()
	_text.custom_minimum_size = TEXT_SIZE
	_text.placeholder_text = tr("NOTE_PLACEHOLDER")
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body.add_child(_text)
	_attach = CheckBox.new()
	_attach.text = tr("NOTE_ATTACH_SHOT")
	_attach.button_pressed = _shot != null
	_attach.disabled = _shot == null
	body.add_child(_attach)
	var h: HBoxContainer = row()
	var save: Button = UiKit.button(tr("NOTE_SAVE"), _save)
	h.add_child(save)
	var back: Button = UiKit.button(tr("MENU_BACK"), close)
	h.add_child(back)
	_wire_focus.call_deferred(save, back)
	# Manette : on commence par l'humeur (le texte s'ouvre au clavier virtuel avec A).
	(_mood_buttons[MOODS.find(_mood)] if InputGlyphs.using_pad else _text).call_deferred("grab_focus")
	closed.connect(queue_free)


## Voisins de focus explicites : la recherche géométrique ne relie pas la zone de texte aux humeurs.
func _wire_focus(save: Button, back: Button) -> void:
	for i: int in _mood_buttons.size():
		var b: Button = _mood_buttons[i]
		b.focus_neighbor_left = b.get_path_to(_mood_buttons[posmod(i - 1, _mood_buttons.size())])
		b.focus_neighbor_right = b.get_path_to(_mood_buttons[posmod(i + 1, _mood_buttons.size())])
		b.focus_neighbor_bottom = b.get_path_to(_text)
	_text.focus_neighbor_top = _text.get_path_to(_mood_buttons[0])
	_text.focus_neighbor_bottom = _text.get_path_to(_attach if not _attach.disabled else save)
	_attach.focus_neighbor_top = _attach.get_path_to(_text)
	_attach.focus_neighbor_bottom = _attach.get_path_to(save)
	for b2: Button in [save, back]:
		b2.focus_neighbor_top = b2.get_path_to(_attach if not _attach.disabled else _text)
	save.focus_neighbor_right = save.get_path_to(back)
	back.focus_neighbor_left = back.get_path_to(save)


func _set_mood(mood: String) -> void:
	_mood = mood


func _save() -> void:
	var shot: Image = _shot if _attach.button_pressed else null
	Telemetry.note(GameState.run(), _mood, _text.text.strip_edges(), _screen, shot)
	EventBus.toast.emit(tr("TOAST_NOTE_SAVED"), &"success")
	close()
