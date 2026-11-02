class_name DecoFrame
extends Control
## Ornements art déco posés sur le cadre d'un panneau (surcouches, boutique, bilans) : éventails
## dorés dans les coins, filets à gradins, fronton en haut et pied en bas. Purement décoratif,
## ne capte pas la souris ; se dessine autour de son rectangle (celui du contenu du panneau).

const FAN_R: float = 34.0
const FAN_RAYS: int = 7

var accent: Color = Palette.GOLD
## Distance entre le rectangle de ce contrôle (contenu du panneau) et le cadre du panneau.
var out: float = 10.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size).grow(out - 4.0)
	var gold: Color = accent
	# Velours : fines rayures verticales et lueur sous le fronton.
	var x0: float = r.position.x + 6.0
	while x0 < r.end.x - 6.0:
		draw_line(Vector2(x0, r.position.y + 6.0), Vector2(x0, r.end.y - 6.0), Color(1, 1, 1, 0.018), 2.0)
		x0 += 9.0
	draw_circle(Vector2(r.get_center().x, r.position.y), minf(r.size.x * 0.3, 260.0), Color(accent, 0.035))
	var dim: Color = Color(accent, 0.35)
	# Double filet intérieur, à gradins aux coins.
	var inner: Rect2 = r.grow(-8.0)
	_stepped(inner, 18.0, dim, 1.5)
	# Éventails rayonnants dans les quatre coins.
	_fan(r.position, 0.0, gold)
	_fan(Vector2(r.end.x, r.position.y), PI * 0.5, gold)
	_fan(r.end, PI, gold)
	_fan(Vector2(r.position.x, r.end.y), PI * 1.5, gold)
	# Fronton : losange central et ailes à gradins ; pied symétrique.
	_crest(Vector2(r.get_center().x, r.position.y), 1.0, gold)
	_crest(Vector2(r.get_center().x, r.end.y), -1.0, gold)
	# Reflet qui parcourt le filet du haut, lentement.
	var u: float = fposmod(_t * 0.12, 1.4) - 0.2
	if u >= 0.0 and u <= 1.0:
		var x: float = r.position.x + r.size.x * u
		draw_line(Vector2(x - 40.0, r.position.y), Vector2(x + 40.0, r.position.y), Color(Palette.GOLD_LIGHT, 0.55), 3.0)


func _fan(corner: Vector2, rot: float, col: Color) -> void:
	var base: Vector2 = Vector2.RIGHT.rotated(rot)
	var down: Vector2 = Vector2.DOWN.rotated(rot)
	for k: int in FAN_RAYS:
		var a: float = float(k) / float(FAN_RAYS - 1) * PI * 0.5
		var dir: Vector2 = base * cos(a) + down * sin(a)
		var length: float = FAN_R * (0.55 + 0.45 * absf(sin(a * 2.0)))
		draw_line(corner + dir * 6.0, corner + dir * length, Color(col, 0.75), 1.5, true)
	draw_arc(corner, FAN_R * 0.42, rot, rot + PI * 0.5, 12, col, 2.0, true)
	draw_arc(corner, FAN_R * 1.02, rot, rot + PI * 0.5, 16, Color(col, 0.5), 1.0, true)
	draw_circle(corner, 4.5, col)


func _stepped(r: Rect2, step: float, col: Color, w: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		r.position + Vector2(step, 0), Vector2(r.end.x - step, r.position.y),
		Vector2(r.end.x - step, r.position.y + step * 0.5), Vector2(r.end.x - step * 0.5, r.position.y + step * 0.5),
		Vector2(r.end.x - step * 0.5, r.position.y + step), Vector2(r.end.x, r.position.y + step),
		Vector2(r.end.x, r.end.y - step), Vector2(r.end.x - step * 0.5, r.end.y - step),
		Vector2(r.end.x - step * 0.5, r.end.y - step * 0.5), Vector2(r.end.x - step, r.end.y - step * 0.5),
		Vector2(r.end.x - step, r.end.y), Vector2(r.position.x + step, r.end.y),
		Vector2(r.position.x + step, r.end.y - step * 0.5), Vector2(r.position.x + step * 0.5, r.end.y - step * 0.5),
		Vector2(r.position.x + step * 0.5, r.end.y - step), Vector2(r.position.x, r.end.y - step),
		Vector2(r.position.x, r.position.y + step), Vector2(r.position.x + step * 0.5, r.position.y + step),
		Vector2(r.position.x + step * 0.5, r.position.y + step * 0.5), Vector2(r.position.x + step, r.position.y + step * 0.5),
		r.position + Vector2(step, 0),
	])
	draw_polyline(pts, col, w, true)


## Fronton (dir = 1, en haut) ou pied (dir = -1, en bas) : losange et ailes à gradins.
func _crest(at: Vector2, dir: float, col: Color) -> void:
	var d: float = 14.0
	var gem: PackedVector2Array = PackedVector2Array(
		[at + Vector2(0, -d * dir), at + Vector2(d, 0), at + Vector2(0, d * dir), at + Vector2(-d, 0)]
	)
	draw_colored_polygon(gem, Palette.INK)
	draw_polyline(gem + PackedVector2Array([gem[0]]), col, 2.0, true)
	draw_circle(at, 4.0, Palette.GOLD_LIGHT)
	for side: float in [-1.0, 1.0]:
		for k: int in 3:
			var x0: float = at.x + side * (d + 8.0 + float(k) * 22.0)
			var hgt: float = (8.0 - float(k) * 2.5) * dir
			draw_line(Vector2(x0, at.y - hgt), Vector2(x0 + side * 16.0, at.y - hgt), col, 2.0)
		draw_line(Vector2(at.x + side * (d + 4.0), at.y), Vector2(at.x + side * (d + 110.0), at.y), Color(col, 0.6), 1.0)
