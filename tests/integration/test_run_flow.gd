extends TestCase
## Intégration : runs complets, déterminisme, sauvegarde/reprise, boutique, pacte.


func _play_simple(ctl: RunController, max_spins: int) -> int:
	var spins: int = 0
	while spins < max_spins:
		match ctl.run.phase:
			RunState.Phase.BETTING:
				ctl.place_bet("red", 5)
				ctl.place_bet("straight:32", 2)
				ctl.place_bet("straight:15", 2)
				ctl.ensure_some_bet()
				ctl.spin(ctl.run.wheel.first_index_of_number(32))
				spins += 1
			RunState.Phase.SHOP:
				ShopModel.buy_grigri(ctl.run, ctl.db, 0)
				ctl.leave_shop()
			RunState.Phase.PACT_OFFER:
				var opts: Array[Dictionary] = ctl.pact_options()
				if opts.is_empty():
					ctl.decline_pact()
				else:
					ctl.accept_pact(opts[0])
			RunState.Phase.EVENT:
				ctl.resolve_event(0)
			_:
				break
	return spins


func test_run_is_deterministic() -> void:
	var a: RunController = RunController.new(ContentDB.shared())
	a.new_run("lea", 0, 777)
	var b: RunController = RunController.new(ContentDB.shared())
	b.new_run("lea", 0, 777)
	_play_simple(a, 60)
	_play_simple(b, 60)
	eq(JSON.stringify(a.run.to_dict()), JSON.stringify(b.run.to_dict()), "même graine → même run")


func test_save_load_roundtrip_continues_identically() -> void:
	var a: RunController = RunController.new(ContentDB.shared())
	a.new_run("odile", 0, 4242)
	_play_simple(a, 9)
	var saved: Dictionary = a.run.to_dict()
	var b: RunController = RunController.new(ContentDB.shared())
	b.load_run(RunState.from_dict(JSON.parse_string(JSON.stringify(saved)) as Dictionary))
	eq(JSON.stringify(b.run.to_dict()), JSON.stringify(saved), "aller-retour JSON exact")
	_play_simple(a, 20)
	_play_simple(b, 20)
	eq(JSON.stringify(a.run.to_dict()), JSON.stringify(b.run.to_dict()), "suite identique après reprise")


func test_all_characters_start_and_play() -> void:
	for cid: String in ContentDB.shared().ids("characters"):
		var c: RunController = RunController.new(ContentDB.shared())
		c.new_run(cid, 0, 99)
		check(c.run.phase == RunState.Phase.BETTING, "%s en phase de paris" % cid)
		_play_simple(c, 30)
		check(c.run.total_spins > 0, "%s a joué" % cid)


func test_all_risk_levels_start() -> void:
	for r: int in range(0, 9):
		var c: RunController = RunController.new(ContentDB.shared())
		c.new_run("vic", r, 5)
		check(c.run.debt > 0, "risque %d : dette > 0" % r)
		_play_simple(c, 12)
	var c4: RunController = RunController.new(ContentDB.shared())
	c4.new_run("vic", 4, 5)
	eq(c4.run.wheel.size(), 38, "risque 4 : zéro double ajouté")


func test_deadline_won_goes_to_shop_with_reward() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("lea", 0, 1)
	c.run.debt = 1
	var money_before: int = c.run.money
	c.place_bet("red", 1)
	var out: RunController.SpinOutcome = c.spin(0)
	check(out.deadline_won, "échéance remboursée")
	eq(c.run.phase, RunState.Phase.SHOP)
	check(c.run.money > money_before, "récompense versée")
	eq(c.run.deadline_idx, 1, "passage à la Grande Échéance")
	eq((c.run.shop_state["grigris"] as Array).size(), Balance.i("shop.grigri_offers"))


func test_shop_buy_sell_reroll() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("vic", 0, 3)
	ShopModel.enter(c.run, c.db)
	c.run.money = 100
	var n_before: int = c.run.grigris.size()
	eq(ShopModel.buy_grigri(c.run, c.db, 0), ShopModel.BuyResult.OK)
	eq(c.run.grigris.size(), n_before + 1)
	eq(ShopModel.buy_grigri(c.run, c.db, 0), ShopModel.BuyResult.SOLD_OUT)
	var g: GrigriInstance = c.run.grigris[c.run.grigris.size() - 1]
	var money: int = c.run.money
	var got: int = ShopModel.sell_grigri(c.run, c.db, g.uid)
	check(got > 0, "vente rapporte")
	eq(c.run.money, money + got)
	var cost: int = int(c.run.shop_state["reroll_cost"])
	check(ShopModel.reroll(c.run, c.db), "reroll")
	eq(int(c.run.shop_state["reroll_cost"]), cost + Balance.i("shop.reroll_cost_step"), "coût croissant")


func test_pocket_pack_add_and_replace() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("vic", 0, 8)
	ShopModel.enter(c.run, c.db)
	c.run.shop_state["open_pack"] = {"kind": "pocket", "choices": [{"type": "golden", "number": 17, "edition": "", "seal": ""}]}
	var size: int = c.run.wheel.size()
	check(ShopModel.choose_pack(c.run, c.db, 0, "add"))
	eq(c.run.wheel.size(), size + 1, "case ajoutée")
	eq(c.run.wheel.count_number(17), 2, "deux 17")
	c.run.shop_state["open_pack"] = {"kind": "pocket", "choices": [{"type": "ruby", "number": 5, "edition": "holo", "seal": ""}]}
	check(ShopModel.choose_pack(c.run, c.db, 0, "replace"))
	var p: Pocket = c.run.wheel.at(c.run.wheel.first_index_of_number(5))
	eq(p.type_id, &"ruby")
	eq(p.edition, &"holo")


func test_pact_gives_extra_spin_once_per_act() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("vic", 0, 11)
	c.run.debt = 999999999
	while c.run.phase == RunState.Phase.BETTING:
		c.place_bet("red", 1)
		c.ensure_some_bet()
		c.spin(0)
	eq(c.run.phase, RunState.Phase.PACT_OFFER, "pacte proposé")
	var opts: Array[Dictionary] = c.pact_options()
	check(not opts.is_empty())
	check(c.accept_pact(opts[opts.size() - 1]))
	eq(c.run.spins_left, Balance.i("pact.extra_spins"))
	c.place_bet("red", 1)
	c.ensure_some_bet()
	c.spin(0)
	eq(c.run.phase, RunState.Phase.GAME_OVER, "un seul pacte par acte")


func test_fortune_targets_pocket() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("vic", 0, 12)
	c.run.fortunes = ["f_gild"]
	check(c.fortune_needs_target("f_gild"))
	check(not c.use_fortune(0, -1), "cible requise")
	check(c.use_fortune(0, 3))
	eq(c.run.wheel.at(3).type_id, &"golden")
	eq(c.run.fortunes.size(), 0)


func test_lea_rethrow() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("lea", 0, 13)
	c.place_bet("red", 1)
	c.throw_ball(0)
	check(c.can_rethrow(), "relance dispo")
	c.rethrow(5)
	check(not c.can_rethrow(), "une seule relance")
	var out: RunController.SpinOutcome = c.commit_spin()
	check(out.ctx != null)
