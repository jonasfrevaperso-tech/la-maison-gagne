class_name TrialRhythm
extends ThrowTrial
## EFFET : un vrai petit jeu de rythme. Un morceau (jazz, funk ou mambo) démarre après une
## mesure de décompte ; les notes glissent sur quatre couloirs vers la ligne et tombent sur la
## grille du morceau, une à la fois (jamais deux touches ensemble) : notes à frapper et notes
## longues à maintenir jusqu'au bout de leur traînée.
## Clavier : flèches ; manette : X / Y / B / A ; souris : clics gauche / droit (deux couloirs).
## Note = moyenne des notes (une note longue lâchée trop tôt ne vaut qu'une partie), moins une
## pénalité par frappe dans le vide.
## 2.0 : des GLISSÉS (note longue qui finit dans un autre couloir : tenir, puis frapper ce
## couloir au bout de la traînée) et le disque qui S'EMBALLE sur les dernières mesures (le
## morceau accélère, notes comprises). Les notes vivent en « temps du morceau » (`_st`).

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
## Décor 3D du club : mètres par pixel, barres de l'égaliseur, projecteurs, vitesse du disque.
const PX3: float = 0.005
const EQ_BARS: int = 24
const SPOTS: int = 3
const RECORD_RPM: float = 33.0

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
var _eq3: Array[MeshInstance3D] = []
var _spots3: Array[SpotLight3D] = []
var _record3: Node3D = null
## Temps du morceau (avance plus vite quand le disque s'emballe) et lecteur du morceau.
var _st: float = 0.0
var _speed_from: float = 1e9
var _song: AudioStreamPlayer = null
var _song_stream: AudioStream = null
## Glissé : couloir d'arrivée de chaque note (-1 : aucune).
var _slide_to: PackedInt32Array = PackedInt32Array()


func begin() -> void:
	_lanes = 2 if mouse else 4
	_groove = GROOVES[rng.randi_range(0, GROOVES.size() - 1)]
	_beat = 60.0 / Balance.f("throw_trials.rhythm.bpm_" + _groove)
	_build_3d()
	_lead = _beat * 4.0
	var steps: int = pi("bars") * 8
	var want: int = pi("notes") - (pi("assist_fewer") if assist else 0)
	var holds: int = pi("holds") - (1 if assist else 0)
	var slides: int = pi("slides") - (1 if assist else 0)
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
		var slide: int = -1
		if holds + slides > 0 and made > 0 and step + 8 < steps and rng.randf() < 0.5:
			len_steps = int(hold_len[rng.randi_range(0, hold_len.size() - 1)])
			if slides > 0 and (holds == 0 or rng.randf() < 0.5):
				slides -= 1
				slide = (lane + 1 + rng.randi_range(0, _lanes - 2)) % _lanes
				prev_lane = slide
			else:
				holds -= 1
		_add(step, lane, len_steps, slide)
		made += 1
		var gap: int = [2, 2, 2, 3, 4][rng.randi_range(0, 4)]
		step += len_steps + gap
		if len_steps == 0 and step % 2 == 1 and rng.randf() < 0.6:
			step += 1
	_end = _lead + float(steps) * _beat * 0.5 + _window() + 0.3
	if not _times.is_empty():
		_end = maxf(_end, _times[_times.size() - 1] + _dur[_dur.size() - 1] + _window() + 0.4)
	AudioBus.duck_music(true)
	_song = AudioBus.play_get("groove_" + _groove, 1.0, -2.0)
	_song_stream = _song.stream if _song != null else null
	# Téléphone : le son sort en retard ; l'horloge de l'épreuve part d'autant en arrière pour que
	# notes, image et jugement tombent sur ce qu'on entend (PC : décalage nul).
	_st = -Platform.audio_offset()
	_speed_from = _lead + float(maxi(pi("bars") - pi("speedup_bars"), 0)) * 4.0 * _beat


func _add(step: int, lane: int, len_steps: int, slide: int = -1) -> void:
	_slide_to.append(slide)
	_times.append(_lead + float(step) * _beat * 0.5)
	_lane_of.append(lane)
	_scores.append(-1.0)
	_press_sc.append(0.0)
	_dur.append(float(len_steps) * _beat * 0.5)


