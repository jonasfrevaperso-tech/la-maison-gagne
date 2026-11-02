class_name WheelModel
extends RefCounted
## La roue du joueur : liste ordonnée de cases (taille variable).

const MIN_SIZE: int = 8

var pockets: Array[Pocket] = []
var next_uid: int = 1


static func standard() -> WheelModel:
	var w: WheelModel = WheelModel.new()
	for n: int in WheelLayout.ORDER:
		w.pockets.append(Pocket.new(n, w._take_uid()))
	return w


func _take_uid() -> int:
	var u: int = next_uid
	next_uid += 1
	return u


func size() -> int:
	return pockets.size()


func at(index: int) -> Pocket:
	return pockets[posmod(index, pockets.size())]


func index_of_uid(p_uid: int) -> int:
	for i: int in pockets.size():
		if pockets[i].uid == p_uid:
			return i
	return -1


func first_index_of_number(n: int) -> int:
	for i: int in pockets.size():
		if pockets[i].number == n:
			return i
	return -1


func neighbors(index: int, radius: int) -> Array[int]:
	var out: Array[int] = []
	for o: int in range(-radius, radius + 1):
		if o != 0:
			out.append(posmod(index + o, pockets.size()))
	return out


## Case diamétralement opposée (utilisée par la case Miroir).
func opposite_index(index: int) -> int:
	return posmod(index + pockets.size() / 2, pockets.size())


func count_type(t: StringName) -> int:
	var c: int = 0
	for p: Pocket in pockets:
		if p.type_id == t:
			c += 1
	return c


func count_with_edition() -> int:
	var c: int = 0
	for p: Pocket in pockets:
		if p.edition != &"":
			c += 1
	return c


## Ordre des cases (identifiants) : sauvegardé avant un mélange temporaire.
func order_uids() -> Array[int]:
	var out: Array[int] = []
	for p: Pocket in pockets:
		out.append(p.uid)
	return out


## Remet les cases dans l'ordre donné ; les cases absentes de l'ordre gardent leur place relative à la fin.
func reorder_by_uids(order: Array) -> void:
	var by_uid: Dictionary = {}
	for p: Pocket in pockets:
		by_uid[p.uid] = p
	var out: Array[Pocket] = []
	for u: Variant in order:
		if by_uid.has(int(u)):
			out.append(by_uid[int(u)])
			by_uid.erase(int(u))
	for p2: Pocket in pockets:
		if by_uid.has(p2.uid):
			out.append(p2)
	pockets = out


func swap(i: int, j: int) -> void:
	var t: Pocket = pockets[i]
	pockets[i] = pockets[j]
	pockets[j] = t


func count_with_seal() -> int:
	var c: int = 0
	for p: Pocket in pockets:
		if p.seal != &"":
			c += 1
	return c


func count_number(n: int) -> int:
	var c: int = 0
	for p: Pocket in pockets:
		if p.number == n:
			c += 1
	return c


func insert_copy(after_index: int, source: Pocket) -> Pocket:
	var p: Pocket = source.duplicate_pocket(_take_uid())
	pockets.insert(posmod(after_index, pockets.size()) + 1, p)
	return p


func insert_number(after_index: int, n: int) -> Pocket:
	var p: Pocket = Pocket.new(n, _take_uid())
	pockets.insert(posmod(after_index, pockets.size()) + 1, p)
	return p


func can_remove() -> bool:
	return pockets.size() > MIN_SIZE


func remove_at(index: int) -> bool:
	if not can_remove():
		return false
	pockets.remove_at(posmod(index, pockets.size()))
	return true


func to_dict() -> Dictionary:
	var arr: Array = []
	for p: Pocket in pockets:
		arr.append(p.to_dict())
	return {"pockets": arr, "next_uid": next_uid}


static func from_dict(d: Dictionary) -> WheelModel:
	var w: WheelModel = WheelModel.new()
	for pd: Variant in d.get("pockets", []):
		w.pockets.append(Pocket.from_dict(pd as Dictionary))
	w.next_uid = int(d.get("next_uid", w.pockets.size() + 1))
	return w
