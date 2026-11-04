class_name TrialCatch
extends ThrowTrial
## LA PLUIE DU GRAND LUSTRE (écran dédié) : la salle de bal du Grand Zéro prend l'eau… en
## jetons. Sous le lustre de cristal qui se balance, le plateau de croupier (inertie, il
## s'incline) attrape jetons (1) et plaques (3), évite les fausses pièces violettes (pénalité),
## les bouteilles et les cigares (plateau étourdi). Bonus : aimant, plateau large, ralenti, ×2.
## La pile grossit et vacille : « vider » la met à l'abri, trop haute ou trop secouée elle se
## renverse. Prises enchaînées = multiplicateur. Quatre vagues : bruine, rafale du ventilateur
## (vent latéral), zigzags, puis le lustre se décroche.
## Note = valeur mise à l'abri / valeur dorée tombée, moins les pénalités.

const TRAY_W: float = 220.0
const TRAY_Y: float = 900.0
const SPAWN_Y: float = 170.0
const CHIP_R: float = 22.0
const FIELD_X: Vector2 = Vector2(260.0, 1660.0)
const REACH_FRAC: float = 0.55
const FAKE: Color = Color("b03aff")
const KINDS: Array[String] = ["chip", "plaque", "fake", "bottle", "cigar", "bonus"]
const BONUSES: Array[String] = ["magnet", "wide", "slow", "double"]
const BONUS_COLORS: Dictionary[String, Color] = {
	"magnet": Color("ff4d6d"), "wide": Color("2ee6a8"), "slow": Color("29e0ff"), "double": Color("ffd23f"),
}
const WAVE_KEYS: Array[String] = ["TRIAL_CATCH_WAVE_1", "TRIAL_CATCH_WAVE_2", "TRIAL_CATCH_WAVE_3", "TRIAL_CATCH_WAVE_4"]
const CRYSTALS: int = 18
const PILE_SHOWN: int = 16
const LAMP_ENERGY: float = 2.6
## Bandeau d'information sous le lustre.
const HUD_Y: float = 330.0

var _x: float = 960.0
var _v: float = 0.0
var _items: Array[Dictionary] = []
var _spawn_t: float = 0.0
var _last_good_x: float = (FIELD_X.x + FIELD_X.y) * 0.5
var _good_total: float = 0.0
var _banked: float = 0.0
var _stack_val: float = 0.0
var _stack_n: int = 0
var _wobble: float = 0.0
var _penalty: float = 0.0
var _combo: int = 0
var _stun: float = 0.0
var _bonus: Dictionary[String, float] = {}
var _bonus_plan: Array[String] = []
var _bonus_next: int = 0
var _wave: int = -1
var _wave_flash: float = 0.0
var _mouse_x: float = -1.0
var _bot_axis: float = 0.0
var _bot_bank: bool = false
var _ended: bool = false
var _sway: float = 0.0
# Scène 3D
var _pool: Dictionary[String, Array] = {}
var _mats: Dictionary[String, Material] = {}
var _tray3: Node3D = null
var _pile3: Array[MeshInstance3D] = []
var _lustre: Node3D = null
var _lamp: OmniLight3D = null
var _sconces: Array[OmniLight3D] = []
var _ghost: Node3D = null
var _shards: CPUParticles3D = null
var _flicker: float = 0.0


