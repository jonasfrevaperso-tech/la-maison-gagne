extends TestCase
## Version 1.2 : grigris des sceaux, des destructions et de la roue ; créanciers de roue.

var ctl: RunController = null


func before_each() -> void:
	ctl = RunController.new(ContentDB.shared())
	ctl.new_run("vic", 0, 1)
	ctl.run.wheel = WheelModel.standard()
	ctl.run.grigris.clear()
	ctl.run.contracts.clear()
	ctl.run.character_id = ""
	ctl.run.flags.clear()
	ctl.run.money = 10
	ctl.begin_betting()


func _land(n: int) -> ScoreContext:
	var t: ThrowResolver.ThrowResult = ThrowResolver.ThrowResult.new()
	t.landing_index = ctl.run.wheel.first_index_of_number(n)
	t.target_index = t.landing_index
	t.in_zone = true
	return ScoreEngine.resolve(ctl.run, ctl.db, t)


func test_seal_triggers_grigri() -> void:
	ShopModel.acquire_grigri(ctl.run, ctl.db, "g_wax_stamp", &"")
	ctl.place_bet("red", 1)
	var plain: ScoreContext = _land(19)
	ctl.run.wheel.at(ctl.run.wheel.first_index_of_number(19)).seal = &"seal_green"
	var sealed: ScoreContext = _land(19)
	check(sealed.mult_add >= plain.mult_add + 4.0 - 0.001, "Cachet de cire : +4 Mult sur une case scellée")


func test_seal_count_variable() -> void:
	ShopModel.acquire_grigri(ctl.run, ctl.db, "g_notary_ring", &"")
	for n: int in [1, 2, 3, 4]:
		ctl.run.wheel.at(ctl.run.wheel.first_index_of_number(n)).seal = &"seal_gold"
	ctl.place_bet("red", 1)
	var c: ScoreContext = _land(19)
	check(c.mult_add >= 6.0 - 0.001, "Chevalière : 4 sceaux × 1,5 Mult")


func test_destroyed_pocket_pays_undertaker() -> void:
	ShopModel.acquire_grigri(ctl.run, ctl.db, "g_undertaker", &"")
	var glass: Pocket = ctl.run.wheel.at(ctl.run.wheel.first_index_of_number(7))
	glass.type_id = &"glass"
	var size_before: int = ctl.run.wheel.size()
	var money_before: int = ctl.run.money
	var broke: bool = false
	for _i: int in 60:
		ctl.place_bet("red", 1)
		_land(7)
		if ctl.run.wheel.size() < size_before:
			broke = true
			break
	check(broke, "une case de verre finit par se briser")
	check(ctl.run.money >= money_before + 3, "Croque-mort : +3 $ à la destruction")


func test_landing_copies_twin_city() -> void:
	ShopModel.acquire_grigri(ctl.run, ctl.db, "g_twin_city", &"")
	var i17: int = ctl.run.wheel.first_index_of_number(17)
	ctl.run.wheel.insert_copy(i17, ctl.run.wheel.at(i17))
	ctl.run.wheel.insert_copy(i17, ctl.run.wheel.at(i17))
	ctl.place_bet("red", 1)
	var c: ScoreContext = _land(17)
	check(absf(c.mult_mul - 2.0) < 0.001, "Ville jumelle : 3 cases « 17 » → ×2 Mult")


func test_shell_gamer_restores_wheel() -> void:
	var before: Array[int] = ctl.run.wheel.order_uids()
	ctl.run.creditor_id = "cr_bonneteur"
	ctl.run.tier = 3
	ctl.run.deadline_idx = 2
	EffectRunner.fire(&"on_bet_phase", ctl.run, null, ctl.db)
	EffectRunner.fire(&"on_bet_phase", ctl.run, null, ctl.db)
	check(ctl.run.wheel.order_uids() != before, "Le Bonneteur mélange la roue")
	eq(ctl.run.wheel.size(), before.size(), "aucune case perdue")
	var rd: Dictionary = RunState.from_dict(ctl.run.to_dict()).flags
	check(rd.has(EffectRunner.WHEEL_BACKUP_FLAG), "l'ordre d'origine survit à la sauvegarde")
	ctl.run.deadline_idx = 0
	ctl.start_deadline()
	eq(ctl.run.wheel.order_uids(), before, "ordre restauré à l'échéance suivante")


func test_waltzer_flags_wheel() -> void:
	var c: Dictionary = ctl.db.get_entry("creditors", "cr_valseuse")
	check(bool(c.get("wheel_reverse", false)), "La Valseuse inverse la roue")
	check(float(c.get("aim_speed_mult", 1.0)) > 1.0, "et accélère la visée")


func test_endless_grigris() -> void:
	ShopModel.acquire_grigri(ctl.run, ctl.db, "g_insomniac", &"")
	ctl.place_bet("red", 1)
	ctl.run.tier = 3
	var normal: ScoreContext = _land(19)
	ctl.run.tier = 10
	var endless: ScoreContext = _land(19)
	check(absf(normal.mult_mul - 1.0) < 0.001 and absf(endless.mult_mul - 2.0) < 0.001, "Insomniaque : ×2 seulement en mode Infini")
