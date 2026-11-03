class_name TrialBlackjack
extends ThrowTrial
## BLACKJACK EXPRESS (écran dédié) : trois mains contre la donneuse du Grand Zéro, quelques
## secondes par décision : TIRER, DOUBLER (premier choix seulement) ou RESTER. La donneuse
## reste sur 17. On ne note PAS le résultat de la main (le hasard des cartes) mais la décision :
## conforme à la stratégie de base (BlackjackRules.best) et rapide.
## Note = moyenne des décisions (1 si conforme, sinon 0), pondérée par la vitesse.

const ACTIONS: Array[String] = ["hit", "double", "stand"]
const ACTION_KEYS: Dictionary[String, String] = {
	"hit": "TRIAL_BLACKJACK_HIT", "double": "TRIAL_BLACKJACK_DOUBLE", "stand": "TRIAL_BLACKJACK_STAND",
}
const ACTION_COLORS: Dictionary[String, Color] = {
	"hit": Color("29e0ff"), "double": Color("ffd23f"), "stand": Color("ff4d6d"),
}
## Bouton de manette de chaque décision (X tirer, Y doubler, B rester).
const SYMBOL_OF: Dictionary[String, int] = {"hit": 0, "double": 1, "stand": 2}
const PLAYER_Y: float = 640.0
const BUTTON_Y: float = 900.0
const BUTTON_SIZE: Vector2 = Vector2(260.0, 90.0)
## Décor 3D : rangées de cartes sur le tapis (m), écart entre cartes, sabot, vitesse de glisse.
const PLAYER_Z: float = 0.85
const DEALER_Z: float = -0.95
const CARD_STEP: float = 0.62
const SHOE_AT: Vector3 = Vector3(2.5, 0.2, -1.5)
const SLIDE: float = 9.0
const CHIP_COLORS: Array[Color] = [Color("d11a3c"), Color("1f6fd1"), Color("1e9e5a"), Color("ece4d0"), Color("1a1a1a")]

var _hand: int = 0
var _player: Array[int] = []
var _suits: Array[int] = []
var _dealer: Array[int] = []
var _dealer_suits: Array[int] = []
var _first: bool = true
var _decide_t: float = 0.0
var _phase: String = "deal"
var _phase_t: float = 0.0
var _marks: Array[float] = []
var _last_ok: int = -1
var _bot_choice: String = ""
var _results: Array[String] = []
var _mouse_pos: Vector2 = Vector2(-1, -1)
var _pc3: Array[PlayingCard3D] = []
var _dc3: Array[PlayingCard3D] = []


