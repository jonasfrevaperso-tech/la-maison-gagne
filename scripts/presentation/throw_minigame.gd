class_name ThrowMinigame
extends Control
## Mini-jeu du lancer v2, après la visée (la case est figée) — trois temps façon QTE :
## 1. ÉLAN : maintenir pour charger la jauge (elle accélère, puis redescend), relâcher dans l'or ;
## 2. EFFET : des invites défilent vers la ligne, frapper la bonne commande à leur passage
##    (flèches au clavier, X/Y/B/A à la manette, clics gauche/droit à la souris) ;
## 3. LÂCHER : l'anneau se referme sur la bille en accélérant, frapper au contact.
## Les règles de notation sont dans ThrowSkill (logique pure) ; ce nœud mesure le temps, lit les
## commandes et dessine. Temps réel : la vitesse de jeu ne fausse jamais le geste.

signal finished(quality: float)

enum Beat { IDLE, CHARGE_WAIT, CHARGING, SPIN, RELEASE, PAUSE, DONE }

const PANEL_H: float = 78.0
const PANEL_INSET: float = 14.0
const PANEL_PAD: float = 18.0
## Bandeau sous la roue (à la place de l'historique pendant le lancer).
const GAUGE_BELOW: float = 40.0
const STEP_ROW_H: float = 30.0
const GAUGE_H: float = 30.0
const RING_START: float = 200.0
const BALL_R: float = 16.0
const GRADE_TIME: float = 1.5
const NEEDLE_W: float = 6.0
const TICKS: int = 20
const TICK_EVERY: float = 0.07
const PROMPT_SIZE: float = 46.0
const HIT_X: float = 80.0
const POP_TIME: float = 0.6
const CHARGE_ACTIONS: Array[StringName] = [&"ui_spin", &"bet_place", &"ui_accept"]
const QTE_ACTIONS: Array[StringName] = [&"qte_left", &"qte_up", &"qte_right", &"qte_down"]
const PAD_GLYPHS: Array[String] = ["pad_x", "pad_y", "pad_b", "pad_a"]
const MOUSE_GLYPHS: Array[String] = ["mouse_left", "mouse_right"]
## Directions des flèches dessinées au clavier (gauche, haut, droite, bas).
const ARROWS: Array[Vector2] = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]

var beat: Beat = Beat.IDLE
## Point de lâcher de la bille (coordonnées locales) : sous le pointeur de la roue.
var release_point: Vector2 = Vector2.ZERO
## Vrai tant que le geste doit attendre (astuce du tutoriel ouverte) : le temps est figé.
var hold: Callable = Callable()
var power_score: float = 0.0
var spin_score: float = 0.0
var release_score: float = 0.0
var quality: float = 0.0
var _t: float = 0.0
var _slow: float = 1.0
var _assist: bool = false
var _half: float = 0.1
var _center: float = 0.7
var _level: float = 0.0
var _stopped_at: float = -1.0
var _tick_t: float = 0.0
var _mouse: bool = false
var _hits: PackedFloat32Array = PackedFloat32Array()
var _syms: PackedInt32Array = PackedInt32Array()
var _scores: PackedFloat32Array = PackedFloat32Array()
var _pops: Array[Dictionary] = []
var _spin_end: float = 0.0
var _release_time: float = 1.0
var _pause_grade: ThrowSkill.Grade = ThrowSkill.Grade.MISS
var _pause_key: String = ""
var _next: Beat = Beat.IDLE
var _grade: ThrowSkill.Grade = ThrowSkill.Grade.MISS
var _grade_t: float = 0.0
var _flash: float = 0.0
var _control_delta: float = 0.0
var _combo: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func start(precision: int, assist: bool) -> void:
	_assist = assist
	_slow = Balance.f("throw_game.assist_slowdown") if assist else 1.0
	_half = ThrowSkill.sweet_half(precision, assist)
	_center = ThrowSkill.sweet_center(RngService.cosmetic().randf())
	_release_time = Balance.f("throw_game.release_seconds") * _slow
	_mouse = GameInput.last_was_mouse and not InputGlyphs.using_pad
	power_score = 0.0
	spin_score = 0.0
	release_score = 0.0
	_level = 0.0
	_stopped_at = -1.0
	_grade_t = 0.0
	_pops.clear()
	_t = 0.0
	beat = Beat.CHARGE_WAIT
	mouse_filter = Control.MOUSE_FILTER_STOP
	AudioBus.play("whoosh", 1.2, -6.0)
	queue_redraw()


