class_name ThrowMinigame
extends Control
## Mini-jeu du lancer, temps 2 et 3 (la visée a déjà figé la case) :
## - Élan : une aiguille balaie la jauge, on l'arrête dans la zone dorée ;
## - Lâcher : un anneau se resserre sur la bille, on frappe quand il la touche.
## Même commande partout : Espace / clic / RT / A. Les règles de notation sont dans ThrowSkill
## (logique pure) ; ce nœud ne fait que mesurer le temps et dessiner.

signal finished(quality: float)

enum Beat { IDLE, POWER, RELEASE, DONE }

const GAUGE_SIZE: Vector2 = Vector2(560, 30)
const PANEL_H: float = 64.0
const PANEL_INSET: float = 20.0
const PANEL_PAD: float = 22.0
const LABEL_W: float = 190.0
## Jauge sous la roue (à la place de l'historique pendant le lancer).
const GAUGE_BELOW: float = 52.0
const RING_START: float = 190.0
const BALL_R: float = 16.0
const GRADE_TIME: float = 0.9
const NEEDLE_W: float = 6.0
const TICKS: int = 20

var beat: Beat = Beat.IDLE
## Point de lâcher de la bille (coordonnées locales) : sous le pointeur de la roue.
var release_point: Vector2 = Vector2.ZERO
## Vrai tant que le geste doit attendre (astuce du tutoriel ouverte) : le temps est figé.
var hold: Callable = Callable()
var power_score: float = 0.0
var release_score: float = 0.0
var quality: float = 0.0
var _t: float = 0.0
var _period: float = 1.0
var _release_time: float = 0.8
var _window: float = 0.2
var _half: float = 0.1
var _assist: bool = false
var _needle: float = 0.0
var _stopped_at: float = -1.0
var _grade: ThrowSkill.Grade = ThrowSkill.Grade.MISS
var _grade_t: float = 0.0
var _flash: float = 0.0
var _control_delta: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func start(precision: int, assist: bool) -> void:
	_assist = assist
	var slow: float = Balance.f("throw_game.assist_slowdown") if assist else 1.0
	_period = Balance.f("throw_game.power_period_seconds") * slow
	_release_time = Balance.f("throw_game.release_seconds") * slow
	_window = Balance.f("throw_game.release_window_seconds") * (Balance.f("throw_game.assist_widen") if assist else 1.0)
	_half = ThrowSkill.sweet_half(precision, assist)
	_t = 0.0
	_stopped_at = -1.0
	_grade_t = 0.0
	beat = Beat.POWER
	mouse_filter = Control.MOUSE_FILTER_STOP
	AudioBus.play("whoosh", 1.2, -6.0)
	queue_redraw()


func active() -> bool:
	return beat == Beat.POWER or beat == Beat.RELEASE


## Le geste du joueur (une seule commande pour les deux temps).
func press() -> void:
	if hold.is_valid() and bool(hold.call()):
		return
	match beat:
		Beat.POWER:
			_stopped_at = _needle
			power_score = ThrowSkill.power_score(_needle, _half)
			_feedback(power_score)
			beat = Beat.RELEASE
			_t = 0.0
		Beat.RELEASE:
			_finish_release(_t - _release_time)


func _finish_release(error_s: float) -> void:
	release_score = ThrowSkill.release_score(error_s, _assist)
	quality = ThrowSkill.quality(power_score, release_score)
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
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and active():
		press()
		accept_event()


func _process(delta: float) -> void:
	if beat == Beat.IDLE:
		return
	if active() and hold.is_valid() and bool(hold.call()):
		return
	# Temps réel : ni la vitesse de jeu ni l'arrêt sur image ne faussent le geste.
	var dt: float = delta / maxf(Engine.time_scale, 0.0001)
	_t += dt
	_flash = maxf(_flash - dt * 3.0, 0.0)
	match beat:
		Beat.POWER:
			_needle = ThrowSkill.power_needle(_t, _period)
			if _t >= _period * float(Balance.i("throw_game.power_auto_cycles")):
				press()  # sans réponse : l'élan est pris où il est
		Beat.RELEASE:
			if _t > _release_time + _window:
				_finish_release(_window * 2.0)  # trop tard : lâcher raté
		Beat.DONE:
			_grade_t -= dt
			if _grade_t <= 0.0:
				beat = Beat.IDLE
	queue_redraw()


# --------------------------------------------------------------------------- dessin


## Bandeau sous la roue : étape à gauche, jauge à droite.
func _panel_rect() -> Rect2:
	return Rect2(Vector2(PANEL_INSET, size.y + GAUGE_BELOW - PANEL_H * 0.5), Vector2(size.x - PANEL_INSET * 2.0, PANEL_H))


func _gauge_rect() -> Rect2:
	var p: Rect2 = _panel_rect()
	var x0: float = p.position.x + LABEL_W
	return Rect2(Vector2(x0, p.get_center().y - GAUGE_SIZE.y * 0.5), Vector2(p.end.x - x0 - PANEL_PAD, GAUGE_SIZE.y))


func _draw() -> void:
	if beat == Beat.IDLE:
		return
	if beat == Beat.POWER or beat == Beat.RELEASE or (beat == Beat.DONE and _grade_t > GRADE_TIME * 0.5):
		_draw_gauge()
	if beat == Beat.RELEASE:
		_draw_ring()
	if beat == Beat.DONE:
		_draw_grade()


