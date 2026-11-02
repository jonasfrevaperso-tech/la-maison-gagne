class_name TrialBottles
extends ThrowTrial
## LES BOUTEILLES (écran dédié) : au comptoir du bar abandonné, on lance des jetons sur des
## bouteilles de bière vides alignées sur l'étagère. Pour chaque jeton : un viseur balaie
## l'étagère (confirmer pour fixer la direction), puis une jauge de force oscille (confirmer dans
## la zone). La bouteille désignée vole en éclats si le tir est juste. Trois jetons, de plus en
## plus vite. Note = moyenne (direction pondérée, force).

enum Phase { AIM, POWER, FLIGHT, REST }

const BOTTLES: int = 6
const SHELF_Y: float = 520.0
const BOTTLE_W: float = 46.0
const BOTTLE_H: float = 150.0
const SHELF_X: Vector2 = Vector2(420.0, 1500.0)
const HAND: Vector2 = Vector2(960.0, 1010.0)
const GLASS: Array[Color] = [Color(0.45, 0.25, 0.08), Color(0.13, 0.4, 0.18), Color(0.55, 0.42, 0.12)]

var _phase: Phase = Phase.AIM
var _throw: int = 0
var _xs: PackedFloat32Array = PackedFloat32Array()
var _alive: Array[bool] = []
var _target: int = 0
var _aim_x: float = 0.0
var _aim_lock: float = 0.0
var _power: float = 0.0
var _scores: Array[float] = []
var _hit: bool = false
var _shards: Array[Dictionary] = []
var _phase_t: float = 0.0
## Valeurs de l'image précédente (le bot détecte le passage sur la cible).
var _prev_aim: float = 0.0
var _prev_power: float = 0.0


func begin() -> void:
	for k: int in BOTTLES:
		_xs.append(lerpf(SHELF_X.x, SHELF_X.y, (float(k) + 0.5) / float(BOTTLES)) + rng.randf_range(-20.0, 20.0))
		_alive.append(true)
	_next_target()


func _next_target() -> void:
	var standing: Array[int] = []
	for k: int in BOTTLES:
		if _alive[k]:
			standing.append(k)
	_target = standing[rng.randi_range(0, standing.size() - 1)]
	_phase = Phase.AIM
	_phase_t = 0.0


func _sweep() -> float:
	return pk("sweep_seconds", _throw) * slow


func handle(event: InputEvent) -> bool:
	if confirm_pressed(event):
		press()
		return true
	return false


func press() -> void:
	match _phase:
		Phase.AIM:
			_aim_lock = _aim_x
			_phase = Phase.POWER
			_phase_t = 0.0
			AudioBus.play("lock", 1.2, -6.0)
		Phase.POWER:
			_throw_chip()


func _power_at(tt: float) -> float:
	var period: float = p("power_seconds") * slow
	var u: float = fposmod(tt / period, 2.0)
	return u if u <= 1.0 else 2.0 - u


func _throw_chip() -> void:
	var zone: float = p("power_zone") * widen()
	var err_x: float = absf(_aim_lock - _xs[_target]) / (BOTTLE_W * 0.5 * p("neck_tolerance") * widen())
	var aim_sc: float = 1.0 if err_x <= 1.0 else clampf(1.0 - (err_x - 1.0) / p("miss_falloff"), 0.0, 1.0)
	var err_p: float = absf(_power - 0.75) / zone
	var pow_sc: float = 1.0 if err_p <= 0.35 else clampf(1.0 - (err_p - 0.35) / 1.3, 0.0, 1.0)
	var sc: float = aim_sc * p("weight_aim") + pow_sc * (1.0 - p("weight_aim"))
	_hit = aim_sc >= 0.99 and pow_sc >= 0.5
	_scores.append(sc)
	_phase = Phase.FLIGHT
	_phase_t = 0.0
	AudioBus.play("whoosh", 1.4, -6.0)


func _land() -> void:
	var sc: float = _scores[-1]
	if _hit:
		_alive[_target] = false
		AudioBus.play("shatter", 1.0 + rng.randf_range(-0.1, 0.1))
		EventBus.juice_shake.emit(0.25)
		for k: int in 14:
			var v: Vector2 = Vector2(rng.randf_range(-320, 320), rng.randf_range(-420, -60))
			_shards.append({"p": Vector2(_xs[_target], SHELF_Y - BOTTLE_H * 0.5), "v": v, "c": GLASS[_target % GLASS.size()], "t": 1.2})
	else:
		AudioBus.play("decor_bottle" if sc > 0.4 else "chip_lose", 1.0, -2.0)
	pop(Vector2(_xs[_target], SHELF_Y - BOTTLE_H - 40.0), sc)
	_phase = Phase.REST
	_phase_t = 0.0


