class_name SimBot
extends RefCounted
## Bots de simulation. Trois profils :
## - random   : paris et achats aléatoires (plancher).
## - greedy   : stratégie de voisinage + extérieurs, achats par heuristique de tags/rareté.
## - synergy  : comme greedy, mais évalue chaque offre par Monte-Carlo (score moyen simulé).
## Les bots ont une visée « humaine » : erreur de ±1 case avec probabilité AIM_ERROR.

const AIM_ERROR: float = 0.35
const SAVE_FOR_INTEREST: int = 10
const MC_SPINS: int = 24
const RARITY_VALUE: Dictionary = {"common": 1.0, "rare": 1.6, "legendary": 2.6, "cursed": 1.9}
const TAG_VALUE: Dictionary = {
	"xmult": 2.0, "mult": 1.2, "chips": 0.8, "retrigger": 1.8, "copy": 1.4, "growth": 1.2, "economy": 0.6, "safety": 0.5
}
const SPECIAL_TYPE_VALUE: Dictionary = {
	"golden": 2.0,
	"ruby": 3.0,
	"glass": 4.0,
	"steel": 3.0,
	"twin": 3.0,
	"lightning": 3.5,
	"lucky": 2.5,
	"mirror": 2.0,
	"bomb": 2.5,
	"magnet": 2.0,
	"prism": 2.0,
	"timed": 2.5,
	"echo": 2.0,
	"sacred": 2.0,
	"thief": 1.5,
	"vault": 1.5,
	"sprout": 2.0,
	"sticky": 1.5,
	"thorn": 3.0,
	"ghost": 2.0,
	"joker": 1.5,
}

var kind: String = "greedy"
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var picks: Array[String] = []
var target_index: int = 0


func _init(p_kind: String, p_seed: int) -> void:
	kind = p_kind
	rng.seed = p_seed


# --------------------------------------------------------------------------- paris


func place_bets(ctl: RunController) -> void:
	var run: RunState = ctl.run
	if kind == "random":
		for _i: int in run.slip.budget:
			var spots: Array[BetSpot] = BetCatalog.all()
			ctl.place_bet(spots[rng.randi_range(0, spots.size() - 1)].id)
		target_index = rng.randi_range(0, run.wheel.size() - 1)
		ctl.ensure_some_bet()
		return
	target_index = _best_target(ctl)
	var half: int = ThrowResolver.zone_width_for(ctl.effective_precision(), int(run.flags.get("zone_width_override", 0))) / 2
	# Pleins sur la cible et ses voisins immédiats, puis le reste en extérieur.
	var straights_budget: int = run.slip.budget / 2
	var placed: int = 0
	for o: int in [0, -1, 1, -2, 2, -3, 3]:
		if absi(o) > half or placed >= straights_budget:
			continue
		var n: int = run.wheel.at(target_index + o).number
		if ctl.place_bet("straight:%d" % n) == BetSlip.PlaceResult.OK:
			placed += 1
	var color: String = _zone_majority_color(ctl, target_index, half)
	while run.slip.remaining() > 0:
		if ctl.place_bet(color) != BetSlip.PlaceResult.OK:
			if ctl.place_bet("dozen:%d" % maxi(WheelLayout.dozen_of(run.wheel.at(target_index).number), 0)) != BetSlip.PlaceResult.OK:
				break
	ctl.ensure_some_bet()
	_fill_allowed(ctl)


## Créanciers restrictifs : remplit avec ce qui est autorisé, au plus près de la cible.
func _fill_allowed(ctl: RunController) -> void:
	var run: RunState = ctl.run
	if run.slip.remaining() <= 0:
		return
	var n: int = run.wheel.at(target_index).number
	for spot: BetSpot in BetCatalog.all():
		if run.slip.remaining() <= 0:
			break
		if spot.covers(n):
			while run.slip.remaining() > 0 and ctl.place_bet(spot.id) == BetSlip.PlaceResult.OK:
				pass