func active() -> bool:
	return beat in [Beat.CHARGE_WAIT, Beat.CHARGING, Beat.SPIN, Beat.RELEASE, Beat.PAUSE]


func _held() -> bool:
	return hold.is_valid() and bool(hold.call())


# --------------------------------------------------------------------------- commandes


## Lit une commande (clavier, manette, souris) ; vrai si elle est consommée.
func handle(event: InputEvent) -> bool:
	if not active() or _held():
		return active()
	var mb: InputEventMouseButton = event as InputEventMouseButton
	match beat:
		Beat.CHARGE_WAIT:
			if _is_charge_press(event):
				press_charge()
				return true
		Beat.CHARGING:
			if _is_charge_release(event):
				release_charge()
				return true
		Beat.SPIN:
			if mb != null:
				if mb.pressed and _mouse and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
					tap(0 if mb.button_index == MOUSE_BUTTON_LEFT else 1)
				return true
			for k: int in QTE_ACTIONS.size():
				if GameInput.pressed(event, QTE_ACTIONS[k]):
					tap(k)
					return true
		Beat.RELEASE:
			if _is_charge_press(event):
				strike()
				return true
	# Pendant le mini-jeu, les autres commandes de jeu sont ignorées (pas de menu par erreur).
	return not event.is_action_pressed("pause_menu")


