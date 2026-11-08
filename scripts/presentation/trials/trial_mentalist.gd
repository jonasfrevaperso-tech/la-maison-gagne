class_name TrialMentalist
extends ThrowTrial
## LE MENTALISTE (Cabaret, 2.0) : le mentaliste a caché une combinaison de jetons sous son
## foulard. À chaque proposition, il répond par des signes : un point doré par jeton bien placé,
## un point blanc par bonne couleur mal placée. Trouver la combinaison en peu d'essais, avant la
## fin du temps. Épreuve de logique (D-046) : aucune adresse, rien au hasard une fois l'indice lu.
## Note = selon le nombre d'essais ; non trouvée : un peu pour la meilleure approche.

const COLORS: Array[Color] = [Color("ff4d6d"), Color("ffd23f"), Color("29e0ff"), Color("2ee6a8"), Color("b03aff")]
const PX3: float = 0.005
const FLOOR_Y: float = 760.0
const BOARD_X: float = 1180.0
const BOARD_Y: float = 250.0
const ROW_H: float = 74.0
const CHIP_R: float = 26.0
const SLOT_GAP: float = 76.0
const CUR_Y: float = 860.0
const CUR_R: float = 44.0
const CUR_GAP: float = 130.0
const SUBMIT: Rect2 = Rect2(1240.0, 815.0, 230.0, 90.0)

var _slots: int = 3
var _ncol: int = 5
var _secret: Array[int] = []
var _guess: Array[int] = []
var _cursor: int = 0
var _history: Array[Array] = []  # [code, noirs, blancs]
var _solved: bool = false
var _ended: bool = false
var _end_t: float = -1.0
var _bot_plan: Array[int] = []
var _mentalist: Figure3D = null
var _ball_mat: StandardMaterial3D = null
var _ball_light: OmniLight3D = null
var _chips3: Array[Node3D] = []
var _heads: Array[Node3D] = []
var _flash: float = 0.0


func begin() -> void:
	_slots = pi("slots")
	_ncol = mini(pi("colors"), COLORS.size())
	for k: int in _slots:
		_secret.append(rng.randi_range(0, _ncol - 1))
		_guess.append(0)
	_build_3d()


func _dur() -> float:
	return p("duration") * slow


## Indice (noirs : bien placés, blancs : bonne couleur ailleurs).
static func clue(code: Array[int], secret: Array[int], ncol: int) -> Vector2i:
	var black: int = 0
	var cc: Array[int] = []
	var cs: Array[int] = []
	cc.resize(ncol)
	cs.resize(ncol)
	for k: int in code.size():
		if code[k] == secret[k]:
			black += 1
		else:
			cc[code[k]] += 1
			cs[secret[k]] += 1
	var white: int = 0
	for c: int in ncol:
		white += mini(cc[c], cs[c])
	return Vector2i(black, white)


func submit() -> void:
	if _ended or _solved:
		return
	var code: Array[int] = _guess.duplicate()
	var cl: Vector2i = clue(code, _secret, _ncol)
	_history.append([code, cl.x, cl.y])
	_bot_plan.clear()
	_flash = 1.0
	AudioBus.play("chime" if cl.x == _slots else "card_flip", 1.0 + 0.1 * float(cl.x), -3.0)
	if cl.x == _slots:
		_solved = true
		pop(Vector2(BOARD_X + SLOT_GAP, _row_y(_history.size() - 1)), _score_now(), "TRIAL_MENTALIST_FOUND")
		_end_t = t + p("reveal_seconds")
	elif _history.size() >= pi("tries"):
		pop(Vector2(BOARD_X + SLOT_GAP, _row_y(_history.size() - 1)), 0.0, "TRIAL_MENTALIST_OUT")
		_end_t = t + p("reveal_seconds")


func _score_now() -> float:
	if _solved:
		var table: Array = Balance.data()["throw_trials"]["mentalist"]["try_scores"] as Array
		return float(table[clampi(_history.size() - 1, 0, table.size() - 1)])
	var best: float = 0.0
	for h: Array in _history:
		best = maxf(best, p("fail_black") * float(h[1]) + p("fail_white") * float(h[2]))
	return best


func tick(dt: float) -> void:
	_flash = maxf(0.0, _flash - dt * 2.0)
	_sync_3d(dt)
	if _ended:
		return
	if _end_t < 0.0 and t >= _dur():
		pop(Vector2(960.0, 300.0), 0.0, "TRIAL_MENTALIST_TIME")
		_end_t = t + p("reveal_seconds")
	if _end_t >= 0.0 and t >= _end_t:
		_ended = true
		finish(_score_now())


