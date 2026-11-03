class_name TrialInvaders
extends ThrowTrial
## LES ENVAHISSEURS DU ZÉRO (écran dédié, borne d'arcade) : des rangées de jetons-envahisseurs
## descendent vers le tapis. Le râteau-canon du croupier glisse en bas (stick, flèches, souris)
## et tire (valider). Piles de jetons en boucliers, plaque volante en bonus. Les envahisseurs
## ripostent : touché, le canon est sonné. Note = part détruite (plaque en prime), moins une
## pénalité par touche ; ils gagnent s'ils atteignent les boucliers.

const SCREEN: Rect2 = Rect2(400.0, 170.0, 1120.0, 760.0)
const CANNON_Y: float = 880.0
const CANNON_W: float = 70.0
const INV_CELL: float = 5.0
const INV_GAP: Vector2 = Vector2(92.0, 70.0)
const SHIELD_Y: float = 790.0
const SHIELD_CELL: float = 12.0
const SHIELD_COLS: int = 8
const SHIELD_ROWS: int = 4
const SAUCER_Y: float = 210.0
const ROW_COLORS: Array[Color] = [Color("ff2e88"), Color("ffd23f"), Color("29e0ff"), Color("2ee6a8")]
## Deux poses de chaque envahisseur (animation de marche), 11 × 8.
const INV_A: Array[String] = [
	"  #     #  ",
	"   #   #   ",
	"  #######  ",
	" ## ### ## ",
	"###########",
	"# ####### #",
	"# #     # #",
	"   ## ##   ",
]
const INV_B: Array[String] = [
	"  #     #  ",
	"#  #   #  #",
	"# ####### #",
	"### ### ###",
	"###########",
	" ######### ",
	"  #     #  ",
	" #       # ",
]
## Profondeur des jetons-envahisseurs dans la vitrine (m, derrière la vitre).
const CHIP_Z: float = -0.25
const RAKE: Array[String] = [
	"      ##      ",
	"      ##      ",
	"  ##########  ",
	" ############ ",
	"##############",
]

var _x: float = 960.0
var _mouse_x: float = -1.0
var _inv: Array[Dictionary] = []
var _total: int = 0
var _killed: int = 0
var _bonus: int = 0
var _hits: int = 0
var _dir: float = 1.0
var _offset: Vector2 = Vector2.ZERO
var _shots: Array[Vector2] = []
var _bombs: Array[Vector2] = []
var _cool: float = 0.0
var _bomb_t: float = 1.0
var _stun: float = 0.0
var _shields: Array[PackedByteArray] = []
var _saucer_x: float = -1.0
var _saucer_done: bool = false
var _frame: int = 0
var _step_t: float = 0.0
var _bot_axis: float = 0.0
var _bot_fire: bool = false
var _boom: Array[Dictionary] = []
var _ended: bool = false
# Décor 3D : borne, envahisseurs en jetons sous la vitre, piles de jetons, râteau en laiton.
var _cab: Dictionary = {}
var _neighbors: Array[MeshInstance3D] = []
var _inv3: Array[Node3D] = []
var _shield3: Array[MeshInstance3D] = []
var _rake3: Node3D = null
var _saucer3: Node3D = null
var _shot_pool: MeshPool = null
var _bomb_pool: MeshPool = null
var _fire_flash: float = 0.0


