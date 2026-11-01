class_name Palette
extends RefCounted
## Palette fixée (cf. docs/ART_BIBLE.md). Toute couleur d'UI/présentation vient d'ici.

const INK: Color = Color("0a080d")
const VELVET_DEEP: Color = Color("1a0c14")
const VELVET: Color = Color("3a1228")
const FELT: Color = Color("0d3b2a")
const FELT_LIGHT: Color = Color("155c40")
const GOLD: Color = Color("d4af37")
const GOLD_LIGHT: Color = Color("f2d27a")
const GOLD_DARK: Color = Color("8a6d1e")
const IVORY: Color = Color("f5f0e6")
const SMOKE: Color = Color("6b6275")
const SMOKE_DARK: Color = Color("2b2631")
const MAGENTA: Color = Color("ff2e88")
const CYAN: Color = Color("29e0ff")
const EMERALD: Color = Color("2ee6a8")
const ROULETTE_RED: Color = Color("c8102e")
const ROULETTE_BLACK: Color = Color("16141a")
const ZERO_GREEN: Color = Color("0f8a4f")
const DANGER: Color = Color("ff4d3d")
const CHIPS_BLUE: Color = Color("3d8bff")
const MULT_RED: Color = Color("ff3b5c")

const RARITY: Dictionary = {
	"common": Color("b8b2c2"), "rare": Color("29e0ff"), "legendary": Color("f2d27a"), "cursed": Color("b03aff"),
}

## Variantes daltoniennes : rouge/noir distinguables par luminance + motif.
const COLORBLIND_RED: Color = Color("e66100")
const COLORBLIND_BLACK: Color = Color("1f2a44")


static func pocket_color(c: StringName) -> Color:
	var cb: bool = Settings.s("access", "colorblind") != "off"
	match c:
		&"red":
			return COLORBLIND_RED if cb else ROULETTE_RED
		&"black":
			return COLORBLIND_BLACK if cb else ROULETTE_BLACK
	return ZERO_GREEN


static func rarity_color(rarity: String) -> Color:
	return RARITY.get(rarity, IVORY) as Color
