class_name ThrowTrial
extends Control
## Épreuve du lancer (v1.5) : un petit jeu d'adresse noté de 0 à 1. Chaque lancer en tire deux
## au hasard (pool de data/throw/throw_trials.json), puis le Lâcher final (anneau) conclut.
## Une épreuve « panel » se joue dans un cadre sous la roue ; une épreuve « full » a son propre
## écran (décor dessiné). Les réglages viennent de balance.json → throw_trials.<id>.
## Temps réel : la vitesse de jeu (x2) ne fausse jamais le geste.
##
## Protocole des bots (parcours automatiques, campagne manette) : `bot_wants()` décrit le geste
## idéal du moment ({"do": "confirm"|"hold"|"release"|"sym"|"dir"|"axis"|"", ...}) et
## `bot_apply()` l'exécute directement.

signal done(score: float)
## Démonstration du tuto : le joueur appuie pour passer à l'essai.
signal skip_requested

const GRADE_COLORS: Array[Color] = [Palette.GOLD_LIGHT, Palette.EMERALD, Palette.CYAN, Palette.MAGENTA]
const CONFIRM_ACTIONS: Array[StringName] = [&"ui_spin", &"bet_place", &"ui_accept"]
const QTE_ACTIONS: Array[StringName] = [&"qte_left", &"qte_up", &"qte_right", &"qte_down"]
const POP_TIME: float = 0.8
## Hauteur réservée en bas du cadre à l'aide aux commandes.
const HINT_H: float = 40.0
const STICK_DEAD: float = 0.25
const HAPTIC_PERFECT_MS: int = 40

var entry: Dictionary = {}
var assist: bool = false
var precision: int = 1
var mouse: bool = false
## Ralenti d'assistance (> 1 : plus lent).
var slow: float = 1.0
## Élargissement des cibles (assistance, difficulté du Musée), lu par widen().
var widen_k: float = 1.0
var t: float = 0.0
var finished: bool = false
var score: float = 0.0
var flash: float = 0.0
var hold: Callable = Callable()
var rng: RandomNumberGenerator = null
## Bandeau des étapes du lancer (« 1 · Bouteilles  2 · Effet  3 · Lâcher ») et étape courante.
var steps: Array[String] = []
var step: int = 0
## Scène 3D facultative (objets de l'épreuve), dessinée DERRIÈRE les textes et repères 2D.
var stage: Stage3D = null
## Téléphone : débord horizontal du décor 3D de chaque côté (épreuve plein écran sur 20:9).
var bleed_x: float = 0.0
## Commandes tactiles à l'écran (pavé, joystick) : un toucher ailleurs ne vaut pas « valider ».
var touch_controls: bool = false
## Tuto de première rencontre (1.9) : "" (épreuve réelle), "demo" (le bot joue sous le carton
## des étapes) ou "essai" (le joueur s'essaie, la note ne compte pas).
var rehearsal: String = ""
var tuto_lines: Array[String] = []
## Part du temps de démo / d'essai écoulée (0..1), dessinée en jauge.
var rehearsal_u: float = 0.0
## Carton d'annonce (nom, règle, commandes) avant que l'épreuve ne commence.
var intro_left: float = 0.0
var _intro_total: float = 1.0
var _begun: bool = false
## « Prêt ? » : la scène est montée mais rien ne bouge encore (le temps de regarder, D-072).
var _ready_left: float = 0.0
var _verdict: int = -1
var _pops: Array[Dictionary] = []
var _hint: RichTextLabel = null
## Illustration pixel art du carton d'annonce (gardée en membre : une texture chargée dans
## _draw et relâchée aussitôt s'afficherait blanche).
var _art: Texture2D = null
## Commandes en grand sur le carton (périphérique actif), placées sous la règle.
var _keys_label: RichTextLabel = null
var _keys_label_rect: Rect2 = Rect2()
## Tuto : carton sauté (1 : sans « Prêt ? », 2 : avec), appliqué une fois dans l'arbre.
var _skip_intro: int = 0


