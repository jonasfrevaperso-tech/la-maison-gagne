extends TestCase
## 2.0 · Salle 6, le Cabaret : Claquettes, Projecteur, Funambule, Lancer de chapeau, Mentaliste.


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


## Claquettes : phrases de plus en plus longues, premier pas sur le temps ; bon pas au bon moment
## = plein, mauvais pas = un peu, frappe hors mesure = en trop.
func test_tapdance_phrases_and_judging() -> void:
	_boot()
	var td: TrialTapdance = _trial("tapdance") as TrialTapdance
	var lens: Array = Balance.data()["throw_trials"]["tapdance"]["phrase_notes"] as Array
	for k: int in lens.size():
		eq((td._phrases[k] as Array).size(), int(lens[k]), "phrase %d : %d pas" % [k, int(lens[k])])
		eq(float((td._phrases[k][0] as Dictionary)["at"]), 0.0, "premier pas sur le temps")
	var first: Dictionary = td._phrases[0][0]
	td.t = td._response_start(0)
	td.tap(int(first["step"]))
	near(td._marks[0], 1.0, 0.001, "bon pas, pile : plein")
	var second: Dictionary = td._phrases[0][1]
	td.t = td._response_start(0) + float(second["at"])
	td.tap((int(second["step"]) + 1) % TrialTapdance.STEPS)
	near(td._marks[1], td.p("wrong_step_value"), 0.001, "mauvais pas au bon moment : un peu")
	td.t = 0.2
	td.tap(0)
	eq(td._extra, 1, "frappe pendant le décompte : en trop")
	td.free()


## Projecteur : la meneuse au cœur du cercle est pleinement éclairée, loin elle ne l'est pas.
func test_spotlight_lighting() -> void:
	_boot()
	var sp: TrialSpotlight = _trial("spotlight") as TrialSpotlight
	sp._pause = 10.0
	sp._spot = sp._target()
	sp._vel = Vector2.ZERO
	sp.tick(1.0 / 60.0)
	near(sp._lit, 1.0, 0.001, "dans la lumière")
	sp._spot = sp._target() + Vector2(600.0, 0.0)
	sp._vel = Vector2.ZERO
	sp.tick(1.0 / 60.0)
	near(sp._lit, 0.0, 0.001, "hors du cercle")
	sp.free()


## Funambule : trop penché, il se rattrape au fil (compté) ; sans avancer, la note est nulle.
func test_tightrope_fall_and_idle() -> void:
	_boot()
	var tr: TrialTightrope = _trial("tightrope") as TrialTightrope
	tr._theta = tr.p("fall_angle") + 0.05
	tr.tick(1.0 / 60.0)
	eq(tr._falls, 1, "rattrapé au fil")
	check(tr._fall_left > 0.0, "temps perdu")
	near(tr._score(), 0.0, 0.001, "sans avancer : rien")
	tr._x = TrialTightrope.WIRE_X1
	tr._falls = 0
	tr._steady_n = 10
	tr._steady_sum = 9.0
	check(tr._score() > 0.6, "arrivé sans chute : bonne note")
	tr.free()


## Lancer de chapeau : chaque lancer tiré a une solution franche (force, effet atteignables).
func test_hattoss_throws_are_fair() -> void:
	_boot()
	var ht: TrialHattoss = _trial("hattoss") as TrialHattoss
	for k: int in ht._throws():
		ht._throw = k
		ht._setup_throw()
		check(ht._make_plan() <= ht.p("hook_radius") * TrialHattoss.FAIR_MARGIN, "lancer %d : accrochable" % k)
	ht.free()


## Mentaliste : indices exacts (doublons compris) ; le raisonnement trouve toujours à temps.
func test_mentalist_clues_and_solver() -> void:
	_boot()
	var a: Array[int] = [0, 0, 1]
	var b: Array[int] = [1, 0, 0]
	eq(TrialMentalist.clue(a, b, 5), Vector2i(1, 2), "1 bien placé, 2 mal placés")
	var c: Array[int] = [2, 2, 2]
	eq(TrialMentalist.clue(c, b, 5), Vector2i(0, 0), "rien en commun")
	for seed_k: int in 6:
		var m: TrialMentalist = _trial("mentalist") as TrialMentalist
		m.rng.seed = 100 + seed_k
		m._secret.clear()
		for s: int in m._slots:
			m._secret.append(m.rng.randi_range(0, m._ncol - 1))
		while not m._locked():
			m.bot_apply(m.bot_wants())
		check(m._solved, "combinaison %s trouvée" % str(m._secret))
		check(m._history.size() <= m.pi("tries"), "dans le nombre d'essais")
		m.free()