func begin() -> void:
	_build_3d()
	_deal()


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.env.background_color = Color(0.03, 0.02, 0.03)
	st.env.ambient_light_energy = 0.4
	st.key.light_energy = 0.3
	st.look(Vector3(0, 4.4, 3.3), Vector3(0, 0, 0.15), 42.0)
	var r: Node3D = st.root
	# Feutre en demi-lune, liseré doré, rail matelassé de cuir.
	var felt: MeshInstance3D = Stage3D.cylinder(r, 4.2, 0.06, Vector3(0, -0.03, -2.2), Stage3D.mat(Color(0.04, 0.24, 0.14), 0.0, 0.95))
	felt.name = "felt"
	Stage3D.box(r, Vector3(14, 0.04, 9), Vector3(0, -0.08, 0), Stage3D.mat(Color(0.12, 0.05, 0.04), 0.0, 0.7))
	var gilt: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.45, 0.35)
	var leather: StandardMaterial3D = Stage3D.mat(Color(0.2, 0.07, 0.05), 0.0, 0.45)
	for k: int in 48:
		var a: float = lerpf(-1.15, 1.15, float(k) / 47.0)
		var arc: MeshInstance3D = Stage3D.box(r, Vector3(0.12, 0.006, 0.025), Vector3(sin(a) * 2.6, 0.002, -2.2 + cos(a) * 2.6), gilt)
		arc.rotation.y = a
		var pad: MeshInstance3D = Stage3D.box(r, Vector3(0.6, 0.18, 0.35), Vector3(sin(a) * 4.25, 0.06, -2.2 + cos(a) * 4.25), leather)
		pad.rotation.y = a
	var rule: Label3D = Stage3D.text3d(r, tr("TRIAL_BLACKJACK_RULE"), Vector3(0, 0.005, 0.0), 64, Color(Palette.GOLD_LIGHT, 0.55),
		Color(0, 0, 0, 0))
	rule.rotation.x = -PI * 0.5
	rule.pixel_size = 0.0019
	# Cases de mise devant le joueur.
	for k2: int in 3:
		var ring: MeshInstance3D = Stage3D.cylinder(r, 0.26, 0.004, Vector3(-1.6 + float(k2) * 1.6, 0.001, 1.9), gilt)
		ring.name = "ring%d" % k2
		Stage3D.cylinder(r, 0.23, 0.006, Vector3(-1.6 + float(k2) * 1.6, 0.002, 1.9), Stage3D.mat(Color(0.04, 0.24, 0.14), 0.0, 0.95))
	# Sabot : boîte de bois laqué, cartes rouges dedans, ouverture vers la donneuse.
	var shoe: Node3D = Node3D.new()
	shoe.position = SHOE_AT
	shoe.rotation.y = -0.5
	r.add_child(shoe)
	Stage3D.box(shoe, Vector3(0.75, 0.32, 1.0), Vector3.ZERO, Stage3D.mat(Color(0.16, 0.08, 0.04), 0.1, 0.35))
	Stage3D.box(shoe, Vector3(0.6, 0.26, 0.9), Vector3(0, 0.06, -0.02), Stage3D.mat(Palette.ROULETTE_RED.darkened(0.4), 0.1, 0.5))
	Stage3D.box(shoe, Vector3(0.77, 0.04, 0.2), Vector3(0, 0.17, 0.45), gilt)
	# Plateau de jetons de la donneuse et piles de jetons du joueur.
	var rack: Node3D = Node3D.new()
	rack.position = Vector3(0, 0.05, -2.05)
	r.add_child(rack)
	Stage3D.box(rack, Vector3(2.4, 0.1, 0.5), Vector3.ZERO, Stage3D.mat(Color(0.12, 0.06, 0.03), 0.1, 0.4))
	for c: int in CHIP_COLORS.size():
		var col_m: StandardMaterial3D = Stage3D.mat(CHIP_COLORS[c], 0.1, 0.4)
		var stack: MeshInstance3D = Stage3D.cylinder(rack, 0.13, 0.4, Vector3(-0.9 + float(c) * 0.45, 0.08, 0), col_m)
		stack.rotation.x = PI * 0.5
		Stage3D.cylinder(r, 0.14, 0.06 + 0.04 * float(c % 3), Vector3(-2.6 + float(c) * 0.32, 0.03, 1.35 + 0.05 * float(c % 2)), col_m)
	var lamp: OmniLight3D = Stage3D.omni(r, Color(1.0, 0.86, 0.6), 2.6, Vector3(0, 2.8, -0.1), 7.5)
	lamp.shadow_enabled = RenderQuality.shadows()


func _spawn_card(rank: int, suit: int) -> PlayingCard3D:
	var c: PlayingCard3D = PlayingCard3D.new()
	stage.root.add_child(c)
	c.set_card(rank, suit)
	c.position = SHOE_AT + Vector3(-0.2, 0.15, 0.3)
	c.rotation.y = -0.5
	c.face_up = false
	c.flip = 0.0
	return c


func _row_at(k: int, n: int, z: float) -> Vector3:
	return Vector3((float(k) - float(n - 1) * 0.5) * CARD_STEP, 0.008 + float(k) * 0.003, z)


func _clear_cards() -> void:
	for c: PlayingCard3D in _pc3 + _dc3:
		c.queue_free()
	_pc3.clear()
	_dc3.clear()


func _sync_3d(dt: float) -> void:
	if stage == null:
		return
	while _pc3.size() < _player.size():
		_pc3.append(_spawn_card(_player[_pc3.size()], _suits[_pc3.size()]))
	# La donneuse a toujours deux cartes : la seconde reste face cachée jusqu'à son tour.
	var dn: int = maxi(_dealer.size(), 2)
	while _dc3.size() < dn:
		var i: int = _dc3.size()
		_dc3.append(_spawn_card(_dealer[i] if i < _dealer.size() else 1, _dealer_suits[i] if i < _dealer_suits.size() else 0))
	var w: float = 1.0 - exp(-SLIDE * dt)
	for k: int in _pc3.size():
		_move(_pc3[k], _row_at(k, _pc3.size(), PLAYER_Z), w, true)
	for k2: int in _dc3.size():
		var shown: bool = k2 < _dealer.size()
		if shown:
			_dc3[k2].set_card(_dealer[k2], _dealer_suits[k2])
		_move(_dc3[k2], _row_at(k2, _dc3.size(), DEALER_Z), w, shown)