func begin() -> void:
	_x = size.x * 0.5
	var plan: Array[String] = BONUSES.duplicate()
	for i: int in range(plan.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = plan[i]
		plan[i] = plan[j]
		plan[j] = tmp
	_bonus_plan = plan
	_build_3d()


func _dur() -> float:
	return p("duration") * slow


func _progress() -> float:
	return clampf(t / _dur(), 0.0, 1.0)


func _fall_scale() -> float:
	return p("slow_factor") if _bonus.has("slow") else 1.0


func _tray_half() -> float:
	return TRAY_W * 0.5 * widen() * (p("wide_factor") if _bonus.has("wide") else 1.0)


func _mult() -> float:
	return minf(1.0 + floorf(float(_combo) / p("combo_step")) * p("combo_bonus"), p("combo_max"))


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.env.background_color = Color(0.03, 0.02, 0.04)
	st.env.ambient_light_energy = 0.32
	st.key.light_energy = 0.3
	st.frontal(0.005, Vector2(960.0, 540.0), 1080.0, 40.0)
	var r: Node3D = st.root
	var px: float = st.px3
	var wide: float = 1920.0 * px * 2.2  # débord du décor (écrans larges)
	# Mur tendu de velours, lambris, pilastres dorés et appliques.
	Stage3D.box(r, Vector3(wide, 1080.0 * px * 1.6, 0.1), Vector3(0, 0, -1.4), Stage3D.mat(Color(0.16, 0.05, 0.1), 0.0, 0.95))
	Stage3D.box(r, Vector3(wide, 220.0 * px, 0.12), st.to3(Vector2(960, 860), -1.3), Stage3D.mat(Color(0.2, 0.1, 0.06), 0.0, 0.7))
	var gilt: StandardMaterial3D = Stage3D.mat(Palette.GOLD.darkened(0.35), 0.85, 0.35)
	for k: int in 13:
		var x: float = -360.0 + float(k) * 240.0  # aucun pilastre derrière le lustre
		Stage3D.box(r, Vector3(26.0 * px, 760.0 * px, 0.08), st.to3(Vector2(x, 560), -1.25), gilt)
		if k % 2 == 0:
			var sc: Vector3 = st.to3(Vector2(x, 420), -1.1)
			Stage3D.sphere(r, 10.0 * px, sc, Stage3D.glow(Color(1.0, 0.78, 0.45), 2.5))
			_sconces.append(Stage3D.omni(r, Color(1.0, 0.7, 0.4), 0.6, sc + Vector3(0, 0, 0.3), 2.2))
	# Plafond à caissons qui fuit.
	var wood: StandardMaterial3D = Stage3D.mat(Color(0.22, 0.12, 0.07), 0.0, 0.8)
	Stage3D.box(r, Vector3(wide, 60.0 * px, 1.6), st.to3(Vector2(960, 120), -0.5), wood)
	for k2: int in 16:
		var hole: Vector3 = st.to3(Vector2(-200.0 + float(k2) * 160.0, 152), 0.25)
		Stage3D.box(r, Vector3(90.0 * px, 0.03, 0.5), hole, Stage3D.mat(Color(0.05, 0.03, 0.03)))
		Stage3D.box(r, Vector3(8.0 * px, 0.03, 0.55), hole + Vector3(48.0 * px, 0, 0), gilt)
	# Parquet et tapis rouge.
	Stage3D.box(r, Vector3(wide, 0.1, 3.2), st.to3(Vector2(960, TRAY_Y + 72.0), 0.0), Stage3D.mat(Color(0.3, 0.17, 0.09), 0.0, 0.6))
	Stage3D.box(r, Vector3(1500.0 * px, 0.11, 0.9), st.to3(Vector2(960, TRAY_Y + 74.0), 0.2), Stage3D.mat(Color(0.5, 0.05, 0.1), 0.0, 0.9))
	_build_balcony(st, gilt)
	_build_lustre(st)
	_build_tray(st)
	_mats["chip"] = _glowing(Palette.GOLD, 0.35, 0.5)
	_mats["plaque"] = _glowing(Palette.IVORY, 0.25, 0.3)
	_mats["fake"] = _glowing(FAKE, 0.45, 0.4)
	_mats["bottle"] = Stage3D.mat(Color(0.1, 0.45, 0.2), 0.2, 0.15)
	_mats["cigar"] = Stage3D.mat(Color(0.45, 0.25, 0.12), 0.0, 0.8)
	for b: String in BONUSES:
		_mats["bonus_" + b] = _glowing(BONUS_COLORS[b], 1.6, 0.2)
	var dust: CPUParticles3D = CPUParticles3D.new()
	dust.amount = RenderQuality.particles(60)
	dust.lifetime = 6.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(wide * 0.5, 1080.0 * px * 0.5, 0.6)
	dust.gravity = Vector3(0, -0.02, 0)
	dust.initial_velocity_min = 0.01
	dust.initial_velocity_max = 0.05
	var dm: SphereMesh = SphereMesh.new()
	dm.radius = 2.0 * px
	dm.height = 4.0 * px
	dust.mesh = dm
	dust.material_override = Stage3D.glow(Color(1.0, 0.9, 0.7), 0.8)
	dust.position = Vector3(0, 0, -0.6)
	r.add_child(dust)


func _glowing(col: Color, energy: float, rough: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = Stage3D.mat(col, 0.5, rough)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


## Balcon à balustres et croupier fantôme qui regarde la pluie.
func _build_balcony(st: Stage3D, gilt: StandardMaterial3D) -> void:
	var px: float = st.px3
	var r: Node3D = st.root
	var y: float = 470.0
	Stage3D.box(r, Vector3(520.0 * px, 16.0 * px, 0.3), st.to3(Vector2(1640, y), -0.9), gilt)
	Stage3D.box(r, Vector3(520.0 * px, 20.0 * px, 0.35), st.to3(Vector2(1640, y + 110.0), -0.9), Stage3D.mat(Color(0.25, 0.13, 0.08)))
	for k: int in 11:
		Stage3D.cylinder(r, 6.0 * px, 100.0 * px, st.to3(Vector2(1395.0 + float(k) * 49.0, y + 56.0), -0.9), gilt)
	_ghost = Node3D.new()
	r.add_child(_ghost)
	_ghost.position = st.to3(Vector2(1680, y - 70.0), -1.0)
	var ecto: StandardMaterial3D = Stage3D.glow(Color(0.55, 0.95, 1.0), 0.9)
	ecto.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ecto.albedo_color.a = 0.35
	Stage3D.box(_ghost, Vector3(70.0 * px, 110.0 * px, 0.2), Vector3.ZERO, ecto)
	Stage3D.sphere(_ghost, 30.0 * px, Vector3(0, 85.0 * px, 0), ecto)
	Stage3D.box(_ghost, Vector3(36.0 * px, 12.0 * px, 0.22), Vector3(0, 52.0 * px, 0.02), Stage3D.mat(Color(0.05, 0.05, 0.08)))


## Lustre de cristal : anneaux dorés et pampilles, lumière qui vacille.
func _build_lustre(st: Stage3D) -> void:
	var px: float = st.px3
	_lustre = Node3D.new()
	st.root.add_child(_lustre)
	_lustre.position = st.to3(Vector2(960, 150), 0.3)
	var gold: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.9, 0.25)
	Stage3D.cylinder(_lustre, 3.0 * px, 60.0 * px, Vector3(0, 30.0 * px, 0), gold)
	var crystal: StandardMaterial3D = Stage3D.glow(Color(0.85, 0.95, 1.0), 1.2)
	crystal.metallic = 0.3
	crystal.roughness = 0.05
	for tier: int in 3:
		var rr: float = (150.0 - float(tier) * 45.0) * px
		var yy: float = -float(tier) * 34.0 * px
		Stage3D.cylinder(_lustre, rr, 6.0 * px, Vector3(0, yy, 0), gold)
		for k: int in CRYSTALS / 3:
			var a: float = TAU * float(k) / float(CRYSTALS / 3) + float(tier) * 0.3
			var at: Vector3 = Vector3(cos(a) * rr, yy - 22.0 * px, sin(a) * rr * 0.4)
			Stage3D.box(_lustre, Vector3(8.0 * px, 30.0 * px, 8.0 * px), at, crystal)
	_lamp = Stage3D.omni(st.root, Color(1.0, 0.88, 0.65), LAMP_ENERGY, st.to3(Vector2(960, 300), 2.5), 9.0)
	_lamp.shadow_enabled = RenderQuality.shadows()
	_shards = CPUParticles3D.new()
	_shards.emitting = false
	_shards.one_shot = true
	_shards.explosiveness = 0.9
	_shards.amount = RenderQuality.particles(40)
	_shards.lifetime = 1.6
	_shards.direction = Vector3(0, -1, 0)
	_shards.spread = 70.0
	_shards.initial_velocity_min = 0.6
	_shards.initial_velocity_max = 1.8
	_shards.gravity = Vector3(0, -4.0, 0)
	var sm: BoxMesh = BoxMesh.new()
	sm.size = Vector3.ONE * 6.0 * px
	_shards.mesh = sm
	_shards.material_override = crystal
	_lustre.add_child(_shards)


func _build_tray(st: Stage3D) -> void:
	var px: float = st.px3
	_tray3 = Node3D.new()
	st.root.add_child(_tray3)
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD.darkened(0.2), 0.9, 0.3)
	Stage3D.box(_tray3, Vector3(1, 18.0 * px, 0.5), Vector3(0, -9.0 * px, 0), brass).name = "floor"
	for side: int in 2:
		Stage3D.box(_tray3, Vector3(10.0 * px, 48.0 * px, 0.5), Vector3.ZERO, brass).name = "side%d" % side


