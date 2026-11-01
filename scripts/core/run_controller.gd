class_name RunController
extends RefCounted
## Orchestration pure d'un run (aucun Node) : utilisée par le jeu ET par le simulateur.
## Paliers → Échéances (Petite, Grande, Créancier) → Tours (paris, lancer, score).

## Drapeaux posés par les créanciers, remis à zéro à chaque nouvelle échéance.
const CREDITOR_FLAGS: Array[String] = ["hide_odds", "control_temp", "zone_width_override"]


class SpinOutcome:
	extends RefCounted
	var throw_result: ThrowResolver.ThrowResult = null
	var ctx: ScoreContext = null
	var deadline_won: bool = false
	var deadline_failed: bool = false
	var forgiven: bool = false
	var reward: Dictionary = {}
	var victory: bool = false


var run: RunState = null
var db: ContentDB = null
var pending_throw: ThrowResolver.ThrowResult = null
## Premier run guidé (positionné avant new_run).
var tutorial_run: bool = false
var _spin_started: bool = false


func _init(p_db: ContentDB = null) -> void:
	db = p_db if p_db != null else ContentDB.shared()


# --------------------------------------------------------------------------- création


func new_run(character_id: String, risk_level: int, seed_value: int, challenge_id: String = "") -> RunState:
	run = RunState.new()
	run.rng.reseed(seed_value)
	run.character_id = character_id
	run.risk_level = risk_level
	run.challenge_id = challenge_id
	run.money = Balance.i("economy.start_money")
	run.bet_budget = Balance.i("bets.bet_budget")
	run.chip_value = Balance.i("bets.chip_value")
	run.precision = Balance.i("throw.base_precision")
	run.grigri_slots = Balance.i("slots.grigri_slots")
	run.fortune_slots = Balance.i("slots.fortune_slots")
	run.wheel = WheelModel.standard()
	if tutorial_run:
		run.flags["tutorial_run"] = true
	_apply_setup(db.get_entry("characters", character_id))
	if challenge_id != "" and db.get_entry("challenges", challenge_id).has("risk"):
		run.risk_level = int(db.get_entry("challenges", challenge_id)["risk"])
	_apply_risks()
	if challenge_id != "":
		var ch: Dictionary = db.get_entry("challenges", challenge_id)
		_apply_setup(ch)
		if ch.has("risk"):
			run.risk_level = int(ch["risk"])
	_plan_creditors()
	EffectRunner.fire(&"on_run_start", run, null, db)
	start_deadline()
	return run


func load_run(state: RunState) -> void:
	run = state
	pending_throw = null
	_spin_started = false
	if run.phase == RunState.Phase.BETTING:
		_configure_slip(false)


## Applique un bloc "setup" (personnage, défi, risque) : stats, roue, grigris, drapeaux.
func _apply_setup(def: Dictionary) -> void:
	if def.is_empty():
		return
	var setup: Dictionary = def.get("setup", {})
	var stats: Dictionary = setup.get("stats", {})
	run.money += int(stats.get("money", 0))
	run.bet_budget += int(stats.get("bet_budget", 0))
	run.chip_value += int(stats.get("chip_value", 0))
	run.precision = clampi(run.precision + int(stats.get("precision", 0)), 1, Balance.i("throw.max_precision"))
	run.grigri_slots += int(stats.get("grigri_slots", 0))
	run.fortune_slots += int(stats.get("fortune_slots", 0))
	run.extra_spins_per_deadline += int(stats.get("spins", 0))
	run.control_bonus += float(stats.get("control", 0.0))
	for op_v: Variant in setup.get("wheel", []):
		_apply_wheel_op(op_v as Dictionary)
	for gid: Variant in setup.get("grigris", []):
		run.add_grigri(String(gid))
	for fid: Variant in setup.get("fortunes", []):
		if run.fortunes.size() < run.fortune_slots:
			run.fortunes.append(String(fid))
	var flags: Dictionary = setup.get("flags", {})
	for k: Variant in flags.keys():
		run.flags[String(k)] = flags[k]