func setup(p_entry: Dictionary, p_precision: int, p_assist: bool, p_mouse: bool) -> ThrowTrial:
	entry = p_entry
	precision = p_precision
	assist = p_assist
	mouse = p_mouse
	slow = Balance.f("throw_game.assist_slowdown") if assist else 1.0
	widen_k = Balance.f("throw_game.assist_widen") if assist else 1.0
	rng = RngService.cosmetic()
	return self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	if full():
		RenderQuality.cover(true)
		tree_exiting.connect(RenderQuality.cover.bind(false))
	_hint = UiKit.rich("", UiKit.SIZE_SMALL)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.fit_content = true
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_keys_label = UiKit.rich("", UiKit.SIZE_BODY)
	_keys_label.fit_content = true
	_keys_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_keys_label)
	resized.connect(_place_hint)
	_refresh_hint()
	_intro_total = Balance.f("throw_game.trial_intro_seconds")
	intro_left = _intro_total
	var art_path: String = "res://assets/trials/trial_%s.png" % String(entry.get("id", ""))
	if ResourceLoader.exists(art_path):
		_art = load(art_path) as Texture2D
	AudioBus.play("panel_open", 1.0, -6.0)
	if _skip_intro > 0:
		_apply_skip_intro()


func _place_hint() -> void:
	_hint.position = Vector2(0, size.y - HINT_H + 6.0)
	_hint.size = Vector2(size.x, HINT_H)


func _refresh_hint() -> void:
	var key: String = "TRIAL_%s_HINT" % String(entry.get("id", "")).to_upper()
	var raw: String = tr(key + "_MOUSE") if mouse and tr(key + "_MOUSE") != key + "_MOUSE" else tr(key)
	if (mouse or touch_controls) and InputGlyphs.using_touch and tr(key + "_TOUCH") != key + "_TOUCH":
		raw = tr(key + "_TOUCH")
	raw = raw.replace("{confirm}", "{@click}" if mouse else "{ui_spin}")
	raw = raw.replace("{move}", "{@mouse}" if mouse else ("{@lstick}" if InputGlyphs.using_pad else "{@arrows}"))
	_hint.text = "[center]%s[/center]" % InputGlyphs.expand(raw, 24)
	_keys_label.text = "[center]%s[/center]" % InputGlyphs.expand(raw, 36)
	_place_hint()


func full() -> bool:
	return String(entry.get("stage", "panel")) == "full"


## Réglage de l'épreuve (balance.json → throw_trials.<id>.<clé>).
func p(key: String) -> float:
	return Balance.f("throw_trials.%s.%s" % [String(entry["id"]), key])


func pi(key: String) -> int:
	return Balance.i("throw_trials.%s.%s" % [String(entry["id"]), key])


## Réglage par manche (tableau) : dernière valeur au-delà.
func pk(key: String, k: int) -> float:
	var a: Array = Balance.arr("throw_trials.%s.%s" % [String(entry["id"]), key])
	return float(a[clampi(k, 0, a.size() - 1)])


## Fenêtre de temps élargie par l'assistance.
func widen() -> float:
	return widen_k


# --------------------------------------------------------------------------- à surcharger


func begin() -> void:
	pass


func tick(_dt: float) -> void:
	pass


## Commande lue pendant l'épreuve ; vrai si consommée.
func handle(_event: InputEvent) -> bool:
	return false


func bot_wants() -> Dictionary:
	return {"do": ""}


func bot_apply(_want: Dictionary) -> void:
	pass


func paint() -> void:
	pass


# --------------------------------------------------------------------------- pilotage (orchestrateur)


func in_intro() -> bool:
	return not _begun


## Commande reçue : pendant l'annonce, confirmer la passe ; ensuite l'épreuve la lit.
func feed(event: InputEvent) -> bool:
	if finished:
		return false
	if rehearsal == "demo":
		if _any_press(event):
			skip_requested.emit()
		return true
	if not _begun:
		if confirm_pressed(event) and _intro_total - intro_left > Balance.f("throw_game.trial_intro_min_seconds"):
			_start()
		return confirm_pressed(event) or sym_pressed(event) >= 0
	if _ready_left > 0.0:
		return confirm_pressed(event) or sym_pressed(event) >= 0
	return handle(event)


