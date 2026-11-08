class_name TrialTapdance
extends ThrowTrial
## LES CLAQUETTES (Cabaret, 2.0) : appel et réponse. Sur la mesure, la danseuse frappe une
## phrase de pas syncopés (pointe gauche, talon, pointe droite, frappe à plat) ; à la mesure
## suivante, le groom (le joueur) la rejoue : bon pas, bon moment. Les phrases s'allongent et se
## décalent sur les contretemps ; dès la troisième, les pas ne sont plus rappelés sur la piste
## (seuls leurs instants le sont) : il faut les avoir retenus.
## Note = moyenne des pas (plein dans la fenêtre parfaite, partiel en limite, un peu pour le bon
## moment sur le mauvais pas), moins une pénalité par frappe en trop.

## Pas : 0 pointe gauche (←/X), 1 talon (↑/Y), 2 pointe droite (→/B), 3 frappe à plat (↓/A).
const STEPS: int = 4
const EIGHTHS: int = 8
const STEP_SOUNDS: Array[String] = ["qte_hat", "qte_snare", "qte_hat", "qte_kick"]
const STEP_PITCH: Array[float] = [1.15, 1.0, 0.9, 1.0]
const STEP_COLORS: Array[Color] = [Color("ff4d6d"), Color("ffd23f"), Color("29e0ff"), Color("2ee6a8")]
const STEP_ACTIONS: Array[StringName] = [&"qte_left", &"qte_up", &"qte_right", &"qte_down"]
const ARROWS: Array[Vector2] = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]
const PAD_KEYS: Array[String] = ["pad_x", "pad_y", "pad_b", "pad_a"]
## Maquette (pixels 1920×1080) : plancher, danseurs, piste et pavés de pas.
const PX3: float = 0.005
const FLOOR_Y: float = 690.0
const DANCER_X: float = 760.0
const GROOM_X: float = 1160.0
const FIGURE_H: float = 1.85
const TRACK: Rect2 = Rect2(410.0, 790.0, 1100.0, 64.0)
const PAD_Y: float = 905.0
const PAD_SIZE: Vector2 = Vector2(210.0, 104.0)
const PAD_GAP: float = 24.0
## Durée de l'élan d'un pas (animation) et de l'éclat d'un pavé.
const TAP_ANIM: float = 0.24
const FLASH_FALL: float = 4.0

var _bar: float = 2.0
var _phrases: Array[Array] = []  # par phrase : [{"at": temps dans la mesure, "step": int}]
var _matched: Array[Array] = []  # par phrase : -1 pas encore joué, sinon note obtenue
var _extra: int = 0
var _marks: Array[float] = []
var _closed: int = 0
var _bot_step: int = -1
var _last_beat: int = -1
var _pad_flash: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _dancer: Figure3D = null
var _groom: Figure3D = null
var _pianist: Figure3D = null
var _heads: Array[Node3D] = []
var _call_anim: Vector2 = Vector2(-1.0, -10.0)  # (pas, instant)
var _resp_anim: Vector2 = Vector2(-1.0, -10.0)
var _spots: Array[SpotLight3D] = []
var _ended: bool = false


func begin() -> void:
	_bar = 4.0 * 60.0 / p("bpm") * slow
	var lengths: Array = Balance.data()["throw_trials"]["tapdance"]["phrase_notes"] as Array
	for k: int in lengths.size():
		_phrases.append(_make_phrase(int(lengths[k]), pk("offbeat_share", k)))
		var m: Array = []
		m.resize((_phrases[k] as Array).size())
		m.fill(-1.0)
		_matched.append(m)
	_build_3d()


## Phrase de `n` pas sur les croches de la mesure : le premier pas tombe sur le temps, les
## autres sur les croches libres (une part `offbeat` sur les contretemps), jamais trois fois le
## même pas d'affilée.
func _make_phrase(n: int, offbeat: float) -> Array:
	var slots: Array[int] = [0]
	var free_on: Array[int] = [2, 4, 6]
	var free_off: Array[int] = [1, 3, 5, 7]
	while slots.size() < n:
		var pool: Array[int] = free_off if (rng.randf() < offbeat and not free_off.is_empty()) or free_on.is_empty() else free_on
		var s: int = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(s)
		slots.append(s)
	slots.sort()
	var out: Array = []
	for i: int in slots.size():
		var step: int = rng.randi_range(0, STEPS - 1)
		if i >= 2 and int(out[i - 1]["step"]) == step and int(out[i - 2]["step"]) == step:
			step = (step + 1 + rng.randi_range(0, STEPS - 2)) % STEPS
		out.append({"at": _bar * float(slots[i]) / float(EIGHTHS), "step": step})
	return out


