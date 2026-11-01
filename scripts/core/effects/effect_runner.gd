class_name EffectRunner
extends RefCounted
## Interpréteur des effets data-driven.
## Un effet : {"trigger": "...", "if": [conditions], "do": [actions]}.
## Condition : {"c": nom, "op": ">=", "v": valeur} — prédicat nommé ou variable comparée.
## Action    : {"op": nom, "v": valeur|expression, ...}.
## Expression: nombre, ou {"var": nom, "mul": m, "add": a, "min": x, "max": y}.

const TRIGGERS: Array[StringName] = [
	&"on_run_start",
	&"on_deadline_start",
	&"on_bet_placed",
	&"on_spin_start",
	&"on_ball_land",
	&"on_zero",
	&"on_bet_win",
	&"on_bet_lose",
	&"on_pocket_score",
	&"on_edition",
	&"on_seal",
	&"on_score_calc",
	&"on_round_end",
	&"on_deadline_end",
	&"on_shop_enter",
	&"on_reroll",
	&"on_buy",
	&"on_sell",
	&"on_fortune_used",
	&"on_pocket_destroyed",
	&"passive",
	&"on_acquire",
	&"on_remove",
	&"on_use",
	&"on_bet_phase",
]
const PREDICATES: Array[StringName] = [
	&"color",
	&"number_in",
	&"parity",
	&"range",
	&"dozen",
	&"is_zero",
	&"pocket_type",
	&"pocket_has_edition",
	&"pocket_edition",
	&"pocket_has_seal",
	&"bet_kind",
	&"bet_outside",
	&"bet_inside",
	&"chance",
	&"deadline_kind",
	&"won_nothing",
	&"number_repeat",
	&"near_miss",
	&"neighbor_type",
	&"not",
	&"any",
	&"last_spin",
	&"first_spin",
	&"has_grigri",
	&"is_creditor",
	&"in_zone",
	&"attracted",
	&"bet_covers_landing_neighbor",
	&"grigri_position",
	&"first_pass",
	&"flag",
]
const VARIABLES: Array[StringName] = [
	&"counter",
	&"money",
	&"grigri_count",
	&"empty_slots",
	&"spins_left",
	&"spin_index",
	&"pocket_number",
	&"color_streak",
	&"bets_won",
	&"bets_lost",
	&"bets_placed",
	&"distinct_kinds",
	&"chips_staked",
	&"tier",
	&"act",
	&"deadline_index",
	&"wheel_size",
	&"cursed_count",
	&"fortune_count",
	&"contract_count",
	&"chip_value",
	&"bet_budget",
	&"precision",
	&"chips",
	&"mult",
	&"win_chips",
	&"bet_chips",
	&"rerolls",
	&"sold_count",
	&"zero_count",
	&"deadline_score",
	&"debt",
	&"edition_pockets",
	&"pocket_level",
	&"total_spins",
	&"unused_budget",
	&"rare_count",
	&"common_count",
	&"legendary_count",
	&"number_count",
	&"debt_progress",
	&"type_count",
]
const OPS: Array[StringName] = [
	&"add_chips",
	&"add_mult",
	&"mul_mult",
	&"add_money",
	&"counter_add",
	&"counter_set",
	&"counter_mul",
	&"add_spins",
	&"temp_budget",
	&"perm_budget",
	&"perm_chip_value",
	&"perm_precision",
	&"temp_precision",
	&"perm_control",
	&"add_slot",
	&"retrigger_pocket",
	&"retrigger_bets",
	&"multiply_win",
	&"self_destroy",
	&"chance_destroy_pocket",
	&"destroy_pocket",
	&"transform_pocket",
	&"set_pocket_edition",
	&"set_pocket_seal",
	&"upgrade_pocket",
	&"add_fortune",
	&"add_grigri",
	&"debt_add_pct",
	&"protect_zero",
	&"copy_right",
	&"copy_left",
	&"message",
	&"house_tax_add",
	&"add_pocket_copy",
	&"set_flag",
	&"ban_random_color",
	&"refund_lost",
	&"sell_bonus",
	&"disable_random_grigri",
	&"burn_random_pocket",
	&"debt_add",
	&"shop_discount",
	&"interest_cap",
	&"table_limit",
	&"add_rethrow",
	&"steal_chips",
	&"randomize_pocket",
	&"destroy_random_grigri",
	&"add_extra_spins",
	&"add_random_seal",
	&"add_random_edition_grigri",
	&"add_fortune_slot",
	&"next_debt_pct",
]
const MAX_DEPTH: int = 3
const CMP_DEFAULT: String = ">="

