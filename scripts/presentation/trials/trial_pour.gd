class_name TrialPour
extends ThrowTrial
## LE VERRE PARFAIT : le bar est fermé depuis 1987, mais les verres attendent encore. Maintenir
## pour verser jusqu'au trait doré, relâcher à temps : la mousse continue de monter un peu après.
## Trois verres de formes différentes (flûte, whisky, coupe), chacun se remplit à sa vitesse.
## Note = proximité du trait, verre par verre ; un verre qui déborde vaut 0.

const GLASS_W: Array[float] = [70.0, 130.0, 190.0]
const GLASS_H: float = 210.0
const FOAM: Color = Color(1.0, 0.97, 0.88)
const DRINKS: Array[Color] = [Color(0.95, 0.82, 0.35), Color(0.75, 0.42, 0.15), Color(0.9, 0.25, 0.4)]

var _glass: int = 0
var _level: float = 0.0
var _settle: float = 0.0
var _target: float = 0.7
var _pouring: bool = false
var _rest: float = 0.0
var _wait: float = 0.0
var _scores: Array[float] = []
var _gurgle_t: float = 0.0
## Scène 3D : tireuse en laiton, verre translucide, boisson et mousse, filet versé.
var _glass3: MeshInstance3D = null
var _drink3: MeshInstance3D = null
var _foam3: MeshInstance3D = null
var _stream3: MeshInstance3D = null
var _drink_mat: StandardMaterial3D = null


