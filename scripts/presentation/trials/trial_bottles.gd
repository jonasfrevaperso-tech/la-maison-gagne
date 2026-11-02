class_name TrialBottles
extends ThrowTrial
## LES BOUTEILLES (écran dédié) : au comptoir du bar abandonné, on lance des jetons sur des
## bouteilles de bière vides alignées sur l'étagère. Pour chaque jeton : un viseur balaie
## l'étagère (confirmer pour fixer la direction), puis une jauge de force oscille (confirmer dans
## la zone). La bouteille désignée vole en éclats si le tir est juste. Trois jetons, de plus en
## plus vite. Note = moyenne (direction pondérée, force).

enum Phase { AIM, POWER, FLIGHT, REST }

const BOTTLES: int = 6
const SHELF_Y: float = 520.0
const BOTTLE_W: float = 46.0
const BOTTLE_H: float = 150.0
const SHELF_X: Vector2 = Vector2(420.0, 1500.0)
const HAND: Vector2 = Vector2(960.0, 1010.0)
const GLASS: Array[Color] = [Color(0.45, 0.25, 0.08), Color(0.13, 0.4, 0.18), Color(0.55, 0.42, 0.12)]

var _phase: Phase = Phase.AIM
var _throw: int = 0
var _xs: PackedFloat32Array = PackedFloat32Array()
var _alive: Array[bool] = []
var _target: int = 0
var _aim_x: float = 0.0
var _aim_lock: float = 0.0
var _power: float = 0.0
var _scores: Array[float] = []
var _hit: bool = false
var _shards: Array[Dictionary] = []
var _phase_t: float = 0.0
## Valeurs de l'image précédente (le bot détecte le passage sur la cible).
var _prev_aim: float = 0.0
var _prev_power: float = 0.0
## Scène 3D : bouteilles de verre sur l'étagère, comptoir, mur de briques, néon « BAR ».
var _bottles3: Array[Node3D] = []
var _chip3: Node3D = null
var _neon: Label3D = null
var _neon_light: OmniLight3D = null