# --------------------------------------------------------------------------- temps


## Phrase en cours et position : (phrase, 0 décompte / 1 appel / 2 réponse, temps dans la mesure).
func _where(now: float) -> Vector3:
	if now < _bar:
		return Vector3(0, 0, now)
	var k: int = int((now - _bar) / (2.0 * _bar))
	var local: float = now - _bar - float(k) * 2.0 * _bar
	if local < _bar:
		return Vector3(k, 1, local)
	return Vector3(k, 2, local - _bar)


func _response_start(k: int) -> float:
	return _bar * (2.0 + 2.0 * float(k))


func _end_time() -> float:
	return _bar * (1.0 + 2.0 * float(_phrases.size())) + p("window_seconds") * widen()


func tick(dt: float) -> void:
	for i: int in STEPS:
		_pad_flash[i] = maxf(0.0, _pad_flash[i] - dt * FLASH_FALL)
	_metronome()
	_play_call(dt)
	if _bot_step >= 0:
		tap(_bot_step)
		_bot_step = -1
	_close_phrases(t)
	_sync_3d(dt)
	if not _ended and t >= _end_time():
		_ended = true
		_close_phrases(INF)
		var raw: float = ThrowTrial.mean(_marks) if not _marks.is_empty() else 0.0
		finish(clampf(raw - p("extra_penalty") * float(_extra), 0.0, 1.0))


## Battue : tic à chaque temps (accent sur le premier), plus discret une fois lancé.
func _metronome() -> void:
	var beat: int = int(t / (_bar * 0.25))
	if beat == _last_beat or t >= _end_time():
		return
	_last_beat = beat
	var first: bool = beat % 4 == 0
	var vol: float = -6.0 if beat < 4 else -16.0
	AudioBus.play("tick", 1.5 if first else 1.2, vol + (3.0 if first else 0.0))


## Appel : la danseuse frappe les pas de la phrase en cours.
func _play_call(dt: float) -> void:
	var w: Vector3 = _where(t)
	if int(w.y) != 1 or int(w.x) >= _phrases.size():
		return
	for n: Variant in _phrases[int(w.x)]:
		var note: Dictionary = n as Dictionary
		var at: float = float(note["at"])
		if at <= w.z and at > w.z - dt:
			_call_anim = Vector2(float(note["step"]), t)
			AudioBus.play(STEP_SOUNDS[int(note["step"])], STEP_PITCH[int(note["step"])], -3.0)


## Frappe du joueur : rapprochée du pas attendu le plus proche dans la mesure de réponse.
func tap(step: int) -> void:
	if _ended:
		return
	_pad_flash[step] = 1.0
	_resp_anim = Vector2(float(step), t)
	AudioBus.play(STEP_SOUNDS[step], STEP_PITCH[step], -2.0)
	var window: float = p("window_seconds") * widen()
	var best_k: int = -1
	var best_i: int = -1
	var best_d: float = INF
	for k: int in _phrases.size():
		if k < _closed:
			continue
		var start: float = _response_start(k)
		if t < start - window or t > start + _bar + window:
			continue
		var notes: Array = _phrases[k]
		for i: int in notes.size():
			if float(_matched[k][i]) >= 0.0:
				continue
			var d: float = absf(t - start - float((notes[i] as Dictionary)["at"]))
			if d < best_d:
				best_d = d
				best_k = k
				best_i = i
	if best_k < 0 or best_d > window:
		_extra += 1
		pop(_pad_center(step) + Vector2(0, -80.0), 0.0, "TRIAL_TAPDANCE_EXTRA")
		return
	var note: Dictionary = _phrases[best_k][best_i]
	var q: float = p("wrong_step_value")
	if int(note["step"]) == step:
		var perfect: float = window * p("perfect_ratio")
		q = 1.0 if best_d <= perfect else lerpf(1.0, p("late_value"), (best_d - perfect) / maxf(window - perfect, 0.001))
	_matched[best_k][best_i] = q
	_marks.append(q)
	pop(_pad_center(step) + Vector2(0, -80.0), q, "" if int(note["step"]) == step else "TRIAL_TAPDANCE_WRONG")


