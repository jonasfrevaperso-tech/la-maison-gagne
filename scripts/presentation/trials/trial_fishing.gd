class_name TrialFishing
extends ThrowTrial
## LA PÊCHE AU GROS (écran dédié) : la fontaine du hall et ses carpes dorées. Pour chaque
## poisson : LANCER (la jauge va et vient, valider quand elle touche les remous), FERRER (le
## bouchon plonge : valider vite), puis REMONTER (maintenir pour mouliner, relâcher pour donner
## du fil) en gardant la tension dans la zone verte pendant que la carpe tire par à-coups.
## Trop tendu, le fil casse ; trop mou, elle s'enfuit.
## Note = par poisson, lancer × poids + ferrage × poids + remontée (temps dans la zone, si
## remonté) × poids ; moyenne des poissons.

const POND: Rect2 = Rect2(260.0, 380.0, 1400.0, 520.0)
const ROD: Vector2 = Vector2(300.0, 960.0)
const GAUGE: Rect2 = Rect2(1720.0, 300.0, 40.0, 560.0)

var _fish: int = 0
var _phase: String = "cast"
var _gauge: float = 0.0
var _gauge_dir: float = 1.0
var _spot: float = 0.5
var _lure: float = 0.0
var _wait: float = 0.0
var _bite_t: float = 0.0
var _tension: float = 0.3
var _dist: float = 1.0
var _hold: bool = false
var _pull: float = 0.0
var _pull_t: float = 0.0
var _in_zone: float = 0.0
var _reel_t: float = 0.0
var _slack_t: float = 0.0
var _part: Dictionary = {}
var _scores: Array[float] = []
var _pause: float = 0.0
var _carps: Array[Dictionary] = []


func begin() -> void:
	for k: int in 6:
		var at: Vector2 = Vector2(rng.randf_range(POND.position.x + 80, POND.end.x - 80), rng.randf_range(POND.position.y + 60, POND.end.y - 60))
		_carps.append({"p": at,
			"a": rng.randf() * TAU, "s": rng.randf_range(40.0, 90.0)})
	_new_fish()


func _new_fish() -> void:
	_phase = "cast"
	_wait = 0.0
	_gauge = 0.0
	_gauge_dir = 1.0
	_spot = rng.randf_range(0.35, 0.9)
	_part = {}
	_tension = p("tension_start")
	_dist = 1.0
	_in_zone = 0.0
	_reel_t = 0.0
	_slack_t = 0.0
	_hold = false


func _spot_pos(v: float) -> Vector2:
	return Vector2(lerpf(POND.position.x + 120.0, POND.end.x - 80.0, v), POND.get_center().y + 40.0)


func handle(event: InputEvent) -> bool:
	if confirm_pressed(event):
		_press()
		_hold = true
		return true
	if confirm_released(event):
		_hold = false
		return true
	return false


func _press() -> void:
	match _phase:
		"cast":
			_lure = _gauge
			var err: float = absf(_gauge - _spot)
			_part["cast"] = clampf(1.0 - err / (p("cast_tolerance") * widen()), 0.0, 1.0)
			pop(_spot_pos(_lure) + Vector2(0, -60), float(_part["cast"]))
			_phase = "wait"
			_wait = rng.randf_range(p("bite_min"), p("bite_max")) * slow
			AudioBus.play("whoosh", 0.9, -4.0)
		"wait":
			# Ferrer avant la touche : le poisson se méfie, on attend un peu plus.
			_wait += p("early_penalty")
			AudioBus.play("sticky", 1.0, -10.0)
		"bite":
			var rt: float = _bite_t
			_part["bite"] = clampf(1.0 - rt / (p("react_window") * widen()), 0.0, 1.0)
			pop(_spot_pos(_lure) + Vector2(0, -60), float(_part["bite"]), "TRIAL_FISHING_HOOKED")
			AudioBus.play("decor_pluck", 1.2, -4.0)
			_phase = "reel"


