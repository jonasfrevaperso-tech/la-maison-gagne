class_name TrialCave
extends ThrowTrial
## LA CAVE DU GRAND ZÉRO (écran dédié, course de plateformes) : le groom traverse les caves
## du casino pour rapporter la bouteille du patron. Courir (stick, flèches, souris à droite),
## sauter (valider). Fosses à franchir, grandes fosses avec un câble de lustre où l'on se
## suspend puis se lâche au bon moment, tonneaux qui roulent, rats qui patrouillent, trésors
## suspendus (jetons) à cueillir d'un saut. Chute = retour au bord, choc = sonné.
## Note = part du parcours × poids + part des trésors × poids, moins les chutes et les chocs.

const FLOOR_Y: float = 860.0
const SCREEN_X: float = 520.0
const BODY: Vector2 = Vector2(36.0, 70.0)
const SEG_W: float = 760.0
const KINDS: Array[String] = ["pit", "rope", "barrel", "rat", "pit", "treasure"]
const ROPE_LEN: float = 300.0
const ROPE_PIVOT_H: float = 470.0
const GRAB_R: float = 56.0
const TREASURE_H: float = 150.0
const BARREL_R: float = 30.0
const RAT_W: float = 50.0
const GROOM: Array[String] = [
	"  ####  ",
	" ###### ",
	"  #  #  ",
	"  ####  ",
	" ###### ",
	"########",
	"# #### #",
	"  ####  ",
	"  #  #  ",
	" ##  ## ",
]

var _x: float = 120.0
var _y: float = FLOOR_Y
var _vx: float = 0.0
var _vy: float = 0.0
var _ground: bool = true
var _rope: int = -1
var _segs: Array[Dictionary] = []
var _goal_x: float = 0.0
var _treasures: int = 0
var _treasure_total: int = 0
var _falls: int = 0
var _hits: int = 0
var _stun: float = 0.0
var _mouse_x: float = -1.0
var _bot_axis: float = 0.0
var _bot_jump: bool = false
var _jump_queued: bool = false
var _cam: float = 0.0
var _ended: bool = false
var _run_anim: float = 0.0


