class_name SplashScreen
extends Control
## Écran d'ouverture « Conçu avec Godot, Blender et Claude Code » : les trois logos apparaissent
## l'un après l'autre, puis l'écran s'efface. Une touche, un bouton de manette ou un clic le passe.

signal finished

const LOGO_DIR: String = "res://assets/splash/"
## Durée totale avant le fondu de sortie (secondes), apparition décalée de chaque logo.
const HOLD: float = 3.6
const STAGGER: float = 0.28
const FADE_IN: float = 0.45
const FADE_OUT: float = 0.4
## Délai avant d'accepter le passage (évite qu'une touche du lancement le saute aussitôt).
const SKIP_GRACE: float = 0.2
const LOGO_H: float = 220.0
const CLAUDE_H: float = 150.0
const SEP: int = 110

var _t: float = 0.0
var _done: bool = false
var _logos: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	add_child(UiKit.background(Palette.INK))
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 70)
	add_child(v)
	var made: Label = UiKit.label(tr("SPLASH_MADE_WITH"), UiKit.SIZE_H2, Palette.GOLD_LIGHT, "display")
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(made)
	_logos.append(made)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", SEP)
	v.add_child(row)
	_logos.append(_logo(row, "godot", Vector2(LOGO_H * 0.86, LOGO_H)))
	_logos.append(_logo(row, "blender", Vector2(LOGO_H * 2.0, LOGO_H)))
	var claude: VBoxContainer = VBoxContainer.new()
	claude.alignment = BoxContainer.ALIGNMENT_CENTER
	claude.add_theme_constant_override("separation", 14)
	_logo(claude, "claude", Vector2(CLAUDE_H, CLAUDE_H))
	var cl: Label = UiKit.label("Claude Code", UiKit.SIZE_H2, Color("d97757"), "display")
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	claude.add_child(cl)
	row.add_child(claude)
	_logos.append(claude)
	var hint: Label = UiKit.label(tr("SPLASH_SKIP"), UiKit.SIZE_SMALL, Palette.SMOKE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	for c: Control in _logos:
		c.modulate.a = 0.0


func _logo(parent: Container, id: String, sz: Vector2) -> Control:
	var r: TextureRect = TextureRect.new()
	r.texture = load(LOGO_DIR + id + ".png") as Texture2D
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = sz
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _process(delta: float) -> void:
	_t += delta
	for i: int in _logos.size():
		_logos[i].modulate.a = clampf((_t - STAGGER * i) / FADE_IN, 0.0, 1.0)
	if _t >= HOLD:
		skip()


func _input(event: InputEvent) -> void:
	if _done or _t < SKIP_GRACE or event.is_echo():
		return
	var press: bool = (
		(event is InputEventKey and event.is_pressed())
		or (event is InputEventJoypadButton and event.is_pressed())
		or (event is InputEventMouseButton and event.is_pressed())
	)
	if press:
		get_viewport().set_input_as_handled()
		skip()


func skip() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(
		func() -> void:
			finished.emit()
			queue_free()
	)