## Une réponse terminée (mesure passée + fenêtre) : les pas non joués comptent zéro.
func _close_phrases(now: float) -> void:
	var window: float = p("window_seconds") * widen()
	while _closed < _phrases.size() and now > _response_start(_closed) + _bar + window:
		var missed: int = 0
		for i: int in (_phrases[_closed] as Array).size():
			if float(_matched[_closed][i]) < 0.0:
				_matched[_closed][i] = 0.0
				_marks.append(0.0)
				missed += 1
		if missed > 0 and now < INF:
			pop(Vector2(GROOM_X, FLOOR_Y - 420.0), 0.0, "TRIAL_TAPDANCE_MISSED")
		_closed += 1


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var a: StringName = tap_action(mb.position)
			if a != &"":
				tap(STEP_ACTIONS.find(a))
		return true
	var ea: InputEventAction = event as InputEventAction
	if ea != null:
		var k: int = STEP_ACTIONS.find(ea.action)
		if k >= 0 and ea.pressed:
			tap(k)
			return true
		return k >= 0
	var s: int = sym_pressed(event)
	if s >= 0:
		tap(s)
		return true
	var d: Vector2i = dir_pressed(event)
	if d != Vector2i.ZERO:
		tap(ARROWS.find(Vector2(d)))
		return true
	return false


## Au doigt (et à la souris) : le pavé de pas touché.
func tap_action(pos: Vector2) -> StringName:
	for i: int in STEPS:
		if _pad_rect(i).grow(16.0).has_point(pos):
			return STEP_ACTIONS[i]
	return &""


func journal() -> Dictionary:
	var lens: Array[int] = []
	for ph: Array in _phrases:
		lens.append(ph.size())
	return {"phrases": lens, "extra_taps": _extra, "bpm": p("bpm")}


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	var w: Vector3 = _where(t)
	if int(w.y) != 2 or int(w.x) >= _phrases.size():
		return {"do": ""}
	var k: int = int(w.x)
	var notes: Array = _phrases[k]
	for i: int in notes.size():
		var note: Dictionary = notes[i]
		if float(_matched[k][i]) < 0.0 and float(note["at"]) <= w.z:
			return {"do": "sym", "symbol": int(note["step"])}
	return {"do": ""}