func begin() -> void:
	for k: int in BOTTLES:
		_xs.append(lerpf(SHELF_X.x, SHELF_X.y, (float(k) + 0.5) / float(BOTTLES)) + rng.randf_range(-20.0, 20.0))
		_alive.append(true)
	_build_3d()
	_next_target()


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.env.background_color = Color(0.05, 0.03, 0.03)
	st.key.light_energy = 0.3
	st.frontal(0.0042, Vector2(960.0, SHELF_Y), 1080.0, 40.0)
	var r: Node3D = st.root
	var px: float = st.px3
	# Mur de briques (texture procédurale), néon qui grésille.
	var wall: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.0, 0.95)
	wall.albedo_texture = _brick_texture()
	wall.uv1_scale = Vector3(16, 8, 1)
	wall.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	Stage3D.box(r, Vector3(1920.0 * px * 1.6, 1080.0 * px * 1.4, 0.1), st.to3(Vector2(960, 400), -0.6), wall)
	_neon = Stage3D.text3d(r, "BAR", st.to3(Vector2(960, 230), -0.5), 260, Palette.MAGENTA, Color("4a0a2a"))
	_neon_light = Stage3D.omni(r, Palette.MAGENTA, 1.6, st.to3(Vector2(960, 260), 0.0), 4.0)
	# Étagère.
	var shelf_w: float = (SHELF_X.y - SHELF_X.x + 240.0) * px
	Stage3D.box(r, Vector3(shelf_w, 22.0 * px, 0.32), st.to3(Vector2(960, SHELF_Y + 11.0), 0.0), Stage3D.mat(Color(0.36, 0.21, 0.1), 0.0, 0.6))
	for x: float in [SHELF_X.x - 60.0, SHELF_X.y + 60.0]:
		Stage3D.box(r, Vector3(0.04, 0.12, 0.25), st.to3(Vector2(x, SHELF_Y + 40.0), -0.02), Stage3D.mat(Color(0.3, 0.3, 0.32), 0.8, 0.3))
	# Bouteilles : corps, épaule, goulot, capsule, étiquette ; verre translucide.
	for k: int in BOTTLES:
		var b: Node3D = Node3D.new()
		b.position = st.to3(Vector2(_xs[k], SHELF_Y))
		r.add_child(b)
		var glass: StandardMaterial3D = Stage3D.mat(GLASS[k % GLASS.size()].lightened(0.15), 0.2, 0.08)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color.a = 0.78
		glass.rim_enabled = true
		glass.rim = 0.6
		var rad: float = BOTTLE_W * 0.5 * px
		var body_h: float = BOTTLE_H * 0.62 * px
		Stage3D.cylinder(b, rad, body_h, Vector3(0, body_h * 0.5, 0), glass)
		var sh_h: float = BOTTLE_H * 0.2 * px
		Stage3D.cylinder(b, rad, sh_h, Vector3(0, body_h + sh_h * 0.5, 0), glass, rad * 0.38)
		var neck_h: float = BOTTLE_H * 0.18 * px
		Stage3D.cylinder(b, rad * 0.38, neck_h, Vector3(0, body_h + sh_h + neck_h * 0.5, 0), glass)
		Stage3D.cylinder(b, rad * 0.46, 8.0 * px, Vector3(0, BOTTLE_H * px, 0), Stage3D.mat(Palette.GOLD, 0.8, 0.3))
		Stage3D.cylinder(b, rad * 1.02, 34.0 * px, Vector3(0, body_h * 0.55, 0), Stage3D.mat(Palette.IVORY.darkened(0.2), 0.0, 0.8))
		_bottles3.append(b)
	# Comptoir au premier plan.
	var top: Vector3 = st.to3(Vector2(960, 800), 0.0)
	Stage3D.box(r, Vector3(1920.0 * px * 1.3, 0.08, 0.9), Vector3(0, top.y, 0.9), Stage3D.mat(Color(0.42, 0.26, 0.12), 0.2, 0.35))
	Stage3D.box(r, Vector3(1920.0 * px * 1.3, 2.0, 0.1), Vector3(0, top.y - 1.0, 1.35), Stage3D.mat(Color(0.22, 0.12, 0.06), 0.0, 0.7))
	var lamp: OmniLight3D = Stage3D.omni(r, Color(1.0, 0.85, 0.6), 2.5, st.to3(Vector2(960, 300), 1.2), 6.0)
	lamp.shadow_enabled = not Settings.b("video", "handheld")
	# Jeton lancé.
	_chip3 = Node3D.new()
	r.add_child(_chip3)
	var chip_body: MeshInstance3D = Stage3D.cylinder(_chip3, 34.0 * px, 8.0 * px, Vector3.ZERO, Stage3D.mat(Palette.ROULETTE_RED, 0.1, 0.4))
	chip_body.rotation.x = PI * 0.5
	var ring: MeshInstance3D = Stage3D.cylinder(_chip3, 24.0 * px, 9.0 * px, Vector3.ZERO, Stage3D.mat(Palette.IVORY, 0.0, 0.5))
	ring.rotation.x = PI * 0.5


static func _brick_texture() -> ImageTexture:
	var w: int = 64
	var h: int = 32
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.05, 0.03, 0.03))
	for row: int in 4:
		var off: int = 0 if row % 2 == 0 else 8
		for col: int in 5:
			var shade: float = 0.1 + 0.03 * float((row * 7 + col * 13) % 5) / 4.0
			img.fill_rect(Rect2i(off + col * 16 - 8, row * 8 + 1, 15, 7), Color(shade + 0.06, shade * 0.6, shade * 0.5))
	return ImageTexture.create_from_image(img)


func _next_target() -> void:
	var standing: Array[int] = []
	for k: int in BOTTLES:
		if _alive[k]:
			standing.append(k)
	_target = standing[rng.randi_range(0, standing.size() - 1)]
	_phase = Phase.AIM
	_phase_t = 0.0


func _sweep() -> float:
	return pk("sweep_seconds", _throw) * slow


