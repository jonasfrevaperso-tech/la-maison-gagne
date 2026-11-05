class_name IntroCutscene
extends Control
## Cinématique d'intro (v1.5) : plans pixel art en calques (parallaxe, travelling, néon qui
## grésille, pluie, poussière, tampon qui s'abat, portes qui s'ouvrent), sous-titres tapés à la
## machine avec la voix (blips) de chaque personnage, bruitages et musique dédiée.
## Contenu : data/cutscenes/cutscenes.json (une entrée par plan). Illustrations :
## assets/cutscene/ (tools/gen_cutscene.py). Un appui court accélère le texte ; MAINTENIR
## n'importe quelle touche (ou bouton) SKIP_HOLD secondes passe la cinématique.

const ART_SIZE: Vector2 = Vector2(320, 180)
const ART_DIR: String = "res://assets/cutscene/%s.png"
const CHARS_PER_SEC: float = 34.0
const HOLD_BASE: float = 1.7
const HOLD_PER_CHAR: float = 0.028
const FADE: float = 0.7
const SKIP_HOLD: float = 3.0
const SKIP_MARGIN: float = 70.0
const TAP_MAX: float = 0.35
const RAIN_DROPS: int = 240
const DUST_MOTES: int = 70
const TITLE_HOLD: float = 3.2
const CAPTION_MARGIN: float = 60.0

var cutscene_id: String = "intro"
var next_screen: StringName = &"title"
## Paramètres transmis à l'écran suivant (défaite → bilan), acte atteint et créancier vainqueur.
var next_params: Dictionary = {}
var act: int = 1
var creditor: String = ""
var _shots: Array[Dictionary] = []
var _shot: int = -1
var _caption: int = -1
var _typed: float = 0.0
var _hold: float = 0.0
var _shot_t: float = 0.0
var _cap_t: float = 0.0
var _fade: float = 1.0
var _fading_out: bool = false
var _done: bool = false
var _title_t: float = -1.0
var _press_t: float = -1.0
var _skip_t: float = 0.0
var _flash: float = 0.0
var _shake: float = 0.0
var _anim_start: Dictionary = {}
var _flicker: float = 1.0
var _flicker_t: float = 0.0
var _rain: PackedVector3Array = PackedVector3Array()
var _dust: PackedVector3Array = PackedVector3Array()
var _textures: Dictionary[String, Texture2D] = {}
var _letter_lines: Array[String] = []
var _last_blip: int = 0
var _box: PanelContainer = null
var _name: Label = null
var _text: Label = null
var _letter: Label = null
var _skip_label: Label = null


func setup(params: Dictionary) -> void:
	next_screen = StringName(String(params.get("next", "title")))
	cutscene_id = String(params.get("cutscene", "intro"))
	next_params = params.get("next_params", {}) as Dictionary
	act = int(params.get("act", 1))
	creditor = String(params.get("creditor", ""))


## Variantes par acte (`by_act`, clés "1".."3") et marqueur {creditor} dans les répliques.
static func vary(lines: Array, p_act: int, creditor_name: String) -> Array:
	var out: Array = []
	for ln: Variant in lines:
		var line: Dictionary = (ln as Dictionary).duplicate()
		var by: Dictionary = line.get("by_act", {})
		if by.has(str(p_act)):
			line.merge(by[str(p_act)] as Dictionary, true)
		for k: String in ["text_fr", "text_en"]:
			if line.has(k):
				line[k] = String(line[k]).replace("{creditor}", creditor_name)
		out.append(line)
	return out


## Nom du créancier vainqueur, ou « la Maison » s'il n'y en avait pas à ce moment-là.
func _creditor_name() -> String:
	var e: Dictionary = DataRegistry.db.get_entry("creditors", creditor) if creditor != "" else {}
	return Localization.t(e, "name") if not e.is_empty() else tr("DEFEAT_THE_HOUSE")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = UiKit.theme()
	for e: Dictionary in DataRegistry.db.list("cutscenes"):
		if String(e.get("cutscene", "")) == cutscene_id:
			_shots.append(e)
	var hero: String = GameState.run().character_id if GameState.run() != null else ""
	for i: int in _shots.size():
		var shot: Dictionary = _shots[i].duplicate()
		var lines: Array = DialogueOverlay.personalize(shot.get("captions", []) as Array, hero)
		shot["captions"] = vary(lines, act, _creditor_name())
		_shots[i] = shot
	_shots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	var rng: RandomNumberGenerator = RngService.cosmetic()
	for i: int in RAIN_DROPS:
		_rain.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.4)))
	for i: int in DUST_MOTES:
		_dust.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.3, 1.0)))
	_build_ui()
	AudioBus.play_music(String(_shots[0].get("music", "intro")) if not _shots.is_empty() else "intro")
	_next_shot()


