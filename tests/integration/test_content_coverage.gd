extends TestCase
## Couverture du contenu : chaque grigri, type de case, édition, sceau, Fortune, contrat
## et créancier doit produire un effet observable en conditions de jeu réelles.

const SPINS: int = 400
## Grigris dont l'effet est passif (statistiques) : vérifiés par différence d'état.
const STAT_KEYS: Array[String] = [
	"bet_budget",
	"chip_value",
	"precision",
	"control_bonus",
	"interest_cap_bonus",
	"grigri_slots",
	"table_limit_bonus",
	"fortune_slots",
	"extra_spins",
	"shop_discount",
]


func _fresh(seed_value: int) -> RunController:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("vic", 0, seed_value)
	c.run.grigris.clear()
	c.run.character_id = ""
	c.run.money = 50
	c.run.flags.erase("creditor_plan")
	return c


## Paris variés couvrant voisinage, extérieurs, Zéro et chevaux ; un tour sur trois : tapis
## « tout sur un seul emplacement » (budget plein, pari unique).
func _bet(c: RunController, target: int, pattern: int) -> void:
	var n: int = c.run.wheel.at(target).number
	if pattern == 0:
		c.place_bet("red" if c.run.banned_color != &"red" else "black", c.run.slip.budget)
		c.ensure_some_bet()
		return
	c.place_bet("straight:%d" % n, 1)
	c.place_bet("straight:0", 1)
	c.place_bet("red", 2)
	c.place_bet("dozen:%d" % maxi(WheelLayout.dozen_of(n), 0), 1)
	c.place_bet("column:1", 1)
	c.place_bet("split:17-20", 1)
	c.place_bet("corner:1", 1)
	c.place_bet("odd", 1)
	c.ensure_some_bet()


func _stats(r: RunState) -> Dictionary:
	var d: Dictionary = r.to_dict()
	var out: Dictionary = {}
	for k: String in STAT_KEYS:
		out[k] = d.get(k)
	return out


## Joue SPINS tours en réinitialisant dette/tours ; renvoie les ids sources ayant émis un événement.
func _play(c: RunController, spins: int, seed_value: int) -> Dictionary:
	var seen: Dictionary = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in spins:
		var r: RunState = c.run
		r.phase = RunState.Phase.BETTING
		r.debt = 1 << 40
		r.spins_left = 1 + i % 3
		r.spin_index = i % 4
		c.begin_betting()
		var target: int = rng.randi_range(0, r.wheel.size() - 1)
		_bet(c, target, i % 3)
		var out: RunController.SpinOutcome = c.spin(target)
		for e: ScoreEvent in out.ctx.events:
			seen[e.source_id] = true
		if i % 25 == 24:
			# Passage en boutique simulé : reroll, achat/vente d'un grigri tiers, Fortune, contrat.
			r.money += 30
			ShopModel.enter(r, c.db)
			ShopModel.reroll(r, c.db)
			if r.empty_grigri_slots() > 0:
				var helper: GrigriInstance = ShopModel.acquire_grigri(r, c.db, "g_lucky_penny", &"")
				ShopModel.sell_grigri(r, c.db, helper.uid)
			r.fortunes = ["f_focus"]
			c.use_fortune(0)
			for cid: String in c.db.ids("contracts"):
				if not r.contracts.has(cid) and String(c.db.get_entry("contracts", cid).get("requires", "")) == "":
					ShopModel.add_contract(r, c.db, cid)
					break
			r.phase = RunState.Phase.BETTING
			# Fin d'échéance simulée : déclencheurs de fin et de début.
			EffectRunner.fire(&"on_deadline_end", r, null, c.db)
			EffectRunner.fire(&"on_deadline_start", r, null, c.db)
			for g: GrigriInstance in r.grigris:
				seen[g.id + "#alive"] = true
	return seen


func test_every_grigri_has_observable_effect() -> void:
	var db: ContentDB = ContentDB.shared()
	var silent: Array[String] = []
	for gid: String in db.ids("grigris"):
		var c: RunController = _fresh(hash(gid))
		# Contexte riche : cases variées et quelques copains pour les copieurs/destructeurs.
		var types: Array[String] = ["golden", "glass", "ruby", "steel", "twin"]
		for k: int in types.size():
			c.run.wheel.at(3 + k * 6).type_id = StringName(types[k])
		ShopModel.acquire_grigri(c.run, db, gid, &"")
		var before: Dictionary = _stats(c.run)
		c.run.grigris = c.run.grigris.filter(func(g: GrigriInstance) -> bool: return g.id != gid)
		var without: Dictionary = _stats(c.run)
		c.run.grigris.clear()
		ShopModel.acquire_grigri(c.run, db, gid, &"")
		if gid in ["g_blueprint", "g_cracked_mirror", "g_vampire"]:
			c.run.grigris.clear()
			ShopModel.acquire_grigri(c.run, db, gid, &"")
			ShopModel.acquire_grigri(c.run, db, "g_velvet_glove", &"")
			ShopModel.acquire_grigri(c.run, db, "g_red_ribbon", &"")
		var seen: Dictionary = _play(c, SPINS, hash(gid) + 1)
		var stat_changed: bool = before != without or _stats(c.run) != before
		var did_something: bool = seen.has(gid) or stat_changed or not c.run.has_grigri(gid)
		if gid == "g_blueprint" or gid == "g_cracked_mirror":
			did_something = seen.has(gid) or seen.has("g_velvet_glove")
		if not did_something:
			silent.append(gid)
	eq(silent, [] as Array[String], "grigris sans effet observable")
	check(db.count("grigris") >= 40, "au moins 40 grigris")


