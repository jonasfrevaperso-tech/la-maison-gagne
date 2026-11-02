class_name TrialShells
extends ThrowTrial
## BONNETEAU (écran dédié) : un croupier fantôme cache la bille sous l'un de trois gobelets de
## cuivre et les mélange, de plus en plus vite. Suivre le bon gobelet et le désigner
## (gauche / droite puis confirmer, ou cliquer). Trois manches, la dernière avec un quatrième
## gobelet ; le temps de réflexion est compté.

enum Phase { SHOW, HIDE, SHUFFLE, PICK, REVEAL }

const CUP: Vector2 = Vector2(190.0, 210.0)
const TABLE_Y: float = 700.0
const SPACING: float = 380.0

var _phase: Phase = Phase.SHOW
var _round: int = 0
## Position (créneau 0..2) de chaque gobelet ; la bille est sous le gobelet _ball.
var _slot: Array[int] = [0, 1, 2]
var _cups: int = 3
var _ball: int = 0
var _swaps: Array[Vector2i] = []
var _swap_i: int = 0
var _swap_t: float = 0.0
var _lift: float = 1.0
var _cursor: int = 1
var _picked: int = -1
var _scores: Array[float] = []
var _phase_t: float = 0.0


func begin() -> void:
	_new_round()


func _new_round() -> void:
	_cups = int(pk("cups", _round))
	_ball = rng.randi_range(0, _cups - 1)
	_slot.clear()
	for k: int in _cups:
		_slot.append(k)
	_picked = -1
	_phase = Phase.SHOW
	_phase_t = 0.0
	_lift = 1.0
	_swaps.clear()
	var n: int = int(pk("swaps", _round))
	for k: int in n:
		var a: int = rng.randi_range(0, _cups - 1)
		var b: int = (a + 1 + rng.randi_range(0, _cups - 2)) % _cups
		_swaps.append(Vector2i(a, b))
	_swap_i = 0
	_swap_t = 0.0


func _swap_time() -> float:
	return pk("swap_seconds", _round) * slow


func _slot_x(s: float) -> float:
	return size.x * 0.5 + (s - float(_cups - 1) * 0.5) * SPACING


