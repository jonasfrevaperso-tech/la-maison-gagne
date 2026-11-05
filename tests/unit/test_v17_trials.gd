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
	eq(c._stack_n, (c.pi("stack_max") + 1) / 2, "pile trop haute : renversée (la moitié basse reste)")
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


## Envahisseurs : tout détruire vaut la note pleine ; une touche coûte et sonne le canon.
func test_invaders_score_and_hits() -> void:
	var v: TrialInvaders = _trial("invaders") as TrialInvaders
	v.begin()
	for i: Dictionary in v._inv:
		i["alive"] = false
	v._killed = v._total
	v.tick(0.01)
	check(v.finished and is_equal_approx(v.score, 1.0), "tous détruits : 1")
	var w: TrialInvaders = _trial("invaders") as TrialInvaders
	w.begin()
	w._bombs.append(Vector2(w._x, TrialInvaders.CANNON_Y))
	w.tick(0.001)
	eq(w._hits, 1, "bombe sur le canon : touché")
	check(w._stun > 0.0, "canon sonné")
	v.free()
	w.free()


## Cave : tomber dans une fosse ramène au bord et compte une chute.
func test_cave_fall_returns_to_edge() -> void:
	var c: TrialCave = _trial("cave") as TrialCave
	c.begin()
	var k: int = -1
	for i: int in c._segs.size():
		if String(c._segs[i]["kind"]) == "pit":
			k = i
			break
	check(k >= 0, "une fosse au parcours")
	var s: Dictionary = c._segs[k]
	c._x = float(s["x"])
	c._y = TrialCave.FLOOR_Y + c.p("fall_depth") + 10.0
	c._vy = 10.0
	c._ground = false
	c._land()
	eq(c._falls, 1, "chute comptée")
	check(c._x < float(s["x"]) - float(s["w"]) * 0.5, "retour avant la fosse")
	c.free()


## Pachinko : un taquet frappé au point idéal envoie la bille dans le godet d'or ;
## une bille non frappée finit hors du godet.
func test_pachinko_kick_reaches_gold() -> void:
	var pa: TrialPachinko = _trial("pachinko") as TrialPachinko
	pa.begin()
	var x: float = pa._center() - TrialPachinko.KICK_GAP * 0.5 - TrialPachinko.KICK_HALF_W
	pa._balls.append({"p": Vector2(x, TrialPachinko.KICK_Y), "v": Vector2(0, 300), "kicked": false})
	pa._launched = pa.pi("balls")
	pa.kick(0)
	for _k: int in 240:
		pa.tick(1.0 / 60.0)
	check(pa.finished, "bille arrivée")
	eq(pa._scores[0], 1.0, "godet d'or")
	pa.free()


## Blackjack : valeur des mains (as souple) et stratégie de base sur des cas d'école.
func test_blackjack_rules() -> void:
	eq(BlackjackRules.total([1, 13]), 21, "as + roi")
	eq(BlackjackRules.total([1, 1, 9]), 21, "deux as + 9")
	check(BlackjackRules.is_soft([1, 6]), "17 souple")
	eq(BlackjackRules.best([10, 6], 10, true), "hit", "16 contre 10 : tirer")
	eq(BlackjackRules.best([10, 6], 6, true), "stand", "16 contre 6 : rester")
	eq(BlackjackRules.best([6, 5], 6, true), "double", "11 contre 6 : doubler")
	eq(BlackjackRules.best([6, 5], 6, false), "hit", "11 sans doubler : tirer")
	eq(BlackjackRules.best([1, 7], 9, true), "hit", "18 souple contre 9 : tirer")
	eq(BlackjackRules.best([1, 7], 4, false), "stand", "18 souple sans doubler : rester")
	eq(BlackjackRules.outcome([10, 9], [10, 7]), "win", "19 contre 17")


## Équité : jouer selon la stratégie de base vaut la note pleine, quelles que soient les cartes.
func test_blackjack_grades_decision_not_luck() -> void:
	for seed_v: int in [3, 77, 1234]:
		var b: TrialBlackjack = _trial("blackjack") as TrialBlackjack
		b.rng = RandomNumberGenerator.new()
		b.rng.seed = seed_v
		b.begin()
		var guard: int = 0
		while not b.finished and guard < 3000:
			guard += 1
			if b._phase == "decide":
				b.choose(BlackjackRules.best(b._player, b._dealer[0], b._first))
			b.tick(1.0 / 60.0)
		check(b.finished, "partie terminée (graine %d)" % seed_v)
		check(b.score > 0.95, "décisions justes et immédiates : ≈ 1 (graine %d, %.2f)" % [seed_v, b.score])
		b.free()


