class_name RunScreenThrow
extends RefCounted
## Déroulé du lancer sur l'écran de run : visée figée → mini-jeu (élan, lâcher) → tirage du
## résultat (avant toute animation) → la bille raconte ce résultat. Séparé de RunScreen.

var s: RunScreen = null
var target: int = 0
## Dev : épreuves imposées (--dev-trials=a,b,c…), jouées deux par deux dans l'ordre.
var _forced_i: int = 0


func _init(screen: RunScreen) -> void:
	s = screen


## Lancer simplifié (Options → Jeu) : un seul appui, qualité de référence.
static func simple_throw() -> bool:
	return Settings.s("game", "throw_mode") == "simple"


## Temps 1 (visée) terminé : la case est figée ; ensuite élan et lâcher, sauf lancer simplifié.
func release() -> void:
	target = s.wheel_view.stop_aim()
	if simple_throw():
		throw(ThrowSkill.NEUTRAL)
		return
	s.wheel_view.locked_index = target
	s.throw_game.release_point = s.wheel_view.release_point()
	var forced: String = String(DevMode.args().get("dev-trials", "")) if DevMode.active() else ""
	if forced != "":
		var all: PackedStringArray = forced.split(",")
		var pair: Array[String] = []
		for k: int in mini(2, all.size()):
			pair.append(all[(_forced_i + k) % all.size()])
		_forced_i += 2
		s.throw_game.start_with(pair, s.ctl.effective_precision(), Settings.b("game", "assist"))
	else:
		s.throw_game.start(s.ctl.effective_precision(), Settings.b("game", "assist"))
	s._history_box.visible = false
	AudioBus.play("lock", 1.3, -6.0)
	s._set_state(RunScreen.UiState.THROWING)
	s.tutorial.notify("throwing")


func on_quality(q: float) -> void:
	if s.state == RunScreen.UiState.THROWING:
		throw(q)


## Tire le résultat (qualité du mini-jeu incluse), puis lance l'animation de la bille.
func throw(skill: float) -> void:
	s.wheel_view.locked_index = -1
	s._history_box.visible = true
	GameState.log_input({"t": "throw", "target": target, "q": snappedf(skill, 0.01), "ms": Time.get_ticks_msec()})
	var res: ThrowResolver.ThrowResult
	if s.has_meta("rethrowing"):
		s.remove_meta("rethrowing")
		res = s.ctl.rethrow(target, skill)
	else:
		res = s.ctl.throw_ball(target, skill)
	AudioBus.play("ball_launch")
	s.wheel_view.play_throw(res.landing_index, near_miss(res.landing_index))
	s._set_state(RunScreen.UiState.BALL)


## Suspense (ralenti final) quand la bille finit sur une mise intérieure ou à côté.
func near_miss(landing: int) -> bool:
	var covered: Dictionary = {}
	for spot_id: String in s.ctl.run.slip.order:
		var spot: BetSpot = BetCatalog.get_spot(spot_id)
		if not spot.outside:
			for n: int in spot.numbers:
				covered[n] = true
	if covered.has(s.ctl.run.wheel.at(landing).number):
		return true  # suspense aussi quand on gagne
	for ni: int in s.ctl.run.wheel.neighbors(landing, 1):
		if covered.has(s.ctl.run.wheel.at(ni).number):
			return true
	return false


## Lecture du lancer pour le joueur : dans la zone, rebond fou, aimanté, collé.
func announce(t: ThrowResolver.ThrowResult, landing: int) -> void:
	if t == null:
		return
	var key: String = "THROW_IN_ZONE"
	var col: Color = Palette.CYAN
	if t.stuck:
		key = "THROW_STUCK"
		col = Palette.GOLD_LIGHT
	elif t.attracted_from >= 0:
		key = "THROW_ATTRACTED"
		col = Palette.GOLD_LIGHT
	elif not t.in_zone:
		key = "THROW_WILD"
		col = Palette.MAGENTA
	elif landing == t.target_index:
		key = "THROW_PERFECT"
		col = Palette.EMERALD
	var pos: Vector2 = UiLayout.canvas_point(s.wheel_view, s.wheel_view.pocket_screen_pos(landing)) + Vector2(0, -60)
	s.float_layer.pop_text(s.tr(key), pos, col, UiKit.SIZE_BODY)
