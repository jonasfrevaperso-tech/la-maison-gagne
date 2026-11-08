extends TestCase
## 2.0 · Salle 7, les Cuisines : Crêpe Suzette, Découpage, Service, Commandes, Soufflé.


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


## Crêpe : la charge règle les tours ; bonne rotation rattrapée = plein, tombée à côté = rien.
func test_crepe_turns_and_catch() -> void:
	_boot()
	var cr: TrialCrepe = _trial("crepe") as TrialCrepe
	near(cr._turns_for(0.0), cr.p("turns_min"), 0.001, "sans élan : peu de tours")
	near(cr._turns_for(1.0), cr.p("turns_max"), 0.001, "plein élan : beaucoup de tours")
	cr._turns_total = cr._target()
	cr._crepe = Vector2(cr._pan_x, TrialCrepe.PAN_Y)
	cr._land()
	near(cr._marks[0], 1.0, 0.001, "demi-tour juste, dans la poêle")
	cr._turns_total = cr._target()
	cr._crepe = Vector2(cr._pan_x + cr.p("catch_miss") + 50.0, TrialCrepe.PAN_Y)
	cr._land()
	near(cr._marks[1], 0.0, 0.001, "à côté de la poêle : rien")
	cr.free()


## Découpage : sur le trait = plein, loin = rien ; sur un os, il faut avoir soulevé la lame.
func test_cutting_judging() -> void:
	_boot()
	var ct: TrialCutting = _trial("cutting") as TrialCutting
	var x: float = TrialCutting.X0 + 20.0
	ct._bones.clear()
	ct._y = ct._path(x)
	ct._judge(x)
	near(ct._sum, 1.0, 0.001, "sur le trait")
	ct._y = ct._path(x) + ct.p("miss_px") + 10.0
	ct._judge(x)
	near(ct._sum, 1.0, 0.001, "loin du trait : rien de plus")
	ct._bones.append(Vector2(x - 5.0, x + 5.0))
	ct._lifted = true
	ct._judge(x)
	near(ct._sum, 2.0, 0.001, "lame levée au-dessus de l'os")
	ct._lifted = false
	ct._judge(x)
	near(ct._sum, 2.0, 0.001, "lame sur l'os : rien")
	ct.free()


## Service : chaque rang d'obstacles laisse un passage ; un choc renverse des verres.
func test_service_gaps_and_bump() -> void:
	_boot()
	var sv: TrialService = _trial("service") as TrialService
	for o: Dictionary in sv._obstacles:
		if float(o["vx"]) != 0.0:
			continue
		var g: float = sv._gap_center(float(o["s"]))
		check(not (g + sv.p("body_half") > float(o["x0"]) and g - sv.p("body_half") < float(o["x1"])),
			"le milieu du passage est libre (rang %.1f)" % float(o["s"]))
	var first: Dictionary = sv._obstacles[0]
	sv._s = float(first["s"])
	sv._x = (float(first["x0"]) + float(first["x1"])) * 0.5
	sv._collide()
	eq(sv._remaining(), TrialService.GLASSES - sv.pi("bump_glasses"), "choc : verres renversés")
	sv.free()


## Commandes : un mauvais ingrédient vide le verre ; la bonne recette, vite, vaut plein.
func test_orders_pouring() -> void:
	_boot()
	var od: TrialOrders = _trial("orders") as TrialOrders
	od.t = od.p("first_ticket")
	od.tick(1.0 / 60.0)
	eq(od._active().size(), 1, "premier bon arrivé")
	var tk: Dictionary = od._active()[0]
	var recipe: Array[int] = tk["recipe"]
	od.pour(recipe[0])
	od.pour((recipe[1] + 1) % TrialOrders.INGREDIENTS)
	eq(od._poured.size(), 0, "mauvais ingrédient : à l'évier")
	eq(int(tk["ruined"]), 1, "erreur comptée")
	for ing: int in recipe:
		od.pour(ing)
	eq(od._marks.size(), 1, "bon servi")
	near(od._marks[0], 1.0 - od.p("ruin_penalty"), 0.001, "servi vite, une erreur")
	od.free()


## Soufflé : le four suit la flamme avec retard ; dans la zone = plein, loin = rien.
func test_souffle_inertia() -> void:
	_boot()
	var sf: TrialSouffle = _trial("souffle") as TrialSouffle
	var start: float = sf._temp
	sf._valve = 1.0
	sf.tick(0.1)
	check(sf._temp - start < 5.0, "inertie : l'air du four monte lentement")
	for k: int in 120:
		sf.tick(1.0 / 60.0)
	check(sf._temp > start + 20.0, "puis monte franchement")
	check(sf._heater > sf._temp, "la résistance est en avance sur l'air")
	sf.free()