func _locked() -> bool:
	return _ended or _end_t >= 0.0


func cycle(d: int) -> void:
	if _locked():
		return
	_guess[_cursor] = posmod(_guess[_cursor] + d, _ncol)
	AudioBus.play("chip_place", 1.0 + 0.08 * float(_guess[_cursor]), -8.0)


func move(d: int) -> void:
	if _locked():
		return
	_cursor = posmod(_cursor + d, _slots)
	AudioBus.play("tick", 1.3, -10.0)


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed:
			_click(mb.position, mb.button_index == MOUSE_BUTTON_RIGHT)
		return true
	if confirm_pressed(event):
		submit()
		return true
	var d: Vector2i = dir_pressed(event)
	if d.x != 0:
		move(d.x)
		return true
	if d.y != 0:
		cycle(-d.y)
		return true
	var s: int = sym_pressed(event)
	if s == 0 or s == 2:
		move(-1 if s == 0 else 1)
		return true
	if s == 1:
		cycle(1)
		return true
	return false


## Souris et doigt : toucher un jeton le change de couleur (clic droit : en arrière), le bouton
## « Proposer » valide.
func _click(pos: Vector2, back: bool) -> void:
	if SUBMIT.grow(10.0).has_point(pos):
		submit()
		return
	for k: int in _slots:
		if pos.distance_to(_cur_pos(k)) <= CUR_R + 14.0:
			_cursor = k
			cycle(-1 if back else 1)
			return


func direct_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_click(mb.position, false)
	return true


func journal() -> Dictionary:
	var rows: Array = []
	for h: Array in _history:
		rows.append({"code": h[0], "black": h[1], "white": h[2]})
	return {"secret": _secret, "guesses": rows, "solved": _solved}


# --------------------------------------------------------------------------- bot


## Codes encore possibles d'après les indices reçus.
func _candidates() -> Array[Array]:
	var out: Array[Array] = []
	var total: int = int(pow(float(_ncol), float(_slots)))
	for n: int in total:
		var code: Array[int] = _decode(n)
		var ok: bool = true
		for h: Array in _history:
			var hc: Array[int] = []
			hc.assign(h[0])
			if clue(hc, code, _ncol) != Vector2i(int(h[1]), int(h[2])):
				ok = false
				break
		if ok:
			out.append(code)
	return out


func _decode(n: int) -> Array[int]:
	var code: Array[int] = []
	var v: int = n
	for k: int in _slots:
		code.append(v % _ncol)
		v /= _ncol
	return code


## Proposition « minimax » parmi les candidats : celle dont la pire réponse laisse le moins de
## possibilités.
func _plan() -> Array[int]:
	var cands: Array[Array] = _candidates()
	if cands.size() <= 2:
		var first: Array[int] = []
		first.assign(cands[0])
		return first
	var best: Array[int] = []
	var best_worst: int = 1 << 30
	for g: Array in cands:
		var ga: Array[int] = []
		ga.assign(g)
		var parts: Dictionary[Vector2i, int] = {}
		for c: Array in cands:
			var ca: Array[int] = []
			ca.assign(c)
			var cl: Vector2i = clue(ga, ca, _ncol)
			parts[cl] = int(parts.get(cl, 0)) + 1
		var worst: int = 0
		for v: int in parts.values():
			worst = maxi(worst, v)
		if worst < best_worst:
			best_worst = worst
			best = ga
	return best