func _mesh_for(kind: String, idx: int) -> MeshInstance3D:
	var key: String = "bonus" if kind.begins_with("bonus") else kind
	if not _pool.has(key):
		_pool[key] = []
	var list: Array = _pool[key]
	while list.size() <= idx:
		var px: float = stage.px3
		var mesh: Mesh = null
		match key:
			"plaque":
				var bm: BoxMesh = BoxMesh.new()
				bm.size = Vector3(64.0 * px, 36.0 * px, 6.0 * px)
				mesh = bm
			"bottle":
				var cm: CylinderMesh = CylinderMesh.new()
				cm.top_radius = 7.0 * px
				cm.bottom_radius = 16.0 * px
				cm.height = 70.0 * px
				mesh = cm
			"cigar":
				var cp: CapsuleMesh = CapsuleMesh.new()
				cp.radius = 8.0 * px
				cp.height = 70.0 * px
				mesh = cp
			"bonus":
				var sp: SphereMesh = SphereMesh.new()
				sp.radius = 26.0 * px
				sp.height = 52.0 * px
				mesh = sp
			_:
				var cy: CylinderMesh = CylinderMesh.new()
				cy.top_radius = CHIP_R * px
				cy.bottom_radius = CHIP_R * px
				cy.height = 7.0 * px
				cy.radial_segments = 20
				mesh = cy
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		stage.root.add_child(mi)
		list.append(mi)
	return list[idx] as MeshInstance3D


