extends TestCase
## Moteur de score : paiements, Zéro, cases spéciales, grigris, ordre des événements.

var ctl: RunController = null


func before_each() -> void:
	ctl = RunController.new(ContentDB.shared())
	ctl.new_run("vic", 0, 1)
	# Roue et grigris neutres pour des tests déterministes.
	ctl.run.wheel = WheelModel.standard()
	ctl.run.grigris.clear()
	ctl.run.contracts.clear()
	ctl.run.character_id = ""
	ctl.run.flags.clear()
	ctl.run.money = 10
	ctl.run.chip_value = 5
	ctl.run.bet_budget = 10
	ctl.begin_betting()


## Force l'atterrissage sur le numéro `n`.
func _land(n: int) -> ScoreContext:
	var tr: ThrowResolver.ThrowResult = ThrowResolver.ThrowResult.new()
	tr.landing_index = ctl.run.wheel.first_index_of_number(n)
	tr.target_index = tr.landing_index
	tr.in_zone = true
	return ScoreEngine.resolve(ctl.run, ctl.db, tr)


func test_red_bet_pays_even_money_plus_stake() -> void:
	ctl.place_bet("red", 10)
	var ctx: ScoreContext = _land(1)  # 1 est rouge
	# 10 jetons × 5 × (1+1) = 100, + numéro 1 = 101 ; Mult 1
	near(ctx.chips, 101.0, 0.001, "jetons")
	eq(ctx.total, 101)
	eq(ctx.bets_won, ["red"] as Array[String])


func test_straight_pays_36x() -> void:
	ctl.place_bet("straight:17", 1)
	var ctx: ScoreContext = _land(17)
	near(ctx.chips, 5.0 * 36.0 + 17.0, 0.001)


func test_losing_bet_scores_only_pocket() -> void:
	ctl.place_bet("black", 10)
	var ctx: ScoreContext = _land(1)
	eq(ctx.total, 1)
	eq(ctx.bets_lost.size(), 1)


func test_zero_kills_outside_and_taxes() -> void:
	ctl.place_bet("red", 5)
	ctl.place_bet("straight:0", 1)
	var ctx: ScoreContext = _land(0)
	check(ctx.is_zero, "zéro détecté")
	eq(ctx.bets_lost, ["red"] as Array[String], "rouge perd")
	eq(ctx.bets_won, ["straight:0"] as Array[String], "plein 0 gagne")
	eq(ctl.run.money, 10 - Balance.i("economy.zero_tax_money"), "taxe")


func test_zero_shield_protects() -> void:
	ctl.run.add_grigri("g_zero_hero")
	ctl.place_bet("even", 5)
	var ctx: ScoreContext = _land(0)
	eq(ctl.run.money, 10, "pas de taxe")
	# Pair ne couvre pas 0 : perd quand même, mais n'est pas « tué » par le zéro.
	eq(ctx.bets_lost, ["even"] as Array[String])


func test_grigri_mult_and_formula() -> void:
	ctl.run.add_grigri("g_red_ribbon")  # +4 Mult sur rouge
	ctl.run.add_grigri("g_house_key")  # ×3
	ctl.place_bet("red", 10)
	var ctx: ScoreContext = _land(1)
	near(ctx.mult(), (1.0 + 4.0) * 3.0, 0.001, "Mult")
	eq(ctx.total, int(floor(101.0 * 15.0)))


func test_golden_pocket_and_events_order() -> void:
	ctl.run.wheel.at(ctl.run.wheel.first_index_of_number(1)).type_id = &"golden"
	ctl.place_bet("red", 1)
	var ctx: ScoreContext = _land(1)
	near(ctx.chips, 10.0 + 1.0 + 50.0, 0.001)
	var kinds: Array[StringName] = []
	for e: ScoreEvent in ctx.events:
		kinds.append(e.kind)
	eq(kinds[0], ScoreEvent.BET_WIN, "le pari d'abord")
	eq(kinds[kinds.size() - 1], ScoreEvent.TOTAL, "total en dernier")


func test_twin_pocket_scores_twice() -> void:
	ctl.run.wheel.at(ctl.run.wheel.first_index_of_number(20)).type_id = &"twin"
	ctl.place_bet("black", 1)
	var ctx: ScoreContext = _land(20)
	near(ctx.chips, 10.0 + 40.0, 0.001, "20 compté deux fois")


func test_chandelier_retriggers_from_ball_land() -> void:
	ctl.run.add_grigri("g_chandelier")
	ctl.place_bet("black", 1)
	var ctx: ScoreContext = _land(20)
	near(ctx.chips, 10.0 + 60.0, 0.001, "20 compté trois fois")


func test_joker_counts_both_colors() -> void:
	ctl.run.wheel.at(ctl.run.wheel.first_index_of_number(1)).type_id = &"joker"
	ctl.place_bet("red", 1)
	ctl.place_bet("black", 1)
	var ctx: ScoreContext = _land(1)
	eq(ctx.bets_won.size(), 2)


func test_ghost_counts_next_number() -> void:
	var idx: int = ctl.run.wheel.first_index_of_number(32)  # suivant : 15
	ctl.run.wheel.at(idx).type_id = &"ghost"
	ctl.place_bet("straight:15", 1)
	var ctx: ScoreContext = _land(32)
	eq(ctx.bets_won, ["straight:15"] as Array[String])


func test_blueprint_copies_right_neighbor() -> void:
	ctl.run.add_grigri("g_blueprint")
	ctl.run.add_grigri("g_velvet_glove")  # +3
	ctl.place_bet("red", 1)
	var ctx: ScoreContext = _land(1)
	near(ctx.mult(), 1.0 + 3.0 + 3.0, 0.001, "copie du +3")


func test_dealer_hand_doubles_bets() -> void:
	ctl.run.add_grigri("g_dealer_hand")
	ctl.place_bet("red", 2)
	var ctx: ScoreContext = _land(1)
	near(ctx.chips, 20.0 * 2.0 + 1.0, 0.001)


func test_glass_can_break() -> void:
	var broke: bool = false
	for s: int in 40:
		before_each()
		ctl.run.rng.reseed(s)
		ctl.run.wheel.at(ctl.run.wheel.first_index_of_number(1)).type_id = &"glass"
		ctl.place_bet("red", 1)
		var size_before: int = ctl.run.wheel.size()
		var ctx: ScoreContext = _land(1)
		near(ctx.mult_mul, 2.0, 0.001, "×2")
		if ctl.run.wheel.size() < size_before:
			broke = true
	check(broke, "au moins une casse sur 40 essais")


func test_comptable_taxes_wins() -> void:
	ctl.run.deadline_idx = 2
	ctl.run.creditor_id = "cr_comptable"
	ctl.place_bet("red", 10)
	var ctx: ScoreContext = _land(1)
	near(ctx.chips, 100.0 * 0.75 + 1.0, 0.001)