# --------------------------------------------------------------------------- déclencheurs


## Exécute un déclencheur sur toutes les sources globales, dans l'ordre :
## personnage, contrats, créancier, puis grigris dans l'ordre des emplacements.
static func fire(trigger: StringName, run: RunState, ctx: ScoreContext, db: ContentDB, extra: Dictionary = {}) -> void:
	var base: EffectEnv = EffectEnv.new()
	base.run = run
	base.ctx = ctx
	base.db = db
	base.extra = extra
	if run.character_id != "":
		_fire_entry(trigger, db.get_entry("characters", run.character_id), base, ScoreEvent.SRC_CHARACTER, run.character_id, 0, null)
	for cid: String in run.contracts:
		_fire_entry(trigger, db.get_entry("contracts", cid), base, ScoreEvent.SRC_CONTRACT, cid, 0, null)
	if run.creditor_id != "" and run.is_creditor():
		var cdef: Dictionary = db.get_entry("creditors", run.creditor_id)
		_fire_entry(trigger, cdef, base, ScoreEvent.SRC_CREDITOR, run.creditor_id, 0, null)
		var phases: Array = cdef.get("phases", [])
		if run.creditor_phase < phases.size():
			_fire_entry(trigger, phases[run.creditor_phase] as Dictionary, base, ScoreEvent.SRC_CREDITOR, run.creditor_id, 0, null)
	if run.challenge_id != "":
		_fire_entry(trigger, db.get_entry("challenges", run.challenge_id), base, ScoreEvent.SRC_SYSTEM, run.challenge_id, 0, null)
	if run.flags.has("risk_effects"):
		for rid: Variant in run.flags["risk_effects"]:
			_fire_entry(trigger, db.get_entry("risks", String(rid)), base, ScoreEvent.SRC_SYSTEM, String(rid), 0, null)
	# Copie défensive : un grigri peut se détruire pendant l'itération.
	var list: Array[GrigriInstance] = run.grigris.duplicate()
	for g: GrigriInstance in list:
		if g.disabled or not run.grigris.has(g):
			continue
		fire_grigri(trigger, g, base)


static func fire_grigri(trigger: StringName, g: GrigriInstance, base: EffectEnv) -> void:
	var def: Dictionary = base.db.get_entry("grigris", g.id)
	_fire_entry(trigger, def, base, ScoreEvent.SRC_GRIGRI, g.id, g.uid, g)
	if g.edition != &"" and trigger == &"on_score_calc":
		var ed: Dictionary = base.db.get_entry("editions", String(g.edition))
		_fire_entry(&"on_edition", ed, base, ScoreEvent.SRC_EDITION, String(g.edition), g.uid, g)


## Exécute les effets d'une case (type, puis édition, puis sceau) pour un déclencheur.
static func fire_pocket(trigger: StringName, pocket: Pocket, index: int, run: RunState, ctx: ScoreContext, db: ContentDB) -> void:
	var base: EffectEnv = EffectEnv.new()
	base.run = run
	base.ctx = ctx
	base.db = db
	base.pocket = pocket
	base.pocket_index = index
	var tdef: Dictionary = db.get_entry("pocket_types", String(pocket.type_id))
	_fire_entry(trigger, tdef, base, ScoreEvent.SRC_POCKET, String(pocket.type_id), pocket.uid, null)
	if trigger == &"on_pocket_score":
		if pocket.edition != &"":
			_fire_entry(
				&"on_edition",
				db.get_entry("editions", String(pocket.edition)),
				base,
				ScoreEvent.SRC_EDITION,
				String(pocket.edition),
				pocket.uid,
				null
			)
		if pocket.seal != &"":
			_fire_entry(
				&"on_seal", db.get_entry("seals", String(pocket.seal)), base, ScoreEvent.SRC_SEAL, String(pocket.seal), pocket.uid, null
			)


