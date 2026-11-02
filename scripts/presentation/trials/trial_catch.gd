class_name TrialCatch
extends ThrowTrial
## PLUIE DE JETONS (écran dédié) : le plafond du Grand Zéro fuit… des jetons. Déplacer le
## plateau (stick, flèches ou souris) pour attraper les jetons dorés et éviter les fausses
## pièces violettes de La Maison. La pluie s'intensifie. Note = part des jetons dorés
## attrapés, moins une pénalité par fausse pièce.

const TRAY_W: float = 220.0
const TRAY_Y: float = 900.0
const CHIP_R: float = 22.0
const FIELD_X: Vector2 = Vector2(300.0, 1620.0)
const FAKE: Color = Color("b03aff")

var _x: float = 960.0
var _chips: Array[Dictionary] = []
var _spawn_t: float = 0.0
var _good_total: int = 0
var _caught: int = 0
var _bad: int = 0
var _mouse_x: float = -1.0
var _bot_axis: float = 0.0
var _ended: bool = false
## Scène 3D : pièces qui tournoient (réserve réutilisée), plateau de croupier, plafond qui fuit.
var _coins3: Array[MeshInstance3D] = []
var _gold_mat: StandardMaterial3D = null
var _fake_mat: StandardMaterial3D = null
var _tray3: Node3D = null
var _pile3: Array[MeshInstance3D] = []


func begin() -> void:
	_x = size.x * 0.5
	_build_3d()


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.env.background_color = Color(0.04, 0.03, 0.04)
	st.key.light_energy = 0.45
	st.frontal(0.005, Vector2(960.0, 540.0), 1080.0, 40.0)
	var r: Node3D = st.root
	var px: float = st.px3
	# Mur à rayures délavées, plafond à poutres percées, sol de feutre vert.
	var wall: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.0, 0.95)
	var img: Image = Image.create(8, 1, false, Image.FORMAT_RGB8)
	for x: int in 8:
		img.set_pixel(x, 0, Color(0.16, 0.07, 0.1) if x < 5 else Color(0.11, 0.05, 0.07))
	wall.albedo_texture = ImageTexture.create_from_image(img)
	wall.uv1_scale = Vector3(30, 1, 1)
	wall.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	Stage3D.box(r, Vector3(1920.0 * px * 1.5, 1080.0 * px * 1.5, 0.1), Vector3(0, 0, -1.2), wall)
	var beam: StandardMaterial3D = Stage3D.mat(Color(0.24, 0.14, 0.08), 0.0, 0.8)
	Stage3D.box(r, Vector3(1920.0 * px * 1.4, 34.0 * px, 1.4), st.to3(Vector2(960, 135), -0.4), beam)
	for k: int in 12:
		var hole: Vector3 = st.to3(Vector2(160.0 + float(k) * 140.0, 152), 0.25)
		Stage3D.box(r, Vector3(30.0 * px, 0.02, 0.3), hole, Stage3D.mat(Color(0.03, 0.02, 0.02)))
	var felt: StandardMaterial3D = Stage3D.mat(Color(0.05, 0.16, 0.1), 0.0, 0.95)
	Stage3D.box(r, Vector3(1920.0 * px * 1.5, 0.1, 3.0), st.to3(Vector2(960, TRAY_Y + 70.0), 0.0), felt)
	# Plateau de croupier en laiton.
	_tray3 = Node3D.new()
	r.add_child(_tray3)
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD.darkened(0.2), 0.9, 0.3)
	Stage3D.box(_tray3, Vector3(1, 18.0 * px, 0.5), Vector3(0, -9.0 * px, 0), brass).name = "floor"
	for side: float in [-1.0, 1.0]:
		var wallk: MeshInstance3D = Stage3D.box(_tray3, Vector3(10.0 * px, 48.0 * px, 0.5), Vector3.ZERO, brass)
		wallk.name = "side%d" % int(side + 1.0)
	_gold_mat = Stage3D.mat(Palette.GOLD, 0.5, 0.3)
	_gold_mat.emission_enabled = true
	_gold_mat.emission = Palette.GOLD
	_gold_mat.emission_energy_multiplier = 0.35
	_fake_mat = Stage3D.mat(FAKE, 0.4, 0.35)
	_fake_mat.emission_enabled = true
	_fake_mat.emission = FAKE
	_fake_mat.emission_energy_multiplier = 0.4
	var lamp: OmniLight3D = Stage3D.omni(r, Color(1.0, 0.88, 0.65), 4.0, st.to3(Vector2(960, 400), 2.0), 9.0)
	lamp.shadow_enabled = not Settings.b("video", "handheld")


func _coin(k: int) -> MeshInstance3D:
	while _coins3.size() <= k:
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = CHIP_R * stage.px3
		cm.bottom_radius = cm.top_radius
		cm.height = 7.0 * stage.px3
		cm.radial_segments = 20
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = cm
		stage.root.add_child(mi)
		_coins3.append(mi)
	return _coins3[k]


