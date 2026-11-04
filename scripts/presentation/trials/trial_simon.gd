class_name TrialSimon
extends ThrowTrial
## LE JUKE-BOX (écran dédié) : le vieux juke-box du Grand Zéro joue une mélodie de lumières.
## La regarder, puis la rejouer touche par touche. Trois mélodies, de plus en plus longues.
## Note = part de la mélodie rejouée sans faute, mélodie par mélodie.

enum Phase { LISTEN, PLAY, RESULT }

const PITCHES: Array[float] = [1.0, 1.26, 1.5, 1.68]
## Couleurs des boutons de la manette Xbox, dans les mêmes directions : X bleu à gauche, Y jaune
## en haut, B rouge à droite, A vert en bas (comme le tri des jetons). Souris : bleu / rouge.
const COLORS: Array[Color] = [Color("2f7bff"), Color("ffc81e"), Color("e8343e"), Color("38c14a")]
const PAD_LABEL: Array[String] = ["X", "Y", "B", "A"]
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
## Scène 3D : le juke-box, ses boutons (qui s'enfoncent et s'allument), son disque qui tourne.
var _btn3: Array[MeshInstance3D] = []
var _btn_mat: Array[StandardMaterial3D] = []
var _btn_light: Array[OmniLight3D] = []
var _disc: Node3D = null
var _tubes: Array[StandardMaterial3D] = []


func begin() -> void:
	_build_3d()
	_new_round()


