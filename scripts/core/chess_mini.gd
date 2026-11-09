class_name ChessMini
extends RefCounted
## Petit moteur d'échecs (2.0, Échecs éclair) : position, coups légaux, échec, mat. Logique pure.
## Ni roque ni prise en passant (les positions des données n'en ont pas besoin) ; un pion qui
## atteint la dernière rangée devient dame. Cases : index = rangée × 8 + colonne, a1 = 0, h8 = 63.
## Pièces : lettres FEN (majuscule = Blancs), "" = case vide.

const KNIGHT_STEPS: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
	Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)]
const KING_STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const ROOK_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const BISHOP_DIRS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var squares: Array[String] = []


static func from_fen(board_fen: String) -> ChessMini:
	var c: ChessMini = ChessMini.new()
	c.squares.resize(64)
	c.squares.fill("")
	var rows: PackedStringArray = board_fen.split(" ")[0].split("/")
	for i: int in mini(rows.size(), 8):
		var rank: int = 7 - i
		var file: int = 0
		for ch: String in rows[i]:
			if ch.is_valid_int():
				file += int(ch)
			elif file < 8:
				c.squares[rank * 8 + file] = ch
				file += 1
	return c


static func sq(file: int, rank: int) -> int:
	return rank * 8 + file


static func coord(s: int) -> Vector2i:
	return Vector2i(s % 8, s / 8)


static func name_of(s: int) -> String:
	return "abcdefgh"[s % 8] + str(s / 8 + 1)


static func is_white(p: String) -> bool:
	return p != "" and p == p.to_upper()


func piece_at(s: int) -> String:
	return squares[s]


func copy() -> ChessMini:
	var c: ChessMini = ChessMini.new()
	c.squares = squares.duplicate()
	return c


## Position après le coup (`move.x` → `move.y`) ; promotion en dame.
func apply(move: Vector2i) -> ChessMini:
	var c: ChessMini = copy()
	var p: String = c.squares[move.x]
	c.squares[move.x] = ""
	var rank: int = move.y / 8
	if p.to_lower() == "p" and (rank == 7 or rank == 0):
		p = "Q" if is_white(p) else "q"
	c.squares[move.y] = p
	return c


func _inside(v: Vector2i) -> bool:
	return v.x >= 0 and v.x < 8 and v.y >= 0 and v.y < 8


## Cases atteintes (pseudo-légales) par la pièce en `s`.
func _targets(s: int) -> Array[int]:
	var out: Array[int] = []
	var p: String = squares[s]
	if p == "":
		return out
	var white: bool = is_white(p)
	var at: Vector2i = coord(s)
	match p.to_lower():
		"n":
			for d: Vector2i in KNIGHT_STEPS:
				_step(at + d, white, out)
		"k":
			for d2: Vector2i in KING_STEPS:
				_step(at + d2, white, out)
		"r":
			_slide(at, ROOK_DIRS, white, out)
		"b":
			_slide(at, BISHOP_DIRS, white, out)
		"q":
			_slide(at, ROOK_DIRS, white, out)
			_slide(at, BISHOP_DIRS, white, out)
		"p":
			var fwd: int = 1 if white else -1
			var one: Vector2i = at + Vector2i(0, fwd)
			if _inside(one) and squares[sq(one.x, one.y)] == "":
				out.append(sq(one.x, one.y))
				var start: int = 1 if white else 6
				var two: Vector2i = at + Vector2i(0, 2 * fwd)
				if at.y == start and squares[sq(two.x, two.y)] == "":
					out.append(sq(two.x, two.y))
			for dx: int in [-1, 1]:
				var cap: Vector2i = at + Vector2i(dx, fwd)
				if _inside(cap):
					var q: String = squares[sq(cap.x, cap.y)]
					if q != "" and is_white(q) != white:
						out.append(sq(cap.x, cap.y))
	return out


func _step(v: Vector2i, white: bool, out: Array[int]) -> void:
	if not _inside(v):
		return
	var q: String = squares[sq(v.x, v.y)]
	if q == "" or is_white(q) != white:
		out.append(sq(v.x, v.y))


func _slide(at: Vector2i, dirs: Array[Vector2i], white: bool, out: Array[int]) -> void:
	for d: Vector2i in dirs:
		var v: Vector2i = at + d
		while _inside(v):
			var q: String = squares[sq(v.x, v.y)]
			if q == "":
				out.append(sq(v.x, v.y))
			else:
				if is_white(q) != white:
					out.append(sq(v.x, v.y))
				break
			v += d


## Vrai si la case `s` est attaquée par le camp `by_white` (les pions attaquent en diagonale).
func attacked(s: int, by_white: bool) -> bool:
	for i: int in 64:
		var p: String = squares[i]
		if p == "" or is_white(p) != by_white:
			continue
		if p.to_lower() == "p":
			var at: Vector2i = coord(i)
			var fwd: int = 1 if by_white else -1
			var tgt: Vector2i = coord(s)
			if tgt.y == at.y + fwd and absi(tgt.x - at.x) == 1:
				return true
			continue
		if s in _targets(i):
			return true
	return false


func king_square(white: bool) -> int:
	return squares.find("K" if white else "k")


func in_check(white: bool) -> bool:
	var k: int = king_square(white)
	return k >= 0 and attacked(k, not white)


## Coups légaux du camp `white` (le roi n'est pas laissé en échec).
func moves(white: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in 64:
		var p: String = squares[i]
		if p == "" or is_white(p) != white:
			continue
		for t: int in _targets(i):
			if squares[t].to_lower() == "k":
				continue
			var mv: Vector2i = Vector2i(i, t)
			if not apply(mv).in_check(white):
				out.append(mv)
	return out


func is_mate(white: bool) -> bool:
	return in_check(white) and moves(white).is_empty()


## Coups blancs qui matent.
func mating_moves() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for mv: Vector2i in moves(true):
		if apply(mv).is_mate(false):
			out.append(mv)
	return out


## Coup en notation « e2e4 » → Vector2i(départ, arrivée) ; (-1, -1) si illisible.
static func parse_uci(uci: String) -> Vector2i:
	if uci.length() < 4:
		return Vector2i(-1, -1)
	var f0: int = "abcdefgh".find(uci[0])
	var f1: int = "abcdefgh".find(uci[2])
	if f0 < 0 or f1 < 0 or not uci[1].is_valid_int() or not uci[3].is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(sq(f0, int(uci[1]) - 1), sq(f1, int(uci[3]) - 1))
