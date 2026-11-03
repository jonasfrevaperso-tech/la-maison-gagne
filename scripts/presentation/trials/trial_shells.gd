class_name TrialShells
extends ThrowTrial
## BONNETEAU (écran dédié) : un croupier fantôme cache la bille sous l'un de trois gobelets de
## cuivre et les mélange, de plus en plus vite. Suivre le bon gobelet et le désigner
## (gauche / droite puis confirmer, ou cliquer). Trois manches, la dernière avec un quatrième
## gobelet ; le temps de réflexion est compté.

enum Phase { SHOW, HIDE, SHUFFLE, PICK, REVEAL }

const CUP: Vector2 = Vector2(190.0, 210.0)
const TABLE_Y: float = 700.0
const SPACING: float = 380.0

var _phase: Phase = Phase.SHOW
var _round: int = 0
## Position (créneau 0..2) de chaque gobelet ; la bille est sous le gobelet _ball.
var _slot: Array[int] = [0, 1, 2]
var _cups: int = 3
var _ball: int = 0
var _swaps: Array[Vector2i] = []
var _swap_i: int = 0
var _swap_t: float = 0.0
var _lift: float = 1.0
var _cursor: int = 1
var _picked: int = -1
var _scores: Array[float] = []
var _phase_t: float = 0.0
## Scène 3D : gobelets de cuivre (4 au plus), bille, lampe nue qui se balance.
var _cup3: Array[Node3D] = []
var _ball3: MeshInstance3D = null
var _lamp: Node3D = null
var _lamp_light: OmniLight3D = null


func begin() -> void:
	_build_3d()
	_new_round()


## Table de rue en 3D : caisse, nappe verte usée, gobelets de cuivre cerclés, lampe suspendue.
func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.env.background_color = Color(0.04, 0.025, 0.035)
	st.key.light_energy = 0.25
	st.look(Vector3(0, 2.3, 3.5), Vector3(0, 0.35, 0), 38.0)
	var r: Node3D = st.root
	Stage3D.box(r, Vector3(5.2, 0.06, 2.4), Vector3(0, -0.03, 0), Stage3D.mat(Color(0.07, 0.24, 0.13), 0.0, 0.95))
	Stage3D.box(r, Vector3(5.3, 0.08, 0.1), Vector3(0, -0.02, 1.22), Stage3D.mat(Color(0.3, 0.18, 0.08), 0.0, 0.7))
	Stage3D.box(r, Vector3(5.0, 1.2, 2.2), Vector3(0, -0.66, 0), Stage3D.mat(Color(0.24, 0.14, 0.06), 0.0, 0.85))
	for k: int in 6:
		Stage3D.box(r, Vector3(5.02, 0.03, 2.22), Vector3(0, -0.2 - 0.18 * float(k), 0), Stage3D.mat(Color(0.16, 0.09, 0.04)))
	Stage3D.box(r, Vector3(12, 6, 0.2), Vector3(0, 1.5, -3.0), Stage3D.mat(Color(0.09, 0.05, 0.07), 0.0, 1.0))
	_lamp = Node3D.new()
	_lamp.position = Vector3(0, 3.1, 0.2)
	r.add_child(_lamp)
	Stage3D.cylinder(_lamp, 0.006, 1.6, Vector3(0, -0.8, 0), Stage3D.mat(Palette.SMOKE))
	Stage3D.cylinder(_lamp, 0.32, 0.22, Vector3(0, -1.65, 0), Stage3D.mat(Color(0.12, 0.3, 0.2), 0.5, 0.4), 0.08)
	Stage3D.sphere(_lamp, 0.07, Vector3(0, -1.78, 0), Stage3D.glow(Palette.GOLD_LIGHT, 4.0))
	_lamp_light = Stage3D.omni(_lamp, Color(1.0, 0.85, 0.55), 3.2, Vector3(0, -1.85, 0), 6.0)
	_lamp_light.shadow_enabled = RenderQuality.shadows()
	var copper: StandardMaterial3D = Stage3D.mat(Color(0.78, 0.45, 0.24), 0.85, 0.22)
	var rim: StandardMaterial3D = Stage3D.mat(Color(0.5, 0.26, 0.12), 0.7, 0.4)
	for c: int in 4:
		var cup: Node3D = Node3D.new()
		r.add_child(cup)
		Stage3D.cylinder(cup, 0.3, 0.62, Vector3(0, 0.31, 0), copper, 0.19)
		Stage3D.cylinder(cup, 0.32, 0.06, Vector3(0, 0.03, 0), rim)
		Stage3D.cylinder(cup, 0.21, 0.05, Vector3(0, 0.62, 0), rim)
		for y: float in [0.2, 0.44]:
			Stage3D.cylinder(cup, 0.3 - 0.11 * y / 0.62 + 0.006, 0.014, Vector3(0, y, 0), rim)
		_cup3.append(cup)
	_ball3 = Stage3D.sphere(r, 0.1, Vector3.ZERO, Stage3D.mat(Palette.IVORY, 0.0, 0.2))