func _move(c: PlayingCard3D, target: Vector3, w: float, face: bool) -> void:
	c.position = c.position.lerp(target, w)
	c.rotation.y = lerp_angle(c.rotation.y, 0.0, w)
	# Retournée une fois posée.
	c.face_up = face and c.position.distance_to(target) < 0.12


func _draw_card() -> int:
	return rng.randi_range(1, 13)


func _deal() -> void:
	_clear_cards()
	_player = [_draw_card(), _draw_card()]
	_suits = [rng.randi_range(0, 3), rng.randi_range(0, 3)]
	_dealer = [_draw_card()]
	_dealer_suits = [rng.randi_range(0, 3)]
	_first = true
	_decide_t = 0.0
	_phase = "deal"
	_phase_t = p("deal_seconds")
	AudioBus.play("card_flip", 1.0, -4.0)
	# Blackjack d'entrée : rien à décider, main suivante.
	if BlackjackRules.total(_player) == 21:
		_phase = "dealer"
		_phase_t = p("reveal_seconds")


func _limit() -> float:
	return p("decision_seconds") * slow


func _button_rect(k: int) -> Rect2:
	var w: float = BUTTON_SIZE.x + 40.0
	var x0: float = size.x * 0.5 - w * 1.5 + 20.0
	return Rect2(Vector2(x0 + float(k) * w, BUTTON_Y), BUTTON_SIZE)


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for k: int in ACTIONS.size():
				if _button_rect(k).has_point(mb.position):
					choose(ACTIONS[k])
					return true
		return true
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_pos = mm.position
		return true
	var s: int = sym_pressed(event)
	var d: Vector2i = dir_pressed(event)
	if s == 0 or d == Vector2i.LEFT:
		choose("hit")
	elif s == 1 or d == Vector2i.UP:
		choose("double")
	elif s == 2 or d == Vector2i.RIGHT:
		choose("stand")
	else:
		return false
	return true


func choose(action: String) -> void:
	if _phase != "decide":
		return
	if action == "double" and not _first:
		AudioBus.play("error", 1.0, -8.0)
		return
	var best: String = BlackjackRules.best(_player, _dealer[0], _first)
	var ok: bool = action == best
	# Le temps de lire ses cartes ne coûte rien : la vitesse ne compte qu'après le délai de grâce.
	var grace: float = p("speed_grace") * slow
	var speed: float = clampf(1.0 - maxf(0.0, _decide_t - grace) / maxf(_limit() - grace, 0.01), 0.0, 1.0)
	_marks.append((1.0 - p("speed_weight") + p("speed_weight") * speed) if ok else 0.0)
	_last_ok = 1 if ok else 0
	pop(Vector2(size.x * 0.5, PLAYER_Y - 60.0), 1.0 if ok else 0.0, "TRIAL_BLACKJACK_BOOK" if ok else "TRIAL_BLACKJACK_OFFBOOK")
	AudioBus.play("chip_place" if ok else "lose_soft", 1.0, -4.0)
	_apply(action)


func _apply(action: String) -> void:
	_first = false
	_decide_t = 0.0
	match action:
		"hit", "double":
			_player.append(_draw_card())
			_suits.append(rng.randi_range(0, 3))
			AudioBus.play("card_place", 1.1, -4.0)
			var tot: int = BlackjackRules.total(_player)
			if action == "double" or tot >= 21:
				_phase = "dealer"
				_phase_t = p("reveal_seconds")
			else:
				# Le temps de voir la nouvelle carte avant la décision suivante.
				_phase = "deal"
				_phase_t = p("hit_seconds")
		_:
			_phase = "dealer"
			_phase_t = p("reveal_seconds")