func _sync_3d(dt: float) -> void:
	if _tray3 == null:
		return
	var px: float = stage.px3
	var half: float = _tray_half()
	_tray3.position = stage.to3(Vector2(_x, TRAY_Y + 18.0), 0.0)
	_tray3.rotation.z = -_v / maxf(p("tray_speed"), 1.0) * 0.22 + (sin(t * 40.0) * 0.08 if _stun > 0.0 else 0.0)
	(_tray3.get_node("floor") as Node3D).scale = Vector3(half * 2.0 * px, 1, 1)
	(_tray3.get_node("side0") as Node3D).position = Vector3(-(half + 5.0) * px, 6.0 * px, 0)
	(_tray3.get_node("side1") as Node3D).position = Vector3((half + 5.0) * px, 6.0 * px, 0)
	var used: Dictionary[String, int] = {}
	for it: Dictionary in _items:
		var kind: String = String(it["kind"])
		var key: String = "bonus" if kind == "bonus" else kind
		var i: int = used.get(key, 0)
		used[key] = i + 1
		var mi: MeshInstance3D = _mesh_for(key, i)
		mi.visible = true
		mi.material_override = _mats["bonus_" + String(it["bonus"])] if kind == "bonus" else _mats[kind]
		mi.position = stage.to3(it["p"] as Vector2, 0.0)
		var spin: float = float(it["spin"])
		match kind:
			"chip", "fake":
				mi.basis = Basis(Vector3.UP, spin) * Basis(Vector3.RIGHT, PI * 0.5)
			"bonus":
				mi.basis = Basis(Vector3.UP, spin)
			_:
				mi.basis = Basis(Vector3.BACK, spin * 0.6)
	for key2: String in _pool.keys():
		var list: Array = _pool[key2]
		for j: int in range(int(used.get(key2, 0)), list.size()):
			(list[j] as Node3D).visible = false
	# Pile du plateau : elle oscille avec le vacillement.
	while _pile3.size() < PILE_SHOWN:
		var pm: MeshInstance3D = Stage3D.cylinder(_tray3, CHIP_R * px, 7.0 * px, Vector3.ZERO, _mats["chip"])
		_pile3.append(pm)
	for j2: int in _pile3.size():
		_pile3[j2].visible = j2 < _stack_n
		var lean: float = sin(t * 9.0) * _wobble * float(j2) * 1.6
		_pile3[j2].position = Vector3(lean * px, (float(j2) * 8.0 + 4.0) * px, 0)
	# Lustre : balancement qui grandit avec les vagues, lumière qui vacille.
	_sway += dt
	var amp: float = 0.03 + 0.03 * float(maxi(_wave, 0))
	_lustre.rotation.z = sin(_sway * 1.3) * amp
	if _wave >= 3:
		_lustre.position.y = lerpf(_lustre.position.y, stage.to3(Vector2(960, 190), 0.3).y, dt)
	_flicker = maxf(0.0, _flicker - dt)
	_lamp.light_energy = LAMP_ENERGY * (0.55 if _flicker > 0.0 and fmod(t * 20.0, 1.0) < 0.5 else 1.0)
	for k: int in _sconces.size():
		_sconces[k].light_energy = 0.6 + 0.15 * sin(t * 7.0 + float(k))
	_ghost.position.y += sin(t * 2.0) * 0.0006


