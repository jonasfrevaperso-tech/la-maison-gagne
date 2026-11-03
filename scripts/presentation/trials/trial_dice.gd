class_name TrialDice
extends ThrowTrial
## LES DÉS (écran dédié, table de craps vue de dessus) : trois lancers. On vise (stick, flèches,
## souris), puis on maintient pour charger la force (la jauge monte et redescend) et on lâche.
## Les dés doivent toucher la bande du fond (règle du craps), rebondir et s'arrêter dans la
## zone dorée, qui change à chaque lancer. On note la position d'arrêt, jamais la face.
## Note = moyenne de la proximité au centre de la zone (sans bande touchée : note réduite).

const TABLE: Rect2 = Rect2(260.0, 170.0, 1400.0, 760.0)
const START: Vector2 = Vector2(960.0, 880.0)
const DIE: float = 44.0
const PAIR_GAP: float = 30.0
const AIM_LIMIT: float = 1.1
const ZONE_X: Vector2 = Vector2(520.0, 1400.0)
const ZONE_Y: Vector2 = Vector2(520.0, 720.0)
const PIPS: Dictionary[int, Array] = {
	1: [Vector2(0, 0)], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}

var _throw: int = 0
var _aim: float = 0.0
var _charge: float = 0.0
var _charge_dir: float = 1.0
var _charging: bool = false
var _flying: bool = false
var _pos: Vector2 = START
var _vel: Vector2 = Vector2.ZERO
var _wall: bool = false
var _spin: float = 0.0
var _faces: Array[int] = [1, 1]
var _zone: Vector2 = Vector2.ZERO
var _scores: Array[float] = []
var _rest_t: float = 0.0
var _mouse_pos: Vector2 = Vector2(-1, -1)
var _bot_aim: float = 0.0
var _bot_mode: String = ""
var _trail: Array[Vector2] = []
var _wait: float = 0.0


func begin() -> void:
	_new_zone()


func _new_zone() -> void:
	_zone = Vector2(rng.randf_range(ZONE_X.x, ZONE_X.y), rng.randf_range(ZONE_Y.x, ZONE_Y.y))
	_pos = START
	_vel = Vector2.ZERO
	_wall = false
	_flying = false
	_charge = 0.0
	_charge_dir = 1.0
	_trail.clear()
	_wait = 0.0


func _zone_r() -> float:
	return p("zone_radius") * widen()


func _speed_for(charge: float) -> float:
	return lerpf(p("speed_min"), p("speed_max"), charge)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_pos = mm.position
		return true
	if confirm_pressed(event):
		_charging = not _flying and _rest_t <= 0.0
		return true
	if confirm_released(event):
		if _charging:
			_release()
		return true
	return false


func _release() -> void:
	_charging = false
	_flying = true
	_vel = Vector2.from_angle(-PI * 0.5 + _aim) * _speed_for(_charge)
	_faces = [rng.randi_range(1, 6), rng.randi_range(1, 6)]
	AudioBus.play("dice", 1.0, -2.0)


func tick(dt: float) -> void:
	if _throw >= pi("throws"):
		return
	if _rest_t > 0.0:
		_rest_t -= dt
		if _rest_t <= 0.0:
			_throw += 1
			if _throw >= pi("throws"):
				finish(ThrowTrial.mean(_scores))
			else:
				_new_zone()
		return
	if not _flying:
		_wait += dt
		if _wait >= p("aim_timeout") * slow:
			_release()  # le croupier perd patience : les dés partent tels quels
			return
		var axis: float = held_vector().x + _bot_aim
		_aim = clampf(_aim + axis * p("aim_speed") * dt, -AIM_LIMIT, AIM_LIMIT)
		if mouse and _mouse_pos.x >= 0.0:
			var d: Vector2 = _mouse_pos - START
			if d.length() > 20.0:
				_aim = clampf(atan2(d.x, -d.y), -AIM_LIMIT, AIM_LIMIT)
		if _charging:
			_charge += _charge_dir * dt / (p("charge_seconds") * slow)
			if _charge >= 1.0 or _charge <= 0.0:
				_charge = clampf(_charge, 0.0, 1.0)
				_charge_dir = -_charge_dir

		return
	_roll(dt)


