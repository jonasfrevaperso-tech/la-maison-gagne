class_name TrialHighLow
extends ThrowTrial
## PLUS HAUT, PLUS BAS : Odile a laissé ses cartes. Une carte est retournée (As à Roi) : la
## suivante sera-t-elle plus haute ou plus basse ? On juge la DÉCISION, pas la chance : choisir
## le pari le plus probable compte comme réussi, même si la carte suivante déjoue les calculs.
## Le temps de réflexion se resserre à chaque carte. Note = part des bons choix.

const RANKS: Array[String] = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R"]
const CARD: Vector2 = Vector2(130.0, 180.0)

var _cards: Array[int] = []
var _i: int = 0
var _decide_t: float = 0.0
var _scores: Array[float] = []
var _reveal: float = -1.0
var _last_guess: int = 0


func begin() -> void:
	for k: int in pi("cards") + 1:
		_cards.append(rng.randi_range(1, 13))
	AudioBus.play("card_flip", 1.0, -4.0)


func _limit() -> float:
	return lerpf(p("decide_start"), p("decide_end"), float(_i) / maxf(float(pi("cards") - 1), 1.0)) * slow


func handle(event: InputEvent) -> bool:
	if _reveal >= 0.0:
		return dir_pressed(event) != Vector2i.ZERO or sym_pressed(event) >= 0
	var d: Vector2i = dir_pressed(event)
	if d.y != 0:
		guess(-d.y)
		return true
	if mouse:
		var k: int = sym_pressed(event)
		if k >= 0:
			guess(1 if k == 0 else -1)
			return true
	return false


## +1 : plus haut, -1 : plus bas. Bon choix = le plus probable (égalité : les deux).
func guess(dir: int) -> void:
	if _reveal >= 0.0 or _i >= pi("cards"):
		return
	var cur: int = _cards[_i]
	var higher: int = 13 - cur
	var lower: int = cur - 1
	var good: bool = (dir > 0 and higher >= lower) or (dir < 0 and lower >= higher)
	_last_guess = dir
	_finish_card(1.0 if good else 0.0)


func _finish_card(sc: float) -> void:
	_scores.append(sc)
	_reveal = 0.0
	AudioBus.play("card_flip", 1.1, -2.0)
	var nxt: int = _cards[_i + 1]
	var lucky: bool = (_last_guess > 0 and nxt > _cards[_i]) or (_last_guess < 0 and nxt < _cards[_i])
	AudioBus.play("chips_win" if lucky else "chip_lose", 1.0, -6.0)
	pop(Vector2(size.x * 0.5, 60.0), sc, "TRIAL_HIGHLOW_GOOD" if sc >= 1.0 else "TRIAL_HIGHLOW_BAD")


func tick(dt: float) -> void:
	if _reveal >= 0.0:
		_reveal += dt
		if _reveal > p("reveal_seconds") * slow:
			_reveal = -1.0
			_i += 1
			_decide_t = 0.0
			if _i >= pi("cards"):
				finish(mean(_scores))
		return
	_decide_t += dt
	if _decide_t > _limit():
		_last_guess = 0
		_finish_card(0.0)


func bot_wants() -> Dictionary:
	if _reveal >= 0.0 or _i >= pi("cards") or _decide_t < 0.2:
		return {"do": ""}
	var cur: int = _cards[_i]
	return {"do": "dir", "dir": Vector2i(0, -1 if 13 - cur >= cur - 1 else 1)}


func bot_apply(want: Dictionary) -> void:
	if String(want.get("do", "")) == "dir":
		guess(-(want["dir"] as Vector2i).y)


func _draw_card(at: Vector2, rank: int, face: bool) -> void:
	var r: Rect2 = Rect2(at - CARD * 0.5, CARD)
	draw_rect(r.grow(3), Color(0, 0, 0, 0.4))
	if not face:
		draw_rect(r, Palette.ROULETTE_RED.darkened(0.3))
		draw_rect(r.grow(-8), Palette.GOLD_DARK, false, 2.0)
		return
	draw_rect(r, Palette.IVORY)
	var red: bool = rank % 2 == 0
	text(r.get_center(), RANKS[rank - 1], UiKit.SIZE_H1, Palette.ROULETTE_RED if red else Palette.INK, "display", 0)
	text(r.position + Vector2(22, 24), RANKS[rank - 1], UiKit.SIZE_SMALL, Palette.ROULETTE_RED if red else Palette.INK, "display", 0)


func paint() -> void:
	var r: Rect2 = play_rect()
	var cx: float = r.get_center().x
	var cy: float = r.get_center().y + 10.0
	var idx: int = mini(_i, pi("cards") - 1)
	_draw_card(Vector2(cx - 110.0, cy), _cards[idx], true)
	_draw_card(Vector2(cx + 110.0, cy), _cards[idx + 1], _reveal >= 0.0)
	# Flèches de choix et compte à rebours.
	if _reveal < 0.0 and _i < pi("cards"):
		var left: float = clampf(1.0 - _decide_t / _limit(), 0.0, 1.0)
		draw_rect(Rect2(cx - 150, r.position.y + 30, 300 * left, 8), Palette.GOLD if left > 0.3 else Palette.DANGER)
		text(Vector2(cx + 330.0, cy - 50.0), tr("TRIAL_HIGHLOW_UP"), UiKit.SIZE_BODY, Palette.EMERALD)
		text(Vector2(cx + 330.0, cy + 50.0), tr("TRIAL_HIGHLOW_DOWN"), UiKit.SIZE_BODY, Palette.CYAN)
	pips(Vector2(cx - 330.0, cy), _scores, pi("cards"))
