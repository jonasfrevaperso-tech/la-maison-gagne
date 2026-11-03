class_name TrialCharge
extends ThrowTrial
## ÉLAN : maintenir pour charger une jauge qui accélère (puis redescend si on tarde), relâcher
## dans la zone dorée, dont la position change à chaque fois. Deux élans d'affilée : le second
## a une zone plus étroite. Notation : ThrowSkill.power_score.

const TICKS: int = 20
const TICK_EVERY: float = 0.07
const NEEDLE_W: float = 6.0
const GAUGE_H: float = 44.0
const BOT_FRAME: float = 1.0 / 60.0
## Décor 3D : rebord de la roue en arc derrière la jauge (centre sous le panneau, en px).
const PX3: float = 0.005
const RIM_R_PX: float = 1150.0
const RIM_DROP_PX: float = 1070.0
const WHEEL_SPIN: float = 0.06

var _half: float = 0.1
var _center: float = 0.7
var _level: float = 0.0
var _stopped_at: float = -1.0
var _charging: bool = false
var _tick_t: float = 0.0
var _round: int = 0
var _scores: Array[float] = []
var _rest: float = 0.0
var _wheel3: Node3D = null


func begin() -> void:
	_new_round()
	_build_3d()


## Rebord de la roue : bois verni, cases rouges et noires numérotées, séparateurs dorés.
func _build_3d() -> void:
	var r: Rect2 = play_rect()
	var st: Stage3D = use_3d()
	st.frontal(PX3, r.get_center(), r.size.y, 36.0)
	st.env.background_color = Color(0.05, 0.02, 0.04)
	st.env.ambient_light_energy = 0.4
	var root: Node3D = st.root
	_wheel3 = Node3D.new()
	_wheel3.position = st.to3(Vector2(r.get_center().x, r.get_center().y + RIM_DROP_PX), -0.6)
	root.add_child(_wheel3)
	var wood: StandardMaterial3D = Stage3D.mat(Color("4a2412"), 0.0, 0.3)
	wood.clearcoat_enabled = true
	wood.clearcoat = 0.8
	var outer: MeshInstance3D = Stage3D.cylinder(_wheel3, (RIM_R_PX + 90.0) * PX3, 0.2, Vector3(0, 0, -0.1), wood)
	outer.rotation.x = PI * 0.5
	var gilt: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.45, 0.3)
	var red: StandardMaterial3D = Stage3D.mat(Palette.ROULETTE_RED, 0.0, 0.3)
	var black: StandardMaterial3D = Stage3D.mat(Color("141418"), 0.0, 0.3)
	var green: StandardMaterial3D = Stage3D.mat(Color("0e6b45"), 0.0, 0.3)
	for k: int in WheelLayout.POCKET_COUNT:
		var a: float = TAU * float(k) / float(WheelLayout.POCKET_COUNT)
		var dir: Vector3 = Vector3(sin(a), cos(a), 0)
		var num: int = WheelLayout.number_at(k)
		var m: StandardMaterial3D = green if num == 0 else (red if WheelLayout.RED.has(num) else black)
		var pocket: MeshInstance3D = Stage3D.box(_wheel3, Vector3(150.0 * PX3, 64.0 * PX3, 0.05),
			dir * RIM_R_PX * PX3 + Vector3(0, 0, 0.02), m)
		pocket.rotation.z = -a
		var sep: MeshInstance3D = Stage3D.box(_wheel3, Vector3(6.0 * PX3, 80.0 * PX3, 0.08),
			Vector3(sin(a + PI / float(WheelLayout.POCKET_COUNT)),
			cos(a + PI / float(WheelLayout.POCKET_COUNT)), 0) * RIM_R_PX * PX3 + Vector3(0, 0, 0.03), gilt)
		sep.rotation.z = -(a + PI / float(WheelLayout.POCKET_COUNT))
		var lbl: Label3D = Stage3D.text3d(_wheel3, str(num), dir * RIM_R_PX * PX3 + Vector3(0, 0, 0.05), 48, Palette.IVORY,
			Color(0, 0, 0, 0))
		lbl.pixel_size = 0.0025
		lbl.rotation.z = -a
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = (RIM_R_PX - 45.0) * PX3
	ring.outer_radius = (RIM_R_PX - 35.0) * PX3
	ring.rings = 96
	var trim: MeshInstance3D = MeshInstance3D.new()
	trim.mesh = ring
	trim.material_override = gilt
	trim.rotation.x = PI * 0.5
	_wheel3.add_child(trim)
	Stage3D.omni(root, Color(1.0, 0.85, 0.6), 1.6, st.to3(r.get_center(), 1.4), 6.0)


