extends TestCase
## Non-régression des bugs trouvés par le fuzzing de graines (phase 13).


func _rt(r: RunState) -> RunState:
	return RunState.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())) as Dictionary)


func test_slip_survives_reload_with_table_bonus() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("vic", 0, 3)  # Vic : limites de table +2
	eq(c.place_bet("straight:9", 3), BetSlip.PlaceResult.OK)
	var back: RunState = _rt(c.run)
	eq(int(back.slip.chips.get("straight:9", 0)), 3, "3 jetons conservés au rechargement")


func test_integer_flags_roundtrip_exactly() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("lea", 0, 4)
	c.run.flags["fortunes_used"] = 3
	c.run.flags["choices"] = {"act1_intro:6": 1}
	var a: String = JSON.stringify(c.run.to_dict())
	eq(JSON.stringify(_rt(c.run).to_dict()), a)


func test_stacked_penalties_keep_one_spin() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("lea", 2, 5, "ch_one_spin")  # 1 tour, et le Risque 2 en retire un aux Petites Échéances
	check(c.run.spins_left >= 1, "au moins un tour")
	c.place_bet("red", 1)
	c.spin(0)
	check(c.run.spins_left >= 0, "jamais négatif")


func test_no_softlock_when_rules_forbid_everything() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("lea", 0, 6, "ch_red_only")
	c.run.banned_color = &"red"
	c._configure_slip(true)
	check(c.ensure_some_bet(), "un pari reste possible")


func test_slip_keeps_consumed_temp_budget_on_reload() -> void:
	# 1.2 : le bulletin du tour précédent (budget gonflé par un bonus temporaire déjà consommé)
	# était tronqué au rechargement hors phase de mise.
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("lea", 0, 7)
	c.run.slip.budget = c.run.bet_budget + 2
	for i: int in c.run.slip.budget:
		c.run.slip.place("straight:%d" % i, 1)
	eq(c.run.slip.total(), c.run.bet_budget + 2, "bulletin rempli au-delà du budget de base")
	c.run.temp_budget_bonus = 0
	var a: String = JSON.stringify(c.run.to_dict())
	eq(JSON.stringify(_rt(c.run).to_dict()), a, "bulletin identique après rechargement")