## Glissement sur le feutre : décélération constante, rebond amorti sur les bandes.
func _roll(dt: float) -> void:
	var sp: float = _vel.length()
	var dec: float = p("friction") * dt
	if sp <= dec:
		_vel = Vector2.ZERO
		_settle()
		return
	_vel = _vel * ((sp - dec) / sp)
	_pos += _vel * dt
	_spin += sp * dt * 0.02
	if _trail.is_empty() or _trail[-1].distance_to(_pos) > 18.0:
		_trail.append(_pos)
	var half: float = DIE * 0.5 + PAIR_GAP * 0.5
	if _pos.y < TABLE.position.y + DIE * 0.5:
		_pos.y = TABLE.position.y + DIE * 0.5
		_vel.y = absf(_vel.y) * p("restitution")
		_vel.x *= p("restitution")
		_wall = true
		AudioBus.play("ball_wood", 1.3, -4.0)
	if _pos.x < TABLE.position.x + half or _pos.x > TABLE.end.x - half:
		_pos.x = clampf(_pos.x, TABLE.position.x + half, TABLE.end.x - half)
		_vel.x = -_vel.x * p("restitution")
		AudioBus.play("ball_wood", 1.1, -8.0)
	if _pos.y > TABLE.end.y - DIE * 0.5:
		_pos.y = TABLE.end.y - DIE * 0.5
		_vel.y = -absf(_vel.y) * p("restitution")


func _settle() -> void:
	_flying = false
	var dist: float = _pos.distance_to(_zone)
	var sc: float = clampf(1.0 - maxf(dist - _zone_r() * p("perfect_ratio"), 0.0) / (_zone_r() * p("falloff")), 0.0, 1.0)
	if not _wall:
		sc *= p("no_wall_factor")
		pop(_pos + Vector2(0, -70), 0.0, "TRIAL_DICE_NO_WALL")
	else:
		pop(_pos + Vector2(0, -70), sc)
	_scores.append(sc)
	_rest_t = p("rest_seconds")
	AudioBus.play("chip_place" if sc > 0.5 else "lose_soft", 1.0, -6.0)


# --------------------------------------------------------------------------- bot


## Visée idéale : le reflet de la zone derrière la bande du fond donne l'angle, et la vitesse
## couvre l'aller (décélération) puis le retour après un rebond amorti.
func bot_plan() -> Vector2:
	var wall_y: float = TABLE.position.y + DIE * 0.5
	var mirror: Vector2 = Vector2(_zone.x, 2.0 * wall_y - _zone.y)
	var dir: Vector2 = (mirror - START).normalized()
	var aim: float = atan2(dir.x, -dir.y)
	var hit: Vector2 = START + dir * ((START.y - wall_y) / -dir.y)
	var d1: float = START.distance_to(hit)
	var d2: float = hit.distance_to(_zone)
	var e: float = p("restitution")
	var v_after: float = sqrt(2.0 * p("friction") * d2) / e
	var v0: float = sqrt(v_after * v_after + 2.0 * p("friction") * d1)
	var charge: float = clampf((v0 - p("speed_min")) / (p("speed_max") - p("speed_min")), 0.0, 1.0)
	return Vector2(aim, charge)


func bot_wants() -> Dictionary:
	if _flying or _rest_t > 0.0:
		return {"do": ""}
	var plan: Vector2 = bot_plan()
	var miss: float = plan.x - _aim
	if absf(miss) > p("bot_aim_tolerance") and not _charging:
		# Amplitude mini : un vrai stick a une zone morte.
		return {"do": "axis", "v": Vector2(signf(miss) * clampf(absf(miss) * 8.0, 0.35, 1.0), 0.0)}
	if not _charging:
		return {"do": "hold"}
	# Lâcher quand la jauge croise la force voulue (prévue une image à l'avance).
	var nxt: float = _charge + _charge_dir / 60.0 / (p("charge_seconds") * slow)
	if (_charge - plan.y) * (nxt - plan.y) <= 0.0:
		return {"do": "release"}
	return {"do": "hold"}