func _process(delta: float) -> void:
	super(delta)
	if _wheel3 != null:
		_wheel3.rotation.z = -t * WHEEL_SPIN - float(_round) * 0.4


func _new_round() -> void:
	_half = ThrowSkill.sweet_half(precision, assist) * (1.0 if _round == 0 else p("second_narrow"))
	_center = ThrowSkill.sweet_center(rng.randf())
	_level = 0.0
	_stopped_at = -1.0
	_charging = false
	t = 0.0


func handle(event: InputEvent) -> bool:
	if _rest > 0.0:
		return confirm_pressed(event)
	if not _charging and confirm_pressed(event):
		press()
		return true
	if _charging and confirm_released(event):
		release()
		return true
	return false


func press() -> void:
	if _charging or _rest > 0.0:
		return
	_charging = true
	t = 0.0
	AudioBus.play("cloth", 1.2, -4.0)


func release() -> void:
	if not _charging:
		return
	_charging = false
	_stopped_at = _level
	var sc: float = ThrowSkill.power_score(_level, _half, _center)
	_scores.append(sc)
	flash = 1.0
	pop(Vector2(_gauge_rect().position.x + _gauge_rect().size.x * _level, _gauge_rect().position.y - 30.0), sc)
	AudioBus.play("whoosh", 0.8 + _level * 0.6)
	AudioBus.play("chime" if sc >= 0.9 else ("chip_place" if sc >= 0.45 else "lose_soft"), 0.9 + sc * 0.4, -6.0)
	_rest = p("rest_seconds")


func tick(dt: float) -> void:
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_round += 1
			if _round >= pi("rounds"):
				finish(mean(_scores))
			else:
				_new_round()
		return
	if not _charging:
		if t >= Balance.f("throw_game.charge_wait_seconds"):
			press()  # sans réponse : l'élan se prend tout seul…
		return
	_level = ThrowSkill.charge_level(t, slow)
	_tick_t -= dt
	if _tick_t <= 0.0:
		_tick_t = TICK_EVERY
		AudioBus.play("tick", 0.7 + _level * 1.1, -10.0)
	if t >= Balance.f("throw_game.charge_seconds") * slow * 4.0:
		release()  # … et se relâche après deux allers-retours.


func bot_wants() -> Dictionary:
	if _rest > 0.0:
		return {"do": ""}
	if not _charging:
		return {"do": "hold"}
	if t >= Balance.f("throw_game.charge_seconds") * slow:
		return {"do": ""}
	# La jauge accélère : on lâche aussi quand elle va franchir le centre à l'image suivante.
	var nxt: float = ThrowSkill.charge_level(t + BOT_FRAME, slow)
	if absf(_level - _center) < _half * 0.25 or (_level - _center) * (nxt - _center) < 0.0:
		return {"do": "release"}
	return {"do": ""}


func bot_apply(want: Dictionary) -> void:
	match String(want.get("do", "")):
		"hold":
			press()
		"release":
			release()


func _gauge_rect() -> Rect2:
	var r: Rect2 = play_rect()
	return Rect2(Vector2(r.position.x + 30.0, r.get_center().y - GAUGE_H * 0.5 + 18.0), Vector2(r.size.x - 60.0, GAUGE_H))