func _is_charge_press(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	for a: StringName in CHARGE_ACTIONS:
		if GameInput.pressed(event, a):
			return true
	return false


func _is_charge_release(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		return not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	for a: StringName in CHARGE_ACTIONS:
		if GameInput.released(event, a):
			return true
	return false


## Compatibilité (bouton à l'écran, bots) : un appui fait avancer le temps en cours.
func press() -> void:
	match beat:
		Beat.CHARGE_WAIT:
			press_charge()
		Beat.CHARGING:
			release_charge()
		Beat.RELEASE:
			strike()


func press_charge() -> void:
	if beat != Beat.CHARGE_WAIT or _held():
		return
	beat = Beat.CHARGING
	_t = 0.0
	_tick_t = 0.0
	AudioBus.play("cloth", 1.2, -4.0)


func release_charge() -> void:
	if beat != Beat.CHARGING:
		return
	_stopped_at = _level
	power_score = ThrowSkill.power_score(_level, _half, _center)
	_feedback(power_score)
	AudioBus.play("whoosh", 0.8 + _level * 0.6)
	_pause_then(power_score, "THROW_BEAT_POWER", Beat.SPIN)


## Frappe d'une invite d'effet (symbole 0–3, ou 0–1 à la souris).
func tap(symbol: int) -> void:
	if beat != Beat.SPIN:
		return
	var win: float = ThrowSkill.tap_window(_assist)
	for i: int in _hits.size():
		if _scores[i] >= 0.0:
			continue
		var err: float = _t - _hits[i]
		if absf(err) > win:
			continue
		var sc: float = ThrowSkill.tap_score(err, _assist) if _syms[i] == symbol else 0.0
		_judge(i, sc, _syms[i] != symbol)
		return


func strike() -> void:
	if beat != Beat.RELEASE:
		return
	_finish_release(_t - _release_time)


func _judge(i: int, sc: float, wrong: bool) -> void:
	_scores[i] = sc
	var g: ThrowSkill.Grade = ThrowSkill.beat_grade(sc)
	_pops.append({"x": _hit_x(), "t": POP_TIME, "key": "THROW_TAP_WRONG" if wrong else ThrowSkill.grade_key(g), "g": int(g)})
	if sc >= 0.45:
		_combo += 1
		AudioBus.play("chip_place", 0.9 + 0.12 * float(_combo))
		if g == ThrowSkill.Grade.PERFECT:
			AudioBus.play("chime", 1.0 + 0.1 * float(_combo), -6.0)
		_flash = 1.0
	else:
		_combo = 0
		AudioBus.play("clang" if wrong else "lose_soft", 1.0, -6.0)


## Bilan d'un temps : verdict affiché un instant, puis temps suivant.
func _pause_then(score: float, key: String, next_beat: Beat) -> void:
	_pause_grade = ThrowSkill.beat_grade(score)
	_pause_key = key
	_next = next_beat
	beat = Beat.PAUSE
	_t = 0.0


func _start_spin() -> void:
	var n: int = Balance.i("throw_game.spin_prompts")
	var lead: float = Balance.f("throw_game.spin_travel_seconds") * _slow
	var gap: float = Balance.f("throw_game.spin_interval_seconds") * _slow
	var rng: RandomNumberGenerator = RngService.cosmetic()
	var symbols: int = ThrowSkill.MOUSE_SYMBOLS if _mouse else ThrowSkill.SYMBOLS
	_hits.resize(n)
	_syms.resize(n)
	_scores.resize(n)
	for i: int in n:
		_hits[i] = lead + gap * float(i)
		_syms[i] = rng.randi_range(0, symbols - 1)
		_scores[i] = -1.0
	_spin_end = _hits[n - 1] + ThrowSkill.tap_window(_assist) + 0.1
	_combo = 0
	_t = 0.0
	beat = Beat.SPIN


func _end_spin() -> void:
	var taps: Array[float] = []
	for v: float in _scores:
		taps.append(maxf(v, 0.0))
	spin_score = ThrowSkill.spin_score(taps)
	_pause_then(spin_score, "THROW_BEAT_SPIN", Beat.RELEASE)


func _finish_release(error_s: float) -> void:
	release_score = ThrowSkill.release_score(error_s, _assist)
	quality = ThrowSkill.quality(power_score, spin_score, release_score)
	_grade = ThrowSkill.grade(quality)
	_control_delta = ThrowSkill.control_bonus(quality)
	_grade_t = GRADE_TIME
	beat = Beat.DONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback(release_score)
	match _grade:
		ThrowSkill.Grade.PERFECT:
			AudioBus.play("jackpot", 1.2, -4.0)
			EventBus.juice_flash.emit(Palette.GOLD_LIGHT, 0.35)
			EventBus.juice_shake.emit(0.4)
		ThrowSkill.Grade.GREAT:
			AudioBus.play("chime", 1.1)
		ThrowSkill.Grade.GOOD:
			AudioBus.play("chime", 0.85, -4.0)
		_:
			AudioBus.play("lose_soft", 1.0, -4.0)
	finished.emit(quality)


func _feedback(score: float) -> void:
	_flash = 1.0
	AudioBus.play("click" if score < 0.7 else "chip_place", 0.8 + score * 0.6)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and active() and handle(event):
		accept_event()


# --------------------------------------------------------------------------- bots (tests)


## Ce que le mini-jeu attend maintenant : {"do": "press"|"release"|"tap"|"strike"|"", "symbol": k}
## au bon moment pour un geste parfait (utilisé par les parcours automatiques).
func bot_wants() -> Dictionary:
	match beat:
		Beat.CHARGE_WAIT:
			return {"do": "press"}
		Beat.CHARGING:
			return {"do": "release"} if absf(_level - _center) < _half * 0.25 and _t < Balance.f("throw_game.charge_seconds") * _slow else {"do": ""}
		Beat.SPIN:
			for i: int in _hits.size():
				if _scores[i] < 0.0 and absf(_t - _hits[i]) < 0.02:
					return {"do": "tap", "symbol": _syms[i], "mouse": _mouse}
		Beat.RELEASE:
			if _t >= _release_time - 0.01:
				return {"do": "strike"}
	return {"do": ""}


# --------------------------------------------------------------------------- temps


func _process(delta: float) -> void:
	if beat == Beat.IDLE:
		return
	if active() and _held():
		return
	var dt: float = delta / maxf(Engine.time_scale, 0.0001)
	_t += dt
	_flash = maxf(_flash - dt * 3.0, 0.0)
	for p: Dictionary in _pops:
		p["t"] = float(p["t"]) - dt
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) > 0.0)
	match beat:
		Beat.CHARGE_WAIT:
			if _t >= Balance.f("throw_game.charge_wait_seconds"):
				press_charge()  # sans réponse : l'élan se prend tout seul…
		Beat.CHARGING:
			_level = ThrowSkill.charge_level(_t, _slow)
			_tick_t -= dt
			if _tick_t <= 0.0:
				_tick_t = TICK_EVERY
				AudioBus.play("tick", 0.7 + _level * 1.1, -10.0)
			if _t >= Balance.f("throw_game.charge_seconds") * _slow * 4.0:
				release_charge()  # … et se relâche après deux allers-retours.
		Beat.SPIN:
			for i: int in _hits.size():
				if _scores[i] < 0.0 and _t - _hits[i] > ThrowSkill.tap_window(_assist):
					_judge(i, 0.0, false)
			if _t >= _spin_end:
				_end_spin()
		Beat.RELEASE:
			if _t > _release_time + ThrowSkill.tap_window(_assist):
				_finish_release(ThrowSkill.tap_window(_assist) * 2.0)  # trop tard : lâcher raté
		Beat.PAUSE:
			if _t >= Balance.f("throw_game.beat_pause_seconds"):
				if _next == Beat.SPIN:
					_start_spin()
				else:
					beat = Beat.RELEASE
					_t = 0.0
		Beat.DONE:
			_grade_t -= dt
			if _grade_t <= 0.0:
				beat = Beat.IDLE
	queue_redraw()


