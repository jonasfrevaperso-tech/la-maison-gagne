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