static func _fire_entry(
	trigger: StringName, def: Dictionary, base: EffectEnv, src_kind: StringName, src_id: String, src_uid: int, g: GrigriInstance
) -> void:
	if def.is_empty() or not def.has("effects"):
		return
	for eff_v: Variant in def["effects"]:
		var eff: Dictionary = eff_v as Dictionary
		if StringName(String(eff.get("trigger", ""))) != trigger:
			continue
		var env: EffectEnv = base.duplicate_env()
		env.source_kind = src_kind
		env.source_id = src_id
		env.source_uid = src_uid
		env.extra = base.extra.merged({"trigger": String(trigger)})
		if g != null:
			env.grigri = g
		run_effect(eff, env)


static func run_effect(eff: Dictionary, env: EffectEnv) -> bool:
	if not check_all(eff.get("if", []) as Array, env):
		return false
	var repeat: int = 1
	if eff.has("repeat"):
		repeat = maxi(int(value(eff["repeat"], env)), 0)
	for _r: int in repeat:
		for a: Variant in eff.get("do", []):
			apply(a as Dictionary, env)
	return true


# --------------------------------------------------------------------------- conditions


static func check_all(conds: Array, env: EffectEnv) -> bool:
	for c: Variant in conds:
		if not check(c as Dictionary, env):
			return false
	return true


static func check(cond: Dictionary, env: EffectEnv) -> bool:
	var name: StringName = StringName(String(cond.get("c", "")))
	var ctx: ScoreContext = env.ctx
	var p: Pocket = _target_pocket(env)
	match name:
		&"color":
			return p != null and _pocket_colors(env, p).has(StringName(String(cond.get("v", ""))))
		&"number_in":
			return p != null and _arr_has_int(cond.get("v", []) as Array, p.number)
		&"parity":
			if p == null or p.number == 0:
				return false
			return (p.number % 2 == 0) == (String(cond.get("v", "")) == "even")
		&"range":
			if p == null or p.number == 0:
				return false
			return WheelLayout.is_low(p.number) == (String(cond.get("v", "")) == "low")
		&"dozen":
			return p != null and WheelLayout.dozen_of(p.number) == int(cond.get("v", -2))
		&"is_zero":
			return ctx != null and ctx.is_zero
		&"pocket_type":
			return p != null and _match_str(cond.get("v", ""), String(p.type_id))
		&"pocket_has_edition":
			return p != null and p.edition != &""
		&"pocket_edition":
			return p != null and _match_str(cond.get("v", ""), String(p.edition))
		&"pocket_has_seal":
			return p != null and p.seal != &""
		&"bet_kind":
			var spot: BetSpot = BetCatalog.get_spot(ctx.current_bet) if ctx != null else null
			return spot != null and _match_str(cond.get("v", ""), String(spot.kind))
		&"bet_outside":
			var s2: BetSpot = BetCatalog.get_spot(ctx.current_bet) if ctx != null else null
			return s2 != null and s2.outside
		&"bet_inside":
			var s3: BetSpot = BetCatalog.get_spot(ctx.current_bet) if ctx != null else null
			return s3 != null and not s3.outside
		&"chance":
			var prob: float = float(value(cond.get("v", 0.0), env)) * _luck_factor(env)
			return env.run.rng.chance(RngStreams.EFFECTS, prob)
		&"deadline_kind":
			return _match_str(cond.get("v", ""), env.run.deadline_kind())
		&"is_creditor":
			return env.run.is_creditor()
		&"won_nothing":
			return ctx != null and ctx.bets_won.is_empty()
		&"number_repeat":
			return p != null and env.run.last_number == p.number
		&"near_miss":
			return ctx != null and ctx.near_miss
		&"flag":
			return bool(env.run.flags.get(String(cond.get("v", "")), false))
		&"first_pass":
			return ctx != null and ctx.pocket_pass <= 1
		&"in_zone":
			return ctx != null and ctx.throw_result != null and ctx.throw_result.in_zone
		&"attracted":
			return ctx != null and ctx.throw_result != null and ctx.throw_result.attracted_from >= 0
		&"neighbor_type":
			if ctx == null or ctx.landing_index < 0:
				return false
			for ni: int in env.run.wheel.neighbors(ctx.landing_index, int(cond.get("r", 1))):
				if _match_str(cond.get("v", ""), String(env.run.wheel.at(ni).type_id)):
					return true
			return false
		&"bet_covers_landing_neighbor":
			return ctx != null and ctx.near_miss
		&"not":
			return not check(cond.get("x", {}) as Dictionary, env)
		&"any":
			for sub: Variant in cond.get("x", []):
				if check(sub as Dictionary, env):
					return true
			return false
		&"last_spin":
			return env.run.spins_left <= 1
		&"first_spin":
			return env.run.spin_index <= 1
		&"has_grigri":
			return env.run.has_grigri(String(cond.get("v", "")))
		&"grigri_position":
			if env.grigri == null:
				return false
			var pos: int = env.run.grigris.find(env.grigri)
			var want: String = String(cond.get("v", "first"))
			return (want == "first" and pos == 0) or (want == "last" and pos == env.run.grigris.size() - 1)
	# Variable comparée
	var lhs: float = var_value(name, env, cond)
	var rhs: float = float(value(cond.get("v", 0), env))
	return compare(lhs, String(cond.get("op", CMP_DEFAULT)), rhs)