# --------------------------------------------------------------------------- dessin


func _panel_rect() -> Rect2:
	return Rect2(Vector2(PANEL_INSET, size.y + GAUGE_BELOW - PANEL_H * 0.5), Vector2(size.x - PANEL_INSET * 2.0, PANEL_H))


func _inner_rect() -> Rect2:
	var p: Rect2 = _panel_rect()
	return Rect2(Vector2(p.position.x + PANEL_PAD, p.get_center().y - GAUGE_H * 0.5), Vector2(p.size.x - PANEL_PAD * 2.0, GAUGE_H))


func _hit_x() -> float:
	return _inner_rect().position.x + HIT_X


func _draw() -> void:
	if beat == Beat.IDLE:
		return
	var p: Rect2 = _panel_rect()
	if beat != Beat.DONE or _grade_t > GRADE_TIME * 0.5:
		draw_rect(p, Color(Palette.INK, 0.92))
		draw_rect(p, Palette.GOLD, false, 2.0)
		draw_rect(p.grow(-5), Palette.GOLD_DARK, false, 1.0)
		_draw_steps(p)
		var stage: Beat = _next if beat == Beat.PAUSE else beat
		if beat == Beat.PAUSE:
			stage = Beat.CHARGING if _next == Beat.SPIN else Beat.SPIN
		match stage:
			Beat.CHARGE_WAIT, Beat.CHARGING:
				_draw_gauge()
			Beat.SPIN:
				_draw_track()
			Beat.RELEASE, Beat.DONE:
				_draw_release_hint()
	if beat == Beat.RELEASE:
		_draw_ring()
	if beat == Beat.PAUSE:
		_draw_pause()
	if beat == Beat.DONE:
		_draw_grade()