func handle(event: InputEvent) -> bool:
	if confirm_pressed(event):
		press()
		return true
	return false


func press() -> void:
	match _phase:
		Phase.AIM:
			_aim_lock = _aim_x
			_phase = Phase.POWER
			_phase_t = 0.0
			AudioBus.play("lock", 1.2, -6.0)
		Phase.POWER:
			_throw_chip()


func _power_at(tt: float) -> float:
	var period: float = p("power_seconds") * slow
	var u: float = fposmod(tt / period, 2.0)
	return u if u <= 1.0 else 2.0 - u


func _throw_chip() -> void:
	var zone: float = p("power_zone") * widen()
	var err_x: float = absf(_aim_lock - _xs[_target]) / (BOTTLE_W * 0.5 * p("neck_tolerance") * widen())
	var aim_sc: float = 1.0 if err_x <= 1.0 else clampf(1.0 - (err_x - 1.0) / p("miss_falloff"), 0.0, 1.0)
	var err_p: float = absf(_power - 0.75) / zone
	var pow_sc: float = 1.0 if err_p <= 0.35 else clampf(1.0 - (err_p - 0.35) / 1.3, 0.0, 1.0)
	var sc: float = aim_sc * p("weight_aim") + pow_sc * (1.0 - p("weight_aim"))
	_hit = aim_sc >= 0.99 and pow_sc >= 0.5
	_scores.append(sc)
	_phase = Phase.FLIGHT
	_phase_t = 0.0
	AudioBus.play("whoosh", 1.4, -6.0)


func _land() -> void:
	var sc: float = _scores[-1]
	if _hit:
		_alive[_target] = false
		AudioBus.play("shatter", 1.0 + rng.randf_range(-0.1, 0.1))
		EventBus.juice_shake.emit(0.25)
		for k: int in 14:
			var v: Vector2 = Vector2(rng.randf_range(-320, 320), rng.randf_range(-420, -60))
			_shards.append({"p": Vector2(_xs[_target], SHELF_Y - BOTTLE_H * 0.5), "v": v, "c": GLASS[_target % GLASS.size()], "t": 1.2})
	else:
		AudioBus.play("decor_bottle" if sc > 0.4 else "chip_lose", 1.0, -2.0)
	pop(Vector2(_xs[_target], SHELF_Y - BOTTLE_H - 40.0), sc)
	_phase = Phase.REST
	_phase_t = 0.0


func tick(dt: float) -> void:
	_phase_t += dt
	for sh: Dictionary in _shards:
		sh["v"] = (sh["v"] as Vector2) + Vector2(0, 900.0 * dt)
		sh["p"] = (sh["p"] as Vector2) + (sh["v"] as Vector2) * dt
		sh["t"] = float(sh["t"]) - dt
	_shards = _shards.filter(func(q: Dictionary) -> bool: return float(q["t"]) > 0.0)
	match _phase:
		Phase.AIM:
			var u: float = sin(_phase_t * TAU / _sweep() - PI * 0.5) * 0.5 + 0.5
			_aim_x = lerpf(SHELF_X.x - 60.0, SHELF_X.y + 60.0, u)
			if _phase_t > _sweep() * 3.0:
				press()  # le viseur se fige tout seul
		Phase.POWER:
			_power = _power_at(_phase_t)
			if _phase_t > p("power_seconds") * slow * 4.0:
				_throw_chip()
		Phase.FLIGHT:
			if _phase_t >= p("flight_seconds"):
				_land()
		Phase.REST:
			if _phase_t >= 0.7:
				_throw += 1
				if _throw >= pi("throws"):
					finish(mean(_scores))
				else:
					_next_target()


func bot_wants() -> Dictionary:
	var want: Dictionary = {"do": ""}
	match _phase:
		Phase.AIM:
			if _phase_t > 0.05 and (_prev_aim - _xs[_target]) * (_aim_x - _xs[_target]) <= 0.0:
				want = {"do": "confirm"}
		Phase.POWER:
			if _phase_t > 0.05 and (_prev_power - 0.75) * (_power - 0.75) <= 0.0:
				want = {"do": "confirm"}
	_prev_aim = _aim_x
	_prev_power = _power
	return want


