extends Node
## Langue courante et textes du contenu data-driven (champs name_fr / name_en...).

const SUPPORTED: Array[String] = ["fr", "en"]
const TRANSLATION_PATTERN: String = "res://localization/strings.%s.translation"


## Au-delà de COMPACT_FROM, les nombres s'écrivent en abrégé (12,3 M ; 4,56 Md) ; au-delà des
## unités connues, en notation scientifique. Les grands builds dépassent vite le milliard.
const COMPACT_FROM: float = 100000.0
const UNITS_FR: Array[String] = ["", "k", "M", "Md", "Bn", "Bd", "Tn"]
const UNITS_EN: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi"]


func _ready() -> void:
	for l: String in SUPPORTED:
		var path: String = TRANSLATION_PATTERN % l
		if ResourceLoader.exists(path):
			TranslationServer.add_translation(load(path) as Translation)


func locale() -> String:
	var l: String = TranslationServer.get_locale().substr(0, 2)
	return l if SUPPORTED.has(l) else "fr"


func set_locale(l: String) -> void:
	Settings.set_value("game", "locale", l)


func t(entry: Dictionary, field: String) -> String:
	return ContentDB.text(entry, field, locale())


func name_of(cat: String, entry_id: String) -> String:
	return t(DataRegistry.db.get_entry(cat, entry_id), "name")


func desc_of(cat: String, entry_id: String) -> String:
	return t(DataRegistry.db.get_entry(cat, entry_id), "desc")


func flavor_of(cat: String, entry_id: String) -> String:
	return t(DataRegistry.db.get_entry(cat, entry_id), "flavor")


## Nom lisible d'un emplacement de pari.
func bet_label(spot_id: String) -> String:
	var spot: BetSpot = BetCatalog.get_spot(spot_id)
	if spot == null:
		return spot_id
	var kind_name: String = tr("BET_" + String(spot.kind).to_upper())
	match spot.kind:
		&"straight", &"split", &"street", &"corner", &"six_line":
			var nums: PackedStringArray = []
			for n: int in spot.numbers:
				nums.append(str(n))
			return "%s %s" % [kind_name, "-".join(nums)]
		&"dozen", &"column":
			return "%s %d" % [kind_name, int(spot_id.split(":")[1]) + 1]
	return kind_name


func format_number(v: float) -> String:
	if absf(v) >= COMPACT_FROM:
		return format_compact(v)
	var n: int = int(round(v))
	var s: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = (" " if locale() == "fr" else ",") + out
	return ("-" if n < 0 else "") + out


## Abrégé à trois chiffres significatifs : 123 k, 12,3 M, 1,23 Md (FR) / 123K, 12.3M, 1.23B (EN).
func format_compact(v: float) -> String:
	var fr: bool = locale() == "fr"
	var units: Array[String] = UNITS_FR if fr else UNITS_EN
	var a: float = absf(v)
	var i: int = 0
	while a >= 999.95 and i < units.size() - 1:
		a /= 1000.0
		i += 1
	var sign: String = "-" if v < 0.0 else ""
	if a >= 999.95:
		var e: int = int(floor(log(absf(v)) / log(10.0)))
		var m: String = "%.2f" % (absf(v) / pow(10.0, float(e)))
		return sign + (m.replace(".", ",") if fr else m) + "e+" + str(e)
	var digits: String = "%.2f" % a if a < 9.995 else ("%.1f" % a if a < 99.95 else "%d" % int(round(a)))
	if fr:
		digits = digits.replace(".", ",")
	return sign + digits + (" " if fr and units[i] != "" else "") + units[i]