func begin() -> void:
	_x = SCREEN.get_center().x
	var cols: int = pi("cols")
	var rows: int = pi("rows")
	var start: Vector2 = Vector2(SCREEN.get_center().x - INV_GAP.x * float(cols - 1) * 0.5, SCREEN.position.y + 120.0)
	for r: int in rows:
		for c: int in cols:
			_inv.append({"p": start + Vector2(c * INV_GAP.x, r * INV_GAP.y), "row": r, "alive": true})
	_total = _inv.size()
	for k: int in 3:
		var cells: PackedByteArray = PackedByteArray()
		cells.resize(SHIELD_COLS * SHIELD_ROWS)
		cells.fill(1)
		_shields.append(cells)
	_bomb_t = p("bomb_every") * slow
	_build_3d()


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(0.005, Vector2(960.0, 540.0), 1080.0, 40.0)
	ArcadeKit3D.room(st, _neighbors)
	_cab = ArcadeKit3D.cabinet(st, SCREEN, tr("TRIAL_INVADERS_MARQUEE"), Color("140a24"))
	var px: float = st.px3
	var ring: StandardMaterial3D = Stage3D.mat(Palette.IVORY, 0.1, 0.4)
	for i: Dictionary in _inv:
		var col: Color = ROW_COLORS[int(i["row"]) % ROW_COLORS.size()]
		var chip: Node3D = Node3D.new()
		st.root.add_child(chip)
		var body: MeshInstance3D = MeshInstance3D.new()
		body.mesh = MeshPool.disc(26.0 * px, 0.05)
		body.material_override = _glowing(col, 0.55)
		body.rotation.x = PI * 0.5
		chip.add_child(body)
		var edge: MeshInstance3D = MeshInstance3D.new()
		edge.mesh = MeshPool.disc(19.0 * px, 0.056, 16)
		edge.material_override = ring
		edge.rotation.x = PI * 0.5
		chip.add_child(edge)
		var core: MeshInstance3D = MeshInstance3D.new()
		core.mesh = MeshPool.disc(14.0 * px, 0.06, 16)
		core.material_override = body.material_override
		core.rotation.x = PI * 0.5
		chip.add_child(core)
		for m: Node in chip.get_children():
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_inv3.append(chip)
	var gold: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.45, 0.3)
	var gold_dark: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.45, 0.35)
	var cell_mesh: BoxMesh = BoxMesh.new()
	cell_mesh.size = Vector3((SHIELD_CELL - 1.0) * px, (SHIELD_CELL - 1.0) * px, 0.12)
	for k: int in _shields.size():
		var o: Vector2 = _shield_origin(k)
		for idx: int in _shields[k].size():
			var cx: int = idx % SHIELD_COLS
			var cy: int = floori(float(idx) / SHIELD_COLS)
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = cell_mesh
			mi.material_override = gold if (cx + cy) % 2 == 0 else gold_dark
			mi.position = st.to3(o + (Vector2(cx, cy) + Vector2(0.5, 0.5)) * SHIELD_CELL, CHIP_Z)
			st.root.add_child(mi)
			_shield3.append(mi)
	# Râteau du croupier en laiton.
	_rake3 = Node3D.new()
	st.root.add_child(_rake3)
	Stage3D.box(_rake3, Vector3(CANNON_W * px, 12.0 * px, 0.1), Vector3(0, -8.0 * px, 0), gold)
	Stage3D.box(_rake3, Vector3(10.0 * px, 34.0 * px, 0.08), Vector3(0, 12.0 * px, 0), Stage3D.mat(Color("6a351f"), 0.0, 0.5))
	for k2: int in 5:
		Stage3D.box(_rake3, Vector3(4.0 * px, 10.0 * px, 0.05), Vector3((float(k2) - 2.0) * 14.0 * px, -18.0 * px, 0), gold)
	# Plaque volante.
	_saucer3 = Node3D.new()
	st.root.add_child(_saucer3)
	Stage3D.box(_saucer3, Vector3(88.0 * px, 28.0 * px, 0.06), Vector3.ZERO, Stage3D.mat(Palette.IVORY, 0.2, 0.3))
	Stage3D.box(_saucer3, Vector3(68.0 * px, 12.0 * px, 0.07), Vector3.ZERO, _glowing(Palette.GOLD, 1.0))
	_shot_pool = MeshPool.new(st.root, MeshPool.capsule(4.0 * px, 28.0 * px), Stage3D.glow(Palette.GOLD_LIGHT, 2.5))
	_bomb_pool = MeshPool.new(st.root, MeshPool.capsule(5.0 * px, 20.0 * px), Stage3D.glow(Color("b03aff"), 2.2))


