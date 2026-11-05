extends TestCase
## 1.9 « Répétition générale » : Musée à la manette, tutos, épreuves refaites, défaite.


func _boot() -> void:
	AudioBus.hush(true)
	if DataRegistry.db == null:
		DataRegistry.db = ContentDB.shared()
	if SaveSystem.profile.is_empty():
		SaveSystem.profile = SaveSystem.default_profile()
	if TranslationServer.translate(&"MUSEUM_COUNT") == "MUSEUM_COUNT":  # runner headless : pas de traductions
		TranslationServer.add_translation(load("res://localization/strings.fr.translation") as Translation)
		TranslationServer.set_locale("fr")


## Musée : B (ui_cancel) pendant une épreuve est un bouton de jeu ; la pause (Start) la fige.
func test_museum_b_reaches_trial() -> void:
	_boot()
	var ms: MuseumScreen = (load("res://scenes/meta/museum_screen.tscn") as PackedScene).instantiate() as MuseumScreen
	(Engine.get_main_loop() as SceneTree).root.add_child(ms)
	if ms.game == null:  # runner headless : l'arbre n'appelle _ready qu'à l'image suivante
		ms._ready()
	ms.select(1)  # Shaker (Bar)
	ms.play_current()
	check(ms.game.active(), "épreuve lancée")
	var b: InputEventAction = InputEventAction.new()
	b.action = &"ui_cancel"
	b.pressed = true
	ms._play_input(b)
	check(ms.game.active(), "B ne quitte pas l'épreuve")
	check(not ms.is_paused(), "B ne met pas en pause")
	var start: InputEventAction = InputEventAction.new()
	start.action = &"pause_menu"
	start.pressed = true
	ms._play_input(start)
	check(ms.is_paused(), "Start met en pause")
	check(bool(ms.game.hold.call()), "l'épreuve est figée")
	ms.go_back()
	check(not ms.is_paused() and ms.game.active(), "B en pause reprend l'épreuve")
	ms._quit_play()
	check(not ms.game.active(), "Quitter l'épreuve")
	ms.get_parent().remove_child(ms)
	ms.free()


## Tuto de première rencontre : démo → essai (note ignorée) → épreuve réelle ; ensuite plus rien.
func test_trial_tuto_flow() -> void:
	_boot()
	Engine.remove_meta(&"no_trial_tutos")
	SaveSystem.profile["trials_tutored"] = []
	var g: ThrowMinigame = ThrowMinigame.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(g)
	g.start_with(["charge"] as Array[String], 1, false)
	eq(g.rehearsing(), "demo", "démo à la première rencontre")
	check(g.trial.tuto_lines.size() >= 2, "étapes du tuto chargées")
	g.bot_apply({"do": "confirm"})
	eq(g.rehearsing(), "essai", "on passe la démo : essai")
	g.trial.done.emit(1.0)
	check(g.trial_scores.is_empty(), "la note de l'essai ne compte pas")
	g._after_pause()
	eq(g.rehearsing(), "", "puis l'épreuve réelle")
	check(g.active() and g.trial.in_intro(), "épreuve réelle avec son carton")
	check(not g.needs_tuto("charge"), "épreuve marquée comme initiée")
	g.start_with(["charge"] as Array[String], 1, false)
	eq(g.rehearsing(), "", "déjà vue : directement l'épreuve")
	Engine.set_meta(&"no_trial_tutos", true)
	g.stop()
	g.get_parent().remove_child(g)
	g.free()


## Billard au doigt : toucher loin de la blanche ne tire jamais ; revenir sur la bille annule.
func test_billiards_slingshot() -> void:
	_boot()
	var e: Dictionary = DataRegistry.db.get_entry("throw_trials", "billiards")
	var b: TrialBilliards = (load("res://scripts/presentation/trials/trial_billiards.gd") as GDScript).new() as TrialBilliards
	b.setup(e, 1, false, true)
	b.begin()
	var far: Vector2 = b._cue + Vector2(400, 0) if b._cue.x < 900.0 else b._cue - Vector2(400, 0)
	b.handle(_mb(far, true))
	b.handle(_mb(far, false))
	check(not b._rolling, "un toucher ailleurs ne tire pas")
	b.handle(_mb(b._cue, true))
	b.handle(_mm(b._cue + Vector2(20, 0)))
	b.handle(_mb(b._cue + Vector2(20, 0), false))
	check(not b._rolling, "relâcher sur la bille annule")
	b.handle(_mb(b._cue, true))
	b.handle(_mm(b._cue + Vector2(-200, 0)))
	b.handle(_mb(b._cue + Vector2(-200, 0), false))
	check(b._rolling, "tirer en arrière puis lâcher joue")
	near(b._aim, 0.0, 0.01, "visée à l'opposé du doigt")
	b.free()


func _mb(at: Vector2, down: bool) -> InputEventMouseButton:
	var m: InputEventMouseButton = InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = down
	m.position = at
	return m


func _mm(at: Vector2) -> InputEventMouseMotion:
	var m: InputEventMouseMotion = InputEventMouseMotion.new()
	m.position = at
	return m