# --------------------------------------------------------------------------- jeu


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_x = mm.position.x
		return true
	if confirm_pressed(event):
		_bank()
		return true
	return false


func _wave_at(pr: float) -> int:
	var starts: Array = Balance.arr("throw_trials.catch.waves")
	var w: int = 0
	for i: int in starts.size():
		if pr >= float(starts[i]):
			w = i
	return w


func _pick_kind() -> String:
	var roll: float = rng.randf()
	var hazard: float = p("hazard_ratio") if _wave >= 2 else 0.0
	var plaque: float = p("plaque_ratio") * (2.0 if _wave >= 3 else (1.0 if _wave >= 1 else 0.0))
	if roll < p("bad_ratio"):
		return "fake"
	if roll < p("bad_ratio") + hazard:
		return "bottle" if rng.randf() < 0.5 else "cigar"
	if roll < p("bad_ratio") + hazard + plaque:
		return "plaque"
	return "chip"


func _spawn(kind: String, bonus: String = "") -> void:
	var good: bool = kind in ["chip", "plaque", "bonus"]
	var sp: float = lerpf(p("fall_speed_start"), p("fall_speed_end"), _progress()) / slow
	if kind == "plaque":
		sp *= p("plaque_speed")
	var fall_t: float = (TRAY_Y - SPAWN_Y) / sp
	var wind: float = p("wind_speed") * (1.0 if rng.randf() < 0.5 else -1.0) if _wave == 1 else 0.0
	var zig: float = p("zig_amp") if _wave >= 2 else 0.0
	var phase: float = rng.randf() * TAU
	var land: float = rng.randf_range(FIELD_X.x, FIELD_X.y)
	if good:
		# Toujours atteignable depuis la prise précédente : une partie parfaite reste possible.
		var gap: float = lerpf(p("spawn_start"), p("spawn_end"), _progress()) * slow
		var reach: float = p("tray_speed") * gap * REACH_FRAC
		land = clampf(land, _last_good_x - reach, _last_good_x + reach)
		land = clampf(land, FIELD_X.x, FIELD_X.y)
		_last_good_x = land
		if kind != "bonus":
			_good_total += _value(kind)
	var base: float = land - wind * fall_t - zig * sin(p("zig_freq") * fall_t + phase)
	_items.append({
		"kind": kind, "bonus": bonus, "base": base, "age": 0.0, "v": sp, "wind": wind, "zig": zig,
		"ph": phase, "mx": 0.0, "land": land, "p": Vector2(base, SPAWN_Y), "spin": rng.randf() * TAU,
	})


func _value(kind: String) -> float:
	return p("plaque_value") if kind == "plaque" else 1.0


