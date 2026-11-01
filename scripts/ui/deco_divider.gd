class_name DecoDivider
extends Control
## Séparateur art déco : deux filets or qui s'effilent vers un losange central.

const HEIGHT: float = 18.0
const DIAMOND: float = 7.0

var color: Color = Palette.GOLD


func _init(width: float = 600.0, p_color: Color = Palette.GOLD) -> void:
	custom_minimum_size = Vector2(width, HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	color = p_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var half: float = size.x * 0.5
	var fade: Color = Color(color, 0.0)
	for side: float in [-1.0, 1.0]:
		var pts: PackedVector2Array = PackedVector2Array([c + Vector2(side * (DIAMOND + 6.0), 0), c + Vector2(side * half, 0)])
		draw_polyline_colors(pts, PackedColorArray([color, fade]), 2.0, true)
		var pts2: PackedVector2Array = PackedVector2Array([c + Vector2(side * (DIAMOND + 6.0), 5), c + Vector2(side * half * 0.6, 5)])
		draw_polyline_colors(pts2, PackedColorArray([Color(color, 0.6), fade]), 1.0, true)
	draw_colored_polygon(
		PackedVector2Array([c + Vector2(0, -DIAMOND), c + Vector2(DIAMOND, 0), c + Vector2(0, DIAMOND), c + Vector2(-DIAMOND, 0)]), color
	)
	draw_circle(c, 2.0, Palette.INK)
