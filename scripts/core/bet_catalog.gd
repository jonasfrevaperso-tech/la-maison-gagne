class_name BetCatalog
extends RefCounted
## Génère tous les emplacements de pari valides du tapis européen.
## Les cotes viennent de balance.json (bets.odds).

const KIND_STRAIGHT: StringName = &"straight"
const KIND_SPLIT: StringName = &"split"
const KIND_STREET: StringName = &"street"
const KIND_CORNER: StringName = &"corner"
const KIND_SIX_LINE: StringName = &"six_line"
const KIND_DOZEN: StringName = &"dozen"
const KIND_COLUMN: StringName = &"column"
const EVEN_MONEY: Array[StringName] = [&"red", &"black", &"even", &"odd", &"low", &"high"]
const ALL_KINDS: Array[StringName] = [
	&"straight",
	&"split",
	&"street",
	&"corner",
	&"six_line",
	&"dozen",
	&"column",
	&"red",
	&"black",
	&"even",
	&"odd",
	&"low",
	&"high",
]

static var _spots: Dictionary[String, BetSpot] = {}
static var _ordered: Array[BetSpot] = []


static func all() -> Array[BetSpot]:
	if _ordered.is_empty():
		_build()
	return _ordered


static func get_spot(spot_id: String) -> BetSpot:
	if _ordered.is_empty():
		_build()
	return _spots.get(spot_id, null)


static func has(spot_id: String) -> bool:
	return get_spot(spot_id) != null


static func _odds(kind: StringName) -> int:
	return Balance.i("bets.odds." + String(kind))


static func _is_outside(kind: StringName) -> bool:
	return Balance.arr("bets.outside_kinds").has(String(kind))


static func _add(spot_id: String, kind: StringName, nums: Array[int]) -> void:
	nums.sort()
	var s: BetSpot = BetSpot.new(spot_id, kind, nums, _odds(kind), _is_outside(kind))
	_spots[spot_id] = s
	_ordered.append(s)


static func _build() -> void:
	_spots.clear()
	_ordered.clear()
	var rows: int = WheelLayout.TABLE_ROWS
	var cols: int = WheelLayout.TABLE_COLS
	for n: int in range(0, WheelLayout.POCKET_COUNT):
		_add("straight:%d" % n, KIND_STRAIGHT, [n])
	# Chevaux avec le zéro
	for n: int in range(1, rows + 1):
		_add("split:0-%d" % n, KIND_SPLIT, [0, n])
	for c: int in cols:
		for r: int in rows:
			var n: int = WheelLayout.number_on_table(c, r)
			if r < rows - 1:
				var up: int = WheelLayout.number_on_table(c, r + 1)
				_add("split:%d-%d" % [n, up], KIND_SPLIT, [n, up])
			if c < cols - 1:
				var right: int = WheelLayout.number_on_table(c + 1, r)
				_add("split:%d-%d" % [n, right], KIND_SPLIT, [n, right])
	for c: int in cols:
		var base: int = WheelLayout.number_on_table(c, 0)
		_add("street:%d" % c, KIND_STREET, [base, base + 1, base + 2])
	_add("corner:0", KIND_CORNER, [0, 1, 2, 3])
	for c: int in range(cols - 1):
		for r: int in range(rows - 1):
			var a: int = WheelLayout.number_on_table(c, r)
			var b: int = WheelLayout.number_on_table(c + 1, r)
			_add("corner:%d" % a, KIND_CORNER, [a, a + 1, b, b + 1])
	for c: int in range(cols - 1):
		var base2: int = WheelLayout.number_on_table(c, 0)
		var nums: Array[int] = []
		for k: int in rows * 2:
			nums.append(base2 + k)
		_add("six_line:%d" % c, KIND_SIX_LINE, nums)
	for d: int in rows:
		var dn: Array[int] = []
		for n: int in range(1, WheelLayout.POCKET_COUNT):
			if WheelLayout.dozen_of(n) == d:
				dn.append(n)
		_add("dozen:%d" % d, KIND_DOZEN, dn)
	for r: int in rows:
		var cn: Array[int] = []
		for n: int in range(1, WheelLayout.POCKET_COUNT):
			if WheelLayout.table_row(n) == r:
				cn.append(n)
		_add("column:%d" % r, KIND_COLUMN, cn)
	var em: Dictionary[StringName, Array] = {
		&"red": [],
		&"black": [],
		&"even": [],
		&"odd": [],
		&"low": [],
		&"high": [],
	}
	for n: int in range(1, WheelLayout.POCKET_COUNT):
		em[WheelLayout.color_of(n)].append(n)
		em[&"even" if n % 2 == 0 else &"odd"].append(n)
		em[&"low" if WheelLayout.is_low(n) else &"high"].append(n)
	for k: StringName in EVEN_MONEY:
		var typed: Array[int] = []
		typed.assign(em[k])
		_add(String(k), k, typed)
