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
	h.add_child(UiKit.button(tr("MENU_BACK"), close))
	_text.call_deferred("grab_focus")
	closed.connect(queue_free)


func _set_mood(mood: String) -> void:
	_mood = mood


func _save() -> void:
	var shot: Image = _shot if _attach.button_pressed else null
	Telemetry.note(GameState.run(), _mood, _text.text.strip_edges(), _screen, shot)
	EventBus.toast.emit(tr("TOAST_NOTE_SAVED"), &"success")
	close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
