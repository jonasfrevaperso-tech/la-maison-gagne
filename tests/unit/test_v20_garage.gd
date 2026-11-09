extends TestCase
## 2.0 · Salle 10, le Garage : Voiturier, Rallye, Clé dynamométrique, Coffre, Fuite.


func _boot() -> void:
	AudioBus.hush(true)
	if DataRegistry.db == null:
		DataRegistry.db = ContentDB.shared()
	if SaveSystem.profile.is_empty():
		SaveSystem.profile = SaveSystem.default_profile()


func _trial(id: String) -> ThrowTrial:
	var trial: ThrowTrial = (load(ThrowMinigame.TRIAL_SCRIPTS % id) as GDScript).new() as ThrowTrial
	trial.setup(DataRegistry.db.get_entry("throw_trials", id), 1, false, false)
	trial.size = UiLayout.DESIGN_SIZE
	trial._begun = true
	trial.begin()
	return trial


## Voiturier : en marche arrière braquée, l'essieu recule et le cap tourne ; seuls les pneus butent
## contre la bordure ; une voiture bien rangée est notée, une voiture dehors ne l'est pas.
func test_valet_model_and_contacts() -> void:
	_boot()
	var v: TrialValet = _trial("valet") as TrialValet
	var s: Dictionary = {"pos": Vector2.ZERO, "head": 0.0, "steer": 0.0, "vel": 0.0}
	for _k: int in 120:
		TrialValet.advance(s, -1.0, -1.0, v._prm())
	check((s["pos"] as Vector2).x < 0.0, "elle recule")
	check(float(s["head"]) > 0.0, "l'arrière part vers le trottoir")
	eq(v.contact(v._goal, 0.0), 0, "rangée : aucun contact")
	eq(v.contact(Vector2(v._goal.x, TrialValet.CURB_Z - 0.5), 0.0), 1, "pneus sur la bordure")
	eq(v.contact(v._parked[0], 0.0), 2, "dans la voiture de devant")
	check(v.quality(v._goal, 0.0, 0) > 0.95, "rangée pile")
	check(v.quality(v._goal, 0.0, 1) < v.quality(v._goal, 0.0, 0), "une bosse coûte")
	eq(v.quality(v._goal + Vector2(0.0, 3.0), 0.0, 0), 0.0, "restée dans la voie")
	v.free()


## Rallye : au frein à main, l'arrière décroche (glissement latéral) ; une porte se franchit.
func test_rally_handbrake_slides() -> void:
	_boot()
	var r: TrialRally = _trial("rally") as TrialRally
	var slips: Array[float] = []
	for hb: bool in [false, true]:
		var s: Dictionary = {"pos": Vector2.ZERO, "head": 0.0, "vel": Vector2(9.0, 0.0)}
		for _k: int in 30:
			TrialRally.advance(s, 1.0, false, hb, r._prm())
		var side: Vector2 = Vector2.from_angle(float(s["head"])).orthogonal()
		slips.append(absf((s["vel"] as Vector2).dot(side)))
	check(slips[1] > slips[0] * 2.0, "le frein à main fait glisser")
	var g: PackedVector2Array = PackedVector2Array([Vector2(0.0, -1.0), Vector2(0.0, 1.0)])
	check(TrialRally.crosses(Vector2(-1.0, 0.0), Vector2(1.0, 0.0), g), "porte franchie")
	check(not TrialRally.crosses(Vector2(-1.0, 3.0), Vector2(1.0, 3.0), g), "à côté de la porte")
	check(r.quality(r.p("lap_par"), 0, 0) >= 1.0 and r.quality(r.p("lap_par"), 2, 0) < 1.0, "chrono et plots")
	r.free()


## Clé : le couple file puis grimpe ; l'étoile interdit deux voisins ; trop serré = foiré.
func test_torque_rules() -> void:
	_boot()
	var k: TrialTorque = _trial("torque") as TrialTorque
	check(TrialTorque.torque_at(0.1, 0.3, 1.0, 0.5) <= TrialTorque.RUN_LEVEL, "l'écrou file")
	check(TrialTorque.torque_at(0.8, 0.3, 1.0, 0.5) > TrialTorque.torque_at(0.6, 0.3, 1.0, 0.5), "puis le couple monte")
	check(k.adjacent(0, 1) and k.adjacent(0, k._nuts.size() - 1) and not k.adjacent(0, 2), "voisins sur le moyeu")
	var n: Dictionary = {"torque": (k.p("zone_lo") + k.p("zone_hi")) * 0.5, "stripped": false}
	eq(k.nut_quality(n), 1.0, "dans le vert")
	n["torque"] = k.p("zone_lo") * 0.5
	check(k.nut_quality(n) < 0.5, "pas assez serré")
	n["stripped"] = true
	eq(k.nut_quality(n), 0.0, "foiré")
	k._last_started = 0
	k._sel = 1
	k._start_hold()
	eq(k._warps, 1, "deux voisins : voilée")
	k.free()


## Coffre : la découpe pave le coffre exactement ; quatre quarts de tour = la forme d'origine.
func test_trunk_partition() -> void:
	_boot()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed: int in 30:
		rng.seed = seed
		var pieces: Array[Dictionary] = TrialTrunk.partition(6, 4, rng, 6, 0.5)
		var seen: Dictionary = {}
		for pc: Dictionary in pieces:
			for c: Vector2i in pc["sol"] as Array[Vector2i]:
				check(not seen.has(c), "case couverte deux fois (graine %d)" % seed)
				seen[c] = true
		eq(seen.size(), 24, "coffre plein (graine %d)" % seed)
	var l_shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
	eq(TrialTrunk.rotated(l_shape, 4), TrialTrunk.normalized(l_shape), "un tour complet")
	check(TrialTrunk.rotated(l_shape, 1) != TrialTrunk.normalized(l_shape), "un quart de tour change la forme")


## Fuite : accrochage = vitesse perdue et police plus près ; rattrapé = rien.
func test_escape_crash_and_caught() -> void:
	_boot()
	var e: TrialEscape = _trial("escape") as TrialEscape
	e._v = 30.0
	var gap0: float = e._gap
	e._crash({"v": 20.0, "cruise": 20.0, "z": -2.0})
	check(e._v < 15.0, "vitesse perdue")
	check(e._gap < gap0, "la police se rapproche")
	e._caught = true
	eq(e.quality(), 0.0, "rattrapé")
	e.free()


## Cartons de tuto (constat de recette 2.0 sur Pixel 7) : une étape trop longue se coupe en deux
## lignes à l'espace le plus proche du milieu.
func test_tuto_line_splits_in_two() -> void:
	var parts: PackedStringArray = ThrowTrial.split_two("Avant de déboîter, vérifie la file d'à côté.")
	eq(parts.size(), 2, "deux lignes")
	eq(parts[0] + " " + parts[1], "Avant de déboîter, vérifie la file d'à côté.", "rien de perdu")
	eq(ThrowTrial.split_two("Indivisible").size(), 1, "sans espace, une ligne")
