extends TestCase
## 1.4 : grigris à malus visuel (données cohérentes, intensités cumulées et plafonnées).


func test_visual_grigris_are_valid() -> void:
	var db: ContentDB = ContentDB.shared()
	var n: int = 0
	for g: Dictionary in db.list("grigris"):
		if not g.has("visual"):
			continue
		n += 1
		check(VisualCurse.KINDS.has(String(g["visual"]["kind"])), "%s : type connu" % g["id"])
		check((g["tags"] as Array).has("curse_fx"), "%s : étiquette curse_fx" % g["id"])
		check(not (g["effects"] as Array).is_empty(), "%s : un avantage compense le malus" % g["id"])
	check(n >= 7, "au moins 7 grigris à malus visuel (%d)" % n)


func test_strengths_stack_and_cap() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("lea", 0, 3)
	eq(VisualCurse.strengths(c.run, c.db).size(), 0, "aucun malus au départ")
	ShopModel.acquire_grigri(c.run, c.db, "g_gin_flask", &"")
	ShopModel.acquire_grigri(c.run, c.db, "g_gin_flask", &"")
	var s: Dictionary[String, float] = VisualCurse.strengths(c.run, c.db)
	eq(s.get("drunk", 0.0), 1.0, "deux flasques : plafonné à 1")
	for g: GrigriInstance in c.run.grigris:
		g.disabled = true
	eq(VisualCurse.strengths(c.run, c.db).size(), 0, "grigri désactivé : pas de malus")
