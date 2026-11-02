class_name RunState
extends RefCounted
## Tout l'état d'un run, sérialisable intégralement (reprise exacte).

enum Phase { BETTING, DEADLINE_WON, SHOP, PACT_OFFER, EVENT, GAME_OVER, VICTORY }

const HISTORY_MAX: int = 50
const SAVE_VERSION: int = 1

var rng: RngStreams = RngStreams.new()
var character_id: String = ""
var risk_level: int = 0
var challenge_id: String = ""
var daily: bool = false
var endless: bool = false

var tier: int = 1
var deadline_idx: int = 0
var spins_left: int = 0
var spins_total: int = 0
var spin_index: int = 0
var deadline_score: int = 0
var debt: int = 0
var creditor_id: String = ""
var creditor_phase: int = 0

var money: int = 0
var wheel: WheelModel = WheelModel.standard()
var grigris: Array[GrigriInstance] = []
var grigri_slots: int = 0
var next_grigri_uid: int = 1
var fortunes: Array[String] = []
var fortune_slots: int = 0
var contracts: Array[String] = []

var bet_budget: int = 0
var chip_value: int = 0
var precision: int = 1
var control_bonus: float = 0.0
var table_limit_bonus: int = 0
var temp_budget_bonus: int = 0
var temp_precision_bonus: int = 0
var interest_cap_bonus: int = 0
var shop_discount: int = 0
var extra_spins_per_deadline: int = 0
var reroll_discount: int = 0

var slip: BetSlip = BetSlip.new()
var last_layout: Dictionary = {}
var favorites: Array[Dictionary] = []
var banned_color: StringName = &""
var allowed_kinds: Array[StringName] = []

var history: Array[Dictionary] = []
var color_streak_color: StringName = &""
var color_streak: int = 0
var last_number: int = -1
var last_landing_index: int = -1
var sticky_index: int = -1
var zeros_hit: int = 0
var total_spins: int = 0
var best_spin: int = 0
var deadlines_cleared: int = 0
var pacts_used: Dictionary = {}  # act(int) -> count
var losses_forgiven_tier: int = 0
var free_rethrows: int = 0
var rethrow_available: bool = false
var shop_rerolls: int = 0
var rerolls_since_rare: int = 0
var sold_count: int = 0
var bought_ids: Array[String] = []
var flags: Dictionary = {}
var phase: Phase = Phase.BETTING
var defeat_reason: String = ""
var deadline_log: Array[Dictionary] = []
var pending_event_id: String = ""
var shop_state: Dictionary = {}


func act() -> int:
	var acts: Array = Balance.arr("run.acts")
	for a: int in acts.size():
		for t: Variant in acts[a]:
			if int(t) == tier:
				return a + 1
	return acts.size()


func deadline_kind() -> String:
	return String(Balance.arr("run.deadline_kinds")[deadline_idx])


func is_creditor() -> bool:
	return deadline_idx == Balance.arr("run.deadline_kinds").size() - 1


func grigri_by_uid(p_uid: int) -> GrigriInstance:
	for g: GrigriInstance in grigris:
		if g.uid == p_uid:
			return g
	return null


func has_grigri(gid: String) -> bool:
	for g: GrigriInstance in grigris:
		if g.id == gid:
			return true
	return false


func empty_grigri_slots() -> int:
	return maxi(grigri_slots - grigris.size(), 0)


func add_grigri(gid: String, edition: StringName = &"") -> GrigriInstance:
	var g: GrigriInstance = GrigriInstance.new(gid, next_grigri_uid)
	next_grigri_uid += 1
	g.edition = edition
	grigris.append(g)
	return g


func push_history(entry: Dictionary) -> void:
	history.push_front(entry)
	if history.size() > HISTORY_MAX:
		history.resize(HISTORY_MAX)


