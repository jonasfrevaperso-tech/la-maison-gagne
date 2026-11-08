class_name TrialCutting
extends ThrowTrial
## LE DÉCOUPAGE (Cuisines, 2.0) : vue plongeante sur la planche. Le couteau avance tout seul le
## long de la pièce ; le stick le guide sur le pointillé (carotte en vagues, filet de poisson,
## gâteau en zigzag). Sur les arêtes et les cerises (zones rouges), il faut soulever la lame
## (maintenir) — mais une lame levée ailleurs ne coupe rien. Trois pièces, de plus en plus vite.
## Note = moyenne, sur tout le trajet, de la justesse du tracé (lame posée) et des sauts (lame levée).

enum Item { CARROT, FISH, CAKE }

const PX3: float = 0.004
const X0: float = 380.0
const X1: float = 1540.0
const MID_Y: float = 560.0
const KNIFE_LEN: float = 150.0
const SAMPLE: float = 12.0
const ITEM_GAP: float = 0.6

var _item: int = 0
var _x: float = X0
var _y: float = MID_Y
var _lifted: bool = false
var _axis: Vector2 = Vector2.ZERO
var _mouse_y: float = -1.0
var _waves: Array[Vector3] = []  # (amplitude, fréquence, phase)
var _bones: Array[Vector2] = []  # (début, fin) en x
var _trail: PackedVector2Array = PackedVector2Array()
var _cut_ok: Array[bool] = []
var _sum: float = 0.0
var _n: int = 0
var _next_sample: float = X0
var _gap: float = 0.0
var _item_marks: Array[float] = []
var _ended: bool = false
var _knife3: Node3D = null
var _food3: Node3D = null
var _hands3: Array[MeshInstance3D] = []


func begin() -> void:
	_build_3d()
	_new_item()


func _items() -> int:
	return pi("items")


func _new_item() -> void:
	_x = X0
	_waves.clear()
	_bones.clear()
	_trail = PackedVector2Array()
	_cut_ok.clear()
	_next_sample = X0
	var amp: float = pk("amplitude", _item)
	for k: int in 2:
		var freq: float = rng.randf_range(p("freq_min"), p("freq_max")) * (1.0 + float(k))
		_waves.append(Vector3(amp * (0.7 if k == 0 else 0.3), freq, rng.randf_range(0.0, TAU)))
	var nb: int = int(pk("bones", _item))
	for k2: int in nb:
		var cx: float = lerpf(X0 + 220.0, X1 - 180.0, (float(k2) + rng.randf_range(0.25, 0.75)) / float(maxi(nb, 1)))
		var w: float = rng.randf_range(p("bone_min"), p("bone_max"))
		_bones.append(Vector2(cx - w * 0.5, cx + w * 0.5))
	_y = _path(X0)
	_build_food()


## Le pointillé : somme de deux ondes (le zigzag du gâteau est une onde triangulaire).
func _path(x: float) -> float:
	var u: float = (x - X0) / (X1 - X0)
	var y: float = MID_Y
	for w: Vector3 in _waves:
		var a: float = u * TAU * w.y + w.z
		y += w.x * (sin(a) if _item != Item.CAKE else (2.0 / PI) * asin(sin(a)))
	return y


func _on_bone(x: float) -> bool:
	for b: Vector2 in _bones:
		if x >= b.x and x <= b.y:
			return true
	return false


func _speed() -> float:
	return pk("speed", _item) / slow


func tick(dt: float) -> void:
	_sync_3d()
	if _ended:
		return
	if _gap > 0.0:
		_gap -= dt
		if _gap <= 0.0:
			_item += 1
			if _item >= _items():
				_ended = true
				finish(_sum / float(maxi(_n, 1)))
				return
			_new_item()
		return
	# Guidage : le stick règle la vitesse verticale ; la souris donne la hauteur visée.
	var v: float = clampf(held_vector().y + _axis.y, -1.0, 1.0)
	if mouse and _mouse_y >= 0.0:
		_y = move_toward(_y, _mouse_y, p("guide_speed") * dt)
	else:
		_y += v * p("guide_speed") * dt
	_y = clampf(_y, MID_Y - 300.0, MID_Y + 300.0)
	_x += _speed() * dt
	while _next_sample <= minf(_x, X1):
		_judge(_next_sample)
		_next_sample += SAMPLE
	if _x >= X1:
		_gap = ITEM_GAP * slow
		var share: float = 0.0
		for ok: bool in _cut_ok:
			share += 1.0 if ok else 0.0
		_item_marks.append(share / float(maxi(_cut_ok.size(), 1)))
		pop(Vector2(X1 - 100.0, MID_Y - 220.0), _item_marks[-1])
		AudioBus.play("chime", 1.1, -6.0)