## Les trois temps au-dessus du bandeau : passé en émeraude, en cours en or, à venir en fumée.
func _draw_steps(p: Rect2) -> void:
	var f: Font = UiKit.font("display")
	var fs: int = UiKit.fs(UiKit.SIZE_SMALL)
	var keys: Array[String] = ["THROW_BEAT_POWER", "THROW_BEAT_SPIN", "THROW_BEAT_RELEASE"]
	var cur: int = _step_index()
	var w: float = p.size.x / 3.0
	for k: int in 3:
		var col: Color = Palette.EMERALD if k < cur else (Palette.GOLD_LIGHT if k == cur else Palette.SMOKE)
		var txt: String = "%d · %s" % [k + 1, tr(keys[k])]
		var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x: float = p.position.x + w * (float(k) + 0.5) - tw * 0.5
		var y: float = p.position.y - 10.0
		draw_string_outline(f, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Palette.INK)
		draw_string(f, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _step_index() -> int:
	match beat:
		Beat.CHARGE_WAIT, Beat.CHARGING:
			return 0
		Beat.SPIN:
			return 1
		Beat.PAUSE:
			return 0 if _next == Beat.SPIN else 1
		Beat.RELEASE:
			return 2
	return 3


func _draw_gauge() -> void:
	var r: Rect2 = _inner_rect()
	draw_rect(r, Palette.VELVET_DEEP)
	var lvl: float = _stopped_at if _stopped_at >= 0.0 else _level
	var in_zone: bool = absf(lvl - _center) <= _half
	draw_rect(Rect2(r.position, Vector2(r.size.x * lvl, r.size.y)), Color(Palette.CYAN if not in_zone else Palette.GOLD_LIGHT, 0.35))
	var zx: float = r.position.x + r.size.x * (_center - _half)
	draw_rect(Rect2(zx, r.position.y, r.size.x * _half * 2.0, r.size.y), Color(Palette.GOLD, 0.55))
	var core: float = _half * Balance.f("throw_game.power_perfect_ratio")
	draw_rect(Rect2(r.position.x + r.size.x * (_center - core), r.position.y, r.size.x * core * 2.0, r.size.y), Palette.GOLD_LIGHT)
	for k: int in TICKS + 1:
		var x: float = r.position.x + r.size.x * float(k) / float(TICKS)
		draw_line(Vector2(x, r.end.y - 6), Vector2(x, r.end.y), Palette.GOLD_DARK, 1.0)
	var nx: float = r.position.x + r.size.x * lvl
	var ncol: Color = Palette.CYAN if _stopped_at < 0.0 else (Palette.EMERALD if power_score >= 0.7 else Palette.MAGENTA)
	draw_rect(Rect2(nx - NEEDLE_W * 0.5, r.position.y - 8, NEEDLE_W, r.size.y + 16), ncol)
	if _flash > 0.0:
		draw_rect(r.grow(8.0 + 10.0 * (1.0 - _flash)), Color(ncol, _flash * 0.8), false, 3.0)
	if beat == Beat.CHARGE_WAIT:
		var pulse: float = 0.6 + 0.4 * sin(_t * 6.0)
		_center_text(r, tr("THROW_HOLD") % _charge_name(), Color(Palette.IVORY, pulse))


func _charge_name() -> String:
	if _mouse:
		return tr("THROW_CLICK")
	return InputGlyphs.plain("ui_spin")


func _draw_track() -> void:
	var r: Rect2 = _inner_rect()
	draw_rect(r, Palette.VELVET_DEEP)
	var hx: float = _hit_x()
	var travel: float = Balance.f("throw_game.spin_travel_seconds") * _slow
	draw_line(Vector2(hx, r.position.y - 14), Vector2(hx, r.end.y + 14), Palette.GOLD_LIGHT, 3.0)
	var frame: Rect2 = Rect2(Vector2(hx, r.get_center().y) - Vector2(PROMPT_SIZE, PROMPT_SIZE) * 0.5, Vector2(PROMPT_SIZE, PROMPT_SIZE))
	draw_rect(frame.grow(4.0), Palette.GOLD, false, 2.0)
	if _flash > 0.0:
		draw_circle(Vector2(hx, r.get_center().y), PROMPT_SIZE * (0.6 + 0.6 * (1.0 - _flash)), Color(Palette.GOLD_LIGHT, _flash * 0.3))
	for i: int in _hits.size():
		if _scores[i] >= 0.0:
			continue
		var u: float = (_hits[i] - _t) / travel
		if u > 1.0:
			continue
		var x: float = hx + u * (r.end.x - hx - PROMPT_SIZE * 0.5)
		_draw_prompt(Vector2(x, r.get_center().y), _syms[i], clampf(1.0 - u * 0.6, 0.4, 1.0))
	var f: Font = UiKit.font("display")
	var fs: int = UiKit.fs(UiKit.SIZE_SMALL)
	for pop: Dictionary in _pops:
		var a: float = clampf(float(pop["t"]) / POP_TIME, 0.0, 1.0)
		var col: Color = [Palette.GOLD_LIGHT, Palette.EMERALD, Palette.CYAN, Palette.MAGENTA][int(pop["g"])]
		var txt: String = tr(String(pop["key"]))
		var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos: Vector2 = Vector2(float(pop["x"]) - tw * 0.5, r.position.y - 26.0 - 22.0 * (1.0 - a))
		draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(Palette.INK, a))
		draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))