func _best_target(ctl: RunController) -> int:
	var run: RunState = ctl.run
	var best: int = 0
	var best_v: float = -1.0
	for i: int in run.wheel.size():
		var v: float = 0.0
		for o: int in range(-1, 2):
			var p: Pocket = run.wheel.at(i + o)
			var w: float = 1.0 if o == 0 else 0.5
			v += w * (float(SPECIAL_TYPE_VALUE.get(String(p.type_id), 0.0)) + float(p.level) * 0.3 + (1.5 if p.edition != &"" else 0.0))
			if p.is_zero() or String(p.type_id) in ["cursed", "burnt", "double_zero"]:
				v -= w * 2.0
		if v > best_v:
			best_v = v
			best = i
	return best


func _zone_majority_color(ctl: RunController, center: int, half: int) -> String:
	var reds: int = 0
	var blacks: int = 0
	for o: int in range(-half, half + 1):
		var c: StringName = ctl.run.wheel.at(center + o).color()
		if c == &"red":
			reds += 1
		elif c == &"black":
			blacks += 1
	var pick: String = "red" if reds >= blacks else "black"
	if String(ctl.run.banned_color) == pick:
		pick = "black" if pick == "red" else "red"
	return pick


func aim(ctl: RunController) -> int:
	if rng.randf() < AIM_ERROR:
		return posmod(target_index + (1 if rng.randf() < 0.5 else -1), ctl.run.wheel.size())
	return target_index


# --------------------------------------------------------------------------- boutique


func shop(ctl: RunController) -> void:
	var run: RunState = ctl.run
	if kind == "random":
		var offers: Array = run.shop_state.get("grigris", [])
		if not offers.is_empty():
			var idx: int = rng.randi_range(0, offers.size() - 1)
			if ShopModel.buy_grigri(run, ctl.db, idx) == ShopModel.BuyResult.OK:
				picks.append(String((offers[idx] as Dictionary)["id"]))
		return
	# 1. Contrats (améliorations permanentes) si on reste au-dessus de la réserve.
	var contracts: Array = run.shop_state.get("contracts", [])
	for i: int in contracts.size():
		var c: Dictionary = contracts[i]
		if not bool(c["sold"]) and run.money - int(c["price"]) >= SAVE_FOR_INTEREST / 2:
			ShopModel.buy_contract(run, ctl.db, i)
	# 2. Grigris : meilleure valeur, en remplaçant le plus faible si plein.
	var tries: int = 0
	while tries < 3:
		tries += 1
		var offers2: Array = run.shop_state.get("grigris", [])
		var best_i: int = -1
		var best_v: float = 0.0
		for i: int in offers2.size():
			var o: Dictionary = offers2[i]
			if bool(o["sold"]) or int(o["price"]) > run.money:
				continue
			var v: float = _value_of(ctl, String(o["id"])) / maxf(float(o["price"]), 1.0)
			if v > best_v:
				best_v = v
				best_i = i
		if best_i < 0:
			break
		if run.empty_grigri_slots() <= 0:
			var weakest: GrigriInstance = _weakest(ctl)
			if weakest == null or _value_of(ctl, weakest.id) * 1.25 >= _value_of(ctl, String((offers2[best_i] as Dictionary)["id"])):
				break
			ShopModel.sell_grigri(run, ctl.db, weakest.uid)
		var gid: String = String((offers2[best_i] as Dictionary)["id"])
		if ShopModel.buy_grigri(run, ctl.db, best_i) == ShopModel.BuyResult.OK:
			picks.append(gid)
	# 3. Paquets si l'argent dépasse la réserve.
	var packs: Array = run.shop_state.get("packs", [])
	for i: int in packs.size():
		var pk: Dictionary = packs[i]
		if bool(pk["sold"]) or run.money - int(pk["price"]) < SAVE_FOR_INTEREST:
			continue
		if ShopModel.buy_pack(run, ctl.db, i) == ShopModel.BuyResult.OK:
			_choose_in_pack(ctl)
	# 4. Utiliser les Fortunes ciblées sur la meilleure zone.
	use_fortunes(ctl)


