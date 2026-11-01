class_name WheelLayout
extends RefCounted
## Faits immuables de la roulette européenne (ordre des cases, couleurs, tapis).
## Ce ne sont pas des nombres de tuning : ce sont les règles du jeu réel.

const POCKET_COUNT: int = 37
const ORDER: Array[int] = [
	0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
	5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26,
]
const RED: Array[int] = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const TABLE_ROWS: int = 3
const TABLE_COLS: int = 12
const HALF: int = 18
const DOZEN_SIZE: int = 12

const COLOR_RED: StringName = &"red"
const COLOR_BLACK: StringName = &"black"
const COLOR_GREEN: StringName = &"green"


static func color_of(number: int) -> StringName:
	if number == 0:
		return COLOR_GREEN
	return COLOR_RED if RED.has(number) else COLOR_BLACK


static func index_of(number: int) -> int:
	return ORDER.find(number)


static func number_at(index: int) -> int:
	return ORDER[posmod(index, POCKET_COUNT)]


## Distance signée la plus courte entre deux index de roue.
static func wheel_distance(from_index: int, to_index: int) -> int:
	var d: int = posmod(to_index - from_index, POCKET_COUNT)
	if d > POCKET_COUNT / 2:
		d -= POCKET_COUNT
	return d


## Colonne du tapis (0..11) et rangée (0 = bas : 1,4,7.. ; 2 = haut : 3,6,9..).
static func table_col(number: int) -> int:
	return (number - 1) / TABLE_ROWS


static func table_row(number: int) -> int:
	return (number - 1) % TABLE_ROWS


static func number_on_table(col: int, row: int) -> int:
	return col * TABLE_ROWS + row + 1


static func dozen_of(number: int) -> int:
	if number == 0:
		return -1
	return (number - 1) / DOZEN_SIZE


static func is_low(number: int) -> bool:
	return number >= 1 and number <= HALF


static func is_high(number: int) -> bool:
	return number > HALF
