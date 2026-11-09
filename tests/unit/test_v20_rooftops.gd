extends TestCase
## 2.0 · Salle 8, les Toits : Pigeon voyageur, Gouttières, Antenne, Tyrolienne, Télescope.


func _boot() -> void:
	AudioBus.hush(true)
	if DataRegistry.db == null:
		DataRegistry.db = ContentDB.shared()
	if SaveSystem.profile.is_empty():
		SaveSystem.profile = SaveSystem.default_profile()


func _trial(id: String) -> ThrowTrial:
	var tr: ThrowTrial = (load(ThrowMinigame.TRIAL_SCRIPTS % id) as GDScript).new() as ThrowTrial
	tr.setup(DataRegistry.db.get_entry("throw_trials", id), 1, false, false)
	tr.size = UiLayout.DESIGN_SIZE
	tr._begun = true
	tr.begin()
	return tr


## Pigeon : sans rien faire il plane en perdant de l'altitude ; un battement d'ailes le fait monter.
func test_pigeon_glide_and_flap() -> void:
	_boot()
	var pg: TrialPigeon = _trial("pigeon") as TrialPigeon
	pg._stacks.clear()
	var y0: float = pg._y
	for _k: int in 60:
		pg.tick(1.0 / 60.0)
	check(pg._y > y0, "vol à plat : il descend")
	var y1: float = pg._y
	pg.flap()
	eq(pg._flaps, TrialPigeon.FLAPS - 1, "un battement consommé")
	for _k2: int in 30:
		pg.tick(1.0 / 60.0)
	check(pg._y < y1, "le battement le fait monter")
	pg.free()


## Gouttières : chaque réseau tiré est soluble (la solution raccorde) et n'est pas déjà raccordé.
func test_gutters_networks_are_solvable() -> void:
	_boot()
	var gt: TrialGutters = _trial("gutters") as TrialGutters
	for round: int in gt._rounds():
		gt._round = round
		gt._new_round()
		check(not gt._solved(), "réseau %d mélangé" % round)
		var saved: Array[int] = gt._rot.duplicate()
		for i: int in gt._sol.size():
			if gt._sol[i] >= 0:
				gt._rot[i] = gt._sol[i]
		gt._flow()
		check(gt._solved(), "réseau %d : la solution raccorde" % round)
		gt._rot = saved
	gt.free()


## Antenne : pleine qualité sur la station au bon gain ; loin en fréquence, presque rien.
func test_antenna_quality() -> void:
	_boot()
	var an: TrialAntenna = _trial("antenna") as TrialAntenna
	var tg: Vector2 = an._target()
	near(an.quality(tg.x, tg.y), 1.0, 0.01, "accordé")
	check(an.quality(fposmod(tg.x + 0.5, 1.0), tg.y) < 0.05, "loin de la station")
	check(an.quality(tg.x, clampf(tg.y + 0.5, 0.0, 1.0)) < 0.2, "gain très faux")
	an.free()


## Tyrolienne : le repère est atteignable sans freiner ; frein serré à l'arrêt, on ne recule pas.
func test_zipline_fair_and_brake_holds() -> void:
	_boot()
	var zp: TrialZipline = _trial("zipline") as TrialZipline
	check(zp._predict(false) >= zp._target_s, "atteignable en laissant filer")
	var held: Vector3 = zp.advance(zp._target_s, 0.0, 0.0, true, 1.0 / 60.0)
	near(held.y, 0.0, 0.001, "le frein retient sur la pente")
	zp.free()


## Télescope : les engrenages entraînent l'anneau voisin ; le ciel tiré se résout de l'extérieur.
func test_telescope_gears() -> void:
	_boot()
	var ts: TrialTelescope = _trial("telescope") as TrialTelescope
	ts._off = [0, 0, 0]
	ts._turn(0, 1)
	eq(ts._off, [1, 1, 0], "l'extérieur entraîne le milieu")
	ts._turn(1, 1)
	eq(ts._off, [1, 2, TrialTelescope.STEPS - 1], "le milieu entraîne l'intérieur à l'envers")
	ts._new_sky()
	var guard: int = 0
	while not ts._solved() and guard < 100:
		ts.bot_apply(ts.bot_wants())
		guard += 1
	check(ts._solved(), "résolu par le bot")
	ts.free()