func bot_apply(w: Dictionary) -> void:
	_bot_step = int(w.get("symbol", -1)) if String(w.get("do", "")) == "sym" else -1


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	var deco: Dictionary = CabaretSet.build(st, FLOOR_Y, 700.0)
	_heads.assign(deco.get("audience", []))
	var r: Node3D = st.root
	# Deux cercles de lumière : la danseuse (appel) et le groom (réponse).
	for x: float in [DANCER_X, GROOM_X]:
		var spot: SpotLight3D = SpotLight3D.new()
		spot.light_color = Color(1.0, 0.92, 0.78)
		spot.spot_range = 12.0
		spot.spot_angle = 16.0
		spot.light_energy = 2.0
		spot.shadow_enabled = RenderQuality.shadows()
		r.add_child(spot)
		spot.look_at_from_position(st.to3(Vector2(x, -300.0), 2.5), st.to3(Vector2(x, FLOOR_Y), 0.0))
		_spots.append(spot)
	_dancer = Figure3D.new().build(FIGURE_H, {"coat": Color("5a1a8a"), "trim": Palette.GOLD_LIGHT, "hat": "bow",
		"hat_col": Color("ff2e88"), "skirt": true, "hair": Color("1a0e08"), "trousers": Color("1c1418")})
	_dancer.position = st.to3(Vector2(DANCER_X, FLOOR_Y), 0.0)
	_dancer.rotation.y = 0.35
	r.add_child(_dancer)
	_groom = Figure3D.new().build(FIGURE_H)
	_groom.position = st.to3(Vector2(GROOM_X, FLOOR_Y), 0.0)
	_groom.rotation.y = -0.35
	r.add_child(_groom)
	# Le pianiste, côté cour : piano droit laqué, clavier, bougeoir.
	var piano_at: Vector3 = st.to3(Vector2(330.0, FLOOR_Y), -0.6)
	var lacquer: StandardMaterial3D = Stage3D.mat(Color("0c0a0e"), 0.3, 0.15)
	Stage3D.box(r, Vector3(1.3, 1.25, 0.55), piano_at + Vector3(0, 0.62, -0.1), lacquer)
	Stage3D.box(r, Vector3(1.22, 0.05, 0.22), piano_at + Vector3(0, 0.74, 0.25), Stage3D.mat(Palette.IVORY, 0.0, 0.3))
	for k: int in 18:
		Stage3D.box(r, Vector3(0.025, 0.03, 0.12), piano_at + Vector3(-0.56 + 0.066 * float(k), 0.77, 0.21), lacquer)
	Stage3D.cylinder(r, 0.02, 0.22, piano_at + Vector3(0.45, 1.36, 0.0), Stage3D.mat(Palette.GOLD, 0.7, 0.3))
	Stage3D.sphere(r, 0.03, piano_at + Vector3(0.45, 1.5, 0.0), Stage3D.glow(Color(1.0, 0.75, 0.35), 3.0))
	Stage3D.omni(r, Color(1.0, 0.7, 0.4), 0.6, piano_at + Vector3(0.45, 1.5, 0.3), 2.0)
	_pianist = Figure3D.new().build(1.7, {"coat": Color("16161e"), "trim": Palette.IVORY, "hat": "", "hair": Color("6a6a70")})
	_pianist.position = piano_at + Vector3(0, 0.12, 0.75)
	_pianist.rotation.y = PI
	r.add_child(_pianist)


func _sync_3d(dt: float) -> void:
	if _dancer == null:
		return
	var beat: float = t / (_bar * 0.25)
	_pose(_dancer, _call_anim, beat, dt)
	_pose(_groom, _resp_anim, beat, dt)
	_pianist.animate(&"sit", beat * PI, dt, 0.85 + 0.15 * sin(beat * PI))
	CabaretSet.bob_audience(_heads, beat * 0.5, 1.0)
	var w: Vector3 = _where(t)
	_spots[0].light_energy = lerpf(_spots[0].light_energy, 6.0 if int(w.y) == 1 else 1.5, minf(1.0, dt * 8.0))
	_spots[1].light_energy = lerpf(_spots[1].light_energy, 6.0 if int(w.y) == 2 else 1.5, minf(1.0, dt * 8.0))


## Pose d'un danseur : le pas en cours (élan puis frappe), sinon un rebond sur le temps.
func _pose(fig: Figure3D, anim: Vector2, beat: float, dt: float) -> void:
	var since: float = t - anim.y
	if anim.x >= 0.0 and since < TAP_ANIM * 1.6:
		fig.animate(&"tap", clampf(since / TAP_ANIM, 0.0, 1.0), dt, anim.x)
	else:
		fig.animate(&"tap", 1.0, dt, 3.0 if fmod(beat, 2.0) < 1.0 else 0.0)


# --------------------------------------------------------------------------- dessin


func _pad_rect(i: int) -> Rect2:
	var total: float = float(STEPS) * PAD_SIZE.x + float(STEPS - 1) * PAD_GAP
	var x0: float = 960.0 - total * 0.5 + float(i) * (PAD_SIZE.x + PAD_GAP)
	return Rect2(Vector2(x0, PAD_Y), PAD_SIZE)


func _pad_center(i: int) -> Vector2:
	return _pad_rect(i).get_center()


