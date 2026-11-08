extends TestCase
## 1.8 « Le Musée » : correctifs (dialogues déjà vus, marquage des mises, blackjack).


## Un dialogue d'ouverture déjà vu ne rejoue que sa réplique à choix (son bonus compte en partie).
func test_seen_dialogue_keeps_only_choice() -> void:
	var db: ContentDB = ContentDB.shared()
	var intro: Dictionary = db.get_entry("dialogues", "act1_intro")
	check(DialogueOverlay.has_choices(intro), "act1_intro a un choix")
	check(not DialogueOverlay.has_choices(db.get_entry("dialogues", "act1_mid")), "act1_mid n'en a pas")
	var lines: Array = intro["lines"]
	var first: int = DialogueOverlay.next_choice(lines, 0)
	check(first < lines.size() and (lines[first] as Dictionary).has("choices"), "saute droit au choix")
	eq(DialogueOverlay.next_choice(lines, first + 1), lines.size(), "puis se termine")


## Blackjack : lire ses cartes pendant le délai de grâce ne coûte rien à la note.
func test_blackjack_grace_period() -> void:
	AudioBus.hush(true)
	var e: Dictionary = ContentDB.shared().get_entry("throw_trials", "blackjack")
	var scr: GDScript = load(ThrowMinigame.TRIAL_SCRIPTS % "blackjack") as GDScript
	var bj: TrialBlackjack = (scr.new() as TrialBlackjack).setup(e, 1, false, false) as TrialBlackjack
	bj.size = UiLayout.DESIGN_SIZE
	bj._player = [10, 10]
	bj._dealer = [6]
	bj._first = true
	bj._phase = "decide"
	bj._decide_t = bj.p("speed_grace") * 0.9
	bj.choose("stand")
	near(bj._marks[0], 1.0, 0.0001, "bonne décision dans le délai de grâce : note pleine")
	bj.free()


## Musée : toutes les épreuves sont exposées, chacune dans une seule salle.
func test_museum_exhibits_every_trial_once() -> void:
	var db: ContentDB = ContentDB.shared()
	var seen: Dictionary[String, int] = {}
	for r: Dictionary in db.list("museum_rooms"):
		for t: Variant in r.get("exhibits", []):
			seen[String(t)] = int(seen.get(String(t), 0)) + 1
	for e: Dictionary in db.list("throw_trials"):
		eq(int(seen.get(String(e["id"]), 0)), 1, "épreuve %s exposée une fois" % e["id"])
	eq(seen.size(), db.count("throw_trials"), "rien d'autre n'est exposé")


## Musée : seuils des médailles, records par difficulté, la Détente plafonne au bronze.
func test_museum_records_and_medals() -> void:
	eq(MuseumRecords.medal_for(Balance.f("museum.medal_gold")), MuseumRecords.Medal.GOLD, "or au seuil")
	eq(MuseumRecords.medal_for(Balance.f("museum.medal_silver")), MuseumRecords.Medal.SILVER, "argent au seuil")
	eq(MuseumRecords.medal_for(Balance.f("museum.medal_bronze")), MuseumRecords.Medal.BRONZE, "bronze au seuil")
	eq(MuseumRecords.medal_for(Balance.f("museum.medal_bronze") - 0.01), MuseumRecords.Medal.NONE, "rien sous le bronze")
	var mus: Dictionary = {}
	eq(MuseumRecords.best(mus, "darts"), -1.0, "jamais jouée")
	check(MuseumRecords.submit(mus, "darts", "relax", 0.95), "premier record")
	eq(MuseumRecords.best_medal(mus, "darts"), MuseumRecords.Medal.BRONZE, "la Détente plafonne au bronze")
	check(MuseumRecords.submit(mus, "darts", "normal", 0.75), "record en Normal")
	check(not MuseumRecords.submit(mus, "darts", "normal", 0.6), "moins bien : pas de record")
	near(MuseumRecords.best(mus, "darts", "normal"), 0.75, 0.001, "garde la meilleure note")
	eq(MuseumRecords.best_medal(mus, "darts"), MuseumRecords.Medal.SILVER, "argent en Normal")
	check(MuseumRecords.submit(mus, "darts", "expert", 0.92), "record en Expert")
	eq(MuseumRecords.count_medals(mus, ["darts", "safe"], MuseumRecords.Medal.GOLD), 1, "une médaille d'or")
	eq(MuseumRecords.gold_count(mus), 1, "compte des ors du profil")


## Musée : l'entraînement joue l'épreuve demandée sans lâcher et rend sa note.
func test_museum_practice_skips_release() -> void:
	AudioBus.hush(true)
	if DataRegistry.db == null:
		DataRegistry.db = ContentDB.shared()
	if SaveSystem.profile.is_empty():
		SaveSystem.profile = SaveSystem.default_profile()
	var g: ThrowMinigame = ThrowMinigame.new()
	var host: Control = Control.new()
	host.size = UiLayout.DESIGN_SIZE
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	host.add_child(g)
	g.full_host = host
	var got: Array[float] = []
	g.practice_done.connect(func(sc: float) -> void: got.append(sc))
	g.start_practice("darts", "expert")
	eq(g.trial_ids, ["darts"] as Array[String], "une seule épreuve")
	eq(g.steps().size(), 1, "pas d'étape de lâcher")
	check(g.trial != null and g.trial.slow < 1.0, "Expert : plus rapide")
	g._on_trial_done(0.8)
	g._after_pause()
	eq(got.size(), 1, "note rendue")
	near(got[0], 0.8, 0.001, "note de l'épreuve")
	check(not g.active(), "rien après l'épreuve")
	host.queue_free()
