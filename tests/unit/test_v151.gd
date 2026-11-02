extends TestCase
## 1.5.1 : tirages gratuits de machine à sous, gros coups, ×Mult temporaire, nombres compacts.


func _ctl(seed_value: int = 7) -> RunController:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("lea", 0, seed_value)
	return c


func test_slot_pull_flag_gives_pulls() -> void:
	var c: RunController = _ctl()
	c.run.flags["slot_pulls"] = 2
	var ctx: ScoreContext = ScoreContext.new()
	var n: int = SlotMachine.pulls(c.run, ctx, 0.5, 1000)
	eq(n, 2, "deux tirages gratuits accumulés")
	check(not c.run.flags.has("slot_pulls"), "tirages gratuits consommés")


func test_big_win_triggers_slot() -> void:
	var c: RunController = _ctl()
	var ctx: ScoreContext = ScoreContext.new()
	ctx.chips = float(c.run.debt)
	ctx.base_mult = 1.0
	ctx.total = ctx.compute_total()
	check(SlotMachine.pulls(c.run, ctx, 1.0, 10) > 0, "un coup qui solde l'échéance déclenche la machine")
	var small: ScoreContext = ScoreContext.new()
	small.chips = 5.0
	small.total = small.compute_total()
	eq(SlotMachine.pulls(c.run, small, 1.0, 10000), 0, "petit coup : pas de machine")


func test_pulls_are_capped() -> void:
	var c: RunController = _ctl()
	c.run.flags["slot_pulls"] = 50
	eq(SlotMachine.pulls(c.run, ScoreContext.new(), 0.0, 1000), Balance.i("slot.max_pulls"), "plafond de tirages")


func test_temp_xmult_consumed() -> void:
	var c: RunController = _ctl()
	SlotMachine.apply(c.run, c.db, c.db.get_entry("slot_prizes", "p_cherry3"))
	c.place_bet("red", 1)
	var out: RunController.SpinOutcome = c.spin(0)
	check(out.ctx.mult_mul >= 2.0 - 0.0001, "×Mult temporaire appliqué")
	check(float(c.run.flags.get("temp_xmult", 1.0)) != 2.0 or out.jackpot, "×Mult temporaire consommé (ou regagné au jackpot)")


func test_total_never_overflows() -> void:
	var ctx: ScoreContext = ScoreContext.new()
	ctx.chips = 1.0e15
	ctx.mult_mul = 1.0e12
	eq(ctx.compute_total(), int(ScoreContext.MAX_TOTAL), "total plafonné")


func test_compact_numbers() -> void:
	var prev: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	eq(Localization.format_number(1234.0), "1,234", "petit nombre : séparateurs")
	eq(Localization.format_compact(123456.0), "123K", "milliers")
	eq(Localization.format_compact(12345678.0), "12.3M", "millions")
	eq(Localization.format_compact(1.5e9), "1.50B", "milliards")
	check(Localization.format_compact(1.0e30).contains("e+"), "notation scientifique au-delà")
	TranslationServer.set_locale("fr")
	eq(Localization.format_compact(12345678.0), "12,3 M", "FR : virgule et espace fine")
	eq(Localization.format_compact(1.5e9), "1,50 Md", "FR : milliard")
	TranslationServer.set_locale(prev)


func test_new_trials_registered() -> void:
	var db: ContentDB = ContentDB.shared()
	for id: String in ["pour", "simon", "catch", "highlow", "sort"]:
		check(not db.get_entry("throw_trials", id).is_empty(), "épreuve %s présente" % id)