func _apply_wheel_op(op: Dictionary) -> void:
	var nums: Array = []
	var raw: Variant = op.get("numbers", [])
	if raw is String and String(raw) == "all":
		for n: int in WheelLayout.POCKET_COUNT:
			nums.append(n)
	elif raw is Array:
		nums = raw as Array
	match String(op.get("op", "")):
		"set_type":
			for n: Variant in nums:
				var idx: int = run.wheel.first_index_of_number(int(n))
				if idx >= 0:
					run.wheel.at(idx).type_id = StringName(String(op.get("type", "standard")))
		"set_edition":
			for n2: Variant in nums:
				var idx2: int = run.wheel.first_index_of_number(int(n2))
				if idx2 >= 0:
					run.wheel.at(idx2).edition = StringName(String(op.get("edition", "")))
		"add":
			for n3: Variant in nums:
				var at: int = run.wheel.first_index_of_number(int(n3))
				var p: Pocket = run.wheel.insert_number(maxi(at, 0), int(n3))
				p.type_id = StringName(String(op.get("type", "standard")))
		"remove":
			for n4: Variant in nums:
				var idx4: int = run.wheel.first_index_of_number(int(n4))
				if idx4 >= 0:
					run.wheel.remove_at(idx4)
		"random_type":
			var count: int = int(op.get("count", 1))
			for _i: int in count:
				var ri: int = run.rng.randi_range_in(RngStreams.EFFECTS, 1, run.wheel.size() - 1)
				run.wheel.at(ri).type_id = StringName(String(op.get("type", "standard")))


## Niveaux de Risque cumulatifs : chaque niveau <= risk_level applique son setup et ses effets.
func _apply_risks() -> void:
	var active: Array = []
	for e: Dictionary in db.list("risks"):
		if int(e.get("level", 0)) <= run.risk_level and int(e.get("level", 0)) > 0:
			_apply_setup(e)
			if e.has("effects"):
				active.append(String(e["id"]))
	if not active.is_empty():
		run.flags["risk_effects"] = active


## Attribue un créancier à chaque palier (déterministe, flux events).
func _plan_creditors() -> void:
	var plan: Array = []
	var used: Array[String] = []
	for t: int in range(1, Balance.i("run.tiers") + 1):
		var pool: Array[String] = []
		for e: Dictionary in db.list("creditors"):
			var cid: String = String(e["id"])
			if used.has(cid) or bool(e.get("secret", false)):
				continue
			if int(e.get("tier_min", 1)) <= t and int(e.get("tier_max", 99)) >= t:
				pool.append(cid)
		if pool.is_empty():
			plan.append("")
			continue
		var pick: String = pool[run.rng.randi_range_in(RngStreams.EVENTS, 0, pool.size() - 1)]
		used.append(pick)
		plan.append(pick)
	run.flags["creditor_plan"] = plan


# --------------------------------------------------------------------------- échéances


func debt_for(tier: int, deadline_idx: int) -> int:
	var debts: Array = Balance.arr("run.tier_debts")
	var base: float
	if tier <= debts.size():
		base = float(debts[tier - 1])
	else:
		base = float(debts[debts.size() - 1]) * pow(Balance.f("run.endless_debt_growth"), float(tier - debts.size()))
	var m: float = float(Balance.arr("run.deadline_multipliers")[deadline_idx])
	m *= float(run.flags.get("debt_mult", 1.0))
	if bool(run.flags.get("tutorial_run", false)) and tier <= Balance.i("run.tutorial_tiers"):
		m *= Balance.f("run.tutorial_debt_mult")
	if deadline_idx == Balance.arr("run.deadline_kinds").size() - 1 and run.creditor_id != "":
		m *= float(db.get_entry("creditors", run.creditor_id).get("debt_mult", 1.0))
	return int(round(base * m))