func _draw_gauge() -> void:
	var r: Rect2 = _gauge_rect()
	var panel: Rect2 = _panel_rect()
	draw_rect(panel, Color(Palette.INK, 0.92))
	draw_rect(panel, Palette.GOLD, false, 2.0)
	draw_rect(panel.grow(-5), Palette.GOLD_DARK, false, 1.0)
	draw_rect(r, Palette.VELVET_DEEP)
	# Zone dorée (et cœur parfait) au centre.
	var half_px: float = _half * r.size.x
	var cx: float = r.position.x + r.size.x * 0.5
	draw_rect(Rect2(cx - half_px, r.position.y, half_px * 2.0, r.size.y), Color(Palette.GOLD, 0.55))
	var core: float = half_px * Balance.f("throw_game.power_perfect_ratio")
	draw_rect(Rect2(cx - core, r.position.y, core * 2.0, r.size.y), Palette.GOLD_LIGHT)
	for k: int in TICKS + 1:
		var x: float = r.position.x + r.size.x * float(k) / float(TICKS)
		draw_line(Vector2(x, r.end.y - 6), Vector2(x, r.end.y), Palette.GOLD_DARK, 1.0)
	var pos: float = _stopped_at if _stopped_at >= 0.0 else _needle
	var nx: float = r.position.x + r.size.x * pos
	var ncol: Color = Palette.CYAN if _stopped_at < 0.0 else (Palette.EMERALD if power_score >= 0.7 else Palette.MAGENTA)
	draw_rect(Rect2(nx - NEEDLE_W * 0.5, r.position.y - 10, NEEDLE_W, r.size.y + 20), ncol)
	var top: float = r.position.y
	draw_colored_polygon(PackedVector2Array([Vector2(nx, top - 4), Vector2(nx - 9, top - 18), Vector2(nx + 9, top - 18)]), ncol)
	if _flash > 0.0:
		draw_rect(r.grow(8.0 + 10.0 * (1.0 - _flash)), Color(ncol, _flash * 0.8), false, 3.0)
	# Étapes : 1 · ÉLAN, 2 · LÂCHER (l'étape en cours en or, la suivante en fumée).
	var f: Font = UiKit.font("display")
	var fs: int = UiKit.fs(UiKit.SIZE_BODY - 2)
	var steps: Array[String] = [tr("THROW_BEAT_POWER"), tr("THROW_BEAT_RELEASE")]
	for k: int in 2:
		var on: bool = (k == 0 and beat == Beat.POWER) or (k == 1 and beat != Beat.POWER)
		var y: float = panel.position.y + panel.size.y * (0.38 + 0.36 * float(k))
		var dot: Vector2 = Vector2(panel.position.x + 22, y - fs * 0.3)
		draw_circle(dot, 6.0, Palette.GOLD_LIGHT if on else Palette.SMOKE_DARK)
		var txt: String = "%d · %s" % [k + 1, steps[k]]
		draw_string(f, Vector2(dot.x + 14, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.GOLD_LIGHT if on else Palette.SMOKE)


func _draw_ring() -> void:
	var u: float = clampf(_t / _release_time, 0.0, 1.5)
	var rad: float = lerpf(RING_START, BALL_R, minf(u, 1.0))
	if u > 1.0:
		rad = BALL_R * (1.0 - (u - 1.0) * 2.0)
	var close: float = 1.0 - clampf(absf(_t - _release_time) / maxf(_window, 0.001), 0.0, 1.0)
	var col: Color = Palette.CYAN.lerp(Palette.GOLD_LIGHT, close)
	draw_circle(release_point, BALL_R + 10.0, Color(Palette.INK, 0.6))
	draw_arc(release_point, BALL_R + 2.0, 0.0, TAU, 32, Palette.GOLD_DARK, 2.0, true)
	draw_circle(release_point, BALL_R * 0.7, Palette.IVORY)
	if rad > 1.0:
		draw_arc(release_point, rad, 0.0, TAU, 48, col, 4.0 + 4.0 * close, true)


func _draw_grade() -> void:
	var u: float = 1.0 - _grade_t / GRADE_TIME
	var f: Font = UiKit.font("display")
	var txt: String = tr(ThrowSkill.grade_key(_grade))
	var pop: float = 1.0 + 0.25 * (1.0 - clampf(u * 4.0, 0.0, 1.0))
	var fs: int = int(UiKit.fs(UiKit.SIZE_H1) * pop)
	var col: Color = [Palette.GOLD_LIGHT, Palette.EMERALD, Palette.CYAN, Palette.MAGENTA][int(_grade)]
	col.a = clampf((1.0 - u) * 2.0, 0.0, 1.0)
	var p: Vector2 = release_point + Vector2(0, 70 - 30 * u)
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string_outline(f, p - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, 8, Color(Palette.INK, col.a))
	draw_string(f, p - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)
	var sub: String = tr("THROW_CONTROL_DELTA") % ("%+d" % roundi(_control_delta * 100.0))
	var sfs: int = UiKit.fs(UiKit.SIZE_SMALL)
	var sw: float = f.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, sfs).x
	var scol: Color = (Palette.EMERALD if _control_delta >= 0.0 else Palette.DANGER)
	scol.a = col.a
	draw_string(UiKit.font("mono"), p + Vector2(-sw * 0.5, sfs + 10), sub, HORIZONTAL_ALIGNMENT_CENTER, -1, sfs, scol)
