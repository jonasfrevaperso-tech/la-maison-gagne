class_name TrialSimon
extends ThrowTrial
## LE JUKE-BOX (écran dédié) : le vieux juke-box du Grand Zéro joue une mélodie de lumières.
## La regarder, puis la rejouer touche par touche. Trois mélodies, de plus en plus longues.
## Note = part de la mélodie rejouée sans faute, mélodie par mélodie.

enum Phase { LISTEN, PLAY, RESULT }

const PITCHES: Array[float] = [1.0, 1.26, 1.5, 1.68]
const COLORS: Array[Color] = [Palette.ROULETTE_RED, Palette.EMERALD, Palette.GOLD, Palette.CYAN]
const PAD: Vector2 = Vector2(230.0, 150.0)

var _phase: Phase = Phase.LISTEN
var _round: int = 0
var _seq: Array[int] = []
var _pos: int = 0
var _phase_t: float = 0.0
var _lit: int = -1
var _lit_t: float = 0.0
var _scores: Array[float] = []
var _input_t: float = 0.0


func begin() -> void:
	_new_round()


func _keys() -> int:
	return 2 if mouse else 4


func _new_round() -> void:
	var n: int = int(pk("lengths", _round))
	_seq.clear()
	for k: int in n:
		_seq.append(rng.randi_range(0, _keys() - 1))
	_pos = 0
	_phase = Phase.LISTEN
	_phase_t = -0.6


func _note_time() -> float:
	return p("note_seconds") * slow


## Centre de la touche k : losange de quatre touches (gauche, haut, droite, bas), ou deux.
func _pad_center(k: int) -> Vector2:
	var c: Vector2 = Vector2(size.x * 0.5, 600.0)
	if mouse:
		return c + Vector2(-170.0 if k == 0 else 170.0, 0.0)
	return c + [Vector2(-260, 0), Vector2(0, -170), Vector2(260, 0), Vector2(0, 170)][k]


func _light(k: int) -> void:
	_lit = k
	_lit_t = 0.32
	AudioBus.play("chime", PITCHES[k], -2.0)


func handle(event: InputEvent) -> bool:
	if _phase != Phase.PLAY:
		return sym_pressed(event) >= 0 or confirm_pressed(event)
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mouse:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for k: int in _keys():
				if mb.position.distance_to(_pad_center(k)) < PAD.x * 0.6:
					press(k)
		return true
	var k2: int = sym_pressed(event)
	if k2 >= 0 and k2 < _keys():
		press(k2)
		return true
	return false


func press(k: int) -> void:
	if _phase != Phase.PLAY:
		return
	_light(k)
	_input_t = 0.0
	if _seq[_pos] == k:
		_pos += 1
		if _pos >= _seq.size():
			_end_round(1.0)
	else:
		AudioBus.play("error", 1.0, -4.0)
		_end_round(float(_pos) / float(_seq.size()))


func _end_round(sc: float) -> void:
	_scores.append(sc)
	_phase = Phase.RESULT
	_phase_t = 0.0
	pop(Vector2(size.x * 0.5, 360.0), sc)
	if sc >= 1.0:
		AudioBus.play("jingle", 1.0, -4.0)


func tick(dt: float) -> void:
	_phase_t += dt
	_lit_t -= dt
	if _lit_t <= 0.0:
		_lit = -1
	match _phase:
		Phase.LISTEN:
			var idx: int = int(floor(_phase_t / _note_time()))
			if _phase_t >= 0.0 and idx < _seq.size() and _pos == idx:
				_light(_seq[idx])
				_pos += 1
			if _phase_t > _note_time() * float(_seq.size()) + 0.3:
				_phase = Phase.PLAY
				_pos = 0
				_input_t = 0.0
		Phase.PLAY:
			_input_t += dt
			if _input_t > p("input_seconds") * slow:
				AudioBus.play("lose_soft", 1.0, -4.0)
				_end_round(float(_pos) / float(_seq.size()))
		Phase.RESULT:
			if _phase_t > 1.0:
				_round += 1
				if _round >= pi("rounds"):
					finish(mean(_scores))
				else:
					_new_round()


func bot_wants() -> Dictionary:
	if _phase != Phase.PLAY or _input_t < 0.15:
		return {"do": ""}
	return {"do": "sym", "symbol": _seq[_pos]}


func bot_apply(want: Dictionary) -> void:
	if String(want.get("do", "")) == "sym":
		press(int(want["symbol"]))


func paint() -> void:
	backdrop()
	# Juke-box : arche lumineuse, grille du haut-parleur, disques.
	var c: Vector2 = Vector2(size.x * 0.5, 600.0)
	var arch: Rect2 = Rect2(c.x - 520, 170, 1040, 860)
	draw_rect(arch, Color(0.22, 0.08, 0.12))
	for k: int in 14:
		var col: Color = [Palette.MAGENTA, Palette.GOLD_LIGHT, Palette.CYAN][(k + int(t * 6.0)) % 3]
		draw_circle(Vector2(arch.position.x + 40 + k * 74.0, arch.position.y + 30), 10.0, Color(col, 0.8))
	draw_rect(arch, Palette.GOLD, false, 6.0)
	for k2: int in _keys():
		var pc: Vector2 = _pad_center(k2)
		var r: Rect2 = Rect2(pc - PAD * 0.5, PAD)
		var on: bool = _lit == k2
		draw_rect(r.grow(8), Color(COLORS[k2], 0.35 if on else 0.08))
		draw_rect(r, COLORS[k2] if on else COLORS[k2].darkened(0.6))
		draw_rect(r, Palette.GOLD_DARK, false, 3.0)
		var glyph: String = ["←", "↑", "→", "↓"][k2] if not mouse else ""
		if glyph != "":
			text(pc, glyph, UiKit.SIZE_H1, Palette.IVORY)
	var msg: String = tr("TRIAL_SIMON_LISTEN") if _phase == Phase.LISTEN else (tr("TRIAL_SIMON_PLAY") % [_pos, _seq.size()])
	text(Vector2(size.x * 0.5, 250.0), msg, UiKit.SIZE_H2, Palette.GOLD_LIGHT)
	pips(Vector2(size.x * 0.5, 300.0), _scores, pi("rounds"))
	if _phase == Phase.PLAY:
		var left: float = clampf(1.0 - _input_t / (p("input_seconds") * slow), 0.0, 1.0)
		draw_rect(Rect2(size.x * 0.5 - 200, 960, 400 * left, 10), Palette.GOLD if left > 0.3 else Palette.DANGER)
