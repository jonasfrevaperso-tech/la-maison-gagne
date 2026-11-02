class_name ScoreEngine
extends RefCounted
## Moteur de score PUR (aucun Node, aucun autoload) : testable en headless.
## Ordre : atterrissage → Zéro → paris (ordre de pose) → case (type, édition, sceau,
## re-déclenchements) → grigris (ordre des emplacements) → total → fin de tour.

const MAX_POCKET_PASSES: int = 8


static func resolve(run: RunState, db: ContentDB, throw_result: ThrowResolver.ThrowResult) -> ScoreContext:
	var ctx: ScoreContext = ScoreContext.new()
	ctx.base_mult = Balance.f("score.base_mult")
	ctx.slip = run.slip.snapshot()
	ctx.throw_result = throw_result
	ctx.landing_index = throw_result.landing_index
	ctx.landing = run.wheel.at(ctx.landing_index)
	_compute_landing_identity(run, db, ctx)
	_update_streak(run, ctx)
	ctx.near_miss = _is_near_miss(run, ctx)

	EffectRunner.fire(&"on_ball_land", run, ctx, db)
	# Bonus de Mult temporaire (machine à sous) : consommé par ce tour.
	var temp_mult: float = float(run.flags.get("temp_mult", 0.0))
	if temp_mult != 0.0:
		run.flags.erase("temp_mult")
		ctx.mult_add += temp_mult
		ctx.push(ScoreEvent.MULT_ADD, ScoreEvent.SRC_SYSTEM, "slot", temp_mult, "slot_buff")

	var tdef: Dictionary = db.get_entry("pocket_types", String(ctx.landing.type_id))
	ctx.is_zero = ctx.landing.is_zero() or bool(tdef.get("zero_like", false))
	if ctx.is_zero:
		run.zeros_hit += 1
		ctx.push(ScoreEvent.ZERO, ScoreEvent.SRC_SYSTEM, "zero", 0.0)
		EffectRunner.fire(&"on_zero", run, ctx, db)
		if not ctx.zero_protected:
			var tax: int = mini(Balance.i("economy.zero_tax_money") + ctx.house_tax, run.money)
			if tax > 0:
				run.money -= tax
				ctx.money_delta -= tax
				ctx.push(ScoreEvent.MONEY, ScoreEvent.SRC_SYSTEM, "house_tax", -float(tax))

	_resolve_bets(run, db, ctx)

	var passes: int = 0
	var remaining: int = 1 + ctx.pocket_retriggers
	ctx.pocket_retriggers = 0
	while remaining > 0 and passes < MAX_POCKET_PASSES and ctx.landing_index >= 0:
		remaining -= 1
		passes += 1
		ctx.pocket_pass = passes
		_score_pocket(run, db, ctx, ctx.landing, ctx.landing_index, 0)
		remaining += ctx.pocket_retriggers
		ctx.pocket_retriggers = 0

	EffectRunner.fire(&"on_score_calc", run, ctx, db)
	ctx.total = ctx.compute_total()
	ctx.push(ScoreEvent.TOTAL, ScoreEvent.SRC_SYSTEM, "total", float(ctx.total))
	EffectRunner.fire(&"on_round_end", run, ctx, db)
	run.last_number = ctx.landing.number
	return ctx


static func _compute_landing_identity(run: RunState, db: ContentDB, ctx: ScoreContext) -> void:
	var p: Pocket = ctx.landing
	var def: Dictionary = db.get_entry("pocket_types", String(p.type_id))
	ctx.landing_colors.clear()
	ctx.landing_numbers.clear()
	ctx.landing_numbers.append(p.number)
	if def.has("counts_as_colors"):
		for c: Variant in def["counts_as_colors"]:
			ctx.landing_colors.append(StringName(String(c)))
	else:
		ctx.landing_colors.append(p.color())
	# Fantôme : compte aussi pour le numéro de la case suivante sur la roue.
	if bool(def.get("ghost", false)):
		var next_num: int = run.wheel.at(ctx.landing_index + 1).number
		if not ctx.landing_numbers.has(next_num):
			ctx.landing_numbers.append(next_num)


