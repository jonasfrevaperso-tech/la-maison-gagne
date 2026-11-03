extends TestCase
## 1.7 « Salle de jeux » : règles des épreuves nouvelles ou refondues, hors rendu.


func _trial(id: String) -> ThrowTrial:
	var e: Dictionary = ContentDB.shared().get_entry("throw_trials", id)
	var scr: GDScript = load(ThrowMinigame.TRIAL_SCRIPTS % id) as GDScript
	var trial: ThrowTrial = (scr.new() as ThrowTrial).setup(e, 1, false, false)
	trial.size = UiLayout.DESIGN_SIZE
	return trial


func before_each() -> void:
	super.before_each()
	AudioBus.hush(true)  # tests headless : l'audio n'a pas de lecteurs


## Pluie du Grand Lustre : vider met la pile à l'abri ; une pile trop haute se renverse
## (valeur perdue, pénalité) ; une bouteille étourdit le plateau.
func test_catch_bank_topple_stun() -> void:
	var c: TrialCatch = _trial("catch") as TrialCatch
	c._stack_val = 5.0
	c._stack_n = 5
	c._bank()
	eq(c._banked, 5.0, "vider : valeur à l'abri")
	eq(c._stack_n, 0, "plateau vide")
	c._stack_val = 9.0
	c._stack_n = c.pi("stack_max") + 1
	c.tick(0.01)
	eq(c._stack_n, 0, "pile trop haute : renversée")
	check(c._penalty > 0.0 and is_equal_approx(c._banked, 5.0), "valeur perdue et pénalité")
	c._catch({"kind": "bottle"}, Vector2(960, 900))
	check(c._stun > 0.0, "bouteille : plateau étourdi")
	c.free()


## Enchaînement : le multiplicateur monte par paliers et plafonne.
func test_catch_combo_multiplier() -> void:
	var c: TrialCatch = _trial("catch") as TrialCatch
	eq(c._mult(), 1.0, "sans enchaînement")
	c._combo = int(c.p("combo_step"))
	check(c._mult() > 1.0, "un palier")
	c._combo = 1000
	eq(c._mult(), c.p("combo_max"), "plafond")
	c.free()
