class_name PromptBar
extends HBoxContainer
## Barre d'invites « [glyphe] action » pour le périphérique actif. Se reconstruit quand le
## périphérique change ; masque les dernières invites si la place manque (jamais de débordement).

const PAIR_GAP: int = 6
const GROUP_GAP: int = 22

var prompt_height: int = InputGlyphs.PROMPT_H
var font_size: int = UiKit.SIZE_SMALL
var text_color: Color = Palette.IVORY
## Largeur maximale imposée (0 = largeur courante) : la barre ne s'élargit jamais au-delà,
## même quand ses invites la poussent avant d'être masquées.
var max_width: float = 0.0
## Paires [action ou repère, clé de libellé].
var _items: Array[Array] = []
var _sentence: String = ""
var _keys_items: Array[Array] = []
var _pad_items: Array[Array] = []


func _ready() -> void:
	add_theme_constant_override("separation", GROUP_GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	EventBus.input_device_changed.connect(_on_device_changed)
	resized.connect(_fit)
	_rebuild()


## Jeux d'invites distincts pour clavier/souris et manette (seul celui du périphérique actif s'affiche).
func set_device_items(keys_items: Array[Array], pad_items: Array[Array]) -> void:
	_keys_items = keys_items
	_pad_items = pad_items
	set_items(pad_items if InputGlyphs.using_pad else keys_items)


func set_items(items: Array[Array], sentence: String = "") -> void:
	if items == _items and sentence == _sentence:
		return
	_items = items
	_sentence = sentence
	if is_inside_tree():
		_rebuild()


func _on_device_changed(pad: bool) -> void:
	if not _keys_items.is_empty() or not _pad_items.is_empty():
		_items = _pad_items if pad else _keys_items
	_rebuild()


func _rebuild() -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	if _sentence != "":
		var s: Label = UiKit.label(_sentence, font_size, text_color)
		s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(s)
	for pair: Array in _items:
		var p: Control = InputGlyphs.prompt(String(pair[0]), prompt_height)
		if p == null:
			continue
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", PAIR_GAP)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(p)
		var l: Label = UiKit.label(tr(String(pair[1])), font_size, text_color)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		add_child(h)
	_fit.call_deferred()


## Masque les invites de fin tant que la barre dépasse sa largeur.
func _fit() -> void:
	var limit: float = max_width if max_width > 0.0 else size.x
	if limit <= 0.0:
		return
	var used: float = 0.0
	var gap: float = float(get_theme_constant("separation"))
	for c: Node in get_children():
		var ctl: Control = c as Control
		var w: float = ctl.get_combined_minimum_size().x
		ctl.visible = used + w <= limit
		used += w + gap
	if max_width > 0.0 and size.x > max_width:
		set_deferred("size", Vector2(max_width, size.y))
