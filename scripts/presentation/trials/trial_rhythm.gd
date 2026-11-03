class_name TrialRhythm
extends ThrowTrial
## EFFET : un vrai petit jeu de rythme. Un morceau (jazz, funk ou mambo) démarre après une
## mesure de décompte ; les notes glissent sur quatre couloirs vers la ligne et tombent sur la
## grille du morceau, une à la fois (jamais deux touches ensemble) : notes à frapper et notes
## longues à maintenir jusqu'au bout de leur traînée.
## Clavier : flèches ; manette : X / Y / B / A ; souris : clics gauche / droit (deux couloirs).
## Note = moyenne des notes (une note longue lâchée trop tôt ne vaut qu'une partie), moins une
## pénalité par frappe dans le vide.

const LANE_KEYS: Array[String] = ["pad_x", "pad_y", "pad_b", "pad_a"]
const MOUSE_KEYS: Array[String] = ["mouse_left", "mouse_right"]
const ARROWS: Array[Vector2] = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]
const LANE_SFX: Array[String] = ["qte_kick", "qte_snare", "qte_hat", "qte_clap"]
## Couleurs des boutons Xbox (X bleu, Y jaune, B rouge, A vert), comme le tri et le juke-box.
const LANE_COLORS: Array[Color] = [Color("2f7bff"), Color("ffc81e"), Color("e8343e"), Color("38c14a")]
const PROMPT: float = 38.0
const HIT_X: float = 96.0
## Les verdicts s'affichent à droite de la ligne de frappe (pas sur le bord du panneau).
const POP_DX: float = 110.0
const GROOVES: Array[String] = ["jazz", "funk", "mambo"]

var _lanes: int = 4
var _times: PackedFloat32Array = PackedFloat32Array()
var _lane_of: PackedInt32Array = PackedInt32Array()
var _scores: PackedFloat32Array = PackedFloat32Array()
var _dur: PackedFloat32Array = PackedFloat32Array()
## Note longue en cours de maintien par couloir (-1 : aucune) et note de frappe associée.
var _holding: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
var _press_sc: PackedFloat32Array = PackedFloat32Array()
var _beat: float = 0.5
var _lead: float = 2.0
var _end: float = 0.0
var _stray: int = 0
var _combo: int = 0
var _best_combo: int = 0
var _lane_flash: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0])
var _groove: String = "jazz"
var _last_beat: int = -1


func begin() -> void:
	_lanes = 2 if mouse else 4
	_groove = GROOVES[rng.randi_range(0, GROOVES.size() - 1)]
	_beat = 60.0 / Balance.f("throw_trials.rhythm.bpm_" + _groove)
	_lead = _beat * 4.0
	var steps: int = pi("bars") * 8
	var want: int = pi("notes") - (pi("assist_fewer") if assist else 0)
	var holds: int = pi("holds") - (1 if assist else 0)
	var hold_len: Array = Balance.arr("throw_trials.rhythm.hold_steps")
	# Une note à la fois, au moins un temps entre deux notes (croches surtout sur les temps).
	var step: int = 2
	var prev_lane: int = -1
	var made: int = 0
	while made < want and step < steps:
		var lane: int = rng.randi_range(0, _lanes - 1)
		if lane == prev_lane:
			lane = (lane + 1 + rng.randi_range(0, _lanes - 2)) % _lanes
		prev_lane = lane
		var len_steps: int = 0
		if holds > 0 and made > 0 and step + 8 < steps and rng.randf() < 0.45:
			len_steps = int(hold_len[rng.randi_range(0, hold_len.size() - 1)])
			holds -= 1
		_add(step, lane, len_steps)
		made += 1
		var gap: int = [2, 2, 2, 3, 4][rng.randi_range(0, 4)]
		step += len_steps + gap
		if len_steps == 0 and step % 2 == 1 and rng.randf() < 0.6:
			step += 1
	_end = _lead + float(steps) * _beat * 0.5 + _window() + 0.3
	if not _times.is_empty():
		_end = maxf(_end, _times[_times.size() - 1] + _dur[_dur.size() - 1] + _window() + 0.4)
	AudioBus.duck_music(true)
	AudioBus.play("groove_" + _groove, 1.0, -2.0)
	# Téléphone : le son sort en retard ; l'horloge de l'épreuve part d'autant en arrière pour que
	# notes, image et jugement tombent sur ce qu'on entend (PC : décalage nul).
	t = -Platform.audio_offset()


func _add(step: int, lane: int, len_steps: int) -> void:
	_times.append(_lead + float(step) * _beat * 0.5)
	_lane_of.append(lane)
	_scores.append(-1.0)
	_press_sc.append(0.0)
	_dur.append(float(len_steps) * _beat * 0.5)