func tick(dt: float) -> void:
	_phase_t += dt
	for sh: Dictionary in _shards:
		sh["v"] = (sh["v"] as Vector2) + Vector2(0, 900.0 * dt)
		sh["p"] = (sh["p"] as Vector2) + (sh["v"] as Vector2) * dt
		sh["t"] = float(sh["t"]) - dt
	_shards = _shards.filter(func(q: Dictionary) -> bool: return float(q["t"]) > 0.0)
	match _phase:
		Phase.AIM:
			var u: float = sin(_phase_t * TAU / _sweep() - PI * 0.5) * 0.5 + 0.5
			_aim_x = lerpf(SHELF_X.x - 60.0, SHELF_X.y + 60.0, u)
			if _phase_t > _sweep() * 3.0:
				press()  # le viseur se fige tout seul
		Phase.POWER:
			_power = _power_at(_phase_t)
			if _phase_t > p("power_seconds") * slow * 4.0:
				_throw_chip()
		Phase.FLIGHT:
			if _phase_t >= p("flight_seconds"):
				_land()
		Phase.REST:
			if _phase_t >= 0.7:
				_throw += 1
				if _throw >= pi("throws"):
					finish(mean(_scores))
				else:
					_next_target()


func bot_wants() -> Dictionary:
	var want: Dictionary = {"do": ""}
	match _phase:
		Phase.AIM:
			if _phase_t > 0.05 and (_prev_aim - _xs[_target]) * (_aim_x - _xs[_target]) <= 0.0:
				want = {"do": "confirm"}
		Phase.POWER:
			if _phase_t > 0.05 and (_prev_power - 0.75) * (_power - 0.75) <= 0.0:
				want = {"do": "confirm"}
	_prev_aim = _aim_x
	_prev_power = _power
	return want


func bot_apply(w: Dictionary) -> void:
	if String(w.get("do", "")) == "confirm":
		press()


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	_draw_bar()
	for k: int in BOTTLES:
		if _alive[k]:
			_draw_bottle(_xs[k], k == _target and _phase != Phase.REST, GLASS[k % GLASS.size()])
	for sh: Dictionary in _shards:
		var c: Color = sh["c"]
		c.a = clampf(float(sh["t"]), 0.0, 1.0)
		var sp: Vector2 = sh["p"]
		draw_colored_polygon(PackedVector2Array([sp, sp + Vector2(10, 4), sp + Vector2(3, 12)]), c.lightened(0.3))
	pips(Vector2(960, 110), _scores, pi("throws"))
	match _phase:
		Phase.AIM:
			_draw_reticle(_aim_x, Palette.CYAN)
		Phase.POWER:
			_draw_reticle(_aim_lock, Palette.GOLD_LIGHT)
			_draw_power()
		Phase.FLIGHT:
			var u: float = clampf(_phase_t / p("flight_seconds"), 0.0, 1.0)
			var dest: Vector2 = Vector2(_aim_lock, SHELF_Y - BOTTLE_H * (0.35 + 0.6 * (_power - 0.4)))
			var pos: Vector2 = HAND.lerp(dest, u) + Vector2(0, -260.0 * sin(u * PI))
			_draw_chip(pos, 1.0 - u * 0.55, _phase_t * 18.0)
	if _phase != Phase.FLIGHT:
		_draw_chip(HAND, 1.0, 0.0)


func _draw_bar() -> void:
	# Mur de briques sombres, néon « BAR » qui grésille, étagère, comptoir.
	draw_rect(Rect2(0, 0, size.x, 780), Color(0.09, 0.05, 0.05))
	for row: int in 20:
		var y: float = 140.0 + row * 32.0
		var off: float = 0.0 if row % 2 == 0 else 40.0
		for col: int in 26:
			var br: Rect2 = Rect2(off + col * 80.0 - 40.0, y, 76.0, 28.0)
			var shade: float = 0.07 + 0.03 * float((row * 7 + col * 13) % 5) / 4.0
			draw_rect(br, Color(shade + 0.05, shade * 0.6, shade * 0.5))
	var flick: float = 0.75 + 0.25 * (1.0 if fposmod(t * 7.3, 3.1) > 0.2 else 0.0)
	text(Vector2(960, 230), "BAR", UiKit.SIZE_H1 + 30, Color(Palette.MAGENTA, flick), "display", 10)
	draw_rect(Rect2(SHELF_X.x - 120.0, SHELF_Y, SHELF_X.y - SHELF_X.x + 240.0, 22.0), Color(0.32, 0.19, 0.09))
	draw_rect(Rect2(SHELF_X.x - 120.0, SHELF_Y + 22.0, SHELF_X.y - SHELF_X.x + 240.0, 8.0), Color(0.16, 0.09, 0.04))
	draw_rect(Rect2(0, 780, size.x, 300), Color(0.22, 0.12, 0.06))
	draw_rect(Rect2(0, 780, size.x, 14), Color(0.42, 0.26, 0.12))
	for k: int in 8:
		draw_line(Vector2(k * 260.0, 800), Vector2(k * 260.0 + 140.0, 1080), Color(0.17, 0.09, 0.04), 3.0)