func want() -> Dictionary:
	if finished:
		return {"do": ""}
	if not _begun:
		return {"do": "confirm"} if _intro_total - intro_left > Balance.f("throw_game.trial_intro_min_seconds") + 0.1 else {"do": ""}
	if _ready_left > 0.0:
		return {"do": ""}
	return bot_wants()


## Tuto : saute le carton d'annonce (la démo et l'essai montrent l'épreuve tout de suite).
func skip_intro(ready: bool) -> void:
	_skip_intro = 2 if ready else 1
	if is_inside_tree():
		_apply_skip_intro()


func _apply_skip_intro() -> void:
	_start()
	if _skip_intro == 1:
		_ready_left = 0.0


func _any_press(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch:
		return event.is_pressed() and not event.is_echo()
	return event is InputEventAction and event.is_pressed()


func act(w: Dictionary) -> void:
	if not _begun:
		if String(w.get("do", "")) == "confirm":
			_start()
		return
	if _ready_left > 0.0:
		return
	bot_apply(w)


## Crée la scène 3D de l'épreuve (appelée par begin()) : elle remplit la zone de jeu et passe
## derrière le dessin 2D de l'épreuve (consignes, pastilles, notes).
func use_3d() -> Stage3D:
	stage = Stage3D.new()
	stage.show_behind_parent = true
	add_child(stage)
	move_child(stage, 0)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not full():
		stage.offset_bottom = -HINT_H
	elif bleed_x > 0.0:
		stage.offset_left = -bleed_x
		stage.offset_right = bleed_x
	return stage


func _start() -> void:
	if _begun:
		return
	_begun = true
	t = 0.0
	_keys_label.visible = false
	_hint.visible = true
	AudioBus.play("whoosh", 1.3, -8.0)
	_ready_left = Balance.f("throw_game.pace.ready_seconds")
	begin()


# --------------------------------------------------------------------------- cycle


func finish(p_score: float) -> void:
	if finished:
		return
	finished = true
	score = clampf(p_score, 0.0, 1.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	done.emit(score)


## Verdict affiché par-dessus l'épreuve terminée (pendant la pause de l'orchestrateur).
func show_verdict(g: ThrowSkill.Grade) -> void:
	_verdict = int(g)
	if g == ThrowSkill.Grade.PERFECT:
		Platform.haptic(HAPTIC_PERFECT_MS)
	queue_redraw()


func blocked() -> bool:
	return hold.is_valid() and bool(hold.call())


func _process(delta: float) -> void:
	if finished or blocked():
		return
	var dt: float = delta / maxf(Engine.time_scale, 0.0001)
	if not _begun:
		intro_left -= dt
		if intro_left <= 0.0:
			_start()
		_keys_label.visible = not _begun and _keys_label_rect.size.x > 0.0
		_hint.visible = not _keys_label.visible
		if _keys_label.visible:
			_keys_label.position = _keys_label_rect.position
			_keys_label.size = _keys_label_rect.size
		queue_redraw()
		return
	if _ready_left > 0.0:
		_ready_left -= dt
		if _ready_left <= 0.0:
			AudioBus.play("tick", 1.4, -6.0)
		queue_redraw()
		return
	t += dt
	flash = maxf(flash - dt * 3.0, 0.0)
	for pop: Dictionary in _pops:
		pop["t"] = float(pop["t"]) - dt
	_pops = _pops.filter(func(q: Dictionary) -> bool: return float(q["t"]) > 0.0)
	tick(dt)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if finished or blocked():
		return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and feed(event):
		accept_event()


func _draw() -> void:
	if stage != null and _begun:
		# La 3D occupe le fond : seulement le cadre doré pour une épreuve sur le tapis.
		if not full():
			draw_rect(Rect2(0, size.y - HINT_H, size.x, HINT_H), Color(Palette.INK, 0.98))
			draw_rect(Rect2(Vector2.ZERO, size), Palette.GOLD, false, 2.0)
	elif full():
		backdrop()
	else:
		frame(Rect2(Vector2.ZERO, size), 1.0)
		# Fond de velours : halo doux en haut, ombre en bas (les épreuves 2D gagnent du relief).
		for k: int in 6:
			var band: float = float(k) / 6.0
			draw_rect(Rect2(4, 4 + (size.y - 8) * band, size.x - 8, (size.y - 8) / 6.0), Color(Palette.VELVET, 0.16 * (1.0 - band)))
	if not _begun:
		_draw_steps()
		_draw_intro()
		return
	paint()
	_draw_steps()
	if _ready_left > 0.0:
		var a: float = clampf(_ready_left / maxf(Balance.f("throw_game.pace.ready_seconds"), 0.01) * 2.0, 0.0, 1.0)
		text(size * 0.5, tr("TRIAL_READY"), UiKit.SIZE_H1, Color(Palette.GOLD_LIGHT, a), "display", 10)
	_draw_pops()
	if rehearsal != "":
		_draw_rehearsal()
	if _verdict >= 0:
		var c: Vector2 = play_rect().get_center()
		draw_rect(Rect2(c.x - size.x * 0.5, c.y - 44.0, size.x, 88.0), Color(Palette.INK, 0.75))
		var txt: String = "%s : %s" % [Localization.t(entry, "name"), tr(ThrowSkill.grade_key(_verdict as ThrowSkill.Grade))]
		text(c, txt, UiKit.SIZE_H2, GRADE_COLORS[_verdict], "display", 8)


## Tuto : bandeau « DÉMONSTRATION » + étape en cours (la démo défile seule), ou « ESSAI ».
func _draw_rehearsal() -> void:
	var pr: Rect2 = play_rect()
	var top: float = pr.position.y + (70.0 if full() else 34.0)
	var w: float = minf(pr.size.x - 40.0, 1100.0)
	if rehearsal == "demo":
		draw_rect(pr, Color(Palette.INK, 0.28))
		var k: int = clampi(floori(rehearsal_u * float(tuto_lines.size())), 0, maxi(tuto_lines.size() - 1, 0))
		var box: Rect2 = Rect2(pr.get_center().x - w * 0.5, top - 30.0, w, 132.0)
		draw_rect(box, Color(Palette.INK, 0.92))
		draw_rect(box, Palette.GOLD, false, 2.0)
		text(Vector2(box.get_center().x, box.position.y + 24.0), "%s · %d/%d" % [tr("TUTO_DEMO"), k + 1, tuto_lines.size()],
			UiKit.SIZE_SMALL, Palette.GOLD_LIGHT)
		if not tuto_lines.is_empty():
			text(Vector2(box.get_center().x, box.position.y + 66.0), tuto_lines[k], UiKit.SIZE_H2 if full() else UiKit.SIZE_BODY, Palette.IVORY,
				"body")
		text(Vector2(box.get_center().x, box.end.y - 18.0), tr("TUTO_SKIP"), UiKit.SIZE_SMALL, Palette.SMOKE, "body")
		draw_rect(Rect2(box.position.x, box.end.y - 4.0, box.size.x * rehearsal_u, 4.0), Palette.GOLD)
	else:
		var band: Rect2 = Rect2(pr.get_center().x - w * 0.3, top - 22.0, w * 0.6, 44.0)
		draw_rect(band, Color(Palette.INK, 0.85))
		draw_rect(band, Palette.CYAN, false, 2.0)
		text(band.get_center(), tr("TUTO_REHEARSAL"), UiKit.SIZE_BODY, Palette.CYAN)
		draw_rect(Rect2(band.position.x, band.end.y - 4.0, band.size.x * (1.0 - rehearsal_u), 4.0), Palette.CYAN)


## Fond d'un écran dédié (déborde largement : couvre aussi les bandes hors maquette).
func backdrop() -> void:
	draw_rect(Rect2(-size, size * 3.0), Color(0.03, 0.02, 0.03))


## Étapes du lancer : passées en émeraude, en cours en or, à venir en fumée.
func _draw_steps() -> void:
	if steps.is_empty():
		return
	var y: float = 22.0 if full() else -18.0
	var w: float = size.x / float(steps.size())
	if not full():
		draw_rect(Rect2(0, y - 16.0, size.x, 32.0), Color(Palette.INK, 0.9))
	for k: int in steps.size():
		var col: Color = Palette.EMERALD if k < step else (Palette.GOLD_LIGHT if k == step else Palette.SMOKE)
		text(Vector2(w * (float(k) + 0.5), y), "%d · %s" % [k + 1, steps[k]], UiKit.SIZE_SMALL, col)


## Carton d'annonce : illustration propre à l'épreuve, nom, règle en une phrase, jauge du temps
## restant ; les commandes du périphérique actif restent affichées en bas (invite).
## Sur le tapis : image à gauche, texte à droite. En plein écran : grande image au-dessus.
func _draw_intro() -> void:
	var pr: Rect2 = play_rect()
	var u: float = 1.0 - clampf(intro_left / maxf(_intro_total, 0.01), 0.0, 1.0)
	var pop_s: float = 1.0 + 0.15 * (1.0 - clampf(u * 6.0, 0.0, 1.0))
	var text_c: Vector2 = pr.get_center()
	var maxw: float = minf(size.x - 60.0, 900.0)
	if _art != null:
		var art_size: Vector2 = _art.get_size()
		var room: Vector2 = Vector2(pr.size.x * 0.44, pr.size.y - 40.0) if not full() else Vector2(pr.size.x * 0.5, pr.size.y * 0.5)
		var k: float = floorf(minf(room.x / art_size.x, room.y / art_size.y) * 2.0) / 2.0
		var dst: Vector2 = art_size * maxf(k, 1.0)
		var at: Vector2
		if full():
			at = Vector2(pr.get_center().x - dst.x * 0.5, pr.position.y + 90.0)
			text_c = Vector2(pr.get_center().x, at.y + dst.y + 110.0)
		else:
			at = Vector2(pr.position.x + 24.0, pr.get_center().y - dst.y * 0.5 + 6.0)
			var right: float = at.x + dst.x + 24.0
			maxw = pr.end.x - right - 24.0
			text_c = Vector2(right + maxw * 0.5, pr.get_center().y)
		# Léger zoom d'entrée, cadre doré.
		var grow: float = (pop_s - 1.0) * 30.0
		var r: Rect2 = Rect2(at, dst).grow(grow)
		draw_rect(r.grow(6.0), Palette.GOLD_DARK)
		draw_rect(r.grow(3.0), Palette.INK)
		draw_texture_rect(_art, r, false)
	text(text_c + Vector2(0, -60), tr("TRIAL_TITLE") % (step + 1), UiKit.SIZE_SMALL, Palette.SMOKE)
	var big: int = UiKit.SIZE_H1 if full() else UiKit.SIZE_H2
	text(text_c + Vector2(0, -24), Localization.t(entry, "name"), int(big * pop_s), Palette.GOLD_LIGHT)
	var f: Font = UiKit.font("body")
	var fs: int = UiKit.fs(UiKit.SIZE_BODY - 2)
	var desc: String = Localization.t(entry, "desc")
	var pos: Vector2 = Vector2(text_c.x - maxw * 0.5, text_c.y + 22.0)
	draw_multiline_string_outline(f, pos, desc, HORIZONTAL_ALIGNMENT_CENTER, maxw, fs, 4, 6, Palette.INK)
	draw_multiline_string(f, pos, desc, HORIZONTAL_ALIGNMENT_CENTER, maxw, fs, 4, Palette.IVORY)
	var text_h: float = f.get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_CENTER, maxw, fs).y
	var lines: int = mini(4, int(text_h / float(fs)) + 1)
	var bar: Rect2 = Rect2(text_c.x - 120.0, pos.y + float(lines) * float(fs) * 1.2 + 10.0, 240.0, 5.0)
	draw_rect(bar, Palette.VELVET_DEEP)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * u, bar.size.y)), Palette.GOLD)
	_keys_label_rect = Rect2(Vector2(text_c.x - maxw * 0.5, bar.end.y + 14.0), Vector2(maxw, 48.0))