## Dés : le plan du bot (reflet sur la bande, force calculée) arrête les dés dans la zone ;
## la face tirée n'entre pas dans la note.
func test_dice_plan_lands_in_zone() -> void:
	var dc: TrialDice = _trial("dice") as TrialDice
	dc.begin()
	var plan: Vector2 = dc.bot_plan()
	dc._aim = plan.x
	dc._charge = plan.y
	dc._release()
	var guard: int = 0
	while dc._flying and guard < 2000:
		guard += 1
		dc.tick(1.0 / 120.0)
	check(dc._wall, "les dés touchent la bande")
	check(dc._pos.distance_to(dc._zone) < dc._zone_r(), "arrêt dans la zone (%.0f px)" % dc._pos.distance_to(dc._zone))
	dc.free()


## Grattage (1.9) : gratter les zones remplit la note ; déborder la fait baisser.
func test_scratch_overflow_costs() -> void:
	var sc: TrialScratch = _trial("scratch") as TrialScratch
	sc.begin()
	for k: int in 3:
		var c: Vector2 = sc._centers[k]
		var r: float = sc.p("zone_radius") - sc.p("brush") * 0.8
		var y: float = -r
		while y <= r:
			var hw: float = sqrt(maxf(r * r - y * y, 0.0))
			sc._scratch_line(c + Vector2(-hw, y), c + Vector2(hw, y))
			y += sc.p("brush") * 0.8
	near(sc.current_score(), 1.0, 0.02, "trois zones grattées proprement")
	var clean: float = sc.current_score()
	sc._scratch_line(sc.FOIL.position + Vector2(30, 30), sc.FOIL.position + Vector2(sc.FOIL.size.x - 30, 30))
	check(sc.overflow() > 0.0 and sc.current_score() < clean, "le débord coûte des points")
	sc.free()


## Pêche : un fil trop tendu casse, la carpe est perdue (remontée nulle).
func test_fishing_line_snaps() -> void:
	var f: TrialFishing = _trial("fishing") as TrialFishing
	f.begin()
	f._phase = "reel"
	f._tension = 0.99
	f._hold = true
	f._pull_t = 10.0
	f.tick(0.1)
	eq(f._scores.size(), 1, "poisson terminé")
	check(f._scores[0] <= f.p("w_cast") + f.p("w_bite"), "remontée perdue")
	f.free()


## Lasers : un faisceau actif touche le cambrioleur placé dessus.
func test_lasers_beam_hits() -> void:
	var l: TrialLasers = _trial("lasers") as TrialLasers
	l.begin()
	var seg: PackedVector2Array = PackedVector2Array()
	for b: Dictionary in l._beams:
		var segs: Array[PackedVector2Array] = l._segments(b, 0.0)
		if not segs.is_empty():
			seg = segs[0]
			break
	check(not seg.is_empty(), "un faisceau actif")
	check(l._hit_at(seg[0].lerp(seg[1], 0.5), 0.0), "touché sur le faisceau")
	l.free()


## Jonglage : frapper au moment où le jeton touche la ligne vaut une réception pleine.
func test_juggle_perfect_strike() -> void:
	var j: TrialJuggle = _trial("juggle") as TrialJuggle
	j.begin()
	var c: Dictionary = j._chips[0]
	c["age"] = j._flight()
	j.strike(int(c["lane"]))
	eq(j._marks.size(), 1, "une réception")
	eq(j._marks[0], 1.0, "parfaite")
	check(float(c["age"]) == 0.0, "relancé")
	j.free()


## Billard : visée « bille fantôme » et force du bot empochent une bille droite devant une poche.
func test_billiards_ghost_ball_pots() -> void:
	var b: TrialBilliards = _trial("billiards") as TrialBilliards
	b.begin()
	var pk: Vector2 = TrialBilliards.TABLE.end
	b._obj = pk - Vector2(260, 140)
	b._cue = b._obj - (pk - b._obj).normalized() * 300.0
	b._aim = b._best_plan().x
	b._charge = b.bot_charge()
	b._strike()
	var guard: int = 0
	while b._rolling and guard < 4000:
		guard += 1
		b.tick(1.0 / 120.0)
	check(b._obj_in, "bille empochée")
	b.free()