func bot_wants() -> Dictionary:
	if _locked():
		return {"do": ""}
	if _bot_plan.is_empty():
		_bot_plan = _plan()
	if _guess == _bot_plan:
		return {"do": "confirm"}
	if _guess[_cursor] != _bot_plan[_cursor]:
		var up: int = posmod(_bot_plan[_cursor] - _guess[_cursor], _ncol)
		return {"do": "dir", "dir": Vector2i(0, -1 if up <= _ncol / 2 else 1)}
	for k: int in _slots:
		if _guess[k] != _bot_plan[k]:
			return {"do": "dir", "dir": Vector2i(1 if k > _cursor else -1, 0)}
	return {"do": ""}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"confirm":
			submit()
		"dir":
			var d: Vector2i = w["dir"] as Vector2i
			if d.x != 0:
				move(d.x)
			else:
				cycle(-d.y)


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	var deco: Dictionary = CabaretSet.build(st, FLOOR_Y, 720.0)
	_heads.assign(deco.get("audience", []))
	st.env.ambient_light_energy = 0.22
	var r: Node3D = st.root
	var at: Vector3 = st.to3(Vector2(560.0, FLOOR_Y), -0.4)
	# Guéridon drapé de velours, boule de cristal sur son socle de laiton.
	var cloth: StandardMaterial3D = Stage3D.mat(Color("3a0a4a"), 0.0, 0.8)
	Stage3D.cylinder(r, 0.55, 0.8, at + Vector3(0, 0.4, 0.5), cloth, 0.45)
	Stage3D.cylinder(r, 0.58, 0.03, at + Vector3(0, 0.81, 0.5), Stage3D.mat(Palette.GOLD, 0.7, 0.3))
	Stage3D.cylinder(r, 0.09, 0.08, at + Vector3(0, 0.86, 0.5), Stage3D.mat(Palette.GOLD, 0.8, 0.25), 0.12)
	_ball_mat = Stage3D.glow(Color(0.55, 0.3, 1.0), 1.2)
	_ball_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ball_mat.albedo_color.a = 0.7
	Stage3D.sphere(r, 0.16, at + Vector3(0, 1.05, 0.5), _ball_mat)
	_ball_light = Stage3D.omni(r, Color(0.6, 0.35, 1.0), 1.2, at + Vector3(0, 1.1, 0.8), 3.0)
	# Le mentaliste, en turban et cape, derrière son guéridon.
	_mentalist = Figure3D.new().build(1.8, {"coat": Color("1a0e2e"), "trim": Palette.GOLD, "hat": "chef",
		"hat_col": Color("e8dcc0"), "hair": Color("101010"), "trousers": Color("120a1a")})
	_mentalist.position = at + Vector3(0, 0, -0.2)
	r.add_child(_mentalist)
	Stage3D.sphere(_mentalist, 0.03, Vector3(0, 1.18 * 0.97, 0.12), Stage3D.glow(Color("ff2e88"), 3.0))
	# Les jetons de la proposition en cours, posés sur le guéridon.
	for k: int in _slots:
		var chip: Node3D = CasinoChip3D.build(r, COLORS[0], 0.07)
		chip.position = at + Vector3(-0.22 + 0.22 * float(k), 0.84, 0.85)
		_chips3.append(chip)


func _sync_3d(dt: float) -> void:
	if _mentalist == null:
		return
	var thinking: bool = not _locked()
	if _solved:
		_mentalist.animate(&"cheer", t * 4.0, dt)
	elif thinking:
		_mentalist.animate(&"point", t, dt, sin(t * 0.7) * 0.5)
	else:
		_mentalist.animate(&"idle", t * 2.0, dt)
	_ball_mat.emission_energy_multiplier = 1.0 + 0.5 * sin(t * 2.5) + 2.5 * _flash
	_ball_light.light_energy = 1.0 + 0.4 * sin(t * 2.5) + 3.0 * _flash
	for k: int in _chips3.size():
		var chip: Node3D = _chips3[k]
		chip.position.y = stage.to3(Vector2(560.0, FLOOR_Y), -0.4).y + 0.84 + (0.05 if k == _cursor and thinking else 0.0)
		_tint(chip, COLORS[_guess[k]])
	CabaretSet.bob_audience(_heads, t * 0.25, 0.3)


func _tint(chip: Node3D, col: Color) -> void:
	for c: Node in chip.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi != null and mi.material_override is StandardMaterial3D:
			var m: StandardMaterial3D = mi.material_override as StandardMaterial3D
			if m.albedo_color.s > 0.3:
				m.albedo_color = col
			return


# --------------------------------------------------------------------------- dessin


func _row_y(k: int) -> float:
	return BOARD_Y + ROW_H * float(k)


func _cur_pos(k: int) -> Vector2:
	return Vector2(BOARD_X - 300.0 + CUR_GAP * float(k), CUR_Y)