func _build_ui() -> void:
	_box = UiKit.panel(Color(Palette.INK, 0.82), Palette.GOLD_DARK)
	_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_left = CAPTION_MARGIN
	_box.offset_right = -CAPTION_MARGIN
	_box.offset_bottom = -CAPTION_MARGIN * 0.6
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var v: VBoxContainer = VBoxContainer.new()
	_box.add_child(v)
	_name = UiKit.label("", UiKit.SIZE_BODY, Palette.GOLD_LIGHT, "display")
	v.add_child(_name)
	_text = UiKit.label("", UiKit.SIZE_H2 - 6, Palette.IVORY)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 80)
	v.add_child(_text)
	_letter = UiKit.label("", UiKit.SIZE_H2 - 4, Color(0.22, 0.13, 0.08))
	_letter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_letter.add_theme_font_override("font", UiKit.font("body"))
	_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_letter)
	var skip_key: String = "CUTSCENE_HOLD_SKIP_TOUCH" if InputGlyphs.using_touch else "CUTSCENE_HOLD_SKIP"
	_skip_label = UiKit.label(tr(skip_key), UiKit.SIZE_SMALL, Palette.SMOKE)
	_skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skip_label)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var art: Rect2 = _art_rect(1.0, Vector2.ZERO)
	# Le texte de la lettre s'écrit sur la feuille (zone utile du dessin de la lettre).
	_letter.position = art.position + Vector2(0.21, 0.17) * art.size
	_letter.size = Vector2(0.6, 0.7) * art.size
	# Largeur du texte (la consigne tactile est plus longue), calée à droite, dans la zone sûre.
	var w: float = _skip_label.get_combined_minimum_size().x
	var right: float = Platform.safe_rect(get_viewport()).end.x - global_position.x if Platform.is_mobile() else size.x
	_skip_label.size = Vector2(w, 30.0)
	_skip_label.position = Vector2(minf(size.x, right) - w - SKIP_MARGIN, 26.0)
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _tex(name: String) -> Texture2D:
	if not _textures.has(name):
		var path: String = ART_DIR % name
		_textures[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[name]


# --------------------------------------------------------------------------- déroulé


func _next_shot() -> void:
	_shot += 1
	if _shot >= _shots.size():
		_finish()
		return
	var s: Dictionary = _shots[_shot]
	_shot_t = 0.0
	_caption = -1
	_anim_start.clear()
	_letter_lines.clear()
	_letter.text = ""
	_fade = 1.0
	_fading_out = false
	if s.has("ambience"):
		var amb: String = String(s["ambience"])
		if amb == "":
			AudioBus.stop_ambience()
		else:
			AudioBus.play_ambience(amb, float(s.get("ambience_db", Balance.f("audio.cutscene_ambience_db"))))
	_next_caption()


func _shot_data() -> Dictionary:
	return _shots[clampi(_shot, 0, _shots.size() - 1)] if not _shots.is_empty() else {}


func _captions() -> Array:
	return _shot_data().get("captions", []) as Array


func _next_caption() -> void:
	_caption += 1
	if _caption >= _captions().size():
		if (_shot_data().get("fx", []) as Array).has("title") and _title_t < 0.0:
			_title_t = 0.0
			AudioBus.play("jackpot", 0.7, -6.0)
			_box.visible = false
			return
		_fading_out = true
		return
	var c: Dictionary = _captions()[_caption]
	_typed = 0.0
	_cap_t = 0.0
	_last_blip = 0
	var txt: String = Localization.t(c, "text")
	_hold = HOLD_BASE + HOLD_PER_CHAR * float(txt.length())
	var letter: bool = bool(c.get("letter", false))
	_box.visible = not letter
	if letter:
		_letter_lines.append(txt)
	else:
		var spk: Dictionary = _speaker(String(c.get("who", "narrator")))
		_name.text = Localization.t(spk, "name")
		_name.add_theme_color_override("font_color", Color.html(String(spk.get("color", "f2d27a"))))
		_text.text = txt
		_text.visible_characters = 0
	# Bruitages et animations accrochés à cette réplique.
	for fx: Variant in _shot_data().get("sfx", []):
		var d: Dictionary = fx as Dictionary
		if int(d.get("at", 0)) == _caption:
			AudioBus.play(String(d["id"]), float(d.get("pitch", 1.0)))
			if bool(d.get("flash", false)):
				_flash = 1.0
			if bool(d.get("shake", false)):
				_shake = 1.0
	for lay: Variant in _shot_data().get("layers", []):
		var l: Dictionary = lay as Dictionary
		if l.has("at") and int(l["at"]) == _caption:
			_anim_start[String(l["img"])] = _shot_t


func _speaker(who: String) -> Dictionary:
	if who == "hero":
		var run: RunState = GameState.run()
		if run == null:  # Prologue revu depuis le titre : « toi », sans personnage.
			return {"name_fr": "Toi", "name_en": "You", "blip": "blip_npc", "color": "f2d27a"}
		var ch: Dictionary = DataRegistry.db.get_entry("characters", run.character_id)
		return {"name_fr": ch.get("name_fr", ""), "name_en": ch.get("name_en", ""), "blip": ch.get("blip", "blip_lea"), "color": "f2d27a"}
	if who == "narrator":
		return {"name_fr": "", "name_en": "", "blip": "blip_npc", "color": "f5f0e6"}
	return DataRegistry.db.get_entry("speakers", who)


func _current_text() -> String:
	if _caption < 0 or _caption >= _captions().size():
		return ""
	return Localization.t(_captions()[_caption] as Dictionary, "text")


## Appui court : finit la réplique en cours, ou passe à la suivante.
func advance() -> void:
	if _title_t >= 0.0:
		_finish()
		return
	if _fading_out:
		return
	if _typed < float(_current_text().length()):
		_typed = float(_current_text().length())
	else:
		_next_caption()


func _finish() -> void:
	if _done:
		return
	_done = true
	SaveSystem.max_stat("%s_seen" % cutscene_id, 1)
	SaveSystem.save_profile()
	AudioBus.stop_ambience()
	GameState.goto(next_screen, next_params)


func _process(delta: float) -> void:
	if _done:
		return
	_shot_t += delta
	_flash = maxf(_flash - delta * 2.5, 0.0)
	_shake = maxf(_shake - delta * 2.0, 0.0)
	_flicker_t -= delta
	if _flicker_t <= 0.0:
		var rng: RandomNumberGenerator = RngService.cosmetic()
		_flicker = 1.0 if rng.randf() < 0.8 else rng.randf_range(0.1, 0.6)
		_flicker_t = rng.randf_range(0.05, 0.4)
		var neon: bool = (_shot_data().get("layers", []) as Array).any(_is_flicker)
		if _flicker < 0.7 and neon:
			AudioBus.play("decor_neon", 1.0, -16.0)
	_update_skip(delta)
	if _title_t >= 0.0:
		_title_t += delta
		if _title_t > TITLE_HOLD:
			_finish()
	elif _fading_out:
		_fade = maxf(_fade - delta / FADE, 0.0)
		if _fade <= 0.0:
			_next_shot()
	else:
		_fade = minf(_fade + delta / FADE, 1.0) if _shot_t < FADE else 1.0
		_type(delta)
	queue_redraw()


func _is_flicker(l: Variant) -> bool:
	return String((l as Dictionary).get("anim", "")) == "flicker"


func _type(delta: float) -> void:
	var txt: String = _current_text()
	if _typed < float(txt.length()):
		_typed = minf(_typed + delta * CHARS_PER_SEC, float(txt.length()))
		var n: int = int(_typed)
		if n - _last_blip >= 2 and n < txt.length() and txt[n] != " ":
			_last_blip = n
			var spk: Dictionary = _speaker(String((_captions()[_caption] as Dictionary).get("who", "narrator")))
			AudioBus.play(String(spk.get("blip", "blip_npc")), 1.0, -10.0)
	else:
		_cap_t += delta
		if _cap_t >= _hold:
			_next_caption()
	var c: Dictionary = _captions()[_caption] if _caption < _captions().size() else {}
	if bool(c.get("letter", false)):
		var done_lines: Array[String] = _letter_lines.slice(0, _letter_lines.size() - 1)
		done_lines.append(txt.substr(0, int(_typed)))
		_letter.text = "\n\n".join(done_lines)
	else:
		_text.visible_characters = int(_typed)


# --------------------------------------------------------------------------- passer


func _update_skip(delta: float) -> void:
	var held: bool = Input.is_anything_pressed() or _axis_held() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if held:
		_skip_t += delta
		if _skip_t >= SKIP_HOLD:
			AudioBus.play("whoosh", 0.8)
			_finish()
	else:
		_skip_t = maxf(_skip_t - delta * 3.0, 0.0)
	_skip_label.modulate.a = 0.55 + 0.45 * clampf(_skip_t / SKIP_HOLD, 0.0, 1.0)


func _axis_held() -> bool:
	return Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5 or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5


func _input(event: InputEvent) -> void:
	var button: bool = event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton
	var pressed: bool = button and event.is_pressed()
	var released: bool = button and event.is_released()
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if pressed:
		_press_t = Time.get_ticks_msec() / 1000.0
	elif released and _press_t >= 0.0:
		if Time.get_ticks_msec() / 1000.0 - _press_t <= TAP_MAX:
			advance()
		_press_t = -1.0
	if pressed or released:
		get_viewport().set_input_as_handled()


## Écran manette sans focus (comme l'écran de jeu) : tout passe par _input.
func go_back() -> void:
	pass


# --------------------------------------------------------------------------- dessin


## Rectangle de l'image (320×180 agrandie pour couvrir l'écran), zoom et décalage de caméra.
func _art_rect(zoom: float, offset: Vector2) -> Rect2:
	var sc: float = maxf(size.x / ART_SIZE.x, size.y / ART_SIZE.y) * zoom
	var sz: Vector2 = ART_SIZE * sc
	return Rect2(size * 0.5 - sz * 0.5 + offset, sz)


func _camera() -> Vector3:
	var cam: Dictionary = _shot_data().get("camera", {})
	var a: Array = cam.get("from", [0, 0, 1])
	var b: Array = cam.get("to", [0, 0, 1])
	var total: float = 0.0
	for c: Variant in _captions():
		var n: float = float(Localization.t(c as Dictionary, "text").length())
		total += HOLD_BASE + n * (1.0 / CHARS_PER_SEC + HOLD_PER_CHAR)
	var u: float = clampf(_shot_t / maxf(total, 1.0), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	return Vector3(lerpf(float(a[0]), float(b[0]), u), lerpf(float(a[1]), float(b[1]), u), lerpf(float(a[2]), float(b[2]), u))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _shots.is_empty():
		return
	var cam: Vector3 = _camera()
	var shake: Vector2 = Vector2(sin(_shot_t * 70.0), cos(_shot_t * 53.0)) * 14.0 * _shake * JuiceProfile.intensity()
	var fx: Array = _shot_data().get("fx", [])
	for lay: Variant in _shot_data().get("layers", []):
		_draw_layer(lay as Dictionary, cam, shake)
	if fx.has("rain"):
		_draw_rain()
	if fx.has("dust"):
		_draw_dust()
	if fx.has("vignette") or fx.has("rain") or fx.has("dust"):
		_draw_vignette()
	if _title_t >= 0.0:
		_draw_title()
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _flash * 0.7))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1.0 - _fade))
	_draw_skip_ring()