func _sync_3d() -> void:
	if _tray3 == null:
		return
	var px: float = stage.px3
	var w: float = TRAY_W * widen()
	_tray3.position = stage.to3(Vector2(_x, TRAY_Y + 18.0), 0.0)
	var fl: MeshInstance3D = _tray3.get_node("floor") as MeshInstance3D
	fl.scale = Vector3(w * px, 1, 1)
	(_tray3.get_node("side0") as Node3D).position = Vector3(-(w * 0.5 + 5.0) * px, 6.0 * px, 0)
	(_tray3.get_node("side2") as Node3D).position = Vector3((w * 0.5 + 5.0) * px, 6.0 * px, 0)
	var k: int = 0
	for c: Dictionary in _chips:
		var mi: MeshInstance3D = _coin(k)
		mi.visible = true
		mi.material_override = _fake_mat if bool(c["bad"]) else _gold_mat
		mi.position = stage.to3(c["p"] as Vector2, 0.0)
		mi.basis = Basis(Vector3.UP, float(c["spin"])) * Basis(Vector3.RIGHT, PI * 0.5)
		k += 1
	for j: int in range(k, _coins3.size()):
		_coins3[j].visible = false
	# Pile des jetons attrapés dans le plateau.
	while _pile3.size() < mini(_caught, 12):
		var pm: MeshInstance3D = Stage3D.cylinder(_tray3, CHIP_R * px, 7.0 * px, Vector3.ZERO, _gold_mat)
		_pile3.append(pm)
	for j: int in _pile3.size():
		var col: int = j % 4
		_pile3[j].position = Vector3((float(col) - 1.5) * CHIP_R * 2.1 * px, (float(j / 4) * 8.0 + 4.0) * px, 0)


func _progress() -> float:
	return clampf(t / (p("duration") * slow), 0.0, 1.0)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_x = mm.position.x
		return true
	return false


func _spawn() -> void:
	var bad: bool = rng.randf() < p("bad_ratio")
	var x: float = rng.randf_range(FIELD_X.x, FIELD_X.y)
	var sp: float = lerpf(p("fall_speed_start"), p("fall_speed_end"), _progress()) / slow
	_chips.append({"p": Vector2(x, 150.0), "v": sp, "bad": bad, "spin": rng.randf() * TAU})
	if not bad:
		_good_total += 1


func tick(dt: float) -> void:
	if _ended:
		return
	var v: float = held_vector().x + _bot_axis
	_x += clampf(v, -1.0, 1.0) * p("tray_speed") * dt
	if mouse and _mouse_x >= 0.0:
		_x = _mouse_x
	_x = clampf(_x, FIELD_X.x, FIELD_X.y)
	_spawn_t -= dt
	if _spawn_t <= 0.0 and t < p("duration") * slow:
		_spawn()
		_spawn_t = lerpf(p("spawn_start"), p("spawn_end"), _progress()) * slow
	var kept: Array[Dictionary] = []
	for c: Dictionary in _chips:
		var pos: Vector2 = c["p"]
		pos.y += float(c["v"]) * dt
		c["p"] = pos
		c["spin"] = float(c["spin"]) + dt * 6.0
		if absf(pos.y - TRAY_Y) < 18.0 and absf(pos.x - _x) < TRAY_W * 0.5 * widen() + CHIP_R * 0.5:
			if bool(c["bad"]):
				_bad += 1
				AudioBus.play("curse", 1.2, -4.0)
				pop(pos + Vector2(0, -40), 0.0, "TRIAL_CATCH_FAKE")
			else:
				_caught += 1
				AudioBus.play("chip_place", 0.9 + 0.02 * float(_caught % 12))
			continue
		if pos.y < size.y + 40.0:
			kept.append(c)
	_chips = kept
	if t >= p("duration") * slow and _chips.is_empty():
		_ended = true
		var sc: float = float(_caught) / maxf(float(_good_total), 1.0) - p("bad_penalty") * float(_bad)
		finish(clampf(sc, 0.0, 1.0))


func bot_wants() -> Dictionary:
	# Vise le premier jeton doré encore atteignable, en évitant les fausses pièces imminentes.
	var goal: float = _x
	var best_t: float = INF
	var half: float = TRAY_W * 0.5 * widen()
	for c: Dictionary in _chips:
		var pos: Vector2 = c["p"]
		if bool(c["bad"]) or pos.y > TRAY_Y + 5.0:
			continue
		var arrive: float = (TRAY_Y - pos.y) / maxf(float(c["v"]), 1.0)
		var travel: float = maxf(absf(pos.x - _x) - half * 0.6, 0.0) / p("tray_speed")
		if travel <= arrive and arrive < best_t:
			best_t = arrive
			goal = pos.x
	for c: Dictionary in _chips:
		var pos: Vector2 = c["p"]
		var arrive: float = (TRAY_Y - pos.y) / maxf(float(c["v"]), 1.0)
		if bool(c["bad"]) and arrive > 0.0 and arrive < minf(best_t, 0.35) and absf(pos.x - goal) < half + CHIP_R:
			goal = pos.x + (half + CHIP_R * 2.0) * (1.0 if goal >= pos.x else -1.0)
	return {"do": "axis", "v": Vector2(clampf((goal - _x) / 40.0, -1.0, 1.0), 0.0)}


func bot_apply(want: Dictionary) -> void:
	if String(want.get("do", "")) == "axis":
		_bot_axis = (want["v"] as Vector2).x
	else:
		_bot_axis = 0.0


func paint() -> void:
	_sync_3d()
	var info: String = tr("TRIAL_CATCH_STATUS") % [_caught, _good_total, _bad]
	text(Vector2(size.x * 0.5, 230.0), info, UiKit.SIZE_H2, Palette.IVORY)
	var left: float = clampf(1.0 - t / (p("duration") * slow), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 300, 270, 600 * left, 10), Palette.GOLD)