func bot_apply(w: Dictionary) -> void:
	_bot_mode = String(w.get("do", ""))
	_bot_aim = (w.get("v", Vector2.ZERO) as Vector2).x if _bot_mode == "axis" else 0.0
	if _bot_mode == "hold" and not _flying and _rest_t <= 0.0:
		_charging = true
	elif _bot_mode == "release" and _charging:
		_release()


# --------------------------------------------------------------------------- dessin


func _die(c: Vector2, face: int, rot: float) -> void:
	var xf: Transform2D = Transform2D(rot, c)
	draw_set_transform_matrix(xf)
	draw_rect(Rect2(Vector2(-DIE, -DIE) * 0.5 + Vector2(4, 5), Vector2(DIE, DIE)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(Vector2(-DIE, -DIE) * 0.5, Vector2(DIE, DIE)), Palette.ROULETTE_RED)
	draw_rect(Rect2(Vector2(-DIE, -DIE) * 0.5, Vector2(DIE, DIE)), Palette.IVORY, false, 2.0)
	for pp: Variant in PIPS[face]:
		draw_circle((pp as Vector2) * DIE * 0.27, 4.5, Palette.IVORY)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func paint() -> void:
	draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color("0c0810"))
	# Table de craps : bande de bois, feutre, marquages.
	draw_rect(TABLE.grow(40.0), Color("4a2a14"))
	draw_rect(TABLE.grow(14.0), Palette.GOLD_DARK)
	draw_rect(TABLE, Palette.FELT)
	# Bande du fond à pyramides (le mur de rebond).
	var x: float = TABLE.position.x
	while x < TABLE.end.x:
		draw_colored_polygon(PackedVector2Array([Vector2(x, TABLE.position.y), Vector2(x + 14, TABLE.position.y + 14),
			Vector2(x + 28, TABLE.position.y)]), Palette.GOLD)
		x += 28.0
	draw_rect(Rect2(TABLE.position.x + 60, TABLE.end.y - 230, TABLE.size.x - 120, 6), Color(Palette.IVORY, 0.3))
	text(Vector2(TABLE.position.x + 220, TABLE.end.y - 260), "PASS LINE", UiKit.SIZE_SMALL, Color(Palette.IVORY, 0.35))
	text(Vector2(TABLE.end.x - 220, TABLE.end.y - 260), "COME", UiKit.SIZE_SMALL, Color(Palette.IVORY, 0.35))
	# Zone visée.
	var zr: float = _zone_r()
	draw_circle(_zone, zr * (1.0 + p("falloff")), Color(Palette.GOLD, 0.08))
	draw_circle(_zone, zr, Color(Palette.GOLD, 0.25))
	draw_arc(_zone, zr, 0, TAU, 40, Palette.GOLD_LIGHT, 3.0)
	draw_circle(_zone, 6.0, Palette.GOLD_LIGHT)
	for k: int in _trail.size():
		draw_circle(_trail[k], 3.0, Color(Palette.IVORY, 0.15))
	# Visée et jauge.
	if not _flying and _rest_t <= 0.0:
		var dir: Vector2 = Vector2.from_angle(-PI * 0.5 + _aim)
		for k2: int in 10:
			draw_circle(START + dir * (60.0 + float(k2) * 34.0), 5.0 - float(k2) * 0.3, Color(Palette.CYAN, 0.8 - float(k2) * 0.07))
		var g: Rect2 = Rect2(TABLE.end.x + 70.0, TABLE.position.y + 80.0, 40.0, TABLE.size.y - 160.0)
		draw_rect(g, Color(Palette.INK, 0.9))
		draw_rect(Rect2(g.position.x, g.end.y - g.size.y * _charge, g.size.x, g.size.y * _charge), Palette.GOLD.lerp(Palette.MULT_RED, _charge))
		draw_rect(g, Palette.GOLD, false, 2.0)
	var rot: float = _spin
	_die(_pos + Vector2(-PAIR_GAP * 0.5 - DIE * 0.25, 0), _faces[0], rot)
	_die(_pos + Vector2(PAIR_GAP * 0.5 + DIE * 0.25, 0), _faces[1], -rot * 0.8)
	pips(Vector2(size.x * 0.5, 100.0), _scores, pi("throws"))
