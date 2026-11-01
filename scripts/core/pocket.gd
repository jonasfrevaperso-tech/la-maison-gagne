class_name Pocket
extends RefCounted
## Une case de la roue. La roue est un « deck » : les cases peuvent être
## ajoutées, retirées, transformées, améliorées (niveau), éditées et scellées.

const TYPE_STANDARD: StringName = &"standard"

var uid: int = 0
var number: int = 0
var type_id: StringName = TYPE_STANDARD
var edition: StringName = &""
var seal: StringName = &""
var color_override: StringName = &""
var level: int = 0
var counter: float = 0.0


func _init(p_number: int = 0, p_uid: int = 0) -> void:
	number = p_number
	uid = p_uid


func color() -> StringName:
	if color_override != &"":
		return color_override
	return WheelLayout.color_of(number)


func is_zero() -> bool:
	return number == 0


func duplicate_pocket(new_uid: int) -> Pocket:
	var p: Pocket = Pocket.new(number, new_uid)
	p.type_id = type_id
	p.edition = edition
	p.seal = seal
	p.color_override = color_override
	p.level = level
	return p


func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"number": number,
		"type": String(type_id),
		"edition": String(edition),
		"seal": String(seal),
		"color": String(color_override),
		"level": level,
		"counter": counter,
	}


static func from_dict(d: Dictionary) -> Pocket:
	var p: Pocket = Pocket.new(int(d.get("number", 0)), int(d.get("uid", 0)))
	p.type_id = StringName(String(d.get("type", "standard")))
	p.edition = StringName(String(d.get("edition", "")))
	p.seal = StringName(String(d.get("seal", "")))
	p.color_override = StringName(String(d.get("color", "")))
	p.level = int(d.get("level", 0))
	p.counter = float(d.get("counter", 0.0))
	return p