func paint() -> void:
	var pr: Rect2 = play_rect()
	var round_txt: String = tr("TRIAL_CHARGE_ROUND") % [_round + 1, pi("rounds")]
	text(Vector2(pr.get_center().x, pr.position.y + 34.0), round_txt, UiKit.SIZE_BODY, Palette.IVORY)
	pips(Vector2(pr.get_center().x, pr.position.y + 66.0), _scores, pi("rounds"))
	var r: Rect2 = _gauge_rect()
	_draw_case(r)
	draw_rect(r, Color("1a0a10"))
	var lvl: float = _stopped_at if _stopped_at >= 0.0 else _level
	var in_zone: bool = absf(lvl - _center) <= _half
	draw_rect(Rect2(r.position, Vector2(r.size.x * lvl, r.size.y)), Color(Palette.CYAN if not in_zone else Palette.GOLD_LIGHT, 0.3))
	var zx: float = r.position.x + r.size.x * (_center - _half)
	draw_rect(Rect2(zx, r.position.y, r.size.x * _half * 2.0, r.size.y), Color(Palette.GOLD, 0.55))
	var core: float = _half * Balance.f("throw_game.power_perfect_ratio")
	draw_rect(Rect2(r.position.x + r.size.x * (_center - core), r.position.y, r.size.x * core * 2.0, r.size.y), Palette.GOLD_LIGHT)
	# Graduations gravées, chiffrées tous les quarts.
	for k: int in TICKS + 1:
		var x: float = r.position.x + r.size.x * float(k) / float(TICKS)
		var major: bool = k % 5 == 0
		draw_line(Vector2(x, r.end.y - (14 if major else 8)), Vector2(x, r.end.y), Color("2a1a08"), 2.0 if major else 1.0)
		if major:
			text(Vector2(x, r.end.y + 24.0), str(k * 5), UiKit.SIZE_SMALL, Color("3a2408"), "mono", 0)
	# Reflet de la vitre.
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x * 0.12, 0), r.position + Vector2(r.size.x * 0.2, 0),
		r.position + Vector2(r.size.x * 0.16, r.size.y), r.position + Vector2(r.size.x * 0.08, r.size.y)]), Color(1, 1, 1, 0.08))
	# Aiguille de laiton à rubis.
	var last: float = _scores[-1] if not _scores.is_empty() and _stopped_at >= 0.0 else 0.0
	var ncol: Color = Palette.CYAN if _stopped_at < 0.0 else (Palette.EMERALD if last >= 0.7 else Palette.MAGENTA)
	var nx: float = r.position.x + r.size.x * lvl
	var top: Vector2 = Vector2(nx, r.position.y - 16.0)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-11, 3), top + Vector2(11, 3), Vector2(nx + 2, r.end.y + 8),
		Vector2(nx - 2, r.end.y + 8)]),
		Color(0, 0, 0, 0.4))
	draw_colored_polygon(PackedVector2Array([top + Vector2(-10, 0), top + Vector2(10, 0), Vector2(nx + NEEDLE_W * 0.3, r.end.y + 6),
		Vector2(nx - NEEDLE_W * 0.3, r.end.y + 6)]), Palette.GOLD)
	draw_circle(top, 8.0, Palette.GOLD_DARK)
	draw_circle(top, 5.0, ncol)
	if flash > 0.0:
		draw_rect(r.grow(8.0 + 10.0 * (1.0 - flash)), Color(ncol, flash * 0.8), false, 3.0)
	if not _charging and _rest <= 0.0:
		var pulse: float = 0.6 + 0.4 * sin(t * 6.0)
		text(r.get_center(), tr("TRIAL_CHARGE_READY"), UiKit.SIZE_BODY, Color(Palette.IVORY, pulse))


## Boîtier de laiton biseauté, rivets aux coins, plaque gravée sous la jauge.
func _draw_case(r: Rect2) -> void:
	var c: Rect2 = r.grow_individual(18.0, 16.0, 18.0, 40.0)
	draw_rect(Rect2(c.position + Vector2(6, 8), c.size), Color(0, 0, 0, 0.45))
	draw_rect(c, Palette.GOLD_DARK)
	draw_rect(c.grow(-3.0), Color("c89a3a"))
	draw_rect(Rect2(c.position + Vector2(3, 3), Vector2(c.size.x - 6.0, c.size.y * 0.35)), Color("e0b858"))
	draw_rect(Rect2(Vector2(c.position.x + 3.0, c.end.y - c.size.y * 0.3), Vector2(c.size.x - 6.0, c.size.y * 0.3 - 3.0)), Color("a87a28"))
	draw_rect(c, Color("5a3a10"), false, 2.0)
	for corner: Vector2 in [c.position + Vector2(9, 9), Vector2(c.end.x - 9, c.position.y + 9), c.end - Vector2(9, 9),
		Vector2(c.position.x + 9, c.end.y - 9)]:
		draw_circle(corner, 4.0, Color("5a3a10"))
		draw_circle(corner - Vector2(1, 1), 2.5, Palette.GOLD_LIGHT)
	draw_rect(r.grow(3.0), Color("3a2408"), false, 3.0)
