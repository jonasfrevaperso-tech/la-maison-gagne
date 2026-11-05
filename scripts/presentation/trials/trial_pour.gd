class_name TrialPour
extends ThrowTrial
## LE VERRE PARFAIT (2.0) : servir comme au comptoir. Maintenir pour verser (le niveau), et
## incliner le verre (stick, flèches, souris ou doigt) pour doser la mousse : droit, la bière
## mousse beaucoup ; penché, presque pas. Le verre est jugé une seconde après le dernier lâcher
## (on peut compléter entre-temps) : boisson au trait doré, col de mousse dans la bande.
## Trois verres (flûte, chope, coupe) moussant de plus en plus. Déborder perd le col.
## Note par verre = niveau (poids `w_level`) + col de mousse (1 − `w_level`).

const GLASS_W: Array[float] = [70.0, 130.0, 190.0]
const GLASS_H: float = 210.0
const FOAM: Color = Color(1.0, 0.97, 0.88)
## Inclinaison maximale du verre (rad) quand `_tilt` vaut 1.
const TILT_MAX: float = 0.32
const DRINKS: Array[Color] = [Color(0.95, 0.82, 0.35), Color(0.75, 0.42, 0.15), Color(0.9, 0.25, 0.4)]

var _glass: int = 0
var _level: float = 0.0
var _foam: float = 0.0
var _target: float = 0.7
var _spilled: bool = false
var _pouring: bool = false
var _rest: float = 0.0
var _serve_t: float = 0.0
## Inclinaison du verre (0 droit, 1 penché) et temps écoulé depuis le dernier lâcher.
var _tilt: float = 0.0
var _since_release: float = -1.0
var _axis: Vector2 = Vector2.ZERO
var _mouse_x: float = -1.0
var _pivot3: Node3D = null
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
	_pivot3 = Node3D.new()
	root.add_child(_pivot3)
	_glass3 = Stage3D.cylinder(_pivot3, 1.0, 1.0, Vector3.ZERO, glass)
	_drink_mat = Stage3D.mat(DRINKS[0], 0.1, 0.2)
	_drink_mat.emission_enabled = true
	_drink_mat.emission_energy_multiplier = 0.25
	_drink3 = Stage3D.cylinder(_pivot3, 1.0, 1.0, Vector3.ZERO, _drink_mat)
	_foam3 = Stage3D.cylinder(_pivot3, 1.0, 1.0, Vector3.ZERO, Stage3D.mat(FOAM, 0.0, 0.8))
	_stream3 = Stage3D.cylinder(root, 4.0 * px, 1.0, Vector3.ZERO, _drink_mat)


func _sync_3d() -> void:
	if _glass3 == null:
		return
	var px: float = stage.px3
	var g: Rect2 = _glass_rect()
	var rad: float = g.size.x * 0.5 * px
	_pivot3.position = stage.to3(Vector2(g.get_center().x, g.end.y), 0.0)
	_pivot3.rotation.z = -_tilt * TILT_MAX
	var base: Vector3 = Vector3.ZERO
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
	var fh: float = clampf(_foam, 0.0, 1.0 - lv)
	_foam3.visible = fh > 0.005
	_foam3.scale = Vector3(rad * 0.95, maxf(gh * fh, 0.001), rad * 0.95)
	_foam3.position = base + Vector3(0, gh * (lv + fh * 0.5), 0)
	_stream3.visible = _pouring
	if _pouring:
		var top: float = stage.to3(Vector2(0, play_rect().position.y + 24.0)).y
		var bottom: float = _pivot3.position.y + gh * lv * cos(_tilt * TILT_MAX)
		_stream3.scale = Vector3(1, maxf(top - bottom, 0.01), 1)
		_stream3.position = Vector3(_pivot3.position.x, (top + bottom) * 0.5, 0)


func _new_glass() -> void:
	_level = 0.0
	_foam = 0.0
	_spilled = false
	_pouring = false
	_serve_t = 0.0
	_since_release = -1.0
	_tilt = 0.0
	_target = rng.randf_range(0.6, 0.8)


## Vitesse de remplissage : la coupe (évasée) monte vite au fond puis ralentit.
func _rate() -> float:
	var base: float = 1.0 / (pk("fill_seconds", _glass) * slow)
	if _glass == 2:
		return base * lerpf(1.7, 0.6, _level)
	return base


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_x = mm.position.x
		return true
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
	_since_release = 0.0


## Mousse produite par unité de boisson versée : beaucoup verre droit, peu verre penché.
func _foam_ratio() -> float:
	return pk("foam_ratio", _glass) * lerpf(1.0, p("tilt_foam_min"), _tilt)


## Col de mousse visé (épaisseur, en fraction du verre).
func _head() -> float:
	return p("head_target")


func _judge() -> void:
	var perfect: float = p("perfect") * widen()
	var d: float = absf(_level - _target)
	var lv_sc: float = 1.0 if d <= perfect else clampf(1.0 - (d - perfect) / p("falloff"), 0.0, 1.0)
	var dh: float = absf(_foam - _head())
	var hd_sc: float = 0.0 if _spilled else clampf(1.0 - maxf(dh - p("head_band") * widen(), 0.0) / p("head_falloff"), 0.0, 1.0)
	var sc: float = lv_sc * p("w_level") + hd_sc * (1.0 - p("w_level"))
	_scores.append(sc)
	var key: String = "TRIAL_POUR_SPILL" if _spilled else ("TRIAL_POUR_HEAD_THIN" if _foam < _head() - p("head_band") * 2.0 else "")
	pop(Vector2(_glass_rect().get_center().x, _glass_rect().position.y - 26.0), sc, key)
	AudioBus.play("decor_glass", 1.0 + sc * 0.3, -4.0)
	if sc >= 0.9:
		AudioBus.play("chime", 1.2, -6.0)
	_rest = p("rest_seconds")