func start_deadline() -> void:
	for f: String in CREDITOR_FLAGS:
		run.flags.erase(f)
	run.creditor_id = ""
	run.creditor_phase = 0
	if run.is_creditor():
		var plan: Array = run.flags.get("creditor_plan", [])
		var override_key: String = "creditor_override_%d" % run.tier
		if run.flags.has(override_key):
			run.creditor_id = String(run.flags[override_key])
		elif run.endless and run.tier == Balance.i("run.tiers") + 1:
			run.creditor_id = "cr_croupier_or"
		elif run.tier - 1 < plan.size():
			run.creditor_id = String(plan[run.tier - 1])
		elif not plan.is_empty():
			run.creditor_id = String(plan[run.rng.randi_range_in(RngStreams.EVENTS, 0, plan.size() - 1)])
	run.debt = debt_for(run.tier, run.deadline_idx)
	if run.flags.has("next_debt_pct"):
		run.debt = maxi(int(round(float(run.debt) * (1.0 + float(run.flags["next_debt_pct"])))), 1)
		run.flags.erase("next_debt_pct")
	run.spins_total = maxi(Balance.i("run.spins_per_deadline") + run.extra_spins_per_deadline + int(run.flags.get("spins_mod", 0)), 1)
	run.spins_left = run.spins_total
	run.spin_index = 0
	run.deadline_score = 0
	run.free_rethrows = int(run.flags.get("rethrows_per_deadline", 0))
	for g: GrigriInstance in run.grigris:
		g.disabled = false
	run.allowed_kinds.clear()
	if run.creditor_id != "":
		var cdef: Dictionary = db.get_entry("creditors", run.creditor_id)
		for k: Variant in cdef.get("allowed_kinds", []):
			run.allowed_kinds.append(StringName(String(k)))
	if run.allowed_kinds.is_empty():
		for k2: Variant in run.flags.get("allowed_kinds_always", []):
			run.allowed_kinds.append(StringName(String(k2)))
	EffectRunner.fire(&"on_deadline_start", run, null, db)
	# Les malus cumulés (risque, créancier, défi) ne peuvent pas supprimer le dernier tour.
	run.spins_left = maxi(run.spins_left, Balance.i("run.min_spins"))
	begin_betting()


func begin_betting() -> void:
	run.phase = RunState.Phase.BETTING
	run.banned_color = &""
	_spin_started = false
	pending_throw = null
	EffectRunner.fire(&"on_bet_phase", run, null, db)
	_configure_slip(true)


func _configure_slip(clear: bool) -> void:
	var keep: Dictionary = run.slip.snapshot()
	run.slip.clear()
	run.slip.budget = maxi(run.bet_budget + run.temp_budget_bonus, 1)
	run.slip.table_limit_bonus = run.table_limit_bonus
	run.slip.allowed_kinds = run.allowed_kinds.duplicate()
	run.slip.banned_spots.clear()
	if run.banned_color != &"":
		run.slip.banned_spots.append(String(run.banned_color))
	# Garde-fou anti-blocage : des règles cumulées ne doivent jamais interdire tout pari.
	if not _any_bet_possible():
		run.slip.banned_spots.clear()
		run.banned_color = &""
	if not _any_bet_possible():
		run.slip.allowed_kinds.clear()
	if not clear:
		run.slip.apply_layout(keep)


func _any_bet_possible() -> bool:
	if run.slip.budget <= 0:
		return false
	for spot: BetSpot in BetCatalog.all():
		if run.slip.allowed_kinds.is_empty() or run.slip.allowed_kinds.has(spot.kind):
			if not run.slip.banned_spots.has(spot.id):
				return true
	return false


## Les créanciers qui interdisent une couleur le font au début de chaque tour (effet on_bet_phase).
func refresh_bans() -> void:
	_configure_slip(false)


# --------------------------------------------------------------------------- paris


func place_bet(spot_id: String, amount: int = 1) -> BetSlip.PlaceResult:
	if run.phase != RunState.Phase.BETTING or pending_throw != null:
		return BetSlip.PlaceResult.FORBIDDEN
	var r: BetSlip.PlaceResult = run.slip.place(spot_id, amount)
	if r == BetSlip.PlaceResult.OK:
		EffectRunner.fire(&"on_bet_placed", run, null, db, {"spot": spot_id})
	return r


func repeat_last() -> int:
	if run.phase != RunState.Phase.BETTING:
		return 0
	run.slip.clear()
	return run.slip.apply_layout(run.last_layout)


## Pose au moins un jeton sur le premier emplacement autorisé (bots, filet de sécurité).
func ensure_some_bet() -> bool:
	if not run.slip.is_empty():
		return true
	for spot: BetSpot in BetCatalog.all():
		if run.slip.check(spot.id) == BetSlip.PlaceResult.OK:
			return place_bet(spot.id) == BetSlip.PlaceResult.OK
	return false


func can_spin() -> bool:
	return run.phase == RunState.Phase.BETTING and not run.slip.is_empty()


# --------------------------------------------------------------------------- lancer


func effective_precision() -> int:
	return clampi(run.precision + run.temp_precision_bonus, 1, Balance.i("throw.max_precision"))