func begin() -> void:
	var order: Array[String] = []
	var n: int = pi("segments")
	while order.size() < n:
		var bag: Array[String] = KINDS.duplicate()
		for i: int in range(bag.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: String = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
		order.append_array(bag)
	order.resize(n)
	for k: int in n:
		var x0: float = 500.0 + float(k) * SEG_W
		var seg: Dictionary = {"kind": order[k], "x": x0 + SEG_W * 0.5, "taken": false, "phase": rng.randf() * TAU}
		match order[k]:
			"pit":
				seg["w"] = p("pit_width")
			"rope":
				seg["w"] = p("rope_pit_width")
			"barrel":
				seg["bx"] = x0 + SEG_W + 300.0
			"rat":
				seg["bx"] = x0 + SEG_W * 0.5
		if order[k] in ["treasure", "pit", "barrel"]:
			_treasure_total += 1
		_segs.append(seg)
	_goal_x = 500.0 + float(n) * SEG_W + 200.0


func _dur() -> float:
	return p("duration") * slow


## Fosse sous x (index du segment) ou -1.
func _pit_at(x: float) -> int:
	for k: int in _segs.size():
		var s: Dictionary = _segs[k]
		if String(s["kind"]) in ["pit", "rope"] and absf(x - float(s["x"])) < float(s["w"]) * 0.5:
			return k
	return -1


func _rope_angle(k: int) -> float:
	return p("rope_swing") * sin(t * TAU / p("rope_period") + float(_segs[k]["phase"]))


func _rope_end(k: int) -> Vector2:
	var a: float = _rope_angle(k)
	var pivot: Vector2 = Vector2(float(_segs[k]["x"]), FLOOR_Y - ROPE_PIVOT_H)
	return pivot + Vector2(sin(a), cos(a)) * ROPE_LEN


func _treasure_pos(s: Dictionary) -> Vector2:
	var x: float = float(s["x"])
	if String(s["kind"]) == "barrel":
		x -= SEG_W * 0.25
	return Vector2(x, FLOOR_Y - TREASURE_H - BODY.y * 0.5)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_x = mm.position.x
		return true
	if confirm_pressed(event) or sym_pressed(event) == 3 or GameInput.pressed(event, &"ui_up"):
		_jump_queued = true
		return true
	return false


func _jump() -> void:
	if _stun > 0.0:
		return
	if _rope >= 0:
		# Se lâcher du câble : on garde l'élan du balancement.
		var a: float = _rope_angle(_rope)
		var w: float = p("rope_swing") * TAU / p("rope_period") * cos(t * TAU / p("rope_period") + float(_segs[_rope]["phase"]))
		_vx = maxf(w * ROPE_LEN * cos(a), 0.0) + p("run_speed") * 0.6
		_vy = -p("jump_speed") * 0.6
		_rope = -1
		_ground = false
		AudioBus.play("whoosh", 1.2, -6.0)
	elif _ground:
		_vy = -p("jump_speed")
		_ground = false
		AudioBus.play("decor_squeak", 1.4, -8.0)


func tick(dt: float) -> void:
	if _ended:
		return
	_stun = maxf(0.0, _stun - dt)
	if _jump_queued or _bot_jump:
		_jump()
	_jump_queued = false
	_bot_jump = false
	var axis: float = clampf(held_vector().x + _bot_axis, -1.0, 1.0)
	if mouse and _mouse_x >= 0.0:
		axis = clampf((_mouse_x - (_x - _cam)) / 120.0, -1.0, 1.0)
	if _stun > 0.0:
		axis = 0.0
	if _rope >= 0:
		var e: Vector2 = _rope_end(_rope)
		_x = e.x
		_y = e.y + BODY.y
	else:
		if _ground:
			_vx = axis * p("run_speed")
		else:
			_vx = move_toward(_vx, axis * p("run_speed"), p("air_control") * dt)
		_vy += p("gravity") * dt
		_x += _vx * dt
		_y += _vy * dt
		_x = maxf(_x, 60.0)
		_land()
		_grab_rope()
	_run_anim += absf(_vx) * dt * 0.02
	_obstacles(dt)
	_collect()
	_cam = clampf(_x - SCREEN_X, 0.0, _goal_x - size.x + 200.0)
	if _x >= _goal_x or t >= _dur():
		_end()


func _land() -> void:
	if _vy < 0.0:
		return
	var pit: int = _pit_at(_x)
	if pit < 0 and _y >= FLOOR_Y:
		_y = FLOOR_Y
		_vy = 0.0
		_ground = true
	elif pit >= 0 and _y > FLOOR_Y + p("fall_depth"):
		# Chute : retour au bord de la fosse, un peu de temps perdu.
		_falls += 1
		pop(Vector2(_x - _cam, FLOOR_Y - 150.0), 0.0, "TRIAL_CAVE_FALL")
		AudioBus.play("decor_topple", 0.8, -4.0)
		var s: Dictionary = _segs[pit]
		_x = float(s["x"]) - float(s["w"]) * 0.5 - 60.0
		_y = FLOOR_Y
		_vx = 0.0
		_vy = 0.0
		_ground = true
		_stun = p("fall_stun")
	elif pit >= 0:
		_ground = false


func _grab_rope() -> void:
	if _ground:
		return
	for k: int in _segs.size():
		if String(_segs[k]["kind"]) != "rope":
			continue
		# Les mains attrapent le câble sur son tiers inférieur (plus tolérant que le seul bout).
		var e: Vector2 = _rope_end(k)
		var pivot: Vector2 = Vector2(float(_segs[k]["x"]), FLOOR_Y - ROPE_PIVOT_H)
		var hands: Vector2 = Vector2(_x, _y - BODY.y)
		var near: Vector2 = Geometry2D.get_closest_point_to_segment(hands, pivot.lerp(e, 0.6), e)
		if near.distance_to(hands) < GRAB_R and _x < float(_segs[k]["x"]) + 40.0:
			_rope = k
			_vx = 0.0
			_vy = 0.0
			AudioBus.play("cloth", 1.0, -6.0)
			return


func _obstacles(dt: float) -> void:
	for s: Dictionary in _segs:
		var kind: String = String(s["kind"])
		if kind == "barrel":
			s["bx"] = float(s["bx"]) - p("barrel_speed") * dt
			var start: float = float(s["x"]) - SEG_W * 0.5
			if float(s["bx"]) < start - 200.0:
				s["bx"] = start + SEG_W + 300.0
			_bump(Vector2(float(s["bx"]), FLOOR_Y - BARREL_R), BARREL_R)
		elif kind == "rat":
			var x0: float = float(s["x"])
			s["bx"] = x0 + sin(t * p("rat_speed") + float(s["phase"])) * SEG_W * 0.3
			_bump(Vector2(float(s["bx"]), FLOOR_Y - 14.0), RAT_W * 0.5)


func _bump(c: Vector2, r: float) -> void:
	if _stun > 0.0 or _rope >= 0:
		return
	var feet: Vector2 = Vector2(_x, _y - BODY.y * 0.3)
	if absf(feet.x - c.x) < r + BODY.x * 0.4 and absf(feet.y - c.y) < r + BODY.y * 0.3:
		_hits += 1
		_stun = p("hit_stun")
		_vx = -p("run_speed") * 0.5
		_x -= 40.0
		pop(Vector2(_x - _cam, FLOOR_Y - 150.0), 0.0, "TRIAL_CAVE_HIT")
		AudioBus.play("decor_bottle", 0.7, -4.0)


func _collect() -> void:
	for s: Dictionary in _segs:
		if bool(s["taken"]) or not String(s["kind"]) in ["treasure", "pit", "barrel"]:
			continue
		var tp: Vector2 = _treasure_pos(s)
		if tp.distance_to(Vector2(_x, _y - BODY.y * 0.5)) < 60.0:
			s["taken"] = true
			_treasures += 1
			pop(tp - Vector2(_cam, 50.0), 1.0, "TRIAL_CAVE_TREASURE")
			AudioBus.play("coins", 1.2, -4.0)


func _end() -> void:
	_ended = true
	var prog: float = clampf(_x / _goal_x, 0.0, 1.0)
	var tre: float = float(_treasures) / maxf(float(_treasure_total), 1.0)
	var sc: float = prog * p("weight_distance") + tre * (1.0 - p("weight_distance"))
	sc -= p("fall_penalty") * float(_falls) + p("hit_penalty") * float(_hits)
	if _x >= _goal_x:
		AudioBus.play("jackpot", 1.3, -8.0)
	finish(clampf(sc, 0.0, 1.0))


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	# Court à droite ; saute au bord des fosses, par-dessus tonneaux et rats ; aux grandes
	# fosses, attend le câble qui revient, s'y suspend puis se lâche en fin d'aller.
	if _rope >= 0:
		var a: float = _rope_angle(_rope)
		var rising: bool = cos(t * TAU / p("rope_period") + float(_segs[_rope]["phase"])) > 0.0
		return {"do": "confirm"} if rising and a > p("rope_swing") * 0.45 else {"do": ""}
	if not _ground:
		return {"do": "axis", "v": Vector2(1, 0)}
	var air: float = 2.0 * p("jump_speed") / p("gravity")
	var reach: float = p("run_speed") * air
	for s: Dictionary in _segs:
		var kind: String = String(s["kind"])
		var x: float = float(s["x"])
		match kind:
			"pit":
				var edge: float = x - float(s["w"]) * 0.5
				if edge - _x > 0.0 and edge - _x < reach * 0.5 - float(s["w"]) * 0.5 + 40.0:
					return {"do": "confirm"}
			"rope":
				var edge2: float = x - float(s["w"]) * 0.5
				if edge2 - _x > -10.0 and edge2 - _x < 120.0:
					var e: Vector2 = _rope_end(int(_segs.find(s)))
					var coming: bool = cos(t * TAU / p("rope_period") + float(s["phase"])) < 0.0
					var near: bool = e.x - edge2 < 110.0
					if edge2 - _x < 40.0 and not (coming and near):
						return {"do": "axis", "v": Vector2.ZERO}
					return {"do": "confirm"} if coming and near else {"do": "axis", "v": Vector2(1, 0)}
			"barrel", "rat":
				var bx: float = float(s["bx"])
				var closing: float = p("run_speed") + (p("barrel_speed") if kind == "barrel" else 0.0)
				var d: float = bx - _x
				if d > 0.0 and d < closing * air * 0.5 + 10.0 and d > closing * air * 0.25:
					return {"do": "confirm"}
		if kind in ["treasure", "barrel"] and not bool(s["taken"]):
			var dt_x: float = _treasure_pos(s).x - _x
			if dt_x < reach * 0.5 + 6.0 and dt_x > reach * 0.5 - 30.0:
				return {"do": "confirm"}
	return {"do": "axis", "v": Vector2(1, 0)}


func bot_apply(w: Dictionary) -> void:
	# Un geste par image : le saut garde l'élan de la course (comme le stick relâché un instant).
	var act: String = String(w.get("do", ""))
	if act == "axis":
		_bot_axis = (w.get("v", Vector2.ZERO) as Vector2).x
	_bot_jump = act == "confirm"


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	var c: float = _cam
	# Voûtes de briques, casiers à bouteilles en parallaxe, torches.
	draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color("1a0f0c"))
	var bw: float = 120.0
	var row: int = 0
	var yb: float = 120.0
	while yb < FLOOR_Y:
		var off: float = fmod(-c * 0.4 + (60.0 if row % 2 == 1 else 0.0), bw)
		var xb: float = -size.x + off
		while xb < size.x * 2.0:
			draw_rect(Rect2(xb + 2, yb + 2, bw - 4, 56), Color("2b1712"))
			xb += bw
		yb += 60.0
		row += 1
	for k: int in 12:
		var rx: float = fmod(float(k) * 520.0 - c * 0.6, 520.0 * 6.0) - 520.0
		draw_rect(Rect2(rx, 360, 220, 330), Color("140a07"))
		for b: int in 12:
			var bc: Vector2 = Vector2(rx + 30.0 + float(b % 4) * 52.0, 400.0 + floorf(float(b) / 4.0) * 100.0)
			draw_circle(bc, 16.0, Color("1d4a2a") if (b + k) % 3 else Color("4a1220"))
	for k2: int in 8:
		var tx: float = fmod(float(k2) * 640.0 - c, 640.0 * 4.0) - 320.0
		draw_rect(Rect2(tx - 5, 250, 10, 50), Palette.BRONZE)
		var fl: float = 1.0 + 0.2 * sin(t * 13.0 + k2)
		draw_circle(Vector2(tx, 240), 14.0 * fl, Color(1.0, 0.6, 0.2, 0.85))
		draw_circle(Vector2(tx, 240), 60.0 * fl, Color(1.0, 0.5, 0.15, 0.08))
	# Sol, fosses, câbles.
	draw_rect(Rect2(-size.x, FLOOR_Y, size.x * 3.0, size.y - FLOOR_Y), Color("3a2418"))
	draw_rect(Rect2(-size.x, FLOOR_Y, size.x * 3.0, 8), Color("6b4a2a"))
	for k3: int in _segs.size():
		var s: Dictionary = _segs[k3]
		var sx: float = float(s["x"]) - c
		if sx < -600.0 or sx > size.x + 600.0:
			continue
		match String(s["kind"]):
			"pit", "rope":
				var w: float = float(s["w"])
				draw_rect(Rect2(sx - w * 0.5, FLOOR_Y, w, size.y - FLOOR_Y), Color("050302"))
				for sp: int in int(w / 40.0):
					var px: float = sx - w * 0.5 + 20.0 + float(sp) * 40.0
					var spike: PackedVector2Array = PackedVector2Array([Vector2(px - 14, size.y), Vector2(px, size.y - 50), Vector2(px + 14, size.y)])
					draw_colored_polygon(spike, Color("4a4a52"))
				if String(s["kind"]) == "rope":
					var pv: Vector2 = Vector2(sx, FLOOR_Y - ROPE_PIVOT_H)
					var e: Vector2 = _rope_end(k3) - Vector2(c, 0)
					draw_circle(pv, 30.0, Palette.GOLD_DARK)
					draw_line(pv, e, Palette.GOLD, 4.0)
					draw_circle(e, 10.0, Palette.GOLD_LIGHT)
			"barrel":
				var b: Vector2 = Vector2(float(s["bx"]) - c, FLOOR_Y - BARREL_R)
				draw_circle(b, BARREL_R, Color("7a4a24"))
				var a: float = -float(s["bx"]) / BARREL_R
				draw_line(b + Vector2.from_angle(a) * BARREL_R, b - Vector2.from_angle(a) * BARREL_R, Color("3a2210"), 5.0)
				draw_arc(b, BARREL_R - 6.0, 0, TAU, 20, Color("c0c0c8"), 3.0)
			"rat":
				var r: Vector2 = Vector2(float(s["bx"]) - c, FLOOR_Y - 14.0)
				draw_rect(Rect2(r - Vector2(RAT_W * 0.5, 12), Vector2(RAT_W, 24)), Color("6a6a70"))
				draw_circle(r + Vector2(RAT_W * 0.5, -6), 9.0, Color("7a7a80"))
				draw_circle(r + Vector2(RAT_W * 0.5 + 3, -9), 2.5, Palette.MULT_RED)
				draw_line(r - Vector2(RAT_W * 0.5, 0), r - Vector2(RAT_W * 0.5 + 30, -8), Color("c08080"), 2.0)
		if String(s["kind"]) in ["treasure", "pit", "barrel"] and not bool(s["taken"]):
			var tp: Vector2 = _treasure_pos(s) - Vector2(c, 0)
			tp.y += sin(t * 3.0 + k3) * 6.0
			draw_circle(tp, 22.0, Palette.GOLD)
			draw_arc(tp, 16.0, 0, TAU, 16, Palette.IVORY, 3.0)
	# Porte de sortie (la bouteille du patron).
	var gx: float = _goal_x - c
	draw_rect(Rect2(gx, FLOOR_Y - 220, 140, 220), Color("2a1a10"))
	draw_rect(Rect2(gx, FLOOR_Y - 220, 140, 220), Palette.GOLD, false, 4.0)
	draw_circle(Vector2(gx + 70, FLOOR_Y - 120), 30.0, Color(Palette.GOLD_LIGHT, 0.4 + 0.3 * sin(t * 4.0)))
	# Le groom.
	var col: Color = Palette.MULT_RED if _stun > 0.0 and fmod(t * 10.0, 1.0) < 0.5 else Palette.ROULETTE_RED
	var cell: float = BODY.x / 8.0 * 1.4
	var at: Vector2 = Vector2(_x - c - 4.0 * cell, _y - 10.0 * cell + (sin(_run_anim) * 3.0 if _ground else 0.0))
	ArcadeKit.sprite(self, at, GROOM, cell, col)
	draw_rect(Rect2(at + Vector2(2.0 * cell, 0), Vector2(4.0 * cell, cell)), Palette.GOLD)
	# Bandeau : progression et trésors.
	var prog: float = clampf(_x / _goal_x, 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 400, 80, 800, 14), Color(Palette.INK, 0.8))
	draw_rect(Rect2(size.x * 0.5 - 400, 80, 800 * prog, 14), Palette.GOLD)
	var left: float = clampf(1.0 - t / _dur(), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 400, 100, 800 * left, 6), Palette.CYAN)
	text(Vector2(size.x * 0.5, 140.0), tr("TRIAL_CAVE_STATUS") % [_treasures, _treasure_total], UiKit.SIZE_BODY, Palette.IVORY)