func begin() -> void:
	_build_3d()
	_new_glass()


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	var r: Rect2 = play_rect()
	st.env.background_color = Color(0.05, 0.03, 0.03)
	st.key.light_energy = 0.4
	st.frontal(0.005, r.get_center(), r.size.y, 36.0)
	BarSet3D.build(st, r)
	var px: float = st.px3
	var root: Node3D = st.root
	# Tireuse : colonne de laiton, bec, poignée émaillée.
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD.darkened(0.15), 0.95, 0.25)
	var tap: Vector3 = st.to3(Vector2(r.get_center().x, r.position.y + 20.0), 0.0)
	Stage3D.cylinder(root, 0.07, 0.6, tap + Vector3(0, 0.3, -0.25), brass)
	Stage3D.box(root, Vector3(0.12, 0.08, 0.32), tap + Vector3(0, 0.02, -0.1), brass)
	Stage3D.cylinder(root, 0.025, 0.1, tap + Vector3(0, -0.04, 0), brass)
	Stage3D.box(root, Vector3(0.05, 0.3, 0.05), tap + Vector3(0, 0.22, -0.08), Stage3D.mat(Color(0.15, 0.35, 0.2), 0.2, 0.3))
	var glass: StandardMaterial3D = Stage3D.mat(Color(0.85, 0.92, 1.0, 0.22), 0.1, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.rim_enabled = true
	glass.rim = 1.0
	_glass3 = Stage3D.cylinder(root, 1.0, 1.0, Vector3.ZERO, glass)
	_drink_mat = Stage3D.mat(DRINKS[0], 0.1, 0.2)
	_drink_mat.emission_enabled = true
	_drink_mat.emission_energy_multiplier = 0.25
	_drink3 = Stage3D.cylinder(root, 1.0, 1.0, Vector3.ZERO, _drink_mat)
	_foam3 = Stage3D.cylinder(root, 1.0, 1.0, Vector3.ZERO, Stage3D.mat(FOAM, 0.0, 0.8))
	_stream3 = Stage3D.cylinder(root, 4.0 * px, 1.0, Vector3.ZERO, _drink_mat)


func _sync_3d() -> void:
	if _glass3 == null:
		return
	var px: float = stage.px3
	var g: Rect2 = _glass_rect()
	var rad: float = g.size.x * 0.5 * px
	var base: Vector3 = stage.to3(Vector2(g.get_center().x, g.end.y), 0.0)
	var gh: float = g.size.y * px
	_glass3.scale = Vector3(rad + 0.01, gh, rad + 0.01)
	_glass3.position = base + Vector3(0, gh * 0.5, 0)
	var lv: float = clampf(_level, 0.0, 1.0)
	var col: Color = DRINKS[_glass % DRINKS.size()]
	_drink_mat.albedo_color = col
	_drink_mat.emission = col
	_drink3.visible = lv > 0.005
	_drink3.scale = Vector3(rad * 0.94, maxf(gh * lv, 0.001), rad * 0.94)
	_drink3.position = base + Vector3(0, gh * lv * 0.5, 0)
	_foam3.visible = lv > 0.02
	_foam3.scale = Vector3(rad * 0.95, 10.0 * px, rad * 0.95)
	_foam3.position = base + Vector3(0, gh * lv + 5.0 * px, 0)
	_stream3.visible = _pouring
	if _pouring:
		var top: float = stage.to3(Vector2(0, play_rect().position.y + 24.0)).y
		var bottom: float = base.y + gh * lv
		_stream3.scale = Vector3(1, maxf(top - bottom, 0.01), 1)
		_stream3.position = Vector3(base.x, (top + bottom) * 0.5, 0)


func _new_glass() -> void:
	_level = 0.0
	_settle = 0.0
	_pouring = false
	_wait = 0.0
	_target = rng.randf_range(0.55, 0.85)


## Vitesse de remplissage : la coupe (évasée) monte vite au fond puis ralentit.
func _rate() -> float:
	var base: float = 1.0 / (pk("fill_seconds", _glass) * slow)
	if _glass == 2:
		return base * lerpf(1.7, 0.6, _level)
	return base


func handle(event: InputEvent) -> bool:
	if _rest > 0.0:
		return confirm_pressed(event)
	if not _pouring and confirm_pressed(event):
		press()
		return true
	if _pouring and confirm_released(event):
		release()
		return true
	return false


func press() -> void:
	if _pouring or _rest > 0.0:
		return
	_pouring = true
	AudioBus.play("decor_bottle", 1.1, -4.0)


func release() -> void:
	if not _pouring:
		return
	_pouring = false
	# La mousse monte encore un peu : il faut anticiper.
	_settle = p("settle") * (1.0 + 0.6 * float(_glass))
	_rest = p("rest_seconds")


func _judge() -> void:
	var final: float = _level
	var sc: float = 0.0
	if final <= 1.0:
		var d: float = absf(final - _target)
		var perfect: float = p("perfect") * widen()
		sc = 1.0 if d <= perfect else clampf(1.0 - (d - perfect) / p("falloff"), 0.0, 1.0)
	_scores.append(sc)
	pop(Vector2(_glass_rect().get_center().x, _glass_rect().position.y - 26.0), sc, "TRIAL_POUR_SPILL" if final > 1.0 else "")
	AudioBus.play("decor_glass" if final <= 1.0 else "glass", 1.0 + sc * 0.3, -4.0)
	if sc >= 0.9:
		AudioBus.play("chime", 1.2, -6.0)


func tick(dt: float) -> void:
	_gurgle_t -= dt
	if _pouring:
		_level += _rate() * dt
		if _gurgle_t <= 0.0:
			_gurgle_t = 0.18
			AudioBus.play("decor_ice", 0.6 + _level * 0.8, -12.0)
		if _level > 1.08:
			release()
		return
	if _settle > 0.0:
		var step: float = minf(_settle, dt * 0.25)
		_level += step
		_settle -= step
		if _settle <= 0.0:
			_judge()
		return
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_glass += 1
			if _glass >= pi("glasses"):
				finish(mean(_scores))
			else:
				_new_glass()
		return
	_wait += dt
	if _wait > p("wait_seconds") * slow:
		_level = 0.0
		_scores.append(0.0)
		pop(_glass_rect().get_center(), 0.0)
		_rest = p("rest_seconds")


func bot_wants() -> Dictionary:
	if _rest > 0.0 or _settle > 0.0:
		return {"do": ""}
	if not _pouring:
		return {"do": "hold"}
	var ahead: float = p("settle") * (1.0 + 0.6 * float(_glass))
	if _level + ahead >= _target:
		return {"do": "release"}
	return {"do": ""}


func bot_apply(want: Dictionary) -> void:
	match String(want.get("do", "")):
		"hold":
			press()
		"release":
			release()


func _glass_rect() -> Rect2:
	var r: Rect2 = play_rect()
	var w: float = GLASS_W[mini(_glass, GLASS_W.size() - 1)]
	return Rect2(Vector2(r.get_center().x - w * 0.5, r.end.y - GLASS_H - 30.0), Vector2(w, GLASS_H))


func paint() -> void:
	var r: Rect2 = play_rect()
	_sync_3d()
	var g: Rect2 = _glass_rect()
	if _level > 1.0:
		draw_rect(Rect2(g.position.x - 14, g.position.y, 10, g.size.y), Color(FOAM, 0.8))
		draw_rect(Rect2(g.end.x + 4, g.position.y, 10, g.size.y), Color(FOAM, 0.8))
	# Trait doré visé.
	var ty: float = g.end.y - g.size.y * _target
	draw_line(Vector2(g.position.x - 30, ty), Vector2(g.end.x + 30, ty), Palette.GOLD_LIGHT, 3.0)
	var tip: PackedVector2Array = PackedVector2Array(
		[Vector2(g.position.x - 30, ty - 9), Vector2(g.position.x - 14, ty), Vector2(g.position.x - 30, ty + 9)]
	)
	draw_colored_polygon(tip, Palette.GOLD_LIGHT)
	pips(Vector2(r.end.x - 120.0, r.position.y + 34.0), _scores, pi("glasses"))
	if not _pouring and _rest <= 0.0 and _settle <= 0.0:
		var left: float = clampf(1.0 - _wait / (p("wait_seconds") * slow), 0.0, 1.0)
		draw_rect(Rect2(r.position.x + 30, r.position.y + 26, 200 * left, 8), Palette.GOLD)