func _draw_layer(l: Dictionary, cam: Vector3, shake: Vector2) -> void:
	var name: String = String(l.get("img", ""))
	var tex: Texture2D = _tex(name)
	if tex == null:
		return
	var depth: float = float(l.get("depth", 0.5))
	var zoom: float = 1.0 + (cam.z - 1.0) * (0.4 + 0.6 * depth)
	var off: Vector2 = Vector2(cam.x, cam.y) * size * depth + shake * depth
	var alpha: float = 1.0
	var px: float = maxf(size.x / ART_SIZE.x, size.y / ART_SIZE.y) * zoom
	match String(l.get("anim", "")):
		"flicker":
			alpha = _flicker
		"pulse":
			alpha = 0.75 + 0.25 * sin(_shot_t * 2.2)
		"rise":
			off.y += 40.0 * px * (1.0 - clampf(_shot_t / 1.4, 0.0, 1.0))
		"slam":
			if not _anim_start.has(name):
				return
			var u: float = clampf((_shot_t - float(_anim_start[name])) / 0.16, 0.0, 1.0)
			zoom *= lerpf(2.4, 1.0, u)
			alpha = u
		"slide_left", "slide_right":
			if _anim_start.has(name):
				var v: float = clampf((_shot_t - float(_anim_start[name])) / 2.6, 0.0, 1.0)
				v = 1.0 - pow(1.0 - v, 3.0)
				off.x += (-1.0 if String(l["anim"]) == "slide_left" else 1.0) * 104.0 * px * v
	var r: Rect2 = _art_rect(zoom, off)
	draw_texture_rect(tex, r, false, Color(1, 1, 1, alpha))
	if (_shot_data().get("fx", []) as Array).has("sepia"):
		draw_rect(r, Color(0.35, 0.2, 0.05, 0.12))