## Un point du trajet : sur une arête, il fallait lever ; ailleurs, couper au plus près du trait.
func _judge(x: float) -> void:
	var q: float = 0.0
	if _on_bone(x):
		q = 1.0 if _lifted else 0.0
		if not _lifted and (_cut_ok.is_empty() or _cut_ok[-1]):
			AudioBus.play("clang", 1.4, -8.0)
	elif not _lifted:
		var err: float = absf(_y - _path(x))
		var ok: float = p("tolerance_px") * widen()
		q = 1.0 if err <= ok else clampf(1.0 - (err - ok) / maxf(p("miss_px") - ok, 1.0), 0.0, 1.0)
		_trail.append(Vector2(x, _y))
		if int(x) % 48 < int(SAMPLE):
			AudioBus.play("blade", rng.randf_range(0.9, 1.2), -16.0)
	_sum += q
	_n += 1
	_cut_ok.append(q >= 0.6)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_y = mm.position.y
		return true
	if confirm_pressed(event):
		_lifted = true
		return true
	if confirm_released(event):
		_lifted = false
		return true
	return false


func journal() -> Dictionary:
	return {"items": _items(), "samples": _n}


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	if _gap > 0.0:
		return {"do": "release"} if _lifted else {"do": "axis", "v": Vector2.ZERO}
	# Anticipation par la pente du trait (vitesse voulue) + rappel doux vers le trait un peu devant.
	var xa: float = minf(_x + _speed() * p("bot_lead"), X1 - 6.0)
	var slope: float = (_path(xa + 5.0) - _path(xa - 5.0)) / 10.0
	var vy: float = slope * _speed() + (_path(xa) - _y) * p("bot_gain")
	var v: Vector2 = Vector2(0.0, clampf(vy / p("guide_speed"), -1.0, 1.0))
	var margin: float = _speed() * p("bot_lift_margin")
	var want_up: bool = false
	for b: Vector2 in _bones:
		if _x >= b.x - margin and _x <= b.y + margin * 0.5:
			want_up = true
	if want_up and not _lifted:
		return {"do": "hold"}
	if not want_up and _lifted:
		return {"do": "release"}
	return {"do": "axis", "v": v}


func bot_apply(w: Dictionary) -> void:
	if w.has("v"):
		_axis = w["v"] as Vector2
	match String(w.get("do", "")):
		"hold":
			_lifted = true
		"release":
			_lifted = false


