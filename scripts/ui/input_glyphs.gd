class_name InputGlyphs
extends RefCounted
## Invites de commandes : quel périphérique est actif, et comment montrer une action.
## - Mode (Options → Commandes) : « auto » (dernier périphérique utilisé), « keyboard », « gamepad ».
## - Manette : glyphes pixel art Xbox 360 (assets/glyphs/, tools/gen_glyphs.py).
## - Clavier : touche en relief portant le nom localisé de la touche assignée (remappage compris).
## Seules les invites du périphérique actif sont affichées.

const GLYPH_DIR: String = "res://assets/glyphs/"
const SEP: String = "  ·  "
const PAIR_FALLBACK: String = "%s: %s"
const STICK_DEADZONE: float = 0.5
const MOUSE_MOVE_THRESHOLD: float = 2.0
const MODES: Array[String] = ["auto", "keyboard", "gamepad"]
## Hauteur par défaut d'une invite (pixels logiques).
const PROMPT_H: int = 30
const KEYCAP_PAD: int = 6
const KEYCAP_BORDER: int = 2
const KEYCAP_DEPTH: int = 4

const PAD_BUTTON_GLYPH: Dictionary[int, String] = {
	JOY_BUTTON_A: "pad_a",
	JOY_BUTTON_B: "pad_b",
	JOY_BUTTON_X: "pad_x",
	JOY_BUTTON_Y: "pad_y",
	JOY_BUTTON_BACK: "pad_back",
	JOY_BUTTON_GUIDE: "pad_guide",
	JOY_BUTTON_START: "pad_start",
	JOY_BUTTON_LEFT_STICK: "pad_l3",
	JOY_BUTTON_RIGHT_STICK: "pad_r3",
	JOY_BUTTON_LEFT_SHOULDER: "pad_lb",
	JOY_BUTTON_RIGHT_SHOULDER: "pad_rb",
	JOY_BUTTON_DPAD_UP: "pad_dpad_up",
	JOY_BUTTON_DPAD_DOWN: "pad_dpad_down",
	JOY_BUTTON_DPAD_LEFT: "pad_dpad_left",
	JOY_BUTTON_DPAD_RIGHT: "pad_dpad_right",
}
const PAD_AXIS_GLYPH: Dictionary[int, String] = {
	JOY_AXIS_TRIGGER_LEFT: "pad_lt",
	JOY_AXIS_TRIGGER_RIGHT: "pad_rt",
	JOY_AXIS_LEFT_X: "pad_ls",
	JOY_AXIS_LEFT_Y: "pad_ls",
	JOY_AXIS_RIGHT_X: "pad_rs",
	JOY_AXIS_RIGHT_Y: "pad_rs",
}
## Repères qui ne sont pas des actions : souris côté clavier, croix/sticks côté manette.
## Touches nommées dans les repères (« #KEY_SHIFT »).
const NAMED_KEYS: Dictionary[String, Key] = {
	"KEY_SHIFT": KEY_SHIFT, "KEY_UP": KEY_UP, "KEY_LEFT": KEY_LEFT, "KEY_RIGHT": KEY_RIGHT, "KEY_DOWN": KEY_DOWN
}
const MARKERS_KEYS: Dictionary[String, Array] = {
	"@click": ["mouse_left"],
	"@shift_click": ["#KEY_SHIFT", "mouse_left"],
	"@right_click": ["mouse_right"],
	"@double_click": ["mouse_left", "mouse_left"],
	"@drag": ["mouse_left"],
	"@wheel": ["mouse_wheel"],
	"@arrows": ["#KEY_UP"],
	"@mouse": ["mouse"],
	"@qte": ["#KEY_LEFT", "#KEY_UP", "#KEY_RIGHT", "#KEY_DOWN"],
	"@qte_mouse": ["mouse_left", "mouse_right"],
}
const MARKERS_PAD: Dictionary[String, Array] = {
	"@dpad": ["pad_dpad"],
	"@dpad_lr": ["pad_dpad_lr"],
	"@rstick": ["pad_rs"],
	"@lstick": ["pad_ls"],
	"@qte": ["pad_x", "pad_y", "pad_b", "pad_a"],
}

static var using_pad: bool = false
static var _auto_checked: bool = false
static var _tex_cache: Dictionary[String, Texture2D] = {}
static var _keycap_style: StyleBoxFlat = null


# --------------------------------------------------------------------------- mode


static func mode() -> String:
	var m: String = String(Settings.get_value("game", "input_mode"))
	return m if m in MODES else "auto"


## Applique le mode réglé (au démarrage et quand les options changent) ; vrai si l'affichage change.
static func apply_mode() -> bool:
	var m: String = mode()
	var want: bool = using_pad
	if m == "keyboard":
		want = false
	elif m == "gamepad":
		want = true
	elif _first_auto():
		want = _pad_connected() and _handheld()
	return _set_pad(want)


## Note le périphérique d'un événement (mode automatique seulement) ; vrai si l'affichage change.
static func note_event(event: InputEvent) -> bool:
	if mode() != "auto":
		return false
	var pad: bool = using_pad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > STICK_DEADZONE:
			pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > MOUSE_MOVE_THRESHOLD:
		pad = false
	return _set_pad(pad)


static func _set_pad(pad: bool) -> bool:
	if pad == using_pad:
		return false
	using_pad = pad
	return true



static func _first_auto() -> bool:
	if _auto_checked:
		return false
	_auto_checked = true
	return true


static func _pad_connected() -> bool:
	return not Input.get_connected_joypads().is_empty()


static func _handheld() -> bool:
	return OS.get_environment("SteamDeck") == "1" or OS.has_feature("steamdeck")


# --------------------------------------------------------------------------- correspondances


