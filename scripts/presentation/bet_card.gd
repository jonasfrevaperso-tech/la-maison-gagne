class_name BetCard
extends RefCounted
## Fiche illustrée d'un emplacement de pari (infobulle souris, curseur manette) : nom à la
## couleur de la famille de pari, pastilles (cote, gain par jeton, limite de table, jetons posés),
## numéros couverts, barre de chance brute et rappel du Zéro pour les paris extérieurs.

const WIDTH: float = 400.0
## Au-delà, les numéros couverts sont résumés par leur nombre.
const MAX_NUMBER_BADGES: int = 6
const NUM_BADGE: float = 30.0
## La chance d'un pari simple (≈ 48,6 %) remplit presque la barre.
const CHANCE_FULL: float = 0.5
const KIND_COLORS: Dictionary[StringName, Color] = {
	&"straight": Color("f2d27a"),
	&"split": Color("29e0ff"),
	&"street": Color("2ee6a8"),
	&"corner": Color("2ee6a8"),
	&"six_line": Color("2ee6a8"),
	&"dozen": Color("3d8bff"),
	&"column": Color("3d8bff"),
	&"red": Color("ff3b5c"),
	&"black": Color("b8b0c4"),
	&"even": Color("f5f0e6"),
	&"odd": Color("f5f0e6"),
	&"low": Color("f5f0e6"),
	&"high": Color("f5f0e6"),
}


static func kind_color(kind: StringName) -> Color:
	return KIND_COLORS.get(kind, Palette.IVORY)


static func build(spot_id: String, hide_odds: bool, wheel: WheelModel, chip_value: int, placed: int) -> PanelContainer:
	var spot: BetSpot = BetCatalog.get_spot(spot_id)
	if spot == null:
		return null
	var col: Color = kind_color(spot.kind)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.flat(Palette.INK, col.darkened(0.15), 2, 6, 12))
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head: VBoxContainer = VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	box.add_child(head)
	head.add_child(UiKit.label(Localization.bet_label(spot_id), UiKit.SIZE_BODY, col, "display"))
	var family: String = "BET_FAMILY_OUTSIDE" if spot.outside else "BET_FAMILY_INSIDE"
	head.add_child(UiKit.label(TranslationServer.translate(family), UiKit.SIZE_SMALL, Palette.SMOKE))
	var pills: HFlowContainer = HFlowContainer.new()
	pills.add_theme_constant_override("h_separation", 8)
	pills.add_theme_constant_override("v_separation", 6)
	box.add_child(pills)
	if hide_odds:
		pills.add_child(PocketCard.pill("odds", Palette.GOLD_LIGHT, "???", ""))
	else:
		var mult: int = spot.odds + (1 if Balance.b("bets.stake_returned") else 0)
		pills.add_child(PocketCard.pill("odds", Palette.GOLD_LIGHT, "%d:1" % spot.odds, "BET_STAT_ODDS"))
		pills.add_child(PocketCard.pill("money", Palette.GOLD, "+%d" % (mult * chip_value), "BET_STAT_PER_CHIP"))
	var limits: Dictionary = Balance.dict("bets.table_limits")
	if limits.has(String(spot.kind)):
		pills.add_child(PocketCard.pill("limit", Palette.DANGER, "%d" % int(limits[String(spot.kind)]), "BET_STAT_LIMIT"))
	if placed > 0:
		pills.add_child(PocketCard.pill("chips", Color("3d8bff"), "%d" % placed, "BET_STAT_PLACED"))
	box.add_child(_numbers_row(spot, wheel))
	if wheel != null:
		box.add_child(PocketCard.chance_row(raw_chance(spot, wheel), CHANCE_FULL, "BET_STAT_CHANCE"))
	if spot.outside:
		var z: HBoxContainer = HBoxContainer.new()
		z.add_theme_constant_override("separation", 8)
		var zt: Texture2D = PocketCard.stat_icon("zero")
		if zt != null:
			z.add_child(PocketCard.tex_rect(zt, PocketCard.STAT_ICON))
		z.add_child(UiKit.label(TranslationServer.translate("BET_ZERO_WARNING"), UiKit.SIZE_SMALL, Palette.EMERALD))
		box.add_child(z)
	return panel


## Part des cases de la roue gagnantes pour ce pari (sans visée).
static func raw_chance(spot: BetSpot, wheel: WheelModel) -> float:
	var covered: int = 0
	for p: Pocket in wheel.pockets:
		if spot.covers(p.number) or (spot.kind == &"red" and p.color() == &"red") or (spot.kind == &"black" and p.color() == &"black"):
			covered += 1
	return float(covered) / float(maxi(wheel.size(), 1))


static func _numbers_row(spot: BetSpot, wheel: WheelModel) -> Control:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var t: Texture2D = PocketCard.stat_icon("covers")
	if t != null:
		h.add_child(PocketCard.tex_rect(t, PocketCard.STAT_ICON))
	var nums: Array[int] = spot.numbers.duplicate()
	if nums.is_empty() and wheel != null:
		for p: Pocket in wheel.pockets:
			if (spot.kind == &"red" and p.color() == &"red") or (spot.kind == &"black" and p.color() == &"black"):
				if not nums.has(p.number):
					nums.append(p.number)
	if nums.size() > MAX_NUMBER_BADGES or nums.is_empty():
		h.add_child(UiKit.label(TranslationServer.translate("BET_STAT_COVERS") % nums.size(), UiKit.SIZE_SMALL, Palette.IVORY))
		return h
	nums.sort()
	for n: int in nums:
		h.add_child(_num_badge(n))
	return h


static func _num_badge(n: int) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(NUM_BADGE, NUM_BADGE)
	var col: Color = Palette.pocket_color(WheelLayout.color_of(n))
	c.draw.connect(
		func() -> void:
			var mid: Vector2 = Vector2(NUM_BADGE, NUM_BADGE) * 0.5
			c.draw_circle(mid, NUM_BADGE * 0.5, Palette.GOLD_DARK)
			c.draw_circle(mid, NUM_BADGE * 0.5 - 2.0, col)
			var f: Font = UiKit.font("mono")
			var fs: int = UiKit.fs(UiKit.SIZE_SMALL)
			var s: String = str(n)
			var w: Vector2 = f.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			c.draw_string(f, Vector2((NUM_BADGE - w.x) * 0.5, mid.y + w.y * 0.3), s, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Palette.IVORY)
	)
	return c
