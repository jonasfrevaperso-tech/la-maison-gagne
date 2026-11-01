class_name GrigriInstance
extends RefCounted
## Un grigri possédé par le joueur (état propre : compteur évolutif, édition, verrou).

var id: String = ""
var uid: int = 0
var edition: StringName = &""
var counter: float = 0.0
var locked: bool = false
var disabled: bool = false
var sell_bonus: int = 0


func _init(p_id: String = "", p_uid: int = 0) -> void:
	id = p_id
	uid = p_uid


func to_dict() -> Dictionary:
	return {
		"id": id, "uid": uid, "edition": String(edition), "counter": counter,
		"locked": locked, "disabled": disabled, "sell_bonus": sell_bonus,
	}


static func from_dict(d: Dictionary) -> GrigriInstance:
	var g: GrigriInstance = GrigriInstance.new(String(d.get("id", "")), int(d.get("uid", 0)))
	g.edition = StringName(String(d.get("edition", "")))
	g.counter = float(d.get("counter", 0.0))
	g.locked = bool(d.get("locked", false))
	g.disabled = bool(d.get("disabled", false))
	g.sell_bonus = int(d.get("sell_bonus", 0))
	return g
