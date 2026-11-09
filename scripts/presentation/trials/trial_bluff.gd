class_name TrialBluff
extends ThrowTrial
## LE BLUFF (Fumoir, 2.0) : quatre joueurs attablés, chacun son tic (se gratter le nez, tirer
## l'oreille, lisser la moustache, tapoter la table) qu'il refait de temps en temps, à son rythme.
## Les mises tombent : celui qui bluffe trahit sa nervosité en refaisant son tic bien plus souvent
## que d'habitude. Le démasquer, vite. Les premiers instants de chaque main montrent le rythme
## habituel de chacun ; plus tard dans la soirée, un autre joueur a parfois un accès de nervosité
## passager (fausse piste), et le menteur se maîtrise mieux.
## Gauche / droite : désigner ; confirmer : accuser. Au doigt : toucher le joueur.
## Note = moyenne des mains (plein si démasqué vite, moins ensuite ; rien sur une erreur).

const PLAYERS: int = 4
const SEAT_X: Array[float] = [450.0, 790.0, 1130.0, 1470.0]
const SEAT_Y: float = 560.0
const HEAD_Y: float = 700.0
const FLOOR_Y: float = 980.0
const COATS: Array[Color] = [Color("1a1a22"), Color("2a1a14"), Color("14222a"), Color("2a2a2a")]
const HAIRS: Array[Color] = [Color("3a2416"), Color("8a8a8a"), Color("c89a50"), Color("1a1010")]

var _hand_i: int = 0
var _bluffer: int = 0
var _herring: int = -1
var _tic_of: Array[int] = []
var _period: Array[float] = []
var _tics: Array[Array] = []  # par joueur : instants (s depuis le début de la main) des tics
var _hand_t: float = 0.0
var _sel: int = 0
var _rest: float = 0.0
var _marks: Array[float] = []
var _wrong: int = 0
var _ended: bool = false
var _accused: int = -1
var _deco: Dictionary = {}
var _figs: Array[Figure3D] = []
var _bets: Array[int] = []


func begin() -> void:
	_build_3d()
	_new_hand()


func _hands() -> int:
	return pi("hands")