# --------------------------------------------------------------------------- décor 3D (vue plongeante)


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	st.env.background_color = Color("101014")
	st.env.ambient_light_energy = 0.5
	st.key.light_energy = 0.9
	var r: Node3D = st.root
	# Plan de travail inox brossé, planche de bois de bout, torchon, bols d'ingrédients.
	Stage3D.box(r, Vector3(14.0, 8.0, 0.04), st.to3(Vector2(960.0, 540.0), -0.06), Stage3D.mat(Color("a8acb6"), 0.8, 0.35))
	var oak: StandardMaterial3D = Stage3D.mat(Color("a8743c"), 0.0, 0.6)
	var oak2: StandardMaterial3D = Stage3D.mat(Color("96642e"), 0.0, 0.65)
	for k: int in 9:
		var plank_at: Vector3 = st.to3(Vector2(960.0, MID_Y - 312.0 + 78.0 * float(k)), -0.02)
		Stage3D.box(r, Vector3((X1 - X0 + 200.0) * PX3, 78.0 * PX3, 0.06), plank_at, oak if k % 2 == 0 else oak2)
	Stage3D.box(r, Vector3(1.1, 0.5, 0.01), st.to3(Vector2(180.0, 900.0), 0.0), Stage3D.mat(Color("e8e0d0"), 0.0, 0.95))
	var stripe: StandardMaterial3D = Stage3D.mat(Palette.ROULETTE_RED, 0.0, 0.9)
	for k2: int in 4:
		Stage3D.box(r, Vector3(1.1, 0.03, 0.012), st.to3(Vector2(180.0, 860.0 + 26.0 * float(k2)), 0.002), stripe)
	var bowl_cols: Array[Color] = [Color("e8c040"), Color("6a9a3a"), Color("d84a2a")]
	for k3: int in 3:
		var at: Vector3 = st.to3(Vector2(1760.0, 230.0 + 260.0 * float(k3)), 0.0)
		var bowl: MeshInstance3D = Stage3D.cylinder(r, 0.26, 0.1, at + Vector3(0, 0, 0.05), Stage3D.mat(Color("f2efe8"), 0.0, 0.25), 0.18)
		bowl.rotation.x = PI * 0.5
		var fill: MeshInstance3D = Stage3D.cylinder(r, 0.21, 0.02, at + Vector3(0, 0, 0.09), Stage3D.mat(bowl_cols[k3], 0.0, 0.7))
		fill.rotation.x = PI * 0.5
	# Couteau de chef : lame d'acier, mitre, manche noir à rivets.
	_knife3 = Node3D.new()
	r.add_child(_knife3)
	var blade: MeshInstance3D = Stage3D.box(_knife3, Vector3(0.06, KNIFE_LEN * PX3, 0.008), Vector3(0, KNIFE_LEN * PX3 * 0.5, 0),
		Stage3D.mat(Color("dfe3ea"), 0.95, 0.15))
	blade.name = "blade"
	Stage3D.box(_knife3, Vector3(0.07, 0.03, 0.02), Vector3(0, KNIFE_LEN * PX3 + 0.015, 0.0), Stage3D.mat(Palette.GOLD, 0.8, 0.3))
	Stage3D.box(_knife3, Vector3(0.05, 0.42, 0.03), Vector3(0, KNIFE_LEN * PX3 + 0.24, 0.0), Stage3D.mat(Color("15121a"), 0.1, 0.4))
	for k4: int in 3:
		Stage3D.sphere(_knife3, 0.008, Vector3(0, KNIFE_LEN * PX3 + 0.1 + 0.12 * float(k4), 0.016), Stage3D.mat(Palette.IVORY, 0.8, 0.3))
	# Mains du cuisinier (vue de dessus) : l'une tient la pièce, l'autre le couteau.
	for k5: int in 2:
		_hands3.append(Stage3D.sphere(r, 0.11, Vector3.ZERO, Stage3D.mat(Color("e8b896"), 0.0, 0.7)))


