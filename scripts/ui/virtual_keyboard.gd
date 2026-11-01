class_name VirtualKeyboard
extends Overlay
## Clavier à l'écran pour la manette (Steam Deck) : ouvert par A sur un champ de texte.
## Croix : choisir une touche · A : taper · B : effacer · Y : espace · Menu (Start) : valider.

signal submitted(text: String)

const ROWS_LATIN: Array[String] = ["1234567890", "AZERTYUIOP", "QSDFGHJKLM", "WXCVBN.,'?", "ÉÈÀÇÙ-!:()"]
const KEY_SIZE: Vector2 = Vector2(64, 60)
const WIDE_KEY: Vector2 = Vector2(200, 60)
const PREVIEW_W: float = 760.0

var target: Control = null
var max_length: int = 0
var uppercase_only: bool = false
var _text: String = ""
var _preview: Label = null
var _shift: bool = false
var _letter_buttons: Array[Button] = []


func configure(p_target: Control) -> VirtualKeyboard:
	target = p_target
	panel_width = 860.0
	cancel_closes = false
	if target is LineEdit:
		_text = (target as LineEdit).text
		max_length = (target as LineEdit).max_length
	elif target is TextEdit:
		_text = (target as TextEdit).text
	return self


func build() -> void:
	heading(tr("OSK_TITLE"))
	_preview = UiKit.label("", UiKit.SIZE_H2, Palette.GOLD_LIGHT, "mono")
	_preview.custom_minimum_size = Vector2(PREVIEW_W, 0)
	_preview.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_preview)
	var first: Button = null
	for r: String in ROWS_LATIN:
		var h: HBoxContainer = row()
		h.add_theme_constant_override("separation", 6)
		for ch: String in r.split(""):
			var b: Button = UiKit.button(ch, _type.bind(ch), KEY_SIZE)
			b.add_theme_font_size_override("font_size", UiKit.SIZE_H2)
			h.add_child(b)
			_letter_buttons.append(b)
			if first == null:
				first = b
	var tools: HBoxContainer = row()
	var specials: Array[Array] = [
		["OSK_SHIFT", _toggle_shift, ""],
		["OSK_SPACE", _type.bind(" "), "bet_repeat"],
		["OSK_BACKSPACE", _backspace, "ui_cancel"],
		["OSK_OK", _submit, "pause_menu"],
	]
	for sp: Array in specials:
		var b2: Button = UiKit.button(tr(String(sp[0])), sp[1] as Callable, WIDE_KEY)
		if String(sp[2]) != "":
			PromptBadge.attach(b2, String(sp[2]))
		tools.add_child(b2)
	_refresh()
	if first != null:
		first.call_deferred("grab_focus")
	closed.connect(queue_free)


func _type(ch: String) -> void:
	if max_length > 0 and _text.length() >= max_length:
		AudioBus.ui("error")
		return
	_text += ch if (_shift or uppercase_only) else ch.to_lower()
	AudioBus.ui("click")
	_refresh()


func _backspace() -> void:
	if _text.is_empty():
		return
	_text = _text.substr(0, _text.length() - 1)
	AudioBus.ui("click")
	_refresh()


func _toggle_shift() -> void:
	_shift = not _shift
	_refresh()


func _refresh() -> void:
	_preview.text = _text + "▏"
	for b: Button in _letter_buttons:
		var t: String = b.text
		b.text = t.to_upper() if (_shift or uppercase_only) else t.to_lower()


func _submit() -> void:
	if target is LineEdit:
		(target as LineEdit).text = _text
		(target as LineEdit).text_changed.emit(_text)
	elif target is TextEdit:
		(target as TextEdit).text = _text
	submitted.emit(_text)
	close()
	if is_instance_valid(target):
		target.grab_focus.call_deferred()


## B efface (le clavier ne se ferme que par Valider ou le bouton Menu).
func go_back() -> void:
	_backspace()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		_submit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("bet_repeat"):
		_type(" ")
		get_viewport().set_input_as_handled()
