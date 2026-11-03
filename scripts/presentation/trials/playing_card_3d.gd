class_name PlayingCard3D
extends Node3D
## Carte à jouer en 3D posée à plat sur un tapis (Blackjack, Plus haut / plus bas) : face ivoire
## avec index aux coins, grande valeur et couleur au centre, dos bordeaux à filets dorés. `face_up`
## retourne la carte (rotation animée par `flip`). Purement cosmétique.

const SIZE: Vector2 = Vector2(0.56, 0.8)
const THICK: float = 0.012
const SUITS: Array[String] = ["♠", "♥", "♦", "♣"]
const RANKS_FR: Array[String] = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R"]
const RANKS_EN: Array[String] = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const FLIP_SPEED: float = 7.0

var face_up: bool = true
## 0 = dos visible, 1 = face visible (suit `face_up`).
var flip: float = 1.0
var _corner_a: Label3D = null
var _corner_b: Label3D = null
var _center: Label3D = null
var _suit: Label3D = null
var _pivot: Node3D = null


func _init() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	var edge: StandardMaterial3D = Stage3D.mat(Color(0.92, 0.88, 0.8), 0.0, 0.6)
	Stage3D.box(_pivot, Vector3(SIZE.x, THICK, SIZE.y), Vector3.ZERO, edge)
	Stage3D.box(_pivot, Vector3(SIZE.x - 0.03, 0.002, SIZE.y - 0.03), Vector3(0, THICK * 0.5 + 0.001, 0),
		Stage3D.mat(Palette.IVORY.darkened(0.12), 0.0, 0.8))
	var back: StandardMaterial3D = Stage3D.mat(Palette.ROULETTE_RED.darkened(0.4), 0.1, 0.5)
	var filet: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.45, 0.35)
	var by: float = -THICK * 0.5 - 0.001
	Stage3D.box(_pivot, Vector3(SIZE.x - 0.03, 0.002, SIZE.y - 0.03), Vector3(0, by, 0), back)
	Stage3D.box(_pivot, Vector3(SIZE.x - 0.1, 0.002, 0.018), Vector3(0, by - 0.0015, SIZE.y * 0.38), filet)
	Stage3D.box(_pivot, Vector3(SIZE.x - 0.1, 0.002, 0.018), Vector3(0, by - 0.0015, -SIZE.y * 0.38), filet)
	Stage3D.box(_pivot, Vector3(0.018, 0.002, SIZE.y * 0.76), Vector3(-SIZE.x * 0.4, by - 0.0015, 0), filet)
	Stage3D.box(_pivot, Vector3(0.018, 0.002, SIZE.y * 0.76), Vector3(SIZE.x * 0.4, by - 0.0015, 0), filet)
	Stage3D.box(_pivot, Vector3(0.1, 0.002, 0.1), Vector3(0, by - 0.0015, 0), filet)
	_corner_a = _label(Vector3(-SIZE.x * 0.33, THICK * 0.5 + 0.003, -SIZE.y * 0.3), 40)
	_corner_b = _label(Vector3(SIZE.x * 0.33, THICK * 0.5 + 0.003, SIZE.y * 0.3), 40)
	_corner_b.rotation = Vector3(-PI * 0.5, 0, PI)
	_center = _label(Vector3(0, THICK * 0.5 + 0.003, -0.07), 120)
	_suit = _label(Vector3(0, THICK * 0.5 + 0.003, 0.17), 90)


func _label(at: Vector3, px: int) -> Label3D:
	var l: Label3D = Label3D.new()
	l.font = UiKit.font("ui")
	l.font_size = px
	l.pixel_size = 0.0022
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.rotation.x = -PI * 0.5
	l.position = at
	_pivot.add_child(l)
	return l


## Valeur 1..13 (as … roi) et couleur 0..3 (pique, cœur, carreau, trèfle).
func set_card(rank: int, suit: int) -> void:
	var ranks: Array[String] = RANKS_FR if TranslationServer.get_locale().begins_with("fr") else RANKS_EN
	var red: bool = suit == 1 or suit == 2
	var col: Color = Palette.ROULETTE_RED if red else Palette.INK
	var idx: String = ranks[clampi(rank, 1, 13) - 1]
	var s: String = SUITS[clampi(suit, 0, 3)]
	_corner_a.text = "%s\n%s" % [idx, s]
	_corner_b.text = "%s\n%s" % [idx, s]
	_center.text = idx
	_suit.text = s
	for l: Label3D in [_corner_a, _corner_b, _center, _suit]:
		l.modulate = col


func _process(delta: float) -> void:
	flip = move_toward(flip, 1.0 if face_up else 0.0, delta * FLIP_SPEED)
	# Retournement autour du grand axe, avec un léger soulèvement à mi-course.
	_pivot.rotation.z = PI * (1.0 - flip)
	_pivot.position.y = sin(PI * flip) * 0.12