func test_every_pocket_type_has_effect() -> void:
	var db: ContentDB = ContentDB.shared()
	var silent: Array[String] = []
	var special: int = 0
	for tid: String in db.ids("pocket_types"):
		if tid == "standard":
			continue
		special += 1
		var c: RunController = _fresh(hash(tid))
		for i: int in range(1, c.run.wheel.size(), 2):
			c.run.wheel.at(i).type_id = StringName(tid)
		var seen: Dictionary = _play(c, 120, hash(tid))
		var def: Dictionary = db.get_entry("pocket_types", tid)
		var structural: bool = (
			def.has("counts_as_colors") or def.has("zero_like") or def.has("attract") or def.has("sticky") or def.has("ghost")
		)
		if not seen.has(tid) and not structural:
			silent.append(tid)
	eq(silent, [] as Array[String], "types de cases sans effet")
	check(special >= 10, "au moins 10 cases spéciales")


func test_editions_and_seals_trigger() -> void:
	var db: ContentDB = ContentDB.shared()
	for eid: String in db.ids("editions"):
		var c: RunController = _fresh(hash(eid))
		for i: int in c.run.wheel.size():
			c.run.wheel.at(i).edition = StringName(eid)
		var seen: Dictionary = _play(c, 30, hash(eid))
		check(seen.has(eid), "édition %s" % eid)
	for sid: String in db.ids("seals"):
		var c2: RunController = _fresh(hash(sid))
		for i2: int in c2.run.wheel.size():
			c2.run.wheel.at(i2).seal = StringName(sid)
		var seen2: Dictionary = _play(c2, 120, hash(sid))
		check(seen2.has(sid), "sceau %s" % sid)


func test_fortunes_apply() -> void:
	var db: ContentDB = ContentDB.shared()
	for fid: String in db.ids("fortunes"):
		var c: RunController = _fresh(hash(fid))
		var before: String = JSON.stringify(c.run.to_dict())
		c.run.fortunes = [fid]
		check(c.use_fortune(0, 5), "utilisation de %s" % fid)
		check(JSON.stringify(c.run.to_dict()) != before, "%s modifie l'état" % fid)


func test_contracts_apply_and_chain() -> void:
	var db: ContentDB = ContentDB.shared()
	for cid: String in db.ids("contracts"):
		var c: RunController = _fresh(hash(cid))
		var before: Dictionary = c.run.to_dict()
		before.erase("contracts")
		ShopModel.add_contract(c.run, db, cid)
		var after: Dictionary = c.run.to_dict()
		after.erase("contracts")
		check(JSON.stringify(before) != JSON.stringify(after), "contrat %s sans effet" % cid)
	# Le niveau 2 n'est proposé qu'après le niveau 1.
	var c2: RunController = _fresh(77)
	for _i: int in 30:
		ShopModel.enter(c2.run, db)
		for o: Variant in c2.run.shop_state["contracts"]:
			var req: String = String(db.get_entry("contracts", String((o as Dictionary)["id"])).get("requires", ""))
			check(req == "" or c2.run.contracts.has(req), "chaîne respectée")


func test_creditors_rules_bite() -> void:
	var db: ContentDB = ContentDB.shared()
	for cid: String in db.ids("creditors"):
		var c: RunController = _fresh(hash(cid))
		c.run.deadline_idx = 2
		c.run.flags["creditor_plan"] = [cid]
		c.start_deadline()
		eq(c.run.creditor_id, cid)
		var before: String = JSON.stringify(c.run.to_dict())
		var seen: Dictionary = {}
		for i: int in 12:
			if c.run.phase != RunState.Phase.BETTING:
				break
			c.place_bet("red", 3)
			c.place_bet("corner:1", 2)
			c.ensure_some_bet()
			var out: RunController.SpinOutcome = c.spin(i)
			for e: ScoreEvent in out.ctx.events:
				seen[e.source_id] = true
			c.run.debt = 1 << 40
		var changed: bool = seen.has(cid) or JSON.stringify(c.run.to_dict()) != before
		check(changed, "créancier %s sans effet" % cid)