func _glowing(col: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = Stage3D.mat(col, 0.3, 0.35)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func _sync_3d(dt: float) -> void:
	if _rake3 == null:
		return
	var st: Stage3D = stage
	for k: int in _inv.size():
		var i: Dictionary = _inv[k]
		var chip: Node3D = _inv3[k]
		chip.visible = bool(i["alive"])
		if chip.visible:
			chip.position = st.to3(_inv_pos(i), CHIP_Z)
			# Marche : le jeton se dandine d'une pose à l'autre.
			chip.rotation = Vector3(0, (0.35 if _frame == 0 else -0.35), sin(t * 3.0 + float(k)) * 0.08)
	for k2: int in _shields.size():
		for idx: int in _shields[k2].size():
			_shield3[k2 * _shields[k2].size() + idx].visible = _shields[k2][idx] == 1
	_rake3.position = st.to3(Vector2(_x, CANNON_Y), CHIP_Z)
	_rake3.rotation.z = sin(t * 60.0) * 0.12 if _stun > 0.0 else 0.0
	_saucer3.visible = _saucer_x >= 0.0
	if _saucer3.visible:
		_saucer3.position = st.to3(Vector2(_saucer_x, SAUCER_Y), CHIP_Z)
		_saucer3.rotation.y = t * 4.0
	for k3: int in _shots.size():
		_shot_pool.at(k3).position = st.to3(_shots[k3], CHIP_Z)
	_shot_pool.hide_from(_shots.size())
	for k4: int in _bombs.size():
		var b: MeshInstance3D = _bomb_pool.at(k4)
		b.position = st.to3(_bombs[k4], CHIP_Z)
		b.rotation.z = t * 9.0
	_bomb_pool.hide_from(_bombs.size())
	# Commandes : le manche suit le canon, le bouton s'enfonce au tir ; l'écran éclaire la borne.
	_fire_flash = maxf(0.0, _fire_flash - dt * 6.0)
	var axis: float = clampf(held_vector().x + _bot_axis, -1.0, 1.0)
	(_cab["stick"] as Node3D).rotation.z = lerpf((_cab["stick"] as Node3D).rotation.z, -axis * 0.45, minf(1.0, dt * 14.0))
	(_cab["button"] as Node3D).position.y = 0.05 - 0.03 * _fire_flash
	(_cab["light"] as OmniLight3D).light_energy = 1.2 + 1.4 * _fire_flash + (1.5 if _stun > 0.0 and fmod(t * 8.0, 1.0) < 0.5 else 0.0)
	for k5: int in _neighbors.size():
		var m: StandardMaterial3D = _neighbors[k5].material_override as StandardMaterial3D
		if m != null:
			m.emission_energy_multiplier = 0.6 + 0.3 * sin(t * (2.0 + float(k5)) + float(k5))


func _shield_origin(k: int) -> Vector2:
	var span: float = SCREEN.size.x / 3.0
	return Vector2(SCREEN.position.x + span * (float(k) + 0.5) - SHIELD_COLS * SHIELD_CELL * 0.5, SHIELD_Y)


func _alive() -> Array[Dictionary]:
	return _inv.filter(func(i: Dictionary) -> bool: return bool(i["alive"]))


func _inv_pos(i: Dictionary) -> Vector2:
	return (i["p"] as Vector2) + _offset


func _march_speed() -> float:
	var left: float = float(_alive().size()) / maxf(float(_total), 1.0)
	return lerpf(p("march_fast"), p("march_slow"), left) / slow


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_x = mm.position.x
		return true
	if confirm_pressed(event) or sym_pressed(event) == 3:
		fire()
		return true
	return false


func fire() -> void:
	_fire_flash = 1.0
	if _cool > 0.0 or _stun > 0.0 or _ended:
		return
	_cool = p("fire_cooldown")
	_shots.append(Vector2(_x, CANNON_Y - 30.0))
	AudioBus.play("zap", 1.6, -8.0)


func tick(dt: float) -> void:
	if _ended:
		return
	_cool = maxf(0.0, _cool - dt)
	_stun = maxf(0.0, _stun - dt)
	if _stun <= 0.0:
		_x += clampf(held_vector().x + _bot_axis, -1.0, 1.0) * p("cannon_speed") * dt
		if mouse and _mouse_x >= 0.0:
			_x = move_toward(_x, _mouse_x, p("cannon_speed") * dt)
		if _bot_fire:
			fire()
	_x = clampf(_x, SCREEN.position.x + CANNON_W * 0.5, SCREEN.end.x - CANNON_W * 0.5)
	_march(dt)
	_move_shots(dt)
	_drop_bombs(dt)
	_saucer(dt)
	for b: Dictionary in _boom:
		b["t"] = float(b["t"]) - dt
	_boom = _boom.filter(func(b: Dictionary) -> bool: return float(b["t"]) > 0.0)
	_sync_3d(dt)
	var alive: Array[Dictionary] = _alive()
	var low: float = 0.0
	for i: Dictionary in alive:
		low = maxf(low, _inv_pos(i).y)
	if alive.is_empty() or low >= SHIELD_Y - 20.0 or t >= p("duration") * slow:
		_end(alive.is_empty())


func _march(dt: float) -> void:
	_offset.x += _dir * _march_speed() * dt
	_step_t += dt
	if _step_t >= 0.35:
		_step_t = 0.0
		_frame = 1 - _frame
	var minx: float = INF
	var maxx: float = -INF
	for i: Dictionary in _alive():
		minx = minf(minx, _inv_pos(i).x)
		maxx = maxf(maxx, _inv_pos(i).x)
	var half: float = 11.0 * INV_CELL * 0.5
	if (_dir > 0.0 and maxx + half >= SCREEN.end.x - 10.0) or (_dir < 0.0 and minx - half <= SCREEN.position.x + 10.0):
		_dir = -_dir
		_offset.y += p("drop_step")


func _move_shots(dt: float) -> void:
	var kept: Array[Vector2] = []
	for s: Vector2 in _shots:
		var n: Vector2 = s + Vector2(0, -p("shot_speed") * dt)
		if n.y < SCREEN.position.y or _hit_shield(n) or _hit_invader(s, n) or _hit_saucer(n):
			continue
		kept.append(n)
	_shots = kept


func _hit_invader(a: Vector2, b: Vector2) -> bool:
	var half: Vector2 = Vector2(11.0, 8.0) * INV_CELL * 0.5
	for i: Dictionary in _inv:
		if not bool(i["alive"]):
			continue
		var c: Vector2 = _inv_pos(i)
		if absf(b.x - c.x) <= half.x and b.y <= c.y + half.y and a.y >= c.y - half.y:
			i["alive"] = false
			_killed += 1
			_boom.append({"p": c, "t": 0.3, "col": ROW_COLORS[int(i["row"]) % ROW_COLORS.size()]})
			AudioBus.play("chip_place", 1.4 + 0.02 * float(_killed % 10), -4.0)
			return true
	return false


func _hit_saucer(p2: Vector2) -> bool:
	if _saucer_x < 0.0 or absf(p2.x - _saucer_x) > 46.0 or absf(p2.y - SAUCER_Y) > 18.0:
		return false
	_bonus += pi("saucer_value")
	_saucer_x = -1.0
	pop(Vector2(p2.x, SAUCER_Y + 40.0), 1.0, "TRIAL_INVADERS_SAUCER")
	AudioBus.play("coins", 1.2, -4.0)
	return true


func _hit_shield(p2: Vector2) -> bool:
	for k: int in _shields.size():
		var o: Vector2 = _shield_origin(k)
		var cell: Vector2i = Vector2i(floori((p2.x - o.x) / SHIELD_CELL), floori((p2.y - o.y) / SHIELD_CELL))
		if cell.x < 0 or cell.y < 0 or cell.x >= SHIELD_COLS or cell.y >= SHIELD_ROWS:
			continue
		var idx: int = cell.y * SHIELD_COLS + cell.x
		if _shields[k][idx] == 1:
			_shields[k][idx] = 0
			AudioBus.play("tick", 0.8, -10.0)
			return true
	return false


## Riposte : le plus bas envahisseur de la colonne la plus proche du canon lâche une bombe.
func _drop_bombs(dt: float) -> void:
	_bomb_t -= dt
	if _bomb_t <= 0.0:
		_bomb_t = p("bomb_every") * slow * rng.randf_range(0.7, 1.3)
		var best: Dictionary = {}
		var best_d: float = INF
		for i: Dictionary in _alive():
			var c: Vector2 = _inv_pos(i)
			var d: float = absf(c.x - _x) - c.y * 0.01 + rng.randf() * 160.0
			if d < best_d:
				best_d = d
				best = i
		if not best.is_empty():
			_bombs.append(_inv_pos(best) + Vector2(0, 24))
	var kept: Array[Vector2] = []
	for b: Vector2 in _bombs:
		var n: Vector2 = b + Vector2(0, p("bomb_speed") / slow * dt)
		if _hit_shield(n):
			continue
		if absf(n.y - CANNON_Y) < 20.0 and absf(n.x - _x) < CANNON_W * 0.5:
			_hits += 1
			_stun = p("stun_seconds")
			pop(Vector2(_x, CANNON_Y - 60.0), 0.0, "TRIAL_INVADERS_HIT")
			AudioBus.play("explosion", 1.4, -6.0)
			continue
		if n.y < SCREEN.end.y:
			kept.append(n)
	_bombs = kept


func _saucer(dt: float) -> void:
	if not _saucer_done and t >= p("saucer_at") * slow:
		_saucer_done = true
		_saucer_x = SCREEN.position.x + 40.0
		AudioBus.play("slot_tease", 1.5, -10.0)
	if _saucer_x >= 0.0:
		_saucer_x += p("saucer_speed") * dt
		if _saucer_x > SCREEN.end.x - 40.0:
			_saucer_x = -1.0


func _end(cleared: bool) -> void:
	_ended = true
	if cleared:
		AudioBus.play("jackpot", 1.2, -6.0)
	var sc: float = (float(_killed) + float(_bonus)) / maxf(float(_total), 1.0) - p("hit_penalty") * float(_hits)
	finish(clampf(sc, 0.0, 1.0))


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	# Esquive d'abord une bombe proche, sinon s'aligne (en anticipant la marche) sur
	# l'envahisseur le plus bas de la colonne la plus proche, et tire quand c'est aligné.
	for b: Vector2 in _bombs:
		if CANNON_Y - b.y < 190.0 and CANNON_Y - b.y > 0.0 and absf(b.x - _x) < CANNON_W:
			return {"do": "axis", "v": Vector2(1.0 if b.x <= _x else -1.0, 0.0)}
	var goal: float = _x
	var best: float = INF
	if _saucer_x >= 0.0:
		var lead_s: float = (CANNON_Y - SAUCER_Y) / p("shot_speed")
		goal = _saucer_x + p("saucer_speed") * lead_s
		best = 0.0
	for i: Dictionary in _alive():
		var c: Vector2 = _inv_pos(i)
		var lead: float = (CANNON_Y - c.y) / p("shot_speed")
		var ax: float = c.x + _dir * _march_speed() * lead
		var score_d: float = absf(ax - _x) - c.y * 0.3
		if score_d < best:
			best = score_d
			goal = ax
	if absf(goal - _x) < 16.0 and _cool <= 0.0 and _stun <= 0.0:
		return {"do": "confirm"}
	return {"do": "axis", "v": Vector2(clampf((goal - _x) / 30.0, -1.0, 1.0), 0.0)}


func bot_apply(w: Dictionary) -> void:
	var act: String = String(w.get("do", ""))
	_bot_axis = (w.get("v", Vector2.ZERO) as Vector2).x if act == "axis" else 0.0
	_bot_fire = act == "confirm"


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	for bo: Dictionary in _boom:
		var a: float = float(bo["t"]) / 0.3
		for k2: int in 8:
			var dirv: Vector2 = Vector2.from_angle(TAU * float(k2) / 8.0) * (1.0 - a) * 46.0
			draw_rect(Rect2((bo["p"] as Vector2) + dirv - Vector2(4, 4), Vector2(8, 8)), Color(bo["col"] as Color, a))
	# Reflet de la vitre bombée (sans lignes de balayage : on regarde une vitrine, pas un tube).
	draw_rect(Rect2(SCREEN.position, Vector2(SCREEN.size.x, SCREEN.size.y * 0.14)), Color(1, 1, 1, 0.04))
	var o: Vector2 = SCREEN.position
	var sz: Vector2 = SCREEN.size
	var streak: PackedVector2Array = PackedVector2Array([o + Vector2(sz.x * 0.62, 0), o + Vector2(sz.x * 0.72, 0),
		o + Vector2(sz.x * 0.52, sz.y), o + Vector2(sz.x * 0.42, sz.y)])
	draw_colored_polygon(streak, Color(1, 1, 1, 0.03))
	var pct: int = roundi(100.0 * float(_killed) / maxf(float(_total), 1.0))
	var status: String = tr("TRIAL_INVADERS_STATUS") % pct
	text(Vector2(SCREEN.position.x + 160.0, SCREEN.position.y + 40.0), status, UiKit.SIZE_BODY, Palette.GOLD_LIGHT, "mono")
	var left: float = clampf(1.0 - t / (p("duration") * slow), 0.0, 1.0)
	draw_rect(Rect2(SCREEN.end.x - 330.0, SCREEN.position.y + 34.0, 300.0 * left, 10.0), Palette.GOLD)
