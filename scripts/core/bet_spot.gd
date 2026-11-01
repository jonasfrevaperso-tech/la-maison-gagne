class_name BetSpot
extends RefCounted
## Un emplacement de pari sur le tapis (ex. « split:17-20 », « red »).

var id: String = ""
var kind: StringName = &""
var numbers: Array[int] = []
var odds: int = 0
var outside: bool = false


func _init(p_id: String, p_kind: StringName, p_numbers: Array[int], p_odds: int, p_outside: bool) -> void:
	id = p_id
	kind = p_kind
	numbers = p_numbers
	odds = p_odds
	outside = p_outside


func covers(n: int) -> bool:
	return numbers.has(n)