## Invite : glyphe de manette, bouton de souris, ou touche fléchée dessinée.
func _draw_prompt(at: Vector2, sym: int, alpha: float) -> void:
	var rect: Rect2 = Rect2(at - Vector2(PROMPT_SIZE, PROMPT_SIZE) * 0.5, Vector2(PROMPT_SIZE, PROMPT_SIZE))
	var tex: Texture2D = null
	if InputGlyphs.using_pad:
		tex = InputGlyphs.texture(PAD_GLYPHS[sym])
	elif _mouse:
		tex = InputGlyphs.texture(MOUSE_GLYPHS[sym % MOUSE_GLYPHS.size()])
	if tex != null:
		draw_texture_rect(tex, rect, false, Color(1, 1, 1, alpha))
		return
	draw_rect(rect, Color(Palette.IVORY, alpha))
	draw_rect(rect.grow(-3), Color(Palette.INK, alpha))
	var d: Vector2 = ARROWS[sym]
	var n: Vector2 = Vector2(-d.y, d.x)
	var c: Vector2 = at
	var tri: PackedVector2Array = PackedVector2Array([c + d * 14.0, c - d * 6.0 + n * 12.0, c - d * 6.0 - n * 12.0])
	draw_colored_polygon(tri, Color(Palette.GOLD_LIGHT, alpha))
	draw_line(c - d * 14.0, c - d * 4.0, Color(Palette.GOLD_LIGHT, alpha), 6.0)


func _draw_release_hint() -> void:
	var r: Rect2 = _inner_rect()
	if beat == Beat.RELEASE:
		_center_text(r, tr("THROW_STRIKE_ON_CONTACT") % _charge_name(), Palette.IVORY)