## Position 3D d'un créneau (même ordre que _slot_x).
func _slot3(s: float) -> float:
	return (s - float(_cups - 1) * 0.5) * 0.9


func _sync_3d() -> void:
	var sway: float = sin(t * 1.3) * 0.18
	_lamp.rotation.z = sway * 0.6
	for c: int in _cup3.size():
		var cup: Node3D = _cup3[c]
		cup.visible = c < _cups
		if c >= _cups:
			continue
		var p2: Vector2 = _cup_pos(c)
		var x: float = _slot3((p2.x - size.x * 0.5) / SPACING + float(_cups - 1) * 0.5)
		var lifted: float = _lift if (_phase != Phase.REVEAL or _slot[c] == _picked or _slot[c] == _slot[_ball]) else 0.0
		cup.position = Vector3(x, lifted * 0.55, (p2.y - TABLE_Y) / 40.0 * 0.35)
		cup.rotation.z = -lifted * 0.25
	_ball3.visible = _phase in [Phase.SHOW, Phase.HIDE, Phase.REVEAL]
	_ball3.position = Vector3(_slot3(float(_slot[_ball])), 0.1, 0)


## Point d'écran au sommet du gobelet posé au créneau s (curseur, notes, clic souris).
func _slot_screen(s: int, y: float = 0.7) -> Vector2:
	if stage == null:
		return Vector2(_slot_x(float(s)), TABLE_Y - CUP.y * y)
	return stage.project(Vector3(_slot3(float(s)), y, 0))


func _new_round() -> void:
	_cups = int(pk("cups", _round))
	_ball = rng.randi_range(0, _cups - 1)
	_slot.clear()
	for k: int in _cups:
		_slot.append(k)
	_picked = -1
	_phase = Phase.SHOW
	_phase_t = 0.0
	_lift = 1.0
	_swaps.clear()
	var n: int = int(pk("swaps", _round))
	for k: int in n:
		var a: int = rng.randi_range(0, _cups - 1)
		var b: int = (a + 1 + rng.randi_range(0, _cups - 2)) % _cups
		_swaps.append(Vector2i(a, b))
	_swap_i = 0
	_swap_t = 0.0


func _swap_time() -> float:
	return pk("swap_seconds", _round) * slow


func _slot_x(s: float) -> float:
	return size.x * 0.5 + (s - float(_cups - 1) * 0.5) * SPACING