static func compare(a: float, op: String, b: float) -> bool:
	match op:
		">=":
			return a >= b
		">":
			return a > b
		"<=":
			return a <= b
		"<":
			return a < b
		"==":
			return is_equal_approx(a, b)
		"!=":
			return not is_equal_approx(a, b)
		"mod":
			return b != 0.0 and posmod(int(a), int(b)) == 0
	push_error("Opérateur de comparaison inconnu : %s" % op)
	return false


static func _match_str(v: Variant, actual: String) -> bool:
	if v is Array:
		for item: Variant in v:
			if String(item) == actual:
				return true
		return false
	return String(v) == actual


static func _arr_has_int(arr: Array, n: int) -> bool:
	for item: Variant in arr:
		if int(item) == n:
			return true
	return false


static func _target_pocket(env: EffectEnv) -> Pocket:
	if env.pocket != null:
		return env.pocket
	if env.ctx != null:
		return env.ctx.landing
	return null


static func _pocket_colors(env: EffectEnv, p: Pocket) -> Array[StringName]:
	if env.ctx != null and p == env.ctx.landing and not env.ctx.landing_colors.is_empty():
		return env.ctx.landing_colors
	var out: Array[StringName] = [p.color()]
	return out


static func _luck_factor(env: EffectEnv) -> float:
	return float(env.run.flags.get("luck_factor", 1.0))


# --------------------------------------------------------------------------- valeurs


static func value(v: Variant, env: EffectEnv) -> float:
	if v is float or v is int:
		return float(v)
	if v is Dictionary:
		var d: Dictionary = v as Dictionary
		var x: float = var_value(StringName(String(d.get("var", ""))), env, d)
		x = x * float(d.get("mul", 1.0)) + float(d.get("add", 0.0))
		if d.has("div") and float(d["div"]) != 0.0:
			x = floor(x / float(d["div"]))
		if d.has("min"):
			x = maxf(x, float(d["min"]))
		if d.has("max"):
			x = minf(x, float(d["max"]))
		return x
	if v is String and String(v).is_valid_float():
		return String(v).to_float()
	return 0.0


