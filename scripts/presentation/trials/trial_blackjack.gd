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
const CARD_SIZE: Vector2 = Vector2(120.0, 168.0)
const PLAYER_Y: float = 640.0
const DEALER_Y: float = 250.0
const BUTTON_Y: float = 900.0
const BUTTON_SIZE: Vector2 = Vector2(260.0, 90.0)
const SUITS: Array[String] = ["♠", "♥", "♦", "♣"]
const RANKS: Array[String] = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

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


func begin() -> void:
	_deal()


func _draw_card() -> int:
	return rng.randi_range(1, 13)


func _deal() -> void:
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
	var speed: float = clampf(1.0 - _decide_t / _limit(), 0.0, 1.0)
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
		_:
			_phase = "dealer"
			_phase_t = p("reveal_seconds")


func tick(dt: float) -> void:
	_phase_t -= dt
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


func _card(at: Vector2, rank: int, suit: int, hidden: bool = false) -> void:
	var r: Rect2 = Rect2(at, CARD_SIZE)
	draw_rect(Rect2(at + Vector2(6, 8), CARD_SIZE), Color(0, 0, 0, 0.35))
	if hidden:
		draw_rect(r, Palette.VELVET)
		draw_rect(r.grow(-8), Palette.GOLD_DARK, false, 3.0)
		return
	draw_rect(r, Palette.IVORY)
	draw_rect(r, Palette.GOLD_DARK, false, 2.0)
	var red: bool = suit == 1 or suit == 2
	var col: Color = Palette.ROULETTE_RED if red else Palette.INK
	var lbl: String = RANKS[rank - 1]
	text(at + Vector2(26, 26), lbl, UiKit.SIZE_BODY, col, "display", 0)
	text(at + CARD_SIZE * 0.5 + Vector2(0, 8), SUITS[suit], UiKit.SIZE_H1, col, "ui", 0)


func paint() -> void:
	# Table de blackjack : feutre vert en demi-lune, liseré doré, sabot.
	draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color("0b0710"))
	var c: Vector2 = Vector2(size.x * 0.5, -260.0)
	draw_circle(c, 1180.0, Palette.GOLD_DARK)
	draw_circle(c, 1166.0, Palette.FELT)
	draw_arc(c, 900.0, 0.35, PI - 0.35, 64, Color(Palette.GOLD, 0.35), 3.0)
	text(Vector2(size.x * 0.5, 470.0), tr("TRIAL_BLACKJACK_RULE"), UiKit.SIZE_SMALL, Color(Palette.GOLD_LIGHT, 0.6))
	draw_rect(Rect2(size.x - 380, 120, 150, 110), Color("2a1a10"))
	draw_rect(Rect2(size.x - 370, 130, 130, 90), Palette.VELVET)
	# Donneuse.
	for k: int in _dealer.size():
		_card(Vector2(size.x * 0.5 - 70.0 + float(k) * 80.0, DEALER_Y), _dealer[k], _dealer_suits[k])
	if _dealer.size() == 1:
		_card(Vector2(size.x * 0.5 + 10.0, DEALER_Y), 1, 0, true)
	if _dealer.size() > 1:
		text(Vector2(size.x * 0.5 - 180.0, DEALER_Y + 80.0), str(BlackjackRules.total(_dealer)), UiKit.SIZE_H2, Palette.IVORY)
	# Joueur.
	var n: int = _player.size()
	for k2: int in n:
		_card(Vector2(size.x * 0.5 - float(n) * 40.0 + float(k2) * 80.0, PLAYER_Y), _player[k2], _suits[k2])
	var tot: int = BlackjackRules.total(_player)
	var soft: String = "*" if BlackjackRules.is_soft(_player) and tot < 21 else ""
	text(Vector2(size.x * 0.5 - float(n) * 40.0 - 80.0, PLAYER_Y + 80.0), str(tot) + soft, UiKit.SIZE_H2, Palette.GOLD_LIGHT)
	if _phase == "result" and not _results.is_empty():
		text(Vector2(size.x * 0.5, PLAYER_Y - 120.0), tr("TRIAL_BLACKJACK_" + _results[-1].to_upper()), UiKit.SIZE_H2, Palette.IVORY)
	# Boutons et chrono de décision.
	for k3: int in ACTIONS.size():
		var a: String = ACTIONS[k3]
		var br: Rect2 = _button_rect(k3)
		var usable: bool = _phase == "decide" and (a != "double" or _first)
		var col: Color = ACTION_COLORS[a] if usable else Palette.SMOKE_DARK
		var hover: bool = mouse and br.has_point(_mouse_pos)
		draw_rect(br, Color(col, 0.35 if hover else 0.2))
		draw_rect(br, col, false, 3.0)
		text(br.get_center(), tr(ACTION_KEYS[a]), UiKit.SIZE_BODY, col)
	if _phase == "decide":
		var left: float = clampf(1.0 - _decide_t / _limit(), 0.0, 1.0)
		draw_rect(Rect2(size.x * 0.5 - 300, BUTTON_Y - 30, 600 * left, 10), Palette.GOLD if left > 0.3 else Palette.MULT_RED)
	pips(Vector2(size.x * 0.5, 80.0), _marks, maxi(_marks.size(), pi("hands")))