## Fenêtre propre au rythme (plus large que l'invite d'effet : on suit une musique).
func _window() -> float:
	return (p("window_seconds") + p("perfect_seconds")) * widen()


func _tap_score(err: float) -> float:
	return ThrowSkill.timing_score(err, p("perfect_seconds") * widen(), p("window_seconds") * widen())


func handle(event: InputEvent) -> bool:
	var k: int = sym_pressed(event)
	if k >= 0:
		tap(k)
		return true
	for lane: int in _lanes:
		if _holding[lane] >= 0 and _released(event, lane):
			_release(lane)
			return true
	return false


func _released(event: InputEvent, lane: int) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		return mouse and not mb.pressed and mb.button_index == (MOUSE_BUTTON_LEFT if lane == 0 else MOUSE_BUTTON_RIGHT)
	return GameInput.released(event, QTE_ACTIONS[lane])


func tap(lane: int) -> void:
	_lane_flash[lane] = 1.0
	var best: int = -1
	var best_err: float = 1e9
	for i: int in _times.size():
		if _scores[i] >= 0.0 or _lane_of[i] != lane:
			continue
		var err: float = t - _times[i]
		if absf(err) <= _window() and absf(err) < absf(best_err):
			best = i
			best_err = err
	if best < 0:
		_stray += 1
		_combo = 0
		AudioBus.play("click", 0.6, -10.0)
		return
	var sc: float = _tap_score(best_err)
	if _dur[best] > 0.0:
		# Note longue : la frappe est jugée maintenant, le maintien à la fin de la traînée.
		_press_sc[best] = sc
		_scores[best] = -2.0
		_holding[lane] = best
		AudioBus.play(LANE_SFX[lane], 1.0, -3.0)
		AudioBus.play("whoosh", 0.7, -14.0)
		return
	_scores[best] = sc
	pop(Vector2(HIT_X + POP_DX, _lane_y(lane) - 26.0), sc)
	AudioBus.play(LANE_SFX[lane], 1.0, -3.0)
	if sc >= 0.45:
		_combo += 1
		_best_combo = maxi(_best_combo, _combo)
		flash = 1.0
		if _combo > 0 and _combo % 5 == 0:
			AudioBus.play("chime", 1.0 + 0.08 * float(_combo / 5), -6.0)
	else:
		_combo = 0


## Lâcher d'une note longue : pleine valeur si l'on tient jusqu'au bout (à la fenêtre près).
func _release(lane: int) -> void:
	var i: int = _holding[lane]
	_holding[lane] = -1
	if i < 0:
		return
	var tail: float = _times[i] + _dur[i]
	var held: float = clampf((t - _times[i]) / maxf(_dur[i], 0.01), 0.0, 1.0)
	if t >= tail - p("release_seconds") * widen():
		held = 1.0
	_close_hold(i, held)


func _close_hold(i: int, held: float) -> void:
	var sc: float = _press_sc[i] * (0.35 + 0.65 * held)
	_scores[i] = sc
	pop(Vector2(HIT_X + POP_DX, _lane_y(_lane_of[i]) - 26.0), sc, "" if held >= 1.0 else "TRIAL_RHYTHM_LET_GO")
	if held >= 1.0:
		AudioBus.play("chime", 1.2, -6.0)
		_combo += 1
		_best_combo = maxi(_best_combo, _combo)
		flash = 1.0
	else:
		_combo = 0


func tick(dt: float) -> void:
	# Note longue tenue jusqu'au bout (plus la fenêtre) : validée sans attendre le lâcher.
	for lane: int in _lanes:
		var hi: int = _holding[lane]
		if hi >= 0 and t >= _times[hi] + _dur[hi] + p("release_seconds") * widen():
			_holding[lane] = -1
			_close_hold(hi, 1.0)
	for l: int in 4:
		_lane_flash[l] = maxf(_lane_flash[l] - dt * 4.0, 0.0)
	var b: int = int(floor(t / _beat))
	if b != _last_beat:
		_last_beat = b
	for i: int in _times.size():
		if _scores[i] == -1.0 and t - _times[i] > _window():
			_scores[i] = 0.0
			_combo = 0
			pop(Vector2(HIT_X + POP_DX, _lane_y(_lane_of[i]) - 26.0), 0.0, "THROW_TAP_MISSED")
			AudioBus.play("lose_soft", 1.2, -12.0)
	if t >= _end:
		for lane: int in _lanes:
			if _holding[lane] >= 0:
				_close_hold(_holding[lane], 1.0)
				_holding[lane] = -1
		AudioBus.duck_music(false)
		var vals: Array[float] = []
		for v: float in _scores:
			vals.append(maxf(v, 0.0))
		finish(mean(vals) - float(_stray) * p("stray_penalty"))