func _bank() -> void:
	if _stack_n <= 0 or _ended:
		return
	_banked += _stack_val
	pop(Vector2(_x, TRAY_Y - 140.0), 1.0, "TRIAL_CATCH_BANKED")
	AudioBus.play("chips_win", 1.0, -4.0)
	_stack_val = 0.0
	_stack_n = 0
	_wobble = 0.0


func _topple() -> void:
	pop(Vector2(_x, TRAY_Y - 140.0), 0.0, "TRIAL_CATCH_TOPPLE")
	AudioBus.play("decor_topple", 1.0, -2.0)
	_penalty += p("topple_penalty")
	_stack_val = 0.0
	_stack_n = 0
	_wobble = 0.0
	_combo = 0


func tick(dt: float) -> void:
	if _ended:
		return
	var w: int = _wave_at(_progress())
	if w != _wave:
		_wave = w
		_wave_flash = 1.6
		_flicker = 0.6
		if w > 0:
			AudioBus.play("chandelier", 0.9 + 0.1 * float(w), -3.0)
			if _shards != null:
				_shards.restart()
				_shards.emitting = true
		if w == 1:
			AudioBus.play("gust", 1.0, -2.0)
	_wave_flash = maxf(0.0, _wave_flash - dt)
	for b: String in _bonus.keys():
		_bonus[b] = _bonus[b] - dt
		if _bonus[b] <= 0.0:
			_bonus.erase(b)
	# Plateau : inertie (on accélère vers la vitesse voulue), étourdi par une bouteille ou un cigare.
	_stun = maxf(0.0, _stun - dt)
	var wish: float = 0.0
	if _stun <= 0.0:
		wish = clampf(held_vector().x + _bot_axis, -1.0, 1.0) * p("tray_speed")
		if (mouse or direct) and _mouse_x >= 0.0:
			wish = clampf((_mouse_x - _x) * p("mouse_gain"), -p("tray_speed"), p("tray_speed"))
	var dv: float = (wish - _v) * minf(1.0, p("tray_accel") * dt)
	_v += dv
	_x += _v * dt
	if _x < FIELD_X.x or _x > FIELD_X.y:
		_x = clampf(_x, FIELD_X.x, FIELD_X.y)
		_v = 0.0
	# La pile vacille aux à-coups ; trop haute ou trop secouée, elle tombe.
	var load_k: float = float(_stack_n) / maxf(p("stack_max"), 1.0)
	_wobble += absf(dv) / maxf(p("tray_speed"), 1.0) * p("wobble_gain") * load_k
	_wobble *= exp(-p("wobble_decay") * dt)
	if _stack_n > 0 and (_wobble >= 1.0 or _stack_n > pi("stack_max")):
		_topple()
	if _bot_bank:
		_bank()
	# Apparitions et bonus programmés.
	_spawn_t -= dt
	if _spawn_t <= 0.0 and t < _dur():
		_spawn(_pick_kind())
		var gap: float = lerpf(p("spawn_start"), p("spawn_end"), _progress()) * slow
		_spawn_t = gap * (p("finale_gap") if _wave >= 3 else 1.0)
	var at: Array = Balance.arr("throw_trials.catch.bonus_at")
	if _bonus_next < at.size() and _progress() >= float(at[_bonus_next]):
		_spawn("bonus", _bonus_plan[_bonus_next % _bonus_plan.size()])
		_bonus_next += 1
	_move_items(dt)
	if t >= _dur() and _items.is_empty():
		_ended = true
		_banked += _stack_val
		var sc: float = _banked / maxf(_good_total, 1.0) - _penalty
		finish(clampf(sc, 0.0, 1.0))


