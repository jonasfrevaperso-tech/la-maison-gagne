extends TestCase
## 2.0 « La Grande Saison » : correctifs, épreuves approfondies, export, difficulté, builds, salles.


func _boot() -> void:
	AudioBus.hush(true)
	if DataRegistry.db == null:
		DataRegistry.db = ContentDB.shared()
	if SaveSystem.profile.is_empty():
		SaveSystem.profile = SaveSystem.default_profile()
	if TranslationServer.translate(&"MUSEUM_COUNT") == "MUSEUM_COUNT":
		TranslationServer.add_translation(load("res://localization/strings.fr.translation") as Translation)
		TranslationServer.set_locale("fr")


func _trial(id: String) -> ThrowTrial:
	var tr: ThrowTrial = (load(ThrowMinigame.TRIAL_SCRIPTS % id) as GDScript).new() as ThrowTrial
	tr.setup(DataRegistry.db.get_entry("throw_trials", id), 1, false, false)
	tr.size = UiLayout.DESIGN_SIZE
	tr._begun = true
	tr.begin()
	return tr


## Pluie : une part de chaque prise est acquise ; une pile renversée garde sa moitié basse.
func test_catch_topple_keeps_half() -> void:
	_boot()
	var c: TrialCatch = _trial("catch") as TrialCatch
	c._catch({"kind": "chip", "bonus": ""}, Vector2(500, 600))
	check(c._banked > 0.0, "une part de la prise est acquise d'office")
	c._stack_n = 8
	c._stack_val = 8.0
	c._topple()
	eq(c._stack_n, 4, "la moitié basse de la pile reste")
	check(c._stack_val > 0.0, "la valeur de la moitié basse est gardée")
	c.free()


## Personnage articulé : toutes les poses se calculent, le corps glisse vers la pose demandée.
func test_figure_poses() -> void:
	_boot()
	var f: Figure3D = Figure3D.new().build(1.0, {"hat": "top"})
	for a: StringName in [&"idle", &"run", &"walk", &"jump", &"fall", &"hang", &"stun", &"cheer"]:
		for k: int in 20:
			f.animate(a, float(k) * 0.3, 1.0 / 60.0, 0.5)
	var sh: Node3D = f.find_child("sh_l", true, false) as Node3D
	check(sh != null and sh.rotation.x < -1.0, "bras levés en fin de « cheer »")
	f.free()


## Tuto : la démo est ralentie et dure au moins une étape de lecture par consigne.
func test_tuto_demo_pace() -> void:
	_boot()
	var g: ThrowMinigame = ThrowMinigame.new()
	g._rehearsal = "demo"
	g.trial = _trial("pour")
	g.trial.tuto_lines.assign(["a", "b", "c"])
	check(g._rehearsal_limit() >= Balance.f("throw_game.tuto_step_seconds") * 3.0 - 0.01
		or g._rehearsal_limit() >= Balance.f("throw_game.tuto_demo_max") - 0.01, "au moins une étape de lecture par consigne")
	check(Balance.f("throw_game.tuto_demo_speed") < 1.0, "démo ralentie")
	g.trial.free()
	g.free()
