extends TestCase
## 1.6 : familles de grigris (builds) et paliers.


func _ctl(seed_value: int, extra: Array[String]) -> RunController:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("lea", 0, seed_value)
	for gid: String in extra:
		c.run.add_grigri(gid)
	return c


func test_every_grigri_has_a_family() -> void:
	var db: ContentDB = ContentDB.shared()
	for e: Dictionary in db.list("grigris"):
		check(db.has_entry("families", String(e.get("family", ""))), "famille de " + String(e["id"]))


func test_tier_thresholds() -> void:
	var def: Dictionary = ContentDB.shared().get_entry("families", "rouge_noir")
	eq(Families.tier_index(def, 1), -1, "1 grigri : aucun palier")
	eq(Families.tier_index(def, 2), 0, "2 grigris : palier 1")
	eq(Families.tier_index(def, 4), 1, "4 grigris : palier 2")
	eq(Families.tier_index(def, 9), 2, "au-delà : palier max")
	eq(Families.next_threshold(def, 3), 5, "prochain seuil")
	eq(Families.next_threshold(def, 5), 0, "tous atteints")


func test_disabled_grigri_does_not_count() -> void:
	var c: RunController = _ctl(3, ["g_even_sock", "g_odd_duck"])
	eq(int(Families.counts(c.run, c.db).get("rouge_noir", 0)), 2, "deux Rouge & Noir")
	c.run.grigris[c.run.grigris.size() - 1].disabled = true
	eq(int(Families.counts(c.run, c.db).get("rouge_noir", 0)), 1, "désactivé : non compté")


## Palier 1 de Rouge & Noir : +3 Mult par pari extérieur gagnant (à grigris égaux par ailleurs).
func test_family_tier_adds_mult() -> void:
	for s: int in range(1, 60):
		var a: RunController = _ctl(s, ["g_even_sock", "g_odd_duck"])
		var b: RunController = _ctl(s, ["g_even_sock", "g_lucky_penny"])
		a.place_bet("red", 1)
		b.place_bet("red", 1)
		var oa: RunController.SpinOutcome = a.spin(0)
		var ob: RunController.SpinOutcome = b.spin(0)
		if oa.ctx.bets_won.is_empty() or oa.ctx.is_zero:
			continue
		check(oa.ctx.landing_index == ob.ctx.landing_index, "même tirage")
		var delta: float = oa.ctx.mult_add - ob.ctx.mult_add
		check(absf(delta - 3.0) < 0.001, "palier : +3 Mult (écart %.2f)" % delta)
		return
	check(false, "aucun tirage gagnant trouvé")
