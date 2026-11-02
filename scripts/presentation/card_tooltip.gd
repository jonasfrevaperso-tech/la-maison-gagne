class_name CardTooltip
extends RefCounted
## Infobulle riche : nom, rareté, description, phrase d'ambiance, famille (build) et paliers, prix.

const WIDTH: float = 380.0
const TAG_GLYPHS: Dictionary = {
	"mult": "✚",
	"xmult": "✖",
	"chips": "◉",
	"economy": "$",
	"money": "$",
	"color": "◐",
	"parity": "⚌",
	"bets": "♣",
	"straight": "│",
	"outside": "◫",
	"split": "‖",
	"dozen": "⑫",
	"column": "▥",
	"zero": "0",
	"safety": "⛨",
	"streak": "≋",
	"ball": "●",
	"precision": "◎",
	"control": "◎",
	"budget": "▤",
	"growth": "↑",
	"decay": "↓",
	"chance": "⚄",
	"copy": "❐",
	"retrigger": "↻",
	"pockets": "◔",
	"golden": "★",
	"glass": "◇",
	"slots": "▢",
	"interest": "%",
	"repeat": "⟳",
	"destroy": "✸",
	"curse": "☠",
	"debt": "✎",
	"fortune": "✧",
	"contract": "✍",
	"ghost": "☁",
	"spins": "⟲",
	"corner": "▦",
	"edition": "◆",
	"range": "↕",
	"seal": "●",
	"six_line": "⚏",
	"street": "≡",
}


static func build(kind: String, entry_id: String, edition: StringName, counter: float, price: int) -> Control:
	var cat: String = {"fortune": "fortunes", "contract": "contracts", "pocket_card": "pocket_types"}.get(kind, "grigris")
	var e: Dictionary = DataRegistry.db.get_entry(cat, entry_id)
	var panel: PanelContainer = PanelContainer.new()
	var rarity: String = String(e.get("rarity", "common"))
	panel.add_theme_stylebox_override("panel", UiKit.flat(Palette.INK, Palette.rarity_color(rarity), 2, 6, 12))
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UiKit.label(Localization.t(e, "name"), UiKit.SIZE_H2 - 6, Palette.GOLD_LIGHT, "display"))
	if kind == "grigri":
		box.add_child(
			UiKit.label(TranslationServer.translate("RARITY_" + rarity.to_upper()), UiKit.SIZE_SMALL, Palette.rarity_color(rarity))
		)
	var desc: RichTextLabel = UiKit.rich(_highlight(Localization.t(e, "desc")), UiKit.SIZE_BODY - 4)
	desc.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_child(desc)
	if absf(counter) > 0.001:
		box.add_child(
			UiKit.label(TranslationServer.translate("CARD_COUNTER") % str(snappedf(counter, 0.01)), UiKit.SIZE_SMALL, Palette.EMERALD)
		)
	if edition != &"":
		var ed: Dictionary = DataRegistry.db.get_entry("editions", String(edition))
		box.add_child(
			UiKit.label(
				"◆ %s : %s" % [Localization.t(ed, "name"), Localization.t(ed, "desc")],
				UiKit.SIZE_SMALL,
				PocketInfo.edition_color(edition).lightened(0.3)
			)
		)
	var flavor: Label = UiKit.label("« %s »" % Localization.t(e, "flavor"), UiKit.SIZE_SMALL, Palette.SMOKE)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_child(flavor)
	# Famille (build) : plus parlant qu'une liste d'étiquettes.
	if cat == "grigris" and String(e.get("family", "")) != "":
		var fid: String = String(e["family"])
		var mine: bool = GameState.has_active_run() and GameState.run().has_grigri(entry_id)
		box.add_child(HSeparator.new())
		box.add_child(FamilyUi.info_block(fid, WIDTH, not mine))
	if price >= 0:
		box.add_child(UiKit.label(TranslationServer.translate("CARD_PRICE") % price, UiKit.SIZE_SMALL, Palette.GOLD))
	return panel


## Colore les mots-clés Jetons / Mult / $ dans les descriptions.
static func _highlight(t: String) -> String:
	var s: String = t
	for w: String in ["Jetons", "Chips"]:
		s = s.replace(w, "[color=#3d8bff]%s[/color]" % w)
	for w2: String in ["Mult"]:
		s = s.replace(w2, "[color=#ff3b5c]%s[/color]" % w2)
	return s