func throw_params(target_index: int) -> ThrowResolver.ThrowParams:
	var p: ThrowResolver.ThrowParams = ThrowResolver.ThrowParams.new()
	p.target_index = target_index
	p.precision = effective_precision()
	p.control_bonus = run.control_bonus + float(run.flags.get("control_temp", 0.0))
	p.zone_width_override = int(run.flags.get("zone_width_override", 0))
	p.last_landing_index = run.last_landing_index
	for i: int in run.wheel.size():
		var def: Dictionary = db.get_entry("pocket_types", String(run.wheel.at(i).type_id))
		if def.has("attract"):
			p.attractors[i] = float(def["attract"])
	if run.sticky_index >= 0 and run.sticky_index < run.wheel.size():
		var sdef: Dictionary = db.get_entry("pocket_types", String(run.wheel.at(run.sticky_index).type_id))
		if sdef.has("sticky"):
			p.sticky_index = run.sticky_index
			p.sticky_chance = float(sdef["sticky"])
	return p


func landing_distribution(target_index: int) -> Array[float]:
	return ThrowResolver.distribution(run.wheel.size(), throw_params(target_index))


## Étape 1 : la bille est lancée ; le résultat est tiré immédiatement.
func throw_ball(target_index: int) -> ThrowResolver.ThrowResult:
	assert(can_spin(), "throw_ball hors phase de paris")
	if not _spin_started:
		_spin_started = true
		run.spin_index += 1
		EffectRunner.fire(&"on_spin_start", run, null, db)
	pending_throw = ThrowResolver.resolve(run.wheel.size(), throw_params(target_index), run.rng)
	return pending_throw


func can_rethrow() -> bool:
	return pending_throw != null and run.free_rethrows > 0


## Relance gratuite (Léa) : avant le calcul du score, uniquement.
func rethrow(target_index: int) -> ThrowResolver.ThrowResult:
	assert(can_rethrow(), "relance indisponible")
	run.free_rethrows -= 1
	pending_throw = ThrowResolver.resolve(run.wheel.size(), throw_params(target_index), run.rng)
	return pending_throw


## Étape 2 : calcul du score et fin de tour.
func commit_spin() -> SpinOutcome:
	assert(pending_throw != null, "commit_spin sans lancer")
	var out: SpinOutcome = SpinOutcome.new()
	out.throw_result = pending_throw
	# Les bonus temporaires ont été consommés (budget à la pose, précision au lancer).
	run.temp_budget_bonus = 0
	run.temp_precision_bonus = 0
	var ctx: ScoreContext = ScoreEngine.resolve(run, db, pending_throw)
	out.ctx = ctx
	pending_throw = null
	_finish_spin(ctx, out)
	return out


func spin(target_index: int) -> SpinOutcome:
	throw_ball(target_index)
	return commit_spin()


func _finish_spin(ctx: ScoreContext, out: SpinOutcome) -> void:
	run.deadline_score += ctx.total
	run.total_spins += 1
	run.best_spin = maxi(run.best_spin, ctx.total)
	if bool(run.flags.get("forgive_first_loss_per_tier", false)) and ctx.bets_won.is_empty() and run.losses_forgiven_tier != run.tier:
		run.losses_forgiven_tier = run.tier
		out.forgiven = true
	else:
		run.spins_left = maxi(run.spins_left - 1, 0)
	run.last_layout = ctx.slip.duplicate()
	var landed: Pocket = ctx.landing
	run.last_landing_index = ctx.landing_index
	var ldef: Dictionary = db.get_entry("pocket_types", String(landed.type_id))
	run.sticky_index = ctx.landing_index if ldef.has("sticky") else -1
	(
		run
		. push_history(
			{
				"n": landed.number,
				"c": String(ctx.landing_colors[0]),
				"score": ctx.total,
				"won": ctx.bets_won.size(),
				"lost": ctx.bets_lost.size(),
				"tier": run.tier,
				"deadline": run.deadline_idx,
				"type": String(landed.type_id),
			}
		)
	)
	_update_creditor_phase()
	if run.deadline_score >= run.debt:
		out.deadline_won = true
		out.reward = _deadline_won()
		out.victory = run.phase == RunState.Phase.VICTORY
	elif run.spins_left <= 0:
		out.deadline_failed = true
		_deadline_failed()
	else:
		begin_betting()