func _draw_bottle(x: float, highlight: bool, glass: Color) -> void:
	var base: Vector2 = Vector2(x, SHELF_Y)
	var body: Rect2 = Rect2(base.x - BOTTLE_W * 0.5, base.y - BOTTLE_H * 0.62, BOTTLE_W, BOTTLE_H * 0.62)
	draw_rect(body, glass)
	draw_colored_polygon(PackedVector2Array([body.position, body.position + Vector2(BOTTLE_W, 0),
		Vector2(x + 9, base.y - BOTTLE_H * 0.82), Vector2(x - 9, base.y - BOTTLE_H * 0.82)]), glass)
	draw_rect(Rect2(x - 9, base.y - BOTTLE_H, 18, BOTTLE_H * 0.18), glass.darkened(0.1))
	draw_rect(Rect2(x - 11, base.y - BOTTLE_H - 4, 22, 8), Palette.GOLD_DARK)
	draw_rect(Rect2(body.position.x + 4, body.position.y + 26, BOTTLE_W - 8, 34), Palette.IVORY.darkened(0.25))
	draw_rect(Rect2(body.position.x + 6, body.position.y + 6, 6, BOTTLE_H * 0.5), Color(1, 1, 1, 0.18))
	if highlight:
		var pulse: float = 0.5 + 0.5 * sin(t * 8.0)
		var hl: Rect2 = Rect2(x - BOTTLE_W * 0.8, base.y - BOTTLE_H - 14, BOTTLE_W * 1.6, BOTTLE_H + 18)
		draw_rect(hl, Color(Palette.GOLD_LIGHT, 0.3 + 0.4 * pulse), false, 3.0)


func _draw_reticle(x: float, col: Color) -> void:
	var y: float = SHELF_Y - BOTTLE_H * 0.55
	draw_line(Vector2(x, y - 120), Vector2(x, SHELF_Y + 40), Color(col, 0.45), 2.0)
	draw_arc(Vector2(x, y), 26.0, 0, TAU, 32, col, 3.0, true)
	draw_line(Vector2(x - 38, y), Vector2(x - 14, y), col, 3.0)
	draw_line(Vector2(x + 14, y), Vector2(x + 38, y), col, 3.0)


func _draw_power() -> void:
	var r: Rect2 = Rect2(1640, 560, 54, 360)
	draw_rect(r, Palette.VELVET_DEEP)
	draw_rect(r, Palette.GOLD, false, 2.0)
	var zone: float = p("power_zone") * widen()
	var zy: float = r.end.y - r.size.y * (0.75 + zone)
	draw_rect(Rect2(r.position.x, zy, r.size.x, r.size.y * zone * 2.0), Color(Palette.GOLD, 0.55))
	var ny: float = r.end.y - r.size.y * _power
	draw_rect(Rect2(r.position.x - 10, ny - 4, r.size.x + 20, 8), Palette.CYAN)
	text(Vector2(r.get_center().x, r.position.y - 24), tr("TRIAL_BOTTLES_POWER"), UiKit.SIZE_SMALL, Palette.IVORY)


func _draw_chip(at: Vector2, sc: float, spin: float) -> void:
	var rx: float = 34.0 * sc
	var ry: float = rx * absf(cos(spin)) + 4.0
	draw_set_transform(at, 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, rx, Palette.ROULETTE_RED)
	draw_arc(Vector2.ZERO, rx * 0.72, 0, TAU, 24, Palette.IVORY, 4.0 * sc, true)
	for k: int in 6:
		var a: float = TAU * float(k) / 6.0
		draw_line(Vector2(cos(a), sin(a)) * rx * 0.78, Vector2(cos(a), sin(a)) * rx, Palette.IVORY, 5.0 * sc)
	draw_set_transform(Vector2.ZERO)