func to_dict() -> Dictionary:
	var gl: Array = []
	for g: GrigriInstance in grigris:
		gl.append(g.to_dict())
	var allowed: Array = []
	for k: StringName in allowed_kinds:
		allowed.append(String(k))
	return {
		"version": SAVE_VERSION,
		"rng": rng.to_dict(),
		"character": character_id,
		"risk": risk_level,
		"challenge": challenge_id,
		"daily": daily,
		"endless": endless,
		"tier": tier,
		"deadline_idx": deadline_idx,
		"spins_left": spins_left,
		"spins_total": spins_total,
		"spin_index": spin_index,
		"deadline_score": deadline_score,
		"debt": debt,
		"creditor": creditor_id,
		"creditor_phase": creditor_phase,
		"money": money,
		"wheel": wheel.to_dict(),
		"grigris": gl,
		"grigri_slots": grigri_slots,
		"next_grigri_uid": next_grigri_uid,
		"fortunes": fortunes.duplicate(),
		"fortune_slots": fortune_slots,
		"contracts": contracts.duplicate(),
		"bet_budget": bet_budget,
		"chip_value": chip_value,
		"precision": precision,
		"control_bonus": control_bonus,
		"table_limit_bonus": table_limit_bonus,
		"temp_budget_bonus": temp_budget_bonus,
		"slip_budget": slip.budget,
		"temp_precision_bonus": temp_precision_bonus,
		"interest_cap_bonus": interest_cap_bonus,
		"shop_discount": shop_discount,
		"extra_spins": extra_spins_per_deadline,
		"reroll_discount": reroll_discount,
		"slip": slip.snapshot(),
		"last_layout": last_layout.duplicate(),
		"favorites": favorites.duplicate(true),
		"banned_color": String(banned_color),
		"allowed_kinds": allowed,
		"history": history.duplicate(true),
		"streak_color": String(color_streak_color),
		"streak": color_streak,
		"last_number": last_number,
		"last_landing": last_landing_index,
		"sticky": sticky_index,
		"zeros": zeros_hit,
		"total_spins": total_spins,
		"best_spin": best_spin,
		"cleared": deadlines_cleared,
		"pacts": pacts_used.duplicate(),
		"forgiven_tier": losses_forgiven_tier,
		"free_rethrows": free_rethrows,
		"rethrow_available": rethrow_available,
		"shop_rerolls": shop_rerolls,
		"rerolls_since_rare": rerolls_since_rare,
		"sold": sold_count,
		"bought": bought_ids.duplicate(),
		"flags": floatify(flags),
		"phase": int(phase),
		"defeat": defeat_reason,
		"deadline_log": deadline_log.duplicate(true),
		"pending_event": pending_event_id,
		"shop_state": shop_state.duplicate(true),
	}


## Les drapeaux mélangent entiers et flottants : on les écrit tous en flottants (relecture JSON exacte).
static func floatify(v: Variant) -> Variant:
	if v is int:
		return float(v)
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in (v as Dictionary).keys():
			out[k] = floatify((v as Dictionary)[k])
		return out
	if v is Array:
		var arr: Array = []
		for item: Variant in v:
			arr.append(floatify(item))
		return arr
	return v


## JSON relit les entiers comme des flottants : on les restaure (déterminisme exact).
static func intify(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, round(v)) and absf(v) < 9.0e15:
		return int(v)
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in (v as Dictionary).keys():
			out[k] = intify((v as Dictionary)[k])
		return out
	if v is Array:
		var arr: Array = []
		for item: Variant in v:
			arr.append(intify(item))
		return arr
	return v