static func var_value(name: StringName, env: EffectEnv, params: Dictionary = {}) -> float:
	var run: RunState = env.run
	var ctx: ScoreContext = env.ctx
	var p: Pocket = _target_pocket(env)
	match name:
		&"counter":
			if env.grigri != null:
				return env.grigri.counter
			return p.counter if p != null else 0.0
		&"money":
			return float(run.money)
		&"grigri_count":
			return float(run.grigris.size())
		&"empty_slots":
			return float(run.empty_grigri_slots())
		&"spins_left":
			return float(run.spins_left)
		&"spin_index":
			return float(run.spin_index)
		&"pocket_number":
			return float(p.number) if p != null else 0.0
		&"pocket_level":
			return float(p.level) if p != null else 0.0
		&"color_streak":
			return float(run.color_streak)
		&"bets_won":
			return float(ctx.bets_won.size()) if ctx != null else 0.0
		&"bets_lost":
			return float(ctx.bets_lost.size()) if ctx != null else 0.0
		&"bets_placed":
			return float(ctx.slip.size()) if ctx != null else float(run.slip.order.size())
		&"distinct_kinds":
			return float(run.slip.distinct_kinds())
		&"chips_staked":
			return float(run.slip.total())
		&"unused_budget":
			return float(run.slip.remaining())
		&"tier":
			return float(run.tier)
		&"act":
			return float(run.act())
		&"deadline_index":
			return float(run.deadline_idx)
		&"wheel_size":
			return float(run.wheel.size())
		&"type_count":
			return float(run.wheel.count_type(StringName(String(params.get("t", "standard")))))
		&"number_count":
			return float(run.wheel.count_number(int(params.get("n", 0))))
		&"edition_pockets":
			return float(run.wheel.count_with_edition())
		&"cursed_count":
			return float(_count_rarity(env, "cursed"))
		&"rare_count":
			return float(_count_rarity(env, "rare"))
		&"common_count":
			return float(_count_rarity(env, "common"))
		&"legendary_count":
			return float(_count_rarity(env, "legendary"))
		&"fortune_count":
			return float(run.fortunes.size())
		&"contract_count":
			return float(run.contracts.size())
		&"chip_value":
			return float(run.chip_value)
		&"bet_budget":
			return float(run.bet_budget)
		&"precision":
			return float(run.precision)
		&"chips":
			return ctx.chips if ctx != null else 0.0
		&"mult":
			return ctx.mult() if ctx != null else 0.0
		&"win_chips":
			return ctx.current_bet_win if ctx != null else 0.0
		&"bet_chips":
			return float(ctx.slip.get(ctx.current_bet, 0)) if ctx != null else 0.0
		&"rerolls":
			return float(run.shop_rerolls)
		&"sold_count":
			return float(run.sold_count)
		&"zero_count":
			return float(run.zeros_hit)
		&"total_spins":
			return float(run.total_spins)
		&"deadline_score":
			return float(run.deadline_score)
		&"debt":
			return float(run.debt)
		&"pacts_used":
			var pacts: int = 0
			for pv: Variant in run.pacts_used.values():
				pacts += int(pv)
			return float(pacts)
		&"debt_progress":
			return float(run.deadline_score) / maxf(float(run.debt), 1.0)
	push_error("Variable d'effet inconnue : %s" % name)
	return 0.0


static func _count_rarity(env: EffectEnv, rarity: String) -> int:
	var c: int = 0
	for g: GrigriInstance in env.run.grigris:
		if String(env.db.get_entry("grigris", g.id).get("rarity", "")) == rarity:
			c += 1
	return c


# --------------------------------------------------------------------------- actions