func _move_items(dt: float) -> void:
	var half: float = _tray_half()
	var kept: Array[Dictionary] = []
	for it: Dictionary in _items:
		var age: float = float(it["age"]) + dt * _fall_scale()
		it["age"] = age
		if _bonus.has("magnet") and String(it["kind"]) in ["chip", "plaque"]:
			var pos0: Vector2 = it["p"]
			if pos0.y > TRAY_Y - p("magnet_radius"):
				it["mx"] = float(it["mx"]) + signf(_x - pos0.x) * p("magnet_pull") * dt
		var x: float = float(it["base"]) + float(it["wind"]) * age + float(it["zig"]) * sin(p("zig_freq") * age + float(it["ph"]))
		var pos: Vector2 = Vector2(x + float(it["mx"]), SPAWN_Y + float(it["v"]) * age)
		it["p"] = pos
		it["spin"] = float(it["spin"]) + dt * 6.0
		if absf(pos.y - TRAY_Y) < 18.0 and absf(pos.x - _x) < half + CHIP_R * 0.5:
			_catch(it, pos)
			continue
		if pos.y >= TRAY_Y + 18.0 and String(it["kind"]) in ["chip", "plaque"] and float(it["seen"] if it.has("seen") else 0.0) == 0.0:
			it["seen"] = 1.0
			_combo = 0  # une pièce dorée manquée casse l'enchaînement
		if pos.y < size.y + 60.0:
			kept.append(it)
	_items = kept


func _catch(it: Dictionary, pos: Vector2) -> void:
	var kind: String = String(it["kind"])
	match kind:
		"fake":
			_penalty += p("bad_penalty")
			_combo = 0
			AudioBus.play("curse", 1.2, -4.0)
			pop(pos + Vector2(0, -40), 0.0, "TRIAL_CATCH_FAKE")
		"bottle", "cigar":
			_stun = p("stun_seconds")
			_v = 0.0
			_wobble += p("stun_wobble")
			_combo = 0
			AudioBus.play("decor_bottle" if kind == "bottle" else "cloth", 1.0, -3.0)
			pop(pos + Vector2(0, -40), 0.0, "TRIAL_CATCH_STUN")
		"bonus":
			var b: String = String(it["bonus"])
			_bonus[b] = p("bonus_seconds") * slow
			AudioBus.play("transform", 1.1, -3.0)
			pop(pos + Vector2(0, -50), 1.0, "TRIAL_CATCH_BONUS_" + b.to_upper())
		_:
			_combo += 1
			var gain: float = _value(kind) * _mult() * (2.0 if _bonus.has("double") else 1.0)
			_stack_val += gain
			_stack_n += 1 if kind == "chip" else 2
			AudioBus.play("chip_place", 0.9 + 0.02 * float(_combo % 12))
			if _combo > 0 and _combo % int(p("combo_step")) == 0:
				AudioBus.play("mult", 1.0 + 0.1 * _mult(), -6.0)


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	# Vise la prochaine pièce dorée (ou bonus) atteignable, évite fausses pièces et obstacles,
	# vide la pile avant qu'elle ne soit trop haute.
	var half: float = _tray_half()
	var goal: float = _x
	var best_t: float = INF
	for it: Dictionary in _items:
		var kind: String = String(it["kind"])
		var pos: Vector2 = it["p"]
		if not kind in ["chip", "plaque", "bonus"] or pos.y > TRAY_Y + 5.0:
			continue
		var arrive: float = (TRAY_Y - pos.y) / maxf(float(it["v"]) * _fall_scale(), 1.0)
		var lx: float = _landing(it)
		var travel: float = maxf(absf(lx - _x) - half * 0.6, 0.0) / p("tray_speed") + 0.12
		if travel <= arrive and arrive < best_t:
			best_t = arrive
			goal = lx
	# Esquive : plusieurs passes, un écart peut en appeler un autre (deux obstacles voisins).
	for _pass: int in 3:
		for it2: Dictionary in _items:
			var kind2: String = String(it2["kind"])
			if kind2 in ["chip", "plaque", "bonus"]:
				continue
			var pos2: Vector2 = it2["p"]
			var arrive2: float = (TRAY_Y - pos2.y) / maxf(float(it2["v"]) * _fall_scale(), 1.0)
			var lx2: float = _landing(it2)
			if arrive2 > 0.0 and arrive2 < minf(best_t, 0.5) and absf(lx2 - goal) < half + CHIP_R * 1.5:
				var side: float = 1.0 if goal >= lx2 else -1.0
				if lx2 + side * (half + CHIP_R * 3.0) < FIELD_X.x or lx2 + side * (half + CHIP_R * 3.0) > FIELD_X.y:
					side = -side  # contre le bord : on esquive de l'autre côté
				goal = lx2 + (half + CHIP_R * 3.0) * side
	# Commande PD : freine à l'approche (le plateau a de l'inertie).
	var axis: float = clampf(((goal - _x) * 6.0 - _v * 0.9) / p("tray_speed"), -1.0, 1.0)
	var bank: bool = _stack_n >= int(p("stack_max") * 0.35) or _wobble > 0.3 or _stun > 0.0
	if bank and _stack_n > 0:
		return {"do": "confirm"}
	return {"do": "axis", "v": Vector2(axis, 0.0)}