## Fenêtre propre au rythme (plus large que l'invite d'effet : on suit une musique).
## Vitesse du morceau : 1, puis le disque s'emballe sur une mesure jusqu'à `speedup`.
func _rate() -> float:
	var u: float = clampf((_st - _speed_from) / (_beat * 4.0), 0.0, 1.0)
	return lerpf(1.0, p("speedup"), u * u * (3.0 - 2.0 * u))


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
	# Glissé : on tient la note d'un couloir et on frappe celui d'arrivée au bout de la traînée.
	for hl: int in _lanes:
		var hi: int = _holding[hl]
		if hi >= 0 and _slide_to[hi] == lane and absf(_st - (_times[hi] + _dur[hi])) <= _window():
			_holding[hl] = -1
			AudioBus.play(LANE_SFX[lane], 1.1, -3.0)
			_close_hold(hi, 1.0)
			return
	var best: int = -1
	var best_err: float = 1e9
	for i: int in _times.size():
		if _scores[i] >= 0.0 or _lane_of[i] != lane:
			continue
		var err: float = _st - _times[i]
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
	var held: float = clampf((_st - _times[i]) / maxf(_dur[i], 0.01), 0.0, 1.0)
	if _st >= tail - p("release_seconds") * widen():
		held = 1.0 if _slide_to[i] < 0 else p("slide_partial")
	_close_hold(i, held)


func _close_hold(i: int, held: float) -> void:
	var sc: float = _press_sc[i] * (0.35 + 0.65 * held)
	_scores[i] = sc
	var key: String = "" if held >= 1.0 else ("TRIAL_RHYTHM_SLIDE_MISS" if _slide_to[i] >= 0 else "TRIAL_RHYTHM_LET_GO")
	pop(Vector2(HIT_X + POP_DX, _lane_y(_lane_of[i]) - 26.0), sc, key)
	if held >= 1.0:
		AudioBus.play("chime", 1.2, -6.0)
		_combo += 1
		_best_combo = maxi(_best_combo, _combo)
		flash = 1.0
	else:
		_combo = 0


func tick(dt: float) -> void:
	_st += dt * _rate()
	if _song != null and _song.stream == _song_stream and _song.playing:
		_song.pitch_scale = _rate()  # le disque s'emballe : tempo et hauteur montent ensemble
	# Note longue tenue jusqu'au bout (plus la fenêtre) : validée sans attendre le lâcher ;
	# glissé non conclu : à moitié.
	for lane: int in _lanes:
		var hi: int = _holding[lane]
		if hi < 0:
			continue
		var slide: bool = _slide_to[hi] >= 0
		if _st >= _times[hi] + _dur[hi] + (_window() if slide else p("release_seconds") * widen()):
			_holding[lane] = -1
			_close_hold(hi, p("slide_partial") if slide else 1.0)
	for l: int in 4:
		_lane_flash[l] = maxf(_lane_flash[l] - dt * 4.0, 0.0)
	var b: int = int(floor(_st / _beat))
	if b != _last_beat:
		_last_beat = b
	for i: int in _times.size():
		if _scores[i] == -1.0 and _st - _times[i] > _window():
			_scores[i] = 0.0
			_combo = 0
			pop(Vector2(HIT_X + POP_DX, _lane_y(_lane_of[i]) - 26.0), 0.0, "THROW_TAP_MISSED")
			AudioBus.play("lose_soft", 1.2, -12.0)
	if _st >= _end:
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
		if hi >= 0 and _st >= _times[hi] + _dur[hi]:
			if _slide_to[hi] >= 0:
				return {"do": "sym", "symbol": _slide_to[hi]}
			return {"do": "release", "symbol": lane}
	for i: int in _times.size():
		if _scores[i] == -1.0 and absf(_st - _times[i]) < 0.02:
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
	var count_in: int = 4 - int(floor(_st / _beat))
	var title: String = tr("TRIAL_RHYTHM_GROOVE_" + _groove.to_upper())
	text(Vector2(r.get_center().x, r.position.y + 24.0), title, UiKit.SIZE_BODY, Palette.GOLD_LIGHT)
	if _combo >= 3:
		text(Vector2(r.end.x - 90.0, r.position.y + 24.0), tr("TRIAL_COMBO") % _combo, UiKit.SIZE_BODY, Palette.EMERALD)
	if _rate() > 1.01:
		text(Vector2(r.get_center().x, r.position.y + 52.0), tr("TRIAL_RHYTHM_SPEEDUP"), UiKit.SIZE_BODY, Palette.MULT_RED)
	if count_in > 0 and _st < _lead:
		text(Vector2(r.get_center().x, r.position.y + 52.0), str(count_in), UiKit.SIZE_H2, Palette.IVORY)
	var beat_pulse: float = 1.0 - fposmod(_st, _beat) / _beat
	_draw_stage(r, beat_pulse)
	for l: int in _lanes:
		var y: float = _lane_y(l)
		var lane_r: Rect2 = Rect2(r.position.x + 20.0, y - lane_h * 0.42, r.size.x - 40.0, lane_h * 0.84)
		# Piste lumineuse : verre fumé, liseré néon de sa couleur.
		draw_rect(lane_r, Color(Palette.VELVET_DEEP, 0.62))
		draw_rect(Rect2(lane_r.position, Vector2(lane_r.size.x, 3.0)), Color(LANE_COLORS[l], 0.35 + 0.5 * _lane_flash[l]))
		draw_rect(Rect2(Vector2(lane_r.position.x, lane_r.end.y - 3.0), Vector2(lane_r.size.x, 3.0)),
			Color(LANE_COLORS[l], 0.35 + 0.5 * _lane_flash[l]))
		# Repères de mesure qui défilent avec les notes.
		var first: int = int(ceil((_st - 0.2) / _beat))
		for bk: int in range(first, first + int(travel / _beat) + 2):
			var u: float = (float(bk) * _beat - _st) / travel
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
		var u2: float = (_times[i] - _st) / travel
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
	var u_head: float = maxf((_times[i] - _st) / travel, 0.0) if held else (_times[i] - _st) / travel
	var u_tail: float = (_times[i] + _dur[i] - _st) / travel
	if u_tail < -0.1:
		return
	var x0: float = HIT_X + clampf(u_head, -0.3, 1.0) * span
	var x1: float = HIT_X + clampf(u_tail, -0.3, 1.0) * span
	if x1 <= x0:
		return
	var glow: float = 0.75 + 0.25 * sin(_st * 18.0) if held else 0.45
	draw_rect(Rect2(x0, ny - 13.0, x1 - x0, 26.0), Color(lc, 0.25 * glow))
	draw_rect(Rect2(x0, ny - 7.0, x1 - x0, 14.0), Color(lc, glow))
	draw_rect(Rect2(x0, ny - 7.0, x1 - x0, 14.0), Color(Palette.IVORY, 0.35 * glow), false, 2.0)
	draw_circle(Vector2(x1, ny), 12.0, Color(lc, glow))
	draw_circle(Vector2(x1, ny), 6.0, Color(Palette.IVORY, glow))
	if _slide_to[i] >= 0:
		# Glissé : la traînée bifurque vers le couloir d'arrivée, où attend son bouton.
		var to: int = _slide_to[i]
		var ty: float = _lane_y(to)
		var tc: Color = LANE_COLORS[to]
		draw_line(Vector2(x1, ny), Vector2(x1 + 24.0, ty), Color(tc, glow), 8.0)
		draw_circle(Vector2(x1 + 24.0, ty), PROMPT * 0.72, Color(tc, 0.3))
		_prompt(Vector2(x1 + 24.0, ty), to, 0.9)
	if held:
		draw_circle(Vector2(HIT_X, ny), PROMPT * 0.75, Color(lc, 0.25 + 0.15 * sin(_st * 20.0)))


