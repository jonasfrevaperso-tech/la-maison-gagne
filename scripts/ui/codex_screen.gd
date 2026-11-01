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
		var g: GridContainer = grid(CARD_COLS)
		for eid2: String in ids:
			if seen_list.has(eid2) or cat == "pocket_types":
				var card: GrigriCard = GrigriCard.new().configure(String(sec[1]), eid2)
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


func _seen_key(cat: String) -> String:
	return {"grigris": "grigris", "pocket_types": "pockets", "fortunes": "fortunes", "contracts": "contracts"}.get(cat, cat)