func bot_wants() -> Dictionary:
	for lane: int in _lanes:
		var hi: int = _holding[lane]
		if hi >= 0 and t >= _times[hi] + _dur[hi]:
			return {"do": "release", "symbol": lane}
	for i: int in _times.size():
		if _scores[i] == -1.0 and absf(t - _times[i]) < 0.02:
			return {"do": "sym", "symbol": _lane_of[i]}
	return {"do": ""}


func bot_apply(want: Dictionary) -> void:
	match String(want.get("do", "")):
		"sym":
			tap(int(want["symbol"]))
		"release":
			_release(int(want["symbol"]))


func _lane_y(lane: int) -> float:
	var r: Rect2 = play_rect()
	var top: float = r.position.y + 70.0
	var h: float = (r.size.y - 90.0) / float(_lanes)
	return top + h * (float(lane) + 0.5)


func paint() -> void:
	var r: Rect2 = play_rect()
	var travel: float = p("travel_seconds")
	var lane_h: float = (r.size.y - 90.0) / float(_lanes)
	var count_in: int = 4 - int(floor(t / _beat))
	var title: String = tr("TRIAL_RHYTHM_GROOVE_" + _groove.to_upper())
	text(Vector2(r.get_center().x, r.position.y + 24.0), title, UiKit.SIZE_BODY, Palette.GOLD_LIGHT)
	if _combo >= 3:
		text(Vector2(r.end.x - 90.0, r.position.y + 24.0), tr("TRIAL_COMBO") % _combo, UiKit.SIZE_BODY, Palette.EMERALD)
	if count_in > 0 and t < _lead:
		text(Vector2(r.get_center().x, r.position.y + 52.0), str(count_in), UiKit.SIZE_H2, Palette.IVORY)
	var beat_pulse: float = 1.0 - fposmod(t, _beat) / _beat
	_draw_stage(r, beat_pulse)
	for l: int in _lanes:
		var y: float = _lane_y(l)
		var lane_r: Rect2 = Rect2(r.position.x + 20.0, y - lane_h * 0.42, r.size.x - 40.0, lane_h * 0.84)
		draw_rect(lane_r, Color(Palette.VELVET_DEEP, 0.9))
		draw_rect(lane_r, Color(LANE_COLORS[l], 0.15 + 0.5 * _lane_flash[l]), false, 2.0)
		# Repères de mesure qui défilent avec les notes.
		var first: int = int(ceil((t - 0.2) / _beat))
		for bk: int in range(first, first + int(travel / _beat) + 2):
			var u: float = (float(bk) * _beat - t) / travel
			if u < 0.0 or u > 1.0:
				continue
			var x: float = HIT_X + u * (lane_r.end.x - HIT_X - 10.0)
			draw_line(Vector2(x, lane_r.position.y), Vector2(x, lane_r.end.y), Color(Palette.GOLD_DARK, 0.5 if bk % 4 == 0 else 0.2), 1.0)
		var target: Rect2 = Rect2(Vector2(HIT_X, y) - Vector2(PROMPT, PROMPT) * 0.5, Vector2(PROMPT, PROMPT))
		draw_rect(target.grow(5.0 + 3.0 * beat_pulse), Color(Palette.GOLD, 0.5 + 0.4 * beat_pulse), false, 2.0)
		if _lane_flash[l] > 0.0:
			draw_circle(Vector2(HIT_X, y), PROMPT * (0.5 + 0.6 * (1.0 - _lane_flash[l])), Color(LANE_COLORS[l], _lane_flash[l] * 0.35))
		_prompt(Vector2(HIT_X - PROMPT - 18.0, y), l, 0.55)
	for i: int in _times.size():
		if _scores[i] >= 0.0:
			continue
		if _dur[i] > 0.0:
			_draw_hold(r, i, travel)
		if _scores[i] == -2.0:
			continue
		var u2: float = (_times[i] - t) / travel
		if u2 > 1.0 or u2 < -0.3:
			continue
		var x2: float = HIT_X + u2 * (r.end.x - 30.0 - HIT_X)
		var ny: float = _lane_y(_lane_of[i])
		var lc: Color = LANE_COLORS[_lane_of[i]]
		# Traînée lumineuse derrière la note.
		draw_rect(Rect2(x2, ny - 4.0, 70.0, 8.0), Color(lc, 0.18))
		draw_circle(Vector2(x2, ny), PROMPT * 0.72, Color(lc, 0.22))
		_prompt(Vector2(x2, ny), _lane_of[i], clampf(1.2 - u2, 0.45, 1.0))
	pips_line(r)


