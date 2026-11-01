class_name PocketInfo
extends RefCounted
## Textes et couleurs d'affichage des cases (infobulles, codex).

const TYPE_COLORS: Dictionary = {
	"golden": Color("f2d27a"),
	"ruby": Color("ff3b5c"),
	"glass": Color("bfe9ff"),
	"magnet": Color("8a8f9c"),
	"mirror": Color("d9e6f2"),
	"bomb": Color("ff8a3d"),
	"ghost": Color("b8b2c2"),
	"joker": Color("ff2e88"),
	"twin": Color("29e0ff"),
	"thorn": Color("2ee6a8"),
	"sticky": Color("c9b26b"),
	"prism": Color("e0b3ff"),
	"thief": Color("6b6275"),
	"timed": Color("f5f0e6"),
	"cursed": Color("b03aff"),
	"sacred": Color("fff6d6"),
	"lightning": Color("fff35c"),
	"double_zero": Color("0f8a4f"),
	"steel": Color("9aa4b5"),
	"lucky": Color("2ee6a8"),
	"echo": Color("7aa7ff"),
	"burnt": Color("3a2a22"),
	"vault": Color("d4af37"),
	"sprout": Color("6ee66e"),
}
const EDITION_COLORS: Dictionary = {
	"brillante": Color("ffffff"),
	"holo": Color("29e0ff"),
	"polychrome": Color("ff2e88"),
	"noire": Color("000000"),
}
const SEAL_COLORS: Dictionary = {
	"seal_gold": Color("f2d27a"),
	"seal_red": Color("ff3b5c"),
	"seal_blue": Color("3d8bff"),
	"seal_purple": Color("b03aff"),
	"seal_green": Color("2ee6a8"),
	"seal_black": Color("16141a"),
}


static func type_color(t: StringName) -> Color:
	return TYPE_COLORS.get(String(t), Palette.GOLD) as Color


static func edition_color(e: StringName) -> Color:
	return EDITION_COLORS.get(String(e), Palette.IVORY) as Color


static func seal_color(s: StringName) -> Color:
	return SEAL_COLORS.get(String(s), Palette.IVORY) as Color


static func describe(p: Pocket, db: ContentDB, probability: float = -1.0) -> String:
	var loc: String = Localization.locale()
	var lines: PackedStringArray = []
	var tdef: Dictionary = db.get_entry("pocket_types", String(p.type_id))
	lines.append("%d — %s" % [p.number, ContentDB.text(tdef, "name", loc)])
	lines.append(ContentDB.text(tdef, "desc", loc))
	if p.level > 0:
		lines.append(TranslationServer.translate("POCKET_LEVEL") % [p.level, p.level * Balance.i("score.pocket_level_chips")])
	if p.edition != &"":
		var e: Dictionary = db.get_entry("editions", String(p.edition))
		lines.append("◆ %s : %s" % [ContentDB.text(e, "name", loc), ContentDB.text(e, "desc", loc)])
	if p.seal != &"":
		var s: Dictionary = db.get_entry("seals", String(p.seal))
		lines.append("● %s : %s" % [ContentDB.text(s, "name", loc), ContentDB.text(s, "desc", loc)])
	if probability >= 0.0:
		lines.append(TranslationServer.translate("POCKET_PROBABILITY") % (probability * 100.0))
	return "\n".join(lines)