func _draw_rain() -> void:
	var col: Color = Color(0.7, 0.75, 0.95, 0.35)
	for d: Vector3 in _rain:
		var y: float = fposmod(d.y + _shot_t * 1.6 * d.z, 1.0) * (size.y + 80.0) - 40.0
		var x: float = fposmod(d.x - _shot_t * 0.08 * d.z, 1.0) * size.x
		var len: float = 26.0 * d.z
		draw_line(Vector2(x, y), Vector2(x - len * 0.25, y + len), col, 2.0)


func _draw_dust() -> void:
	for d: Vector3 in _dust:
		var x: float = fposmod(d.x + sin(_shot_t * 0.3 + d.y * 9.0) * 0.02 + _shot_t * 0.006, 1.0) * size.x
		var y: float = fposmod(d.y - _shot_t * 0.012 * d.z, 1.0) * size.y
		draw_rect(Rect2(x, y, 3.0 * d.z + 1.0, 3.0 * d.z + 1.0), Color(1.0, 0.9, 0.7, 0.18 * d.z))


func _draw_vignette() -> void:
	for i: int in 10:
		var a: float = 0.06
		var g: float = float(i) * size.y * 0.018
		draw_rect(Rect2(0, 0, size.x, g), Color(0, 0, 0, a))
		draw_rect(Rect2(0, size.y - g, size.x, g), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 0, g, size.y), Color(0, 0, 0, a))
		draw_rect(Rect2(size.x - g, 0, g, size.y), Color(0, 0, 0, a))


func _draw_title() -> void:
	var u: float = clampf(_title_t / 1.2, 0.0, 1.0)
	var f: Font = UiKit.font("display")
	var fs: int = int(UiKit.fs(UiKit.SIZE_H1) * (1.6 + 0.2 * (1.0 - u)))
	var txt: String = tr("GAME_TITLE").to_upper()
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos: Vector2 = Vector2(size.x * 0.5 - w * 0.5, size.y * 0.5 + fs * 0.35)
	draw_rect(Rect2(0, size.y * 0.5 - fs, size.x, fs * 2.0), Color(0, 0, 0, 0.6 * u))
	draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(Palette.INK, u))
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Palette.GOLD_LIGHT, u))


func _draw_skip_ring() -> void:
	if _skip_t <= 0.0:
		return
	var c: Vector2 = Vector2(_skip_label.position.x + _skip_label.size.x + SKIP_MARGIN - 30.0, 40.0)
	draw_arc(c, 16.0, 0, TAU, 32, Color(Palette.SMOKE, 0.5), 3.0, true)
	draw_arc(c, 16.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(_skip_t / SKIP_HOLD, 0.0, 1.0), 32, Palette.GOLD_LIGHT, 4.0, true)