static func apply(a: Dictionary, env: EffectEnv) -> void:
	var op: StringName = StringName(String(a.get("op", "")))
	var run: RunState = env.run
	var ctx: ScoreContext = env.ctx
	var v: float = value(a.get("v", 0), env)
	var label: String = String(a.get("label", ""))
	# Contributions nulles : aucun effet, aucun bruit à l'écran (« +0 Mult »).
	if (op in [&"add_chips", &"add_mult"] and is_zero_approx(v)) or (op == &"mul_mult" and is_equal_approx(v, 1.0)):
		return
	match op:
		&"add_chips":
			if ctx != null:
				ctx.chips += v
				_emit(env, ScoreEvent.CHIPS, v, label)
		&"add_mult":
			if ctx != null:
				ctx.mult_add += v
				_emit(env, ScoreEvent.MULT_ADD, v, label)
		&"mul_mult":
			if ctx != null:
				ctx.mult_mul *= v
				_emit(env, ScoreEvent.MULT_MUL, v, label)
		&"add_money":
			var delta: int = maxi(int(v), -run.money)
			run.money += delta
			if ctx != null:
				ctx.money_delta += delta
			if delta != 0:
				_emit(env, ScoreEvent.MONEY, float(delta), label)
		&"counter_add":
			_set_counter(env, _get_counter(env) + v)
			_emit(env, ScoreEvent.COUNTER, _get_counter(env), label)
		&"counter_set":
			_set_counter(env, v)
		&"counter_mul":
			_set_counter(env, _get_counter(env) * v)
			_emit(env, ScoreEvent.COUNTER, _get_counter(env), label)
		&"add_spins":
			run.spins_left = maxi(run.spins_left + int(v), 0)
			_emit(env, ScoreEvent.SPINS, v, label)
		&"add_fortune_slot":
			run.fortune_slots = maxi(run.fortune_slots + int(v), 0)
		&"add_extra_spins":
			run.extra_spins_per_deadline += int(v)
		&"temp_budget":
			run.temp_budget_bonus += int(v)
			_emit(env, ScoreEvent.INFO, v, label if label != "" else "budget_up")
		&"perm_budget":
			run.bet_budget += int(v)
		&"perm_chip_value":
			run.chip_value = maxi(run.chip_value + int(v), 1)
		&"perm_precision":
			run.precision = clampi(run.precision + int(v), 1, Balance.i("throw.max_precision"))
		&"temp_precision":
			run.temp_precision_bonus += int(v)
			_emit(env, ScoreEvent.INFO, v, label if label != "" else ("precision_up" if v > 0.0 else "precision_down"))
		&"perm_control":
			run.control_bonus += v
		&"add_slot":
			run.grigri_slots = mini(run.grigri_slots + int(v), Balance.i("slots.grigri_slots_max"))
		&"table_limit":
			run.table_limit_bonus += int(v)
		&"shop_discount":
			run.shop_discount += int(v)
		&"interest_cap":
			run.interest_cap_bonus += int(v)
		&"add_rethrow":
			run.free_rethrows += int(v)
		&"retrigger_pocket":
			if ctx != null:
				ctx.pocket_retriggers += int(v)
				_emit(env, ScoreEvent.INFO, v, label if label != "" else "retrigger")
		&"retrigger_bets":
			if ctx != null:
				ctx.bet_retriggers += int(v)
				_emit(env, ScoreEvent.INFO, v, label if label != "" else "retrigger")
		&"multiply_win":
			if ctx != null and ctx.current_bet != "":
				var extra_chips: float = ctx.current_bet_win * (v - 1.0)
				ctx.chips += extra_chips
				_emit(env, ScoreEvent.CHIPS, extra_chips, label)
		&"steal_chips":
			if ctx != null:
				var stolen: float = v * float(run.chip_value)
				ctx.chips += stolen
				_emit(env, ScoreEvent.CHIPS, stolen, label if label != "" else "steal")
		&"refund_lost":
			if ctx != null:
				var refund: float = 0.0
				for bid: String in ctx.bets_lost:
					refund += float(ctx.slip.get(bid, 0)) * float(run.chip_value) * v
				ctx.chips += refund
				_emit(env, ScoreEvent.CHIPS, refund, label)
		&"self_destroy":
			if env.grigri != null:
				run.grigris.erase(env.grigri)
				_emit(env, ScoreEvent.DESTROY, 0.0, label)
		&"chance_destroy_pocket", &"destroy_pocket":
			var idx: int = _pocket_index(env)
			if idx >= 0 and (op == &"destroy_pocket" or run.rng.chance(RngStreams.EFFECTS, v)):
				if run.wheel.remove_at(idx):
					_emit(env, ScoreEvent.DESTROY, 0.0, label if label != "" else "pocket_destroyed")
					if ctx != null and ctx.landing_index == idx:
						ctx.landing_index = -1
		&"burn_random_pocket":
			var ri: int = run.rng.randi_range_in(RngStreams.EFFECTS, 0, run.wheel.size() - 1)
			var target_type: String = String(a.get("type", "burnt"))
			run.wheel.at(ri).type_id = StringName(target_type)
			run.wheel.at(ri).edition = &""
			_emit(env, ScoreEvent.TRANSFORM, float(run.wheel.at(ri).number), label if label != "" else "burn")
		&"transform_pocket":
			var p: Pocket = _target_pocket(env)
			if p != null:
				p.type_id = StringName(String(a.get("type", "standard")))
				_emit(env, ScoreEvent.TRANSFORM, float(p.number), label)
		&"randomize_pocket":
			var p2: Pocket = _target_pocket(env)
			if p2 != null:
				p2.number = run.rng.randi_range_in(RngStreams.EFFECTS, 0, WheelLayout.POCKET_COUNT - 1)
				_emit(env, ScoreEvent.TRANSFORM, float(p2.number), label)
		&"set_pocket_edition":
			var p3: Pocket = _target_pocket(env)
			if p3 != null:
				p3.edition = StringName(String(a.get("edition", "")))
				_emit(env, ScoreEvent.TRANSFORM, float(p3.number), label)
		&"set_pocket_seal":
			var p4: Pocket = _target_pocket(env)
			if p4 != null:
				p4.seal = StringName(String(a.get("seal", "")))
				_emit(env, ScoreEvent.TRANSFORM, float(p4.number), label)
		&"add_random_seal":
			var seals: Array[String] = env.db.ids("seals")
			if not seals.is_empty():
				var target: Pocket = run.wheel.at(run.rng.randi_range_in(RngStreams.EFFECTS, 0, run.wheel.size() - 1))
				target.seal = StringName(seals[run.rng.randi_range_in(RngStreams.EFFECTS, 0, seals.size() - 1)])
				_emit(env, ScoreEvent.TRANSFORM, float(target.number), label)
		&"upgrade_pocket":
			var p5: Pocket = _target_pocket(env)
			if p5 != null:
				p5.level += maxi(int(v), 1)
				_emit(env, ScoreEvent.TRANSFORM, float(p5.number), label)
		&"add_pocket_copy":
			var idx2: int = _pocket_index(env)
			if idx2 >= 0:
				run.wheel.insert_copy(idx2, run.wheel.at(idx2))
				_emit(env, ScoreEvent.TRANSFORM, float(run.wheel.at(idx2).number), label)
		&"add_fortune":
			_add_fortune(env, String(a.get("id", "random")))
		&"add_grigri":
			if run.empty_grigri_slots() > 0:
				var gid: String = _pick_grigri(env, String(a.get("id", "")), String(a.get("rarity", "common")))
				if gid != "":
					run.add_grigri(gid)
					_emit(env, ScoreEvent.INFO, 0.0, gid)
		&"add_random_edition_grigri":
			var plain: Array[GrigriInstance] = []
			for g: GrigriInstance in run.grigris:
				if g.edition == &"":
					plain.append(g)
			if not plain.is_empty():
				var eds: Array[String] = env.db.ids("editions")
				var pick: GrigriInstance = plain[run.rng.randi_range_in(RngStreams.EFFECTS, 0, plain.size() - 1)]
				pick.edition = StringName(eds[run.rng.randi_range_in(RngStreams.EFFECTS, 0, eds.size() - 1)])
		&"destroy_random_grigri":
			var candidates: Array[GrigriInstance] = []
			for g2: GrigriInstance in run.grigris:
				if g2 != env.grigri and not g2.locked:
					candidates.append(g2)
			if not candidates.is_empty():
				var victim: GrigriInstance = candidates[run.rng.randi_range_in(RngStreams.EFFECTS, 0, candidates.size() - 1)]
				run.grigris.erase(victim)
				_emit(env, ScoreEvent.DESTROY, 0.0, victim.id)
		&"disable_random_grigri":
			var active: Array[GrigriInstance] = []
			for g3: GrigriInstance in run.grigris:
				if not g3.disabled:
					active.append(g3)
			if not active.is_empty():
				active[run.rng.randi_range_in(RngStreams.EFFECTS, 0, active.size() - 1)].disabled = true
		&"debt_add_pct":
			run.debt = maxi(int(round(float(run.debt) * (1.0 + v))), 1)
			_emit(env, ScoreEvent.INFO, v, label if label != "" else "debt")
		&"debt_add":
			run.debt = maxi(run.debt + int(v), 1)
		&"next_debt_pct":
			run.flags["next_debt_pct"] = float(run.flags.get("next_debt_pct", 0.0)) + v
		&"protect_zero":
			if ctx != null:
				ctx.zero_protected = true
				_emit(env, ScoreEvent.INFO, 0.0, label if label != "" else "zero_protected")
		&"house_tax_add":
			if ctx != null:
				ctx.house_tax += int(v)
		&"ban_random_color":
			var colors: Array[StringName] = [WheelLayout.COLOR_RED, WheelLayout.COLOR_BLACK]
			run.banned_color = colors[run.rng.randi_range_in(RngStreams.EFFECTS, 0, 1)]
		&"sell_bonus":
			if env.grigri != null:
				env.grigri.sell_bonus += int(v)
		&"set_flag":
			run.flags[String(a.get("flag", ""))] = a.get("value", true)
		&"copy_right", &"copy_left":
			_copy_neighbor(env, 1 if op == &"copy_right" else -1)
		&"message":
			_emit(env, ScoreEvent.INFO, v, label)
		_:
			push_error("Action d'effet inconnue : %s" % op)