## Une main : tics attribués, rythmes habituels, menteur (et fausse piste) tirés ; les instants
## de tous les tics sont calculés d'avance (le résultat est connu avant d'être montré).
func _new_hand() -> void:
	_tic_of = [0, 1, 2, 3]
	for i: int in range(PLAYERS - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = _tic_of[i]
		_tic_of[i] = _tic_of[j]
		_tic_of[j] = tmp
	_bluffer = rng.randi_range(0, PLAYERS - 1)
	_herring = -1
	if rng.randf() < pk("herring_chance", _hand_i):
		_herring = (_bluffer + rng.randi_range(1, PLAYERS - 1)) % PLAYERS
	_period.clear()
	_tics.clear()
	_bets.clear()
	var calm: float = p("calm_seconds")
	var horizon: float = calm + p("window_seconds") + 1.0
	for k: int in PLAYERS:
		var base: float = rng.randf_range(p("period_min"), p("period_max"))
		_period.append(base)
		var times: Array[float] = []
		var at: float = rng.randf_range(0.2, base)
		var burst_at: float = calm + rng.randf_range(0.5, p("window_seconds") * 0.6)
		while at < horizon:
			times.append(at)
			var per: float = base
			if k == _bluffer and at >= calm - 0.2:
				per = base / pk("nervous_ratio", _hand_i)
			if k == _herring and at >= burst_at and at < burst_at + p("herring_seconds"):
				per = base / pk("nervous_ratio", _hand_i)
			at += per * rng.randf_range(1.0 - p("jitter"), 1.0 + p("jitter"))
		_tics.append(times)
		_bets.append(rng.randi_range(2, 9) * 100)
	_hand_t = 0.0
	_sel = clampi(_sel, 0, PLAYERS - 1)
	_accused = -1


func accuse(k: int) -> void:
	if _ended or _rest > 0.0 or _hand_t < p("calm_seconds"):
		return
	var since: float = _hand_t - p("calm_seconds")
	var q: float = 0.0
	if k == _bluffer:
		var late: float = maxf(0.0, since - p("quick_seconds")) / maxf(0.01, p("window_seconds") - p("quick_seconds"))
		q = lerpf(1.0, p("late_floor"), clampf(late, 0.0, 1.0))
		pop(Vector2(SEAT_X[k], HEAD_Y - 240.0), q, "TRIAL_BLUFF_CAUGHT")
		AudioBus.play("chime", 1.1, -4.0)
	else:
		_wrong += 1
		pop(Vector2(SEAT_X[k], HEAD_Y - 240.0), 0.0, "TRIAL_BLUFF_WRONG")
		AudioBus.play("lose_soft", 1.0, -4.0)
	_accused = k
	_close(q)


func _close(q: float) -> void:
	_marks.append(q)
	_rest = p("rest_seconds") * slow


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _ended:
		return
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_hand_i += 1
			if _hand_i >= _hands():
				_ended = true
				finish(ThrowTrial.mean(_marks))
				return
			_new_hand()
		return
	_hand_t += dt / slow
	if _hand_t >= p("calm_seconds") + p("window_seconds"):
		pop(Vector2(SEAT_X[_bluffer], HEAD_Y - 240.0), 0.0, "TRIAL_BLUFF_ESCAPED")
		_accused = _bluffer
		_close(0.0)


## Phase du tic du joueur `k` à l'instant de la main `at` : 0..1 pendant le geste, 0 sinon.
func tic_phase(k: int, at: float) -> float:
	var dur: float = p("tic_seconds")
	for s: float in _tics[k]:
		if at >= s and at < s + dur:
			return (at - s) / dur
		if s > at:
			break
	return 0.0


## Nombre de tics du joueur `k` depuis l'ouverture des mises.
func tics_since_calm(k: int) -> int:
	var n: int = 0
	for s: float in _tics[k]:
		if s >= p("calm_seconds") and s <= _hand_t:
			n += 1
	return n


func handle(event: InputEvent) -> bool:
	var d: Vector2i = dir_pressed(event)
	if d.x != 0:
		_sel = clampi(_sel + d.x, 0, PLAYERS - 1)
		AudioBus.play("tick", 1.3, -14.0)
		return true
	if confirm_pressed(event):
		accuse(_sel)
		return true
	return false


func direct_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return true
	for k: int in PLAYERS:
		if absf(mb.position.x - SEAT_X[k]) < 150.0 and mb.position.y > 200.0 and mb.position.y < 900.0:
			_sel = k
			accuse(k)
			break
	return true


func journal() -> Dictionary:
	return {"hands": _marks.size(), "wrong": _wrong}


# --------------------------------------------------------------------------- bot


## Le bot observe comme un joueur attentif : il compte, pour chacun, les tics refaits bien plus
## tôt que son rythme habituel depuis l'ouverture des mises ; un accès passager n'en donne qu'un,
## le menteur les enchaîne. Il accuse le premier qui en montre `bot_min_short`.
func bot_wants() -> Dictionary:
	if _ended or _rest > 0.0 or _hand_t < p("calm_seconds"):
		return {"do": ""}
	var best: int = -1
	for k: int in PLAYERS:
		if short_intervals(k) >= pi("bot_min_short"):
			best = k
			break
	if best < 0:
		return {"do": ""}
	if best != _sel:
		return {"do": "dir", "dir": Vector2i(signi(best - _sel), 0)}
	return {"do": "confirm"}


## Intervalles nettement plus courts que le rythme habituel, vus depuis l'ouverture des mises.
func short_intervals(k: int) -> int:
	var n: int = 0
	var prev: float = -INF
	for s: float in _tics[k]:
		if s > _hand_t:
			break
		if s >= p("calm_seconds") and prev > -INF and s - prev < _period[k] * p("short_cut"):
			n += 1
		prev = s
	return n


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"dir":
			_sel = clampi(_sel + (w["dir"] as Vector2i).x, 0, PLAYERS - 1)
		"confirm":
			accuse(_sel)


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(0.005, Vector2(960.0, 540.0), 1080.0, 40.0)
	_deco = SmokingSet.build(st, FLOOR_Y, 1700.0)
	var r: Node3D = st.root
	var floor3: float = st.to3(Vector2(0.0, FLOOR_Y)).y
	# Grande table de jeu, tapis vert, rebord de cuir, lampe suspendue.
	var top_y: float = floor3 + 0.8
	var felt: StandardMaterial3D = Stage3D.textured("felt", Color("1e5a34"), 0.5, 0.0, 1.0)
	var leather: StandardMaterial3D = Stage3D.mat(SmokingSet.LEATHER.darkened(0.2), 0.1, 0.35)
	Stage3D.box(r, Vector3(6.0, 0.05, 1.6), Vector3(0, top_y, 0.6), felt)
	var rim: MeshInstance3D = Stage3D.cylinder(r, 0.06, 6.1, Vector3(0, top_y + 0.03, 1.42), leather)
	rim.rotation.z = PI * 0.5
	Stage3D.box(r, Vector3(5.8, 0.75, 0.1), Vector3(0, top_y - 0.4, 1.38), Stage3D.textured("wood", SmokingSet.WALNUT_D, 0.6, 0.0, 0.4))
	for lx: float in [-1.6, 0.0, 1.6]:
		Stage3D.cylinder(r, 0.008, 1.0, Vector3(lx, top_y + 2.4, 0.5), Stage3D.mat(Color("2a2010"), 0.6, 0.4))
		Stage3D.cylinder(r, 0.28, 0.2, Vector3(lx, top_y + 1.85, 0.5), Stage3D.glow(SmokingSet.LAMP_GREEN, 0.5), 0.1)
	Stage3D.omni(r, Color(1.0, 0.92, 0.75), 2.2, Vector3(0, top_y + 1.6, 0.6), 4.5)
	for k: int in PLAYERS:
		var x3: float = st.to3(Vector2(SEAT_X[k], 0.0)).x
		var fig: Figure3D = SmokingSet.gentleman(1.75, COATS[k], HAIRS[k])
		fig.position = Vector3(x3, floor3, -0.15)
		r.add_child(fig)
		_figs.append(fig)
		# Cartes face cachée et pile de jetons devant chaque joueur.
		for c: int in 2:
			var card_at: Vector3 = Vector3(x3 - 0.1 + 0.2 * float(c), top_y + 0.03, 0.5)
			var card: MeshInstance3D = Stage3D.box(r, Vector3(0.16, 0.004, 0.24), card_at, Stage3D.mat(Color("8a1a24"), 0.0, 0.5))
			card.rotation.y = 0.15 * float(c * 2 - 1)
		var chip_cols: Array[Color] = [Palette.ROULETTE_RED, Palette.IVORY, Palette.CHIPS_BLUE, Palette.ROULETTE_BLACK]
		for c2: int in 2 + k:
			var chip_at: Vector3 = Vector3(x3 + 0.35, top_y + 0.035 + 0.019 * float(c2), 0.6)
			Stage3D.cylinder(r, 0.06, 0.018, chip_at, Stage3D.mat(chip_cols[c2 % chip_cols.size()], 0.2, 0.4))


func _sync_3d(dt: float) -> void:
	if _figs.is_empty():
		return
	for k: int in PLAYERS:
		var ph: float = tic_phase(k, _hand_t) if _rest <= 0.0 else 0.0
		_figs[k].animate(&"tic", ph, dt, float(_tic_of[k]))
	SmokingSet.animate(_deco, stage, FLOOR_Y, t)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	var betting: bool = _hand_t >= p("calm_seconds") and _rest <= 0.0 and not _ended
	for k: int in PLAYERS:
		var at: Vector2 = Vector2(SEAT_X[k], SEAT_Y)
		# Bulle de mise une fois les mises ouvertes.
		if betting or (_rest > 0.0 and not _ended):
			var bubble: Rect2 = Rect2(Vector2(at.x - 80.0, HEAD_Y - 190.0), Vector2(160.0, 50.0))
			draw_rect(bubble, Color(Palette.IVORY, 0.92))
			draw_rect(bubble, Palette.GOLD_DARK, false, 2.0)
			text(bubble.get_center() + Vector2(0, 8), tr("TRIAL_BLUFF_BET") % _bets[k], UiKit.SIZE_SMALL, Palette.INK, "body", 0)
		# Traits de mouvement pendant un tic (lisibilité sur petit écran).
		var ph: float = tic_phase(k, _hand_t) if _rest <= 0.0 else 0.0
		if ph > 0.0:
			var a: float = sin(ph * PI)
			for j: int in 3:
				var off: Vector2 = Vector2.from_angle(-PI * 0.5 + (float(j) - 1.0) * 0.5) * (90.0 + 12.0 * a)
				var head: Vector2 = Vector2(at.x, HEAD_Y)
				draw_line(head + off * 0.8, head + off, Color(Palette.GOLD_LIGHT, 0.6 * a), 3.0)
		# Désignation.
		if k == _sel and not _ended:
			draw_arc(at + Vector2(0, 330.0), 70.0, PI * 1.1, PI * 1.9, 24, Palette.GOLD_LIGHT, 5.0)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-18, 380), at + Vector2(18, 380), at + Vector2(0, 352)]), Palette.GOLD_LIGHT)
		if _accused == k and _rest > 0.0:
			draw_arc(Vector2(at.x, HEAD_Y), 110.0, 0, TAU, 40, Palette.EMERALD if k == _bluffer else Palette.ROULETTE_RED, 5.0)
	var key: String = "TRIAL_BLUFF_WATCH" if _hand_t < p("calm_seconds") else "TRIAL_BLUFF_STATUS"
	text(Vector2(960.0, 105.0), tr(key) % [mini(_hand_i + 1, _hands()), _hands()], UiKit.SIZE_BODY, Palette.IVORY)
	if betting:
		var left: float = clampf(1.0 - (_hand_t - p("calm_seconds")) / p("window_seconds"), 0.0, 1.0)
		draw_rect(Rect2(760.0, 130.0, 400.0 * left, 8.0), Palette.GOLD.lerp(Palette.ROULETTE_RED, 1.0 - left))