func _chip(at: Vector2, r: float, c: int, alpha: float = 1.0) -> void:
	draw_circle(at, r, Color(COLORS[c], alpha))
	draw_arc(at, r, 0, TAU, 32, Color(Palette.IVORY, 0.8 * alpha), 2.0)
	# Forme distincte par couleur (lisible sans les couleurs).
	var s: float = r * 0.42
	var ink: Color = Color(Palette.INK, 0.85 * alpha)
	match c:
		0:
			draw_circle(at, s, ink)
		1:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s), at + Vector2(s, 0), at + Vector2(0, s), at + Vector2(-s, 0)]), ink)
		2:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s), at + Vector2(s, s * 0.8), at + Vector2(-s, s * 0.8)]), ink)
		3:
			draw_rect(Rect2(at - Vector2(s, s) * 0.8, Vector2(s, s) * 1.6), ink)
		_:
			draw_line(at - Vector2(s, 0), at + Vector2(s, 0), ink, 5.0)
			draw_line(at - Vector2(0, s), at + Vector2(0, s), ink, 5.0)


func paint() -> void:
	var tries: int = pi("tries")
	# Tableau des propositions : jetons, puis les signes du mentaliste.
	var panel: Rect2 = Rect2(BOARD_X - 60.0, BOARD_Y - 60.0, SLOT_GAP * float(_slots) + 260.0, ROW_H * float(tries) + 30.0)
	draw_rect(panel, Color(Palette.INK, 0.86))
	draw_rect(panel, Palette.GOLD_DARK, false, 2.0)
	for k: int in tries:
		var y: float = _row_y(k)
		text(Vector2(BOARD_X - 30.0, y), str(k + 1), UiKit.SIZE_SMALL, Palette.SMOKE, "body", 4)
		if k >= _history.size():
			for s: int in _slots:
				draw_arc(Vector2(BOARD_X + 20.0 + SLOT_GAP * float(s), y), CHIP_R, 0, TAU, 24, Color(Palette.SMOKE, 0.3), 2.0)
			continue
		var h: Array = _history[k]
		var code: Array = h[0]
		for s2: int in _slots:
			_chip(Vector2(BOARD_X + 20.0 + SLOT_GAP * float(s2), y), CHIP_R, int(code[s2]))
		var px: float = BOARD_X + 20.0 + SLOT_GAP * float(_slots)
		for b: int in int(h[1]):
			draw_circle(Vector2(px + 26.0 * float(b), y), 10.0, Palette.GOLD_LIGHT)
		for w: int in int(h[2]):
			draw_circle(Vector2(px + 26.0 * float(int(h[1]) + w), y), 10.0, Palette.IVORY)
			draw_arc(Vector2(px + 26.0 * float(int(h[1]) + w), y), 10.0, 0, TAU, 16, Palette.INK, 2.0)
	# Proposition en cours : grands jetons, curseur, bouton « Proposer ».
	for k2: int in _slots:
		var c: Vector2 = _cur_pos(k2)
		_chip(c, CUR_R, _guess[k2])
		if k2 == _cursor and not _locked():
			draw_arc(c, CUR_R + 10.0, 0, TAU, 40, Palette.GOLD_LIGHT, 4.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -CUR_R - 34.0), c + Vector2(-12, -CUR_R - 18.0),
				c + Vector2(12, -CUR_R - 18.0)]), Palette.GOLD_LIGHT)
	draw_rect(SUBMIT, Color(Palette.INK, 0.9))
	draw_rect(SUBMIT, Palette.GOLD, false, 3.0)
	text(SUBMIT.get_center(), tr("TRIAL_MENTALIST_SUBMIT"), UiKit.SIZE_BODY, Palette.GOLD_LIGHT)
	# Combinaison révélée à la fin.
	if _end_t >= 0.0:
		text(Vector2(560.0, 230.0), tr("TRIAL_MENTALIST_SECRET"), UiKit.SIZE_BODY, Palette.IVORY)
		for k3: int in _slots:
			_chip(Vector2(560.0 - SLOT_GAP + SLOT_GAP * float(k3), 300.0), CHIP_R + 6.0, _secret[k3])
	var left: float = clampf(1.0 - t / _dur(), 0.0, 1.0)
	draw_rect(Rect2(660.0, 120.0, 600.0, 10.0), Color(Palette.INK, 0.7))
	draw_rect(Rect2(660.0, 120.0, 600.0 * left, 10.0), Palette.GOLD if left > 0.25 else Palette.ROULETTE_RED)
	text(Vector2(960.0, 165.0), tr("TRIAL_MENTALIST_TRIES") % [_history.size(), tries], UiKit.SIZE_BODY, Palette.IVORY)