func tick(dt: float) -> void:
	for c: Dictionary in _carps:
		c["a"] = float(c["a"]) + rng.randf_range(-1.0, 1.0) * dt
		var pos: Vector2 = (c["p"] as Vector2) + Vector2.from_angle(float(c["a"])) * float(c["s"]) * dt
		if not POND.grow(-50.0).has_point(pos):
			c["a"] = float(c["a"]) + PI
		else:
			c["p"] = pos
	if _pause > 0.0:
		_pause -= dt
		if _pause <= 0.0:
			_fish += 1
			if _fish >= pi("fish"):
				finish(ThrowTrial.mean(_scores))
			else:
				_new_fish()
		return
	match _phase:
		"cast":
			_wait += dt
			if _wait >= p("cast_timeout") * slow:
				_press()  # la ligne part toute seule
				return
			_gauge += _gauge_dir * dt / (p("cast_seconds") * slow)
			if _gauge >= 1.0 or _gauge <= 0.0:
				_gauge = clampf(_gauge, 0.0, 1.0)
				_gauge_dir = -_gauge_dir
		"wait":
			_wait -= dt
			if _wait <= 0.0:
				_phase = "bite"
				_bite_t = 0.0
				AudioBus.play("decor_puff", 1.3, -4.0)
		"bite":
			_bite_t += dt
			if _bite_t >= p("react_window") * widen():
				_part["bite"] = 0.0
				pop(_spot_pos(_lure) + Vector2(0, -60), 0.0, "TRIAL_FISHING_MISSED")
				_land(false)
		"reel":
			_reel(dt)


## Remontée : maintenir tend le fil et rapproche la carpe ; elle tire par à-coups.
func _reel(dt: float) -> void:
	_reel_t += dt
	_pull_t -= dt
	if _pull_t <= 0.0:
		_pull_t = rng.randf_range(p("pull_every_min"), p("pull_every_max")) * slow
		_pull = p("pull_strength") * rng.randf_range(0.6, 1.0)
		AudioBus.play("decor_creak", 1.4, -8.0)
	_pull = maxf(0.0, _pull - p("pull_decay") * dt)
	var rate: float = p("reel_tension") if _hold else -p("slack_rate")
	_tension = clampf(_tension + (rate + _pull) * dt / slow, 0.0, 1.0)
	if _hold:
		_dist -= p("reel_speed") * dt * (1.0 - _pull / maxf(p("pull_strength"), 0.01)) / slow
	else:
		_dist = minf(1.0, _dist + p("run_speed") * _pull * dt)
	var lo: float = p("zone_low")
	var hi: float = p("zone_high")
	if _tension >= lo and _tension <= hi:
		_in_zone += dt
	if _tension >= 1.0:
		pop(_spot_pos(_lure * _dist) + Vector2(0, -60), 0.0, "TRIAL_FISHING_SNAP")
		AudioBus.play("crack", 1.2, -4.0)
		_land(false)
	elif _tension <= 0.0:
		_slack_t += dt
		if _slack_t >= p("slack_escape") * slow:
			pop(_spot_pos(_lure * _dist) + Vector2(0, -60), 0.0, "TRIAL_FISHING_ESCAPED")
			_land(false)
	else:
		_slack_t = 0.0
	if _dist <= 0.0:
		pop(ROD + Vector2(200, -200), 1.0, "TRIAL_FISHING_LANDED")
		AudioBus.play("coins", 1.1, -4.0)
		_land(true)


