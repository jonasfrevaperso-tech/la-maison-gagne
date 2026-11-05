class_name CodexScreen
extends MetaScreen
## Codex : collection de tout le contenu. Ce qui n'a pas encore été vu reste masqué.

const CARD_COLS: int = 12
const TRIAL_COLS: int = 5
## Carton d'épreuve du Codex : illustration pixel art ×2 (160 × 100) et règle dessous.
const TRIAL_ART_SCALE: float = 2.0
const TRIAL_TILE_W: float = 320.0
const UNSEEN_TINT: Color = Color(0.09, 0.07, 0.12)
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
	_trials(seen)
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


## Épreuves du lancer : carton illustré, nom et règle ; masquées tant qu'on ne les a pas jouées.
func _trials(seen: Dictionary) -> void:
	var all: Array[Dictionary] = DataRegistry.db.list("throw_trials")
	var seen_list: Array = seen.get("trials", [])
	var known: int = all.filter(func(e: Dictionary) -> bool: return seen_list.has(e["id"])).size()
	section("%s — %d / %d" % [tr("CODEX_TRIALS"), known, all.size()])
	var to_museum: Button = UiKit.button(tr("CODEX_TO_MUSEUM"), GameState.goto.bind(GameState.SCREEN_MUSEUM))
	to_museum.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content.add_child(to_museum)
	var g: GridContainer = grid(TRIAL_COLS)
	for e: Dictionary in all:
		var box: VBoxContainer = VBoxContainer.new()
		box.custom_minimum_size = Vector2(TRIAL_TILE_W, 0)
		var met: bool = seen_list.has(e["id"])
		var art: TextureRect = TextureRect.new()
		var path: String = "res://assets/trials/trial_%s.png" % String(e["id"])
		if ResourceLoader.exists(path):
			art.texture = load(path) as Texture2D  # silhouette sombre tant qu'elle n'est pas jouée
		art.custom_minimum_size = Vector2(160.0, 100.0) * TRIAL_ART_SCALE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.modulate = Color.WHITE if met else UNSEEN_TINT
		box.add_child(art)
		box.add_child(UiKit.label(Localization.t(e, "name") if met else "???", UiKit.SIZE_BODY, Palette.GOLD_LIGHT, "display"))
		var desc: Label = UiKit.label(Localization.t(e, "desc") if met else tr("CODEX_UNKNOWN"), UiKit.SIZE_SMALL, Palette.IVORY)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(TRIAL_TILE_W, 0)
		box.add_child(desc)
		g.add_child(box)


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


## En-tête d'une famille : emblème, nom, description et paliers (2 / 4 / 7).
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