func _landing(it: Dictionary) -> float:
	return float(it["land"]) + float(it["mx"])


func bot_apply(want: Dictionary) -> void:
	# Un geste par image, comme à la vraie manette (stick, ou valider pour vider).
	var act: String = String(want.get("do", ""))
	_bot_axis = (want["v"] as Vector2).x if act == "axis" else 0.0
	_bot_bank = act == "confirm"


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if direct:
		_draw_bank_button()
	_sync_3d(get_process_delta_time())
	var total: float = _banked + _stack_val
	var status: String = tr("TRIAL_CATCH_STATUS") % roundi(total)
	text(Vector2(size.x * 0.5, HUD_Y), status, UiKit.SIZE_H2, Palette.IVORY)
	var left: float = clampf(1.0 - t / _dur(), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 300, HUD_Y + 40.0, 600 * left, 10), Palette.GOLD)
	if _mult() > 1.0:
		var mult_s: String = "×%s" % String.num(_mult(), 2).trim_suffix("0").trim_suffix(".")
		text(Vector2(size.x * 0.5 + 420, HUD_Y), mult_s, UiKit.SIZE_H2, Palette.MULT_RED)
	if _wave >= 0:
		var a: float = clampf(_wave_flash, 0.0, 1.0)
		var wave_s: String = tr(WAVE_KEYS[mini(_wave, WAVE_KEYS.size() - 1)])
		text(Vector2(size.x * 0.5, HUD_Y + 90.0), wave_s, UiKit.SIZE_BODY, Color(Palette.GOLD_LIGHT, 0.55 + 0.45 * a))
	# Jauge de pile sous le plateau (orange puis rouge quand elle vacille).
	if _stack_n > 0:
		var cap: float = p("stack_max")
		var r: Rect2 = Rect2(_x - 60.0, TRAY_Y + 40.0, 120.0, 8.0)
		draw_rect(r, Color(Palette.INK, 0.8))
		var col: Color = Palette.EMERALD.lerp(Palette.MULT_RED, clampf(_wobble, 0.0, 1.0))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(float(_stack_n) / cap, 0.0, 1.0), r.size.y)), col)
	var bx: float = 300.0
	for b: String in _bonus.keys():
		text(Vector2(bx, HUD_Y), tr("TRIAL_CATCH_BONUS_" + b.to_upper()), UiKit.SIZE_SMALL, BONUS_COLORS[b])
		bx += 220.0


## Au doigt : le plateau suit le doigt ; toucher le bouton VIDER (sur le comptoir) met la pile
## à l'abri. Un toucher ailleurs ne vide jamais.
func direct_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and mb.position.distance_to(_bank_button()) <= p("bank_button_r"):
			_bank()
		elif mb.pressed:
			_mouse_x = mb.position.x
		return true
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and mm.button_mask & MOUSE_BUTTON_MASK_LEFT != 0 and mm.position.distance_to(_bank_button()) > p("bank_button_r"):
		_mouse_x = mm.position.x
	return true


func _bank_button() -> Vector2:
	var pr: Rect2 = play_rect()
	return Vector2(pr.end.x - p("bank_button_r") - 40.0, pr.end.y - p("bank_button_r") - 40.0)


func _draw_bank_button() -> void:
	var c: Vector2 = _bank_button()
	var r: float = p("bank_button_r")
	draw_circle(c, r, Color(Palette.INK, 0.85))
	draw_arc(c, r, 0, TAU, 48, Palette.GOLD if _stack_n > 0 else Palette.SMOKE, 4.0)
	text(c, tr("TOUCH_EMPTY"), UiKit.SIZE_H2, Palette.GOLD_LIGHT if _stack_n > 0 else Palette.SMOKE)