## Position animée du gobelet c (créneau courant, ou en plein échange).
func _cup_pos(c: int) -> Vector2:
	var x: float = _slot_x(float(_slot[c]))
	var y: float = TABLE_Y
	if _phase == Phase.SHUFFLE and _swap_i < _swaps.size():
		var sw: Vector2i = _swaps[_swap_i]
		var u: float = clampf(_swap_t / _swap_time(), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		if _slot[c] == sw.x or _slot[c] == sw.y:
			var from: float = float(_slot[c])
			var to: float = float(sw.y if _slot[c] == sw.x else sw.x)
			x = _slot_x(lerpf(from, to, u))
			y += (40.0 if _slot[c] == sw.x else -40.0) * sin(u * PI)
	return Vector2(x, y)


func handle(event: InputEvent) -> bool:
	if _phase != Phase.PICK:
		return confirm_pressed(event) or dir_pressed(event) != Vector2i.ZERO
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and mouse:
		var hs: int = _slot_at(mm.position)
		if hs >= 0:
			_cursor = hs
		return true
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _slot_at(mb.position) >= 0:
			_cursor = _slot_at(mb.position)
			pick()
		return true
	var d: Vector2i = dir_pressed(event)
	if d.x != 0:
		move(d.x)
		return true
	if confirm_pressed(event):
		pick()
		return true
	return false


## Position de départ sans indice : le gobelet du milieu, ou aucun si leur nombre est pair.
func _neutral_cursor() -> int:
	return (_cups >> 1) if _cups % 2 == 1 else -1


func _slot_at(pt: Vector2) -> int:
	for s: int in _cups:
		var top: Vector2 = _slot_screen(s, 0.75)
		var base: Vector2 = _slot_screen(s, 0.0)
		var half: float = maxf(absf(_slot_screen(s, 0.0).x - _slot_screen(mini(s + 1, _cups - 1), 0.0).x), 120.0) * 0.4
		if absf(pt.x - base.x) < half and pt.y > top.y - 20.0 and pt.y < base.y + 30.0:
			return s
	return -1


func move(dx: int) -> void:
	if _cursor < 0:
		# Aucun gobelet présélectionné (nombre pair) : le premier appui choisit un des deux du centre.
		_cursor = (_cups >> 1) - (1 if dx < 0 else 0)
	else:
		_cursor = clampi(_cursor + dx, 0, _cups - 1)
	AudioBus.play("hover", 1.0, -8.0)


func pick(timed_out: bool = false) -> void:
	if _phase != Phase.PICK or (_cursor < 0 and not timed_out):
		return
	_picked = _cursor if _cursor >= 0 else (_cups >> 1)
	var ok: bool = _slot[_ball] == _picked
	var thinking: float = clampf(_phase_t / (p("pick_seconds") * slow), 0.0, 1.0)
	# Trop tard : le croupier soulève le gobelet visé, mais la manche ne rapporte rien.
	var sc: float = (1.0 - 0.15 * thinking) if ok and not timed_out else 0.0
	_scores.append(sc)
	_phase = Phase.REVEAL
	_phase_t = 0.0
	AudioBus.play("cloth", 1.3, -4.0)
	AudioBus.play("chips_win" if ok else "lose_soft", 1.0, -2.0)
	pop(_slot_screen(_picked, 1.4), sc, "TRIAL_SHELLS_FOUND" if ok else "TRIAL_SHELLS_EMPTY")


func tick(dt: float) -> void:
	_phase_t += dt
	match _phase:
		Phase.SHOW:
			if _phase_t > 1.2 * slow:
				_phase = Phase.HIDE
				_phase_t = 0.0
		Phase.HIDE:
			_lift = maxf(1.0 - _phase_t / 0.35, 0.0)
			if _lift <= 0.0:
				AudioBus.play("stone", 1.6, -8.0)
				_phase = Phase.SHUFFLE
				_phase_t = 0.0
		Phase.SHUFFLE:
			_swap_t += dt
			if _swap_t >= _swap_time():
				var sw: Vector2i = _swaps[_swap_i]
				for c: int in _cups:
					if _slot[c] == sw.x:
						_slot[c] = sw.y
					elif _slot[c] == sw.y:
						_slot[c] = sw.x
				AudioBus.play("cloth", 1.5 + 0.1 * float(_swap_i % 3), -8.0)
				_swap_i += 1
				_swap_t = 0.0
				if _swap_i >= _swaps.size():
					_phase = Phase.PICK
					_phase_t = 0.0
					_cursor = _neutral_cursor()
		Phase.PICK:
			if _phase_t > p("pick_seconds") * slow:
				pick(true)  # trop long : le croupier soulève le gobelet visé, sans points
		Phase.REVEAL:
			_lift = minf(_phase_t / 0.3, 1.0)
			if _phase_t > 1.3:
				_round += 1
				if _round >= pi("rounds"):
					finish(mean(_scores))
				else:
					_new_round()


func bot_wants() -> Dictionary:
	if _phase != Phase.PICK or _phase_t < 0.3:
		return {"do": ""}
	var goal: int = _slot[_ball]
	if goal == _cursor:
		return {"do": "confirm"}
	return {"do": "dir", "dir": Vector2i(signi(goal - _cursor), 0)}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"confirm":
			pick()
		"dir":
			move((w["dir"] as Vector2i).x)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	_sync_3d()
	pips(Vector2(size.x * 0.5, 110), _scores, pi("rounds"))
	var msg: String = ""
	match _phase:
		Phase.SHOW:
			msg = tr("TRIAL_SHELLS_WATCH")
		Phase.SHUFFLE:
			msg = tr("TRIAL_SHELLS_FOLLOW")
		Phase.PICK:
			msg = tr("TRIAL_SHELLS_PICK")
	if msg != "":
		text(Vector2(size.x * 0.5, 200), msg, UiKit.SIZE_H2, Palette.IVORY)
	if _phase == Phase.PICK and _cursor >= 0:
		# Flèche cyan au-dessus du gobelet visé.
		var top: Vector2 = _slot_screen(_cursor, 0.8) + Vector2(0, -20.0 - 8.0 * sin(t * 8.0))
		draw_colored_polygon(PackedVector2Array([top, top + Vector2(-26, -34), top + Vector2(26, -34)]), Palette.CYAN)
		draw_polyline(PackedVector2Array([top, top + Vector2(-26, -34), top + Vector2(26, -34), top]), Palette.INK, 3.0)
	if _phase == Phase.PICK:
		var left: float = clampf(1.0 - _phase_t / (p("pick_seconds") * slow), 0.0, 1.0)
		var bar: Rect2 = Rect2(size.x * 0.5 - 200.0, 980.0, 400.0, 10.0)
		draw_rect(bar, Palette.VELVET_DEEP)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Palette.GOLD)
