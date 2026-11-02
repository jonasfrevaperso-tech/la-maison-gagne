class_name CodexScreen
extends MetaScreen
## Codex : collection de tout le contenu. Ce qui n'a pas encore été vu reste masqué.

const CARD_COLS: int = 12
const SECTIONS: Array[Array] = [
	["grigris", "grigri", "CODEX_GRIGRIS"],
	["pocket_types", "pocket_card", "CODEX_POCKETS"],
	["fortunes", "fortune", "CODEX_FORTUNES"],
	["contracts", "contract", "CODEX_CONTRACTS"],
]


func screen_title() -> String:
	return tr("MENU_CODEX")


func build() -> void:
	var seen: Dictionary = SaveSystem.profile.get("seen", {})
	for sec: Array in SECTIONS:
		var cat: String = String(sec[0])
		var ids: Array[String] = DataRegistry.db.ids(cat)
		if cat == "pocket_types":
			ids.erase("standard")
		var seen_list: Array = seen.get(_seen_key(cat), [])
		var known: int = 0
		for eid: String in ids:
			if seen_list.has(eid) or cat == "pocket_types":
				known += 1
		section("%s — %d / %d" % [tr(String(sec[2])), known, ids.size()])
		if cat == "grigris":
			# Grigris rangés par famille (build), chaque famille présentée avec ses paliers.
			for fam: Dictionary in DataRegistry.db.list("families"):
				var fid: String = String(fam["id"])
				var members: Array[String] = ids.filter(func(x: String) -> bool: return FamilyUi.of_grigri(x) == fid)
				content.add_child(_family_header(fam))
				_fill_grid(grid(CARD_COLS), members, seen_list, String(sec[1]), cat)
		else:
			_fill_grid(grid(CARD_COLS), ids, seen_list, String(sec[1]), cat)
	section(tr("CODEX_CREDITORS"))
	for c: Dictionary in DataRegistry.db.list("creditors"):
		if bool(c.get("secret", false)) and not seen.get("creditors", []).has(c["id"]):
			continue
		var r: RichTextLabel = UiKit.rich(
			(
				"[color=#%s][b]%s[/b][/color] — %s [i](%s)[/i]"
				% [c.get("color", "f2d27a"), Localization.t(c, "name"), Localization.t(c, "desc"), Localization.t(c, "flavor")]
			),
			UiKit.SIZE_BODY - 4
		)
		r.custom_minimum_size = Vector2(1600, 0)
		content.add_child(r)


func _fill_grid(g: GridContainer, ids: Array[String], seen_list: Array, kind: String, cat: String) -> void:
	for eid2: String in ids:
		if seen_list.has(eid2) or cat == "pocket_types":
			var card: GrigriCard = GrigriCard.new().configure(kind, eid2)
			card.draggable = false
			g.add_child(card)
		else:
			var unknown: Panel = Panel.new()
			unknown.custom_minimum_size = GrigriCard.CARD_SIZE
			unknown.tooltip_text = tr("CODEX_UNKNOWN")
			unknown.focus_mode = Control.FOCUS_ALL
			var q: Label = UiKit.title("?", UiKit.SIZE_H1)
			q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			unknown.add_child(q)
			g.add_child(unknown)


## En-tête d'une famille : emblème, nom, description et paliers (2 / 3 / 5).
func _family_header(fam: Dictionary) -> Control:
	var fid: String = String(fam["id"])
	var col: Color = FamilyUi.color(fid)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var ic: TextureRect = TextureRect.new()
	ic.texture = FamilyUi.icon(fid)
	ic.custom_minimum_size = Vector2(48, 48)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var tiers: PackedStringArray = []
	for td: Variant in fam.get("tiers", []):
		var tier: Dictionary = td as Dictionary
		tiers.append("[b]%d[/b] : %s" % [int(tier.get("n", 0)), CardTooltip._highlight(Localization.t(tier, "desc"))])
	var fam_name: String = Localization.t(fam, "name").to_upper()
	var head: String = "[color=#%s][b]%s[/b][/color] — %s" % [col.to_html(false), fam_name, Localization.t(fam, "desc")]
	var txt: String = "%s\n[color=#%s]%s[/color]" % [head, Palette.IVORY.to_html(false), "   ·   ".join(tiers)]
	var r: RichTextLabel = UiKit.rich(txt, UiKit.SIZE_BODY - 6)
	r.custom_minimum_size = Vector2(1500, 0)
	row.add_child(r)
	return row


func _seen_key(cat: String) -> String:
	return {"grigris": "grigris", "pocket_types": "pockets", "fortunes": "fortunes", "contracts": "contracts"}.get(cat, cat)