static func _emit(env: EffectEnv, kind: StringName, amount: float, label: String) -> void:
	if env.ctx != null:
		env.ctx.push(kind, env.source_kind, env.source_id, amount, label, env.source_uid)


static func _get_counter(env: EffectEnv) -> float:
	if env.grigri != null:
		return env.grigri.counter
	var p: Pocket = _target_pocket(env)
	return p.counter if p != null else 0.0


static func _set_counter(env: EffectEnv, v: float) -> void:
	if env.grigri != null:
		env.grigri.counter = v
		return
	var p: Pocket = _target_pocket(env)
	if p != null:
		p.counter = v


static func _pocket_index(env: EffectEnv) -> int:
	if env.pocket_index >= 0:
		return env.pocket_index
	if env.ctx != null:
		return env.ctx.landing_index
	return -1


static func _add_fortune(env: EffectEnv, fid: String) -> void:
	var run: RunState = env.run
	if run.fortunes.size() >= run.fortune_slots:
		return
	var chosen: String = fid
	if fid == "random":
		var all_ids: Array[String] = env.db.ids("fortunes")
		if all_ids.is_empty():
			return
		chosen = all_ids[run.rng.randi_range_in(RngStreams.EFFECTS, 0, all_ids.size() - 1)]
	run.fortunes.append(chosen)
	_emit(env, ScoreEvent.INFO, 0.0, chosen)


