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

const GRADE_COLORS: Array[Color] = [Palette.GOLD_LIGHT, Palette.EMERALD, Palette.CYAN, Palette.MAGENTA]
const CONFIRM_ACTIONS: Array[StringName] = [&"ui_spin", &"bet_place", &"ui_accept"]
const QTE_ACTIONS: Array[StringName] = [&"qte_left", &"qte_up", &"qte_right", &"qte_down"]
const POP_TIME: float = 0.8
## Hauteur réservée en bas du cadre à l'aide aux commandes.
const HINT_H: float = 40.0
const STICK_DEAD: float = 0.25

var entry: Dictionary = {}
var assist: bool = false
var precision: int = 1
var mouse: bool = false
## Ralenti d'assistance (> 1 : plus lent).
var slow: float = 1.0
var t: float = 0.0
var finished: bool = false
var score: float = 0.0
var flash: float = 0.0
var hold: Callable = Callable()
var rng: RandomNumberGenerator = null
## Bandeau des étapes du lancer (« 1 · Bouteilles  2 · Effet  3 · Lâcher ») et étape courante.
var steps: Array[String] = []
var step: int = 0
## Carton d'annonce (nom, règle, commandes) avant que l'épreuve ne commence.
var intro_left: float = 0.0
var _intro_total: float = 1.0
var _begun: bool = false
var _verdict: int = -1
var _pops: Array[Dictionary] = []
var _hint: RichTextLabel = null


func setup(p_entry: Dictionary, p_precision: int, p_assist: bool, p_mouse: bool) -> ThrowTrial:
	entry = p_entry
	precision = p_precision
	assist = p_assist
	mouse = p_mouse
	slow = Balance.f("throw_game.assist_slowdown") if assist else 1.0
	rng = RngService.cosmetic()
	return self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_hint = UiKit.rich("", UiKit.SIZE_SMALL)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.fit_content = true
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	resized.connect(_place_hint)
	_refresh_hint()
	_intro_total = Balance.f("throw_game.trial_intro_seconds")
	intro_left = _intro_total
	AudioBus.play("panel_open", 1.0, -6.0)


func _place_hint() -> void:
	_hint.position = Vector2(0, size.y - HINT_H + 6.0)
	_hint.size = Vector2(size.x, HINT_H)


func _refresh_hint() -> void:
	var key: String = "TRIAL_%s_HINT" % String(entry.get("id", "")).to_upper()
	var raw: String = tr(key + "_MOUSE") if mouse and tr(key + "_MOUSE") != key + "_MOUSE" else tr(key)
	raw = raw.replace("{confirm}", "{@click}" if mouse else "{ui_spin}")
	raw = raw.replace("{move}", "{@mouse}" if mouse else ("{@lstick}" if InputGlyphs.using_pad else "{@arrows}"))
	_hint.text = "[center]%s[/center]" % InputGlyphs.expand(raw, 24)
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
	return Balance.f("throw_game.assist_widen") if assist else 1.0


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
	if not _begun:
		if confirm_pressed(event) and _intro_total - intro_left > Balance.f("throw_game.trial_intro_min_seconds"):
			_start()
		return confirm_pressed(event) or sym_pressed(event) >= 0
	return handle(event)


func want() -> Dictionary:
	if finished:
		return {"do": ""}
	if not _begun:
		return {"do": "confirm"} if _intro_total - intro_left > Balance.f("throw_game.trial_intro_min_seconds") + 0.1 else {"do": ""}
	return bot_wants()


func act(w: Dictionary) -> void:
	if not _begun:
		if String(w.get("do", "")) == "confirm":
			_start()
		return
	bot_apply(w)


func _start() -> void:
	if _begun:
		return
	_begun = true
	t = 0.0
	AudioBus.play("whoosh", 1.3, -8.0)
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
	if full():
		backdrop()
	else:
		frame(Rect2(Vector2.ZERO, size), 0.98)
	if not _begun:
		_draw_steps()
		_draw_intro()
		return
	paint()
	_draw_steps()
	_draw_pops()
	if _verdict >= 0:
		var c: Vector2 = play_rect().get_center()
		draw_rect(Rect2(c.x - size.x * 0.5, c.y - 44.0, size.x, 88.0), Color(Palette.INK, 0.75))
		var txt: String = "%s : %s" % [Localization.t(entry, "name"), tr(ThrowSkill.grade_key(_verdict as ThrowSkill.Grade))]
		text(c, txt, UiKit.SIZE_H2, GRADE_COLORS[_verdict], "display", 8)


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


## Carton d'annonce : nom de l'épreuve, règle en une phrase, jauge du temps restant.
func _draw_intro() -> void:
	var c: Vector2 = play_rect().get_center()
	var u: float = 1.0 - clampf(intro_left / maxf(_intro_total, 0.01), 0.0, 1.0)
	var pop_s: float = 1.0 + 0.15 * (1.0 - clampf(u * 6.0, 0.0, 1.0))
	text(c + Vector2(0, -60), tr("TRIAL_TITLE") % (step + 1), UiKit.SIZE_SMALL, Palette.SMOKE)
	var big: int = UiKit.SIZE_H1 if full() else UiKit.SIZE_H2
	text(c + Vector2(0, -24), Localization.t(entry, "name"), int(big * pop_s), Palette.GOLD_LIGHT)
	var f: Font = UiKit.font("body")
	var fs: int = UiKit.fs(UiKit.SIZE_BODY - 2)
	var maxw: float = minf(size.x - 60.0, 900.0)
	var desc: String = Localization.t(entry, "desc")
	var pos: Vector2 = Vector2(c.x - maxw * 0.5, c.y + 22.0)
	draw_multiline_string_outline(f, pos, desc, HORIZONTAL_ALIGNMENT_CENTER, maxw, fs, 3, 6, Palette.INK)
	draw_multiline_string(f, pos, desc, HORIZONTAL_ALIGNMENT_CENTER, maxw, fs, 3, Palette.IVORY)
	var bar: Rect2 = Rect2(c.x - 120.0, c.y + 100.0, 240.0, 5.0)
	draw_rect(bar, Palette.VELVET_DEEP)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * u, bar.size.y)), Palette.GOLD)


# --------------------------------------------------------------------------- commandes


func confirm_pressed(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	for a: StringName in CONFIRM_ACTIONS:
		if GameInput.pressed(event, a):
			return true
	return false


func confirm_released(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		return not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
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