func tick(dt: float) -> void:
	_phase_t -= dt
	_sync_3d(dt)
	match _phase:
		"deal":
			if _phase_t <= 0.0:
				_phase = "decide"
		"decide":
			_decide_t += dt
			if _bot_choice != "":
				choose(_bot_choice)
				_bot_choice = ""
			elif _decide_t >= _limit():
				# Temps écoulé : la donneuse fait « rester » d'office, décision ratée.
				_marks.append(0.0)
				_last_ok = 0
				pop(Vector2(size.x * 0.5, PLAYER_Y - 60.0), 0.0, "TRIAL_BLACKJACK_SLOW")
				_apply("stand")
		"dealer":
			# La donneuse tire jusqu'à 17, carte par carte.
			if _phase_t <= 0.0:
				if BlackjackRules.total(_player) <= 21 and BlackjackRules.total(_dealer) < 17:
					_dealer.append(_draw_card())
					_dealer_suits.append(rng.randi_range(0, 3))
					AudioBus.play("card_flip", 1.2, -6.0)
					_phase_t = p("dealer_card_seconds")
				else:
					if _dealer.size() == 1:
						_dealer.append(_draw_card())
						_dealer_suits.append(rng.randi_range(0, 3))
					_results.append(BlackjackRules.outcome(_player, _dealer))
					_phase = "result"
					_phase_t = p("result_seconds")
		"result":
			if _phase_t <= 0.0:
				_hand += 1
				if _hand >= pi("hands"):
					_phase = "over"
					finish(ThrowTrial.mean(_marks) if not _marks.is_empty() else 0.0)
				else:
					_deal()


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	if _phase != "decide" or _decide_t < p("bot_delay"):
		return {"do": ""}
	return {"do": "sym", "symbol": SYMBOL_OF[BlackjackRules.best(_player, _dealer[0], _first)]}


func bot_apply(w: Dictionary) -> void:
	_bot_choice = ""
	if String(w.get("do", "")) == "sym":
		for a: String in SYMBOL_OF.keys():
			if SYMBOL_OF[a] == int(w.get("symbol", -1)):
				_bot_choice = a


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	# Totaux à côté des rangées 3D, issue de la main.
	if _dealer.size() > 1:
		var dl: Vector2 = stage.project(_row_at(0, _dc3.size(), DEALER_Z) - Vector3(0.55, 0, 0))
		_badge(dl, str(BlackjackRules.total(_dealer)), Palette.IVORY)
	var tot: int = BlackjackRules.total(_player)
	var soft: String = "*" if BlackjackRules.is_soft(_player) and tot < 21 else ""
	var pl: Vector2 = stage.project(_row_at(0, maxi(_pc3.size(), 1), PLAYER_Z) - Vector3(0.6, 0, 0))
	_badge(pl, str(tot) + soft, Palette.GOLD_LIGHT if tot <= 21 else Palette.MULT_RED)
	if _phase == "result" and not _results.is_empty():
		var mid: Vector2 = stage.project(Vector3(0, 0, (PLAYER_Z + DEALER_Z) * 0.5))
		text(mid, tr("TRIAL_BLACKJACK_" + _results[-1].to_upper()), UiKit.SIZE_H1, Palette.IVORY)
	# Boutons et chrono de décision.
	for k3: int in ACTIONS.size():
		var a: String = ACTIONS[k3]
		var br: Rect2 = _button_rect(k3)
		var usable: bool = _phase == "decide" and (a != "double" or _first)
		var col: Color = ACTION_COLORS[a] if usable else Palette.SMOKE_DARK
		var hover: bool = mouse and br.has_point(_mouse_pos)
		draw_rect(br, Color(Palette.INK, 0.75))
		draw_rect(br, Color(col, 0.35 if hover else 0.2))
		draw_rect(br, col, false, 3.0)
		text(br.get_center(), tr(ACTION_KEYS[a]), UiKit.SIZE_BODY, col)
	if _phase == "decide":
		var left: float = clampf(1.0 - _decide_t / _limit(), 0.0, 1.0)
		draw_rect(Rect2(size.x * 0.5 - 300, BUTTON_Y - 30, 600, 10), Color(Palette.INK, 0.7))
		draw_rect(Rect2(size.x * 0.5 - 300, BUTTON_Y - 30, 600 * left, 10), Palette.GOLD if left > 0.3 else Palette.MULT_RED)
	pips(Vector2(size.x * 0.5, 80.0), _marks, maxi(_marks.size(), pi("hands")))


## Pastille ronde avec un total de main.
func _badge(at: Vector2, label: String, col: Color) -> void:
	draw_circle(at, 46.0, Color(Palette.INK, 0.85))
	draw_arc(at, 46.0, 0, TAU, 32, col, 3.0)
	text(at, label, UiKit.SIZE_H2, col)
