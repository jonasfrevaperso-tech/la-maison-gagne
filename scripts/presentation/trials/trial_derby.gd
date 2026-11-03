class_name TrialDerby
extends ThrowTrial
## LE TIERCÉ (écran dédié, course de chevaux mécaniques de fête foraine) : quatre chevaux de
## bois sur leurs rails. Le tien galope quand on alterne gauche et droite au rythme du métronome
## (le sabot doré) : dans le temps, la poussée est pleine ; à côté, elle faiblit. Marteler trop
## vite vide la jauge de souffle et le cheval s'essouffle. Trois adversaires à allure fixe.
## Note = place (1er… 4e) et temps à l'arrivée, contre trois chevaux pilotés.

const LANES: int = 4
const TRACK_X: Vector2 = Vector2(300.0, 1640.0)
const LANE_Y0: float = 330.0
const LANE_H: float = 150.0
const HORSE_COLORS: Array[Color] = [Color("ffd23f"), Color("29e0ff"), Color("ff4d6d"), Color("2ee6a8")]
const PLACE_SCORES: Array[float] = [1.0, 0.7, 0.45, 0.2]
const ME: int = 0

var _dist: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _speed: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _finish_t: Array[float] = [-1.0, -1.0, -1.0, -1.0]
var _pace: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _last_side: int = -1
var _last_press: float = -10.0
var _breath: float = 1.0
var _winded: float = 0.0
var _beat_phase: float = 0.0
var _bot_side: int = -1
var _ended: bool = false
var _place: int = -1
var _bob: Array[float] = [0.0, 0.0, 0.0, 0.0]


func begin() -> void:
	var paces: Array = Balance.arr("throw_trials.derby.rival_paces")
	for k: int in range(1, LANES):
		_pace[k] = float(paces[(k - 1) % paces.size()]) * rng.randf_range(0.98, 1.02) / slow
		_bob[k] = rng.randf() * TAU


func _beat() -> float:
	return p("beat_seconds") * slow


## Position dans le temps : 0 sur le temps, 0.5 à contretemps.
func _off_beat() -> float:
	var ph: float = fmod(t / _beat(), 1.0)
	return minf(ph, 1.0 - ph)


func handle(event: InputEvent) -> bool:
	var k: int = sym_pressed(event)
	var d: Vector2i = dir_pressed(event)
	if k == 0 or d == Vector2i.LEFT:
		gallop(0)
		return true
	if (mouse and k == 1) or k == 2 or d == Vector2i.RIGHT:
		gallop(1)
		return true
	return false


func gallop(side: int) -> void:
	if _finish_t[ME] >= 0.0 or _ended:
		return
	if side == _last_side:
		AudioBus.play("sticky", 1.2, -10.0)
		return
	_last_side = side
	var gap: float = t - _last_press
	_last_press = t
	if gap < p("min_gap") * slow:
		_breath = maxf(0.0, _breath - p("breath_cost"))
		if _breath <= 0.0:
			_winded = p("winded_seconds")
			pop(Vector2(TRACK_X.x + 200.0, LANE_Y0 - 70.0), 0.0, "TRIAL_DERBY_WINDED")
	var timing: float = 1.0 - clampf(_off_beat() / (p("beat_window") * widen()), 0.0, 1.0)
	var push: float = lerpf(p("push_off"), 1.0, timing) * (0.25 if _winded > 0.0 else 1.0)
	_speed[ME] = minf(_speed[ME] + p("push") * push, p("max_speed"))
	AudioBus.play("decor_creak" if side == 0 else "tick", 0.9 + 0.3 * timing, -6.0)


func tick(dt: float) -> void:
	if _ended:
		return
	_winded = maxf(0.0, _winded - dt)
	_breath = minf(1.0, _breath + p("breath_regen") * dt)
	if _bot_side >= 0:
		gallop(_bot_side)
		_bot_side = -1
	_speed[ME] -= _speed[ME] * p("drag") * dt  # frottement proportionnel : allure d'équilibre
	for k: int in LANES:
		if k != ME:
			_speed[k] = _pace[k] * (1.0 + 0.08 * sin(t * 1.7 + _bob[k]))
		if _finish_t[k] < 0.0:
			_dist[k] = minf(1.0, _dist[k] + _speed[k] * dt)
			if _dist[k] >= 1.0:
				_finish_t[k] = t
				if k == ME:
					_place = _rank()
					AudioBus.play("slot_win" if _place == 0 else "chip_place", 1.0, -4.0)
					pop(Vector2(TRACK_X.y - 100.0, LANE_Y0 - 70.0), PLACE_SCORES[_place], "TRIAL_DERBY_PLACE_%d" % (_place + 1))
	if _finish_t[ME] >= 0.0 or t >= p("duration") * slow:
		_end()


func _rank() -> int:
	var ahead: int = 0
	for k: int in LANES:
		if k != ME and _finish_t[k] >= 0.0:
			ahead += 1
	return ahead