func _choose_in_pack(ctl: RunController) -> void:
	var run: RunState = ctl.run
	var pack: Dictionary = run.shop_state.get("open_pack", {})
	var choices: Array = pack.get("choices", [])
	var best: int = -1
	var best_v: float = -1.0
	for i: int in choices.size():
		var c: Dictionary = choices[i]
		var v: float = 0.0
		match String(pack["kind"]):
			"pocket":
				v = float(SPECIAL_TYPE_VALUE.get(String(c["type"]), 0.5))
			"occult":
				v = _value_of(ctl, String(c["grigri"]))
			"fortune":
				v = 1.0
		if v > best_v:
			best_v = v
			best = i
	if best < 0 or not ShopModel.choose_pack(run, ctl.db, best, "replace"):
		ShopModel.skip_pack(run)


func use_fortunes(ctl: RunController) -> void:
	var run: RunState = ctl.run
	var guard: int = 0
	while not run.fortunes.is_empty() and guard < 4:
		guard += 1
		var fid: String = run.fortunes[0]
		var target: int = -1
		if ctl.fortune_needs_target(fid):
			var t: int = _best_target(ctl)
			# Cible une case standard proche de la meilleure zone.
			for o: int in [0, 1, -1, 2, -2]:
				if run.wheel.at(t + o).type_id == Pocket.TYPE_STANDARD and not run.wheel.at(t + o).is_zero():
					target = posmod(t + o, run.wheel.size())
					break
			if target < 0:
				target = t
			if fid == "f_eraser":
				target = run.wheel.first_index_of_number(0)
				if target < 0:
					target = t
		if not ctl.use_fortune(0, target):
			run.fortunes.remove_at(0)


func _weakest(ctl: RunController) -> GrigriInstance:
	var worst: GrigriInstance = null
	var worst_v: float = INF
	for g: GrigriInstance in ctl.run.grigris:
		if g.locked:
			continue
		var v: float = _value_of(ctl, g.id)
		if v < worst_v:
			worst_v = v
			worst = g
	return worst


func _value_of(ctl: RunController, gid: String) -> float:
	if kind == "synergy":
		return _mc_value(ctl, gid)
	var def: Dictionary = ctl.db.get_entry("grigris", gid)
	var v: float = float(RARITY_VALUE.get(String(def.get("rarity", "common")), 1.0))
	for t: Variant in def.get("tags", []):
		v += float(TAG_VALUE.get(String(t), 0.2))
	return v


## Valeur Monte-Carlo : score moyen sur MC_SPINS tours simulés avec ce grigri en plus.
func _mc_value(ctl: RunController, gid: String) -> float:
	var clone: RunController = RunController.new(ctl.db)
	clone.load_run(RunState.from_dict(ctl.run.to_dict()))
	var r: RunState = clone.run
	r.rng.reseed(rng.randi())
	if not r.has_grigri(gid):
		ShopModel.acquire_grigri(r, ctl.db, gid, &"")
	r.debt = 1 << 40
	r.spins_left = MC_SPINS + 1
	r.phase = RunState.Phase.BETTING
	clone.begin_betting()
	var total: float = 0.0
	var probe: SimBot = SimBot.new("greedy", rng.randi())
	for _i: int in MC_SPINS:
		if r.phase != RunState.Phase.BETTING:
			break
		probe.place_bets(clone)
		var out: RunController.SpinOutcome = clone.spin(probe.aim(clone))
		total += float(out.ctx.total)
	return total / float(MC_SPINS)


func pact(ctl: RunController) -> void:
	var opts: Array[Dictionary] = ctl.pact_options()
	for o: Dictionary in opts:
		if String(o["kind"]) == "budget":
			ctl.accept_pact(o)
			return
	if not opts.is_empty():
		ctl.accept_pact(opts[0])
	else:
		ctl.decline_pact()