## Jeu direct au doigt : chaque geste du bot devient un vrai toucher sur l'objet (trouvé en
## balayant l'écran avec tap_action) ; l'épreuve doit se jouer et bien se noter ainsi.
func test_direct_touch_plays() -> void:
	_boot()
	for id: String in ["simon", "rhythm", "highlow", "sort", "juggle", "pachinko"]:
		var e: Dictionary = DataRegistry.db.get_entry("throw_trials", id)
		check(bool(e.get("touch_direct", false)), "%s : jeu direct déclaré" % id)
		var trial: ThrowTrial = (load(ThrowMinigame.TRIAL_SCRIPTS % id) as GDScript).new() as ThrowTrial
		trial.setup(e, 1, false, false)
		trial.direct = true
		trial.size = ThrowMinigame.PANEL_RECT.size if not trial.full() else UiLayout.DESIGN_SIZE
		trial._begun = true
		trial.begin()
		var spots: Dictionary = {}
		var release: StringName = &""
		var guard: int = 0
		while not trial.finished and guard < 60 * 60:
			guard += 1
			if release != &"":
				trial.feed(_mb(spots[release] as Vector2, false))
				release = &""
			var w: Dictionary = trial.bot_wants()
			var a: StringName = _want_action(w)
			if a != &"":
				if not spots.has(a):
					spots[a] = _find_spot(trial, a)
				if String(w["do"]) == "release":
					trial.feed(_mb(spots[a] as Vector2, false))
				else:
					trial.feed(_mb(spots[a] as Vector2, true))
					if id != "rhythm":
						release = a
			trial.t += 1.0 / 60.0
			trial.tick(1.0 / 60.0)
		check(trial.finished, "%s : terminée au doigt" % id)
		check(trial.score >= 0.6, "%s : bien jouée au doigt (%.2f)" % [id, trial.score])
		for s: Variant in spots.values():
			check((s as Vector2).x >= 0.0, "%s : un objet répond à chaque action" % id)
		trial.free()


func _want_action(w: Dictionary) -> StringName:
	match String(w.get("do", "")):
		"sym", "release":
			return ThrowTrial.QTE_ACTIONS[int(w.get("symbol", 0))]
		"dir":
			var d: Vector2i = w["dir"] as Vector2i
			return &"ui_up" if d == Vector2i.UP else (&"ui_down" if d == Vector2i.DOWN else (&"ui_left" if d == Vector2i.LEFT else &"ui_right"))
	return &""


func _find_spot(trial: ThrowTrial, a: StringName) -> Vector2:
	var y: float = 0.0
	while y < trial.size.y:
		var x: float = 0.0
		while x < trial.size.x:
			if trial.tap_action(Vector2(x, y)) == a:
				return Vector2(x, y)
			x += 20.0
		y += 20.0
	return Vector2(-1, -1)


## Pluie au doigt : le plateau suit le doigt ; seul le bouton VIDER met la pile à l'abri.
func test_catch_direct_bank() -> void:
	_boot()
	var c: TrialCatch = (load(ThrowMinigame.TRIAL_SCRIPTS % "catch") as GDScript).new() as TrialCatch
	c.setup(DataRegistry.db.get_entry("throw_trials", "catch"), 1, false, false)
	c.direct = true
	c.size = UiLayout.DESIGN_SIZE
	c._begun = true
	c.begin()
	c._stack_n = 3
	c._stack_val = 3.0
	c.feed(_mb(Vector2(500, 600), true))
	eq(c._banked, 0.0, "toucher le décor ne vide pas")
	eq(c._mouse_x, 500.0, "le plateau suit le doigt")
	c.feed(_mb(Vector2(500, 600), false))
	c.feed(_mb(c._bank_button(), true))
	eq(c._banked, 3.0, "VIDER met la pile à l'abri")
	c.free()


## Défaite : variante de réplique par acte, créancier nommé ; réglage toujours / 1re fois / jamais.
func test_defeat_cutscene_variants() -> void:
	_boot()
	var lines: Array = [{"text_fr": "Acte normal", "by_act": {"3": {"text_fr": "Acte trois"}}}, {"text_fr": "{creditor} gagne."}]
	var a1: Array = IntroCutscene.vary(lines, 1, "Le Notaire")
	var a3: Array = IntroCutscene.vary(lines, 3, "Le Notaire")
	eq(String(a1[0]["text_fr"]), "Acte normal", "texte de base à l'acte 1")
	eq(String(a3[0]["text_fr"]), "Acte trois", "variante de l'acte 3")
	eq(String(a1[1]["text_fr"]), "Le Notaire gagne.", "créancier nommé")
	var shots: int = 0
	for e: Dictionary in DataRegistry.db.list("cutscenes"):
		if String(e.get("cutscene", "")) == "defeat":
			shots += 1
	check(shots >= 3, "trois plans de défaite")
	var stats: Dictionary = SaveSystem.profile["stats"]
	var before: String = Settings.s("game", "defeat_cutscene")
	stats["defeat_seen"] = 1
	Settings.set_value("game", "defeat_cutscene", "first")
	check(not GameState.defeat_cutscene_wanted(), "« la première fois » : déjà vue")
	Settings.set_value("game", "defeat_cutscene", "always")
	check(GameState.defeat_cutscene_wanted(), "« toujours »")
	Settings.set_value("game", "defeat_cutscene", "never")
	check(not GameState.defeat_cutscene_wanted(), "« jamais »")
	Settings.set_value("game", "defeat_cutscene", before)
	stats.erase("defeat_seen")