## Couleur du bouton k (à la souris, le second bouton est le rouge de droite).
func _col(k: int) -> Color:
	return COLORS[2 if mouse and k == 1 else k]


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.env.background_color = Color(0.05, 0.02, 0.04)
	st.key.light_energy = 0.35
	st.frontal(0.004, Vector2(960.0, 600.0), 1080.0, 38.0)
	var r: Node3D = st.root
	Stage3D.box(r, Vector3(14, 8, 0.1), Vector3(0, 0.5, -1.2), Stage3D.mat(Color(0.14, 0.04, 0.08), 0.0, 1.0))
	Stage3D.box(r, Vector3(14, 0.1, 6), Vector3(0, -2.1, 0), Stage3D.mat(Color(0.12, 0.08, 0.06), 0.1, 0.4))
	# Caisse du juke-box (placée en pixels du repère 2D) : arche laquée cerclée de chrome,
	# corps, tubes à bulles, disque sous verre en haut, grille du haut-parleur en bas.
	var lacquer: StandardMaterial3D = Stage3D.mat(Color(0.35, 0.08, 0.12), 0.3, 0.25)
	var chrome: StandardMaterial3D = Stage3D.mat(Color(0.85, 0.85, 0.9), 1.0, 0.15)
	var px: float = st.px3
	var arch_c: Vector3 = st.to3(Vector2(960, 560), -0.5)
	var arch: MeshInstance3D = Stage3D.cylinder(r, 500.0 * px, 0.8, arch_c, lacquer)
	arch.rotation.x = PI * 0.5
	var trim: MeshInstance3D = Stage3D.cylinder(r, 525.0 * px, 0.7, arch_c + Vector3(0, 0, -0.02), chrome)
	trim.rotation.x = PI * 0.5
	var body_c: Vector3 = st.to3(Vector2(960, 860), -0.5)
	Stage3D.box(r, Vector3(1000.0 * px, 600.0 * px, 0.8), body_c, lacquer)
	for side: float in [-1.0, 1.0]:
		Stage3D.box(r, Vector3(0.12, 600.0 * px, 0.9), body_c + Vector3(side * 510.0 * px, 0, 0), chrome)
		var tube: StandardMaterial3D = Stage3D.glow(Palette.MAGENTA, 1.6)
		_tubes.append(tube)
		Stage3D.cylinder(r, 0.08, 700.0 * px, st.to3(Vector2(960.0 + side * 430.0, 720), -0.05), tube)
	var win_c: Vector3 = st.to3(Vector2(960, 230), -0.08)
	Stage3D.cylinder(r, 150.0 * px, 0.05, win_c, Stage3D.mat(Color(0.05, 0.03, 0.05), 0.0, 0.9)).rotation.x = PI * 0.5
	Stage3D.cylinder(r, 162.0 * px, 0.04, win_c + Vector3(0, 0, -0.01), chrome).rotation.x = PI * 0.5
	_disc = Node3D.new()
	_disc.position = win_c + Vector3(0, 0, 0.05)
	_disc.rotation.x = PI * 0.5
	r.add_child(_disc)
	Stage3D.cylinder(_disc, 125.0 * px, 0.02, Vector3.ZERO, Stage3D.mat(Color(0.03, 0.03, 0.04), 0.4, 0.2))
	Stage3D.cylinder(_disc, 40.0 * px, 0.025, Vector3.ZERO, Stage3D.mat(Palette.GOLD, 0.5, 0.4))
	Stage3D.box(_disc, Vector3(0.04, 0.03, 0.12), Vector3(0, 0, 0.06), Stage3D.mat(Palette.ROULETTE_RED))
	for k: int in 6:
		Stage3D.box(r, Vector3(700.0 * px, 0.035, 0.05), st.to3(Vector2(960, 990.0 + 14.0 * float(k)), -0.08), chrome)
	# Boutons : gros champignons de couleur sur la façade, lumière propre.
	for k: int in 4:
		var pc: Vector3 = st.to3(_pad_center(k), 0.0)
		var m: StandardMaterial3D = Stage3D.mat(_col(k).darkened(0.5), 0.1, 0.25)
		m.emission_enabled = true
		m.emission = _col(k)
		m.emission_energy_multiplier = 0.0
		var b: MeshInstance3D = Stage3D.cylinder(r, PAD.y * 0.5 * st.px3, 0.18, pc, m)
		b.rotation.x = PI * 0.5
		Stage3D.cylinder(r, PAD.y * 0.58 * st.px3, 0.12, pc + Vector3(0, 0, -0.08), chrome).rotation.x = PI * 0.5
		_btn3.append(b)
		_btn_mat.append(m)
		_btn_light.append(Stage3D.omni(r, _col(k), 0.0, pc + Vector3(0, 0, 0.6), 2.5))
	Stage3D.omni(r, Color(1.0, 0.8, 0.7), 1.2, Vector3(0, 2.0, 2.5), 7.0)


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
	_sync_3d()
	for k2: int in _keys():
		var pc: Vector2 = _pad_center(k2)
		if mouse:
			continue
		var glyph: String = PAD_LABEL[k2] if InputGlyphs.using_pad else ["←", "↑", "→", "↓"][k2]
		text(pc, glyph, UiKit.SIZE_H1, Palette.IVORY if _lit != k2 else Palette.INK)
	var msg: String = tr("TRIAL_SIMON_LISTEN") if _phase == Phase.LISTEN else (tr("TRIAL_SIMON_PLAY") % [_pos, _seq.size()])
	text(Vector2(size.x * 0.5, 880.0), msg, UiKit.SIZE_H2, Palette.GOLD_LIGHT)
	pips(Vector2(size.x * 0.5, 930.0), _scores, pi("rounds"))
	if _phase == Phase.PLAY:
		var left: float = clampf(1.0 - _input_t / (p("input_seconds") * slow), 0.0, 1.0)
		draw_rect(Rect2(size.x * 0.5 - 200, 960, 400 * left, 10), Palette.GOLD if left > 0.3 else Palette.DANGER)


func _sync_3d() -> void:
	if _disc == null:
		return
	_disc.basis = Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, t * 3.4)
	for k: int in _tubes.size():
		_tubes[k].emission = Color.from_hsv(fposmod(t * 0.15 + 0.5 * float(k), 1.0), 0.8, 1.0)
		_tubes[k].albedo_color = _tubes[k].emission
	for k: int in _btn3.size():
		var on: bool = _lit == k
		_btn3[k].visible = k < _keys()
		_btn_mat[k].emission_energy_multiplier = 2.5 if on else 0.15
		_btn_mat[k].albedo_color = _col(k) if on else _col(k).darkened(0.5)
		_btn_light[k].light_energy = 2.5 if on else 0.0
		var pc: Vector3 = stage.to3(_pad_center(k), 0.0)
		_btn3[k].position = pc + Vector3(0, 0, -0.06 if on else 0.0)


## Au doigt : la touche du juke-box sous le doigt.
func tap_action(pos: Vector2) -> StringName:
	for k: int in _keys():
		if pos.distance_to(_pad_center(k)) < PAD.x * 0.75:
			return QTE_ACTIONS[k]
	return &""