func _end() -> void:
	_ended = true
	var place: int = _place if _place >= 0 else LANES - 1
	var place_sc: float = PLACE_SCORES[place] if _place >= 0 else 0.0
	var time_sc: float = 0.0
	if _finish_t[ME] >= 0.0:
		var par: float = p("par_seconds") * slow
		var limit: float = p("duration") * slow
		time_sc = clampf((limit - _finish_t[ME]) / maxf(limit - par, 0.01), 0.0, 1.0)
	finish(clampf(place_sc * (1.0 - p("time_weight")) + time_sc * p("time_weight"), 0.0, 1.0))


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	# Frappe sur chaque temps (alterné), jamais plus vite que le souffle ne le permet.
	if _off_beat() < 0.03 and t - _last_press > _beat() * 0.6:
		return {"do": "sym", "symbol": 2 if _last_side == 0 else 0}
	return {"do": ""}


func bot_apply(w: Dictionary) -> void:
	if String(w.get("do", "")) == "sym":
		_bot_side = 0 if int(w.get("symbol", 0)) == 0 else 1
	else:
		_bot_side = -1


# --------------------------------------------------------------------------- dessin


func _horse(at: Vector2, col: Color, gait: float) -> void:
	var lift: float = absf(sin(gait)) * 14.0
	var body: Rect2 = Rect2(at + Vector2(-60, -60 - lift), Vector2(120, 44))
	draw_rect(body, col)
	draw_rect(Rect2(body.end.x - 10, body.position.y - 40, 28, 50), col)
	draw_rect(Rect2(body.end.x + 6, body.position.y - 44, 36, 22), col)
	draw_rect(Rect2(body.end.x - 4, body.position.y - 48, 12, 12), col.darkened(0.3))
	for k: int in 4:
		var lx: float = body.position.x + 10.0 + float(k) * 30.0
		var swing: float = sin(gait + float(k) * 1.6) * 10.0
		draw_line(Vector2(lx, body.end.y), Vector2(lx + swing, at.y), col.darkened(0.25), 8.0)
	var tail: Vector2 = Vector2(body.position.x - 30, body.position.y + 30 + lift)
	draw_line(Vector2(body.position.x, body.position.y + 8), tail, col.darkened(0.4), 6.0)
	draw_circle(Vector2(body.end.x + 30, body.position.y - 36), 3.0, Palette.INK)


func paint() -> void:
	# Stand forain : fronton à ampoules, rails, cible d'arrivée.
	draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color("1a0c18"))
	draw_rect(Rect2(-size.x, 150, size.x * 3.0, 90), Palette.VELVET)
	for k: int in 40:
		var bx: float = -size.x * 0.5 + float(k) * 80.0
		var on: bool = (int(t * 6.0) + k) % 2 == 0
		draw_circle(Vector2(bx, 160), 8.0, Palette.GOLD_LIGHT if on else Palette.GOLD_DARK)
	text(Vector2(size.x * 0.5, 200.0), tr("TRIAL_DERBY_MARQUEE"), UiKit.SIZE_H2, Palette.GOLD_LIGHT)
	for k2: int in LANES:
		var y: float = LANE_Y0 + float(k2) * LANE_H
		draw_rect(Rect2(TRACK_X.x - 80, y - 110, TRACK_X.y - TRACK_X.x + 200, LANE_H - 10), Color("2a1420") if k2 % 2 == 0 else Color("241020"))
		draw_line(Vector2(TRACK_X.x - 80, y + 4), Vector2(TRACK_X.y + 120, y + 4), Palette.BRONZE, 4.0)
		var x: float = lerpf(TRACK_X.x, TRACK_X.y, _dist[k2])
		_horse(Vector2(x, y), HORSE_COLORS[k2], _dist[k2] * 90.0)
		if k2 == ME:
			text(Vector2(TRACK_X.x - 160, y - 50), tr("TRIAL_DERBY_YOU"), UiKit.SIZE_SMALL, HORSE_COLORS[k2])
	for yy: int in 16:
		var fy: float = LANE_Y0 - 110.0 + float(yy) * LANE_H * float(LANES) / 16.0
		draw_rect(Rect2(TRACK_X.y + 60, fy, 20, LANE_H * float(LANES) / 16.0), Palette.IVORY if yy % 2 == 0 else Palette.INK)
	# Métronome (sabot doré) et souffle.
	var m: Vector2 = Vector2(size.x * 0.5 - 200.0, size.y - 110.0)
	var ph: float = fmod(t / _beat(), 1.0)
	draw_arc(m, 34.0, 0, TAU, 32, Palette.GOLD_DARK, 3.0)
	draw_circle(m, 34.0 * (1.0 - ph), Color(Palette.GOLD, 0.25 + 0.6 * (1.0 - ph)))
	var bw: Rect2 = Rect2(size.x * 0.5 - 120.0, size.y - 120.0, 400.0, 20.0)
	draw_rect(bw, Color(Palette.INK, 0.9))
	var bc: Color = Palette.EMERALD if _winded <= 0.0 else Palette.MULT_RED
	draw_rect(Rect2(bw.position, Vector2(bw.size.x * _breath, bw.size.y)), bc)
	draw_rect(bw, Palette.GOLD, false, 2.0)
	text(Vector2(bw.get_center().x, bw.position.y - 22.0), tr("TRIAL_DERBY_BREATH"), UiKit.SIZE_SMALL, Palette.IVORY)
