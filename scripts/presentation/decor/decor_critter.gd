class_name DecorCritter
extends DecorProp
## Habitants du casino abandonné : une araignée et un rat qui viennent de temps en temps faire
## un tour sur la table puis repartent ; cliqués, ils détalent. Cosmétique.

enum Mode { HIDDEN, ENTER, REST, LEAVE }

const WALK_SPEED: float = 1.1
const FLEE_SPEED: float = 4.5
const REST_RANGE: Vector2 = Vector2(4.0, 9.0)
const AWAY_RANGE: Vector2 = Vector2(20.0, 45.0)
const FIRST_RANGE: Vector2 = Vector2(6.0, 18.0)

var mode: Mode = Mode.HIDDEN
## Points en coordonnées du parent (monde de la table) : hors champ → repos.
var home: Vector3 = Vector3.ZERO
var spot: Vector3 = Vector3.ZERO
var _timer: float = 0.0
var _speed: float = WALK_SPEED
var _gait: float = 0.0
var _legs: Array[Node3D] = []


func _init(p_kind: String) -> void:
	super(p_kind)
	_timer = rng().randf_range(FIRST_RANGE.x, FIRST_RANGE.y)
	visible = false


func can_poke() -> bool:
	return mode == Mode.ENTER or mode == Mode.REST


func place(p_home: Vector3, p_spot: Vector3) -> void:
	home = p_home
	spot = p_spot
	if mode == Mode.HIDDEN:
		position = home


func _process(delta: float) -> void:
	match mode:
		Mode.HIDDEN:
			_timer -= delta
			if _timer <= 0.0:
				mode = Mode.ENTER
				_speed = WALK_SPEED
				position = home
				visible = true
		Mode.ENTER:
			if _walk_to(spot, delta):
				mode = Mode.REST
				_timer = rng().randf_range(REST_RANGE.x, REST_RANGE.y)
		Mode.REST:
			_timer -= delta
			_fidget(delta)
			if _timer <= 0.0:
				mode = Mode.LEAVE
				_speed = WALK_SPEED
		Mode.LEAVE:
			if _walk_to(home, delta):
				mode = Mode.HIDDEN
				visible = false
				_timer = rng().randf_range(AWAY_RANGE.x, AWAY_RANGE.y)


func _walk_to(target: Vector3, delta: float) -> bool:
	var d: Vector3 = target - position
	d.y = 0.0
	var step: float = _speed * delta * scale.x
	if d.length() <= step:
		position = Vector3(target.x, position.y, target.z)
		_set_legs(0.0)
		return true
	var dir: Vector3 = d.normalized()
	position += dir * step
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 10.0))
	_gait += delta * _speed * 14.0
	_set_legs(sin(_gait))
	return false


func _fidget(delta: float) -> void:
	_gait += delta * 3.0
	if parts.has("head"):
		parts["head"].rotation.y = sin(_gait * 1.7) * 0.35
	_set_legs(sin(_gait * 0.5) * 0.15)


func _set_legs(s: float) -> void:
	for i: int in _legs.size():
		_legs[i].rotation.x = s * 0.45 * (1.0 if i % 2 == 0 else -1.0)


func poke() -> void:
	if not can_poke():
		return
	pokes += 1
	poked.emit(kind)
	AudioBus.play("decor_squeak", 1.4 if kind == "spider" else 1.0)
	mode = Mode.LEAVE
	_speed = FLEE_SPEED
	hop(_root, 0.15, 0.2)


# --------------------------------------------------------------------------- araignée


func build_spider() -> void:
	radius_px = 40.0
	aim_height = 0.08
	var body: Node3D = pivot("body", Vector3(0, 0.1, 0))
	var black: StandardMaterial3D = mat(Color(0.05, 0.04, 0.05), 0.35, 0.1)
	add_mesh(body, ball(0.1), black, Vector3(0, 0, -0.14))
	add_mesh(body, ball(0.07), black, Vector3(0, 0, 0.04))
	add_mesh(body, ball(0.018), glow(Palette.DANGER, 2.0), Vector3(0.03, 0.03, 0.1))
	add_mesh(body, ball(0.018), glow(Palette.DANGER, 2.0), Vector3(-0.03, 0.03, 0.1))
	add_mesh(body, ball(0.03), mat(Palette.ROULETTE_RED, 0.4), Vector3(0, 0.09, -0.16))
	var leg: CylinderMesh = cyl(0.008, 0.012, 0.32, 6)
	for side: float in [-1.0, 1.0]:
		for k: int in 4:
			var hip: Node3D = Node3D.new()
			hip.position = Vector3(0.04 * side, 0, 0.06 - 0.05 * float(k))
			hip.rotation.y = side * (0.9 - 0.35 * float(k)) + (PI * 0.5 if side < 0.0 else -PI * 0.5) * 0.0
			body.add_child(hip)
			add_mesh(hip, leg, black, Vector3(0.14 * side, 0.03, 0), Vector3(0, 0, side * 1.2))
			_legs.append(hip)


# --------------------------------------------------------------------------- rat


func build_rat() -> void:
	radius_px = 55.0
	aim_height = 0.12
	var body: Node3D = pivot("body", Vector3(0, 0.12, 0))
	var fur: StandardMaterial3D = mat(Color(0.33, 0.3, 0.3), 0.9)
	var pink: StandardMaterial3D = mat(Color(0.86, 0.55, 0.58), 0.7)
	var torso: MeshInstance3D = add_mesh(body, ball(0.16), fur, Vector3(0, 0, -0.05))
	torso.scale = Vector3(0.9, 0.75, 1.5)
	var head: Node3D = Node3D.new()
	head.position = Vector3(0, 0.02, 0.22)
	body.add_child(head)
	parts["head"] = head
	var snout: MeshInstance3D = add_mesh(head, ball(0.1), fur, Vector3(0, 0, 0.04))
	snout.scale = Vector3(0.85, 0.8, 1.3)
	add_mesh(head, ball(0.025), pink, Vector3(0, 0, 0.17))
	add_mesh(head, ball(0.055), pink, Vector3(0.07, 0.08, -0.02))
	add_mesh(head, ball(0.055), pink, Vector3(-0.07, 0.08, -0.02))
	add_mesh(head, ball(0.017), glow(Palette.DANGER, 1.5), Vector3(0.045, 0.04, 0.09))
	add_mesh(head, ball(0.017), glow(Palette.DANGER, 1.5), Vector3(-0.045, 0.04, 0.09))
	var tail: MeshInstance3D = add_mesh(body, cyl(0.008, 0.025, 0.5, 6), pink, Vector3(0, -0.05, -0.45), Vector3(PI * 0.5 - 0.15, 0, 0))
	parts["tail"] = tail
	for p: Vector3 in [Vector3(0.09, -0.1, 0.1), Vector3(-0.09, -0.1, 0.1), Vector3(0.09, -0.1, -0.15), Vector3(-0.09, -0.1, -0.15)]:
		var hip: Node3D = Node3D.new()
		hip.position = p
		body.add_child(hip)
		add_mesh(hip, ball(0.035), pink, Vector3(0, -0.01, 0.02))
		_legs.append(hip)
