class_name TrialSafe
extends ThrowTrial
## COFFRE-FORT : le vieux coffre du caissier. Tourner la molette (stick, flèches, molette ou
## glisser à la souris) en écoutant les crans : plus on approche du bon chiffre, plus le
## stéthoscope s'affole. Confirmer pour valider chacun des trois chiffres avant la fin du temps.

const DIAL_N: int = 40
const DIAL_R: float = 92.0

var _codes: Array[int] = []
var _locked: Array[float] = []
var _dial: float = 0.0
var _last_notch: int = 0
var _bot_axis: float = 0.0
var _drag: bool = false
var _open_t: float = -1.0
var _scores: Array[float] = []


func begin() -> void:
	for k: int in pi("numbers"):
		var c: int = rng.randi_range(0, DIAL_N - 1)
		while not _codes.is_empty() and absi(c - _codes[-1]) < 8:
			c = rng.randi_range(0, DIAL_N - 1)
		_codes.append(c)
	_dial = float(rng.randi_range(0, DIAL_N - 1))
	_last_notch = int(round(_dial))


func _target() -> int:
	return _codes[_locked.size()] if _locked.size() < _codes.size() else 0


## Écart circulaire au bon chiffre (en crans).
func _dist() -> float:
	var d: float = absf(fposmod(_dial - float(_target()) + DIAL_N * 0.5, float(DIAL_N)) - DIAL_N * 0.5)
	return d