func bot_apply(w: Dictionary) -> void:
	if String(w.get("do", "")) == "confirm":
		press()


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	_sync_3d()
	for k: int in BOTTLES:
		if _alive[k] and k == _target and _phase != Phase.REST:
			var pulse: float = 0.5 + 0.5 * sin(t * 8.0)
			var hl: Rect2 = Rect2(_xs[k] - BOTTLE_W * 0.8, SHELF_Y - BOTTLE_H - 14, BOTTLE_W * 1.6, BOTTLE_H + 18)
			draw_rect(hl, Color(Palette.GOLD_LIGHT, 0.3 + 0.4 * pulse), false, 3.0)
	for sh: Dictionary in _shards:
		var c: Color = sh["c"]
		c.a = clampf(float(sh["t"]), 0.0, 1.0)
		var sp: Vector2 = sh["p"]
		draw_colored_polygon(PackedVector2Array([sp, sp + Vector2(10, 4), sp + Vector2(3, 12)]), c.lightened(0.3))
	pips(Vector2(960, 110), _scores, pi("throws"))
	match _phase:
		Phase.AIM:
			_draw_reticle(_aim_x, Palette.CYAN)
		Phase.POWER:
			_draw_reticle(_aim_lock, Palette.GOLD_LIGHT)
			_draw_power()


func _sync_3d() -> void:
	if stage == null:
		return
	for k: int in _bottles3.size():
		_bottles3[k].visible = _alive[k]
		_bottles3[k].rotation.z = sin(t * 2.0 + float(k)) * 0.01
	var flick: float = 1.0 if fposmod(t * 7.3, 3.1) > 0.2 else 0.35
	_neon.modulate = Color(Palette.MAGENTA, flick)
	_neon_light.light_energy = 1.6 * flick
	var pos: Vector2 = HAND
	var spin: float = 0.0
	var depth: float = 1.45
	if _phase == Phase.FLIGHT:
		var u: float = clampf(_phase_t / p("flight_seconds"), 0.0, 1.0)
		var dest: Vector2 = Vector2(_aim_lock, SHELF_Y - BOTTLE_H * (0.35 + 0.6 * (_power - 0.4)))
		pos = HAND.lerp(dest, u) + Vector2(0, -260.0 * sin(u * PI))
		spin = _phase_t * 18.0
		depth = lerpf(1.45, 0.12, u)
	_chip3.position = stage.to3(pos, depth)
	_chip3.rotation = Vector3(spin, 0, 0)


func _draw_reticle(x: float, col: Color) -> void:
	var y: float = SHELF_Y - BOTTLE_H * 0.55
	draw_line(Vector2(x, y - 120), Vector2(x, SHELF_Y + 40), Color(col, 0.45), 2.0)
	draw_arc(Vector2(x, y), 26.0, 0, TAU, 32, col, 3.0, true)
	draw_line(Vector2(x - 38, y), Vector2(x - 14, y), col, 3.0)
	draw_line(Vector2(x + 14, y), Vector2(x + 38, y), col, 3.0)


func _draw_power() -> void:
	var r: Rect2 = Rect2(1640, 560, 54, 360)
	draw_rect(r, Palette.VELVET_DEEP)
	draw_rect(r, Palette.GOLD, false, 2.0)
	var zone: float = p("power_zone") * widen()
	var zy: float = r.end.y - r.size.y * (0.75 + zone)
	draw_rect(Rect2(r.position.x, zy, r.size.x, r.size.y * zone * 2.0), Color(Palette.GOLD, 0.55))
	var ny: float = r.end.y - r.size.y * _power
	draw_rect(Rect2(r.position.x - 10, ny - 4, r.size.x + 20, 8), Palette.CYAN)
	text(Vector2(r.get_center().x, r.position.y - 24), tr("TRIAL_BOTTLES_POWER"), UiKit.SIZE_SMALL, Palette.IVORY)