# --------------------------------------------------------------------------- commandes


func confirm_pressed(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		return mb.pressed and not touch_controls and mb.button_index == MOUSE_BUTTON_LEFT
	for a: StringName in CONFIRM_ACTIONS:
		if GameInput.pressed(event, a):
			return true
	return false


func confirm_released(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		return not mb.pressed and not touch_controls and mb.button_index == MOUSE_BUTTON_LEFT
	for a: StringName in CONFIRM_ACTIONS:
		if GameInput.released(event, a):
			return true
	return false


## Direction d'un appui (flèches, croix) : Vector2i.ZERO sinon.
func dir_pressed(event: InputEvent) -> Vector2i:
	if GameInput.pressed(event, &"ui_left", true):
		return Vector2i.LEFT
	if GameInput.pressed(event, &"ui_right", true):
		return Vector2i.RIGHT
	if GameInput.pressed(event, &"ui_up", true):
		return Vector2i.UP
	if GameInput.pressed(event, &"ui_down", true):
		return Vector2i.DOWN
	return Vector2i.ZERO


## Symbole QTE (0 gauche/X, 1 haut/Y, 2 droite/B, 3 bas/A ; clics gauche 0 / droit 1) ou -1.
func sym_pressed(event: InputEvent) -> int:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mouse and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return 0 if mb.button_index == MOUSE_BUTTON_LEFT else 1
		return -1
	for k: int in QTE_ACTIONS.size():
		if GameInput.pressed(event, QTE_ACTIONS[k]):
			return k
	return -1


## Direction tenue (stick gauche, flèches maintenues) en continu, de -1 à 1 par axe.
static func held_vector() -> Vector2:
	var v: Vector2 = Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if v.length() < STICK_DEAD:
		v = Vector2.ZERO
	v += Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	return v.limit_length(1.0)


# --------------------------------------------------------------------------- dessin


## Verdict flottant (« Parfait », « Raté »…) au point donné.
func pop(at: Vector2, sc: float, key: String = "") -> void:
	var g: ThrowSkill.Grade = ThrowSkill.beat_grade(sc)
	_pops.append({"at": at, "t": POP_TIME, "key": key if key != "" else ThrowSkill.grade_key(g), "g": int(g)})


func _draw_pops() -> void:
	for q: Dictionary in _pops:
		var a: float = clampf(float(q["t"]) / POP_TIME, 0.0, 1.0)
		var at: Vector2 = (q["at"] as Vector2) + Vector2(0, -30.0 * (1.0 - a))
		text(at, tr(String(q["key"])), UiKit.SIZE_BODY, Color(GRADE_COLORS[int(q["g"])], a))


func text(at: Vector2, s: String, sz: int, col: Color, font: String = "display", outline: int = 7) -> void:
	var f: Font = UiKit.font(font)
	var fs: int = UiKit.fs(sz)
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos: Vector2 = Vector2(at.x - w * 0.5, at.y + fs * 0.35)
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(Palette.INK, col.a))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Cadre d'épreuve : fond encre, double filet doré.
func frame(r: Rect2, alpha: float = 0.93) -> void:
	draw_rect(r, Color(Palette.INK, alpha))
	draw_rect(r, Palette.GOLD, false, 2.0)
	draw_rect(r.grow(-5), Palette.GOLD_DARK, false, 1.0)


## Zone de jeu (sans la bande d'aide en bas).
func play_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x, size.y - HINT_H))


## Pastilles de progression (n coups, notes déjà obtenues).
func pips(at: Vector2, scores: Array[float], total: int) -> void:
	for k: int in total:
		var c: Vector2 = at + Vector2((float(k) - (total - 1) * 0.5) * 26.0, 0)
		draw_circle(c, 9.0, Palette.VELVET_DEEP)
		draw_arc(c, 9.0, 0, TAU, 20, Palette.GOLD_DARK, 2.0, true)
		if k < scores.size():
			draw_circle(c, 7.0, GRADE_COLORS[int(ThrowSkill.beat_grade(scores[k]))])


static func mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var s: float = 0.0
	for v: float in values:
		s += v
	return s / float(values.size())