func _center_text(r: Rect2, txt: String, col: Color) -> void:
	var f: Font = UiKit.font("display")
	var fs: int = UiKit.fs(UiKit.SIZE_BODY - 2)
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos: Vector2 = Vector2(r.get_center().x - w * 0.5, r.get_center().y + fs * 0.35)
	draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Palette.INK)
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_ring() -> void:
	var u: float = ThrowSkill.ring_progress(_t, _release_time)
	var rad: float = lerpf(BALL_R, RING_START, u)
	if _t > _release_time:
		rad = BALL_R * maxf(1.0 - (_t - _release_time) * 4.0, 0.0)
	var close: float = 1.0 - clampf(absf(_t - _release_time) / maxf(ThrowSkill.tap_window(_assist), 0.001), 0.0, 1.0)
	var col: Color = Palette.CYAN.lerp(Palette.GOLD_LIGHT, close)
	draw_circle(release_point, BALL_R + 10.0, Color(Palette.INK, 0.6))
	draw_arc(release_point, BALL_R + 2.0, 0.0, TAU, 32, Palette.GOLD_DARK, 2.0, true)
	draw_circle(release_point, BALL_R * 0.7, Palette.IVORY)
	if rad > 1.0:
		draw_arc(release_point, rad, 0.0, TAU, 48, col, 4.0 + 4.0 * close, true)
		draw_arc(release_point, rad + 9.0, 0.0, TAU, 48, Color(col, 0.25), 2.0, true)


## Verdict d'un temps, au-dessus du bandeau.
func _draw_pause() -> void:
	var p: Rect2 = _panel_rect()
	var u: float = clampf(_t / maxf(Balance.f("throw_game.beat_pause_seconds"), 0.01), 0.0, 1.0)
	var f: Font = UiKit.font("display")
	var txt: String = "%s : %s" % [tr(_pause_key), tr(ThrowSkill.grade_key(_pause_grade))]
	var pop: float = 1.0 + 0.2 * (1.0 - clampf(u * 5.0, 0.0, 1.0))
	var fs: int = int(UiKit.fs(UiKit.SIZE_H2) * pop)
	var col: Color = [Palette.GOLD_LIGHT, Palette.EMERALD, Palette.CYAN, Palette.MAGENTA][int(_pause_grade)]
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos: Vector2 = Vector2(p.get_center().x - w * 0.5, p.position.y - 48.0)
	draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Palette.INK)
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_grade() -> void:
	var u: float = 1.0 - _grade_t / GRADE_TIME
	var f: Font = UiKit.font("display")
	var txt: String = tr(ThrowSkill.grade_key(_grade))
	var pop: float = 1.0 + 0.25 * (1.0 - clampf(u * 4.0, 0.0, 1.0))
	var fs: int = int(UiKit.fs(UiKit.SIZE_H1) * pop)
	var col: Color = [Palette.GOLD_LIGHT, Palette.EMERALD, Palette.CYAN, Palette.MAGENTA][int(_grade)]
	col.a = clampf((1.0 - u) * 2.0, 0.0, 1.0)
	var pt: Vector2 = release_point + Vector2(0, 70 - 30 * u)
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string_outline(f, pt - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, 8, Color(Palette.INK, col.a))
	draw_string(f, pt - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)
	# Trois pastilles : note de chaque temps.
	var scores: Array[float] = [power_score, spin_score, release_score]
	for k: int in 3:
		var g: int = int(ThrowSkill.beat_grade(scores[k]))
		var c: Color = [Palette.GOLD_LIGHT, Palette.EMERALD, Palette.CYAN, Palette.MAGENTA][g]
		draw_circle(pt + Vector2(-36.0 + 36.0 * float(k), 26.0), 9.0, Color(c, col.a))
	var sub: String = tr("THROW_CONTROL_DELTA") % ("%+d" % roundi(_control_delta * 100.0))
	var sfs: int = UiKit.fs(UiKit.SIZE_SMALL)
	var sw: float = f.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, sfs).x
	var scol: Color = (Palette.EMERALD if _control_delta >= 0.0 else Palette.DANGER)
	scol.a = col.a
	draw_string(UiKit.font("mono"), pt + Vector2(-sw * 0.5, sfs + 50), sub, HORIZONTAL_ALIGNMENT_CENTER, -1, sfs, scol)
