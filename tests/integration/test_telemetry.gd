extends TestCase
## Télémétrie locale (enregistrements purs) et historique des runs du profil.


func test_records_follow_a_run() -> void:
	var ctl: RunController = RunController.new(ContentDB.shared())
	ctl.new_run("lea", 0, 4242)
	var start: Dictionary = RunTelemetry.run_start(ctl.run, "human", "test")
	eq(String(start["t"]), "run_start", "type")
	eq(int(start["seed"]), 4242, "graine")
	var deadlines: int = 0
	var spins: int = 0
	while spins < 40 and ctl.run.phase != RunState.Phase.GAME_OVER and ctl.run.phase != RunState.Phase.VICTORY:
		match ctl.run.phase:
			RunState.Phase.BETTING:
				ctl.place_bet("red", 5)
				ctl.place_bet("split:17-20", 2)
				ctl.ensure_some_bet()
				var pre: Dictionary = RunTelemetry.snapshot(ctl.run)
				var tier_before: int = ctl.run.tier
				var out: RunController.SpinOutcome = ctl.spin(ctl.run.wheel.first_index_of_number(17))
				var rec: Dictionary = RunTelemetry.spin(pre, ctl.run, out.ctx, 500.0)
				eq(int(rec["tier"]), tier_before, "palier d'avant le tour")
				eq(float(rec["think_s"]), RunTelemetry.MAX_THINK_SECONDS, "réflexion plafonnée")
				check((rec["bets"] as Dictionary).has("split"), "paris par type")
				if out.deadline_won or out.deadline_failed:
					var d: Dictionary = RunTelemetry.deadline(pre, ctl.run, out.ctx, out.deadline_won, 1.0)
					eq(bool(d["won"]), int(d["score"]) >= int(d["debt"]), "victoire = score ≥ dette")
					deadlines += 1
				spins += 1
			RunState.Phase.SHOP:
				var before: Array[String] = RunTelemetry.grigri_ids(ctl.run)
				var money: int = ctl.run.money
				ShopModel.buy_grigri(ctl.run, ctl.db, 0)
				var offered: Array[String] = []
				var bought: Array[String] = []
				for o: Dictionary in RunTelemetry.shop_offers(ctl.run):
					offered.append(String(o["id"]))
					if bool(o.get("sold", false)):
						bought.append(String(o["id"]))
				var s: Dictionary = RunTelemetry.shop(ctl.run, offered, bought, before, money, 0, 1.0)
				eq((s["bought"] as Array).size(), RunTelemetry.grigri_ids(ctl.run).size() - before.size(), "achats = grigris gagnés")
				ctl.leave_shop()
			RunState.Phase.PACT_OFFER:
				ctl.decline_pact()
			RunState.Phase.EVENT:
				ctl.resolve_event(0)
	check(deadlines >= 1, "au moins une échéance terminée")
	var line: String = JSON.stringify(RunTelemetry.run_end(ctl.run, false, 60.0))
	check(JSON.parse_string(line) is Dictionary, "enregistrement JSON valide")


func test_history_and_survival() -> void:
	var ctl: RunController = RunController.new(ContentDB.shared())
	ctl.new_run("vic", 1, 99)
	var profile: Dictionary = {}
	ctl.run.tier = 3
	RunHistory.record(profile, RunHistory.entry(ctl.run, false, 600.0, "AAAA", "d"), 8)
	RunHistory.record(profile, RunHistory.entry(ctl.run, true, 1800.0, "BBBB", "d"), 8)
	var rates: Array[float] = RunHistory.survival_rates(profile, 8)
	eq(rates[0], 1.0, "palier 1 passé deux fois")
	eq(rates[2], 0.5, "palier 3 : un échec, une victoire")
	eq(rates[7], 1.0, "palier 8 : la victoire")
	eq(float((profile["stats"] as Dictionary)["minutes"]), 40.0, "temps de jeu cumulé")
	for i: int in RunHistory.MAX_ENTRIES + 5:
		RunHistory.record(profile, RunHistory.entry(ctl.run, false, 1.0, "C", "d"), 8)
	eq((profile["history"] as Array).size(), RunHistory.MAX_ENTRIES, "historique borné")


func test_seed_race_ranking() -> void:
	var profile: Dictionary = {
		"history":
		[
			{"seed": "AAA", "victory": false, "deadlines": 9, "score_total": 500, "minutes": 10.0},
			{"seed": "AAA", "victory": true, "deadlines": 24, "score_total": 100, "minutes": 50.0},
			{"seed": "BBB", "victory": true, "deadlines": 24, "score_total": 9999, "minutes": 1.0},
			{"seed": "AAA", "victory": false, "deadlines": 9, "score_total": 500, "minutes": 8.0},
			{"seed": "AAA", "victory": false, "deadlines": 12, "score_total": 10, "minutes": 60.0},
		]
	}
	var board: Array[Dictionary] = RunHistory.leaderboard(profile, "AAA")
	eq(board.size(), 4, "seuls les runs de cette graine")
	check(bool(board[0]["victory"]), "la victoire passe devant")
	eq(int(board[1]["deadlines"]), 12, "puis le plus d'échéances")
	eq(float(board[2]["minutes"]), 8.0, "à égalité, le plus rapide")