static func from_dict(d: Dictionary) -> RunState:
	var s: RunState = RunState.new()
	s.rng.from_dict(d.get("rng", {}))
	s.character_id = String(d.get("character", ""))
	s.risk_level = int(d.get("risk", 0))
	s.challenge_id = String(d.get("challenge", ""))
	s.daily = bool(d.get("daily", false))
	s.endless = bool(d.get("endless", false))
	s.tier = int(d.get("tier", 1))
	s.deadline_idx = int(d.get("deadline_idx", 0))
	s.spins_left = int(d.get("spins_left", 0))
	s.spins_total = int(d.get("spins_total", 0))
	s.spin_index = int(d.get("spin_index", 0))
	s.deadline_score = int(d.get("deadline_score", 0))
	s.debt = int(d.get("debt", 0))
	s.creditor_id = String(d.get("creditor", ""))
	s.creditor_phase = int(d.get("creditor_phase", 0))
	s.money = int(d.get("money", 0))
	s.wheel = WheelModel.from_dict(d.get("wheel", {}))
	for gd: Variant in d.get("grigris", []):
		s.grigris.append(GrigriInstance.from_dict(gd as Dictionary))
	s.grigri_slots = int(d.get("grigri_slots", 0))
	s.next_grigri_uid = int(d.get("next_grigri_uid", 1))
	s.fortunes.assign(d.get("fortunes", []))
	s.fortune_slots = int(d.get("fortune_slots", 0))
	s.contracts.assign(d.get("contracts", []))
	s.bet_budget = int(d.get("bet_budget", 0))
	s.chip_value = int(d.get("chip_value", 0))
	s.precision = int(d.get("precision", 1))
	s.control_bonus = float(d.get("control_bonus", 0.0))
	s.table_limit_bonus = int(d.get("table_limit_bonus", 0))
	s.temp_budget_bonus = int(d.get("temp_budget_bonus", 0))
	s.temp_precision_bonus = int(d.get("temp_precision_bonus", 0))
	s.interest_cap_bonus = int(d.get("interest_cap_bonus", 0))
	s.shop_discount = int(d.get("shop_discount", 0))
	s.extra_spins_per_deadline = int(d.get("extra_spins", 0))
	s.reroll_discount = int(d.get("reroll_discount", 0))
	s.last_layout = intify(d.get("last_layout", {}))
	for fav: Variant in intify(d.get("favorites", [])):
		s.favorites.append(fav as Dictionary)
	s.banned_color = StringName(String(d.get("banned_color", "")))
	for k: Variant in d.get("allowed_kinds", []):
		s.allowed_kinds.append(StringName(String(k)))
	for h: Variant in intify(d.get("history", [])):
		s.history.append(h as Dictionary)
	s.color_streak_color = StringName(String(d.get("streak_color", "")))
	s.color_streak = int(d.get("streak", 0))
	s.last_number = int(d.get("last_number", -1))
	s.last_landing_index = int(d.get("last_landing", -1))
	s.sticky_index = int(d.get("sticky", -1))
	s.zeros_hit = int(d.get("zeros", 0))
	s.total_spins = int(d.get("total_spins", 0))
	s.best_spin = int(d.get("best_spin", 0))
	s.deadlines_cleared = int(d.get("cleared", 0))
	s.pacts_used = intify(d.get("pacts", {}))
	s.losses_forgiven_tier = int(d.get("forgiven_tier", 0))
	s.free_rethrows = int(d.get("free_rethrows", 0))
	s.rethrow_available = bool(d.get("rethrow_available", false))
	s.shop_rerolls = int(d.get("shop_rerolls", 0))
	s.rerolls_since_rare = int(d.get("rerolls_since_rare", 0))
	s.sold_count = int(d.get("sold", 0))
	s.bought_ids.assign(d.get("bought", []))
	s.flags = d.get("flags", {})
	s.phase = int(d.get("phase", 0)) as Phase
	s.defeat_reason = String(d.get("defeat", ""))
	for dl: Variant in intify(d.get("deadline_log", [])):
		s.deadline_log.append(dl as Dictionary)
	s.pending_event_id = String(d.get("pending_event", ""))
	s.shop_state = intify(d.get("shop_state", {}))
	# Reconfigure le bulletin exactement comme en jeu avant de reposer les mises.
	# Budget réel du bulletin : hors phase de mise, il peut encore inclure un bonus temporaire
	# déjà consommé (mises du tour précédent conservées).
	s.slip.budget = maxi(int(d.get("slip_budget", s.bet_budget + s.temp_budget_bonus)), 1)
	s.slip.table_limit_bonus = s.table_limit_bonus
	s.slip.allowed_kinds = s.allowed_kinds.duplicate()
	if s.banned_color != &"":
		s.slip.banned_spots.append(String(s.banned_color))
	s.slip.apply_layout(intify(d.get("slip", {})))
	return s
