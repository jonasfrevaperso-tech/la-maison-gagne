extends TestCase
## Événements, succès, défis.


func test_every_event_has_an_available_choice_and_resolves() -> void:
	var db: ContentDB = ContentDB.shared()
	for eid: String in db.ids("events"):
		var choices: Array = db.get_entry("events", eid).get("choices", [])
		for i: int in choices.size():
			var c: RunController = RunController.new(db)
			c.new_run("lea", 0, hash(eid) + i)
			c.run.money = 0
			c.run.pending_event_id = eid
			c.run.phase = RunState.Phase.EVENT
			var any: bool = false
			for ch: Variant in choices:
				any = any or c.event_choice_available(ch as Dictionary)
			check(any, "%s : au moins un choix sans condition" % eid)
			c.run.money = 50
			c.resolve_event(i)
			eq(c.run.phase, RunState.Phase.BETTING, "%s/%d reprend le jeu" % [eid, i])


func test_next_debt_pct_applies_once() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("vic", 0, 5)
	var base: int = c.debt_for(1, 1)
	c.run.flags["next_debt_pct"] = 0.5
	c.run.deadline_idx = 1
	c.start_deadline()
	eq(c.run.debt, int(round(float(base) * 1.5)))
	c.start_deadline()
	eq(c.run.debt, base, "appliqué une seule fois")


func test_achievements_unlock_and_reward() -> void:
	var db: ContentDB = ContentDB.shared()
	var profile: Dictionary = {"achievements": [], "unlocked_characters": ["lea"]}
	var got: Array[String] = MetaProgress.evaluate(
		profile,
		db,
		"deadline_won",
		{"tier": 7, "deadline": 0, "spins_used": 2, "score_ratio": 1.2, "money": 10, "creditor": "", "character": "lea"}
	)
	check(got.has("ach_ghost_story"), "succès du Fantôme")
	check((profile["unlocked_characters"] as Array).has("ghost"), "Fantôme débloqué")
	var again: Array[String] = MetaProgress.evaluate(
		profile,
		db,
		"deadline_won",
		{"tier": 7, "deadline": 0, "spins_used": 2, "score_ratio": 1.2, "money": 10, "creditor": "", "character": "lea"}
	)
	check(not again.has("ach_ghost_story"), "pas de double déblocage")
	var shop: Array[String] = MetaProgress.evaluate(profile, db, "shop", {"action": "buy", "rarity": "legendary"})
	check(shop.has("ach_buy_legendary"))


func test_achievement_conditions_use_known_metrics() -> void:
	var db: ContentDB = ContentDB.shared()
	var c: RunController = RunController.new(db)
	c.new_run("lea", 0, 1)
	c.place_bet("red", 1)
	var out: RunController.SpinOutcome = c.spin(0)
	var keys: Dictionary = {
		"spin": MetaProgress.spin_metrics(c.run, out.ctx),
		"deadline_won": MetaProgress.deadline_metrics(c.run),
		"run_end": MetaProgress.run_metrics(c.run, db, false),
		"profile": MetaProgress.profile_metrics({}),
		"shop": {"action": "", "rarity": "", "rerolls_here": 0, "id": ""},
	}
	eq(db.count("achievements"), 66)
	for a: Dictionary in db.list("achievements"):
		var hook: String = String(a["on"])
		check(keys.has(hook), "%s : crochet inconnu" % a["id"])
		for cond: Variant in a.get("cond", []):
			check(
				(keys[hook] as Dictionary).has(String((cond as Dictionary)["k"])), "%s : métrique %s" % [a["id"], (cond as Dictionary)["k"]]
			)


func test_every_challenge_starts_and_plays() -> void:
	var db: ContentDB = ContentDB.shared()
	eq(db.count("challenges"), 20)
	for cid: String in db.ids("challenges"):
		var ch: Dictionary = db.get_entry("challenges", cid)
		var c: RunController = RunController.new(db)
		c.new_run(String(ch.get("character", "lea")), 0, hash(cid), cid)
		eq(c.run.challenge_id, cid)
		for _i: int in 6:
			if c.run.phase != RunState.Phase.BETTING:
				break
			c.place_bet("red", 2)
			c.place_bet("straight:7", 1)
			c.ensure_some_bet()
			check(c.can_spin(), "%s : un pari est possible" % cid)
			c.spin(3)
	var r: RunController = RunController.new(db)
	r.new_run("lea", 0, 1, "ch_house_rules")
	eq(r.run.risk_level, 8, "risque imposé")