func _update_creditor_phase() -> void:
	if run.creditor_id == "":
		return
	var phases: Array = db.get_entry("creditors", run.creditor_id).get("phases", [])
	if phases.is_empty():
		return
	var progress: float = float(run.deadline_score) / maxf(float(run.debt), 1.0)
	run.creditor_phase = clampi(int(progress * float(phases.size())), 0, phases.size() - 1)


func _deadline_won() -> Dictionary:
	EffectRunner.fire(&"on_deadline_end", run, null, db)
	var reward: Dictionary = compute_reward()
	run.money += int(reward["total"])
	run.deadlines_cleared += 1
	(
		run
		. deadline_log
		. append(
			{
				"tier": run.tier,
				"deadline": run.deadline_idx,
				"score": run.deadline_score,
				"debt": run.debt,
				"spins_used": run.spins_total - run.spins_left,
				"won": true,
			}
		)
	)
	var prev_act: int = run.act()
	run.deadline_idx += 1
	if run.deadline_idx >= Balance.arr("run.deadline_kinds").size():
		run.deadline_idx = 0
		run.tier += 1
		if run.tier > Balance.i("run.tiers") and not run.endless:
			run.phase = RunState.Phase.VICTORY
			return reward
	if run.act() != prev_act:
		run.flags["act_changed"] = true
	elif run.deadline_idx == 0 and run.rng.chance(RngStreams.EVENTS, Balance.f("run.event_chance_per_tier")):
		run.flags["event_due"] = true
	ShopModel.enter(run, db)
	return reward


func compute_reward() -> Dictionary:
	var base: int = int(Balance.arr("economy.deadline_rewards")[run.deadline_idx])
	var spins_bonus: int = maxi(run.spins_left, 0) * Balance.i("economy.money_per_unused_spin")
	var cap: int = Balance.i("economy.interest_cap") + run.interest_cap_bonus
	var interest: int = mini(run.money / Balance.i("economy.interest_step") * Balance.i("economy.interest_per_step"), cap)
	if bool(run.flags.get("no_interest", false)):
		interest = 0
	return {"base": base, "spins": spins_bonus, "interest": interest, "total": base + spins_bonus + interest}


func _deadline_failed() -> void:
	var used: int = int(run.pacts_used.get(str(run.act()), 0))
	if used < Balance.i("pact.max_per_act") and not bool(run.flags.get("no_pact", false)):
		run.phase = RunState.Phase.PACT_OFFER
	else:
		_game_over()


func _game_over() -> void:
	run.phase = RunState.Phase.GAME_OVER
	(
		run
		. deadline_log
		. append(
			{
				"tier": run.tier,
				"deadline": run.deadline_idx,
				"score": run.deadline_score,
				"debt": run.debt,
				"spins_used": run.spins_total,
				"won": false,
			}
		)
	)
	run.defeat_reason = "debt_missed"


# --------------------------------------------------------------------------- pacte


## Options de sacrifice proposées par La Maison.
func pact_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var unlocked: Array[GrigriInstance] = []
	for g: GrigriInstance in run.grigris:
		if not g.locked:
			unlocked.append(g)
	if not unlocked.is_empty():
		out.append({"kind": "grigri", "uid": unlocked[unlocked.size() - 1].uid})
	if run.wheel.can_remove():
		out.append({"kind": "pocket"})
	if run.bet_budget > Balance.i("pact.budget_sacrifice"):
		out.append({"kind": "budget", "amount": Balance.i("pact.budget_sacrifice")})
	return out


func accept_pact(option: Dictionary) -> bool:
	if run.phase != RunState.Phase.PACT_OFFER:
		return false
	match String(option.get("kind", "")):
		"grigri":
			var g: GrigriInstance = run.grigri_by_uid(int(option.get("uid", -1)))
			if g == null:
				return false
			run.grigris.erase(g)
		"pocket":
			# La Maison prend la case la plus précieuse (niveau / édition / type spécial).
			var best: int = 0
			var best_score: int = -1
			for i: int in run.wheel.size():
				var p: Pocket = run.wheel.at(i)
				var s: int = p.level * 2 + (3 if p.edition != &"" else 0) + (2 if p.type_id != Pocket.TYPE_STANDARD else 0)
				if s > best_score:
					best_score = s
					best = i
			run.wheel.remove_at(best)
		"budget":
			run.bet_budget -= int(option.get("amount", 0))
		_:
			return false
	var key: String = str(run.act())
	run.pacts_used[key] = int(run.pacts_used.get(key, 0)) + 1
	run.spins_left += Balance.i("pact.extra_spins")
	begin_betting()
	return true


