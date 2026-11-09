extends TestCase
## 2.0 · Salle 9, le Fumoir : Ronds de fumée, Palet, Dominos, Bluff, Échecs éclair.


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


## Ronds de fumée : un rond monte en vol ; trop lent, il n'atteint pas le cerceau.
func test_smoke_ring_rises_and_fades() -> void:
	_boot()
	var sr: TrialSmokerings = _trial("smokerings") as TrialSmokerings
	check(sr.ring_pos(Vector2(800.0, 0.0), 1.5).y < 0.0, "la fumée monte")
	check(sr.ring_radius(1.0) > sr.ring_radius(0.0), "le rond grossit")
	check(sr.outcome(4, 0.0, 0.0, sr.t).y < 0.0, "souffle trop faible : n'arrive pas")
	sr.free()


## Palet : la table creusée ramène un palet lancé de biais vers l'axe ; brosser rallonge.
func test_palet_bowl_and_brush() -> void:
	_boot()
	var pl: TrialPalet = _trial("palet") as TrialPalet
	pl._pucks.resize(1)
	var plain: Dictionary = pl.predict(0.0, 0.4)
	var brushed: Dictionary = pl.predict(0.0, 0.4, 0.0)
	check((brushed["p"] as Vector2).x > (plain["p"] as Vector2).x, "brosser rallonge")
	var pucks: Array[Dictionary] = [{"p": Vector2(0.15, 0.0), "vel": Vector2.from_angle(0.12) * 2.4, "own": true, "out": false}]
	var max_v: float = 0.0
	for _k: int in 400:
		TrialPalet.step_pucks(pucks, false, pl._prm())
		max_v = maxf(max_v, (pucks[0]["p"] as Vector2).y)
	check(max_v > 0.05, "il s'écarte")
	check((pucks[0]["p"] as Vector2).y < max_v * 0.7, "puis revient vers l'axe")
	pl.free()


## Dominos : un domino se pose au bout qui porte son nombre ; à faux, la main se bloque.
func test_dominoes_rules() -> void:
	_boot()
	var dm: TrialDominoes = _trial("dominoes") as TrialDominoes
	dm._root = Vector2i(2, 5)
	dm._left.clear()
	dm._right.clear()
	dm._hand = [Vector2i(5, 1), Vector2i(0, 0)]
	eq(dm.fits(dm._hand[0]), [1] as Array[int], "5-1 va à droite")
	check(dm.fits(dm._hand[1]).is_empty(), "0-0 ne va nulle part")
	check(not dm.play(1), "posé à faux")
	check(dm._lock > 0.0, "main bloquée")
	dm._lock = 0.0
	check(dm.play(0), "posé")
	eq(dm.end_value(1), 1, "nouveau bout droit")
	dm.free()


## Bluff : le menteur refait son tic plus souvent ; le bot (qui observe) le démasque sans erreur.
func test_bluff_bot_finds_liar() -> void:
	_boot()
	for seed: int in 4:
		var bl: TrialBluff = _trial("bluff") as TrialBluff
		bl.rng.seed = seed * 31 + 7
		bl._new_hand()
		var guard: int = 0
		while bl._rest <= 0.0 and guard < 900:
			bl.bot_apply(bl.bot_wants())
			bl.tick(1.0 / 60.0)
			guard += 1
		eq(bl._wrong, 0, "pas d'erreur (graine %d)" % seed)
		check(bl._marks[0] > 0.0, "démasqué (graine %d)" % seed)
		bl.free()


## Échecs : moteur (échec, mat, coups légaux) et chaque position des données mate en un coup unique.
func test_chess_engine_and_data() -> void:
	_boot()
	var c: ChessMini = ChessMini.from_fen("6k1/5ppp/8/8/8/8/8/R5K1")
	var m: Array[Vector2i] = c.mating_moves()
	eq(m.size(), 1, "mat du couloir unique")
	eq(m[0], ChessMini.parse_uci("a1a8"), "Ta8#")
	check(c.apply(m[0]).is_mate(false), "le roi noir est mat")
	check(not ChessMini.from_fen("8/8/8/8/8/8/8/K6k").in_check(false), "pas d'échec")
	var e: Dictionary = DataRegistry.db.get_entry("throw_trials", "chess")
	check((e["puzzles"] as Array).size() >= 30, "positions en nombre")
	for pz: Variant in e["puzzles"]:
		var pd: Dictionary = pz as Dictionary
		eq(ChessMini.from_fen(String(pd["fen"])).mating_moves().size(), 1, "mat unique : %s" % String(pd["fen"]))