## La pièce à découper, posée sur la planche.
func _build_food() -> void:
	if stage == null:
		return
	if _food3 != null:
		_food3.queue_free()
	_food3 = Node3D.new()
	stage.root.add_child(_food3)
	var st: Stage3D = stage
	var c: Vector3 = st.to3(Vector2((X0 + X1) * 0.5, MID_Y), 0.05)
	var span: float = (X1 - X0) * PX3
	match _item:
		Item.CARROT:
			var body: MeshInstance3D = MeshInstance3D.new()
			body.mesh = MeshPool.capsule(0.55, span)
			body.material_override = Stage3D.mat(Color("ee7a22"), 0.0, 0.6)
			body.rotation.z = PI * 0.5
			body.scale = Vector3(1.0, 1.0, 0.35)
			body.position = c
			_food3.add_child(body)
			for k: int in 5:
				var leaf: MeshInstance3D = Stage3D.box(_food3, Vector3(0.5, 0.06, 0.02), c + Vector3(-span * 0.5 - 0.3, -0.2 + 0.1 * float(k), 0.05),
					Stage3D.mat(Color("4a8a2a"), 0.0, 0.7))
				leaf.rotation.z = (float(k) - 2.0) * 0.25
		Item.FISH:
			var fish: MeshInstance3D = Stage3D.sphere(_food3, 0.5, c, Stage3D.mat(Color("c8ccd8"), 0.7, 0.3))
			fish.scale = Vector3(span, 1.4, 0.25)
			var fin: StandardMaterial3D = Stage3D.mat(Color("9aa0b0"), 0.6, 0.35)
			var tail: MeshInstance3D = Stage3D.box(_food3, Vector3(0.5, 0.9, 0.04), c + Vector3(span * 0.5 + 0.15, 0, 0), fin)
			tail.rotation.z = PI * 0.25
			Stage3D.sphere(_food3, 0.07, c + Vector3(-span * 0.5 + 0.35, 0.18, 0.12), Stage3D.mat(Color("101014"), 0.3, 0.2))
		Item.CAKE:
			var cake: MeshInstance3D = Stage3D.box(_food3, Vector3(span, 2.3, 0.3), c, Stage3D.mat(Color("5a2a1a"), 0.0, 0.6))
			cake.name = "cake"
			Stage3D.box(_food3, Vector3(span * 0.98, 2.2, 0.02), c + Vector3(0, 0, 0.16), Stage3D.mat(Color("f2e8d8"), 0.0, 0.4))
	# Arêtes et cerises sur les zones à sauter.
	for b: Vector2 in _bones:
		var bx: float = (b.x + b.y) * 0.5
		var at: Vector3 = st.to3(Vector2(bx, _path(bx)), 0.22)
		if _item == Item.CAKE:
			Stage3D.sphere(_food3, 0.09, at, Stage3D.mat(Color("c0102a"), 0.2, 0.2))
		else:
			for k2: int in 4:
				var bone: MeshInstance3D = Stage3D.box(_food3, Vector3(0.015, 0.5, 0.015), at + Vector3((float(k2) - 1.5) * 0.06, 0, 0),
					Stage3D.mat(Palette.IVORY, 0.0, 0.5))
				bone.rotation.z = 0.2


func _sync_3d() -> void:
	if _knife3 == null:
		return
	var st: Stage3D = stage
	var lift: float = 0.25 if _lifted else 0.12
	_knife3.position = st.to3(Vector2(minf(_x, X1), _y), lift)
	_knife3.rotation = Vector3(0.0, 0.0, PI)
	_knife3.scale = Vector3.ONE * (1.12 if _lifted else 1.0)
	_hands3[0].position = st.to3(Vector2(minf(_x, X1), _y + KNIFE_LEN + 110.0), lift + 0.1)
	_hands3[1].position = st.to3(Vector2(clampf(_x - 240.0, X0 - 60.0, X1), MID_Y - 30.0), 0.3)
	_hands3[1].scale = Vector3(1.3, 1.0, 0.6)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	pips(Vector2(960.0, 110.0), _item_marks, _items())
	text(Vector2(960.0, 160.0), tr("TRIAL_CUTTING_ITEM_%d" % mini(_item, _items() - 1)), UiKit.SIZE_H2, Palette.GOLD_LIGHT)
	# Pointillé à suivre (rouge sur les zones à sauter), entaille déjà faite.
	var x: float = X0
	while x < X1:
		var c: Color = Color(Palette.ROULETTE_RED, 0.95) if _on_bone(x) else Color(Palette.INK, 0.85)
		draw_line(Vector2(x, _path(x)), Vector2(x + 10.0, _path(x + 10.0)), c, 6.0 if _on_bone(x) else 4.0)
		x += 22.0
	if _trail.size() >= 2:
		draw_polyline(_trail, Color("2a1206", 0.9), 3.0)
	if _gap <= 0.0:
		draw_circle(Vector2(minf(_x, X1), _y), 9.0, Palette.GOLD_LIGHT if not _lifted else Palette.CYAN)
		if _lifted:
			text(Vector2(minf(_x, X1), _y - 60.0), tr("TRIAL_CUTTING_LIFTED"), UiKit.SIZE_SMALL, Palette.CYAN)
