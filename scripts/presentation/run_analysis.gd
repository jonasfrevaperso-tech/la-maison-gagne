class_name RunAnalysis
extends RefCounted
## Explique une défaite et propose des pistes de build (anti-frustration, lisibilité).

const CLOSE_RATIO: float = 0.85
const ZERO_HEAVY: int = 3
const LOW_MULT_GRIGRIS: int = 1


static func explain_defeat(r: RunState, db: ContentDB) -> String:
	var lines: PackedStringArray = []
	var ratio: float = float(r.deadline_score) / maxf(float(r.debt), 1.0)
	lines.append(
		TranslationServer.translate("WHY_MISSING") % [100.0 * (1.0 - ratio), Localization.format_number(float(r.debt - r.deadline_score))]
	)
	if ratio >= CLOSE_RATIO:
		lines.append(TranslationServer.translate("WHY_CLOSE"))
	var deadline_zeros: int = 0
	var lost_spins: int = 0
	for h: Dictionary in r.history:
		if int(h.get("tier", 0)) == r.tier and int(h.get("deadline", -1)) == r.deadline_idx:
			if int(h["n"]) == 0:
				deadline_zeros += 1
			if int(h["won"]) == 0:
				lost_spins += 1
	if deadline_zeros > 0:
		lines.append(TranslationServer.translate("WHY_ZEROS") % deadline_zeros)
	if lost_spins > 0:
		lines.append(TranslationServer.translate("WHY_LOST_SPINS") % lost_spins)
	if r.is_creditor() and r.creditor_id != "":
		lines.append(TranslationServer.translate("WHY_CREDITOR") % Localization.t(db.get_entry("creditors", r.creditor_id), "name"))
	var mult_sources: int = 0
	for g: GrigriInstance in r.grigris:
		var tags: Array = db.get_entry("grigris", g.id).get("tags", [])
		if tags.has("mult") or tags.has("xmult"):
			mult_sources += 1
	if mult_sources <= LOW_MULT_GRIGRIS:
		lines.append(TranslationServer.translate("WHY_LOW_MULT"))
	return "[color=#ff4d3d]" + TranslationServer.translate("WHY_TITLE") + "[/color]\n• " + "\n• ".join(lines)


## Suggestions selon les tags dominants des grigris possédés.
static func build_suggestions(r: RunState, db: ContentDB) -> String:
	var counts: Dictionary = {}
	for g: GrigriInstance in r.grigris:
		for t: Variant in db.get_entry("grigris", g.id).get("tags", []):
			counts[String(t)] = int(counts.get(String(t), 0)) + 1
	var tips: PackedStringArray = []
	var rules: Array[Array] = [
		["straight", "TIP_STRAIGHT"],
		["outside", "TIP_OUTSIDE"],
		["color", "TIP_COLOR"],
		["zero", "TIP_ZERO"],
		["economy", "TIP_ECONOMY"],
		["retrigger", "TIP_RETRIGGER"],
		["copy", "TIP_COPY"],
		["streak", "TIP_STREAK"],
	]
	for rule: Array in rules:
		if int(counts.get(String(rule[0]), 0)) > 0:
			tips.append(TranslationServer.translate(String(rule[1])))
	if not counts.has("xmult"):
		tips.append(TranslationServer.translate("TIP_NEED_XMULT"))
	if r.precision <= 1:
		tips.append(TranslationServer.translate("TIP_PRECISION"))
	return "[color=#29e0ff]" + TranslationServer.translate("TIP_TITLE") + "[/color]\n• " + "\n• ".join(tips)
