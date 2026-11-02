class_name TrialCharge
extends ThrowTrial
## ÉLAN : maintenir pour charger une jauge qui accélère (puis redescend si on tarde), relâcher
## dans la zone dorée, dont la position change à chaque fois. Deux élans d'affilée : le second
## a une zone plus étroite. Notation : ThrowSkill.power_score.

const TICKS: int = 20
const TICK_EVERY: float = 0.07
const NEEDLE_W: float = 6.0
const GAUGE_H: float = 44.0

var _half: float = 0.1
var _center: float = 0.7
var _level: float = 0.0
var _stopped_at: float = -1.0
var _charging: bool = false
var _tick_t: float = 0.0
var _round: int = 0
var _scores: Array[float] = []
var _rest: float = 0.0


func begin() -> void:
	_new_round()


func _new_round() -> void:
	_half = ThrowSkill.sweet_half(precision, assist) * (1.0 if _round == 0 else p("second_narrow"))
	_center = ThrowSkill.sweet_center(rng.randf())
	_level = 0.0
	_stopped_at = -1.0
	_charging = false
	t = 0.0


func handle(event: InputEvent) -> bool:
	if _rest > 0.0:
		return confirm_pressed(event)
	if not _charging and confirm_pressed(event):
		press()
		return true
	if _charging and confirm_released(event):
		release()
		return true
	return false


func press() -> void:
	if _charging or _rest > 0.0:
		return
	_charging = true
	t = 0.0
	AudioBus.play("cloth", 1.2, -4.0)


func release() -> void:
	if not _charging:
		return
	_charging = false
	_stopped_at = _level
	var sc: float = ThrowSkill.power_score(_level, _half, _center)
	_scores.append(sc)
	flash = 1.0
	pop(Vector2(_gauge_rect().position.x + _gauge_rect().size.x * _level, _gauge_rect().position.y - 30.0), sc)
	AudioBus.play("whoosh", 0.8 + _level * 0.6)
	AudioBus.play("chime" if sc >= 0.9 else ("chip_place" if sc >= 0.45 else "lose_soft"), 0.9 + sc * 0.4, -6.0)
	_rest = p("rest_seconds")


func tick(dt: float) -> void:
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_round += 1
			if _round >= pi("rounds"):
				finish(mean(_scores))
			else:
				_new_round()
		return
	if not _charging:
		if t >= Balance.f("throw_game.charge_wait_seconds"):
			press()  # sans réponse : l'élan se prend tout seul…
		return
	_level = ThrowSkill.charge_level(t, slow)
	_tick_t -= dt
	if _tick_t <= 0.0:
		_tick_t = TICK_EVERY
		AudioBus.play("tick", 0.7 + _level * 1.1, -10.0)
	if t >= Balance.f("throw_game.charge_seconds") * slow * 4.0:
		release()  # … et se relâche après deux allers-retours.


func bot_wants() -> Dictionary:
	if _rest > 0.0:
		return {"do": ""}
	if not _charging:
		return {"do": "hold"}
	if absf(_level - _center) < _half * 0.25 and t < Balance.f("throw_game.charge_seconds") * slow:
		return {"do": "release"}
	return {"do": ""}


func bot_apply(want: Dictionary) -> void:
	match String(want.get("do", "")):
		"hold":
			press()
		"release":
			release()


func _gauge_rect() -> Rect2:
	var r: Rect2 = play_rect()
	return Rect2(Vector2(r.position.x + 30.0, r.get_center().y - GAUGE_H * 0.5 + 18.0), Vector2(r.size.x - 60.0, GAUGE_H))


func paint() -> void:
	var pr: Rect2 = play_rect()
	var round_txt: String = tr("TRIAL_CHARGE_ROUND") % [_round + 1, pi("rounds")]
	text(Vector2(pr.get_center().x, pr.position.y + 34.0), round_txt, UiKit.SIZE_BODY, Palette.IVORY)
	pips(Vector2(pr.get_center().x, pr.position.y + 66.0), _scores, pi("rounds"))
	var r: Rect2 = _gauge_rect()
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
		draw_line(Vector2(x, r.end.y - 8), Vector2(x, r.end.y), Palette.GOLD_DARK, 1.0)
	var last: float = _scores[-1] if not _scores.is_empty() and _stopped_at >= 0.0 else 0.0
	var ncol: Color = Palette.CYAN if _stopped_at < 0.0 else (Palette.EMERALD if last >= 0.7 else Palette.MAGENTA)
	var nx: float = r.position.x + r.size.x * lvl
	draw_rect(Rect2(nx - NEEDLE_W * 0.5, r.position.y - 10, NEEDLE_W, r.size.y + 20), ncol)
	if flash > 0.0:
		draw_rect(r.grow(8.0 + 10.0 * (1.0 - flash)), Color(ncol, flash * 0.8), false, 3.0)
	if not _charging and _rest <= 0.0:
		var pulse: float = 0.6 + 0.4 * sin(t * 6.0)
		text(r.get_center(), tr("TRIAL_CHARGE_READY"), UiKit.SIZE_BODY, Color(Palette.IVORY, pulse))