## Éléments visuels d'une action pour le périphérique actif : noms de glyphes (« pad_a »,
## « mouse_left ») ou « #<Touche> » pour une touche de clavier. Vide si non assignée.
static func parts_for(action: String) -> Array[String]:
	var out: Array[String] = []
	# « a+b » : les deux commandes à la suite (ex. LB RB pour −/+).
	if action.contains("+"):
		for part: String in action.split("+"):
			out.append_array(parts_for(part))
		return out
	if action.begins_with("@"):
		var table: Dictionary[String, Array] = MARKERS_PAD if using_pad else MARKERS_KEYS
		for p: Variant in table.get(action, []):
			out.append(String(p))
		return out
	if not InputMap.has_action(action):
		return out
	for e: InputEvent in InputMap.action_get_events(action):
		if using_pad and e is InputEventJoypadButton:
			var g: String = PAD_BUTTON_GLYPH.get((e as InputEventJoypadButton).button_index, "")
			if g != "":
				out.append(g)
				return out
		elif using_pad and e is InputEventJoypadMotion:
			var ga: String = PAD_AXIS_GLYPH.get((e as InputEventJoypadMotion).axis, "")
			if ga != "":
				out.append(ga)
				return out
		elif not using_pad and e is InputEventKey:
			out.append("#" + key_label(e as InputEventKey))
			return out
	return out


static func key_label(k: InputEventKey) -> String:
	var code: Key = k.keycode
	if k.physical_keycode != KEY_NONE:
		code = k.physical_keycode
		if DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_label_from_physical(k.physical_keycode)
	return key_name(code)


## Nom lisible et traduit d'une touche.
static func key_name(code: Key) -> String:
	var raw: String = OS.get_keycode_string(code)
	var key: String = "KEYNAME_" + raw.to_upper().replace(" ", "_")
	var t: String = TranslationServer.translate(key)
	return raw if t == key else t


static func texture(glyph: String) -> Texture2D:
	if _tex_cache.has(glyph):
		return _tex_cache[glyph]
	var path: String = GLYPH_DIR + glyph + ".png"
	var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_tex_cache[glyph] = t
	return t


static func clear_cache() -> void:
	_tex_cache.clear()
	_keycap_style = null


# --------------------------------------------------------------------------- rendu


## Invite d'une action (glyphe(s) ou touche(s) en relief). Null si rien n'est assigné.
static func prompt(action: String, height: int = PROMPT_H) -> Control:
	var parts: Array[String] = parts_for(action)
	if parts.is_empty():
		return null
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p: String in parts:
		box.add_child(_part(p, height))
	return box


static func _part(p: String, height: int) -> Control:
	if p.begins_with("#"):
		var label: String = p.substr(1)
		if label.begins_with("KEY_"):
			label = key_name(NAMED_KEYS.get(label, KEY_NONE))
		return keycap(label, height)
	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.texture = texture(p)
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var aspect: float = 1.0
	if tex_rect.texture != null:
		aspect = float(tex_rect.texture.get_width()) / float(tex_rect.texture.get_height())
	tex_rect.custom_minimum_size = Vector2(roundf(float(height) * aspect), height)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex_rect


## Touche de clavier en relief (style pixel : bord clair, socle sombre plus épais en bas).
static func keycap(label: String, height: int = PROMPT_H) -> Control:
	var pc: PanelContainer = PanelContainer.new()
	if _keycap_style == null:
		_keycap_style = StyleBoxFlat.new()
		_keycap_style.bg_color = Palette.SMOKE_DARK
		_keycap_style.border_color = Palette.IVORY.darkened(0.25)
		_keycap_style.set_border_width_all(KEYCAP_BORDER)
		_keycap_style.border_width_bottom = KEYCAP_DEPTH
		_keycap_style.set_corner_radius_all(3)
		_keycap_style.content_margin_left = KEYCAP_PAD
		_keycap_style.content_margin_right = KEYCAP_PAD
		_keycap_style.content_margin_top = 0
		_keycap_style.content_margin_bottom = 0
	pc.add_theme_stylebox_override("panel", _keycap_style)
	pc.custom_minimum_size = Vector2(height, height)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = UiKit.label(label, int(float(height) * 0.55), Palette.IVORY, "mono")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(l)
	return pc


## Version BBCode (RichTextLabel) d'une invite, pour les textes (tutoriel, astuces).
static func bbcode(action: String, height: int = 26) -> String:
	var out: String = ""
	for p: String in parts_for(action):
		if p.begins_with("#"):
			var label: String = p.substr(1)
			if label.begins_with("KEY_"):
				label = key_name(NAMED_KEYS.get(label, KEY_NONE))
			out += "[bgcolor=#2b2631][color=#f2d27a][font_size=%d] %s [/font_size][/color][/bgcolor]" % [int(height * 0.7), label]
		else:
			var t: Texture2D = texture(p)
			if t != null:
				var w: int = roundi(float(height) * float(t.get_width()) / float(t.get_height()))
				out += "[img=%dx%d]%s[/img]" % [w, height, t.resource_path]
	return out


## Remplace les jetons {action} d'un texte par leurs invites BBCode.
static func expand(text: String, height: int = 26) -> String:
	var re: RegEx = RegEx.create_from_string("\\{(@?[a-z_0-9]+)\\}")
	var out: String = text
	for m: RegExMatch in re.search_all(text):
		out = out.replace(m.get_string(), bbcode(m.get_string(1), height))
	return out


## Texte simple d'une invite (journaux, tests, infobulles).
static func plain(action: String) -> String:
	var names: Array[String] = []
	for p: String in parts_for(action):
		names.append(p.substr(1) if p.begins_with("#") else p.replace("pad_", "").to_upper())
	return "+".join(names)
