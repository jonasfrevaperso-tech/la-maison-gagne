class_name TrialShaker
extends ThrowTrial
## SHAKER : le barman est parti en 1987, c'est toi qui secoues. Alterner gauche / droite pour
## faire monter la mousse et la garder dans la bande dorée, qui se promène. Trop mou, ça
## retombe ; trop fort, ça déborde. Note = part du temps passé dans la bande.

var _level: float = 0.0
var _last_side: int = -1
var _inside: float = 0.0
var _phase: float = 0.0
var _shake: float = 0.0
var _end_t: float = -1.0
var _ice_t: float = 0.0


func begin() -> void:
	_phase = rng.randf() * TAU
	_level = 0.15


func _band_center() -> float:
	return 0.5 + 0.22 * sin(t * p("band_speed") / slow * TAU + _phase)


func _band() -> float:
	return p("band") * widen() * 0.5


func handle(event: InputEvent) -> bool:
	var k: int = sym_pressed(event)
	if k < 0:
		return false
	if k == 0:
		shake(0)
	elif k == 2 or (mouse and k == 1):
		shake(1)
	return true


func shake(side: int) -> void:
	if _end_t >= 0.0:
		return
	if side == _last_side:
		AudioBus.play("sticky", 1.3, -10.0)
		return
	_last_side = side
	_level = minf(_level + p("pump"), 1.08)
	_shake = 1.0
	if _ice_t <= 0.0:
		AudioBus.play("decor_ice", 0.9 + _level * 0.4, -6.0)
		_ice_t = 0.09


func tick(dt: float) -> void:
	_shake = maxf(_shake - dt * 6.0, 0.0)
	_ice_t -= dt
	if _end_t >= 0.0:
		_end_t += dt
		if _end_t > 0.7:
			finish(_inside / maxf(p("duration") * slow - p("grace"), 0.1))
		return
	_level = maxf(_level - p("decay") * dt, 0.0)
	if absf(_level - _band_center()) <= _band():
		_inside += dt
	if _level > 1.0:
		_level = 0.8
		AudioBus.play("decor_puff", 1.4, -4.0)
		pop(Vector2(size.x * 0.3, 40.0), 0.0, "TRIAL_SHAKER_SPILL")
	if t >= p("duration") * slow:
		_end_t = 0.0
		AudioBus.play("decor_glass", 1.0)


func bot_wants() -> Dictionary:
	if _end_t >= 0.0 or _level >= _band_center() - p("pump") * 0.5:
		return {"do": ""}
	var side: int = 1 - maxi(_last_side, 0) if _last_side >= 0 else 0
	return {"do": "sym", "symbol": 0 if side == 0 else (1 if mouse else 2)}


func bot_apply(w: Dictionary) -> void:
	if String(w.get("do", "")) == "sym":
		var k: int = int(w["symbol"])
		shake(0 if k == 0 else 1)


func paint() -> void:
	var r: Rect2 = play_rect()
	# Shaker qui tremble.
	var c: Vector2 = Vector2(r.position.x + 150.0, r.get_center().y + 8.0)
	var jig: Vector2 = Vector2(sin(t * 70.0) * 10.0, cos(t * 55.0) * 6.0) * _shake
	var rot: float = (0.25 if _last_side == 0 else -0.25) * _shake
	draw_set_transform(c + jig, rot)
	var steel: Color = Color(0.72, 0.74, 0.78)
	draw_colored_polygon(PackedVector2Array([Vector2(-46, 90), Vector2(46, 90), Vector2(36, -40), Vector2(-36, -40)]), steel)
	draw_rect(Rect2(-40, -60, 80, 22), steel.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(-30, -60), Vector2(30, -60), Vector2(14, -100), Vector2(-14, -100)]), steel)
	draw_rect(Rect2(-16, -112, 32, 14), steel.darkened(0.25))
	draw_rect(Rect2(-30, -30, 10, 110), Color(1, 1, 1, 0.35))
	draw_set_transform(Vector2.ZERO)
	# Jauge de mousse et bande dorée.
	var g: Rect2 = Rect2(Vector2(r.position.x + 330.0, r.position.y + 30.0), Vector2(70.0, r.size.y - 50.0))
	draw_rect(g, Palette.VELVET_DEEP)
	var bc: float = _band_center()
	var b0: float = clampf(bc - _band(), 0.0, 1.0)
	var b1: float = clampf(bc + _band(), 0.0, 1.0)
	draw_rect(Rect2(g.position.x, g.end.y - g.size.y * b1, g.size.x, g.size.y * (b1 - b0)), Color(Palette.GOLD, 0.5))
	var lv: float = clampf(_level, 0.0, 1.0)
	var inside: bool = absf(_level - bc) <= _band()
	var foam: Color = Color(Palette.IVORY if inside else Palette.CYAN, 0.85)
	draw_rect(Rect2(g.position.x + 8, g.end.y - g.size.y * lv, g.size.x - 16, g.size.y * lv), foam)
	for k: int in 4:
		draw_circle(Vector2(g.position.x + 14 + k * 14, g.end.y - g.size.y * lv), 8.0 + 2.0 * sin(t * 9.0 + k), Palette.IVORY)
	draw_rect(g, Palette.GOLD, false, 2.0)
	# Chronomètre et part du temps dans la bande.
	var dur: float = p("duration") * slow
	var tl: float = clampf(1.0 - t / dur, 0.0, 1.0)
	var bar: Rect2 = Rect2(Vector2(r.position.x + 450.0, r.position.y + 70.0), Vector2(r.size.x - 490.0, 12.0))
	draw_rect(bar, Palette.VELVET_DEEP)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * tl, bar.size.y)), Palette.GOLD)
	var ratio: float = minf(_inside / maxf(dur - p("grace"), 0.1), 1.0)
	var band_txt: String = tr("TRIAL_SHAKER_IN_BAND") % roundi(ratio * 100.0)
	text(Vector2(bar.get_center().x, bar.position.y + 60.0), band_txt, UiKit.SIZE_BODY, Palette.EMERALD if inside else Palette.IVORY)
	text(Vector2(bar.get_center().x, bar.position.y + 110.0), tr("TRIAL_SHAKER_TIP"), UiKit.SIZE_SMALL, Palette.SMOKE)
