class_name ShopModel
extends RefCounted
## Boutique entre les échéances. Tout l'état vit dans run.shop_state (sauvegardable).
## Offres : grigris, paquets (cases / fortune / occulte), un contrat ; reroll croissant.

enum BuyResult { OK, NO_MONEY, NO_SLOT, SOLD_OUT, INVALID }

const TYPE_GRIGRI: String = "grigri"
const TYPE_PACK: String = "pack"
const TYPE_CONTRACT: String = "contract"
const PACK_KINDS: Array[String] = ["pocket", "fortune", "occult"]
const RARITIES: Array[String] = ["common", "rare", "legendary", "cursed"]


static func enter(run: RunState, db: ContentDB) -> void:
	run.shop_state = {
		"grigris": _roll_grigris(run, db),
		"packs": _roll_packs(run),
		"contracts": _roll_contracts(run, db),
		"reroll_cost": maxi(Balance.i("shop.reroll_base_cost") - run.reroll_discount - int(run.flags.get("reroll_discount", 0)), 0),
		"open_pack": {},
	}
	run.phase = RunState.Phase.SHOP
	EffectRunner.fire(&"on_shop_enter", run, null, db)


## Poids de rareté effectifs (affichés en boutique : transparence des probabilités).
static func rarity_weights(run: RunState) -> Dictionary:
	var w: Dictionary = Balance.dict("shop.rarity_weights").duplicate()
	var cursed_bonus: float = float(run.flags.get("cursed_weight", 0.0))
	w["cursed"] = float(w.get("cursed", 0.0)) + cursed_bonus
	return w


static func rarity_probabilities(run: RunState) -> Dictionary:
	var w: Dictionary = rarity_weights(run)
	var total: float = 0.0
	for r: String in RARITIES:
		total += float(w.get(r, 0.0))
	var out: Dictionary = {}
	for r: String in RARITIES:
		out[r] = float(w.get(r, 0.0)) / maxf(total, 1.0)
	return out


static func price_of(run: RunState, base_cost: int) -> int:
	var mult: float = float(run.flags.get("shop_price_mult", 1.0))
	return maxi(int(round(float(base_cost) * mult)) - run.shop_discount, 0)


static func grigri_cost(db: ContentDB, gid: String) -> int:
	var def: Dictionary = db.get_entry("grigris", gid)
	if def.has("cost"):
		return int(def["cost"])
	return Balance.i("rarity_cost." + String(def.get("rarity", "common")))


static func _pick_rarity(run: RunState, force_rare: bool) -> String:
	var w: Dictionary = rarity_weights(run)
	var weights: Array[float] = []
	for r: String in RARITIES:
		var x: float = float(w.get(r, 0.0))
		if force_rare and r == "common":
			x = 0.0
		weights.append(x)
	var idx: int = run.rng.weighted_index(RngStreams.SHOP, weights)
	return RARITIES[maxi(idx, 0)]


static func _pool(run: RunState, db: ContentDB, rarity: String, exclude: Array[String]) -> Array[String]:
	var pool: Array[String] = []
	for e: Dictionary in db.list("grigris"):
		var gid: String = String(e["id"])
		if String(e.get("rarity", "")) != rarity or bool(e.get("hidden", false)):
			continue
		if run.has_grigri(gid) or exclude.has(gid):
			continue
		if int(e.get("min_tier", 1)) > run.tier:
			continue
		pool.append(gid)
	return pool


static func _roll_grigris(run: RunState, db: ContentDB) -> Array:
	var offers: Array = []
	var taken: Array[String] = []
	var force_rare: bool = run.rerolls_since_rare >= Balance.i("shop.pity_rerolls_without_rare")
	var got_rare: bool = false
	for i: int in Balance.i("shop.grigri_offers"):
		var rarity: String = _pick_rarity(run, force_rare and i == 0)
		var pool: Array[String] = _pool(run, db, rarity, taken)
		if pool.is_empty():
			pool = _pool(run, db, "common", taken)
		if pool.is_empty():
			continue
		var gid: String = pool[run.rng.randi_range_in(RngStreams.SHOP, 0, pool.size() - 1)]
		taken.append(gid)
		if rarity != "common":
			got_rare = true
		var edition: String = ""
		if run.rng.chance(RngStreams.SHOP, Balance.f("shop.edition_chance")):
			var eds: Array[String] = db.ids("editions")
			if not eds.is_empty():
				edition = eds[run.rng.randi_range_in(RngStreams.SHOP, 0, eds.size() - 1)]
		var cost: int = grigri_cost(db, gid)
		if edition != "":
			cost += int(Balance.dict("shop.edition_costs").get(edition, 0))
		offers.append({"type": TYPE_GRIGRI, "id": gid, "edition": edition, "price": price_of(run, cost), "sold": false})
	run.rerolls_since_rare = 0 if got_rare else run.rerolls_since_rare + 1
	return offers