## Scène de cabaret : rideau sombre, égaliseur qui bat la mesure, projecteurs colorés.
## Club de jazz : rideau de fond, égaliseur lumineux, disque qui tourne, projecteurs colorés.
func _build_3d() -> void:
	var r: Rect2 = play_rect()
	var st: Stage3D = use_3d()
	st.frontal(PX3, r.get_center(), r.size.y, 36.0)
	st.env.background_color = Color(0.03, 0.01, 0.03)
	st.env.ambient_light_energy = 0.25
	st.key.light_energy = 0.15
	var root: Node3D = st.root
	var velvet: StandardMaterial3D = Stage3D.mat(Color(0.25, 0.03, 0.08), 0.0, 0.8)
	for k: int in 40:
		var x: float = r.position.x - 400.0 + float(k) * 60.0
		Stage3D.cylinder(root, 34.0 * PX3, r.size.y * 2.0 * PX3, st.to3(Vector2(x, r.get_center().y), -1.2 - 0.04 * float(k % 2)), velvet)
	var w: float = (r.size.x - 40.0) / float(EQ_BARS)
	for k2: int in EQ_BARS:
		var col: Color = LANE_COLORS[k2 % LANE_COLORS.size()]
		var bar: MeshInstance3D = Stage3D.box(root, Vector3((w - 6.0) * PX3, 1.0, 0.05),
			st.to3(Vector2(r.position.x + 20.0 + (float(k2) + 0.5) * w, r.end.y - 20.0), -0.9), Stage3D.glow(col.darkened(0.55), 0.25))
		_eq3.append(bar)
	# Disque vinyle derrière la zone de frappe, avec étiquette dorée.
	_record3 = Node3D.new()
	_record3.position = st.to3(Vector2(r.position.x + HIT_X, r.get_center().y), -0.7)
	root.add_child(_record3)
	var vinyl: MeshInstance3D = Stage3D.cylinder(_record3, r.size.y * 0.42 * PX3, 0.02, Vector3.ZERO,
		Stage3D.mat(Color("0a0a0c"), 0.2, 0.15))
	vinyl.rotation.x = PI * 0.5
	for g: int in 5:
		var groove: TorusMesh = TorusMesh.new()
		groove.inner_radius = r.size.y * (0.18 + 0.045 * float(g)) * PX3
		groove.outer_radius = groove.inner_radius + 1.5 * PX3
		var gm: MeshInstance3D = MeshInstance3D.new()
		gm.mesh = groove
		gm.material_override = Stage3D.mat(Color("2a2a30"), 0.3, 0.2)
		gm.rotation.x = PI * 0.5
		gm.position.z = 0.012
		_record3.add_child(gm)
	var label: MeshInstance3D = Stage3D.cylinder(_record3, r.size.y * 0.13 * PX3, 0.025, Vector3(0, 0, 0.002),
		Stage3D.mat(Palette.ROULETTE_RED.darkened(0.5), 0.0, 0.5))
	label.rotation.x = PI * 0.5
	Stage3D.box(_record3, Vector3(r.size.y * 0.05 * PX3, r.size.y * 0.02 * PX3, 0.01), Vector3(r.size.y * 0.06 * PX3, 0, 0.016),
		Stage3D.mat(Palette.GOLD, 0.45, 0.3))
	for k3: int in SPOTS:
		var sp: SpotLight3D = SpotLight3D.new()
		sp.light_color = LANE_COLORS[k3]
		sp.light_energy = 3.0
		sp.spot_range = 8.0
		sp.spot_angle = 26.0
		sp.position = st.to3(Vector2(r.position.x + r.size.x * (0.25 + 0.25 * float(k3)), r.position.y - 200.0), 2.0)
		root.add_child(sp)
		_spots3.append(sp)