static func _pick_grigri(env: EffectEnv, gid: String, rarity: String) -> String:
	if gid != "":
		return gid
	var pool: Array[String] = []
	for e: Dictionary in env.db.list("grigris"):
		if String(e.get("rarity", "")) == rarity and not env.run.has_grigri(String(e["id"])):
			pool.append(String(e["id"]))
	if pool.is_empty():
		return ""
	return pool[env.run.rng.randi_range_in(RngStreams.EFFECTS, 0, pool.size() - 1)]


## Rejoue les effets du grigri voisin (droite/gauche) pour le déclencheur courant.
static func _copy_neighbor(env: EffectEnv, direction: int) -> void:
	if env.grigri == null or env.depth >= MAX_DEPTH:
		return
	var trig: StringName = StringName(String(env.extra.get("trigger", "on_score_calc")))
	var pos: int = env.run.grigris.find(env.grigri)
	var other_pos: int = pos + direction
	if pos < 0 or other_pos < 0 or other_pos >= env.run.grigris.size():
		return
	var other: GrigriInstance = env.run.grigris[other_pos]
	var def: Dictionary = env.db.get_entry("grigris", other.id)
	if bool(def.get("no_copy", false)):
		return
	for eff_v: Variant in def.get("effects", []):
		var eff: Dictionary = eff_v as Dictionary
		if StringName(String(eff.get("trigger", ""))) != trig:
			continue
		var sub: EffectEnv = env.duplicate_env()
		sub.depth = env.depth + 1
		sub.grigri = other
		run_effect(eff, sub)
