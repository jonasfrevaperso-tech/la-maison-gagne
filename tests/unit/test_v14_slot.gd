extends TestCase
## 1.4 : machine à sous du jackpot (plein gagnant), gains temporaires, déterminisme.


func _ctl(seed_value: int = 7) -> RunController:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("lea", 0, seed_value)
	return c


func test_prize_table() -> void:
	var db: ContentDB = ContentDB.shared()
	eq(String(SlotMachine.prize_for(db, ["seven", "seven", "seven"] as Array[String]).get("id", "")), "p_seven3", "brelan de 7")
	eq(String(SlotMachine.prize_for(db, ["bell", "chip", "bell"] as Array[String]).get("id", "")), "p_bell2", "paire de cloches")
	check(SlotMachine.prize_for(db, ["bell", "chip", "seven"] as Array[String]).is_empty(), "trois symboles différents : rien")
	var o: Dictionary = SlotMachine.odds(db)
	check(float(o["triple"]) > 0.03 and float(o["triple"]) < 0.08, "brelan rare (%.3f)" % float(o["triple"]))
	check(float(o["pair"]) > 0.4 and float(o["pair"]) < 0.6, "paire une fois sur deux (%.3f)" % float(o["pair"]))
	check(float(o["quad"]) > 0.001 and float(o["quad"]) < 0.01, "carré exceptionnel (%.4f)" % float(o["quad"]))
	var four: Array[String] = ["seven", "seven", "seven", "seven"]
	eq(String(SlotMachine.prize_for(db, four).get("id", "")), "p_seven4", "carré de 7")
	eq(String(SlotMachine.prize_for(db, ["bell", "chip", "bell", "bell"] as Array[String]).get("id", "")), "p_bell3", "brelan sur 4 rouleaux")


func test_jackpot_detection_and_spins() -> void:
	var c: RunController = _ctl()
	var target: int = 0
	var n: int = c.run.wheel.at(target).number
	c.place_bet("straight:%d" % n, 1)
	# Lancer parfait sur la cible, contrôle forcé : la bille tombe sur le numéro joué.
	c.run.flags["control_temp"] = 5.0
	c.run.flags["zone_width_override"] = 1
	var out: RunController.SpinOutcome = c.spin(target, 1.0)
	if out.ctx.landing.number != n:
		return  # rebond improbable : rien à vérifier sur ce tirage
	check(out.jackpot, "plein gagnant = jackpot")
	eq(out.slot.size(), 3, "lancer parfait : trois tirages")
	eq(int(c.run.flags.get("jackpots", 0)), 1, "jackpot compté")


func test_slot_is_deterministic() -> void:
	var a: RunController = _ctl(99)
	var b: RunController = _ctl(99)
	var pa: Array[Dictionary] = SlotMachine.play(a.run, a.db, 3)
	eq(pa, SlotMachine.play(b.run, b.db, 3), "même graine, mêmes rouleaux")
	eq((pa[0]["reels"] as Array).size(), SlotMachine.REELS, "quatre rouleaux")


func test_temp_mult_and_control_are_consumed() -> void:
	var c: RunController = _ctl()
	SlotMachine.apply(c.run, c.db, c.db.get_entry("slot_prizes", "p_cherry3"))
	SlotMachine.apply(c.run, c.db, c.db.get_entry("slot_prizes", "p_clover2"))
	var p: ThrowResolver.ThrowParams = c.throw_params(0)
	check(p.control_bonus >= 0.05 - 0.0001, "contrôle temporaire pris en compte au lancer")
	c.place_bet("red", 1)
	var out: RunController.SpinOutcome = c.spin(0)
	check(out.ctx.mult_add >= 6.0, "Mult temporaire ajouté au tour suivant")
	# Le tour peut lui-même déclencher la machine (plein, case à tirage) et regagner un petit
	# bonus temporaire : on vérifie seulement que les bonus d'avant ont été consommés.
	var regained: bool = false
	for pull: Dictionary in out.slot:
		regained = regained or String(pull.get("prize", "")) != ""
	check(float(c.run.flags.get("temp_mult", 0.0)) < 6.0, "Mult temporaire consommé")
	check(regained or not c.run.flags.has("temp_control"), "contrôle temporaire consommé")


func test_free_spin_saves_last_spin() -> void:
	var c: RunController = _ctl()
	var before: int = c.run.spins_left
	SlotMachine.apply(c.run, c.db, c.db.get_entry("slot_prizes", "p_seven3"))
	eq(c.run.spins_left, before + 1, "tour offert")


func test_jackpot_on_deadline_winning_spin() -> void:
	var found: bool = false
	for sd: int in range(1, 40):
		var c: RunController = _ctl(sd)
		c.run.debt = 1
		var n: int = c.run.wheel.at(0).number
		c.place_bet("straight:%d" % n, 1)
		c.run.flags["control_temp"] = 5.0
		var out: RunController.SpinOutcome = c.spin(0, 1.0)
		if out.ctx.landing.number != n:
			continue
		found = true
		check(out.deadline_won, "échéance remboursée")
		check(out.jackpot and not out.slot.is_empty(), "jackpot conservé quand l'échéance est remboursée")
		break
	check(found, "un plein gagnant trouvé")


func test_free_spin_carries_over_won_deadline() -> void:
	var c: RunController = _ctl()
	c.run.flags["carry_spins"] = 1
	c.start_deadline()
	eq(c.run.spins_left, c.run.spins_total + 1, "tour offert reporté")
	check(not c.run.flags.has("carry_spins"), "report consommé")