func _sync_3d(pulse: float) -> void:
	if _record3 == null:
		return
	var r: Rect2 = play_rect()
	for k: int in _eq3.size():
		var h: float = (0.25 + 0.75 * absf(sin(_st * 2.3 + float(k) * 0.7) * cos(_st * 1.1 + float(k) * 0.31))) * (0.55 + 0.45 * pulse)
		var bh: float = maxf(h * (r.size.y - 60.0) * 0.45, 4.0) * PX3
		var bar: MeshInstance3D = _eq3[k]
		bar.scale.y = bh
		bar.position.y = stage.to3(Vector2(0, r.end.y - 20.0)).y + bh * 0.5
	_record3.rotation.z = -_st * RECORD_RPM / 60.0 * TAU
	for k2: int in _spots3.size():
		var sp: SpotLight3D = _spots3[k2]
		var target: Vector2 = Vector2(r.position.x + r.size.x * (0.3 + 0.2 * float(k2)) + sin(_st * 0.8 + float(k2) * 2.0) * 120.0,
			r.get_center().y)
		sp.look_at_from_position(sp.position, stage.to3(target, -1.0))
		sp.light_color = LANE_COLORS[(k2 + int(_st / _beat)) % 4]
		sp.light_energy = 1.2 + 1.5 * pulse


func _draw_stage(r: Rect2, pulse: float) -> void:
	if stage != null:
		_sync_3d(pulse)
		return
	draw_rect(Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6)), Color(0.05, 0.02, 0.05))
	var bars: int = 34
	var w: float = (r.size.x - 40.0) / float(bars)
	for k: int in bars:
		var h: float = (0.25 + 0.75 * absf(sin(_st * 2.3 + float(k) * 0.7) * cos(_st * 1.1 + float(k) * 0.31))) * (0.55 + 0.45 * pulse)
		var bh: float = h * (r.size.y - 60.0) * 0.8
		var col: Color = LANE_COLORS[k % LANE_COLORS.size()]
		draw_rect(Rect2(r.position.x + 20.0 + float(k) * w + 2.0, r.end.y - 20.0 - bh, w - 4.0, bh), Color(col, 0.07))
	for k: int in 3:
		var cx: float = r.position.x + r.size.x * (0.3 + 0.2 * float(k)) + sin(_st * 0.8 + float(k) * 2.0) * 120.0
		draw_circle(Vector2(cx, r.position.y + r.size.y * 0.55), 150.0, Color(LANE_COLORS[(k + int(_st / _beat)) % 4], 0.04 + 0.04 * pulse))


## Barre de progression du morceau.
func pips_line(r: Rect2) -> void:
	var bar: Rect2 = Rect2(r.position.x + 20.0, r.end.y - 14.0, r.size.x - 40.0, 6.0)
	draw_rect(bar, Palette.VELVET_DEEP)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_st / maxf(_end, 0.01), 0.0, 1.0), bar.size.y)), Palette.GOLD)


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


## Au doigt : la piste touchée (les pistes sont des bandes horizontales).
func tap_action(pos: Vector2) -> StringName:
	var best: int = 0
	for lane: int in _lanes:
		if absf(pos.y - _lane_y(lane)) < absf(pos.y - _lane_y(best)):
			best = lane
	return QTE_ACTIONS[best]