## Position animée du gobelet c (créneau courant, ou en plein échange).
func _cup_pos(c: int) -> Vector2:
	var x: float = _slot_x(float(_slot[c]))
	var y: float = TABLE_Y
	if _phase == Phase.SHUFFLE and _swap_i < _swaps.size():
		var sw: Vector2i = _swaps[_swap_i]
		var u: float = clampf(_swap_t / _swap_time(), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		if _slot[c] == sw.x or _slot[c] == sw.y:
			var from: float = float(_slot[c])
			var to: float = float(sw.y if _slot[c] == sw.x else sw.x)
			x = _slot_x(lerpf(from, to, u))
			y += (40.0 if _slot[c] == sw.x else -40.0) * sin(u * PI)
	return Vector2(x, y)


func handle(event: InputEvent) -> bool:
	if _phase != Phase.PICK:
		return confirm_pressed(event) or dir_pressed(event) != Vector2i.ZERO
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		var hs: int = _slot_at(mm.position)
		if hs >= 0:
			_cursor = hs
		return true
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _slot_at(mb.position) >= 0:
			_cursor = _slot_at(mb.position)
			pick()
		return true
	var d: Vector2i = dir_pressed(event)
	if d.x != 0:
		move(d.x)
		return true
	if confirm_pressed(event):
		pick()
		return true
	return false


func _slot_at(pt: Vector2) -> int:
	for s: int in _cups:
		if absf(pt.x - _slot_x(float(s))) < CUP.x * 0.6 and pt.y > TABLE_Y - CUP.y - 40.0 and pt.y < TABLE_Y + 40.0:
			return s
	return -1


func move(dx: int) -> void:
	_cursor = clampi(_cursor + dx, 0, _cups - 1)
	AudioBus.play("hover", 1.0, -8.0)


func pick(timed_out: bool = false) -> void:
	if _phase != Phase.PICK:
		return
	_picked = _cursor
	var ok: bool = _slot[_ball] == _picked
	var thinking: float = clampf(_phase_t / (p("pick_seconds") * slow), 0.0, 1.0)
	# Trop tard : le croupier soulève le gobelet visé, mais la manche ne rapporte rien.
	var sc: float = (1.0 - 0.15 * thinking) if ok and not timed_out else 0.0
	_scores.append(sc)
	_phase = Phase.REVEAL
	_phase_t = 0.0
	AudioBus.play("cloth", 1.3, -4.0)
	AudioBus.play("chips_win" if ok else "lose_soft", 1.0, -2.0)
	pop(Vector2(_slot_x(float(_picked)), TABLE_Y - CUP.y - 90.0), sc, "TRIAL_SHELLS_FOUND" if ok else "TRIAL_SHELLS_EMPTY")


func tick(dt: float) -> void:
	_phase_t += dt
	match _phase:
		Phase.SHOW:
			if _phase_t > 1.2 * slow:
				_phase = Phase.HIDE
				_phase_t = 0.0
		Phase.HIDE:
			_lift = maxf(1.0 - _phase_t / 0.35, 0.0)
			if _lift <= 0.0:
				AudioBus.play("stone", 1.6, -8.0)
				_phase = Phase.SHUFFLE
				_phase_t = 0.0
		Phase.SHUFFLE:
			_swap_t += dt
			if _swap_t >= _swap_time():
				var sw: Vector2i = _swaps[_swap_i]
				for c: int in _cups:
					if _slot[c] == sw.x:
						_slot[c] = sw.y
					elif _slot[c] == sw.y:
						_slot[c] = sw.x
				AudioBus.play("cloth", 1.5 + 0.1 * float(_swap_i % 3), -8.0)
				_swap_i += 1
				_swap_t = 0.0
				if _swap_i >= _swaps.size():
					_phase = Phase.PICK
					_phase_t = 0.0
					_cursor = 1
		Phase.PICK:
			if _phase_t > p("pick_seconds") * slow:
				pick(true)  # trop long : le croupier soulève le gobelet visé, sans points
		Phase.REVEAL:
			_lift = minf(_phase_t / 0.3, 1.0)
			if _phase_t > 1.3:
				_round += 1
				if _round >= pi("rounds"):
					finish(mean(_scores))
				else:
					_new_round()


func bot_wants() -> Dictionary:
	if _phase != Phase.PICK or _phase_t < 0.3:
		return {"do": ""}
	var goal: int = _slot[_ball]
	if goal == _cursor:
		return {"do": "confirm"}
	return {"do": "dir", "dir": Vector2i(signi(goal - _cursor), 0)}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"confirm":
			pick()
		"dir":
			move((w["dir"] as Vector2i).x)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# Table de rue : caisse en bois, nappe verte usée, lampe nue qui se balance.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.04, 0.05))
	var sway: float = sin(t * 1.3) * 60.0
	draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5 + sway, 200), Palette.SMOKE, 2.0)
	draw_circle(Vector2(size.x * 0.5 + sway, 210), 16.0, Palette.GOLD_LIGHT)
	draw_circle(Vector2(size.x * 0.5 + sway * 0.6, 640), 560.0, Color(1.0, 0.85, 0.5, 0.06))
	draw_rect(Rect2(size.x * 0.5 - 720.0, TABLE_Y + 20.0, 1440.0, 240.0), Color(0.07, 0.24, 0.13))
	draw_rect(Rect2(size.x * 0.5 - 720.0, TABLE_Y + 20.0, 1440.0, 10.0), Color(0.3, 0.18, 0.08))
	draw_rect(Rect2(size.x * 0.5 - 700.0, TABLE_Y + 260.0, 1400.0, 100.0), Color(0.24, 0.14, 0.06))
	pips(Vector2(size.x * 0.5, 110), _scores, pi("rounds"))
	var msg: String = ""
	match _phase:
		Phase.SHOW:
			msg = tr("TRIAL_SHELLS_WATCH")
		Phase.SHUFFLE:
			msg = tr("TRIAL_SHELLS_FOLLOW")
		Phase.PICK:
			msg = tr("TRIAL_SHELLS_PICK")
	if msg != "":
		text(Vector2(size.x * 0.5, 300), msg, UiKit.SIZE_H2, Palette.IVORY)
	var show_ball: bool = _phase in [Phase.SHOW, Phase.HIDE, Phase.REVEAL]
	if show_ball:
		var bp: Vector2 = Vector2(_slot_x(float(_slot[_ball])), TABLE_Y - 18.0)
		draw_circle(bp, 20.0, Palette.IVORY)
		draw_circle(bp + Vector2(-6, -6), 6.0, Color(1, 1, 1, 0.8))
	for c: int in _cups:
		var lifted: float = _lift if (_phase != Phase.REVEAL or _slot[c] == _picked or _slot[c] == _slot[_ball]) else 0.0
		_draw_cup(_cup_pos(c) + Vector2(0, -lifted * 150.0), _phase == Phase.PICK and _slot[c] == _cursor)
	if _phase == Phase.PICK:
		var left: float = clampf(1.0 - _phase_t / (p("pick_seconds") * slow), 0.0, 1.0)
		var bar: Rect2 = Rect2(size.x * 0.5 - 200.0, 980.0, 400.0, 10.0)
		draw_rect(bar, Palette.VELVET_DEEP)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Palette.GOLD)


func _draw_cup(base: Vector2, focus: bool) -> void:
	var w0: float = CUP.x
	var w1: float = CUP.x * 0.62
	var pts: PackedVector2Array = PackedVector2Array([
		base + Vector2(-w0 * 0.5, 0), base + Vector2(w0 * 0.5, 0),
		base + Vector2(w1 * 0.5, -CUP.y), base + Vector2(-w1 * 0.5, -CUP.y)])
	draw_colored_polygon(pts, Color(0.62, 0.34, 0.16))
	draw_colored_polygon(PackedVector2Array([pts[0], pts[0] + Vector2(28, 0), pts[3] + Vector2(18, 0), pts[3]]), Color(0.85, 0.55, 0.3))
	draw_rect(Rect2(base + Vector2(-w0 * 0.5 - 6, -16), Vector2(w0 + 12, 16)), Color(0.5, 0.26, 0.12))
	draw_rect(Rect2(base + Vector2(-w1 * 0.5 - 4, -CUP.y - 10), Vector2(w1 + 8, 12)), Color(0.5, 0.26, 0.12))
	for k: int in 3:
		var y: float = -CUP.y * (0.3 + 0.2 * float(k))
		draw_line(base + Vector2(-w0 * 0.42 + k * 6, y), base + Vector2(w0 * 0.42 - k * 6, y), Color(0.4, 0.2, 0.08), 3.0)
	if focus:
		var pulse: float = 0.6 + 0.4 * sin(t * 8.0)
		draw_rect(Rect2(base + Vector2(-w0 * 0.5 - 14, -CUP.y - 24), Vector2(w0 + 28, CUP.y + 38)), Color(Palette.CYAN, pulse), false, 4.0)
