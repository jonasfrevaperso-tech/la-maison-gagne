class_name BetSlip
extends RefCounted
## Les mises du tour en cours : emplacement -> nombre de jetons.
## L'ordre de pose est conservé (annulation, ordre de résolution du score).

enum PlaceResult { OK, NO_BUDGET, TABLE_LIMIT, UNKNOWN_SPOT, FORBIDDEN }

var chips: Dictionary[String, int] = {}
var order: Array[String] = []
var history: Array[String] = []  # pile d'actions pour l'annulation
var budget: int = 0
var table_limit_bonus: int = 0
var allowed_kinds: Array[StringName] = []  # vide = tout autorisé
var banned_spots: Array[String] = []


func total() -> int:
	var t: int = 0
	for v: int in chips.values():
		t += v
	return t


func remaining() -> int:
	return budget - total()


func is_empty() -> bool:
	return chips.is_empty()


func limit_for(spot: BetSpot) -> int:
	var limits: Dictionary = Balance.dict("bets.table_limits")
	if limits.has(String(spot.kind)):
		return int(limits[String(spot.kind)]) + table_limit_bonus
	return budget


func check(spot_id: String, amount: int = 1) -> PlaceResult:
	var spot: BetSpot = BetCatalog.get_spot(spot_id)
	if spot == null:
		return PlaceResult.UNKNOWN_SPOT
	if banned_spots.has(spot_id) or (not allowed_kinds.is_empty() and not allowed_kinds.has(spot.kind)):
		return PlaceResult.FORBIDDEN
	if remaining() < amount:
		return PlaceResult.NO_BUDGET
	if int(chips.get(spot_id, 0)) + amount > limit_for(spot):
		return PlaceResult.TABLE_LIMIT
	return PlaceResult.OK


func place(spot_id: String, amount: int = 1) -> PlaceResult:
	var r: PlaceResult = check(spot_id, amount)
	if r != PlaceResult.OK:
		return r
	if not chips.has(spot_id):
		order.append(spot_id)
	chips[spot_id] = int(chips.get(spot_id, 0)) + amount
	for _i: int in amount:
		history.append(spot_id)
	return PlaceResult.OK


func undo() -> String:
	if history.is_empty():
		return ""
	var spot_id: String = history.pop_back()
	_decrement(spot_id)
	return spot_id


## Retire un jeton d'un emplacement précis (clic droit).
func remove_one(spot_id: String) -> void:
	if not chips.has(spot_id):
		return
	_decrement(spot_id)
	var idx: int = history.rfind(spot_id)
	if idx >= 0:
		history.remove_at(idx)


func _decrement(spot_id: String) -> void:
	chips[spot_id] -= 1
	if chips[spot_id] <= 0:
		chips.erase(spot_id)
		order.erase(spot_id)


func clear() -> void:
	chips.clear()
	order.clear()
	history.clear()


## Repose un ensemble de mises (répéter le dernier pari, favoris). Ignore ce qui ne passe pas.
func apply_layout(layout: Dictionary) -> int:
	var placed: int = 0
	for spot_id: Variant in layout.keys():
		var n: int = int(layout[spot_id])
		for _i: int in n:
			if place(String(spot_id)) == PlaceResult.OK:
				placed += 1
	return placed


func snapshot() -> Dictionary:
	var d: Dictionary = {}
	for k: String in order:
		d[k] = chips[k]
	return d


func distinct_kinds() -> int:
	var kinds: Dictionary = {}
	for k: String in order:
		kinds[BetCatalog.get_spot(k).kind] = true
	return kinds.size()