func tick(dt: float) -> void:
	_gurgle_t -= dt
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_glass += 1
			if _glass >= pi("glasses"):
				finish(mean(_scores))
			else:
				_new_glass()
		return
	_serve_t += dt
	# Inclinaison : le stick (ou les flèches) la fait varier ; la souris la règle directement
	# (à droite du verre = penché).
	var v: float = held_vector().x + _axis.x
	_tilt = clampf(_tilt + v * p("tilt_speed") * dt, 0.0, 1.0)
	if mouse and _mouse_x >= 0.0:
		var g: Rect2 = _glass_rect()
		_tilt = clampf((_mouse_x - g.get_center().x) / p("tilt_mouse_px"), 0.0, 1.0)
	# La mousse retombe lentement ; une part redevient boisson.
	var fall: float = _foam * (1.0 - exp(-dt / maxf(p("foam_settle_seconds"), 0.01)))
	_foam -= fall
	_level += fall * p("foam_to_liquid")
	if _pouring:
		var d_l: float = _rate() * dt
		_level += d_l
		_foam += d_l * _foam_ratio()
		if _gurgle_t <= 0.0:
			_gurgle_t = 0.18
			AudioBus.play("decor_ice", 0.6 + _level * 0.8, -12.0)
	if _level + _foam > 1.0:
		if not _spilled:
			# Débordement : la mousse coule le long du verre, le col est perdu.
			_spilled = true
			release()
			AudioBus.play("glass", 0.9, -6.0)
		_foam = maxf(0.0, 1.0 - _level)
	if _since_release >= 0.0 and not _pouring:
		_since_release += dt
		if _since_release >= p("judge_after_seconds"):
			_judge()
	elif _serve_t >= p("serve_seconds") * slow and not _pouring:
		_judge()  # le client s'impatiente : verre jugé tel quel


func bot_wants() -> Dictionary:
	if _rest > 0.0:
		return {"do": ""}
	# Inclinaison visée : la mousse produite par tout le service doit donner le col voulu au
	# moment du jugement (elle s'affaisse pendant le service et l'attente).
	var keep: float = exp(-(_target * pk("fill_seconds", _glass) * 0.5 + p("judge_after_seconds")) / p("foam_settle_seconds"))
	var want_ratio: float = (_head() / keep) / maxf(_target, 0.05)
	var r0: float = pk("foam_ratio", _glass)
	var tilt_want: float = clampf((1.0 - want_ratio / r0) / maxf(1.0 - p("tilt_foam_min"), 0.01), 0.0, 1.0)
	if _level > 0.02:
		tilt_want = _tilt  # le service est lancé : on ne touche plus à l'inclinaison
	var d: float = tilt_want - _tilt
	var axis: Vector2 = Vector2(clampf(d * 6.0, -1.0, 1.0), 0.0) if absf(d) > 0.03 else Vector2.ZERO
	var settle: float = 1.0 - exp(-p("judge_after_seconds") / p("foam_settle_seconds"))
	var final_level: float = _level + _foam * settle * p("foam_to_liquid")
	if _pouring:
		if final_level + _rate() * 0.03 >= _target:
			return {"do": "release"}
		return {"do": "hold", "v": axis}
	if absf(d) > 0.03:
		return {"do": "axis", "v": axis}
	if final_level < _target - 0.03 and _since_release < 0.0:
		return {"do": "hold", "v": axis}
	return {"do": "axis", "v": Vector2.ZERO}


func bot_apply(want: Dictionary) -> void:
	_axis = want.get("v", Vector2.ZERO) as Vector2
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
	if _rest <= 0.0:
		var left: float = clampf(1.0 - _serve_t / (p("serve_seconds") * slow), 0.0, 1.0)
		draw_rect(Rect2(r.position.x + 30, r.position.y + 26, 200 * left, 8), Palette.GOLD)
		# Bande du col de mousse visé, juste au-dessus du trait.
		var hy0: float = g.end.y - g.size.y * (_target + _head() - p("head_band"))
		var hy1: float = g.end.y - g.size.y * (_target + _head() + p("head_band"))
		draw_rect(Rect2(g.end.x + 8, hy1, 10, hy0 - hy1), Color(FOAM, 0.55))
	# Jauge d'inclinaison : à gauche, droit (mousse) ; à droite, penché (peu de mousse).
	var gauge: Rect2 = Rect2(Vector2(r.position.x + 30, r.end.y - 40), Vector2(200, 10))
	draw_rect(gauge, Color(Palette.INK, 0.7))
	draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * (1.0 - _tilt), gauge.size.y)), Color(FOAM, 0.7))
	draw_rect(gauge, Palette.GOLD, false, 1.5)
	text(Vector2(gauge.get_center().x, gauge.position.y - 14), tr("TRIAL_POUR_FOAM"), UiKit.SIZE_SMALL, Palette.IVORY, "body")