static func _update_streak(run: RunState, ctx: ScoreContext) -> void:
	var c: StringName = ctx.landing_colors[0]
	if c == run.color_streak_color:
		run.color_streak += 1
	else:
		run.color_streak_color = c
		run.color_streak = 1


static func _is_near_miss(run: RunState, ctx: ScoreContext) -> bool:
	var covered: Dictionary = {}
	for spot_id: String in ctx.slip.keys():
		var spot: BetSpot = BetCatalog.get_spot(spot_id)
		if spot != null and not spot.outside:
			for n: int in spot.numbers:
				covered[n] = true
	if covered.is_empty():
		return false
	for n: int in ctx.landing_numbers:
		if covered.has(n):
			return false
	for ni: int in run.wheel.neighbors(ctx.landing_index, 1):
		if covered.has(run.wheel.at(ni).number):
			return true
	return false


static func bet_wins(spot: BetSpot, ctx: ScoreContext) -> bool:
	match spot.kind:
		&"red", &"black":
			return ctx.landing_colors.has(spot.kind)
	for n: int in ctx.landing_numbers:
		if spot.covers(n):
			return true
	return false


static func payout(run: RunState, spot: BetSpot, stake: int) -> float:
	var mult: int = spot.odds + (1 if Balance.b("bets.stake_returned") else 0)
	return float(stake * run.chip_value * mult)


static func _resolve_bets(run: RunState, db: ContentDB, ctx: ScoreContext) -> void:
	for spot_id: String in ctx.slip.keys():
		var spot: BetSpot = BetCatalog.get_spot(spot_id)
		var stake: int = int(ctx.slip[spot_id])
		var won: bool = bet_wins(spot, ctx)
		if ctx.is_zero and spot.outside and not ctx.zero_protected:
			won = false
		ctx.current_bet = spot_id
		if won:
			var win: float = payout(run, spot, stake)
			ctx.chips += win
			ctx.bets_won.append(spot_id)
			ctx.win_chips_by_bet[spot_id] = win
			ctx.current_bet_win = win
			ctx.push(ScoreEvent.BET_WIN, ScoreEvent.SRC_BET, spot_id, win)
			EffectRunner.fire(&"on_bet_win", run, ctx, db)
		else:
			ctx.bets_lost.append(spot_id)
			ctx.current_bet_win = 0.0
			ctx.push(ScoreEvent.BET_LOSE, ScoreEvent.SRC_BET, spot_id, float(stake))
			EffectRunner.fire(&"on_bet_lose", run, ctx, db)
	var retrig: int = ctx.bet_retriggers
	ctx.bet_retriggers = 0
	for _r: int in retrig:
		for spot_id2: String in ctx.bets_won.duplicate():
			var win2: float = float(ctx.win_chips_by_bet.get(spot_id2, 0.0))
			ctx.current_bet = spot_id2
			ctx.current_bet_win = win2
			ctx.chips += win2
			ctx.push(ScoreEvent.BET_WIN, ScoreEvent.SRC_BET, spot_id2, win2, "retrigger")
			EffectRunner.fire(&"on_bet_win", run, ctx, db)
	ctx.current_bet = ""
	ctx.current_bet_win = 0.0


static func _score_pocket(run: RunState, db: ContentDB, ctx: ScoreContext, p: Pocket, index: int, depth: int) -> void:
	var num_chips: float = float(p.number * Balance.i("score.pocket_number_chips"))
	var lvl_chips: float = float(p.level * Balance.i("score.pocket_level_chips"))
	if num_chips + lvl_chips > 0.0:
		ctx.chips += num_chips + lvl_chips
		ctx.push(ScoreEvent.CHIPS, ScoreEvent.SRC_POCKET, String(p.type_id), num_chips + lvl_chips, str(p.number), p.uid)
	EffectRunner.fire_pocket(&"on_pocket_score", p, index, run, ctx, db)
	# Miroir : rejoue la case opposée (sans récursion infinie).
	var def: Dictionary = db.get_entry("pocket_types", String(p.type_id))
	if bool(def.get("mirror", false)) and depth == 0 and index >= 0:
		var oi: int = run.wheel.opposite_index(index)
		var other: Pocket = run.wheel.at(oi)
		if other.type_id != p.type_id:
			EffectRunner.fire_pocket(&"on_pocket_score", other, oi, run, ctx, db)