func _closeness() -> float:
	return clampf(1.0 - _dist() / 10.0, 0.0, 1.0)


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			turn(1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			turn(-1.0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			lock()
		return true
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		if _drag:
			turn(mm.relative.x * 0.08)
		return true
	if confirm_pressed(event):
		lock()
		return true
	return false


func turn(d: float) -> void:
	if _open_t >= 0.0:
		return
	_dial = fposmod(_dial + d, float(DIAL_N))
	var notch: int = int(round(_dial)) % DIAL_N
	if notch != _last_notch:
		_last_notch = notch
		var c: float = _closeness()
		AudioBus.play("tick", 0.8 + c * 0.9, -14.0 + c * 10.0)
		if _dist() < 0.5:
			AudioBus.play("lock", 0.7, -4.0)


func lock() -> void:
	if _open_t >= 0.0 or _locked.size() >= _codes.size():
		return
	var d: float = _dist()
	var tol: float = p("tolerance") * widen()
	var sc: float = 1.0 if d <= tol * 0.5 else clampf(1.0 - (d - tol * 0.5) / p("falloff"), 0.0, 1.0)
	_locked.append(_dial)
	_scores.append(sc)
	pop(Vector2(_slot_x(_locked.size() - 1), 70.0), sc)
	AudioBus.play("vault" if sc >= 0.7 else "clang", 1.0, -4.0)
	if _locked.size() >= _codes.size():
		_open_t = 0.0


func _time_left() -> float:
	return p("time_limit") * slow - t


func tick(dt: float) -> void:
	if _open_t >= 0.0:
		_open_t += dt
		if _open_t > 0.9:
			var vals: Array[float] = _scores.duplicate()
			while vals.size() < _codes.size():
				vals.append(0.0)
			finish(mean(vals))
		return
	var v: float = held_vector().x + _bot_axis
	if absf(v) > 0.0:
		turn(v * p("dial_speed") * dt * (0.35 if absf(v) < 0.6 else 1.0))
	if _time_left() <= 0.0:
		AudioBus.play("error", 0.8)
		_open_t = 0.0


func bot_wants() -> Dictionary:
	if _open_t >= 0.0:
		return {"do": ""}
	var d: float = fposmod(float(_target()) - _dial + DIAL_N * 0.5, float(DIAL_N)) - DIAL_N * 0.5
	if absf(d) < 0.25:
		return {"do": "confirm"}
	return {"do": "axis", "v": Vector2(clampf(d * 0.8, -1.0, 1.0), 0)}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"confirm":
			_bot_axis = 0.0
			lock()
		"axis":
			_bot_axis = (w["v"] as Vector2).x
		_:
			_bot_axis = 0.0


func _slot_x(k: int) -> float:
	return size.x * 0.52 + float(k) * 92.0


func paint() -> void:
	var r: Rect2 = play_rect()
	var c: Vector2 = Vector2(r.position.x + 150.0, r.get_center().y + 4.0)
	# Porte du coffre : acier, rivets, molette graduée.
	draw_rect(Rect2(c - Vector2(130, 118), Vector2(260, 236)), Color(0.22, 0.24, 0.26))
	for k: int in 4:
		var corner: Vector2 = c + Vector2(-112 if k % 2 == 0 else 112, -100 if k < 2 else 100)
		draw_circle(corner, 6.0, Color(0.45, 0.47, 0.5))
	var shake: Vector2 = Vector2(sin(t * 60.0), cos(t * 53.0)) * 2.0 * _closeness() * _closeness()
	var dc: Vector2 = c + shake
	draw_circle(dc, DIAL_R + 8.0, Color(0.1, 0.1, 0.11))
	draw_circle(dc, DIAL_R, Color(0.32, 0.33, 0.35))
	var f: Font = UiKit.font("mono")
	var fs: int = UiKit.fs(UiKit.SIZE_SMALL - 4)
	for n: int in DIAL_N:
		var a: float = -PI * 0.5 + TAU * (float(n) - _dial) / DIAL_N
		var dir: Vector2 = Vector2(cos(a), sin(a))
		var big: bool = n % 5 == 0
		draw_line(dc + dir * (DIAL_R - (16.0 if big else 9.0)), dc + dir * (DIAL_R - 2.0), Palette.IVORY, 2.0 if big else 1.0)
		if big:
			var lbl: String = str(n)
			var w: float = f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, dc + dir * (DIAL_R - 32.0) + Vector2(-w * 0.5, fs * 0.35), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.IVORY)
	draw_circle(dc, 26.0, Color(0.2, 0.2, 0.22))
	var notch: PackedVector2Array = PackedVector2Array(
		[c + Vector2(-10, -DIAL_R - 22), c + Vector2(10, -DIAL_R - 22), c + Vector2(0, -DIAL_R - 6)]
	)
	draw_colored_polygon(notch, Palette.GOLD_LIGHT)
	# Combinaison : trois cases, chiffre en cours qui clignote.
	for k: int in _codes.size():
		var box: Rect2 = Rect2(Vector2(_slot_x(k) - 36.0, r.position.y + 96.0), Vector2(72, 64))
		draw_rect(box, Palette.VELVET_DEEP)
		var col: Color = Palette.GOLD_DARK
		var lbl2: String = "--"
		if k < _locked.size():
			lbl2 = "%02d" % (int(round(_locked[k])) % DIAL_N)
			col = GRADE_COLORS[int(ThrowSkill.beat_grade(_scores[k]))]
		elif k == _locked.size():
			col = Color(Palette.CYAN, 0.6 + 0.4 * sin(t * 6.0))
		draw_rect(box, col, false, 3.0)
		text(box.get_center(), lbl2, UiKit.SIZE_H2, Palette.IVORY, "mono", 0)
	# Stéthoscope : jauge de proximité qui s'affole.
	var meter: Rect2 = Rect2(Vector2(size.x * 0.52 - 36.0, r.position.y + 190.0), Vector2(256.0, 16.0))
	draw_rect(meter, Palette.VELVET_DEEP)
	var jitter: float = 0.05 * sin(t * 47.0) * _closeness()
	var fill: float = meter.size.x * clampf(_closeness() + jitter, 0.0, 1.0)
	draw_rect(Rect2(meter.position, Vector2(fill, meter.size.y)), Palette.EMERALD.lerp(Palette.GOLD_LIGHT, _closeness()))
	text(Vector2(meter.position.x + meter.size.x * 0.5, meter.position.y - 14.0), tr("TRIAL_SAFE_LISTEN"), UiKit.SIZE_SMALL, Palette.SMOKE)
	var tl: float = clampf(_time_left() / (p("time_limit") * slow), 0.0, 1.0)
	var secs: String = "%d s" % ceili(maxf(_time_left(), 0.0))
	text(Vector2(r.end.x - 70.0, r.position.y + 40.0), secs, UiKit.SIZE_BODY, Palette.GOLD if tl > 0.3 else Palette.DANGER, "mono")