func paint() -> void:
	if _phrases.is_empty():
		return
	var w: Vector3 = _where(t)
	var k: int = mini(int(w.x), _phrases.size() - 1)
	var phase: int = int(w.y) if t < _end_time() - p("window_seconds") * widen() else 3
	var keys: Array[String] = ["TRIAL_TAPDANCE_COUNT", "TRIAL_TAPDANCE_LISTEN", "TRIAL_TAPDANCE_YOUR_TURN", "TRIAL_TAPDANCE_BRAVO"]
	var col: Color = [Palette.SMOKE, STEP_COLORS[0], Palette.GOLD_LIGHT, Palette.EMERALD][phase]
	var title: String = tr(keys[phase])
	if phase == 0:
		title = title % (int(w.z / (_bar * 0.25)) + 1)
	text(Vector2(960.0, 150.0), title, UiKit.SIZE_H1, col)
	text(Vector2(960.0, 205.0), tr("TRIAL_TAPDANCE_PHRASE") % [k + 1, _phrases.size()], UiKit.SIZE_BODY, Palette.IVORY)
	_draw_track(k, int(w.y), w.z)
	for i: int in STEPS:
		var rr: Rect2 = _pad_rect(i)
		var f: float = _pad_flash[i]
		draw_rect(rr, Color(Palette.INK, 0.82))
		draw_rect(rr, Color(STEP_COLORS[i], 0.25 + 0.6 * f), false, 3.0 + 3.0 * f)
		_symbol(rr.get_center() - Vector2(0, 12.0), i, 1.0)
		text(rr.get_center() + Vector2(0, 32.0), tr("TRIAL_TAPDANCE_STEP_%d" % i), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)


## Piste de la mesure : 8 croches, tête de lecture, pas de l'appel puis à rejouer (de mémoire
## dès la phrase `hide_from` : les instants restent, les pas sont masqués).
func _draw_track(k: int, phase: int, local: float) -> void:
	draw_rect(TRACK, Color(Palette.INK, 0.85))
	draw_rect(TRACK, Palette.GOLD_DARK, false, 2.0)
	for e: int in EIGHTHS + 1:
		var x: float = TRACK.position.x + TRACK.size.x * float(e) / float(EIGHTHS)
		var strong: bool = e % 2 == 0
		draw_line(Vector2(x, TRACK.position.y + (6.0 if strong else 20.0)), Vector2(x, TRACK.end.y - (6.0 if strong else 20.0)),
			Color(Palette.SMOKE, 0.6 if strong else 0.3), 2.0)
	if phase == 0:
		return
	var hide: bool = k >= pi("hide_from") and phase == 2
	var notes: Array = _phrases[k]
	for i: int in notes.size():
		var note: Dictionary = notes[i]
		var at: float = float(note["at"])
		var x2: float = TRACK.position.x + TRACK.size.x * at / _bar
		var c: Vector2 = Vector2(x2, TRACK.get_center().y)
		if phase == 1 and at > local:
			continue  # l'appel se découvre pas à pas
		var done: float = float(_matched[k][i])
		if phase == 2 and done >= 0.0:
			draw_circle(c, 24.0, Color(Palette.EMERALD if done >= 0.75 else (Palette.GOLD if done > 0.0 else Palette.ROULETTE_RED), 0.7))
		if hide:
			draw_arc(c, 22.0, 0, TAU, 24, Palette.GOLD_LIGHT, 3.0)
		else:
			_symbol(c, int(note["step"]), 1.0 if phase == 1 else 0.85)
	var head: float = TRACK.position.x + TRACK.size.x * clampf(local / _bar, 0.0, 1.0)
	draw_line(Vector2(head, TRACK.position.y - 8.0), Vector2(head, TRACK.end.y + 8.0), Palette.GOLD_LIGHT, 4.0)


## Pas dessiné : glyphe de manette, sinon flèche colorée.
func _symbol(at: Vector2, step: int, alpha: float) -> void:
	if InputGlyphs.using_pad:
		var tex: Texture2D = InputGlyphs.texture(PAD_KEYS[step])
		if tex != null:
			draw_texture_rect(tex, Rect2(at - Vector2(22, 22), Vector2(44, 44)), false, Color(1, 1, 1, alpha))
			return
	draw_circle(at, 22.0, Color(STEP_COLORS[step], alpha))
	var d: Vector2 = ARROWS[step]
	var n: Vector2 = Vector2(-d.y, d.x)
	var tri: PackedVector2Array = PackedVector2Array([at + d * 13.0, at - d * 4.0 + n * 11.0, at - d * 4.0 - n * 11.0])
	draw_colored_polygon(tri, Color(Palette.INK, alpha))
	draw_line(at - d * 13.0, at - d * 2.0, Color(Palette.INK, alpha), 5.0)
