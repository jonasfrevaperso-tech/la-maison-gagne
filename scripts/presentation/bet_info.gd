class_name BetInfo
extends RefCounted
## Texte d'infobulle d'un emplacement de pari : nom, cote, gain potentiel, probabilité.


static func describe(spot_id: String, hide_odds: bool, wheel: WheelModel, chip_value: int, placed: int) -> String:
	var spot: BetSpot = BetCatalog.get_spot(spot_id)
	if spot == null:
		return ""
	var lines: PackedStringArray = []
	lines.append(Localization.bet_label(spot_id))
	if hide_odds:
		lines.append(TranslationServer.translate("BET_ODDS_HIDDEN"))
	else:
		var mult: int = spot.odds + (1 if Balance.b("bets.stake_returned") else 0)
		lines.append(TranslationServer.translate("BET_ODDS") % [spot.odds, mult * chip_value])
	if wheel != null:
		var covered: int = 0
		for p: Pocket in wheel.pockets:
			if spot.covers(p.number) or (spot.kind == &"red" and p.color() == &"red") or (spot.kind == &"black" and p.color() == &"black"):
				covered += 1
		lines.append(TranslationServer.translate("BET_RAW_CHANCE") % (100.0 * float(covered) / float(maxi(wheel.size(), 1))))
	var limits: Dictionary = Balance.dict("bets.table_limits")
	if limits.has(String(spot.kind)):
		lines.append(TranslationServer.translate("BET_LIMIT") % int(limits[String(spot.kind)]))
	if placed > 0:
		lines.append(TranslationServer.translate("BET_PLACED") % placed)
	if spot.outside:
		lines.append(TranslationServer.translate("BET_ZERO_WARNING"))
	return "\n".join(lines)