func decline_pact() -> void:
	if run.phase == RunState.Phase.PACT_OFFER:
		_game_over()


# --------------------------------------------------------------------------- boutique


func leave_shop() -> void:
	if run.phase != RunState.Phase.SHOP:
		return
	run.shop_state = {}
	var act_change: bool = bool(run.flags.get("act_changed", false))
	if act_change or bool(run.flags.get("event_due", false)):
		run.flags.erase("act_changed")
		run.flags.erase("event_due")
		var ev: String = _pick_event()
		if ev != "":
			run.pending_event_id = ev
			run.phase = RunState.Phase.EVENT
			return
	start_deadline()


func _pick_event() -> String:
	var pool: Array[String] = []
	var seen: Array = run.flags.get("seen_events", [])
	for e: Dictionary in db.list("events"):
		var eid: String = String(e["id"])
		if not seen.has(eid) and int(e.get("act_min", 1)) <= run.act():
			pool.append(eid)
	if pool.is_empty():
		return ""
	var pick: String = pool[run.rng.randi_range_in(RngStreams.EVENTS, 0, pool.size() - 1)]
	seen.append(pick)
	run.flags["seen_events"] = seen
	return pick


func _event_env() -> EffectEnv:
	var env: EffectEnv = EffectEnv.new()
	env.run = run
	env.db = db
	env.source_kind = ScoreEvent.SRC_SYSTEM
	env.source_id = run.pending_event_id
	return env


## Un choix d'événement peut exiger des conditions (ex. argent suffisant).
func event_choice_available(choice: Dictionary) -> bool:
	return EffectRunner.check_all(choice.get("if", []) as Array, _event_env())


## Résout un choix d'événement entre actes (effets on_use du choix), puis reprend.
func resolve_event(choice_index: int) -> void:
	if run.phase != RunState.Phase.EVENT:
		return
	var def: Dictionary = db.get_entry("events", run.pending_event_id)
	var choices: Array = def.get("choices", [])
	if choice_index >= 0 and choice_index < choices.size() and event_choice_available(choices[choice_index] as Dictionary):
		var env: EffectEnv = _event_env()
		for eff: Variant in (choices[choice_index] as Dictionary).get("effects", []):
			EffectRunner.run_effect(eff as Dictionary, env)
		var event_log: Array = run.flags.get("event_log", [])
		event_log.append("%s:%d" % [run.pending_event_id, choice_index])
		run.flags["event_log"] = event_log
	run.pending_event_id = ""
	start_deadline()


# --------------------------------------------------------------------------- fortune


func fortune_needs_target(fid: String) -> bool:
	return String(db.get_entry("fortunes", fid).get("target", "none")) == "pocket"


## Utilise une carte Fortune ; `pocket_index` requis si la carte cible une case.
func use_fortune(slot: int, pocket_index: int = -1) -> bool:
	if slot < 0 or slot >= run.fortunes.size():
		return false
	var fid: String = run.fortunes[slot]
	var def: Dictionary = db.get_entry("fortunes", fid)
	var env: EffectEnv = EffectEnv.new()
	env.run = run
	env.db = db
	env.source_kind = ScoreEvent.SRC_FORTUNE
	env.source_id = fid
	if fortune_needs_target(fid):
		if pocket_index < 0 or pocket_index >= run.wheel.size():
			return false
		env.pocket = run.wheel.at(pocket_index)
		env.pocket_index = pocket_index
	run.fortunes.remove_at(slot)
	run.flags["fortunes_used"] = int(run.flags.get("fortunes_used", 0)) + 1
	for eff: Variant in def.get("effects", []):
		if String((eff as Dictionary).get("trigger", "on_use")) == "on_use":
			EffectRunner.run_effect(eff as Dictionary, env)
	EffectRunner.fire(&"on_fortune_used", run, null, db, {"fortune": fid})
	if run.phase == RunState.Phase.BETTING:
		_configure_slip(false)
	return true


# --------------------------------------------------------------------------- endless


func continue_endless() -> void:
	if run.phase != RunState.Phase.VICTORY:
		return
	run.endless = true
	ShopModel.enter(run, db)