static func _roll_packs(run: RunState) -> Array:
	var packs: Array = []
	var costs: Dictionary = Balance.dict("shop.pack_costs")
	for _i: int in Balance.i("shop.pack_offers"):
		var kind: String = PACK_KINDS[run.rng.randi_range_in(RngStreams.SHOP, 0, PACK_KINDS.size() - 1)]
		packs.append({"type": TYPE_PACK, "kind": kind, "price": price_of(run, int(costs.get(kind, 0))), "sold": false})
	return packs


static func _roll_contracts(run: RunState, db: ContentDB) -> Array:
	var pool: Array[String] = []
	for e: Dictionary in db.list("contracts"):
		var cid: String = String(e["id"])
		if run.contracts.has(cid):
			continue
		var req: String = String(e.get("requires", ""))
		if req != "" and not run.contracts.has(req):
			continue
		pool.append(cid)
	var out: Array = []
	for _i: int in Balance.i("shop.contract_offers"):
		if pool.is_empty():
			break
		var idx: int = run.rng.randi_range_in(RngStreams.SHOP, 0, pool.size() - 1)
		var cid2: String = pool[idx]
		pool.remove_at(idx)
		var cost: int = int(db.get_entry("contracts", cid2).get("cost", 0))
		out.append({"type": TYPE_CONTRACT, "id": cid2, "price": price_of(run, cost), "sold": false})
	return out


static func reroll(run: RunState, db: ContentDB) -> bool:
	var cost: int = int(run.shop_state.get("reroll_cost", 0))
	if run.money < cost:
		return false
	run.money -= cost
	run.shop_rerolls += 1
	run.shop_state["grigris"] = _roll_grigris(run, db)
	run.shop_state["reroll_cost"] = cost + Balance.i("shop.reroll_cost_step")
	EffectRunner.fire(&"on_reroll", run, null, db)
	return true


static func buy_grigri(run: RunState, db: ContentDB, index: int) -> BuyResult:
	var offers: Array = run.shop_state.get("grigris", [])
	if index < 0 or index >= offers.size():
		return BuyResult.INVALID
	var o: Dictionary = offers[index]
	if bool(o["sold"]):
		return BuyResult.SOLD_OUT
	if run.money < int(o["price"]):
		return BuyResult.NO_MONEY
	var def: Dictionary = db.get_entry("grigris", String(o["id"]))
	var needs_slot: bool = String(o.get("edition", "")) != "noire"
	if needs_slot and run.empty_grigri_slots() <= 0:
		return BuyResult.NO_SLOT
	run.money -= int(o["price"])
	o["sold"] = true
	acquire_grigri(run, db, String(o["id"]), StringName(String(o.get("edition", ""))))
	run.bought_ids.append(String(def.get("id", "")))
	return BuyResult.OK


static func acquire_grigri(run: RunState, db: ContentDB, gid: String, edition: StringName) -> GrigriInstance:
	var g: GrigriInstance = run.add_grigri(gid, edition)
	if edition == &"noire":
		run.grigri_slots = mini(run.grigri_slots + 1, Balance.i("slots.grigri_slots_max"))
	var env: EffectEnv = _env(run, db)
	EffectRunner.fire_grigri(&"on_acquire", g, env)
	EffectRunner.fire(&"on_buy", run, null, db, {"bought": gid})
	return g


static func sell_value(_run: RunState, db: ContentDB, g: GrigriInstance) -> int:
	var base: int = grigri_cost(db, g.id)
	return maxi(int(floor(float(base) * Balance.f("economy.sell_ratio"))) + g.sell_bonus, 1)


static func sell_grigri(run: RunState, db: ContentDB, g_uid: int) -> int:
	var g: GrigriInstance = run.grigri_by_uid(g_uid)
	if g == null or g.locked:
		return 0
	var def: Dictionary = db.get_entry("grigris", g.id)
	if bool(def.get("unsellable", false)):
		return 0
	var value: int = sell_value(run, db, g)
	EffectRunner.fire_grigri(&"on_remove", g, _env(run, db))
	run.grigris.erase(g)
	if g.edition == &"noire":
		run.grigri_slots = maxi(run.grigri_slots - 1, Balance.i("slots.grigri_slots"))
	run.money += value
	run.sold_count += 1
	EffectRunner.fire(&"on_sell", run, null, db, {"sold": g.id})
	return value


static func buy_contract(run: RunState, db: ContentDB, index: int) -> BuyResult:
	var offers: Array = run.shop_state.get("contracts", [])
	if index < 0 or index >= offers.size():
		return BuyResult.INVALID
	var o: Dictionary = offers[index]
	if bool(o["sold"]):
		return BuyResult.SOLD_OUT
	if run.money < int(o["price"]):
		return BuyResult.NO_MONEY
	run.money -= int(o["price"])
	o["sold"] = true
	add_contract(run, db, String(o["id"]))
	return BuyResult.OK


static func add_contract(run: RunState, db: ContentDB, cid: String) -> void:
	run.contracts.append(cid)
	var env: EffectEnv = _env(run, db)
	env.source_kind = ScoreEvent.SRC_CONTRACT
	env.source_id = cid
	for eff: Variant in db.get_entry("contracts", cid).get("effects", []):
		if String((eff as Dictionary).get("trigger", "")) == "on_acquire":
			EffectRunner.run_effect(eff as Dictionary, env)


