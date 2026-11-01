extends TestCase
## Règles de base : roue, catalogue de paris, mises, RNG.


func test_wheel_layout_is_european() -> void:
	eq(WheelLayout.ORDER.size(), 37, "37 cases")
	var seen: Dictionary = {}
	for n: int in WheelLayout.ORDER:
		seen[n] = true
	eq(seen.size(), 37, "numéros uniques")
	var reds: int = 0
	var blacks: int = 0
	for n: int in range(1, 37):
		if WheelLayout.color_of(n) == WheelLayout.COLOR_RED:
			reds += 1
		else:
			blacks += 1
	eq(reds, 18, "18 rouges")
	eq(blacks, 18, "18 noirs")
	eq(WheelLayout.color_of(0), WheelLayout.COLOR_GREEN, "zéro vert")


func test_bet_catalog_counts() -> void:
	var counts: Dictionary = {}
	for s: BetSpot in BetCatalog.all():
		counts[s.kind] = int(counts.get(s.kind, 0)) + 1
	eq(counts[&"straight"], 37, "pleins")
	eq(counts[&"split"], 60, "chevaux")
	eq(counts[&"street"], 12, "transversales")
	eq(counts[&"corner"], 23, "carrés (dont 0-1-2-3)")
	eq(counts[&"six_line"], 11, "sixains")
	eq(counts[&"dozen"], 3, "douzaines")
	eq(counts[&"column"], 3, "colonnes")
	eq(BetCatalog.get_spot("red").numbers.size(), 18, "rouge couvre 18")
	eq(BetCatalog.get_spot("split:17-20").numbers, [17, 20] as Array[int], "cheval 17-20")
	check(BetCatalog.get_spot("corner:1").covers(5), "carré 1-2-4-5 couvre 5")
	check(BetCatalog.get_spot("column:2").covers(36), "colonne 3 couvre 36")


func test_bet_slip_budget_and_limits() -> void:
	var slip: BetSlip = BetSlip.new()
	slip.budget = 4
	eq(slip.place("straight:17"), BetSlip.PlaceResult.OK)
	eq(slip.place("straight:17"), BetSlip.PlaceResult.OK)
	eq(slip.place("straight:17"), BetSlip.PlaceResult.TABLE_LIMIT, "limite du plein")
	eq(slip.place("red", 2), BetSlip.PlaceResult.OK)
	eq(slip.place("black"), BetSlip.PlaceResult.NO_BUDGET)
	eq(slip.total(), 4)
	eq(slip.undo(), "red")
	eq(slip.total(), 3)
	slip.remove_one("straight:17")
	eq(int(slip.chips["straight:17"]), 1)
	eq(slip.place("nope"), BetSlip.PlaceResult.UNKNOWN_SPOT)
	slip.allowed_kinds = [&"corner"]
	eq(slip.place("black"), BetSlip.PlaceResult.FORBIDDEN, "interdit par le créancier")


func test_rng_streams_are_deterministic_and_independent() -> void:
	var a: RngStreams = RngStreams.new(42)
	var b: RngStreams = RngStreams.new(42)
	for _i: int in 10:
		eq(a.randi_range_in(RngStreams.WHEEL, 0, 1000), b.randi_range_in(RngStreams.WHEEL, 0, 1000))
	# Consommer le flux cosmétique ne change pas le flux roue.
	var c: RngStreams = RngStreams.new(7)
	var d: RngStreams = RngStreams.new(7)
	for _i: int in 50:
		c.randf_in(RngStreams.COSMETIC)
	eq(c.randi_range_in(RngStreams.WHEEL, 0, 1 << 30), d.randi_range_in(RngStreams.WHEEL, 0, 1 << 30), "flux indépendants")
	# Sérialisation exacte.
	var e: RngStreams = RngStreams.new(99)
	e.randf_in(RngStreams.SHOP)
	var saved: Dictionary = e.to_dict()
	var expected: float = e.randf_in(RngStreams.SHOP)
	var f: RngStreams = RngStreams.new()
	f.from_dict(saved)
	eq(f.randf_in(RngStreams.SHOP), expected, "reprise exacte du flux")


func test_throw_distribution_sums_to_one() -> void:
	for prec: int in range(1, 8):
		var p: ThrowResolver.ThrowParams = ThrowResolver.ThrowParams.new()
		p.target_index = 5
		p.precision = prec
		var dist: Array[float] = ThrowResolver.distribution(37, p)
		var total: float = 0.0
		for x: float in dist:
			total += x
		near(total, 1.0, 0.0001, "somme précision %d" % prec)
		check(dist[5] > dist[20], "la cible est plus probable qu'une case lointaine")


func test_throw_resolution_matches_distribution() -> void:
	var rng: RngStreams = RngStreams.new(1234)
	var p: ThrowResolver.ThrowParams = ThrowResolver.ThrowParams.new()
	p.target_index = 10
	p.precision = 1
	var hits: int = 0
	var n: int = 4000
	for _i: int in n:
		var r: ThrowResolver.ThrowResult = ThrowResolver.resolve(37, p, rng)
		if r.landing_index == 10:
			hits += 1
	var expected: float = ThrowResolver.distribution(37, p)[10]
	near(float(hits) / float(n), expected, 0.025, "fréquence observée ≈ théorique")


func test_magnet_attracts() -> void:
	var rng: RngStreams = RngStreams.new(5)
	var p: ThrowResolver.ThrowParams = ThrowResolver.ThrowParams.new()
	p.target_index = 10
	p.precision = 7
	p.zone_width_override = 1
	p.control_bonus = 1.0
	p.attractors = {11: 1.0}
	var r: ThrowResolver.ThrowResult = ThrowResolver.resolve(37, p, rng)
	eq(r.landing_index, 11, "aimant à 100 %")
	eq(r.attracted_from, 10)


func test_acts_mapping() -> void:
	var r: RunState = RunState.new()
	var expected: Array[int] = [1, 1, 1, 2, 2, 2, 3, 3]
	for t: int in range(1, 9):
		r.tier = t
		eq(r.act(), expected[t - 1], "palier %d" % t)