## Note longue : traînée colorée jusqu'à sa fin ; elle se consume à mesure qu'on la tient.
func _draw_hold(r: Rect2, i: int, travel: float) -> void:
	var lc: Color = LANE_COLORS[_lane_of[i]]
	var ny: float = _lane_y(_lane_of[i])
	var span: float = r.end.x - 30.0 - HIT_X
	var held: bool = _scores[i] == -2.0
	var u_head: float = maxf((_times[i] - t) / travel, 0.0) if held else (_times[i] - t) / travel
	var u_tail: float = (_times[i] + _dur[i] - t) / travel
	if u_tail < -0.1:
		return
	var x0: float = HIT_X + clampf(u_head, -0.3, 1.0) * span
	var x1: float = HIT_X + clampf(u_tail, -0.3, 1.0) * span
	if x1 <= x0:
		return
	var glow: float = 0.75 + 0.25 * sin(t * 18.0) if held else 0.45
	draw_rect(Rect2(x0, ny - 13.0, x1 - x0, 26.0), Color(lc, 0.25 * glow))
	draw_rect(Rect2(x0, ny - 7.0, x1 - x0, 14.0), Color(lc, glow))
	draw_rect(Rect2(x0, ny - 7.0, x1 - x0, 14.0), Color(Palette.IVORY, 0.35 * glow), false, 2.0)
	draw_circle(Vector2(x1, ny), 12.0, Color(lc, glow))
	draw_circle(Vector2(x1, ny), 6.0, Color(Palette.IVORY, glow))
	if held:
		draw_circle(Vector2(HIT_X, ny), PROMPT * 0.75, Color(lc, 0.25 + 0.15 * sin(t * 20.0)))


## Scène de cabaret : rideau sombre, égaliseur qui bat la mesure, projecteurs colorés.
func _draw_stage(r: Rect2, pulse: float) -> void:
	draw_rect(Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6)), Color(0.05, 0.02, 0.05))
	var bars: int = 34
	var w: float = (r.size.x - 40.0) / float(bars)
	for k: int in bars:
		var h: float = (0.25 + 0.75 * absf(sin(t * 2.3 + float(k) * 0.7) * cos(t * 1.1 + float(k) * 0.31))) * (0.55 + 0.45 * pulse)
		var bh: float = h * (r.size.y - 60.0) * 0.8
		var col: Color = LANE_COLORS[k % LANE_COLORS.size()]
		draw_rect(Rect2(r.position.x + 20.0 + float(k) * w + 2.0, r.end.y - 20.0 - bh, w - 4.0, bh), Color(col, 0.07))
	for k: int in 3:
		var cx: float = r.position.x + r.size.x * (0.3 + 0.2 * float(k)) + sin(t * 0.8 + float(k) * 2.0) * 120.0
		draw_circle(Vector2(cx, r.position.y + r.size.y * 0.55), 150.0, Color(LANE_COLORS[(k + int(t / _beat)) % 4], 0.04 + 0.04 * pulse))


## Barre de progression du morceau.
func pips_line(r: Rect2) -> void:
	var bar: Rect2 = Rect2(r.position.x + 20.0, r.end.y - 14.0, r.size.x - 40.0, 6.0)
	draw_rect(bar, Palette.VELVET_DEEP)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(t / maxf(_end, 0.01), 0.0, 1.0), bar.size.y)), Palette.GOLD)


## Invite : glyphe de manette, bouton de souris, ou flèche dessinée.
func _prompt(at: Vector2, sym: int, alpha: float) -> void:
	var rect: Rect2 = Rect2(at - Vector2(PROMPT, PROMPT) * 0.5, Vector2(PROMPT, PROMPT))
	var tex: Texture2D = null
	if InputGlyphs.using_pad:
		tex = InputGlyphs.texture(LANE_KEYS[sym])
	elif mouse:
		tex = InputGlyphs.texture(MOUSE_KEYS[sym % MOUSE_KEYS.size()])
	if tex != null:
		draw_texture_rect(tex, rect, false, Color(1, 1, 1, alpha))
		return
	draw_rect(rect, Color(LANE_COLORS[sym], alpha))
	draw_rect(rect.grow(-3), Color(Palette.INK, alpha))
	var d: Vector2 = ARROWS[sym]
	var n: Vector2 = Vector2(-d.y, d.x)
	var tri: PackedVector2Array = PackedVector2Array([at + d * 12.0, at - d * 5.0 + n * 10.0, at - d * 5.0 - n * 10.0])
	draw_colored_polygon(tri, Color(Palette.GOLD_LIGHT, alpha))
	draw_line(at - d * 12.0, at - d * 3.0, Color(Palette.GOLD_LIGHT, alpha), 5.0)