static func buy_pack(run: RunState, db: ContentDB, index: int) -> BuyResult:
	var packs: Array = run.shop_state.get("packs", [])
	if index < 0 or index >= packs.size():
		return BuyResult.INVALID
	var o: Dictionary = packs[index]
	if bool(o["sold"]):
		return BuyResult.SOLD_OUT
	if run.money < int(o["price"]):
		return BuyResult.NO_MONEY
	run.money -= int(o["price"])
	o["sold"] = true
	run.shop_state["open_pack"] = {"kind": o["kind"], "choices": roll_pack_choices(run, db, String(o["kind"]))}
	return BuyResult.OK


static func roll_pack_choices(run: RunState, db: ContentDB, kind: String) -> Array:
	var n: int = int(Balance.dict("shop.pack_choices").get(kind, 0))
	var out: Array = []
	match kind:
		"pocket":
			var types: Array[String] = []
			var weights: Array[float] = []
			for e: Dictionary in db.list("pocket_types"):
				if bool(e.get("shop", false)):
					types.append(String(e["id"]))
					weights.append(float(e.get("weight", 1.0)))
			for _i: int in n:
				var t_idx: int = run.rng.weighted_index(RngStreams.SHOP, weights)
				if t_idx < 0:
					break
				var choice: Dictionary = {
					"type": types[t_idx],
					"number": run.rng.randi_range_in(RngStreams.SHOP, 1, WheelLayout.POCKET_COUNT - 1),
					"edition": "",
					"seal": "",
				}
				if run.rng.chance(RngStreams.SHOP, Balance.f("shop.pocket_pack_edition_chance")):
					var eds: Array[String] = db.ids("editions")
					choice["edition"] = eds[run.rng.randi_range_in(RngStreams.SHOP, 0, eds.size() - 1)]
				if run.rng.chance(RngStreams.SHOP, Balance.f("shop.pocket_pack_seal_chance")):
					var seals: Array[String] = db.ids("seals")
					choice["seal"] = seals[run.rng.randi_range_in(RngStreams.SHOP, 0, seals.size() - 1)]
				out.append(choice)
		"fortune":
			var fids: Array[String] = db.ids("fortunes")
			run.rng.shuffle_in(RngStreams.SHOP, fids)
			for i: int in mini(n, fids.size()):
				out.append({"fortune": fids[i]})
		"occult":
			var w: Dictionary = Balance.dict("shop.occult_rarity_weights")
			var rar: Array[String] = []
			var rw: Array[float] = []
			for k: Variant in w.keys():
				rar.append(String(k))
				rw.append(float(w[k]))
			var taken: Array[String] = []
			for _j: int in n:
				var rarity: String = rar[maxi(run.rng.weighted_index(RngStreams.SHOP, rw), 0)]
				var pool: Array[String] = _pool(run, db, rarity, taken)
				if pool.is_empty():
					pool = _pool(run, db, "rare", taken)
				if pool.is_empty():
					continue
				var gid: String = pool[run.rng.randi_range_in(RngStreams.SHOP, 0, pool.size() - 1)]
				taken.append(gid)
				out.append({"grigri": gid})
	return out


## Choix dans un paquet ouvert. Pour une case : mode "add" (ajoute à côté de son numéro)
## ou "replace" (transforme la case existante portant ce numéro).
static func choose_pack(run: RunState, db: ContentDB, choice_index: int, mode: String = "add") -> bool:
	var pack: Dictionary = run.shop_state.get("open_pack", {})
	if pack.is_empty():
		return false
	var choices: Array = pack.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return false
	var c: Dictionary = choices[choice_index]
	match String(pack["kind"]):
		"pocket":
			var n: int = int(c["number"])
			var idx: int = run.wheel.first_index_of_number(n)
			var p: Pocket
			if mode == "replace" and idx >= 0:
				p = run.wheel.at(idx)
			else:
				p = run.wheel.insert_number(idx if idx >= 0 else 0, n)
			p.type_id = StringName(String(c["type"]))
			if String(c.get("edition", "")) != "":
				p.edition = StringName(String(c["edition"]))
			if String(c.get("seal", "")) != "":
				p.seal = StringName(String(c["seal"]))
		"fortune":
			if run.fortunes.size() >= run.fortune_slots:
				return false
			run.fortunes.append(String(c["fortune"]))
		"occult":
			if run.empty_grigri_slots() <= 0:
				return false
			acquire_grigri(run, db, String(c["grigri"]), &"")
	run.shop_state["open_pack"] = {}
	return true


static func skip_pack(run: RunState) -> void:
	run.shop_state["open_pack"] = {}


static func _env(run: RunState, db: ContentDB) -> EffectEnv:
	var env: EffectEnv = EffectEnv.new()
	env.run = run
	env.db = db
	return env