func _land(caught: bool) -> void:
	var zone: float = _in_zone / maxf(_reel_t, 0.01) if caught else 0.0
	var sc: float = float(_part.get("cast", 0.0)) * p("w_cast") + float(_part.get("bite", 0.0)) * p("w_bite")
	sc += zone * (1.0 - p("w_cast") - p("w_bite"))
	_scores.append(clampf(sc, 0.0, 1.0))
	_phase = "done"
	_hold = false
	_pause = p("pause_seconds")


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	match _phase:
		"cast":
			var nxt: float = _gauge + _gauge_dir / 60.0 / (p("cast_seconds") * slow)
			if (_gauge - _spot) * (nxt - _spot) <= 0.0:
				return {"do": "confirm"}
		"bite":
			if _bite_t > p("bot_react"):
				return {"do": "confirm"}
		"reel":
			var mid: float = (p("zone_low") + p("zone_high")) * 0.5
			return {"do": "hold"} if _tension < mid else {"do": "release"}
	return {"do": ""}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"confirm":
			_press()
		"hold":
			_hold = true
		"release":
			_hold = false


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# Hall de marbre, fontaine ronde, statue dorée, carpes, bouchon et fil.
	draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color("1c1820"))
	for k: int in 20:
		var x: float = -size.x * 0.5 + float(k) * 180.0
		draw_rect(Rect2(x, 0, 90, POND.position.y - 40), Color("26212c"))
	draw_rect(POND.grow(36.0), Color("cfc6b8"))
	draw_rect(POND.grow(22.0), Color("9a9080"))
	draw_rect(POND, Color("0f3b4a"))
	for k2: int in 8:
		var y: float = POND.position.y + 30.0 + float(k2) * 60.0
		var off: float = sin(t * 1.4 + k2) * 30.0
		draw_line(Vector2(POND.position.x + 40 + off, y), Vector2(POND.end.x - 40 + off, y), Color(Palette.CYAN, 0.06), 2.0)
	var statue: Vector2 = Vector2(POND.end.x - 220.0, POND.position.y - 10.0)
	draw_rect(Rect2(statue - Vector2(40, 160), Vector2(80, 160)), Palette.GOLD_DARK)
	draw_circle(statue - Vector2(0, 190), 34.0, Palette.GOLD)
	for c: Dictionary in _carps:
		var cp: Vector2 = c["p"]
		var dir: Vector2 = Vector2.from_angle(float(c["a"]))
		var side: Vector2 = dir.orthogonal() * 12.0
		draw_colored_polygon(PackedVector2Array([cp + dir * 34.0, cp + side, cp - dir * 24.0, cp - side]), Color(Palette.GOLD, 0.55))
		draw_colored_polygon(PackedVector2Array([cp - dir * 22.0, cp - dir * 40.0 + side, cp - dir * 40.0 - side]), Color(Palette.GOLD, 0.45))
	# Remous visés.
	var sp: Vector2 = _spot_pos(_spot)
	if _phase == "cast":
		for r: int in 3:
			var rr: float = 20.0 + fmod(t * 40.0 + float(r) * 25.0, 75.0)
			draw_arc(sp, rr, 0, TAU, 32, Color(Palette.IVORY, 0.5 * (1.0 - rr / 95.0)), 2.0)
	# Canne, fil, bouchon.
	var tip: Vector2 = ROD + Vector2(260, -360)
	draw_line(ROD, tip, Color("7a4a24"), 8.0)
	var bob: Vector2 = _spot_pos(_lure * (_dist if _phase == "reel" else 1.0))
	if _phase == "cast":
		bob = tip + Vector2(0, 120)
	if _phase == "bite":
		bob.y += 14.0 + sin(t * 40.0) * 6.0
	draw_line(tip, bob, Color(Palette.IVORY, 0.7), 2.0)
	draw_circle(bob, 12.0, Palette.ROULETTE_RED)
	draw_circle(bob - Vector2(0, 8), 7.0, Palette.IVORY)
	if _phase == "bite":
		text(bob + Vector2(0, -60), "!", UiKit.SIZE_H1, Palette.GOLD_LIGHT)
	# Jauges : lancer, puis tension.
	draw_rect(GAUGE, Color(Palette.INK, 0.9))
	if _phase == "cast":
		var sy: float = GAUGE.end.y - GAUGE.size.y * _spot
		draw_rect(Rect2(GAUGE.position.x - 6, sy - p("cast_tolerance") * GAUGE.size.y * widen() * 0.5, GAUGE.size.x + 12,
			p("cast_tolerance") * GAUGE.size.y * widen()), Color(Palette.GOLD, 0.4))
		draw_rect(Rect2(GAUGE.position.x, GAUGE.end.y - GAUGE.size.y * _gauge - 4, GAUGE.size.x, 8), Palette.IVORY)
	elif _phase == "reel":
		var lo_y: float = GAUGE.end.y - GAUGE.size.y * p("zone_high")
		var zone_h: float = GAUGE.size.y * (p("zone_high") - p("zone_low"))
		draw_rect(Rect2(GAUGE.position.x, lo_y, GAUGE.size.x, zone_h), Color(Palette.EMERALD, 0.35))
		var col: Color = Palette.EMERALD if _tension >= p("zone_low") and _tension <= p("zone_high") else Palette.MULT_RED
		draw_rect(Rect2(GAUGE.position.x, GAUGE.end.y - GAUGE.size.y * _tension, GAUGE.size.x, GAUGE.size.y * _tension), Color(col, 0.8))
		text(Vector2(GAUGE.get_center().x, GAUGE.position.y - 30), tr("TRIAL_FISHING_TENSION"), UiKit.SIZE_SMALL, Palette.IVORY)
	draw_rect(GAUGE, Palette.GOLD, false, 2.0)
	var key: String = {"cast": "TRIAL_FISHING_CAST", "wait": "TRIAL_FISHING_WAIT", "bite": "TRIAL_FISHING_BITE",
		"reel": "TRIAL_FISHING_REEL"}.get(_phase, "")
	if key != "":
		text(Vector2(size.x * 0.5, 160.0), tr(key), UiKit.SIZE_H2, Palette.GOLD_LIGHT)
	pips(Vector2(size.x * 0.5, 100.0), _scores, pi("fish"))
